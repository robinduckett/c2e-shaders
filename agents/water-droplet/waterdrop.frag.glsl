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

void main() {
    float amp   = (P(0) > 0.0) ? P(0) : 0.02;   // param0: ripple amplitude (uv)
    float freq  = (P(1) > 0.0) ? P(1) : 40.0;   // param1: spatial frequency
    float speed = (P(2) > 0.0) ? P(2) : 3.0;    // param2: wave speed
    float t = u.m3.x;
    vec2 screenUV = gl_FragCoord.xy * u.m0.xy;              // canonical screen UV
    vec2 p = vUv - 0.5;
    float  d = length(p);
    float  mask = 1.0 - smoothstep(0.44, 0.5, d);           // circular bead
    vec3 sceneHere = texture(sampler2D(sceneTex, samp), screenUV).rgb;
    if (mask <= 0.0) { fragColor = vec4(sceneHere, 1.0); return; }
    vec2 dir = (d > 1e-4) ? p / d : vec2(0.0);
    float wave = sin(d * freq - t * speed) * (1.0 - d * 2.0); // decays to rim
    vec2 off = dir * wave * amp;
    vec3 refr = texture(sampler2D(sceneTex, samp), screenUV + off).rgb;
    float spec = pow(max(0.0, wave), 3.0) * 0.3;             // glint on wave crests
    vec3 rgb = mix(sceneHere, refr + spec, mask);
    fragColor = vec4(rgb, 1.0);
}
