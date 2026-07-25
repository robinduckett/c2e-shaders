#!/usr/bin/env python3
"""Write a multi-frame .s16 sprite (classic C2E 16-bit lane, RGB565).

.s16 layout (little-endian), per Gallery.cpp:
  u32 pixelFormat (bit 0 = 565, clear = 555) | u16 count |
  count x { u32 pixelOffset(abs), u16 w, u16 h } | concatenated u16 pixel data

Pixel value 0 is the C2E colour key (transparent), so the opaque-black surrogate
uses 0x0001 — the darkest non-transparent 565 value — rather than true black.

The injector preview frame MUST be a 16-bit sprite: the DS agent injector builds
its preview with `new: simp 3 3 66 pray agts …` and that path does not take an
.s32 gallery, so an .s32 sprite falls back to `question_mark` and then indexes
the thumbnail frame past its end.
"""
import argparse, struct, sys, zlib

C16_FLAG_565 = 0x1


def _rgb565(r: int, g: int, b: int) -> int:
    v = ((r & 0xF8) << 8) | ((g & 0xFC) << 3) | (b >> 3)
    return v if v else 0x0001          # never emit the colour key by accident


def _frame_pixels(w: int, h: int, opaque: bool) -> bytes:
    px = 0x0001 if opaque else 0x0000
    return struct.pack("<%dH" % (w * h), *([px] * (w * h)))


def _png_to_565(data: bytes):
    """Decode an 8-bit RGB/RGBA PNG to (w, h, 565 bytes). Fully transparent
    pixels become the colour key; everything else is forced non-zero."""
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("not a PNG")
    pos, idat, w = 8, b"", None
    while pos < len(data):
        ln = struct.unpack(">I", data[pos:pos + 4])[0]
        tag = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + ln]
        if tag == b"IHDR":
            w, h, depth, colour = struct.unpack(">IIBB", body[:10])
            if depth != 8 or colour not in (2, 6):
                raise ValueError("thumb PNG must be 8-bit RGB or RGBA")
        elif tag == b"IDAT":
            idat += body
        elif tag == b"IEND":
            break
        pos += 12 + ln
    if w is None:
        raise ValueError("PNG has no IHDR")

    nch = 4 if colour == 6 else 3
    raw = zlib.decompress(idat)
    stride = w * nch
    out, prev = bytearray(), bytearray(stride)
    p = 0
    for _ in range(h):
        ft = raw[p]; p += 1
        line = bytearray(raw[p:p + stride]); p += stride
        for i in range(stride):                      # undo the PNG line filter
            a = line[i - nch] if i >= nch else 0
            bb = prev[i]
            c = prev[i - nch] if i >= nch else 0
            if ft == 1:   line[i] = (line[i] + a) & 0xFF
            elif ft == 2: line[i] = (line[i] + bb) & 0xFF
            elif ft == 3: line[i] = (line[i] + ((a + bb) >> 1)) & 0xFF
            elif ft == 4:
                pa, pb, pc = abs(bb - c), abs(a - c), abs(a + bb - 2 * c)
                pr = a if (pa <= pb and pa <= pc) else (bb if pb <= pc else c)
                line[i] = (line[i] + pr) & 0xFF
        for x in range(w):
            r, g, b = line[x * nch], line[x * nch + 1], line[x * nch + 2]
            alpha = line[x * nch + 3] if nch == 4 else 255
            out += struct.pack("<H", 0 if alpha == 0 else _rgb565(r, g, b))
        prev = line
    return w, h, bytes(out)


def build_s16(frames) -> bytes:
    """frames: [(w, h, pixeldata), ...] — one entry per frame. Frames may differ
    in size: the table carries per-frame w/h, and SimpleAgent::ShowPose feeds the
    new frame's dimensions into the agent's extent. That is what lets an agent
    toggle between a full-size pose (0) and a small carry pose (1), the latter
    small enough to satisfy the vehicle cabin fit-check. An optional trailing
    frame holds the injector thumbnail."""
    header = struct.pack("<I", C16_FLAG_565) + struct.pack("<H", len(frames))
    off = 6 + len(frames) * 8
    table = b""
    for (w, h, px) in frames:
        table += struct.pack("<IHH", off, w, h)
        off += len(px)
    return header + table + b"".join(px for (_, _, px) in frames)


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
                    help="fully-transparent sprite (default is opaque surrogate)")
    a = ap.parse_args()
    opaque = not a.transparent

    frames = [(a.w, a.h, _frame_pixels(a.w, a.h, opaque))]
    if a.carry_w and a.carry_h:
        frames.append((a.carry_w, a.carry_h, _frame_pixels(a.carry_w, a.carry_h, opaque)))
    if a.thumb:
        try:
            tw, th, px = _png_to_565(open(a.thumb, "rb").read())
        except ValueError as e:
            sys.exit(f"--thumb {a.thumb}: {e}")
        frames.append((tw, th, px))

    with open(a.out, "wb") as f:
        f.write(build_s16(frames))
    kind = "transparent" if a.transparent else "opaque surrogate"
    dims = " + ".join(f"{w}x{h}" for (w, h, _) in frames)
    print(f"wrote {a.out} ({dims} {kind} .s16{', +thumbnail' if a.thumb else ''})")


if __name__ == "__main__":
    main()
