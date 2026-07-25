#!/usr/bin/env python3
"""Pack a shader into a CE .ceshad container.

Preferred: --shade <src.frag.glsl>, one canonical `vec4 shade(vec4 texel, vec2 uv)`
source. It is compiled through ceshad-prelude.glsl to SPIR-V, cross-compiled to MSL and
HLSL SM5.1, and META is derived from CESHAD_* macros in the source (see scan_macros).
Legacy: --msl <src.frag.msl> plus explicit --bleed/--scene-read/--full-screen and
optional pre-built --glsl/--spv/--hl51/--dxil sections.

Format (little-endian), per lisdude ceshad.md and CeshadPack.cpp:
  "CESHADPK" | u32 containerVer=1 | u32 ifaceVer=1 | u32 count | u32 reserved=0
  count x { char[4] tag, u32 offset(abs), u32 size }
  payloads...
Required sections: GLSL, SPV\x20, MSL\x20, HL51, META, DXIL (DXBC optional).
Apple uses only MSL + META; the rest are content-ignored placeholders.
META = i32 bleedL, bleedT, bleedR, bleedB, u32 flags (bit0 = sceneRead, bit1 = fullScreen).
"""
import argparse, os, re, shutil, struct, subprocess, sys, tempfile

# Any line that LOOKS like a CESHAD_ define is one we must understand. Lines matching
# _DEFINE_LOOSE but not _MACRO_RE abort the pack rather than being dropped: a scanner that
# skips what it cannot parse packs the wrong META in silence, which is how a shader ends up
# clipped at its frame edge with no error anywhere. Comments are stripped before matching,
# because a real reference pack annotates its bleed with a trailing comment. Separators are
# [ \t] rather than \s so a bare "#define CESHAD_BLEED" can never pick up a number from the
# NEXT line (the preprocessor sees that macro as empty).
_DEFINE_LOOSE = re.compile(r"^[ \t]*#[ \t]*define[ \t]+CESHAD_")
_COMMENT_RE   = re.compile(r"//.*$|/\*.*?\*/")
_MACRO_RE     = re.compile(r"^[ \t]*#[ \t]*define[ \t]+(CESHAD_[A-Z_]+)(?:[ \t]+(-?\d+))?[ \t]*$")

def scan_macros(text: str):
    """META is authored in the shader source, per ceshad.md. Returns
    ([bleedL, bleedT, bleedR, bleedB], sceneRead, fullScreen)."""
    found = {}
    for n, line in enumerate(text.splitlines(), 1):
        if not _DEFINE_LOOSE.match(line):
            continue                      # not a CESHAD_ define (incl. a commented-out one)
        m = _MACRO_RE.match(_COMMENT_RE.sub(" ", line).rstrip())
        if m is None:
            sys.exit(f"line {n}: cannot parse CESHAD macro: {line.strip()}\n"
                     "  expected '#define CESHAD_NAME' or '#define CESHAD_NAME <integer>' "
                     "(no expressions, hex, or line continuations)")
        found[m.group(1)] = int(m.group(2)) if m.group(2) is not None else 1
    uniform = found.get("CESHAD_BLEED", 0)
    bleed = [found.get("CESHAD_BLEED_LEFT",   uniform),
             found.get("CESHAD_BLEED_TOP",    uniform),
             found.get("CESHAD_BLEED_RIGHT",  uniform),
             found.get("CESHAD_BLEED_BOTTOM", uniform)]
    return bleed, "CESHAD_SCENE" in found, "CESHAD_FULLSCREEN" in found

# glslc ships in shaderc, spirv-val in spirv-tools, spirv-cross in its own formula —
# three tools, three formulas. Naming the RIGHT one matters: told to `brew install
# shaderc spirv-cross` for a missing spirv-val, a contributor reinstalls two formulas
# they already have and is no closer.
_BREW_FORMULA = {"glslc": "shaderc", "spirv-val": "spirv-tools", "spirv-cross": "spirv-cross"}

def _need(tool):
    if shutil.which(tool) is None:
        sys.exit(f"{tool} not found — required by --shade "
                 f"(brew install {_BREW_FORMULA.get(tool, tool)})")

def _run(cmd, what, capture_stdout=False, remap=None):
    """Run a tool, and on failure print ITS diagnostics rather than a Python traceback.
    stderr is always surfaced — a swallowed cross-compiler error is unactionable."""
    r = subprocess.run(cmd, capture_output=True)
    err = r.stderr.decode("utf-8", "replace")
    if remap:
        err = err.replace(remap[0], remap[1])
    if err:
        sys.stderr.write(err)
    if r.returncode != 0:
        sys.exit(f"{what} failed ({os.path.basename(cmd[0])} exit {r.returncode})")
    return r.stdout if capture_stdout else None

