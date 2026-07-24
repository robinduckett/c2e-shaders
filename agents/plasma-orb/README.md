# Plasma Orb

<video src="https://github.com/user-attachments/assets/391fa6af-d934-43ee-9c36-1f98b4edf623" autoplay="autoplay" loop="loop" muted="muted" playsinline="playsinline" style="max-width: 730px;">
</video>

A **volumetric energy‑tendril plasma** — ray‑marched electric filaments inside a reflective sphere that swirls the background (a port of a public‑domain Star‑Nest‑style Shadertoy). Scene‑read, composited additively.

- **Classifier:** `2 21 42004`
- **Sprite:** 160×160 (+24 bleed), scene‑read
- **Shader pack:** `plasma.ceshad` (source: `plasma.frag.msl`, meta: `meta.json`)

## Parameters — `shdr "plasma" { intensity }`

| # | Param | Default | Meaning |
|---|-------|---------|---------|
| 0 | intensity | 1.0 | plasma brightness |

## Use

Drop `Plasma Orb.agent` (spaces removed) into your game's **My Agents** folder and
inject it, or send `install.cos` to the engine's CAOS port. On injection it is
dropped into the world at your cursor as an ordinary carryable agent — click it with the
Hand to pick it up, click again to put it down.

## Remove

Send `remove.cos` — it kills every `2 21 42004` agent.
