# Build tools

Everything needed to turn a fragment shader into a redistributable Docking
Station `.agent`.

```
tools/build-agents.sh        one command: sprite + pack + agent for every effect
├── make-sprite.py           the .s32 surrogate sprite (poses + thumbnail)
├── make-ceshad.py           the .ceshad shader-pack container
│   └── ceshad-prelude.glsl  the CESHAD interface every shader compiles against
├── make-agent.py            the PRAY .agent bundle
└── unpack-ceshad.py         read a .ceshad back out again
```

## Prerequisites

Three tools, and they come from three different formulas:

| tool | formula | what it does |
|---|---|---|
| `glslc` | **shaderc** | GLSL → SPIR-V |
| `spirv-cross` | **spirv-cross** | SPIR-V → MSL, HLSL SM5.1 |
| `spirv-val` | **spirv-tools** | validates the SPIR-V before it is packed |

```sh
brew install shaderc spirv-cross spirv-tools
```

All three are **required**. There is no MSL-only fallback: an earlier version of
this toolchain quietly packed Metal alone when the cross-compilers were missing,
which is precisely how the GLSL half of every pack rotted without anyone
noticing. A build that cannot produce all four backends from the one source now
fails.

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
| `meta.json` | ✅ | name, description, sprite name, sprite size |
| `<sprite>.frag.glsl` | ✅ | the shader — one `shade()` function, plus its `CESHAD_*` macros |
| `install.cos` | ✅ | CAOS injected when the agent is installed |
| `remove.cos` | — | the PRAY **Remove script**, run to uninstall |
| `thumb.png` | — | injector / Library thumbnail |

```json
{
  "name": "Magnifier",
  "desc": "CESHAD magnifier - magnifies and refracts the world through a glass lens.",
  "sprite": "magnifier",
  "spriteW": 256, "spriteH": 256
}
```

`meta.json` describes the *agent*. Everything about the *shader* — bleed,
scene-read, full-screen — is declared in the shader source, so the two can never
disagree about the code they describe.

## Writing a shader

An effect is one function:

```glsl
vec4 shade(vec4 texel, vec2 uv)
```

- `texel` — this fragment's sprite colour, or `vec4(0)` outside the frame (in the bleed)
- `uv` — frame-local uv, `0..1` across the sprite frame, outside that range in the bleed

No `#version`, no `layout`, no uniform block, no `main()`. `ceshad-prelude.glsl`
supplies all of them, and `make-ceshad.py` prepends it before compiling. The
prelude is a decode of CE's own compiled output, recovered from the two
CE-authored reference packs, so what an author writes against is CE's real
interface rather than a reconstruction of it.

### The helper API

| helper | what |
|---|---|
| `float param(int i)` | parameter `i` from the agent's `shdr` call (0..63) |
| `float shaderTime()` | seconds, for animation |
| `vec2 texelSize()` | **reciprocal** texel of the sprite texture (`1/texW, 1/texH`) |
| `vec2 spriteUV()` | frame-local uv — the same value handed to `shade()` as `uv` |
| `vec4 sampleSprite(vec2 uv)` | sample the sprite frame at frame-local uv |
| `vec2 worldPos()` | this fragment's position in world coordinates |
| `vec2 sceneUV()` | *(scene-read only)* this fragment's uv in the composited frame |
| `vec4 sceneBehind(vec2 uv)` | *(scene-read only)* sample the composite behind the agent |

On a full-screen pass there is no sprite: `texelSize()` is filled from the
**composite** instead, which is the grid `sceneUV()` and `sceneBehind()` address.
That is the size a full-screen blur wants, and it is not always the window size
(iOS composites at output ÷ resolution factor).

To work in sprite **pixels** rather than frame-uv, use the idiom CE's own
`glow.ceshad` uses:

```glsl
vec2 perPixel = texelSize() / (v_spriteRect.zw - v_spriteRect.xy);
```

Pixel-sized parameters are what let the shipped agents shrink when picked up:
the same value means the same on-screen effect on either sprite pose, so the
frame swap needs no shader change.

### There is no screen UV and no frame centre

