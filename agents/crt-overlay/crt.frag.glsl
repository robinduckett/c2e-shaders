// CRT — a full-screen post-process: barrel curvature, scanlines, vignette,
// and RGB chromatic aberration over the finished composite.
//
//   param(0) = barrel curvature                 (default 0.12)
//   param(1) = scanline strength                (default 0.30)
//   param(2) = chromatic aberration, in uv      (default 0.0016)
//   param(3) = scanline count                   (default 240 -> 120 bands)
//
// param(3) counts sine half-periods, not visible bands: the term below has period
// 2/lines across the frame, so 240 draws 120 dark bands.
//
// Every param falls back to its default when <= 0, so zero is not directly
// settable — pass a small epsilon (say 1e-4) to mean "off". That is inherited
// verbatim from the hand-written MSL this replaces and is how all seven example
// effects behave; it is left alone deliberately so tuned packs keep their look.
#define CESHAD_FULLSCREEN
#define CESHAD_BLEED 0

// `texel` and `uv` go unread. This is a full-screen pass: texture(0) is a 1x1
// dummy and the carrier's sprite frame is irrelevant, so screen position comes
// from sceneUV() and colour from sceneBehind().
vec4 shade(vec4 texel, vec2 uv)
{
    float curvature = (param(0) > 0.0) ? param(0) : 0.12;
    float scan      = (param(1) > 0.0) ? param(1) : 0.30;
    float aberr     = (param(2) > 0.0) ? param(2) : 0.0016;
    float lines     = (param(3) > 0.0) ? param(3) : 240.0;

    vec2  c      = sceneUV() - 0.5;
    float r2     = dot(c, c);
    vec2  warped = 0.5 + c * (1.0 + curvature * r2);

    // Outside the curved tube -> black bezel.
    if (warped.x < 0.0 || warped.x > 1.0 || warped.y < 0.0 || warped.y > 1.0)
        return vec4(0.0, 0.0, 0.0, 1.0);

    vec3 col;
    col.r = sceneBehind(warped + vec2(aberr, 0.0)).r;
    col.g = sceneBehind(warped).g;
    col.b = sceneBehind(warped - vec2(aberr, 0.0)).b;

    float sl = 0.5 + 0.5 * sin(warped.y * lines * 3.14159265);
    col *= (1.0 - scan) + scan * sl;
    col *= smoothstep(0.75, 0.35, r2);

    return vec4(col, 1.0);
}
