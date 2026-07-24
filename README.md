# c2e-shaders

CESHAD shader packs for the Creatures 3 / Docking Station **Community Edition**
engine. Each **agent** is a pick‑up‑and‑drop toy that applies a live shader to the
world beneath it. The packs are **cross‑platform** — each `.ceshad` carries the
shader as GLSL, SPIR‑V, MSL and HLSL (SM5.1), so it runs on the Metal, Vulkan and
Direct3D CE backends.

## Gallery

| Magnifier | Fireball | Glowing Crystal |
|:---:|:---:|:---:|
| <video src="https://github.com/user-attachments/assets/884dc107-51e0-4c1a-8afd-bf2466645405" autoplay="autoplay" loop="loop" muted="muted" playsinline="playsinline" style="max-width: 730px;"></video> | <video src="https://github.com/user-attachments/assets/2e91fd11-42b4-4cc9-b650-ca499f8065c6" autoplay="autoplay" loop="loop" muted="muted" playsinline="playsinline" style="max-width: 730px;"></video> | <video src="https://github.com/user-attachments/assets/85bcb7bb-3c6e-4094-bef8-c824185c5351" autoplay="autoplay" loop="loop" muted="muted" playsinline="playsinline" style="max-width: 730px;"></video> |
| **Plasma Orb** | **Water Droplet** | |
| <video src="https://github.com/user-attachments/assets/391fa6af-d934-43ee-9c36-1f98b4edf623" autoplay="autoplay" loop="loop" muted="muted" playsinline="playsinline" style="max-width: 730px;"></video> | <video src="https://github.com/user-attachments/assets/769372c1-26b8-49ec-9f48-9b81601223af" autoplay="autoplay" loop="loop" muted="muted" playsinline="playsinline" style="max-width: 730px;"></video> | |

## Agents (pick‑up toys)

Every agent is **held by the hand on injection** — it floats on the cursor so it
lands in your hand. **Click** it to drop it into the world; click again to pick
it back up. Once dropped it is a normal carryable agent you can drag with the hand.

| Agent | Effect |
|-------|--------|
| [Magnifier](agents/magnifier/) | a glass lens that magnifies + refracts the world |
| [Fireball](agents/fireball/) | a procedural flame that casts warm light on nearby pixels |
| [Glowing Crystal](agents/glowing-crystal/) | a refractive gem that brightens + pulses the scene behind it |
| [Plasma Orb](agents/plasma-orb/) | volumetric electric‑energy tendrils in a reflective sphere |
| [Water Droplet](agents/water-droplet/) | concentric ripples distorting the world beneath |

## Installing an agent

Drop the agent's `.agent` file into your game's **My Agents** folder and inject it
from the in‑game Agent Injector (or send its `install.cos` to the running engine's
CAOS port). The `.agent` bundles the compiled `.ceshad` shader pack and a
placeholder sprite; the engine resolves the shader by name from the game Images tree.

## What is a `.ceshad`?

A CESHAD pack is a portable shader container holding the same fragment shader in
every backend language — **GLSL**, **SPIR‑V**, **MSL**, and **HLSL SM5.1** — plus a
small META block describing bleed margins and the **scene‑read** flag (the shader
samples the composited frame behind it). Each agent folder ships the canonical
`*.frag.glsl` source and the reference `*.frag.msl`; the packer
(`tools/make-ceshad.py`) cross‑compiles GLSL → SPIR‑V → MSL/HLSL and packs them
together, so one `.ceshad` runs on the Metal, Vulkan and Direct3D CE backends.

## Licence

Original shader code released under **CC0 1.0** (public domain). Several effects
are ports of public‑domain Shadertoy techniques.
