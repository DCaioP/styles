#!/bin/sh
# Compila os shaders GLSL → .qsb (formato do Qt6 RHI). Rode após editar um .frag.
# ATENÇÃO: o hot-reload do qs NÃO relê .qsb — reinicie o qs pra ver a mudança.
cd "$(dirname "$0")" || exit 1
for f in *.frag; do
    /usr/lib/qt6/bin/qsb --glsl "100es,120,150" --hlsl 50 --msl 12 -o "$f.qsb" "$f" && echo "ok  $f.qsb"
done
