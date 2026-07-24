# Water Droplet

<video src="https://github.com/robinduckett/c2e-shaders/raw/main/agents/water-droplet/preview.mp4" controls muted loop width="480"></video>

A **water droplet** that sends concentric ripples across the world beneath it, refracting the scene. Scene‑read.

- **Classifier:** `2 21 42002`
- **Sprite:** 256×256, scene‑read
- **Shader pack:** `waterdrop.ceshad` (source: `waterdrop.frag.msl`, meta: `meta.json`)

## Parameters — `shdr "waterdrop" { amplitude frequency speed }`

| # | Param | Default | Meaning |
|---|-------|---------|---------|
| 0 | amplitude | 0.08 | ripple strength (uv) |
| 1 | frequency | 25 | spatial ripple frequency |
| 2 | speed | 4 | wave speed |

## Use

Drop `Water Droplet.agent` (spaces removed) into your game's **My Agents** folder and
inject it, or send `install.cos` to the engine's CAOS port. On injection it is
**held by the hand** — click to drop it into the world, click again to pick it up.

## Remove

Send `remove.cos` — it kills every `2 21 42002` agent.