Deliberately. The interface hands you no whole-screen coordinate and no
"centre of my frame" varying, because a host varying is exactly what broke these
packs before: they were authored against a `screenUV` at `locn4` and a
`centerUV` at `locn5` that only one engine emitted, and Metal rejects a fragment
shader whose inputs are not a subset of the vertex shader's outputs — so on
Community Edition every one of them failed pipeline creation and rendered as a
bare black square.

Both values are derivable. Differencing a linear varying with `dFdx`/`dFdy` is
exact, because `uv` and `gl_FragCoord` are both affine in window space.
[`agents/magnifier/magnifier.frag.glsl`](../agents/magnifier/magnifier.frag.glsl)
is the worked example: it measures scene-uv per unit frame-uv and magnifies
about the frame centre without ever naming it.

Sample the composite through `sceneBehind(sceneUV())` and you have the screen
you wanted, in a way that runs everywhere.

## META: the `CESHAD_*` macros

META is authored in the shader, as `#define`s near the top:

| macro | effect |
|---|---|
| `CESHAD_BLEED <n>` | widen the drawn quad by *n* pixels on every side |
| `CESHAD_BLEED_LEFT`/`_TOP`/`_RIGHT`/`_BOTTOM` `<n>` | per-side override of `CESHAD_BLEED` |
| `CESHAD_SCENE` | the shader reads the composited frame behind it; enables `sceneUV()`/`sceneBehind()` |
| `CESHAD_FULLSCREEN` | whole-frame post-process; implies `CESHAD_SCENE` |

Bleed is what lets an effect spill past its sprite — a glow needs it, a lens does
not. Fireball declares 64, the crystal and the plasma orb 24.

Two rules you will otherwise hit blind:

- **`CESHAD_` is a reserved prefix.** Every `#define` starting with it is parsed
  by the packer, whether or not it means anything to it, so your own
  `#define CESHAD_PI 3.5` aborts the build. Prefix private constants with
  anything else.
- **Values must be bare decimal integers.** `#define CESHAD_BLEED (10)`, `0x10`,
  and a line continuation all abort. Trailing comments are fine.

This is not a typo guard: `#define CESHAD_BLED 10` parses cleanly and is then
silently ignored, because a well-formed macro the packer has no use for is not an
error. What the rules buy is detection of a malformed **value**. A scanner that
skipped what it could not parse would pack the wrong META in silence, and the
symptom of that is an effect clipped at its frame edge with no error anywhere.

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

Full-screen effects skip all of this: their sprite is a 16×16 placeholder that is
never drawn.

## Running the tools directly

```sh
python3 tools/make-sprite.py --w 256 --h 256 --carry-w 96 --carry-h 96 \
        --thumb agents/magnifier/thumb.png --out build/magnifier.s32

python3 tools/make-ceshad.py --shade agents/magnifier/magnifier.frag.glsl \
        --out build/magnifier.ceshad

python3 tools/make-agent.py --name Magnifier --desc "…" \
        --install agents/magnifier/install.cos --remove agents/magnifier/remove.cos \
        --sprite build/magnifier.s32 --ceshad build/magnifier.ceshad \
        --thumb-frame 2 --out build/Magnifier.agent
```

`--shade` derives META and builds every backend section from the one source, so
it takes no `--bleed`/`--scene-read`/`--glsl`/`--spv`/`--hl51`; passing one is an
error rather than a value silently ignored.

To look inside a pack:

```sh
python3 tools/unpack-ceshad.py agents/magnifier/magnifier.ceshad          # section table
python3 tools/unpack-ceshad.py agents/magnifier/magnifier.ceshad --meta   # bleed L T R B, flags
python3 tools/unpack-ceshad.py agents/magnifier/magnifier.ceshad --out /tmp/x
```

`make-ceshad.py --selftest-macros` and `unpack-ceshad.py --selftest` check the
macro scanner, the HLSL register rewrite, and the container round-trip.

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
- **HLSL registers are rewritten** to the fixed CE slots (uniform `b0`, sprite
  `t0`/`s0`, scene `t1`/`s1`), because spirv-cross numbers resources from its own
  binding order. `make-ceshad.py` does this; it is not something to do by hand.
