# Waybar · Liquid Glass

Ilhas de vidro fosco ("liquid glass") para **Waybar (GTK3)** sobre **Hyprland**,
usando só o que a stack padrão entrega — **sem patch no compositor**. O frost
real vem do blur do Hyprland; o material de vidro (tint, rim de luz, sheen,
sombra em camadas) é montado no CSS do Waybar.

> **Tier 0/1.** Isto é o teto do efeito com Waybar GTK3 + Hyprland de prateleira.
> A **refração** de verdade (a "lente" que distorce o fundo nas bordas) precisa
> de shader no compositor — as notas e o protótipo desse caminho estão em
> [`NOTES.md`](NOTES.md) e [`reference-shaders/`](reference-shaders/).

![preview](preview.png) <!-- adicione um screenshot aqui -->

## O que tem aqui

```
waybar-liquid-glass/
├── waybar/
│   ├── style.css        # o material de vidro (componentizado por tokens)
│   ├── config.jsonc     # config de referência (layout dos módulos + exclusive:false)
│   └── scripts/         # scripts auxiliares dos módulos custom
├── hypr/
│   └── hyprland-glass.conf  # trechos de blur / layerrule / gaps do Hyprland
├── NOTES.md             # R&D do caminho de refração no compositor (Tier 2)
└── reference-shaders/   # shaders GLSL de referência (GNOME / Three.js)
```

## Requisitos

- **Hyprland** (testado no 0.55.4 — a sintaxe de `layerrule` usa `match:namespace`).
- **Waybar** 0.15+ (GTK3).
- **[pywal](https://github.com/dylanaraps/pywal)** — o estilo importa
  `~/.cache/wal/colors-waybar.css` e as cores seguem o wallpaper. Sem pywal,
  troque o `@import` e defina `@background`, `@color6`, `@color7`, `@color9`.
- Fonte Nerd Font (o estilo usa *CodeNewRoman Nerd Font Propo* — ajuste em `*`).

## Instalação

1. **Waybar** — copie `waybar/style.css` e `waybar/config.jsonc` pra
   `~/.config/waybar/` (renomeando `config.jsonc` → `config`). Ajuste o caminho
   do `@import` no topo do `style.css` pro seu usuário se não for pywal.

2. **Hyprland** — leve os três blocos de `hypr/hyprland-glass.conf` pros seus
   arquivos (`decoration`, `layerrule`, `general`) ou `source` o arquivo inteiro.

3. Recarregue: `hyprctl reload` e reinicie o Waybar (`killall waybar; waybar &`).

## Como funciona (arquitetura)

| Camada | Onde | Papel |
|--------|------|-------|
| **Frost** | Hyprland `blur` + `layerrule` | borra o wallpaper atrás da barra |
| **Material** | Waybar `style.css` | tint, rim de luz, sheen, sombra (o "vidro") |
| **Flutuar** | `exclusive: false` + `gaps_out` topo | barra paira; janelas sobem por baixo |

Três decisões que fazem o efeito fechar:

- **`"exclusive": false`** no Waybar → a barra não reserva espaço; as janelas
  sobem até o `gaps_out` superior e a ilha/sombra flutua sobre o topo delas.
- **`gaps_out` superior maior** (ex.: `55, 14, 14, 14`) → a "margem" das janelas
  em relação à barra flutuante. É o número que você calibra pro respiro.
- **`margin` da ilha com folga embaixo** (`14px 12px 30px 12px`) → o layer do
  Waybar precisa ser mais alto que a ilha pra **não clipar a sombra** projetada.

## Ajuste rápido (tuning)

**Recolorir o vidro** — topo do `style.css`, bloco `TOKENS`:

```css
@define-color glass-tint   @background;  /* corpo do vidro   */
@define-color glass-accent @color6;      /* acento (hover)   */
@define-color glass-rim    #ffffff;      /* luz das bordas   */
@define-color glass-shadow #000000;      /* sombra           */
```

**Transparência / vazamento de cor** — se cor de elementos distantes "entrar" na
barra, baixe `passes` (ex.: `4 → 3`) e/ou `vibrancy` no `hyprland-glass.conf`.
Mais wallpaper à mostra: baixe as opacidades do `linear-gradient` (tint) na ilha.

**Distância da janela pra barra** — 1º valor do `gaps_out` (topo). Maior = mais
respiro; menor = janela mais "consumida" pela sombra.

**Adicionar vidro a outro elemento** — some o seletor dele às duas listas do
`COMPONENTE · Ilha de vidro` (estado normal e `:hover`).

## Limitações do GTK3

Sem `backdrop-filter`, `filter` ou `mix-blend-mode`, então: nada de refração,
aberração cromática ou blur por-widget no CSS. Tudo isso é fake via gradiente +
sombra. O caminho pra refração real (shader no Hyprland) está documentado em
[`NOTES.md`](NOTES.md).

## Créditos

- Material inspirado no *liquid glass* da Apple e no Prisma Design System.
- Shaders de referência em `reference-shaders/` (GNOME `liquid-glass`, Three.js).
