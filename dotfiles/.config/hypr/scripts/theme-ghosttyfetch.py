#!/usr/bin/env python3
"""Regera as cores da animacao do ghosttyfetch a partir da paleta do pywal.

O config.json do ghosttyfetch tinha as cores chapadas num azul (#136089), que
era o color2 do pywal na epoca em que foi montado. Este script refaz esse
vinculo: o `color` vira o color2 atual e o degrade e reconstruido com a mesma
regra do original — matiz e saturacao fixos, luminosidade linear de 0.12 a 0.97
em 11 passos. Todo o resto do config (fps, sysinfo, ...) e preservado.

Uso: theme-ghosttyfetch.py [slot]     slot padrao: color2
"""
import colorsys
import json
import os
import sys
import tempfile

WAL = os.path.expanduser("~/.cache/wal/colors.json")
CONFIG = os.path.expanduser("~/.config/ghosttyfetch/config.json")
STEPS = 11
L_MIN, L_MAX = 0.12, 0.97


def hex_to_hls(value):
    value = value.lstrip("#")
    r, g, b = (int(value[i:i + 2], 16) / 255 for i in (0, 2, 4))
    return colorsys.rgb_to_hls(r, g, b)


def hls_to_hex(h, l, s):
    r, g, b = colorsys.hls_to_rgb(h, l, s)
    return "#%02x%02x%02x" % tuple(round(c * 255) for c in (r, g, b))


def main():
    slot = sys.argv[1] if len(sys.argv) > 1 else "color2"

    try:
        with open(WAL) as fh:
            palette = json.load(fh)
    except (OSError, ValueError) as exc:
        print(f"ghosttyfetch: nao li {WAL}: {exc}", file=sys.stderr)
        return 1

    accent = palette.get("colors", {}).get(slot)
    if not accent:
        print(f"ghosttyfetch: slot {slot} ausente na paleta", file=sys.stderr)
        return 1

    try:
        with open(CONFIG) as fh:
            config = json.load(fh)
    except (OSError, ValueError) as exc:
        print(f"ghosttyfetch: nao li {CONFIG}: {exc}", file=sys.stderr)
        return 1

    hue, _, sat = hex_to_hls(accent)
    ramp = [
        hls_to_hex(hue, L_MIN + (L_MAX - L_MIN) * i / (STEPS - 1), sat)
        for i in range(STEPS)
    ]

    config["color"] = accent
    config["white_gradient_colors"] = ramp

    # O config costuma ser um symlink pro repo de dotfiles. Escrever no caminho do
    # link com os.replace() trocaria o PROPRIO symlink por um arquivo comum e
    # quebraria o vinculo; por isso resolvemos o alvo real antes de gravar.
    target = os.path.realpath(CONFIG)

    # Escrita atomica: um terminal abrindo no meio do write leria JSON truncado.
    # O temporario vai no mesmo diretorio do alvo pra os.replace() nao cruzar
    # sistema de arquivos (o repo pode estar noutra particao).
    with tempfile.NamedTemporaryFile(
        "w", dir=os.path.dirname(target), delete=False
    ) as tmp:
        json.dump(config, tmp, indent=2)
        tmp.write("\n")
        temp_name = tmp.name
    os.replace(temp_name, target)

    print(f"ghosttyfetch: {slot} -> {accent}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
