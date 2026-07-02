# Waybar Liquid Glass — notas de projeto

Objetivo: chegar o mais perto possível do "Liquid Glass" da Apple na waybar do
Hyprland (NVIDIA RTX 3060 Ti, Waybar 0.15 GTK3, pywal).

## Estado atual (Tier 0/1 — feito)
Frosted glass real via compositor + fake de rim/sheen em CSS GTK3.
- `~/.config/hypr/conf/windowrule.conf`: `layerrule = match:namespace ^(waybar)$, blur on` + `ignore_alpha 0.3` (sintaxe nova do Hyprland 0.55+).
- `~/.config/hypr/conf/decoration.conf`: blur `vibrancy 0.25`, `vibrancy_darkness 0.15` (global).
- `~/.config/waybar/style.css`: ilhas com gradiente de tint, rim especular no topo, sheen, hairline, sombra interna, drop shadow, + lift no hover com halo de acento (@color6).

Teto do Tier 0/1 = ~70-75% do visual. Falta a **refração** (a lente nas bordas).

## O que NÃO dá com a stack atual
Waybar é GTK3 → CSS sem `backdrop-filter`/`filter`/`mix-blend-mode`. Nenhum
gancho de shader por-widget. Refração precisa de GLSL rodando no compositor ou
num surface layer-shell próprio.

## Referência de ouro: ryohsuke1231/liquid-glass (extensão GNOME)
GNOME consegue refração porque usa `Clutter.ShaderEffect` (GLSL por actor).
Shaders salvos em `reference-shaders/`:
- `gnome-glass.frag` — o shader de produção (424 linhas). É o núcleo reutilizável.
- `threejs-glass.frag` / `threejs-vertex.glsl` — protótipo WebGL original.

### Anatomia do gnome-glass.frag (o que dá pra portar)
Pipeline por pixel, todo dirigido por uniforms:
1. **SDF** de rounded-rect (`sdRoundRect`) → distância `d` (dentro<0, fora>0).
2. **Campo de altura** por **superelipse** (`profileHeight`, expoente `profile_shape_n`)
   → simula espessura fluida, alta no centro, caindo pras bordas.
3. **Normal** via diferenças finitas do campo de altura (`heightGradient`→`getNormal`).
4. **Refração** (`getDisplacement`): `refract(viewDir, normal, 1.0/ior)` (Snell),
   projeta o raio no plano de fundo → **deslocamento de UV** (a "lente"). Clampa
   deslocamento máximo e trata reflexão interna total.
5. **Aberração cromática**: amostra R/G/B em UVs levemente separados ao longo do
   deslocamento (`chroma_strength`) → borda espectral.
6. **Blur** 4-tap por canal sobre o fundo refratado.
7. **Tint** (`mix(refracted, tintColor, tint_strength)`).
8. **AO interno** + **focal highlight** → 3D mesmo sobre fundo branco.
9. **Rim / fresnel / specular / sheen** com `light_angle_deg`.
10. **Screen blend** (A+B-A*B) pra não estourar branco; saída **premultiplied alpha**.

Entrada essencial: `cogl_sampler` = **textura do que está atrás**. Todo o efeito
é reamostrar essa textura com deslocamento. É a única dependência de plataforma.

## Caminhos de porte (Tier 2) — do menos ao mais invasivo
O trabalho é sempre: "dar a esse shader uma textura do fundo + desenhá-lo sob a barra".

### A) Daemon layer-shell próprio (recomendado p/ começar)
Surface `wlr-layer-shell` no layer `bottom`, logo abaixo da waybar (que fica
transparente e só desenha texto/ícones). Loop:
- `wlr-screencopy` da região atrás da barra (ou sample direto do wallpaper).
- Upload como textura → roda `gnome-glass.frag` adaptado (trocar `cogl_*` por
  GL/EGL puro; uniforms viram config).
- Desenha as ilhas de vidro refrativo.
Prós: não precisa patch no Hyprland; isolado; usa GPU direto. Contras: sincronia
screencopy vs. waybar; custo de captura contínua (mitigável: barra é quase estática).
Stack sugerida: C/Zig/Rust + `wayland-client` + `wlr-layer-shell` + EGL/OpenGL.

