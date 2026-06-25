# CLAUDE.md

Guia pra agentes de IA trabalharem neste repositório.

## O que é

Repositório **pessoal de customização de IDE** (VS Code + JetBrains) no **Arch
Linux**. Não há build, testes ou app — são arquivos de configuração/estilo que o
usuário copia/sincroniza pro ambiente real. Linguagens: CSS, JS (vanilla),
JSONC, ICLS.

## Estrutura

```
vscode/
  custom.css     # Forma/efeito (cartões flutuantes, sombras, paleta, breadcrumb, lista)
  custom.js      # Injeções de DOM: blur da paleta de comandos + filtro SVG do liquid glass
  settings.json  # CÓPIA versionada do settings do usuário (cores em colorCustomizations)
  style.jsonc    # Color scheme de referência (não é carregado sozinho)
  MANUAL.md      # Guia humano: editar, achar seletor, ritual do Arch
jetbrains/
  jeet_brains_theme.icls   # Color scheme JetBrains ("One Dark Vivid")
README.md
```

## ⚠️ Gotchas que mudam o resultado

1. **Dois settings.json.** O que o VS Code lê é
   `~/.config/Code/User/settings.json` (NÃO rastreado pelo git). O
   `vscode/settings.json` deste repo é só cópia versionada. **Ao mudar
   configuração, edite os DOIS** (o `~/.config` pra ter efeito, o do repo pra
   versionar). Eles têm indentação diferente (4 espaços no ativo, 6 no repo).

2. **O CSS ativo aponta pra ESTE repo.** `vscode_custom_css.imports` no settings
   ativo aponta pra `file:///home/caiop/programing/personal/style/vscode/custom.css`
   (e `custom.js`). Então editar o `custom.css`/`custom.js` deste repo já é o
   lugar certo — não há cópia separada.

## Arquitetura de cores: tema vs CSS

Regra central deste projeto, **siga sempre**:

| Tipo de mudança | Onde fazer |
|-----------------|------------|
| **Cor chapada** (fundo, foreground, borda, hover/seleção de lista) | **Tema** → `workbench.colorCustomizations` no settings (os dois) |
| **Forma e efeito** (radius, margem flutuante, sombra, glow, blur, posição) | **CSS** → `custom.css` |

Por quê: cor no tema é nativa, sem `!important`, consistente em todas as
superfícies internas e aplica **na hora** (sem reload). CSS é só pro que o tema
não consegue.

### Tokens (topo do `custom.css`, em `.monaco-workbench`)

- `--float-gap` — folga das bordas dos cartões flutuantes (editor/sidebar/painel).
  O `padding-right` das decorações de git no sidebar é `2 * --float-gap`.
- `--float-bg` / `--panel-bg` — tom dos cartões (espelha o do tema).
- `--float-shadow` — sombra dos cartões: base (suave) + topo (Y negativo) +
  ambiente + `inset` highlight (o "inner glow").

### Tons atuais (no `colorCustomizations`)

- Cartões (editor, sidebar, painel/terminal): `#181A1F`
- Backdrop atrás dos cartões + titlebar: `#23252B` (mais claro → efeito flutuante)
- Accent ativo (paleta de comandos, hover/seleção da lista): vermelho `#FF3C3C`

## Conceitos de implementação

- **Cartões flutuantes**: `.part.editor`, `.part.sidebar`, `.part.panel` ganham
  `margin: var(--float-gap)`, `width/height: calc(100% - 2*--float-gap)`,
  `border-radius`, `overflow: hidden` e `box-shadow: var(--float-shadow)`.
  Como o VS Code calcula a largura do conteúdo pela caixa original, encolher o
  cartão pode cortar a borda direita — por isso o `padding-right` compensatório
  no sidebar; se cortar, baixe `--float-gap`.
- **Conteúdo transparente**: pra o tratamento do cartão (bg + inset glow)
  aparecer, as superfícies internas são transparentes (`.part.editor .monaco-editor`,
  `.part.sidebar > .composite`, `.xterm-viewport`, etc.).
- **Activity bar embaixo**: ancorada com `position:absolute; bottom:0` no
  sidebar, senão o `overflow:hidden` do cartão a "engole".
- **Botões de janela**: requerem `"window.controlsStyle": "custom"` pra serem
  HTML estilizáveis (semáforo macOS no CSS).
- **Liquid glass** (paleta de comandos): material de 3 camadas inspirado no
  Prisma Design System — fosco (`backdrop-filter`), bisel (`inset` shadows) e
  rim ondulado via filtro SVG `#lg-rim-wobble` injetado pelo `custom.js`.

## Fluxo de trabalho

- Achar seletor: `Help → Toggle Developer Tools` (`Ctrl+Shift+I`), inspecionar,
  prototipar na aba *Styles* e copiar pro `custom.css`.
- Quase toda regra CSS precisa de `!important` (o tema tem alta especificidade).
- Aplicar: **cor de tema** → instantâneo; **CSS** → `Ctrl+Shift+P` →
  *Reload Custom CSS and JS*; **titlebar/controlsStyle** → reabrir o VS Code.
- Após `pacman -Syu`: o loader é desabilitado. Ritual no `vscode/MANUAL.md`
  (`chown /usr/share/code` → *Enable Custom CSS and JS* → reiniciar → dispensar
  aviso "corrupt").

## Git

Branch padrão `main`. Commitar só quando o usuário pedir. Mensagens devem
terminar com:

```
Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
```

## JetBrains

`.icls` é um color scheme. Instalar copiando pra
`~/.config/JetBrains/<IDE>/colors/` e selecionar em
*Settings → Editor → Color Scheme*.
