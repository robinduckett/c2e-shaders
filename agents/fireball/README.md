# Fireball

<video src="https://github.com/robinduckett/c2e-shaders/raw/main/agents/fireball/preview.mp4" controls muted loop width="480"></video>

A procedural **licking flame** (iq simplex‑noise fbm) that casts a warm emissive glow onto the pixels around it. Scene‑read.

- **Classifier:** `2 21 42003`
- **Sprite:** 128×128 (+64 bleed), scene‑read
- **Shader pack:** `fireball.ceshad` (source: `fireball.frag.msl`, meta: `meta.json`)

## Parameters — `shdr "fireball" { intensity speed - glow }`

| # | Param | Default | Meaning |
|---|-------|---------|---------|
| 0 | intensity | 1.6 | flame brightness |
| 1 | speed | 1.0 | rise speed |
| 2 | — | — | reserved |
| 3 | glow | 1.2 | warm light cast onto surrounding pixels |

## Use

Drop `Fireball.agent` (spaces removed) into your game's **My Agents** folder and
inject it, or send `install.cos` to the engine's CAOS port. On injection it is
**held by the hand** — click to drop it into the world, click again to pick it up.

## Remove

Send `remove.cos` — it kills every `2 21 42003` agent.
