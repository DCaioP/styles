#!/usr/bin/env bash
# Define qual imagem serve de referencia para as cores do tema (pywal), de forma
# independente do wallpaper que esta na tela. Util com wallpaper em video: o
# video anima na tela, mas as cores vem de uma imagem fixa que voce escolheu.
#
#   wallpaper-colors.sh <imagem>   fixa a referencia e regenera o tema
#   wallpaper-colors.sh --auto     volta a derivar do wallpaper atual
#   wallpaper-colors.sh            mostra a referencia em uso
set -u

REF="$HOME/.config/waypaper/color-ref"
mkdir -p "${REF%/*}"

case "${1:-}" in
    "")
        if [ -s "$REF" ]; then
            printf 'referencia fixa: %s\n' "$(cat "$REF")"
        else
            printf 'automatico (cores vem do wallpaper atual)\n'
        fi
        exit 0
        ;;
    --auto|-a)
        rm -f "$REF"
        printf 'voltou pro automatico; regenerando a partir do wallpaper atual\n'
        ;;
    -h|--help)
        sed -n '2,9p' "$0" | sed 's/^# \?//'
        exit 0
        ;;
    *)
        img=$(realpath -e -- "$1" 2>/dev/null) || {
            printf 'erro: nao encontrei %s\n' "$1" >&2
            exit 1
        }
        # O pywal precisa de imagem estatica; video nao serve como referencia.
        case "${img,,}" in
            *.mp4|*.mkv|*.webm|*.mov|*.avi|*.m4v|*.mpg|*.mpeg|*.wmv|*.flv)
                printf 'erro: %s e video. Passe uma imagem (png/jpg/webp).\n' "${img##*/}" >&2
                exit 1
                ;;
        esac
        printf '%s\n' "$img" >"$REF"
        printf 'referencia fixada: %s\n' "$img"
        ;;
esac

# Regenera o tema agora. Passa o monitor principal pra vencer o gate do script.
principal=$(hyprctl monitors -j 2>/dev/null | python3 -c '
import json,sys
try: mons = json.load(sys.stdin)
except Exception: sys.exit(0)
for m in mons:
    if m["x"] == 0 and m["y"] == 0:
        print(m["name"]); break
' 2>/dev/null)

atual=$(python3 -c '
import configparser, os
c = configparser.ConfigParser(); c.read(os.path.expanduser("~/.config/waypaper/config.ini"), "utf-8")
paps = c.get("Settings", "wallpaper", fallback="", raw=True).split("\n")
print(os.path.expanduser(paps[0].strip()) if paps and paps[0].strip() else "")' 2>/dev/null)

exec "$HOME/.config/hypr/scripts/wallpaper.sh" "${atual:-$1}" "${principal:-All}"
