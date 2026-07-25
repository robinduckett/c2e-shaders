# c2e-shaders

CESHAD shader packs for the Creatures 3 / Docking Station **Community Edition**
engine. Each **agent** applies a live shader to the game — five as pick‑up‑and‑drop
toys that shade the world beneath them, two as full‑screen post‑processes. The
packs are **cross‑platform** — each `.ceshad` carries the shader as GLSL, SPIR‑V,
MSL and HLSL (SM5.1), so it runs on the Metal, Vulkan and Direct3D CE backends.

## Gallery

| Magnifier | Fireball | Glowing Crystal |
|:---:|:---:|:---:|
| <video src="https://github.com/user-attachments/assets/884dc107-51e0-4c1a-8afd-bf2466645405" autoplay="autoplay" loop="loop" muted="muted" playsinline="playsinline" style="max-width: 730px;"></video> | <video src="https://github.com/user-attachments/assets/2e91fd11-42b4-4cc9-b650-ca499f8065c6" autoplay="autoplay" loop="loop" muted="muted" playsinline="playsinline" style="max-width: 730px;"></video> | <video src="https://github.com/user-attachments/assets/85bcb7bb-3c6e-4094-bef8-c824185c5351" autoplay="autoplay" loop="loop" muted="muted" playsinline="playsinline" style="max-width: 730px;"></video> |
| **Plasma Orb** | **Water Droplet** | |
| <video src="https://github.com/user-attachments/assets/391fa6af-d934-43ee-9c36-1f98b4edf623" autoplay="autoplay" loop="loop" muted="muted" playsinline="playsinline" style="max-width: 730px;"></video> | <video src="https://github.com/user-attachments/assets/769372c1-26b8-49ec-9f48-9b81601223af" autoplay="autoplay" loop="loop" muted="muted" playsinline="playsinline" style="max-width: 730px;"></video> | |

## Agents (pick‑up toys)

Each of these drops into the world at your cursor as an ordinary carryable agent —
click it with the Hand to pick it up, click again to put it down.

**Pick one up and it shrinks**; drop it in the world and it grows back. The shrink
is done by the shader (each effect takes its size in pixels, eased by the engine)
rather than by swapping sprites, so it closes smoothly. Dropped into the inventory
drawer it stays small — a vehicle only accepts an agent that fits its cabin.

| Agent | Effect |
|-------|--------|
| [Magnifier](agents/magnifier/) | a glass lens that magnifies + refracts the world |
| [Fireball](agents/fireball/) | a procedural flame that casts warm light on nearby pixels |
| [Glowing Crystal](agents/glowing-crystal/) | a refractive gem that brightens + pulses the scene behind it |
| [Plasma Orb](agents/plasma-orb/) | volumetric electric‑energy tendrils in a reflective sphere |
| [Water Droplet](agents/water-droplet/) | concentric ripples distorting the world beneath |

## Agents (full‑screen)

These two shade the whole view instead of a patch of world. The sprite geometry
is ignored: the shader runs once over the composited frame. The carrier is
Floatable, so it screen‑locks to the camera and the effect follows you anywhere.
There is nothing to pick up.

| Agent | Effect |
|-------|--------|
| [CRT Overlay](agents/crt-overlay/) | barrel curvature, scanlines, vignette and chromatic aberration |
| [Bloom](agents/bloom/) | bright‑pass, blur, and an additive glow over the frame |

## Installing an agent

Drop the agent's `.agent` file into your game's **My Agents** folder and inject it
from the in‑game Agent Injector (or send its `install.cos` to the running engine's
CAOS port). The `.agent` bundles the compiled `.ceshad` shader pack and a
placeholder sprite; the engine resolves the shader by name from the game Images tree.

## Building from source

Everything needed to turn a fragment shader into a redistributable `.agent`
lives in [`tools/`](tools/):

```sh
tools/build-agents.sh                                      # every effect → build/
tools/build-agents.sh --src agents/magnifier --out build   # just one
```

`glslc`, `spirv-cross` and `spirv-val` all have to be on `PATH` — there is no
Metal‑only fallback. See [tools/README.md](tools/README.md) for the
effect-directory layout, how to write a shader against the CESHAD interface, the
`CESHAD_*` macros, and the CAOS gotchas worth knowing before you write an install
script.

## What is a `.ceshad`?

A CESHAD pack is a portable shader container holding the same fragment shader in
every backend language — **GLSL**, **SPIR‑V**, **MSL**, and **HLSL SM5.1** — plus a
small META block describing the bleed margins and the **scene‑read** and
**full‑screen** flags.

Each effect here is a single `vec4 shade(vec4 texel, vec2 uv)` source. There is
no second, hand-written copy per backend: `tools/make-ceshad.py` compiles that
one source through [`tools/ceshad-prelude.glsl`](tools/ceshad-prelude.glsl) —
which supplies the varyings, uniform block, samplers, helper API and `main()` —
to SPIR‑V, cross‑compiles it to MSL and HLSL, and packs all four together, so one
`.ceshad` runs on the Metal, Vulkan and Direct3D CE backends and cannot have its
backends disagree.

The prelude is a decode of CE's own compiled output, recovered from the two
CE-authored reference packs. The shaders consume fragment inputs `locn0`–`locn3`,
a subset of the older, wider interface, so a pack built here runs both on
Community Edition and on engines that emit more than CE does.

## Licence

Original shader code released under **CC0 1.0** (public domain). Several effects
are ports of public‑domain Shadertoy techniques. `tools/ceshad-prelude.glsl` is a
decode of the CESHAD interface, written for interoperability; no third‑party pack
contents are redistributed here.
