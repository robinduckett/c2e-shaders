# CRT Overlay

A **CRT tube** over the whole view — barrel curvature, scanlines, a vignette and
RGB chromatic aberration, applied to the finished composite. A CESHAD
full‑screen post‑process.

- **Classifier:** `2 21 42006`
- **Sprite:** 16×16 placeholder, full‑screen (scene‑read)
- **Shader pack:** `crt.ceshad` (source: `crt.frag.glsl`; bleed and flags come from its `CESHAD_*` macros)

Full‑screen means the sprite geometry is ignored: the shader runs once over the
composited frame, reading it through `sceneBehind()` at `sceneUV()`. The carrier
is Floatable (`attr 32`, `flto 0 0`), so it screen‑locks to the camera, has no
world position and is never camera‑culled — the effect covers the view from
anywhere in the world.

## Parameters — `shdr "crt" { curvature scanline aberration lines }`

| # | Param | Default | Meaning |
|---|-------|---------|---------|
| 0 | curvature | 0.12 | barrel distortion; outside the curved tube is a black bezel |
| 1 | scanline | 0.30 | scanline darkening strength |
| 2 | aberration | 0.0016 | red/blue horizontal split, in uv |
| 3 | lines | 240 | sine half‑periods across the frame — 240 draws 120 dark bands |

Defaults above are the shader's own fallbacks. `install.cos` injects a slightly
stronger `{ 0.14 0.32 0.0018 220 }`.

Every param falls back to its default when ≤ 0, so zero is not directly
settable — pass a small epsilon (say `1e-4`) to mean "off".

## Use

Drop `CRTOverlay.agent` into your game's **My Agents** folder and inject it, or
send `install.cos` to the engine's CAOS port. Unlike the carryable effects there
is nothing to pick up: the agent appears screen‑locked and the whole view is
shaded immediately.

## Remove

Send `remove.cos` — it kills every `2 21 42006` agent.
