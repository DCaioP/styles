# Manual: customizando o VS Code (Arch Linux)

Guia prático pra editar a aparência do VS Code via CSS e não sofrer toda vez que
o Arch atualizar o pacote `code`.

---

## 1. Como o stack funciona

Duas peças trabalham juntas:

| Peça | Papel | Onde se configura |
|------|-------|-------------------|
| **Custom CSS and JS Loader** (`be5invis.vscode-custom-css`) | Injeta seu CSS/JS no VS Code (forma, sombra, layout flutuante) | `vscode_custom_css.imports` no settings |
| **settings.json** | Cores chapadas (`workbench.colorCustomizations`) + configs nativas | `~/.config/Code/User/settings.json` |

⚠️ **Pegadinha importante:** o settings que **vale** é o de
`~/.config/Code/User/settings.json`. O `settings.json` deste repo é só uma
cópia versionada — editar ele sozinho **não muda nada** até você sincronizar
pro `~/.config`.

O CSS ativo é o apontado em `vscode_custom_css.imports`. Hoje aponta pra:
```
file:///home/caiop/programing/personal/style/vscode/custom.css
```
Ou seja, **editar o `custom.css` deste repo já é o lugar certo.**

---

## 2. Fluxo pra adicionar/editar uma customização

1. **Descubra o seletor** do elemento (ver seção 3).
2. **Edite** `custom.css` (este repo) — adicione sua regra com `!important`.
3. **Recarregue** o CSS:
   `Ctrl+Shift+P` → **Reload Custom CSS and JS**
   (ou feche e abra o VS Code inteiro).
4. Não funcionou? Quase sempre é falta de `!important` ou seletor errado.

> Regra de ouro: quase tudo no VS Code precisa de `!important` porque o tema
> já define o estilo com alta especificidade.

---

## 3. Como achar o seletor CSS de um elemento

1. `Help` → `Toggle Developer Tools` (ou `Ctrl+Shift+I`).
2. Clique no ícone de "inspecionar" (canto superior esquerdo do DevTools) e
   passe o mouse no elemento que quer estilizar.
3. Veja as classes no painel. Prototipe a regra **ao vivo** na aba *Styles* do
   DevTools — quando ficar bom, copie pro `custom.css`.

**Dica de ouro:** se o container aparece **vazio** no DevTools (ex.: os botões
de janela), o elemento é desenhado nativamente pelo Electron, não é HTML —
nenhum CSS pega. É preciso forçar o VS Code a renderizar em HTML primeiro
(ver seção 4).

---

## 4. Botões da janela (minimizar/maximizar/fechar)

Por padrão o VS Code usa **Window Controls Overlay** (`wco-enabled`): os botões
são pintados pelo Electron, fora do DOM. Pra poder estilizar como CSS:

```jsonc
// settings.json
"window.controlsStyle": "custom"   // HTML, estilizável (nosso semáforo macOS)
// "hidden"  -> some com os botões
// "native"  -> padrão, NÃO estilizável
```

Depois disso, os botões viram `.window-icon` com as classes
`codicon-chrome-close` / `codicon-chrome-minimize` / `codicon-chrome-maximize` /
`codicon-chrome-restore`. O CSS de semáforo + animação de hover está no
`custom.css` (busque por "Window controls estilo macOS").

> Mudar `controlsStyle` exige **fechar e reabrir o VS Code inteiro**, não só
> recarregar a janela.

---

## 5. ⚡ O ritual do Arch: depois de cada `pacman -Syu`

Quando o pacote `code` atualiza, a injeção do Custom CSS **é perdida** e você vê
o aviso *"Your Code installation appears to be corrupt"*. É esperado. Pra voltar:

```bash
# 1. O extension precisa de permissão de escrita nos arquivos do VS Code.
#    No Arch eles pertencem ao root, então dê posse ao seu usuário:
sudo chown -R "$(whoami)":"$(whoami)" /usr/share/code

# 2. Reabilite no VS Code:
#    Ctrl+Shift+P -> "Enable Custom CSS and JS"
#    -> ele pede pra reiniciar. Reinicie.

# 3. O aviso de "corrupt" volta uma vez: clique na engrenagem ->
#    "Don't Show Again" (é só porque mexemos nos arquivos do core).
```

> O `chown` é resetado a cada update, então o passo 1 faz parte do ritual.
> Se quiser automatizar, dá pra criar um hook do pacman (ver seção 7).

**Resumo do ritual:** `chown` → `Enable Custom CSS and JS` → reiniciar → dispensar aviso.

---

## 6. Arquitetura de cores: tema vs CSS

Regra que seguimos pra não brigar com o VS Code:

| O quê | Onde mora |
|-------|-----------|
| **Cor chapada** (fundo de editor, sidebar, painel, titlebar, lista, etc.) | **Tema** → `workbench.colorCustomizations` no settings |
| **Forma e efeito** (radius, margem flutuante, sombra, glow, blur) | **CSS** → `custom.css` |

Por que: cor no tema é nativo, sem `!important`, aplica em **todas** as
superfícies internas de forma consistente e aplica **na hora** (sem reload).
CSS só pro que o tema não faz.

**Tokens do CSS** (topo do `custom.css`, em `.monaco-workbench`):

| Token | Papel |
|-------|-------|
| `--float-gap` | folga das bordas dos cartões flutuantes (editor/sidebar/painel) |
| `--float-bg` | tom dos cartões (espelha o do tema) |
| `--panel-bg` | tom do painel/terminal |
| `--float-shadow` | sombra dos cartões (base + topo + ambiente + inset highlight) |

**Tons atuais** (no `colorCustomizations`):
- Cartões (editor/sidebar/painel): `#181A1F`
- Backdrop atrás dos cartões + titlebar: `#23252B` (mais claro, dá o flutuante)
- Accent ativo (paleta de comandos, lista do sidebar): vermelho `#FF3C3C`

---

## 7. (Opcional) Automatizar o re-enable no update

Hook do pacman pra dar posse automática após atualizar o `code`:

```ini
# /etc/pacman.d/hooks/vscode-customcss.hook
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = code

[Action]
Description = Dando posse do VS Code pro usuario (Custom CSS)
When = PostTransaction
Exec = /usr/bin/chown -R caiop:caiop /usr/share/code
```

Isso resolve o passo 1 sozinho. O **Enable Custom CSS** (passo 2) ainda precisa
ser rodado manualmente dentro do VS Code, porque depende da sessão aberta.

---

## 8. Troubleshooting rápido

| Sintoma | Causa provável | Solução |
|---------|----------------|---------|
| CSS não aplica nada | Loader desabilitado após update | Seção 5 (re-enable) |
| Regra ignorada | Falta `!important` ou seletor errado | Seção 3 |
| Container vazio no DevTools | Elemento é nativo (Electron) | Seção 4 |
| Mudei o settings do repo e nada | Settings ativo é o `~/.config` | Sincronizar pro `~/.config` |
| Aviso "corrupt" toda hora | Esperado pós-injeção | "Don't Show Again" |
| Mudei uma cor e não pegou | Cor chapada deve ir no tema, não no CSS | Seção 6 |
| Cartão flutuante cortou conteúdo na direita | Largura calculada pela caixa original | Baixe `--float-gap` |