### B) Plugin do Hyprland (hyprpm) — mais nativo
Hyprland já produz o framebuffer borrado atrás de cada layer no blur pass
(`src/render/`). Um plugin adicionaria uma `layerrule = glass` que, pra layers
casando, roda um pós-processo com a matemática do gnome-glass.frag amostrando
esse backbuffer borrado. Sem screencopy, sem sync manual, borra conteúdo real.
Prós: nativo, zero latência, mergeável como feature. Contras: C++ no interno do
Hyprland; API de plugin muda entre versões; curva maior.
Ponto de entrada: achar onde o blur escreve a região do layer e injetar o shader
de refração ali (candidato a PR upstream, não só plugin).

### C) screen_shader global (`decoration:screen_shader`)
Shader único no frame inteiro. Dá pra restringir por coordenada (só a faixa da
barra), mas é global e desajeitado. Só como PoC rápido da matemática de refração.

## Caminho B — ponto de injeção CONFIRMADO no source (Hyprland v0.55.4)
Investigação read-only do source (arquivos-chave abaixo). Descoberta que muda a
recomendação: **B ficou mais fácil que A**, porque o Hyprland já computa e
entrega a textura do fundo borrado — não precisa de screencopy.

### O ponto exato
`src/render/OpenGL.cpp` → `CHyprOpenGLImpl::renderTextureWithBlurInternal(...)`
(~linha 1943). Dentro dela, o fundo borrado é desenhado como quad chapado:
```cpp
renderTextureInternal(data.blurredBG, box, STextureRenderData{ ... });
```
`data.blurredBG` **é exatamente o `cogl_sampler`** do gnome-glass.frag: a textura
do que está atrás do surface, já borrada (dual-Kawase, com vibrancy/noise). Um
caminho "glass" trocaria essa chamada por um `renderGlass(data.blurredBG, box,
params)` que amostra `blurredBG` com deslocamento de UV (refração) em vez de 1:1.

### Sistema de shaders (extensível, com molde pronto)
- Shaders em `src/render/shaders/glsl/`, registrados em OpenGL.cpp:
  `SHADER_INCLUDES` (~L875) e `FRAG_SHADERS` (~L881) + enum `SH_FRAG_*`.
- **Molde ideal: `inner_glow.frag` + `inner_glow.glsl`** (efeito decorativo
  recém-adicionado, via `InnerGlowPassElement`). Já recebe os uniforms de
  geometria que o vidro precisa: `topLeft, bottomRight, fullSize, radius,
  roundingPower, range` — e usa `rounding.glsl` (SDF de rounded-rect **já
  pronto**, poupa o `sdRoundRect` do gnome-glass.frag).
- Precedente de pós-efeito no pass system: `src/render/pass/InnerGlowPassElement.*`
  é o template pra um `GlassPassElement`.
- `decoration:screen_shader` (OpenGL.cpp L747, `applyScreenShader`) = rota do
  screen shader global (Caminho C), útil só pra PoC da matemática.

### Shape concreto do PR/plugin
1. `glass.frag` + `glass.glsl` em `shaders/glsl/` — portar gnome-glass.frag,
   reusando `rounding.glsl` pro SDF. Uniforms: ior, displacement_scale,
   profile_shape_n, chroma_strength, tint_*, rim_*, etc.
2. Registrar em `FRAG_SHADERS`/`SH_FRAG_*`/loader (OpenGL.cpp ~L875-891).
3. Parse de `layerrule = match:..., glass on` (+ params) e flag no surface data.
4. Em `renderTextureWithBlurInternal`, se o layer tem `glass`, chamar o path de
   refração amostrando `data.blurredBG` em vez do `renderTextureInternal` chapado.

Arquivos de referência baixados/estudados: OpenGL.cpp (2644 linhas), estrutura
de `src/render/pass/*PassElement`, `shaders/glsl/{inner_glow,rounding,surface}`.

## Próximo passo sugerido (revisado)
Caminho B é o alvo primário (nativo, sem screencopy, reusa `blurredBG`).

IMPORTANTE — Caminho C (screen_shader) NÃO serve de PoC aqui: o screen shader
roda no frame FINAL já composto, onde a waybar já ocluiu o fundo atrás dela.
Só refrataria o que está ao redor da barra, não atrás. Descartado pra este efeito.

