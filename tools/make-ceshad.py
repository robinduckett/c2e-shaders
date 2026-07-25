#!/usr/bin/env python3
"""Pack a Metal fragment (+ META) into a CE .ceshad container.

Format (little-endian), per lisdude ceshad.md and CeshadPack.cpp:
  "CESHADPK" | u32 containerVer=1 | u32 ifaceVer=1 | u32 count | u32 reserved=0
  count x { char[4] tag, u32 offset(abs), u32 size }
  payloads...
Required sections: GLSL, SPV\x20, MSL\x20, HL51, META, DXIL (DXBC optional).
Apple uses only MSL + META; the rest are content-ignored placeholders.
META = i32 bleedL, bleedT, bleedR, bleedB, u32 flags (bit0 = sceneRead, bit1 = fullScreen).
"""
import argparse, struct, sys

def build(msl: bytes, bleed, scene_read: bool, full_screen: bool,
          glsl=None, spv=None, hl51=None, dxil=None) -> bytes:
    flags = (1 if scene_read else 0) | (2 if full_screen else 0)
    meta = struct.pack("<5i", bleed[0], bleed[1], bleed[2], bleed[3], flags)
    # tag -> payload. Real cross-platform sections when provided, else placeholders
    # (Apple reads only MSL + META; other hosts read their own section).
    sections = [
        (b"GLSL", glsl if glsl is not None else b"// unused on Apple\n"),
        (b"SPV ", spv  if spv  is not None else b"\x03\x02\x23\x07"),
        (b"MSL ", msl),
        (b"HL51", hl51 if hl51 is not None else b"// unused on Apple\n"),
        (b"META", meta),
        (b"DXIL", dxil if dxil is not None else b"\x44\x58\x42\x43"),
    ]
    header = b"CESHADPK" + struct.pack("<4I", 1, 1, len(sections), 0)
    table_size = len(sections) * 12
    payload_start = len(header) + table_size
    table = b""
    cur = payload_start
    payloads = b""
    for tag, data in sections:
        assert len(tag) == 4
        table += tag + struct.pack("<II", cur, len(data))
        payloads += data
        cur += len(data)
    return header + table + payloads

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--msl", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--bleed", default="0,0,0,0")
    ap.add_argument("--scene-read", type=int, default=0)
    ap.add_argument("--full-screen", type=int, default=0)
    ap.add_argument("--glsl", help="real GLSL source (else placeholder)")
    ap.add_argument("--spv",  help="real SPIR-V bytecode (else placeholder)")
    ap.add_argument("--hl51", help="real HLSL SM5.1 source (else placeholder)")
    ap.add_argument("--dxil", help="real DXIL bytecode (else placeholder)")
    a = ap.parse_args()
    bleed = [int(x) for x in a.bleed.split(",")]
    if len(bleed) != 4:
        sys.exit("--bleed must be L,T,R,B")
    def rd(p):
        if not p: return None
        with open(p, "rb") as f: return f.read()
    with open(a.msl, "rb") as f:
        msl = f.read()
    glsl, spv, hl51, dxil = rd(a.glsl), rd(a.spv), rd(a.hl51), rd(a.dxil)
    with open(a.out, "wb") as f:
        f.write(build(msl, bleed, bool(a.scene_read), bool(a.full_screen), glsl, spv, hl51, dxil))
    have = "+".join(t for t, v in
                    [("MSL", msl), ("GLSL", glsl), ("SPV", spv), ("HL51", hl51), ("DXIL", dxil)] if v)
    print(f"wrote {a.out} ({len(msl)} bytes MSL, bleed={bleed}, sceneRead={a.scene_read}, "
          f"fullScreen={a.full_screen}, real sections: {have})")

if __name__ == "__main__":
    main()
