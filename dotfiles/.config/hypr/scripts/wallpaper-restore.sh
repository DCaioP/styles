#!/usr/bin/env bash
# Restaura o wallpaper no login (exec-once do Hyprland).
#
# Prefere o waypaper, mas NAO depende dele: se ele nao rodar (dependencia
# quebrada apos um upgrade de Python, por exemplo), aplica a config.ini direto
# via mpvpaper. Sem isso, uma falha do waypaper deixa a area de trabalho vazia.
set -u

CONFIG="$HOME/.config/waypaper/config.ini"
LOG="$HOME/.cache/waypaper/restore.log"
mkdir -p "${LOG%/*}"

log() { printf '%s %s\n' "$(date '+%H:%M:%S')" "$*" >>"$LOG"; }
: >"$LOG"

# Os monitores podem nao estar prontos no instante do exec-once.
for _ in $(seq 20); do
    hyprctl monitors -j 2>/dev/null | grep -q '"name"' && break
    sleep 0.25
done

if command -v waypaper >/dev/null 2>&1 && waypaper --restore >>"$LOG" 2>&1; then
    log "waypaper --restore OK"
    exit 0
fi

log "waypaper --restore falhou (veja acima) - usando fallback via mpvpaper"
[ -r "$CONFIG" ] || { log "sem $CONFIG"; exit 0; }

backend=$(python3 -c '
import configparser, sys
c = configparser.ConfigParser(); c.read(sys.argv[1], "utf-8")
print(c.get("Settings", "backend", fallback=""))' "$CONFIG")

if [ "$backend" != "mpvpaper" ]; then
    log "backend=$backend nao coberto pelo fallback"
    exit 0
fi

opts=$(python3 -c '
import configparser, sys
c = configparser.ConfigParser(); c.read(sys.argv[1], "utf-8")
print(c.get("Settings", "mpvpaper_options", fallback=""))' "$CONFIG")
color=$(python3 -c '
import configparser, sys
c = configparser.ConfigParser(); c.read(sys.argv[1], "utf-8")
print(c.get("Settings", "color", fallback="#000000"))' "$CONFIG")

# Le os pares monitor/wallpaper (listas pareadas por indice, como o waypaper grava).
python3 -c '
import configparser, os, sys
c = configparser.ConfigParser(); c.read(sys.argv[1], "utf-8")
mons = c.get("Settings", "monitors", fallback="", raw=True).split("\n")
paps = c.get("Settings", "wallpaper", fallback="", raw=True).split("\n")
for m, p in zip(mons, paps):
    m, p = m.strip(), os.path.expanduser(p.strip())
    if m and p:
        print(f"{m}\t{p}")' "$CONFIG" |
while IFS=$'\t' read -r monitor wallpaper; do
    [ -e "$wallpaper" ] || { log "arquivo sumiu: $wallpaper"; continue; }
    rm -f "/tmp/mpv-socket-$monitor"
    mpvpaper --fork -o "input-ipc-server=/tmp/mpv-socket-$monitor $opts loop panscan=1.0 --mute=yes --background-color=$color" \
        "$monitor" "$wallpaper" >>"$LOG" 2>&1
    log "mpvpaper $monitor <- ${wallpaper##*/}"
    sleep 0.3
    "$HOME/.config/hypr/scripts/wallpaper.sh" "$wallpaper" "$monitor" >>"$LOG" 2>&1 &
done

wait
