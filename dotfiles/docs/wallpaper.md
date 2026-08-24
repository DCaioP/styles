# Wallpaper animado + cores do tema

Wallpaper em **vídeo**, um por monitor, com as cores do sistema (Hyprland,
Waybar, hyprlock, vicinae, animação do terminal) derivadas de uma imagem que
você escolhe — independente do que está tocando na tela.

## Peças

| Peça | Papel |
|------|-------|
| `waypaper` | frontend: GUI, CLI, guarda o par monitor↔wallpaper e restaura no login |
| `mpvpaper` | backend de vídeo — é ele que desenha o wallpaper animado |
| `socat` | troca o vídeo pelo socket IPC do mpv, sem respawn |
| `ffmpeg` | extrai um quadro do vídeo pra alimentar o pywal |
| `pywal` | gera a paleta a partir de uma imagem estática |

```
                     waypaper (config.ini: monitor ↔ wallpaper)
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
        mpvpaper HDMI-A-2               mpvpaper DP-1
        (vídeo na tela)                 (vídeo na tela)
              │                               │
              └──────────► post_command ◄─────┘
                     wallpaper.sh $wallpaper $monitor
                              │
                    (só o monitor principal passa)
                              ▼
                  fonte da cor: color-ref  ou  quadro do vídeo
                              ▼
                          wal -i
                              ▼
              ┌───────────┬───────────┬──────────────┐
              ▼           ▼           ▼              ▼
          Hyprland     Waybar     vicinae     ghosttyfetch
                                              (animação do terminal)
```

## Arquivos deste repo

```
.config/hypr/scripts/
  wallpaper-restore.sh     # exec-once do login; waypaper --restore + fallback
  wallpaper.sh             # post_command: decide a cor e propaga pros consumidores
  wallpaper-colors.sh      # fixa/limpa a imagem de referência das cores
  theme-ghosttyfetch.py    # regera as cores da animação do terminal
.config/waypaper/config.ini    # backend, pares monitor↔wallpaper, post_command
.config/ghosttyfetch/config.json  # cores da animação (regerado; versionado como semente)
.config/zshrc/25-aliases       # wallcolor, wallset
```

## Instalar num sistema novo

```bash
yay -S --needed waypaper mpvpaper python-screeninfo socat ffmpeg
./install.sh                       # symlinks
mkdir -p ~/Wallpaper/live          # ponha vídeos e imagens aqui
```

Depois edite `.config/waypaper/config.ini` com os nomes dos **seus** monitores
(`hyprctl monitors -j | jq -r .[].name`) e rode `waypaper --restore`.

## Uso

```bash
wallset DP-1 ~/Wallpaper/live/algum.mp4   # troca o wallpaper de UM monitor
wallcolor ~/Wallpaper/live/wall.png       # fixa a imagem de referência das cores
wallcolor --auto                          # volta a derivar do vídeo em tela
wallcolor                                 # mostra a referência em uso
waypaper                                  # GUI (Super+Ctrl+W)
waypaper --random                         # sorteia um por monitor (Super+Shift+W)
waypaper --list                           # o par monitor↔wallpaper atual
```

## ⚠️ Gotchas

Cada um destes custou uma sessão de depuração.

### 1. `waypaper --wallpaper` sem `--monitor` destrói a config por monitor

```
antes:  HDMI-A-2 -> guts.mp4        depois:  All -> outro.mp4
        DP-1     -> rengoku.mp4
```

`attribute_selected_wallpaper()` (`config.py:207`) colapsa as listas num único
par quando o monitor é `All`. **Sempre passe `--monitor`** — é o que o alias
`wallset` garante. `waypaper --random` é seguro: passa por outro caminho, que
itera `zip(wallpapers, monitors)`.

### 2. O `post_command` roda uma vez POR MONITOR, em paralelo

`__main__.py` dispara uma thread por monitor com 0.1s de intervalo. Sem defesa,
duas instâncias do `wallpaper.sh` competem: dois `ffmpeg` escrevendo no mesmo
`still.png` e dois `wal` disputando — a cor final vira sorteio.

Defesa no `wallpaper.sh`: só o monitor em `0,0` regenera cores (os outros saem
em silêncio), mais um `flock`. Sobrescreva o escolhido com
`WALLPAPER_COLOR_MONITOR`.

