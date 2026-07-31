#!/usr/bin/env bash
# =============================================================================
#  install.sh — reconstrói a identidade visual/funcional do Hyprland
#  Cria symlinks de style/dotfiles/{.config,home} -> ~/.config e ~/ .
#  NÃO instala aplicativos (veja packages.txt pra a lista de dependências).
#
#  Seguro: faz backup de qualquer coisa existente em ~/.config-backup-<data>/
#  antes de sobrescrever. Idempotente (rode quantas vezes quiser).
#  Reverter: mova os itens do backup de volta, ou aponte os symlinks pro antigo.
# =============================================================================
set -euo pipefail

DOTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"

link() {
    local src="$1" dst="$2"
    [ -e "$src" ] || return 0
    if [ -L "$dst" ] || [ -e "$dst" ]; then
        # já aponta pro lugar certo? nada a fazer.
        if [ "$(readlink -f "$dst" 2>/dev/null)" = "$(readlink -f "$src")" ]; then
            echo "  ok    $dst"; return 0
        fi
        mkdir -p "$BACKUP$(dirname "${dst#$HOME}")"
        mv "$dst" "$BACKUP${dst#$HOME}"
        echo "  bkp   $dst"
    fi
    mkdir -p "$(dirname "$dst")"
    ln -s "$src" "$dst"
    echo "  link  $dst -> $src"
}

# Pastas cujo dono é o próprio app (guardam Cache/Cookies/estado): linkamos
# ARQUIVO por ARQUIVO. Linkar a pasta inteira mandaria os dados do app pro
# backup e o app começaria do zero.
FILE_ONLY=(obsidian)

echo "» ~/.config"
for d in "$DOTDIR"/.config/*; do
    name="$(basename "$d")"
    if printf '%s\n' "${FILE_ONLY[@]}" | grep -qx "$name"; then
        for f in "$d"/*; do
            [ -e "$f" ] || continue
            link "$f" "$HOME/.config/$name/$(basename "$f")"
        done
        continue
    fi
    link "$d" "$HOME/.config/$name"
done

echo "» ~/ (home dotfiles)"
shopt -s dotglob nullglob          # inclui arquivos ocultos (.Xresources etc.)
for f in "$DOTDIR"/home/*; do
    [ -e "$f" ] || continue
    link "$f" "$HOME/$(basename "$f")"
done
shopt -u dotglob nullglob

echo "» ~/.XCompose (gerado — cedilha no layout us-intl)"
"$DOTDIR/gen-xcompose.sh" || echo "  !!    falhou; veja a mensagem acima"

echo
if [ -d "$BACKUP" ]; then
    echo "Backup do que existia antes: $BACKUP"
fi
echo "Pronto. Recarregue: hyprctl reload && killall waybar; waybar &"
