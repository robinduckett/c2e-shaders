# Glowing Crystal

<video src="https://github.com/robinduckett/c2e-shaders/raw/main/agents/glowing-crystal/preview.mp4" controls muted loop width="480"></video>

A **refractive glassy gem** that bends the scene behind it and brightens + pulses it with a coloured inner glow. Scene‑read.

- **Classifier:** `2 21 42005`
- **Sprite:** 128×160 (+24 bleed), scene‑read
- **Shader pack:** `crystal.ceshad` (source: `crystal.frag.msl`, meta: `meta.json`)

## Parameters — `shdr "crystal" { tintR tintG tintB pulse }`

| # | Param | Default | Meaning |
|---|-------|---------|---------|
| 0 | tint R | 0.45 | crystal tint, red |
| 1 | tint G | 0.8 | crystal tint, green |
| 2 | tint B | 1.0 | crystal tint, blue |
| 3 | pulse | 2.0 | glow pulse rate |

## Use

Drop `Glowing Crystal.agent` (spaces removed) into your game's **My Agents** folder and
inject it, or send `install.cos` to the engine's CAOS port. On injection it is
**held by the hand** — click to drop it into the world, click again to pick it up.

## Remove

Send `remove.cos` — it kills every `2 21 42005` agent.
