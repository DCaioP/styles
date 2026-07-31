#!/usr/bin/env python3
"""Regenera as cores do ghosttyfetch a partir da paleta atual do pywal.

O ghosttyfetch emite truecolor (\\e[38;2;r;g;b), então ele ignora as sequences
OSC 4 do wal — que só remapeiam os 16 slots da paleta do terminal. Por isso o
`wal -i` sozinho nunca muda o tom dele: é preciso reescrever o hex no
~/.config/ghosttyfetch/config.json. É o que este script faz.

Rodar manualmente depois do `wal -i` (alias `walfetch`):

    ghosttyfetch-from-wal.py            # accent = cor mais viva da paleta
    ghosttyfetch-from-wal.py color4     # accent = slot específico do wal
    ghosttyfetch-from-wal.py '#ff3131'  # accent = hex cru
"""

import colorsys
import json
import sys
from pathlib import Path

WAL_COLORS = Path.home() / ".cache/wal/colors.json"
GF_CONFIG = Path.home() / ".config/ghosttyfetch/config.json"

# Slots candidatos a accent (0 = fundo, 7/15 = texto -> não servem).
ACCENT_SLOTS = [f"color{i}" for i in range(1, 7)]

# O gradiente original ia de um tom escuro saturado até um quase-branco tingido.
GRADIENT_STEPS = 11
GRADIENT_MIN_L = 0.12
GRADIENT_MAX_L = 0.97


def die(msg):
    print(f"Erro: {msg}", file=sys.stderr)
    sys.exit(1)


def hex_to_hls(value):
    value = value.lstrip("#")
    r, g, b = (int(value[i:i + 2], 16) / 255 for i in (0, 2, 4))
    return colorsys.rgb_to_hls(r, g, b)


def hls_to_hex(h, l, s):
    r, g, b = colorsys.hls_to_rgb(h, l, s)
    return "#{:02x}{:02x}{:02x}".format(*(round(c * 255) for c in (r, g, b)))


def pick_accent(colors, override=None):
    """Escolhe o accent: o slot mais saturado, ou o que o usuário pediu."""
    if override:
        if override.startswith("#"):
            return override
        if override not in colors:
            die(f"slot '{override}' não existe em {WAL_COLORS}")
        return colors[override]

    # Mais saturado vence; empate desempata pelo mais claro (mais visível).
    return max(
        (colors[slot] for slot in ACCENT_SLOTS if slot in colors),
        key=lambda hex_value: (hex_to_hls(hex_value)[2], hex_to_hls(hex_value)[1]),
    )


def build_gradient(accent):
    """Rampa escuro -> quase-branco mantendo o matiz do accent."""
    h, _, s = hex_to_hls(accent)
    span = GRADIENT_MAX_L - GRADIENT_MIN_L
    return [
        hls_to_hex(h, GRADIENT_MIN_L + span * i / (GRADIENT_STEPS - 1), s)
        for i in range(GRADIENT_STEPS)
    ]


def main():
    if not WAL_COLORS.exists():
        die(f"{WAL_COLORS} não encontrado. Rode `wal -i <imagem>` primeiro.")
    if not GF_CONFIG.exists():
        die(f"{GF_CONFIG} não encontrado.")

    colors = json.loads(WAL_COLORS.read_text())["colors"]
    accent = pick_accent(colors, sys.argv[1] if len(sys.argv) > 1 else None)
    gradient = build_gradient(accent)

    # Carrega e reescreve só as chaves de cor — o resto do config fica intacto.
    config = json.loads(GF_CONFIG.read_text())
    config["color"] = accent
    config["white_gradient_colors"] = gradient
    GF_CONFIG.write_text(json.dumps(config, indent=2, ensure_ascii=False) + "\n")

    print(f"ghosttyfetch: accent {accent}, gradiente {gradient[0]} -> {gradient[-1]}")


if __name__ == "__main__":
    main()
