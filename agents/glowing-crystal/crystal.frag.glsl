// Glowing crystal — a refractive glassy gem. Reads the scene behind it, refracts it
// per hexagonal facet, tints + BRIGHTENS it (a pulsing inner glow), and adds facet
// highlights + a bright rim. Scene-read, so it visibly lightens the world textures
// behind it.
//
//   param(0) = tint red                              (default 0.45)
//   param(1) = tint green                            (default 0.80)
//   param(2) = tint blue                             (default 1.00)
//   param(3) = pulse rate                            (default 2)
//   param(4) = gem size in sprite-PIXELS, 0 = fill the frame
#define CESHAD_SCENE
#define CESHAD_BLEED 24

vec4 shade(vec4 texel, vec2 uv)
{
    vec2 screenUV = sceneUV();

    vec3 tint  = vec3(param(0) > 0.0 ? param(0) : 0.45,
                      param(1) > 0.0 ? param(1) : 0.80,
                      param(2) > 0.0 ? param(2) : 1.00);
    float pulse  = (param(3) > 0.0) ? param(3) : 2.0;
    // param(4): gem size in PIXELS. Expressed in pixels rather than sprite-UV so
    // the same value gives the same on-screen gem whatever frame the agent is
    // on — an agent that swaps to a smaller carry frame needs no restatement,
    // which is what lets the swap happen without a visible jump.
    // 0 (default / param absent) means "fill the sprite frame".
    float sizePx   = (param(4) > 0.0) ? param(4) : 0.0;
    // One sprite-pixel in frame-uv units (the idiom CE's own glow.ceshad uses).
    vec2  perPixel = texelSize() / (v_spriteRect.zw - v_spriteRect.xy);
    float s        = (sizePx > 0.0) ? (sizePx * perPixel.x) : 1.0;
    float t        = shaderTime();

    vec2 uvS = (uv - 0.5) / s + 0.5;                       // gem uv, scaled about the frame centre
    vec2 p = (uvS - 0.5) * 2.0;                            // [-1,1]
    vec2 ap = abs(p);
    float  hex = max(ap.x * 0.866 + ap.y * 0.5, ap.y);     // hexagonal distance

    vec3 sceneHere = sceneBehind(screenUV).rgb;
    float  body = smoothstep(0.94, 0.86, hex);             // crystal shape
    if (body <= 0.0)
        return vec4(sceneHere, 1.0);

    // Per-facet refraction: 6 wedges, each offsets the scene sample outward.
    float ang   = atan(p.y, p.x);
    float facet = floor((ang + 3.14159265) / (3.14159265 / 3.0));
    vec2 fdir = vec2(cos(facet * 1.0472 + 0.5), sin(facet * 1.0472 + 0.5));
    float  d    = length(p);
    vec3 refr = sceneBehind(screenUV + fdir * 0.025 * d).rgb;

    // Pulsing inner glow that BRIGHTENS + tints the refracted scene.
    float glow = 0.55 + 0.45 * sin(t * pulse);             // ~0.1 .. 1.0
    vec3 col = refr * (1.0 + glow * 0.9);                  // lighten the scene behind
    col = mix(col, col * tint + tint * 0.15, 0.55);        // glassy colour cast

    // Facet highlights + bright rim.
    float facetHi = 0.5 + 0.5 * sin(ang * 6.0 + t * 0.7);
    col += tint * facetHi * 0.25 * glow;
    col += tint * smoothstep(0.86, 0.94, hex) * 0.5;       // rim

    vec3 rgb = mix(sceneHere, col, body);
    return vec4(rgb, 1.0);
}
