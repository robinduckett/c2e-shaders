// Water droplet — a procedural radial ripple that refracts the world beneath it.
//
//   param(0) = ripple amplitude, in scene-uv    (default 0.02)
//   param(1) = spatial frequency                (default 40)
//   param(2) = wave speed                       (default 3)
//   param(3) = droplet size in sprite-PIXELS, 0 = fill the frame
#define CESHAD_SCENE
#define CESHAD_BLEED 0

vec4 shade(vec4 texel, vec2 uv)
{
    float amp    = (param(0) > 0.0) ? param(0) : 0.02;
    float freq   = (param(1) > 0.0) ? param(1) : 40.0;
    float speed  = (param(2) > 0.0) ? param(2) : 3.0;
    float sizePx = (param(3) > 0.0) ? param(3) : 0.0;

    // One sprite-pixel in frame-uv units (the idiom CE's own glow.ceshad uses).
    vec2  perPixel = texelSize() / (v_spriteRect.zw - v_spriteRect.xy);
    float s        = (sizePx > 0.0) ? (sizePx * perPixel.x) : 1.0;
    float t        = shaderTime();

    vec2  screenUV = sceneUV();
    vec2  uvS = (uv - 0.5) / s + 0.5;
    vec2  p   = uvS - 0.5;
    float d   = length(p);
    float mask = 1.0 - smoothstep(0.44, 0.5, d);

    vec3 sceneHere = sceneBehind(screenUV).rgb;
    if (mask <= 0.0)
        return vec4(sceneHere, 1.0);

    vec2  dir  = (d > 1e-4) ? p / d : vec2(0.0);
    float wave = sin(d * freq - t * speed) * (1.0 - d * 2.0);
    vec2  off  = dir * wave * amp;
    vec3  refr = sceneBehind(screenUV + off).rgb;
    float spec = pow(max(0.0, wave), 3.0) * 0.3;

    return vec4(mix(sceneHere, refr + spec, mask), 1.0);
}
