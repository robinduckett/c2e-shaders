#!/usr/bin/env bash
#
# build-agents.sh — build CESHAD shader agents from source.
#
# For each effect directory found under SRC this produces, in OUT:
#   <sprite>.s32      surrogate sprite (+ carry frame, + thumbnail frame)
#   <sprite>.ceshad   shader pack — MSL, plus GLSL/SPIR-V/HLSL when the
#                     cross-compile toolchain is installed
#   <Name>.agent      the PRAY agent you drop into My Agents
#
# An effect directory contains:
#   meta.json          required — name, desc, sprite, spriteW/H, bleed, sceneRead
#   <sprite>.frag.msl  required — the Metal fragment shader
#   <sprite>.frag.glsl optional — canonical Vulkan GLSL. When present, and glslc
#                      + spirv-cross are on PATH, real GLSL/SPV/HL51 sections are
#                      packed too, so the agent also runs on the Vulkan and
#                      Direct3D CE backends
#   install.cos        required — injected when the agent is installed
#                      (<sprite>.cos is also accepted)
#   remove.cos         optional — becomes the PRAY "Remove script", which the
#                      injector runs to uninstall. Without it, removing the agent
#                      leaves everything it injected alive in the world
#   thumb.png          optional — injector / Library thumbnail
#
# Usage:
#   tools/build-agents.sh                            # SRC=agents/  OUT=build/
#   tools/build-agents.sh --src src --out out
#   tools/build-agents.sh --src agents/magnifier --out build   # a single effect
#
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
src="$root/agents"
out="$root/build"

while [ $# -gt 0 ]; do
  case "$1" in
    --src) src="$2"; shift 2;;
    --out) out="$2"; shift 2;;
    -h|--help) sed -n '2,29p' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
    *) echo "build-agents.sh: unknown argument $1" >&2; exit 2;;
  esac
done
mkdir -p "$out"

meta_get() {   # file key default
  python3 -c "import json,sys;print(json.load(open(sys.argv[1])).get(sys.argv[2], sys.argv[3]))" "$1" "$2" "$3"
}

# A directory is an effect if it holds a meta.json; passing one directly builds
# just that effect.
dirs=()
if [ -f "$src/meta.json" ]; then
  dirs=("$src")
else
  for d in "$src"/*/; do [ -f "$d/meta.json" ] && dirs+=("${d%/}"); done
fi
[ ${#dirs[@]} -gt 0 ] || { echo "build-agents.sh: no effect (meta.json) under $src" >&2; exit 1; }

for dir in "${dirs[@]}"; do
  meta="$dir/meta.json"
  name=$(meta_get "$meta" name "")
  desc=$(meta_get "$meta" desc "")
  sprite=$(meta_get "$meta" sprite "")
  w=$(meta_get "$meta" spriteW 0)
  h=$(meta_get "$meta" spriteH 0)
  sr=$(meta_get "$meta" sceneRead 0)
  fs=$(meta_get "$meta" fullScreen 0)
  bleed=$(python3 -c "import json,sys;print(','.join(map(str,json.load(open(sys.argv[1])).get('bleed',[0,0,0,0]))))" "$meta")

  msl="$dir/$sprite.frag.msl"
  [ -f "$msl" ] || { echo "$name: missing $(basename "$msl")" >&2; exit 1; }
  install="$dir/install.cos"
  [ -f "$install" ] || install="$dir/$sprite.cos"
  [ -f "$install" ] || { echo "$name: no install.cos" >&2; exit 1; }

  # Carry frame: the smaller pose an agent swaps to so it fits a vehicle cabin
  # (the inventory drawer rejects anything wider or taller than the cabin).
  # Capped at 96px on the long edge, aspect preserved.
  cw="$w"; ch="$h"
  if [ "$w" -gt 96 ] || [ "$h" -gt 96 ]; then
    if [ "$w" -ge "$h" ]; then cw=96; ch=$(( h * 96 / w )); else ch=96; cw=$(( w * 96 / h )); fi
  fi

  thumbargs=(); thumbframe=-1
  if [ -f "$dir/thumb.png" ]; then thumbargs=(--thumb "$dir/thumb.png"); thumbframe=2; fi
  python3 "$here/make-sprite.py" --w "$w" --h "$h" --carry-w "$cw" --carry-h "$ch" \
    "${thumbargs[@]}" --out "$out/$sprite.s32"

  # Cross-platform sections, when the canonical GLSL and the toolchain are both
  # present: glslc -> SPIR-V, spirv-cross -> HLSL SM5.1. spirv-cross numbers the
  # resources from its own binding order, so the registers are rewritten to the
  # fixed CE slots (uniform b0, sprite t0, scene t1, sampler s0).
  glsl="$dir/$sprite.frag.glsl"
  ceshadargs=()
  if [ -f "$glsl" ] && command -v glslc >/dev/null && command -v spirv-cross >/dev/null; then
    glslc -fshader-stage=frag "$glsl" -o "$out/$sprite.spv"
    spirv-cross --hlsl --shader-model 51 "$out/$sprite.spv" \
      | sed -E -e 's#register\(t1, space0\)#register(t0, space0)#' \
               -e 's#register\(t2, space0\)#register(t1, space0)#' \
               -e 's#register\(s3, space0\)#register(s0, space0)#' > "$out/$sprite.hlsl"
    ceshadargs=(--glsl "$glsl" --spv "$out/$sprite.spv" --hl51 "$out/$sprite.hlsl")
  fi
  python3 "$here/make-ceshad.py" --msl "$msl" --out "$out/$sprite.ceshad" \
    --bleed "$bleed" --scene-read "$sr" --full-screen "$fs" "${ceshadargs[@]}"

  rmargs=(); [ -f "$dir/remove.cos" ] && rmargs=(--remove "$dir/remove.cos")
  python3 "$here/make-agent.py" --name "$name" --desc "$desc" --install "$install" \
    "${rmargs[@]}" --thumb-frame "$thumbframe" \
    --sprite "$out/$sprite.s32" --ceshad "$out/$sprite.ceshad" --out "$out/$name.agent"
  echo "built $out/$name.agent"
done
