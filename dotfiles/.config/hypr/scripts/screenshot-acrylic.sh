#!/usr/bin/env bash
#  Screenshot da janela ativa (+margem) -> embelezamento acrílico
#  -----------------------------------------------------
#  Captura a JANELA ATIVA com 10px extra de cada extremidade e
#  passa pelo acrylic-crop.sh (alias `acrylic` no zshrc).
#  Pensado pro fluxo: SUPER+T deixa a janela em FullHD (1920x1080)
#  centralizada -> CTRL+SHIFT+S captura ela + 10px (= 1940x1100).
#  Como usa a geometria real da janela, alinha mesmo com barra/gaps.
#
#  Bind: CTRL SHIFT, S  (ver ~/.config/hypr/conf/keybinding.conf)
set -euo pipefail

# Margem extra capturada além da janela, em cada uma das 4 extremidades
MARGIN=10

ACRYLIC="/home/caiop/programing/kromos-group/scripts/beautification/acrylic-crop.sh"
OUTDIR="$HOME/Pictures/Screenshots"
mkdir -p "$OUTDIR"

# Geometria da janela ativa (vazio se nenhuma janela estiver focada)
GEOM=$(hyprctl activewindow -j | jq -r 'if .address then "\(.at[0]) \(.at[1]) \(.size[0]) \(.size[1])" else "" end')
read -r WX WY WW WH <<<"$GEOM" || true

if [[ -n "${WW:-}" && "$WW" -gt 0 ]]; then
    # Recorte = janela + MARGIN px em cada extremidade
    GX=$((WX - MARGIN)); GY=$((WY - MARGIN))
    GW=$((WW + 2 * MARGIN)); GH=$((WH + 2 * MARGIN))
else
    # Fallback (sem janela ativa): FullHD + margem, centralizado no monitor focado.
    # Considera scale e rotação; clampa caso o recorte seja maior que a tela.
    MON=$(hyprctl monitors -j | jq -r '.[] | select(.focused==true) | "\(.x) \(.y) \(.width) \(.height) \(.scale) \(.transform)"')
    read -r GX GY GW GH <<<"$(awk -v m="$MARGIN" '{
        mx=$1; my=$2; pw=$3; ph=$4; sc=$5; tr=$6;
        lw=pw/sc; lh=ph/sc;
        if (tr==1||tr==3||tr==5||tr==7){t=lw;lw=lh;lh=t}   # transforms rotacionados trocam W<->H
        cw=1920+2*m; ch=1080+2*m;
        if(cw>lw)cw=lw; if(ch>lh)ch=lh;
        printf "%d %d %d %d\n", mx+(lw-cw)/2, my+(lh-ch)/2, cw, ch;
    }' <<<"$MON")"
fi

TS=$(date +%Y%m%d_%H%M%S)
RAW="$OUTDIR/shot_$TS.png"
OUT="$OUTDIR/acrylic_shot_$TS.png"   # nome de saída do acrylic-crop.sh: acrylic_<base>

grim -g "${GX},${GY} ${GW}x${GH}" "$RAW"
"$ACRYLIC" "$RAW" >/dev/null

# Copia o resultado embelezado pro clipboard e notifica
wl-copy --type image/png < "$OUT"
notify-send -t 3000 -i "$OUT" "Screenshot acrílico" "Copiado p/ área de transferência · $(basename "$OUT")"