def _normalise_hlsl_registers(hl51: bytes) -> bytes:
    """spirv-cross derives HLSL registers from the GLSL binding numbers, so our
    bindings 1 and 2 come out as t1/s1 (sprite) and t2/s2 (scene). The fixed CE slots
    are sprite t0/s0 and scene t1/s1, so shift every t/s register down by one. The
    uniform is already b0 and is left alone (the pattern only matches t and s).
    Verified output before: b0, t1/s1, t2/s2. After: b0, t0/s0, t1/s1."""
    def shift(m):
        n = int(m.group(2))
        # Cannot happen while the prelude keeps binding 0 for the UBO and starts textures
        # at 1. If that ever changes, fail here rather than emit register(t-1, space0).
        if n < 1:
            sys.exit(f"cannot shift HLSL register {m.group(1).decode()}{n} down: the "
                     "prelude's texture bindings must start at 1, not 0")
        return b"register(%s%d, space0)" % (m.group(1), n - 1)
    return re.sub(rb"register\(([ts])(\d+), space0\)", shift, hl51)

def compile_shade(shade_path: str, prelude_path: str):
    """Prelude + author source -> (glsl, spv, msl, hl51, bleed, sceneRead, fullScreen).
    The GLSL section stores the author's source alone, as the spec intends."""
    for t in ("glslc", "spirv-cross", "spirv-val"):
        _need(t)
    with open(shade_path, "r", encoding="utf-8") as f:
        author = f.read()
    with open(prelude_path, "r", encoding="utf-8") as f:
        prelude = f.read()
    bleed, scene_read, full_screen = scan_macros(author)
    # A full-screen pack always reads the composite, so it is implicitly scene-read.
    # Write bit 0 explicitly rather than relying on the reader: the RFC says bit 0 MAY
    # be set when bit 1 is, CeshadPack.cpp forces it at parse time anyway, and a pack
    # whose raw META says what it means is easier to diff against CE's.
    scene_read = scene_read or full_screen
    #
    # CESHAD_HAVE_SCENE is ours, not the author's. Passing -DCESHAD_SCENE would
    # collide with the author's own bare #define of it ("Macro redefined; different
    # substitutions"). CESHAD_FULLSCREEN is never passed at all — no prelude code is
    # keyed on it; it only sets META bit 1 and tells the host how to schedule the pass.
    defines = []
    if scene_read or full_screen:
        defines.append("-DCESHAD_HAVE_SCENE=1")
    with tempfile.TemporaryDirectory() as td:
        frag = os.path.join(td, "frag.glsl")
        spv  = os.path.join(td, "frag.spv")
        with open(frag, "w", encoding="utf-8") as f:
            f.write(prelude)
            # Reset the line counter so glslc reports errors against the AUTHOR's line
            # numbers, not the concatenation's. Without this a mistake on line 2 of the
            # source is reported at line ~130 of a temp file that is then deleted.
            f.write("\n#line 1\n")
            f.write(author)
        _run(["glslc", "-fshader-stage=frag", *defines, frag, "-o", spv],
             "shader compile", remap=(frag, shade_path))
        _run(["spirv-val", spv], "SPIR-V validation")
        msl  = _run(["spirv-cross", "--msl", spv], "MSL cross-compile", capture_stdout=True)
        hl51 = _run(["spirv-cross", "--hlsl", "--shader-model", "51", spv],
                    "HLSL cross-compile", capture_stdout=True)
        hl51 = _normalise_hlsl_registers(hl51)
        with open(spv, "rb") as f:
            spv_bytes = f.read()
    return (author.encode("utf-8"), spv_bytes, msl, hl51, bleed, scene_read, full_screen)

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

