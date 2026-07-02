# Plano de estudo — do zero ao "Liquid Glass" no compositor

Objetivo: chegar sozinho no resultado que prototipamos (refração de vidro na
waybar via Hyprland). O caminho cruza 5 domínios; aqui eles estão em ordem de
dependência, e **cada fase entrega um resultado visível**. Você pode PARAR em
várias alturas dependendo do objetivo:

- Só quer o **visual** (Liquid Glass numa tela)? → Fases 1–2 bastam.
- Quer um **app/daemon próprio** de vidro? → + Fase 3 (OpenGL real).
- Quer **contribuir no Hyprland** (o PR)? → + Fases 4–6.

Estimativas assumem ~5-8h/semana (part-time). Você já é dev (SQL, Delphi, Flask),
então NÃO vou mandar aprender a programar — foco no que é novo: **gráficos, GLSL,
C++ de sistema e internals de compositor**.

Mapa do que construímos (pra você ver onde cada fase entra):
`glass.frag` usa SDF + normais + `refract()` (Snell) [Fase 1], amostra a textura
`blurredBG` [Fase 2-3], é ligado por `STextureRenderData`/`renderGlass` em C++
[Fase 4], dentro do render pass do Hyprland [Fase 5], entregue como PR [Fase 6].

---

## Fase 0 — Modelo mental (1 semana, só leitura/vídeo)
**Meta:** entender COMO as peças se encaixam, sem escrever código.
- O que é um compositor Wayland, cliente vs. servidor, `wl_surface`, `wl_output`.
- O que é `wlr-layer-shell` (a waybar é um layer surface).
- O que é o "blur pass" e por que a refração precisa rodar no compositor.
**Recursos:**
- The Wayland Book — https://wayland-book.com (leia cap. 1-3, visão geral).
- Vídeo: "How does Linux graphics/Wayland work" (procure no YouTube).
- Hyprland wiki: seção de conceitos e de blur.
**Entrega:** conseguir explicar em 3 frases por que a waybar (GTK3) não faz a
refração sozinha e o compositor faz.

---

## Fase 1 — GLSL e fragment shaders (A ETAPA-CHAVE) (4-6 semanas)
**Meta:** escrever shaders. É AQUI que mora o "look da Apple". Você faz TUDO no
navegador, com feedback instantâneo, sem compilar nada.
**Tópicos, em ordem:**
1. Coordenadas/UV, cor como vetor, `vec2/3/4`, funções (`mix`, `smoothstep`, `clamp`, `step`).
2. **SDF (Signed Distance Fields)** — desenhar um retângulo arredondado (é o `sdRoundRect` do nosso shader).
3. Gradiente e **normais** por diferenças finitas (o "bisel" do vidro).
4. **Refração**: `refract()`, lei de Snell, índice de refração (IOR) — o coração do efeito.
5. Fresnel, specular, rim light, aberração cromática (o acabamento).
6. Amostrar **texturas** (`texture()`), deslocar UV = a "lente".
**Recursos (os melhores, não um firehose):**
- **The Book of Shaders** — https://thebookofshaders.com (leia inteiro, é o cânone).
- **Inigo Quilez** — https://iquilezles.org/articles/distfunctions2d (SDFs 2D) e o canal dele no YouTube.
- **"The Art of Code"** (YouTube, BigWings) — melhores tutoriais de shader passo a passo.
- **Shadertoy** — https://shadertoy.com — pratique aqui; estude shaders de "glass"/"refraction".
**Mini-projeto (o marco):** recrie o Liquid Glass INTEIRO no Shadertoy — carregue
uma imagem de fundo (iChannel0), desenhe uma pílula SDF, refrate o fundo nas
bordas, adicione rim + aberração cromática. **Isso é exatamente o nosso
`glass.frag`, mas num sandbox.** Quando isso ficar bonito, você "chegou no look".

---

## Fase 2 — Prototipar em WebGL/Three.js (2-3 semanas) [opcional mas MUITO recomendado]
**Meta:** sair do shader isolado pra um app interativo — foi EXATAMENTE o que o
autor da extensão GNOME (nossa referência) fez antes de portar. Browser = zero atrito.
**Tópicos:** o que é uma cena/mesh/material, render-to-texture (FBO), passar
uniforms do JS pro shader, animação.
**Recursos:**
- Three.js Journey — https://threejs-journey.com (pago, é o melhor) OU docs+exemplos do Three.js (grátis).
- O próprio protótipo da referência: `reference-shaders/threejs-*` (nesta pasta).
**Mini-projeto:** uma "barra de vidro" HTML sobre um wallpaper, com sliders pra
IOR/displacement/bevel — igualzinho aos knobs que criamos no Hyprland.

