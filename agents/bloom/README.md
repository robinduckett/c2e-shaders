# Bloom

A **bright‑pass glow** over the whole view — the composite is thresholded on
luminance, the bright pixels are blurred with a weighted 9‑tap cross, and the
result is added back over the original. A CESHAD full‑screen post‑process.

- **Classifier:** `2 21 42007`
- **Sprite:** 16×16 placeholder, full‑screen (scene‑read)
- **Shader pack:** `bloom.ceshad` (source: `bloom.frag.glsl`; bleed and flags come from its `CESHAD_*` macros)

Full‑screen means the sprite geometry is ignored: the shader runs once over the
composited frame, reading it through `sceneBehind()` at `sceneUV()`. The carrier
is Floatable (`attr 32`, `flto 0 0`), so it screen‑locks to the camera, has no
world position and is never camera‑culled — the effect covers the view from
anywhere in the world.

## Parameters — `shdr "bloom" { threshold intensity radius }`

| # | Param | Default | Meaning |
|---|-------|---------|---------|
| 0 | threshold | 0.7 | bright‑pass luminance cutoff (Rec. 709 luma) |
| 1 | intensity | 1.2 | additive glow strength |
| 2 | radius | 2 | blur spread, in **composite texels** |

Defaults above are the shader's own fallbacks; `install.cos` injects exactly
those values.

The blur step is sized from `texelSize()`, which on a full‑screen pass is the
composite's texel — not the window's, which can be larger (iOS renders the
composite at output ÷ resolution factor). So the spread stays the same visual
size whatever the output resolution.

Every param falls back to its default when ≤ 0, so zero is not directly
settable — pass a small epsilon (say `1e-4`) to mean "off".

## Use

Drop `Bloom.agent` into your game's **My Agents** folder and inject it, or send
`install.cos` to the engine's CAOS port. Unlike the carryable effects there is
nothing to pick up: the agent appears screen‑locked and the whole view is shaded
immediately.

## Remove

Send `remove.cos` — it kills every `2 21 42007` agent.
