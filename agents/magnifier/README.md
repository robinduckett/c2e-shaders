# Magnifier

<video src="https://github.com/user-attachments/assets/884dc107-51e0-4c1a-8afd-bf2466645405" autoplay="autoplay" loop="loop" muted="muted" playsinline="playsinline" style="max-width: 730px;">
</video>

A glass lens that **magnifies and refracts** the world beneath it, with a chromatic‑dispersion rim. A CESHAD scene‑read shader agent.

- **Classifier:** `2 21 42001`
- **Sprite:** 256×256, scene‑read
- **Shader pack:** `magnifier.ceshad` (source: `magnifier.frag.glsl`; bleed and flags come from its `CESHAD_*` macros)

## Parameters — `shdr "magnifier" { zoom radiusPx refraction dispersion }`

| # | Param | Default | Meaning |
|---|-------|---------|---------|
| 0 | zoom | 2.0 | magnification (>1 magnifies) |
| 1 | radius | 108 | lens radius in **pixels** (same on-screen size on either sprite frame) |
| 2 | refraction | 0.01 | rim refraction (uv) |
| 3 | dispersion | 0.004 | chromatic dispersion |

## Use

Drop `Magnifier.agent` (spaces removed) into your game's **My Agents** folder and
inject it, or send `install.cos` to the engine's CAOS port. On injection it is
dropped into the world at your cursor as an ordinary carryable agent — click it with the
Hand to pick it up, click again to put it down.

## Remove

Send `remove.cos` — it kills every `2 21 42001` agent.
