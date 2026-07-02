#!/bin/bash

CONFIG_DIR="$HOME/.config/hypr/conf"
MONITOR_CONFIG="$CONFIG_DIR/monitor.conf"

# Função para listar configurações disponíveis
list_configs() {
  echo "Configurações disponíveis:"
  ls -1 "$CONFIG_DIR"/monitor_*.conf | sed 's/.*monitor_//' | sed 's/\.conf$//'
}

# Função para aplicar uma configuração
apply_config() {
  local config_name="$1"
  local config_file="$CONFIG_DIR/monitor_$config_name.conf"
  
  if [ ! -f "$config_file" ]; then
    echo "Erro: Configuração '$config_name' não encontrada."
    list_configs
    exit 1
  fi
  
  # Fazer backup da configuração atual
  cp "$MONITOR_CONFIG" "$MONITOR_CONFIG.bak"
  
  # Aplicar nova configuração
  cp "$config_file" "$MONITOR_CONFIG"
  
  # Recarregar o Hyprland
  hyprctl reload
  
  echo "Configuração '$config_name' aplicada com sucesso!"
}

# Função para salvar a configuração atual
save_config() {
  local config_name="$1"
  local config_file="$CONFIG_DIR/monitor_$config_name.conf"
  
  if [ -z "$config_name" ]; then
    echo "Erro: Nome da configuração não especificado."
    exit 1
  fi
  
  if [ -f "$config_file" ]; then
    read -p "Configuração '$config_name' já existe. Sobrescrever? (s/n): " confirm
    if [ "$confirm" != "s" ]; then
      echo "Operação cancelada."
      exit 0
    fi
  fi
  
  cp "$MONITOR_CONFIG" "$config_file"
  echo "Configuração atual salva como '$config_name'."
}

# Mostrar uso se nenhum argumento foi fornecido
if [ $# -eq 0 ]; then
  echo "Uso: $0 [comando] [nome_da_configuração]"
  echo ""
  echo "Comandos:"
  echo "  list             - Lista todas as configurações disponíveis"
  echo "  apply [nome]     - Aplica uma configuração existente"
  echo "  save [nome]      - Salva a configuração atual com um nome específico"
  echo ""
  list_configs
  exit 0
fi

# Processar comandos
case "$1" in
  "list")
    list_configs
    ;;
  "apply")
    if [ -z "$2" ]; then
      echo "Erro: Nome da configuração não especificado."
      list_configs
      exit 1
    fi
    apply_config "$2"
    ;;
  "save")
    if [ -z "$2" ]; then
      echo "Erro: Nome da configuração não especificado."
      exit 1
    fi
    save_config "$2"
    ;;
  *)
    echo "Comando desconhecido: $1"
    echo "Use 'list', 'apply' ou 'save'."
    exit 1
    ;;
esac

exit 0
