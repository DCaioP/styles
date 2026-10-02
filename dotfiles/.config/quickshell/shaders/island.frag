#version 440
// Forma da Dynamic Island: duas caixas arredondadas (SDF) unidas por um
// smooth-min. Quando a bolha secundária sai de dentro da principal, o smin
// estica um "pescoço" líquido entre elas até romper — o efeito de gota.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;   // px
    vec4 rectA;      // x, y, w, h (px)
    vec4 rectB;
    float radiusA;
    float radiusB;
    float goo;       // raio da fusão (px)
    vec4 fillColor;
    vec4 rimColor;
};

float sdRoundBox(vec2 p, vec4 r, float rad) {
    vec2 h = r.zw * 0.5;
    rad = min(rad, min(h.x, h.y));
    vec2 q = abs(p - (r.xy + h)) - h + rad;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - rad;
}

float smin(float a, float b, float k) {
    float h = max(k - abs(a - b), 0.0) / k;
    return min(a, b) - h * h * k * 0.25;
}

void main() {
    vec2 p = qt_TexCoord0 * itemSize;
    float d = sdRoundBox(p, rectA, radiusA);
    if (rectB.z > 0.5 && rectB.w > 0.5)
        d = smin(d, sdRoundBox(p, rectB, radiusB), goo);

    // cobertura exata de 1 px centrada na borda (box filter). Um ramp mais
    // largo vira um contorno cinza-claro visível sobre fundo branco.
    float shape = clamp(0.5 - d / max(fwidth(d), 1e-4), 0.0, 1.0);

    // aro opcional (rimColor.a = 0 desliga): só por dentro, nunca clareia a borda externa
    float rim = (1.0 - smoothstep(1.0, 2.5, -d)) * step(0.0, -d);
    vec3 rgb = mix(fillColor.rgb, rimColor.rgb, rim * rimColor.a);
    fragColor = vec4(rgb * fillColor.a, fillColor.a) * shape * qt_Opacity;
}
