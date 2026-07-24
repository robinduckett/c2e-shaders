# Water Droplet

<video src="https://github.com/user-attachments/assets/769372c1-26b8-49ec-9f48-9b81601223af" autoplay="autoplay" loop="loop" muted="muted" playsinline="playsinline" style="max-width: 730px;">
</video>

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
dropped into the world at your cursor as an ordinary carryable agent — click it with the
Hand to pick it up, click again to put it down.

## Remove

Send `remove.cos` — it kills every `2 21 42002` agent.
