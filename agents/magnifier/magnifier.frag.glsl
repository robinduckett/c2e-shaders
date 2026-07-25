// Magnifier — a glass lens that magnifies, refracts, and disperses the world behind it.
//
//   param(0) = magnification (>1 magnifies)          (default 2)
//   param(1) = lens radius in sprite-PIXELS          (default 108)
//   param(2) = rim refraction, in scene-uv           (default 0)
//   param(3) = chromatic dispersion                  (default 0)
//
// Radius is in pixels, not frame-uv, so the same value means the same on-screen lens
// on either pose — which is what lets the carry-frame swap happen with no shader change.
#define CESHAD_SCENE
#define CESHAD_BLEED 0

vec4 shade(vec4 texel, vec2 uv)
{
    float zoom       = (param(0) > 0.0) ? param(0) : 2.0;
    float radiusPx   = (param(1) > 0.0) ? param(1) : 108.0;
    float refractAmt = param(2);
    float dispersion = param(3);

    // One sprite-pixel in frame-uv units (the idiom CE's own glow.ceshad uses).
    vec2  perPixel = texelSize() / (v_spriteRect.zw - v_spriteRect.xy);
    float radius   = radiusPx * perPixel.x;

    vec2  p = uv - 0.5;                       // centred lens space
    float d = length(p);

    float edge = 0.02;
    float mask = 1.0 - smoothstep(radius, radius + edge, d);
    vec2  s    = sceneUV();

    // Scene-uv per unit frame-uv, measured. Both uv and gl_FragCoord are affine in
    // window space, so differencing a linear varying is exact — given that frame-uv
    // is axis-aligned with window space, which every C2E sprite blit is: g takes only
    // the DIAGONAL of the Jacobian (d s.x/d x_win over d uv.x/d x_win), so a rotated
    // quad would need the full 2x2. The measured gradient carries the y-axis sign
    // automatically. There is no canonical way to ask the host for the scene size or
    // the camera zoom, and inventing one is the bug this file exists to fix.
    //
    // The gradient block sits ABOVE the early return below on purpose: GLSL leaves a
    // derivative taken in non-uniform control flow undefined, and the compiled MSL
    // keeps that branch rather than flattening it.
    float dux = dFdx(uv.x), dvy = dFdy(uv.y);
    vec2  ds  = vec2(dFdx(s.x), dFdy(s.y));

    // An exactly-degenerate quad — a divide-by-zero guard and nothing more. dux runs
    // at 1/(srcW * zoom): 0.0039 for a 256-px frame, still ~2.5e-4 stretched across a
    // 4000-px window. A genuinely sub-pixel quad gives dux > 1, not a small dux, so
    // this never fires on small sprites. Guarded rather than selected after the fact,
    // so 0/0 is never evaluated at all.
    vec2 g = vec2(0.0);
    if (abs(dux) > 1e-8 && abs(dvy) > 1e-8)
        g = vec2(ds.x / dux, ds.y / dvy);

    vec3 sceneHere = sceneBehind(s).rgb;
    if (mask <= 0.0)
        return vec4(sceneHere, 1.0);

    // Magnify about the frame centre. Substituting C = s + (0.5 - uv) * g into
    // C + (s - C)/zoom cancels C entirely — only the offset toward it survives,
    // which is also better conditioned than building a large absolute coordinate
    // and subtracting it back out. A degenerate quad leaves g zero, so base collapses
    // to s and the lens just does not magnify.
    vec2 base = s + (vec2(0.5) - uv) * g * (1.0 - 1.0 / zoom);

    vec2  dir   = (d > 1e-4) ? p / d : vec2(0.0);
    float curve = smoothstep(0.0, radius, d);         // 0 centre -> 1 rim
    vec2  refr  = dir * refractAmt * curve;
    vec2  disp  = dir * dispersion * curve;

    vec3 col;
    col.r = sceneBehind(base + refr + disp).r;
    col.g = sceneBehind(base + refr).g;
    col.b = sceneBehind(base + refr - disp).b;

    col += smoothstep(radius - 0.06, radius, d) * 0.25;   // fresnel-ish rim

    return vec4(mix(sceneHere, col, mask), 1.0);
}
