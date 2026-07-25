#version 450
// CESHAD interface v1 authoring prelude.
//
// Recovered from the two CE-authored reference packs (glow.ceshad, sunbeams.ceshad):
// each carries both its shade() source and CE's compiled MSL, so every helper below
// is a decode of real CE output, not a guess. See
// docs/superpowers/specs/2026-07-25-ceshad-canonical-shader-abi-design.md.
//
// An author writes ONE function:  vec4 shade(vec4 texel, vec2 uv)
//   texel = this fragment's sprite colour, or vec4(0) outside the frame (the bleed)
//   uv    = frame-local uv, 0..1 across the sprite frame, outside it in the bleed
//
// Interface v1 is the helper set below. It deliberately provides no helper for the
// scene size or the camera scale — derive what you need with dFdx/dFdy. Those values
// ARE reachable (u_frag.camera.xy, textureSize(ceshad_sceneTex, 0)), because u_frag
// and the samplers must be declared here to be usable at all; nothing enforces the
// boundary. But reaching past the helpers is outside v1 and is not guaranteed stable
// across engines or versions — CE's block layout is the only thing pinning it.

layout(location = 0) in vec4       v_colour;
layout(location = 1) in vec2       v_uv;           // sprite-texture (atlas) uv
layout(location = 2) flat in uvec2 v_tint;         // .x flat-colour mode, .y tint row
layout(location = 3) flat in vec4  v_spriteRect;   // frame rect in atlas uv
layout(location = 0) out vec4      ceshad_fragColor;

layout(set = 0, binding = 0, std140) uniform CeshadUniform {
    vec4 texelSize;    // 1/texW, 1/texH, texW, texH  — the SPRITE texture (on a
                       // full-screen pass, the COMPOSITE; see texelSize() below)
    vec4 tintA[32];
    vec4 tintB[32];
    vec4 config;       // .x time, .z pixel-snap, .w supersample
    vec4 camera;       // scaleX, scaleY, offX, offY
    vec4 world;        // origin
    vec4 params[16];   // 64 floats: param(0)..param(63) — CE's ceiling. Do NOT grow this
                       // to match our host's larger m6[64] (RenderGPU.mm): what must agree
                       // is the OFFSETS of m0..m5, which are identical either way. An
                       // oversized host BINDING is always legal; an oversized shader
                       // DECLARATION against CE's smaller binding is not.
} u_frag;

// CESHAD_HAVE_SCENE is set by the PACKER, not by the author. The author's own
// #define CESHAD_SCENE is metadata the packer scans for META; guarding on it here
// too would be a macro redefinition (glslc: "Macro redefined; different
// substitutions") the moment the packer also passes it on the command line.
layout(set = 0, binding = 1) uniform sampler2D ceshad_spriteTex;
#ifdef CESHAD_HAVE_SCENE
layout(set = 0, binding = 2) uniform sampler2D ceshad_sceneTex;
#endif

float param(int i) { return u_frag.params[i / 4][i % 4]; }
float shaderTime() { return u_frag.config.x; }
vec2  texelSize()  { return u_frag.texelSize.xy; }   // RECIPROCAL (1/texW, 1/texH); the
                                                     // sprite texture's pixel dimensions
                                                     // are u_frag.texelSize.zw, unwrapped
// On a FULL-SCREEN pass there is no sprite — texture(0) is a 1x1 dummy — and the
// host instead fills texelSize() from the composite (scene-texture) size, i.e.
// one texel of the grid sceneUV()/sceneBehind() address. That is the size a
// full-screen blur/offset wants; note it is NOT the window size where the two
// differ (iOS composites at output/ResolutionFactor()).

vec2 spriteUV() {
    vec2 span = v_spriteRect.zw - v_spriteRect.xy;
    return vec2(span.x != 0.0 ? (v_uv.x - v_spriteRect.x) / span.x : 0.0,
                span.y != 0.0 ? (v_uv.y - v_spriteRect.y) / span.y : 0.0);
}

