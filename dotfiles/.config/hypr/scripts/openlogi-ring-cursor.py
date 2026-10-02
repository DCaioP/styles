#!/usr/bin/env python3
"""Centraliza o Actions Ring do OpenLogi no cursor.

Por que isso existe:
  - O OpenLogi lê a posição do cursor apenas via X11 (openlogi-hook/src/
    linux.rs:145); sob Wayland o valor vem congelado.
  - Um cliente Wayland não pode posicionar a própria janela, então o
    WindowBounds pedido em openlogi-overlay/src/ring.rs:281 é descartado.
  - A window rule `move cursor -50% -50%` seria a saída natural, mas no
    Hyprland 0.56.2 o modificador `cursor` passa na validação e é ignorado
    (medido: `move 400 400` posiciona; `move cursor 0 0` cai no centro do
    monitor). Só `move` com coordenadas absolutas funciona.

Então: escuta o socket de eventos do Hyprland e, quando a janela do ring
abre, lê o cursor real e reposiciona a janela por dispatcher.
"""

import json
import os
import socket
import subprocess
import sys

RING_CLASS = "openlogi-action-ring"
RING_SIZE = 360  # openlogi-overlay/src/ring.rs:24 -> WINDOW_SIZE

def hyprctl(*args):
    out = subprocess.run(["hyprctl", *args], capture_output=True, text=True)
    return out.stdout.strip()

def cursor_pos():
    raw = hyprctl("cursorpos")
    try:
        x, y = (int(p.strip()) for p in raw.split(","))
        return x, y
    except ValueError:
        return None

def monitor_at(x, y):
    """Monitor que contém o ponto. Os monitores podem se sobrepor na config
    do usuário, então o primeiro que contiver o ponto vence."""
    try:
        mons = json.loads(hyprctl("-j", "monitors"))
    except json.JSONDecodeError:
        return None
    for m in mons:
        mx, my = m["x"], m["y"]
        mw = m["width"] / m.get("scale", 1)
        mh = m["height"] / m.get("scale", 1)
        if mx <= x < mx + mw and my <= y < my + mh:
            return mx, my, mw, mh
    return None

def place(address):
    pos = cursor_pos()
    if pos is None:
        return
    cx, cy = pos
    x = cx - RING_SIZE // 2
    y = cy - RING_SIZE // 2
    mon = monitor_at(cx, cy)
    if mon:  # não deixa o anel sair da tela onde o cursor está
        mx, my, mw, mh = mon
        x = max(mx, min(x, mx + mw - RING_SIZE))
        y = max(my, min(y, my + mh - RING_SIZE))
    hyprctl("dispatch", "movewindowpixel",
            f"exact {int(x)} {int(y)},address:0x{address}")

def main():
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    runtime = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    if not sig:
        print("HYPRLAND_INSTANCE_SIGNATURE ausente", file=sys.stderr)
        return 1
    path = f"{runtime}/hypr/{sig}/.socket2.sock"

    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.connect(path)
    buf = b""
    while True:
        chunk = sock.recv(4096)
        if not chunk:
            return 0
        buf += chunk
        while b"\n" in buf:
            line, buf = buf.split(b"\n", 1)
            text = line.decode("utf-8", "replace")
            # openwindow>>endereco,workspace,classe,titulo
            if not text.startswith("openwindow>>"):
                continue
            parts = text[len("openwindow>>"):].split(",", 3)
            if len(parts) >= 3 and parts[2] == RING_CLASS:
                place(parts[0])

if __name__ == "__main__":
    sys.exit(main())
