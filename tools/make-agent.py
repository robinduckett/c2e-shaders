#!/usr/bin/env python3
"""Write a Docking Station .agent PRAY file bundling a CESHAD shader effect.

PRAY (little-endian), per PrayStructs.h / StringIntGroup.cpp / PrayHandlers.cpp:
  "PRAY" then chunks until EOF.
  chunk = char type[4] | char name[128] (NUL-padded) | i32 size(compressed) |
          i32 usize(uncompressed) | i32 flags (bit0 = zlib-compressed) | body
  DSAG body (tag block): i32 intCount, {i32 nameLen, name, i32 value}* ,
                         i32 strCount, {i32 nameLen, name, i32 valLen, value}*
  Engine reads: "Agent Type"(int), "Script Count"(int), "Script N"(str),
  "Dependency Count"(int), "Dependency N"(str filename == FILE chunk name),
  "Dependency Category N"(int; Images=2, Sounds=1).
  A dependency's file bytes live in a FILE chunk whose name == the filename.
"""
import argparse, struct, zlib

def _tag_block(int_tags, str_tags) -> bytes:
    out = struct.pack("<i", len(int_tags))
    for name, val in int_tags:
        nb = name.encode("ascii")
        out += struct.pack("<i", len(nb)) + nb + struct.pack("<i", int(val))
    out += struct.pack("<i", len(str_tags))
    for name, val in str_tags:
        nb = name.encode("ascii"); vb = val.encode("utf-8")
        out += struct.pack("<i", len(nb)) + nb + struct.pack("<i", len(vb)) + vb
    return out

def _chunk(type4: bytes, name: str, body: bytes) -> bytes:
    assert len(type4) == 4
    comp = zlib.compress(body, 9)                         # standard zlib (header+deflate+adler32)
    enc = name.encode("utf-8")[:128]                       # 128-byte fixed field
    enc = enc.decode("utf-8", "ignore").encode("utf-8")    # drop a split trailing multibyte seq
    name128 = enc.ljust(128, b"\x00")
    return type4 + name128 + struct.pack("<iii", len(comp), len(body), 1) + comp

def build_agent(name, desc, install_cos, deps, remove_cos=None, anim_file=None, thumb_frame=0):
    # deps: list of (filename, category_int, filebytes)
    # "Remove script" is what the injector / asset library runs to UNINSTALL the
    # agent (it kills the injected agents). Without it, removing the agent leaves
    # everything it injected alive in the world.
    # "Agent Animation File" + "Agent Sprite First Image" are what the injector /
    # asset Library read to draw the agent's thumbnail: the sprite to decode and
    # which frame of it to show. We point them at the agent's OWN sprite and a
    # trailing frame holding a real picture of the effect, so no extra dependency
    # file is needed.
    int_tags = [("Agent Type", 0), ("Script Count", 1), ("Dependency Count", len(deps))]
    str_tags = [("Agent Description", desc), ("Script 1", install_cos)]
    if anim_file:
        str_tags.append(("Agent Animation File", anim_file))
        int_tags.append(("Agent Sprite First Image", thumb_frame))
    if remove_cos:
        str_tags.append(("Remove script", remove_cos))
    for i, (fn, cat, _) in enumerate(deps):
        int_tags.append(("Dependency Category %d" % (i + 1), cat))
        str_tags.append(("Dependency %d" % (i + 1), fn))
    out = b"PRAY"
    out += _chunk(b"DSAG", name, _tag_block(int_tags, str_tags))
    for fn, cat, data in deps:
        out += _chunk(b"FILE", fn, data)
    return out

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--name", required=True)
    ap.add_argument("--desc", default="")
    ap.add_argument("--install", required=True)           # install .cos path
    ap.add_argument("--remove")                           # remove .cos path (uninstall)
    ap.add_argument("--sprite", required=True)            # .s32 path
    ap.add_argument("--ceshad", required=True)            # .ceshad path
    ap.add_argument("--thumb-frame", type=int, default=-1,
                    help="frame index in the sprite to use as the injector thumbnail")
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    install = open(a.install, "r", encoding="utf-8").read()
    remove = open(a.remove, "r", encoding="utf-8").read() if a.remove else None
    import os
    deps = [
        (os.path.basename(a.sprite), 2, open(a.sprite, "rb").read()),   # Images
        (os.path.basename(a.ceshad), 2, open(a.ceshad, "rb").read()),   # Images
    ]
    with open(a.out, "wb") as f:
        anim = os.path.basename(a.sprite) if a.thumb_frame >= 0 else None
        f.write(build_agent(a.name, a.desc, install, deps, remove,
                            anim_file=anim, thumb_frame=max(0, a.thumb_frame)))
    print("wrote %s (%d deps%s)" % (a.out, len(deps), ", +remove script" if remove else ""))

if __name__ == "__main__":
    main()
