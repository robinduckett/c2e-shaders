#!/usr/bin/env python3
"""Write a single-image, fully-transparent .s32 sprite (CE 32-bit PNG lane).

.s32 layout (little-endian), per C2eSprite32.cpp:
  u32 flags (must have bit 2 / 0x4 set) | u16 count |
  count x { u32 pngOffset(abs), u16 w, u16 h } | concatenated PNG streams
The PNG's own IHDR is authoritative; the table w/h are ignored by the engine.
"""
import argparse, struct, sys, zlib

def _png_rgba(w: int, h: int, rgba: bytes) -> bytes:
    def chunk(tag: bytes, data: bytes) -> bytes:
        c = tag + data
        return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c) & 0xffffffff)
    sig = b"\x89PNG\r\n\x1a\n"
    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)   # 8-bit depth, colour type 6 = RGBA
    stride = w * 4
    raw = bytearray()
    for y in range(h):
        raw.append(0)                                     # filter type 0 (None) per scanline
        raw += rgba[y * stride:(y + 1) * stride]
    idat = zlib.compress(bytes(raw), 9)
    return sig + chunk(b"IHDR", ihdr) + chunk(b"IDAT", idat) + chunk(b"IEND", b"")

def _frame_png(w: int, h: int, opaque: bool) -> bytes:
    if opaque:
        # Opaque black surrogate: every pixel R=0 G=0 B=0 A=255. Gives the agent
        # hit-test pixels across its whole frame (so a CESHAD shader agent is
        # grab/mouse-pickable), and is a visible fallback if the shader ever fails
        # to load. The attached .ceshad shader draws over the quad, so the black
        # is not seen while the shader runs.
        px = bytes([0, 0, 0, 255]) * (w * h)
    else:
        px = bytes(w * h * 4)                             # all zero = fully transparent
    return _png_rgba(w, h, px)

def build_s32(sizes, opaque: bool, thumb: bytes = None) -> bytes:
    """sizes: [(w, h), ...] — one frame per entry. Frames may differ in size:
    the .s32 table carries per-frame w/h, and SimpleAgent::ShowPose feeds the
    new frame's dimensions into the agent's extent. That is what lets an agent
    toggle between a full-size pose (0) and a small carry pose (1), the latter
    small enough to satisfy the vehicle cabin fit-check. An optional trailing
    frame holds the injector thumbnail."""
    # The thumbnail (when present) is the LAST entry in `sizes` and arrives
    # already encoded — it is a real picture of the effect, not a surrogate.
    frames = sizes[:-1] if thumb else sizes
    pngs = [_frame_png(w, h, opaque) for (w, h) in frames]
    if thumb:
        pngs.append(thumb)
    header = struct.pack("<I", 0x4) + struct.pack("<H", len(sizes))
    table_size = len(sizes) * 8
    off = 6 + table_size
    table = b""
    for (w, h), png in zip(sizes, pngs):
        table += struct.pack("<IHH", off, w, h)
        off += len(png)
    return header + table + b"".join(pngs)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--w", type=int, required=True)
    ap.add_argument("--h", type=int, required=True)
    ap.add_argument("--carry-w", type=int, help="optional second (carry) frame width")
    ap.add_argument("--carry-h", type=int, help="optional second (carry) frame height")
    ap.add_argument("--thumb", help="PNG appended as a final frame — the injector / "
                                    "Library thumbnail (Agent Sprite First Image points at it)")
    ap.add_argument("--out", required=True)
    ap.add_argument("--transparent", action="store_true",
                    help="fully-transparent sprite (default is opaque-black surrogate)")
    a = ap.parse_args()
    sizes = [(a.w, a.h)]
    if a.carry_w and a.carry_h:
        sizes.append((a.carry_w, a.carry_h))
    thumb = None
    if a.thumb:
        thumb = open(a.thumb, "rb").read()
        if thumb[:8] != b"\x89PNG\r\n\x1a\n":
            sys.exit(f"--thumb {a.thumb} is not a PNG")
        tw, th = struct.unpack(">II", thumb[16:24])   # IHDR width/height
        sizes.append((tw, th))
    with open(a.out, "wb") as f:
        f.write(build_s32(sizes, opaque=not a.transparent, thumb=thumb))
    kind = "transparent" if a.transparent else "opaque-black surrogate"
    dims = " + ".join(f"{w}x{h}" for (w, h) in sizes)
    print(f"wrote {a.out} ({dims} {kind} .s32{', +thumbnail' if thumb else ''})")

if __name__ == "__main__":
    main()