def selftest_macros():
    assert scan_macros("#define CESHAD_BLEED 10\n") == ([10, 10, 10, 10], False, False)
    assert scan_macros("#define CESHAD_SCENE\n#define CESHAD_BLEED 480\n") \
        == ([480, 480, 480, 480], True, False)
    assert scan_macros("#define CESHAD_BLEED_LEFT 1\n#define CESHAD_BLEED_TOP 2\n"
                       "#define CESHAD_BLEED_RIGHT 3\n#define CESHAD_BLEED_BOTTOM 4\n") \
        == ([1, 2, 3, 4], False, False)
    # A per-side macro overrides the uniform CESHAD_BLEED for that side only.
    assert scan_macros("#define CESHAD_BLEED 8\n#define CESHAD_BLEED_TOP 20\n") \
        == ([8, 20, 8, 8], False, False)
    assert scan_macros("#define CESHAD_FULLSCREEN\n") == ([0, 0, 0, 0], False, True)
    assert scan_macros("// #define CESHAD_SCENE\n") == ([0, 0, 0, 0], False, False)
    # A trailing comment must not silently zero the bleed — a reference pack annotates its
    # bleed this way, and dropping the line would clip the effect at the sprite edge, the
    # one thing CESHAD_BLEED exists to prevent.
    assert scan_macros("#define CESHAD_BLEED 10        // enough for the blur to spread\n") \
        == ([10, 10, 10, 10], False, False)
    assert scan_macros("#define CESHAD_SCENE  /* reads the composite */\n") \
        == ([0, 0, 0, 0], True, False)
    # A CESHAD_ define we cannot parse aborts; it is never dropped on the floor.
    for bad in ("#define CESHAD_BLEED (10)\n", "#define CESHAD_BLEED 0x10\n",
                "#define CESHAD_BLEED \\\n480\n", "#define CESHAD_BLEED 10 20\n"):
        try:
            scan_macros(bad)
        except SystemExit:
            pass
        else:
            raise AssertionError(f"unparseable macro accepted: {bad!r}")
    print("make-ceshad macro selftest OK")

def selftest_registers():
    n = _normalise_hlsl_registers
    assert n(b"register(t1, space0)") == b"register(t0, space0)"
    assert n(b"register(s2, space0)") == b"register(s1, space0)"
    # The uniform buffer is already in the right slot and must not be shifted.
    assert n(b"register(b0, space0)") == b"register(b0, space0)"
    # A register that cannot shift down must abort, not emit register(t-1, space0).
    try:
        n(b"register(t0, space0)")
    except SystemExit:
        pass
    else:
        raise AssertionError("register t0 was shifted below zero")
    print("make-ceshad register selftest OK")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--msl", help="pre-built Metal fragment (legacy path)")
    ap.add_argument("--shade", help="canonical shade() GLSL source (preferred)")
    ap.add_argument("--prelude", default=os.path.join(os.path.dirname(__file__),
                                                      "ceshad-prelude.glsl"))
    ap.add_argument("--out")
    ap.add_argument("--selftest-macros", action="store_true")
    ap.add_argument("--bleed", default="0,0,0,0")
    ap.add_argument("--scene-read", type=int, default=0)
    ap.add_argument("--full-screen", type=int, default=0)
    ap.add_argument("--glsl", help="real GLSL source (else placeholder)")
    ap.add_argument("--spv",  help="real SPIR-V bytecode (else placeholder)")
    ap.add_argument("--hl51", help="real HLSL SM5.1 source (else placeholder)")
    ap.add_argument("--dxil", help="real DXIL bytecode (else placeholder)")
    a = ap.parse_args()
    if a.selftest_macros:
        selftest_macros(); selftest_registers(); return
    if not a.out:
        sys.exit("--out is required")
    if bool(a.shade) == bool(a.msl):
        sys.exit("give exactly one of --shade (preferred) or --msl (legacy)")
    if a.shade:
        # --shade derives META from the source and builds every section itself. Silently
        # ignoring a legacy flag would let a caller believe their --bleed took effect.
        legacy = [n for n, given in (("--bleed", a.bleed != "0,0,0,0"),
                                     ("--scene-read", a.scene_read),
                                     ("--full-screen", a.full_screen),
                                     ("--glsl", a.glsl), ("--spv", a.spv),
                                     ("--hl51", a.hl51), ("--dxil", a.dxil)) if given]
        if legacy:
            sys.exit(f"--shade derives META and every section from the source itself; "
                     f"remove {', '.join(legacy)}")
        glsl, spv, msl, hl51, bleed, scene_read, full_screen = compile_shade(a.shade, a.prelude)
        with open(a.out, "wb") as f:
            f.write(build(msl, bleed, scene_read, full_screen, glsl, spv, hl51, None))
        print(f"wrote {a.out} from {a.shade} "
              f"(bleed={bleed}, sceneRead={scene_read}, fullScreen={full_screen}, "
              f"{len(msl)} bytes MSL, {len(spv)} bytes SPIR-V)")
        return
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