Ordem prática realista:
1. Validar a matemática de refração isoladamente num sandbox GL simples (ou no
   próprio protótipo Three.js do repo, em `reference-shaders/threejs-*`), com
   uma textura de fundo fixa. Sem tocar no compositor.
2. Portar pra `glass.frag` interno + path em `renderTextureWithBlurInternal`
   (build local do Hyprland — precisa de sessão dedicada, é patch em compositor
   vivo; testar num monitor/nested, ex. via `Hyprland` aninhado, antes do daily).
3. Abrir como feature/PR upstream (`layerrule = glass`).
O daemon layer-shell (A) fica como fallback caso o upstream resista à feature.

## IMPLEMENTAÇÃO — pontos exatos no source (build local em ~/programing/hyprland-glass, tag v0.55.4)
Sistema de shaders passa por glslang; shaders `#version 300 es` com `#include`.
- **Enum shader**: `src/render/ShaderLoader.hpp` — add `SH_FRAG_GLASS` antes de `SH_FRAG_LAST`.
- **Registro filename**: `src/render/OpenGL.cpp:881` array `FRAG_SHADERS` (ordem casa o enum) — add `"glass.frag"`.
- **Shader novo**: `src/render/shaders/glsl/glass.frag` (modelo: `inner_glow.frag`; sampler: `uniform sampler2D tex;` como `surface.frag`; varying `v_texcoord` do `tex300.vert`; saída com `#if USE_MIRROR`). Reusar `rounding.glsl` (SDF pronto) — mas o gnome-glass tem SDF+superelipse próprios.
- **Acesso no render**: `useShader(getShaderVariant(SH_FRAG_GLASS, feats))` + setUniform + bind textura + draw quad.
- **Ponto de injeção**: `src/render/OpenGL.cpp` `renderTextureWithBlurInternal`, ramo `!*PBLEND` (~L2008): `renderTextureInternal(data.blurredBG, box, {...})` desenha o fundo borrado chapado. Quando glass: desenhar `data.blurredBG` pelo glass shader, usando `box` (geometria p/ SDF) e `primarySurfaceUVTopLeft/BottomRight` (mapeia box->textura monitor-size). `blurredBG` já é a textura do fundo (xray=wallpaper).
- **Render data**: `src/render/OpenGL.hpp:159` `STextureRenderData` — add `bool glass=false;` (+params ou ler de config).
- **Trigger layer**: `src/render/Renderer.cpp:941` `renderdata.blur = shouldBlur(pLayer);` — add `renderdata.glass = <layer tem regra glass>`.
- **Layerrule glass** (fase 2): enum `LAYER_RULE_EFFECT_GLASS` em `src/desktop/rule/layerRule/LayerRuleEffectContainer.hpp`; desc `{"glass",...bool, LE::LAYER_RULE_EFFECT_GLASS}` em `LuaBindingsConfigRules.cpp` (~L178, cuidar do static_assert de contagem); membro `m_glass` + `case` em `LayerRuleApplicator.cpp` (add tb no `forward_as_tuple` L34) e `.hpp`; `LayerRule.cpp::parseEffect` tipo bool.

### Plano faseado (de-risk)
1. Baseline build + rodar nested (confirmar loop de iteração). [em andamento]
2. PoC shader plumbing: `SH_FRAG_GLASS` + glass.frag TRIVIAL (ex: tint/offset fixo visível),
   gate por config bool global `decoration:blur:glass` lido em renderTextureWithBlurInternal.
   Prova: compila no glslang, bind funciona, uniforms fluem, muda na tela.
3. Portar matemática real (superelipse SDF, refract IOR, chroma) de gnome-glass.frag.
   Cuidar: gnome usa `texture2D`/GLSL1 -> converter p/ `texture()`/300es.
4. Trocar gate global pela layerrule `glass` (fase 2 acima).

## ✅ CAMINHO B IMPLEMENTADO E FUNCIONANDO (build em ~/programing/hyprland-glass)
Hyprland próprio (v0.55.4) com shader `glass` de refração real. Prova: A/B de
`decoration:blur:glass_displacement` 0 vs 400 dá mean-abs-diff 0.019 concentrado
SÓ nas ilhas, com aberração cromática visível. Valores elegantes: displacement 45,
ior 1.45, blur size 5/passes 2.

