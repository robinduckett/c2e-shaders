// Procedural flame — a port of the classic public-domain Shadertoy fire
// (iq-style simplex fbm shaped into a licking plume). Scene-read: a single flame
// sits over the scene beneath it and casts a warm emissive glow that BRIGHTENS
// the surrounding scene pixels, spilling out into the 64 px bleed margin.
//
//   param(0) = flame brightness                       (default 1.5)
//   param(1) = rise speed                             (default 1)
//   param(2) = unused
//   param(3) = emissive glow onto the scene           (default 0.9)
//   param(4) = flame size in sprite-PIXELS, 0 = fill the frame
#define CESHAD_SCENE
#define CESHAD_BLEED 64

// --- iq 2D simplex noise + fbm (smooth, no floor()-quantised blockiness) -----
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

// The flame body works in its own y-UP uv (y=0 base, y=1 tip) and calls that
// `uv`; GLSL treats a body-scope redeclaration of a parameter name as a
// redefinition, so the FRAME uv arrives here as `frameUV`. The parameter name is
// the only thing that moves — the plume below is the original, unchanged.
//
// `texel` is never read: the flame is procedural and its coverage comes from the
// frame uv, not from the sprite's alpha. Nothing in it depends on what the sprite
// texture holds, in the frame or in the bleed.
vec4 shade(vec4 texel, vec2 frameUV)
{
    float intensity = (param(0) > 0.0) ? param(0) : 1.5;
    float speed     = (param(1) > 0.0) ? param(1) : 1.0;
    float glowAmt   = (param(3) > 0.0) ? param(3) : 0.9;
    // param4: flame size in PIXELS. Expressed in pixels rather than sprite-UV so
    // the same value gives the same on-screen flame whatever frame the agent is
    // on — an agent that swaps to a smaller carry frame needs no restatement,
    // which is what lets the swap happen without a visible jump.
    // 0 (the default, i.e. param absent) means "fill the frame": scale stays 1.
    float sizePx   = (param(4) > 0.0) ? param(4) : 0.0;
    vec2  perPixel = texelSize() / (v_spriteRect.zw - v_spriteRect.xy);
    float s        = (sizePx > 0.0) ? (sizePx * perPixel.x) : 1.0;

    float t = shaderTime();
    vec2 screenUV = sceneUV();
    // Remap the sprite uv about the frame CENTRE so a smaller s draws a smaller
    // flame centred in the quad; s == 1 leaves the uv untouched.
    vec2 uvS = (frameUV - 0.5) / s + 0.5;
    vec2 uv = vec2(uvS.x, 1.0 - uvS.y);                 // y=0 base, y=1 tip

    // NB: NO floor()/mod() tiling from the original full-screen version — the
    // sprite's bleed pushes uv outside [0,1], and tiling there spawns extra
    // partial flames plus a uniform bright block. Exactly one flame lives at the
    // sprite centre and the bleed region stays empty.
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

    // Confine the flame BODY to the sprite proper. Evaluated in the bleed margin
    // (uv outside [0,1]) the plume math leaves its domain — c goes strongly
    // negative and c1 = n*c*(negative) flips positive, saturating col to a white
    // rectangle. Fade coverage to 0 at the sprite edge so only the (decaying) halo
    // lives in the bleed; the glow still spills, the white block does not.
    vec2 edge = min(uvS, vec2(1.0) - uvS);
    float edgeMask = smoothstep(0.0, 0.04, min(edge.x, edge.y));
    a *= edgeMask;

    // Warm emissive halo: a soft radial field centred on the flame body, spilling
    // well beyond it into the bleed margin and flickered by the noise. It
    // BRIGHTENS the scene pixels it overlaps (multiplicative) plus a small
    // additive term so the fire also glows into darkness.
    vec2 g = vec2((uv.x - 0.5) * 1.25, uv.y - 0.35);
    float halo = exp(-4.5 * dot(g, g)) * (0.65 + 0.6 * n);
    halo = max(halo, a);

    col *= intensity;
    vec3 warm = vec3(1.0, 0.55, 0.22);
    vec3 sceneHere = sceneBehind(screenUV).rgb;
    vec3 lit = sceneHere
             + sceneHere * (halo * glowAmt * intensity) * warm
             + warm * (halo * glowAmt * intensity * 0.35);
    vec3 outc = mix(lit, col, a);
    return vec4(outc, 1.0);
}
