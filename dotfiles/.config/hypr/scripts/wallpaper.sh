#!/usr/bin/env bash
# waypaper post_command: regenera as cores do pywal a partir do novo wallpaper
# e recarrega os consumidores. Chamado por waypaper (config.ini → post_command).
set -u

wallpaper="${1:-$(cat "$HOME/.cache/wal/wal" 2>/dev/null)}"
[ -z "${wallpaper:-}" ] && exit 0

# pywal — waypaper já aplicou o papel de parede, então -n (não re-seta)
wal -i "$wallpaper" -n -e -q

# vicinae — recarrega o tema (o symlink do tema já aponta pro cache atualizado)
command -v vicinae >/dev/null 2>&1 && vicinae theme set pywal >/dev/null 2>&1 || true

# hyprland — re-source dos colors-hyprland (bordas seguem o wallpaper)
command -v hyprctl >/dev/null 2>&1 && hyprctl reload >/dev/null 2>&1 || true