### 3. pywal e hyprlock não leem vídeo

`wal -i video.mp4` falha, e o `$wallpaper` do hyprlock viraria um caminho de
`.mp4` — tela de lock quebrada. O `wallpaper.sh` extrai um quadro com
`ffmpeg -ss 3` (com fallback pro início, se o vídeo for curto) em
`~/.cache/waypaper/still.png` e usa esse PNG.

### 4. `python-screeninfo` quebra em upgrade de Python

Sintoma: `ModuleNotFoundError: No module named 'screeninfo'`, e no login **o
wallpaper não sobe**. O pacote AUR foi compilado pra uma versão antiga
(arquivos em `/usr/lib/python3.12/`) e o sistema já está noutra. Como a versão
do pacote não mudou, `yay -S --needed` **pula** e não resolve. Force:

```bash
yay -S --rebuild --noconfirm python-screeninfo
```

Diagnóstico rápido:

```bash
pacman -Ql python-screeninfo | grep -c "python$(python3 -c 'import sys;print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
# 0 = precisa rebuild
```

Por isso o `wallpaper-restore.sh` tem fallback: se o waypaper morrer, ele lê a
`config.ini` sozinho e sobe o mpvpaper. Log em `~/.cache/waypaper/restore.log`,
reescrito a cada boot.

### 5. Sem auto-pause

O mpvpaper tem `--auto-pause` pra congelar o vídeo quando uma janela cobre a
tela, mas o waypaper monta o comando internamente e só expõe `-o` (opções do
mpv) — não dá pra injetar flags do próprio mpvpaper. O vídeo roda o tempo todo.
Numa RTX 3060 Ti, dois vídeos 4K custam ~30% de GPU e ~25% do decoder.

Baratear: pré-escale o vídeo pra resolução real do monitor. Um 4K num monitor
1080p é decodificado em 4K e só depois reduzido.

```bash
ffmpeg -i in.mp4 -vf scale=1920:-2 -c:v libx264 -crf 20 -an out.mp4
```

### 6. O `config.json` do ghosttyfetch é symlink e é reescrito

O gerador resolve o `realpath` antes de gravar. Escrever no caminho do link com
`os.replace()` trocaria o **symlink** por um arquivo comum e quebraria o
vínculo com o repo no primeiro wallpaper trocado.

Efeito colateral esperado: trocar de tema deixa o git sujo (`config.json` e
`waypaper/config.ini` são estado vivo versionado). O `color-ref` fica no
`.gitignore` porque guarda caminho absoluto da máquina.

## A animação do terminal (ghosttyfetch)

As cores estavam chapadas no `config.json` — `#136089` mais uma rampa de 11
azuis. Aquele `#136089` era o `color2` do pywal na época em que o arquivo foi
montado; ou seja, geraram uma vez e congelaram. O
`theme-ghosttyfetch.py` restabelece o vínculo.

Template do pywal não serve: só substitui texto, e a rampa exige interpolação.
Decompondo a original em HSL, a regra é exata:

```
#072636  H=200.4  S=0.77  L=0.12    ← matiz e saturação constantes
#125b82  H=200.9  S=0.76  L=0.29       luminosidade linear 0.12 → 0.97
#1d90ce  H=201.0  S=0.75  L=0.46       em 11 passos
#f2f9fd  H=201.8  S=0.73  L=0.97
```

O script reimplementa isso a partir do `color2` atual, preservando `fps`,
`sysinfo` e o resto. Outro slot: `theme-ghosttyfetch.py color4`.

> **Binário fora do gerenciador de pacotes.** O `~/.local/bin/ghosttyfetch` é um
> executável Zig que nenhum pacote possui e sem URL embutida — não dá pra
> rastrear a origem pelo sistema. Guarde o link de onde ele veio; sem isso essa
> parte não é replicável. As `animation.json`/`ansi.json` (2.6M) não estão
> versionadas: vêm com a distribuição do binário.

## Trocar de backend

Vídeo é o modo atual. Pra voltar a imagem estática, mude `backend` na
`config.ini` pra `swww` e rode `waypaper --restore` — o waypaper sobe o
`swww-daemon` sozinho. O `wallpaper.sh` continua funcionando: sem vídeo, ele
usa a imagem direto, sem passar pelo ffmpeg.
