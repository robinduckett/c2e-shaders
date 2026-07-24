# c2e-shaders

CESHAD shader packs for the Creatures 3 / Docking Station **Community Edition**
engine (the SDL3‑GPU / Metal renderer). Each **agent** is a pick‑up‑and‑drop toy
that applies a live shader to the world beneath it; the **full‑screen** packs are
whole‑frame post‑processes.

## Gallery

| Magnifier | Fireball | Glowing Crystal |
|:---:|:---:|:---:|
| <video src="https://github.com/robinduckett/c2e-shaders/raw/main/agents/magnifier/preview.mp4" muted loop controls width="240"></video> | <video src="https://github.com/robinduckett/c2e-shaders/raw/main/agents/fireball/preview.mp4" muted loop controls width="240"></video> | <video src="https://github.com/robinduckett/c2e-shaders/raw/main/agents/glowing-crystal/preview.mp4" muted loop controls width="240"></video> |
| **Plasma Orb** | **Water Droplet** | |
| <video src="https://github.com/robinduckett/c2e-shaders/raw/main/agents/plasma-orb/preview.mp4" muted loop controls width="240"></video> | <video src="https://github.com/robinduckett/c2e-shaders/raw/main/agents/water-droplet/preview.mp4" muted loop controls width="240"></video> | |

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

## Full‑screen post‑process (source only)

Whole‑frame effects, shipped as **shader source only** (no packaged agent). A pack
is full‑screen when its CESHAD META `flags` **bit 1** is set; apply it as a
post‑process through your engine's rendering settings.

| Pack | Effect |
|------|--------|
| [Bloom](full-screen/bloom/) | bright‑pass + blur + additive glow |
| [CRT](full-screen/crt/) | barrel curvature + scanlines + chromatic aberration |

## Installing an agent

Drop the agent's `.agent` file into your game's **My Agents** folder and inject it
from the in‑game Agent Injector (or send its `install.cos` to the running engine's
CAOS port). The `.agent` bundles the compiled `.ceshad` shader pack and a
placeholder sprite; the engine resolves the shader by name from the game Images tree.

## What is a `.ceshad`?

A CESHAD pack is a portable shader container: a cross‑compiled fragment shader
(MSL here, `*.frag.msl`) plus a small META block (`meta.json`) describing bleed
margins and flags — **scene‑read** (the shader samples the composited frame behind
it) and **full‑screen** (applied over the whole frame). Each folder holds the
shader source and meta so you can rebuild or adapt it.

## Licence

Original shader code released under **CC0 1.0** (public domain). Several effects
are ports of public‑domain Shadertoy techniques.
