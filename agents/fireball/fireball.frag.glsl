#version 450
// Canonical cross-platform CESHAD fragment (Vulkan GLSL). Cross-compiled to
// SPIR-V / MSL / HLSL. No custom screenUV/centerUV varyings — the screen UV is
// derived canonically from the pixel position (gl_FragCoord * m0.xy), so it only
// needs the host's standard varyings (colour@0, uv@1) + gl_FragCoord.
//
// Bindings map to: uniform -> buffer(0)/b0, spriteTex -> texture(0)/t0,
// sceneTex -> texture(1)/t1, samp -> sampler(0)/s0.

layout(set = 0, binding = 0, std140) uniform CeshadUniform {
    vec4 m0; vec4 m1[32]; vec4 m2[32]; vec4 m3; vec4 m4; vec4 m5; vec4 m6[64];
} u;
layout(set = 0, binding = 1) uniform texture2D spriteTex;
layout(set = 0, binding = 2) uniform texture2D sceneTex;
layout(set = 0, binding = 3) uniform sampler   samp;

layout(location = 0) in vec4 vColour;
layout(location = 1) in vec2 vUv;
layout(location = 0) out vec4 fragColor;

float P(int i) { return u.m6[i / 4][i % 4]; }

vec2 hash(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}
float snoise(vec2 p) {
    const float K1 = 0.366025404;
    const float K2 = 0.211324865;
    vec2 i = floor(p + (p.x + p.y) * K1);
    vec2 a = p - i + (i.x + i.y) * K2;
    vec2 o = (a.x > a.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
    vec2 b = a - o + K2;
    vec2 c = a - 1.0 + 2.0 * K2;
    vec3 h = max(0.5 - vec3(dot(a, a), dot(b, b), dot(c, c)), 0.0);
    vec3 n = h * h * h * h * vec3(dot(a, hash(i + 0.0)), dot(b, hash(i + o)), dot(c, hash(i + 1.0)));
    return dot(n, vec3(70.0));
}
float fbm(vec2 uv) {
    float f;
    mat2 m = mat2(1.6, 1.2, -1.2, 1.6);
    f  = 0.5000 * snoise(uv); uv = m * uv;
    f += 0.2500 * snoise(uv); uv = m * uv;
    f += 0.1250 * snoise(uv); uv = m * uv;
    f += 0.0625 * snoise(uv); uv = m * uv;
    f = 0.5 + 0.5 * f;
    return f;
}

void main() {
    float intensity = (P(0) > 0.0) ? P(0) : 1.5;
    float speed     = (P(1) > 0.0) ? P(1) : 1.0;
    float glowAmt   = (P(3) > 0.0) ? P(3) : 0.9;

    float t = u.m3.x;
    vec2 screenUV = gl_FragCoord.xy * u.m0.xy;          // canonical screen UV
    vec2 inUv = vUv;
    vec2 uv = vec2(inUv.x, 1.0 - inUv.y);               // y=0 base, y=1 tip

    vec2 q = uv;
    q.y *= 2.0;
    float T3 = 3.0 * t * speed;
    q.x = (q.x - 0.5) * 2.0;
    q.y -= 0.25;
    float n  = fbm(q - vec2(0.0, T3));
    float c  = 1.0 - 16.0 * pow(max(0.0, length(q * vec2(1.8 + q.y * 1.5, 0.75)) - n * max(0.0, q.y + 0.25)), 1.2);
    float c1 = clamp(n * c * (1.5 - pow(1.25 * uv.y, 4.0)), 0.0, 1.0);
    vec3 col = vec3(1.5 * c1, 1.5 * c1 * c1 * c1, c1 * c1 * c1 * c1 * c1 * c1);
    float a  = clamp(c * (1.0 - pow(uv.y, 3.0)), 0.0, 1.0);

    vec2 edge = min(inUv, vec2(1.0) - inUv);
    float edgeMask = smoothstep(0.0, 0.04, min(edge.x, edge.y));
    a *= edgeMask;

    vec2 g = vec2((uv.x - 0.5) * 1.25, uv.y - 0.35);
    float halo = exp(-4.5 * dot(g, g)) * (0.65 + 0.6 * n);
    halo = max(halo, a);

    col *= intensity;
    vec3 warm = vec3(1.0, 0.55, 0.22);
    vec3 sceneHere = texture(sampler2D(sceneTex, samp), screenUV).rgb;
    vec3 lit = sceneHere
             + sceneHere * (halo * glowAmt * intensity) * warm
             + warm * (halo * glowAmt * intensity * 0.35);
    vec3 outc = mix(lit, col, a);
    fragColor = vec4(outc, 1.0);
}