---

## Fase 3 — OpenGL "de verdade" (C/C++) (3-4 semanas)
**Meta:** rodar seu shader fora do navegador. Isto habilita o "Caminho A" (daemon
layer-shell próprio) e prepara pra entender o render do Hyprland.
**Tópicos:** pipeline (vertex→fragment), VBO/VAO, texturas, **framebuffers /
render-to-texture**, alpha blending, **premultiplied alpha** (o bug do "retângulo
vazando" que o shader do GNOME resolve).
**Recursos:**
- **LearnOpenGL** — https://learnopengl.com (Joey de Vries) — o padrão-ouro. Faça
  as seções: Getting Started, Textures, Framebuffers, Blending.
**Mini-projeto:** um programa C/C++ que abre uma janela, carrega uma imagem como
textura e roda seu `glass.frag` nela. Um "visualizador de vidro" standalone.

---

## Fase 4 — C++ moderno pra LER e editar codebase grande (paralelo, 4-8 semanas)
**Meta:** NÃO virar expert em C++ — só conseguir LER o Hyprland (C++23) e fazer
edições pequenas com segurança, como a gente fez (seguir o dado da layerrule até
o shader).
**Tópicos:** referências vs. ponteiros, `struct`/`enum`/`class`, smart pointers
(`SP<>`), RAII, `std::optional`, templates o básico, ler assinaturas de função.
E a habilidade meta: **rastrear fluxo de dados** num codebase (grep + ler + seguir).
**Recursos:**
- **learncpp.com** — grátis, completo (leia o suficiente pra LER, não decore tudo).
- "A Tour of C++" (Stroustrup) — versão rápida pra quem já programa.
- cppreference.com — consulta.
**Mini-projeto:** pegue QUALQUER função do Hyprland e mapeie de onde vêm os dados
dela e pra onde vão (foi essa habilidade que destravou nossa feature).

---

## Fase 5 — Wayland/Hyprland internals + build (3-4 semanas)
**Meta:** compilar o Hyprland, achar onde as coisas acontecem, fazer uma mudança
e testar aninhado (nested), sem arriscar seu daily.
**Tópicos:** o render loop, o blur pass (dual-Kawase), layer rules, o sistema de
pass elements, o loader de shaders. CMake o básico.
**Recursos:**
- Código do Hyprland + a wiki + o `AGENTS.md` (guidelines de estilo).
- As NOTES.md desta pasta (o mapa que já levantamos: onde mora `blurredBG`,
  `renderTextureWithBlurInternal`, o enum de layerrule, etc.).
**Mini-projeto:** compile o Hyprland do source, adicione uma config trivial (ex:
uma cor), rebuild, rode aninhado (`Hyprland -c config-de-teste`) e veja funcionar.
(Cuidado que já aprendemos: shaders exigem `scripts/generateShaderIncludes.sh`
antes do build; nunca `pkill -f Hyprland` — mata o próprio shell.)

---

## Fase 6 — Contribuir (o PR) (1-2 semanas)
**Meta:** transformar a mudança em contribuição de comunidade.
**Tópicos:** git branch/commit/push, fork vs. upstream, `clang-format`, ler
`AGENTS.md`, abrir PR com `gh`, PR paralelo no wiki pra opções de config novas.
**Recursos:** Pro Git (git-scm.com/book) caps. 2-3 e 6; docs de contribuição do Hyprland.
**Entrega:** o PR `layerrule = glass` (que já está pronto no seu fork como referência).

---

## Ordem de prioridade se o tempo for curto
1. **Fase 1** (shaders) — 80% do resultado visual, e a habilidade mais transferível.
2. **Fase 3** (OpenGL) — pra ter um artefato próprio rodando.
3. **Fases 4-5** (C++ + Hyprland) — só se quiser o PR/integração no compositor.

O código que construímos juntos (fork `DCaioP/Hyprland` branch `feat/layerrule-glass`
+ o `glass.frag` + estas NOTES) fica como seu **gabarito**: conforme você aprende
cada fase, volta e entende um pedaço a mais do que já está funcionando.
