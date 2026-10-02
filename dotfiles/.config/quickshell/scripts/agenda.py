#!/usr/bin/env python3
"""Agenda do calendário da barra: baixa feeds ICS (endereço secreto do Google
Agenda), expande eventos recorrentes e imprime JSON no stdout.

Fontes (FORA do repo — as URLs são segredos):
  ~/.local/share/quickshell/agenda-sources.json
  [{"name": "Pessoal", "url": "https://calendar.google.com/calendar/ical/.../basic.ics", "color": "#4285f4"}]

Saída: {"updated", "events": [{title, start, end, allDay, days[], location, link, cal, color}], "errors"}
Offline: devolve o último cache (~/.cache/quickshell/agenda.json) com os erros.
"""
import datetime as dt
import json
import os
import re
import sys
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

HOME = Path.home()
SOURCES = Path(os.environ.get("XDG_DATA_HOME", HOME / ".local/share")) / "quickshell/agenda-sources.json"
CACHE = Path(os.environ.get("XDG_CACHE_HOME", HOME / ".cache")) / "quickshell/agenda.json"
MEET = re.compile(r"https://(?:meet\.google\.com|[\w.-]*zoom\.us|teams\.microsoft\.com)/[^\s<>\"\\]+")


def emit(out):
    print(json.dumps(out, ensure_ascii=False))


def fetch(src):
    req = urllib.request.Request(src["url"], headers={"User-Agent": "quickshell-agenda"})
    with urllib.request.urlopen(req, timeout=20) as r:
        return r.read()


def local(v):
    """DTSTART/DTEND → (datetime local, é dia inteiro?)"""
    if isinstance(v, dt.datetime):
        return (v.astimezone() if v.tzinfo else v.astimezone()), False
    return dt.datetime.combine(v, dt.time()).astimezone(), True


def day_keys(start, end, all_day):
    """Dias (YYYY-MM-DD) que o evento ocupa; fim é exclusivo."""
    last = (end - dt.timedelta(seconds=1)).date() if end > start else start.date()
    d, keys = start.date(), []
    while d <= last and len(keys) < 62:
        keys.append(d.isoformat())
        d += dt.timedelta(days=1)
    return keys


def parse(src, data, start, end):
    import icalendar
    import recurring_ical_events

    cal = icalendar.Calendar.from_ical(data)
    out = []
    for ev in recurring_ical_events.of(cal).between(start, end):
        if str(ev.get("STATUS", "")).upper() == "CANCELLED":
            continue
        s, all_day = local(ev.decoded("DTSTART"))
        if "DTEND" in ev:
            e = local(ev.decoded("DTEND"))[0]
        elif "DURATION" in ev:
            e = s + ev.decoded("DURATION")
        else:
            e = s + (dt.timedelta(days=1) if all_day else dt.timedelta(hours=1))
        text = f'{ev.get("X-GOOGLE-CONFERENCE", "")} {ev.get("LOCATION", "")} {ev.get("DESCRIPTION", "")}'
        link = MEET.search(text)
        out.append({
            "title": str(ev.get("SUMMARY", "(sem título)")),
            "start": s.isoformat(),
            "end": e.isoformat(),
            "allDay": all_day,
            "days": day_keys(s, e, all_day),
            "location": str(ev.get("LOCATION", "")),
            "link": link.group(0) if link else "",
            "cal": src.get("name", ""),
            "color": src.get("color", "#4285f4"),
        })
    return out


def main():
    if not SOURCES.exists():
        return emit({"error": "nosources", "events": [], "errors": []})
    try:
        import icalendar, recurring_ical_events  # noqa: F401
    except ImportError:
        return emit({"error": "nodeps", "events": [], "errors": []})

    sources = json.loads(SOURCES.read_text())
    today = dt.date.today()
    start = today.replace(day=1) - dt.timedelta(days=45)
    end = today + dt.timedelta(days=150)

    events, errors = [], []
    with ThreadPoolExecutor(max_workers=4) as pool:
        futures = [(s, pool.submit(fetch, s)) for s in sources]
        for src, fut in futures:
            try:
                events += parse(src, fut.result(), start, end)
            except Exception as ex:  # rede, ICS inválido...
                errors.append(f'{src.get("name", "?")}: {ex}')

    events.sort(key=lambda e: (not e["allDay"], e["start"]))
    out = {"updated": dt.datetime.now().astimezone().isoformat(), "events": events, "errors": errors}

    if errors and len(errors) == len(sources) and CACHE.exists():
        cached = json.loads(CACHE.read_text())
        cached["errors"] = errors
        return emit(cached)

    CACHE.parent.mkdir(parents=True, exist_ok=True)
    CACHE.write_text(json.dumps(out, ensure_ascii=False))
    emit(out)


if __name__ == "__main__":
    sys.exit(main())
