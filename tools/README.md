# Build tools

Everything needed to turn a fragment shader into a redistributable Docking
Station `.agent`.

```
tools/build-agents.sh        one command: sprite + pack + agent for every effect
├── make-sprite.py           the .s32 surrogate sprite (poses + thumbnail)
├── make-ceshad.py           the .ceshad shader-pack container
└── make-agent.py            the PRAY .agent bundle
```

## Quick start

```sh
tools/build-agents.sh                              # every effect → build/
tools/build-agents.sh --src agents/magnifier --out build   # just one
tools/build-agents.sh --help
```

Drop the resulting `<Name>.agent` into your game's **My Agents** folder and
inject it from the in-game injector.

## An effect directory

`build-agents.sh` treats any directory holding a `meta.json` as an effect:

| file | required | purpose |
|---|---|---|
| `meta.json` | ✅ | name, description, sprite name, sprite size, bleed, `sceneRead` |
| `<sprite>.frag.msl` | ✅ | the Metal fragment shader |
| `<sprite>.frag.glsl` | — | canonical Vulkan GLSL (see *cross-platform* below) |
| `install.cos` | ✅ | CAOS injected when the agent is installed |
| `remove.cos` | — | the PRAY **Remove script**, run to uninstall |
| `thumb.png` | — | injector / Library thumbnail |

```json
{
  "name": "Magnifier",
  "desc": "CESHAD magnifier - magnifies and refracts the world through a glass lens.",
  "sprite": "magnifier",
  "spriteW": 256, "spriteH": 256,
  "bleed": [0, 0, 0, 0],
  "sceneRead": 1
}
```

`sceneRead: 1` means the shader samples the composited frame behind it (the
engine binds it as `texture(1)`). `fullScreen: 1` marks a whole-frame
post-process. `bleed` widens the drawn quad so an effect can spill past its
sprite — a glow needs it, a lens does not.

## Cross-platform packs

With a `<sprite>.frag.glsl` present and `glslc` + `spirv-cross` on `PATH`, the
pack carries **GLSL + SPIR-V + MSL + HLSL SM5.1** instead of Metal alone, so it
runs on the Vulkan and Direct3D CE backends too:

```sh
brew install shaderc spirv-cross        # glslc, spirv-cross
```

Without them the build still succeeds and packs MSL only — you just get an
Apple-only agent. The HLSL registers are rewritten to the fixed CE slots
(uniform `b0`, sprite `t0`, scene `t1`, sampler `s0`), because spirv-cross
numbers resources from its own binding order.

## Sprite poses

Shader agents use a generated surrogate sprite: opaque black, so the agent is
mouse-pickable across its whole frame and has a visible fallback if the shader
fails to load. The attached shader draws over it, so the black is never seen.

`make-sprite.py` emits up to three frames:

| pose | what |
|---|---|
| 0 | full size, from `spriteW`/`spriteH` |
| 1 | **carry** frame, long edge capped at 96px, aspect preserved |
| 2 | the `thumb.png` thumbnail, if present |

Pose 1 exists because a vehicle only accepts an agent that fits its cabin — C3's
inventory drawer cabins are roughly 105×110 to 121×144, so a 256px agent can
never go in. The shipped agents swap to pose 1 when picked up.

## Running the tools directly

```sh
python3 tools/make-sprite.py --w 256 --h 256 --carry-w 96 --carry-h 96 \
        --thumb agents/magnifier/thumb.png --out build/magnifier.s32

python3 tools/make-ceshad.py --msl agents/magnifier/magnifier.frag.msl \
        --bleed 0,0,0,0 --scene-read 1 --out build/magnifier.ceshad

python3 tools/make-agent.py --name Magnifier --desc "…" \
        --install agents/magnifier/install.cos --remove agents/magnifier/remove.cos \
        --sprite build/magnifier.s32 --ceshad build/magnifier.ceshad \
        --thumb-frame 2 --out build/Magnifier.agent
```

## Gotchas worth knowing

- **CAOS comments must be on their own line.** A trailing `* comment` after a
  command silently aborts the rest of the script — no error, the agent just
  half-installs.
- **`FREL` has no rvalue form.** `doif frel eq pntr` is a parse error; track
  state in an `ov` variable instead.
- **A click on a carryable agent is a pick-up**, so `activate 1` never arrives.
  Use the pickup (4) / drop (5) scripts as your trigger.
- **Ship a `remove.cos`.** Without the PRAY *Remove script* tag, removing the
  agent leaves everything it injected alive in the world.
