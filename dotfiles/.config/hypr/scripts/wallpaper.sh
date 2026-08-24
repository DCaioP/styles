#!/usr/bin/env bash
# waypaper post_command: regenera as cores do pywal e recarrega os consumidores.
# Chamado pelo waypaper (config.ini) como: wallpaper.sh $wallpaper $monitor
#
# Fonte das cores, em ordem de prioridade:
#   1. ~/.config/waypaper/color-ref  — imagem fixa escolhida pelo usuario
#   2. um quadro extraido do wallpaper atual (se for video)
#   3. o proprio wallpaper (se ja for imagem)
set -u

COLOR_REF_FILE="$HOME/.config/waypaper/color-ref"

wallpaper="${1:-$(cat "$HOME/.cache/wal/wal" 2>/dev/null)}"
monitor="${2:-}"
[ -z "${wallpaper:-}" ] && exit 0

# O waypaper roda o post_command UMA VEZ POR MONITOR, em paralelo. Sem isto, os
# dois monitores disputam o pywal e a cor final e sorteio. So o monitor
# principal (o que estiver em 0,0) manda nas cores; os outros saem quietos.
if [ -n "$monitor" ] && [ "$monitor" != "All" ]; then
    color_monitor="${WALLPAPER_COLOR_MONITOR:-$(
        hyprctl monitors -j 2>/dev/null | python3 -c '
import json,sys
try: mons = json.load(sys.stdin)
except Exception: sys.exit(0)
for m in mons:
    if m["x"] == 0 and m["y"] == 0:
        print(m["name"]); break
' 2>/dev/null)}"
    if [ -n "$color_monitor" ] && [ "$monitor" != "$color_monitor" ]; then
        exit 0
    fi
fi

# Serializa: duas chamadas simultaneas corromperiam o still.png e o cache do wal.
mkdir -p "$HOME/.cache/waypaper"
exec 9>"$HOME/.cache/waypaper/.wallpaper.lock"
flock 9

# 1) Referencia de cor fixa, se o usuario tiver definido uma.
color_ref=""
if [ -r "$COLOR_REF_FILE" ]; then
    ref=$(sed -n '1p' "$COLOR_REF_FILE")
    ref="${ref/#\~/$HOME}"
    if [ -n "$ref" ] && [ -s "$ref" ]; then
        color_ref="$ref"
    elif [ -n "$ref" ]; then
        printf 'aviso: color-ref aponta pra um arquivo inexistente: %s\n' "$ref" >&2
    fi
fi

if [ -n "$color_ref" ]; then
    wallpaper="$color_ref"
else
    # 2) Wallpaper animado: nem o pywal nem o hyprlock leem video. Extrai um quadro.
    case "${wallpaper,,}" in
        *.mp4|*.mkv|*.webm|*.mov|*.avi|*.m4v|*.mpg|*.mpeg|*.wmv|*.flv|*.gif)
            still="$HOME/.cache/waypaper/still.png"
            command -v ffmpeg >/dev/null 2>&1 || exit 0
            # -ss 3 pega um quadro ja com a cena formada; se o video for curto, cai pro inicio.
            ffmpeg -y -loglevel error -ss 3 -i "$wallpaper" -frames:v 1 -vf scale=1920:-2 "$still" </dev/null 2>/dev/null
            [ -s "$still" ] || ffmpeg -y -loglevel error -i "$wallpaper" -frames:v 1 -vf scale=1920:-2 "$still" </dev/null 2>/dev/null
            [ -s "$still" ] || exit 0
            wallpaper="$still"
            ;;
    esac
fi

# pywal — waypaper ja aplicou o papel de parede, entao -n (nao re-seta)
wal -i "$wallpaper" -n -e -q

# ghosttyfetch — regera as cores da animacao de boas-vindas do terminal
[ -x "$HOME/.config/hypr/scripts/theme-ghosttyfetch.py" ] &&
    "$HOME/.config/hypr/scripts/theme-ghosttyfetch.py" >/dev/null 2>&1 || true

# vicinae — recarrega o tema (o symlink do tema ja aponta pro cache atualizado)
command -v vicinae >/dev/null 2>&1 && vicinae theme set pywal >/dev/null 2>&1 || true

# hyprland — re-source dos colors-hyprland (bordas seguem o wallpaper)
command -v hyprctl >/dev/null 2>&1 && hyprctl reload >/dev/null 2>&1 || true