Arquivos alterados (todos no repo clonado):
- `src/render/ShaderLoader.hpp`: `SH_FRAG_GLASS` no enum.
- `src/render/OpenGL.cpp`: `"glass.frag"` em FRAG_SHADERS; método `renderGlass()`
  (modelado em renderInnerGlow + bind de textura); no ramo `!*PBLEND` de
  `renderTextureWithBlurInternal`, `if (*PGLASS) renderGlass(...) else` o draw chapado.
- `src/render/OpenGL.hpp`: declaração de `renderGlass(box, blurredBG, round, roundingPower, a)`.
- `src/config/values/ConfigValues.cpp`: `decoration:blur:{glass,glass_displacement,glass_ior}`.
- `src/render/shaders/glsl/glass.frag`: shader novo (SDF rounded-rect -> bisel
  superelipse -> normal por diferenças finitas -> refract(IOR) -> sample blurredBG
  deslocado + aberração cromática + rim/sheen). Reusa uniforms existentes por nome
  (tex, uvOffset/uvSize, fullSize, radius, range=displacement, shadowPower=ior).

### GOTCHAS que custaram tempo (não repetir)
1. **Shader não atualiza no rebuild:** os `.inc` são gerados por
   `scripts/generateShaderIncludes.sh` só no CONFIGURE do cmake (execute_process).
   Após editar qualquer `.glsl/.frag`: rodar o script À MÃO, depois `cmake --build`.
2. **`pkill -f 'build/Hyprland'` mata o próprio shell** (o cmdline do launcher casa
   o padrão) -> exit 144, nada sobe. Matar o nested por PID.
3. **Refração invisível se o bisel = raio do canto:** a normal fica ~plana no interior
   e o deslocamento some. FIX: bisel = fração do elemento (`min(halfSize)*0.95`),
   não `radius`. Só então a normal tilta numa banda larga e a lente aparece.
4. **CSS opaca da waybar tapa o vidro:** o surface do waybar é desenhado SOBRE o
   blurredBG(refratado). Pro vidro aparecer, ilha quase transparente (alpha ~0.10)
   + `layerrule ignore_alpha < alpha` senão o blur nem dispara.
5. **Blur forte apaga features:** com size 10/passes 5 as linhas viram gradiente liso
   e a refração fica sutil. Pra VER/testar: size ~3-5.

### Harness de teste nested (reprodutível)
`~/programing/hyprland-glass/`: `nested-test.conf` (roda `./build/Hyprland -c`),
`waybar-nested.jsonc` (waybar com `"exclusive": false` -> não reserva espaço),
`waybar-nested.css` (ilhas alpha 0.10), `grid.png` (grade 8-bit p/ ver a lente).
Textura sob a barra via `feh -F grid.png` + `xray=false` (hyprpaper 0.8.4 não casou
o monitor). Janela nested = class `aquamarine`; achar posição via `hyprctl clients`.
Tunar ao vivo: `HYPRLAND_INSTANCE_SIGNATURE=<sig do nested> hyprctl keyword decoration:blur:glass_displacement N`.

### FALTA (fase de produção, fazer com o caiop presente)
- `layerrule = glass` por-namespace (hoje é toggle global `decoration:blur:glass`
  que afeta TODA janela borrada). Pontos mapeados: enum LAYER_RULE_EFFECT_GLASS +
  desc lua + LayerRuleApplicator + flag glass no STextureRenderData vindo de
  Renderer.cpp:941. 
- Polir o shader (AO interno, focal highlight, screen-blend do gnome-glass.frag).
- Instalar no daily (`make install` ou empacotar) — decisão do caiop.

## Estado da investigação (parar aqui com segurança)
Extraído o shader de refração + mapeado o ponto de injeção exato no Hyprland.
O próximo passo (escrever glass.frag e compilar Hyprland, OU montar o daemon) é
commitment grande e mexe em compositor vivo — fazer COM o caiop presente, nunca
unattended. Retomar decidindo A vs. B (recomendação: B).
