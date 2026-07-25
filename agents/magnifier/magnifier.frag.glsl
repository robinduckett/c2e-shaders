#version 450
// Cross-platform CESHAD fragment (Vulkan GLSL). Cross-compiled to SPIR-V / MSL /
// HLSL. The screen UV is derived canonically from the pixel position
// (gl_FragCoord * m0.xy); the lens needs the sprite-frame centre in screen UV,
// which the host vertex supplies as the scene-read centreUV varying (location 5).
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
layout(location = 5) in vec2 vCenterUV;   // sprite-frame centre in screen UV (host-provided)
layout(location = 0) out vec4 fragColor;

float P(int i) { return u.m6[i / 4][i % 4]; }

void main() {
    vec2 screenUV = gl_FragCoord.xy * u.m0.xy;
    vec2 centerUV = vCenterUV;

    float zoom       = (P(0) > 0.0) ? P(0) : 2.0;   // param0: magnification (>1 magnifies; sensible 2x default so an empty param vector doesn't collapse to a minified smear)
    // param1: lens radius in PIXELS (see the MSL twin) — u.m0.x = 1/texW.
    float radiusPx   = (P(1) > 0.0) ? P(1) : 108.0;
    float radius     = radiusPx * u.m0.x;
    float refractAmt = P(2);                         // param2: rim refraction (uv units)
    float dispersion = P(3);                         // param3: chromatic dispersion

    vec2 p = vUv - 0.5;                               // centered lens space [-0.5, 0.5]
    float  d = length(p);

    float edge = 0.02;
    float mask = 1.0 - smoothstep(radius, radius + edge, d);
    vec3 sceneHere = texture(sampler2D(sceneTex, samp), screenUV).rgb;
    if (mask <= 0.0) {
        fragColor = vec4(sceneHere, 1.0);
        return;
    }

    vec2 dir = (d > 1e-4) ? p / d : vec2(0.0);
    float  curve = smoothstep(0.0, radius, d);       // 0 centre -> 1 rim
    vec2 base = centerUV + (screenUV - centerUV) / zoom;  // magnify about centre
    vec2 refr = dir * refractAmt * curve;
    vec2 disp = dir * dispersion * curve;

    vec3 col;
    col.r = texture(sampler2D(sceneTex, samp), base + refr + disp).r;
    col.g = texture(sampler2D(sceneTex, samp), base + refr).g;
    col.b = texture(sampler2D(sceneTex, samp), base + refr - disp).b;

    float rim = smoothstep(radius - 0.06, radius, d); // fresnel-ish rim highlight
    col += rim * 0.25;

    vec3 rgb = mix(sceneHere, col, mask);
    fragColor = vec4(rgb, 1.0);
}
