#!/bin/bash

# Opções de configuração de monitor
OPTIONS=(
    "Monitor único (Primário)"
    "Espelhar monitores"
    "Estender para a direita"
    "Estender para a esquerda"
    "Estender para cima"
    "Estender para baixo"
    "Desativar monitor externo"
    "Desativar monitor interno"
)

# Usar wofi para exibir o menu
CHOICE=$(printf "%s\n" "${OPTIONS[@]}" | wofi --dmenu --prompt="Configuração de monitores" --width=400 --height=400)

# Obter os monitores disponíveis
MONITORS=$(hyprctl monitors -j | jq -r '.[].name')
PRIMARY=$(echo "$MONITORS" | head -n1)
SECONDARY=$(echo "$MONITORS" | tail -n1)

# Verificar se temos pelo menos dois monitores
if [ "$(echo "$MONITORS" | wc -l)" -lt 2 ] && [ "$CHOICE" != "Monitor único (Primário)" ]; then
    notify-send "Monitor Switcher" "Apenas um monitor detectado. Algumas opções podem não funcionar."
fi

# Aplicar a configuração escolhida
case "$CHOICE" in
    "Monitor único (Primário)")
        hyprctl keyword monitor "$PRIMARY,preferred,auto,1"
        for monitor in $MONITORS; do
            if [ "$monitor" != "$PRIMARY" ]; then
                hyprctl keyword monitor "$monitor,disable"
            fi
        done
        ;;
    "Espelhar monitores")
        hyprctl keyword monitor "$PRIMARY,preferred,auto,1"
        hyprctl keyword monitor "$SECONDARY,preferred,auto,1,mirror,$PRIMARY"
        ;;
    "Estender para a direita")
        hyprctl keyword monitor "$PRIMARY,preferred,auto,1"
        hyprctl keyword monitor "$SECONDARY,preferred,auto,1,right-of,$PRIMARY"
        ;;
    "Estender para a esquerda")
        hyprctl keyword monitor "$PRIMARY,preferred,auto,1"
        hyprctl keyword monitor "$SECONDARY,preferred,auto,1,left-of,$PRIMARY"
        ;;
    "Estender para cima")
        hyprctl keyword monitor "$PRIMARY,preferred,auto,1"
        hyprctl keyword monitor "$SECONDARY,preferred,auto,1,above,$PRIMARY"
        ;;
    "Estender para baixo")
        hyprctl keyword monitor "$PRIMARY,preferred,auto,1"
        hyprctl keyword monitor "$SECONDARY,preferred,auto,1,below,$PRIMARY"
        ;;
    "Desativar monitor externo")
        hyprctl keyword monitor "$PRIMARY,preferred,auto,1"
        hyprctl keyword monitor "$SECONDARY,disable"
        ;;
    "Desativar monitor interno")
        hyprctl keyword monitor "$PRIMARY,disable"
        hyprctl keyword monitor "$SECONDARY,preferred,auto,1"
        ;;
    *)
        # Se nenhuma opção for selecionada ou Esc for pressionado
        exit 0
        ;;
esac

# Notificar usuário
notify-send "Monitor Switcher" "Configuração aplicada: $CHOICE"
