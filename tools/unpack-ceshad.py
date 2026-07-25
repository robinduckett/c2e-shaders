#!/usr/bin/env python3
"""Extract sections from a CE .ceshad container (per lisdude ceshad.md)."""
import argparse, os, struct, sys

def parse_table(b: bytes) -> list:
    """[(tag, offset, size)] in table order. Tags are rstripped ('SPV ' -> 'SPV')."""
    if len(b) < 24 or b[:8] != b"CESHADPK":
        raise ValueError("not a CESHAD container")
    container_ver, iface_ver, count, _res = struct.unpack_from("<4I", b, 8)
    if container_ver != 1:
        raise ValueError(f"unsupported container version {container_ver}")
    if 24 + 12 * count > len(b):
        raise ValueError("section table runs past end of file")
    entries = []
    off = 24
    for _ in range(count):
        tag = b[off:off + 4].decode("latin1")
        payload_off, size = struct.unpack_from("<2I", b, off + 4)
        off += 12
        if payload_off + size > len(b):
            raise ValueError(f"section {tag!r} runs past end of file")
        entries.append((tag.rstrip(), payload_off, size))
    return entries

def parse(b: bytes) -> dict:
    return {tag: b[off:off + size] for tag, off, size in parse_table(b)}

def meta_fields(meta: bytes):
    """Read META by length: 20, 16, or 4 bytes; missing fields are 0."""
    vals = list(struct.unpack_from("<%di" % (len(meta) // 4), meta, 0))
    if len(vals) == 1:
        return (vals[0], vals[0], vals[0], vals[0], 0)
    while len(vals) < 5:
        vals.append(0)
    return tuple(vals[:5])

def selftest():
    # Round-trip a synthetic container: header + table + payloads.
    import struct as _s
    secs = [(b"GLSL", b"vec4 shade(){}"), (b"SPV ", b"\x03\x02\x23\x07"),
            (b"MSL ", b"fragment"), (b"HL51", b"hl"),
            (b"META", _s.pack("<5i", 1, 2, 3, 4, 1)), (b"DXIL", b"DXBC")]
    hdr = b"CESHADPK" + _s.pack("<4I", 1, 1, len(secs), 0)
    cur = len(hdr) + 12 * len(secs)
    table, payloads = b"", b""
    for tag, data in secs:
        table += tag + _s.pack("<II", cur, len(data)); payloads += data; cur += len(data)
    blob = hdr + table + payloads
    got = parse(blob)
    assert got["GLSL"] == b"vec4 shade(){}", got.get("GLSL")
    assert got["MSL"] == b"fragment", got.get("MSL")
    assert meta_fields(got["META"]) == (1, 2, 3, 4, 1), meta_fields(got["META"])
    assert meta_fields(_s.pack("<i", 7)) == (7, 7, 7, 7, 0), meta_fields(_s.pack("<i", 7))
    # Offsets are absolute: payloads start after the 24-byte header + 12-byte-per-section table.
    assert parse_table(blob)[:2] == [("GLSL", 96, 14), ("SPV", 110, 4)], parse_table(blob)[:2]
    print("unpack-ceshad selftest OK")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("pack", nargs="?")
    ap.add_argument("--out", help="directory to write <tag>.bin into")
    ap.add_argument("--meta", action="store_true", help="print META fields only")
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args()
    if a.selftest:
        selftest(); return
    if not a.pack:
        sys.exit("need a pack path (or --selftest)")
    with open(a.pack, "rb") as f:
        blob = f.read()
    table = parse_table(blob)
    secs = {tag: blob[off:off + size] for tag, off, size in table}
    if a.meta:
        if "META" not in secs:
            sys.exit("pack has no META section")
        print(" ".join(str(x) for x in meta_fields(secs["META"]))); return
    if a.out:
        os.makedirs(a.out, exist_ok=True)
        for tag, data in secs.items():
            # Tags come straight off disk: never let one escape --out as a path.
            if not (tag.isascii() and tag.isalnum()):
                print(f"skipping unsafe section tag {tag!r}", file=sys.stderr); continue
            with open(os.path.join(a.out, tag + ".bin"), "wb") as f:
                f.write(data)
    for tag, off, size in table:
        print(f"{tag} {off} {size}")

if __name__ == "__main__":
    main()
