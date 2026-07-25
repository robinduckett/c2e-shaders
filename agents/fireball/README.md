# Fireball

<video src="https://github.com/user-attachments/assets/2e91fd11-42b4-4cc9-b650-ca499f8065c6" autoplay="autoplay" loop="loop" muted="muted" playsinline="playsinline" style="max-width: 730px;">
</video>

A procedural **licking flame** (iq simplex‑noise fbm) that casts a warm emissive glow onto the pixels around it. Scene‑read.

- **Classifier:** `2 21 42003`
- **Sprite:** 128×128 (+64 bleed), scene‑read
- **Shader pack:** `fireball.ceshad` (source: `fireball.frag.glsl`; bleed and flags come from its `CESHAD_*` macros)

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
dropped into the world at your cursor as an ordinary carryable agent — click it with the
Hand to pick it up, click again to put it down.

## Remove

Send `remove.cos` — it kills every `2 21 42003` agent.
