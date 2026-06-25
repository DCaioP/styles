# ✨ Style – VSCode & JetBrains

> Meu cantinho de customização de IDE. A ideia: um ambiente **escuro, leve e
> bonito**, com cartões "flutuantes", tom neutro e um toque de vermelho.
> Menos poluição, mais foco — e lindão. 💅

![Preview do VS Code](assets/preview.png)

*Editor em split, sidebar à direita e terminal — todos como cartões flutuantes
sobre um backdrop mais claro.*

---

## 🗂️ O que tem aqui

```
├── vscode/
│   ├── custom.css     # 🎨 Forma & efeito: cartões flutuantes, sombras, paleta, breadcrumb
│   ├── custom.js      # ⚙️ Injeções de DOM (blur da paleta + filtro SVG do liquid glass)
│   ├── settings.json  # 🎚️ Cópia versionada do settings (cores em colorCustomizations)
│   ├── style.jsonc    # 🌑 Color scheme de referência (dark)
│   └── MANUAL.md      # 📖 Guia prático: editar, achar seletor, ritual do Arch
├── jetbrains/
│   └── jeet_brains_theme.icls   # 🧩 Color scheme ("One Dark Vivid")
├── CLAUDE.md          # 🤖 Guia pra agentes de IA
└── README.md
```

> 👉 Como tudo funciona e como editar sem quebrar nada:
> **[vscode/MANUAL.md](vscode/MANUAL.md)**.

---

## 🎨 Como o visual é montado

Duas camadas, cada uma no seu lugar:

| Camada | Faz | Mora em |
|--------|-----|---------|
| 🎚️ **Cor chapada** | fundo, texto, bordas, hover/seleção | `workbench.colorCustomizations` no `settings.json` |
| 🧩 **Forma & efeito** | radius, margem flutuante, sombra, glow | `custom.css` (via extensão *Custom CSS and JS Loader*) |

**A paleta atual:**

| Token | Cor | Onde |
|-------|-----|------|
| Cartões (editor/sidebar/painel) | `#181A1F` 🌑 | fundo dos blocos flutuantes |
| Backdrop + titlebar | `#23252B` 🩶 | atrás dos cartões (mais claro = efeito flutuante) |
| Accent ativo | `#FF3C3C` ❤️ | paleta de comandos, item ativo da lista |

---

## 🖌️ Exemplos rápidos

**Mudar um tom** → é cor chapada, então vai no tema (`settings.json`),
aplica na hora:

```jsonc
"workbench.colorCustomizations": {
  "editor.background": "#181A1F",
  "sideBar.background": "#181A1F",
  "panel.background": "#181A1F",
  "titleBar.activeBackground": "#23252B"
}
```

**Mexer na flutuação** → é forma, então vai no `custom.css`. Tudo sai de tokens:

```css
.monaco-workbench {
  --float-gap: 6px;      /* folga entre os cartões e as bordas */
  --float-bg: #181a1f;   /* tom dos cartões */
  --float-shadow: /* base suave + sombra no topo + inset highlight */ ;
}
```

Editou o CSS? → `Ctrl+Shift+P` → **Reload Custom CSS and JS** e pronto. ✅

---

## 🧰 Setup rápido

**VSCode**

1. Instale a extensão **Custom CSS and JS Loader** (`be5invis.vscode-custom-css`).
2. Aponte o import pro `custom.css`/`custom.js` deste repo (em
   `~/.config/Code/User/settings.json`):
   ```jsonc
   "vscode_custom_css.imports": [
     "file:///home/caiop/programing/personal/style/vscode/custom.css",
     "file:///home/caiop/programing/personal/style/vscode/custom.js"
   ]
   ```
3. `Ctrl+Shift+P` → **Enable Custom CSS and JS** → reinicie.

> ⚠️ O settings que **vale** é o `~/.config/Code/User/settings.json`. O
> `vscode/settings.json` deste repo é só a cópia versionada — sincronize pra
> valer.
>
> 🩹 Depois de cada `pacman -Syu` o loader cai e precisa ser reabilitado —
> ver o **ritual do Arch** no [MANUAL](vscode/MANUAL.md).

**JetBrains**

1. Copie o `.icls` pra `~/.config/JetBrains/<NomeDaIDE>/colors/`.
2. `File > Settings > Editor > Color Scheme` → selecione o tema.

---

## 📝 Observação

Repositório pessoal. Pode pegar o que quiser à vontade — mas lembra: gosto
visual é coisa íntima. O que me agrada pode te incomodar. 😉
