// Bloom — a full-screen post-process: bright-pass the composite, blur the bright
// pixels with a weighted 9-tap cross, and add the glow back over the original.
//
//   param(0) = bright-pass luminance cutoff     (default 0.7)
//   param(1) = additive glow strength           (default 1.2)
//   param(2) = blur spread, in composite texels (default 2)
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
    float threshold = (param(0) > 0.0) ? param(0) : 0.7;
    float intensity = (param(1) > 0.0) ? param(1) : 1.2;
    float radius    = (param(2) > 0.0) ? param(2) : 2.0;

    vec2 suv        = sceneUV();
    vec3 sceneColor = sceneBehind(suv).rgb;

    // A real texel of the thing we are sampling: on a full-screen pass the host
    // fills texelSize() from the COMPOSITE (scene-texture) size, which is the
    // grid sceneUV()/sceneBehind() work in — not the window's, which can be
    // larger (iOS renders the composite at output/ResolutionFactor()).
    vec2 stepUV = texelSize() * radius;

    vec2 offs[9] = vec2[9](
        vec2( 0.0,  0.0),
        vec2( 1.0,  0.0), vec2(-1.0,  0.0),
        vec2( 0.0,  1.0), vec2( 0.0, -1.0),
        vec2( 1.0,  1.0), vec2(-1.0,  1.0),
        vec2( 1.0, -1.0), vec2(-1.0, -1.0));
    float weight[9] = float[9](4.0, 2.0, 2.0, 2.0, 2.0, 1.0, 1.0, 1.0, 1.0);

    vec3  bright = vec3(0.0);
    float wsum   = 0.0;
    for (int i = 0; i < 9; ++i) {
        vec3  s = sceneBehind(suv + offs[i] * stepUV).rgb;
        float l = dot(s, vec3(0.2126, 0.7152, 0.0722));
        bright += s * max(l - threshold, 0.0) / max(1.0 - threshold, 1e-4) * weight[i];
        wsum   += weight[i];
    }
    bright /= wsum;

    return vec4(sceneColor + bright * intensity, 1.0);
}
