# Glowing Crystal

<video src="https://github.com/user-attachments/assets/85bcb7bb-3c6e-4094-bef8-c824185c5351" autoplay="autoplay" loop="loop" muted="muted" playsinline="playsinline" style="max-width: 730px;">
</video>

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
dropped into the world at your cursor as an ordinary carryable agent — click it with the
Hand to pick it up, click again to put it down.

## Remove

Send `remove.cos` — it kills every `2 21 42005` agent.
