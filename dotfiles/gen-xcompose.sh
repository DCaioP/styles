#!/usr/bin/env bash
# =============================================================================
#  gen-xcompose.sh — gera ~/.XCompose a partir do Compose do sistema,
#  trocando as sequências de C-com-acento-agudo (ć/Ć) por cedilha (ç/Ç).
#
#  Por quê: o layout é us(intl) (ver .config/hypr/conf/keyboard.conf), onde a
#  tecla ' é dead_acute. O Compose padrão mapeia <dead_acute> <c> -> "ć"
#  (polonês). Em pt-BR o esperado é "ç".
#
#  Por que gerar em vez de versionar o arquivo: o ~/.XCompose é uma cópia
#  integral do Compose do sistema (448K) com apenas 8 linhas trocadas. Versionar
#  o gerador mantém o repo enxuto e, mais importante, o arquivo não congela —
#  ao atualizar o libx11, rode de novo e as sequências novas entram junto.
#
#  Quem lê o ~/.XCompose: Xlib (apps X11/XWayland, incluindo Electron com
#  --ozone-platform=x11) e libxkbcommon-compose (foot, kitty, ...). GTK usa o
#  módulo de IM (GTK_IM_MODULE=simple, setado em hypr/conf/keyboard.conf).
#  NÃO cobre Electron em Wayland nativo — esse caso é tratado com a flag em
#  .config/obsidian/user-flags.conf.
#
#  Idempotente. Guarda o arquivo anterior em ~/.XCompose.bak.
# =============================================================================
set -euo pipefail

SRC="${1:-/usr/share/X11/locale/en_US.UTF-8/Compose}"
DST="$HOME/.XCompose"

[ -r "$SRC" ] || { echo "!! Compose do sistema não encontrado: $SRC" >&2; exit 1; }

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

sed -E 's/^(<[^:]*>[[:space:]]*:[[:space:]]*)"Ć"/\1"Ç"/; s/^(<[^:]*>[[:space:]]*:[[:space:]]*)"ć"/\1"ç"/' \
    "$SRC" > "$TMP"

# Sanidade: se o upstream mudar de formato o sed vira no-op silencioso.
trocadas=$(diff "$SRC" "$TMP" | grep -c '^>' || true)
if ! grep -qE '^<dead_acute>[[:space:]]*<c>[[:space:]]*:[[:space:]]*"ç"' "$TMP"; then
    echo "!! regra <dead_acute> <c> -> \"ç\" não foi aplicada; $DST mantido como estava" >&2
    exit 1
fi

if cmp -s "$TMP" "$DST" 2>/dev/null; then
    echo "  ok    $DST (já atualizado, $trocadas sequências de cedilha)"
    exit 0
fi

[ -e "$DST" ] && cp -a "$DST" "$DST.bak" && echo "  bkp   $DST.bak"
cp "$TMP" "$DST"
echo "  gen   $DST ($trocadas sequências ć/Ć -> ç/Ç, base: $SRC)"
echo "        apps precisam ser reabertos pra reler o arquivo."
