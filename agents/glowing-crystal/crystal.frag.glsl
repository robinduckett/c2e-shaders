#version 450
// Canonical cross-platform CESHAD fragment (Vulkan GLSL). Cross-compiled to
// SPIR-V / MSL / HLSL. No custom screenUV/centerUV varyings — the screen UV is
// derived canonically from the pixel position (gl_FragCoord * m0.xy), so it only
// needs the host's standard varyings (colour@0, uv@1) + gl_FragCoord.
//
// Bindings map to: uniform -> buffer(0)/b0, spriteTex -> texture(0)/t0,
// sceneTex -> texture(1)/t1, samp -> sampler(0)/s0.
//
// Refractive glassy crystal: reads the scene behind it (sceneTex), refracts it
// per hexagonal facet, tints + BRIGHTENS it (a pulsing inner glow), and adds
// facet highlights + a bright rim. Scene-read so it visibly lightens the world
// textures behind it.

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

vec2 ceshadCenterUV(vec2 uv, vec2 screenUV) {
    vec2 dU = vec2(dFdx(uv.x), dFdy(uv.y));
    vec2 dS = vec2(dFdx(screenUV.x), dFdy(screenUV.y));
    vec2 grad = dS / dU;
    return screenUV + (vec2(0.5) - uv) * grad;
}

void main() {
    vec2 screenUV = gl_FragCoord.xy * u.m0.xy;             // canonical screen UV
    vec2 centerUV = ceshadCenterUV(vUv, screenUV);

    vec3 tint  = vec3(P(0) > 0.0 ? P(0) : 0.45,
                      P(1) > 0.0 ? P(1) : 0.80,
                      P(2) > 0.0 ? P(2) : 1.00);            // param0..2 colour
    float pulse  = (P(3) > 0.0) ? P(3) : 2.0;              // param3 pulse rate
    // param4: gem size in PIXELS. Expressed in pixels rather than sprite-UV so
    // the same value gives the same on-screen gem whatever frame the agent is
    // on — an agent that swaps to a smaller carry frame needs no restatement,
    // which is what lets the swap happen without a visible jump. u.m0.x = 1/texW.
    // 0 (default / param absent) means "fill the sprite frame" exactly as before.
    float sizePx = (P(4) > 0.0) ? P(4) : 0.0;
    float s      = (sizePx > 0.0) ? (sizePx * u.m0.x) : 1.0;
    float t = u.m3.x;

    vec2 uvS = (vUv - 0.5) / s + 0.5;                      // gem uv, scaled about the frame centre
    vec2 p = (uvS - 0.5) * 2.0;                            // [-1,1]
    vec2 ap = abs(p);
    float  hex = max(ap.x * 0.866 + ap.y * 0.5, ap.y);     // hexagonal distance

    vec3 sceneHere = texture(sampler2D(sceneTex, samp), screenUV).rgb;
    float  body = smoothstep(0.94, 0.86, hex);             // crystal shape
    if (body <= 0.0) { fragColor = vec4(sceneHere, 1.0); return; }

    // Per-facet refraction: 6 wedges, each offsets the scene sample outward.
    float ang   = atan(p.y, p.x);
    float facet = floor((ang + 3.14159265) / (3.14159265 / 3.0));
    vec2 fdir = vec2(cos(facet * 1.0472 + 0.5), sin(facet * 1.0472 + 0.5));
    float  d    = length(p);
    vec3 refr = texture(sampler2D(sceneTex, samp), screenUV + fdir * 0.025 * d).rgb;

    // Pulsing inner glow that BRIGHTENS + tints the refracted scene.
    float glow = 0.55 + 0.45 * sin(t * pulse);             // ~0.1 .. 1.0
    vec3 col = refr * (1.0 + glow * 0.9);                  // lighten the scene behind
    col = mix(col, col * tint + tint * 0.15, 0.55);        // glassy colour cast

    // Facet highlights + bright rim.
    float facetHi = 0.5 + 0.5 * sin(ang * 6.0 + t * 0.7);
    col += tint * facetHi * 0.25 * glow;
    col += tint * smoothstep(0.86, 0.94, hex) * 0.5;       // rim

    vec3 rgb = mix(sceneHere, col, body);
    fragColor = vec4(rgb, 1.0);
}
