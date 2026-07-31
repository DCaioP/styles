# dotfiles · identidade visual do Hyprland

Configuração **visual e funcional** do meu desktop Hyprland (Arch/Wayland),
versionada pra reconstruir a *cara* e o *funcionamento* do sistema — **sem
reinstalar aplicativos**, só as configs.

> Este diretório é a **fonte canônica** das configs (~1.2M, enxuto): `~/.config/*`
> são symlinks apontando pra cá (via `install.sh`).

## Estrutura

```
dotfiles/
├── .config/                 # symlinkado p/ ~/.config
│   ├── hypr/                # compositor: monitores, binds, regras, decoração, animações, lock/idle
│   ├── waybar/              # barra (liquid glass — ver docs/)
│   ├── wal/                 # templates do pywal (cores seguem o wallpaper)
│   ├── gtk-3.0/ gtk-4.0/    # tema GTK
│   ├── qt6ct/ xsettingsd/   # tema QT / xsettings
│   ├── ags/                 # widgets (Aylur's GTK Shell)
│   ├── rofi/ wofi/          # launchers
│   ├── dunst/               # notificações
│   ├── wlogout/             # tela de logout
│   ├── nwg-dock-hyprland/   # dock
│   ├── waypaper/            # GUI de wallpaper (swww)
│   ├── kitty/               # terminal
│   ├── obsidian/            # só user-flags.conf (cedilha — ver Notas); pasta é do app
│   └── nvim/ vim/ zshrc/ bashrc/ fastfetch/ ohmyposh/  # editor/shell/fetch
├── home/                    # dotfiles de nível ~ (.Xresources, .gtkrc-2.0)
├── docs/liquid-glass/       # R&D do efeito liquid glass (notas + shaders de referência)
├── install.sh               # cria os symlinks (com backup do que existir)
├── gen-xcompose.sh          # gera ~/.XCompose (cedilha no us-intl); chamado pelo install
└── packages.txt             # dependências (referência; não auto-instala)
```

## Reconstruir num sistema novo

```bash
# 1) dependências (revise a lista antes; alguns são AUR)
sudo pacman -S --needed $(grep -vE '^#|^$' packages.txt | awk '{print $1}')

# 2) symlinks (faz backup de ~/.config/* existente em ~/.config-backup-<data>)
./install.sh

# 3) recarrega
hyprctl reload && killall waybar 2>/dev/null; waybar &
```

**Cores (pywal):** o visual segue o wallpaper via [pywal](https://github.com/dylanaraps/pywal).
Gere as cores uma vez (`wal -i /caminho/do/wallpaper.jpg`) — isso popula
`~/.cache/wal/` que o Waybar/Hypr importam. Wallpaper em si: `swww` + `waypaper`.

## Notas

- **Fonte canônica é este repo.** Se mover a pasta, os symlinks quebram — rode
  `install.sh` de novo pra recriar apontando pro novo caminho.
- **Cedilha (`ç`) no layout us-intl.** O layout é `us(intl)` (`hypr/conf/keyboard.conf`),
  onde `'` é `dead_acute` — e o Compose padrão mapeia `dead_acute + c` pra `ć`
  (polonês), não `ç`. A correção tem duas metades, porque cada toolkit compõe de
  um jeito:
  1. **`gen-xcompose.sh`** gera o `~/.XCompose` (cópia do Compose do sistema com
     8 sequências `ć/Ć` trocadas por `ç/Ç`). Cobre Xlib (apps X11/XWayland) e
     libxkbcommon (foot, kitty). Rode de novo depois de atualizar o `libx11`.
     GTK entra por outro caminho: `GTK_IM_MODULE=simple` em `hypr/conf/keyboard.conf`.
  2. **`.config/obsidian/user-flags.conf`** força `--ozone-platform=x11`. Em
     Wayland nativo o Electron compõe com uma tabela compilada no binário e
     ignora o `~/.XCompose` (nem importa os símbolos `xkb_compose_*`) — só o
     caminho X11 respeita o arquivo. Vale pra qualquer app Electron que apareça
     digitando `ć`: dê a mesma flag.
- **Pastas de app dentro de `.config/`.** `install.sh` linka a pasta inteira, o
  que destruiria o estado de apps que guardam cache/cookies ali. Essas ficam na
  lista `FILE_ONLY` do `install.sh` e são linkadas arquivo por arquivo (hoje:
  `obsidian`).
- **Liquid glass**: a barra usa vidro fosco montado em CSS + blur do compositor.
  A anatomia, os gotchas e o caminho pra refração real (shader no Hyprland) estão
  em [`docs/liquid-glass/`](docs/liquid-glass/).

## Reverter

`install.sh` guarda o que substituiu em `~/.config-backup-<data>/`. Pra voltar,
mova de volta de lá.