// Internal: sample the sprite at ATLAS uv. config.z selects CE's texel-snapping
// filter, which needs explicit gradients because the snapped coordinate is
// discontinuous. Not part of the author-facing API.
vec4 ceshad_sampleAtlas(vec2 atlasUV) {
    if (u_frag.config.z != 0.0) {
        vec2 fw   = clamp(fwidth(atlasUV) * u_frag.texelSize.zw, vec2(1e-5), vec2(1.0));
        vec2 t    = atlasUV * u_frag.texelSize.zw - fw * 0.5;
        vec2 snap = (floor(t) + vec2(0.5) + smoothstep(vec2(1.0) - fw, vec2(1.0), fract(t)))
                    * u_frag.texelSize.xy;
        return textureGrad(ceshad_spriteTex, snap, dFdx(atlasUV), dFdy(atlasUV));
    }
    return texture(ceshad_spriteTex, atlasUV);
}

vec4 sampleSprite(vec2 uv) {
    return ceshad_sampleAtlas(mix(v_spriteRect.xy, v_spriteRect.zw, clamp(uv, 0.0, 1.0)));
}

vec2 worldPos() {
    return (gl_FragCoord.xy - u_frag.camera.zw) / u_frag.camera.xy + u_frag.world.xy;
}

#ifdef CESHAD_HAVE_SCENE
vec2 sceneUV() {
    return clamp(gl_FragCoord.xy / vec2(textureSize(ceshad_sceneTex, 0)), 0.0, 1.0);
}
vec4 sceneBehind(vec2 uv) {
    return texture(ceshad_sceneTex, clamp(uv, 0.0, 1.0));
}
#endif

// Internal: the C2E tint-table rotate/swap. Dead on this host (tint rows are zeroed
// and v_tint is (0,0)), but a pack we build must behave correctly on CE, where it is
// live. Decoded from glow's compiled MSL; 0.0078125 == 1/128. The row index is used
// unclamped against a 32-entry table, exactly as CE's MSL does — the HOST guarantees
// v_tint.y < 32; do not add a clamp here or we diverge from the reference.
vec3 ceshad_applyTint(vec3 rgb) {
    uint r = v_tint.y;
    vec3 p = clamp(floor(rgb * 255.0 + vec3(0.5)) + u_frag.tintA[r].xyz, vec3(0.0), vec3(255.0));
    vec3 q;
    if (u_frag.tintA[r].w > 0.5)
        q = vec3(floor((u_frag.tintB[r].x * p.z + u_frag.tintB[r].y * p.x) * 0.0078125),
                 floor((u_frag.tintB[r].x * p.x + u_frag.tintB[r].y * p.y) * 0.0078125),
                 floor((u_frag.tintB[r].x * p.y + u_frag.tintB[r].y * p.z) * 0.0078125));
    else
        q = vec3(floor((u_frag.tintB[r].x * p.y + u_frag.tintB[r].y * p.x) * 0.0078125),
                 floor((u_frag.tintB[r].x * p.z + u_frag.tintB[r].y * p.y) * 0.0078125),
                 floor((u_frag.tintB[r].x * p.x + u_frag.tintB[r].y * p.z) * 0.0078125));
    return clamp(vec3(floor((u_frag.tintB[r].z * q.z + u_frag.tintB[r].w * q.x) * 0.0078125),
                      q.y,
                      floor((u_frag.tintB[r].z * q.x + u_frag.tintB[r].w * q.z) * 0.0078125)),
                 vec3(0.0), vec3(255.0)) * (1.0 / 255.0);
}

vec4 shade(vec4 texel, vec2 uv);

void main() {
    vec2 uv = spriteUV();
    bool inFrame = all(greaterThanEqual(uv, vec2(0.0))) && all(lessThanEqual(uv, vec2(1.0)));
    // The inFrame ternary puts ceshad_sampleAtlas's fwidth/dFdx/dFdy in non-uniform
    // control flow, which the GLSL spec calls undefined. This is inherited faithfully:
    // CE's glow MSL has the same snap branch inside its own inFrame block, and matching
    // CE's output is the point. Do NOT "fix" it — that would change what packs render.
    vec4 c = shade(inFrame ? ceshad_sampleAtlas(v_uv) : vec4(0.0), uv);
    if (v_tint.y != 0u) c.rgb = ceshad_applyTint(c.rgb);
    ceshad_fragColor = (v_tint.x == 1u) ? vec4(v_colour.rgb, c.a * v_colour.a) : c * v_colour;
}
