#!/usr/bin/env bash
#
# build-agents.sh — build CESHAD shader agents from source.
#
# For each effect directory found under SRC this produces, in OUT:
#   <sprite>.s16      surrogate sprite (+ carry frame, + thumbnail frame)
#   <sprite>.ceshad   shader pack — GLSL + SPIR-V + MSL + HLSL SM5.1 + META
#   <Name>.agent      the PRAY agent you drop into My Agents
#
# An effect directory contains:
#   meta.json           required — name, desc, sprite, spriteW/H
#   <sprite>.frag.glsl  required — the canonical shade() source. META (bleed,
#                       scene-read, full-screen) is read from its CESHAD_* macros,
#                       not from meta.json
#   install.cos         required — injected when the agent is installed
#                       (<sprite>.cos is also accepted)
#   remove.cos          optional — becomes the PRAY "Remove script", which the
#                       injector runs to uninstall. Without it, removing the agent
#                       leaves everything it injected alive in the world
#   thumb.png           optional — injector / Library thumbnail
#
# Needs glslc (shaderc), spirv-cross (spirv-cross) and spirv-val (spirv-tools)
# on PATH. There is no MSL-only fallback: a pack that is not cross-compiled from
# the one canonical source is a pack whose backends can silently disagree.
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

  glsl="$dir/$sprite.frag.glsl"
  [ -f "$glsl" ] || { echo "$name: missing $(basename "$glsl")" >&2; exit 1; }
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
    "${thumbargs[@]}" --out "$out/$sprite.s16"

  # One canonical shade() source per effect: the packer prepends the prelude,
  # compiles with glslc, cross-compiles with spirv-cross to MSL and HLSL SM5.1
  # (normalising the registers to CE's fixed slots), and derives META from the
  # CESHAD_* macros in the source.
  python3 "$here/make-ceshad.py" --shade "$glsl" --out "$out/$sprite.ceshad"

  rmargs=(); [ -f "$dir/remove.cos" ] && rmargs=(--remove "$dir/remove.cos")
  python3 "$here/make-agent.py" --name "$name" --desc "$desc" --install "$install" \
    "${rmargs[@]}" --thumb-frame "$thumbframe" \
    --sprite "$out/$sprite.s16" --ceshad "$out/$sprite.ceshad" --out "$out/$name.agent"
  echo "built $out/$name.agent"
done
