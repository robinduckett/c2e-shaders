# CRT (full‑screen)

A full‑screen **CRT** emulation: barrel curvature, scanlines, a subtle chromatic aberration and vignette over the whole frame.

**Source only** — a full‑screen CESHAD pack (META `flags` bit 1 set), *not* a
packaged pick‑up agent. Apply it as a whole‑frame post‑process through your
engine's rendering settings, or wrap it in your own carrier agent.

- **Shader source:** `crt.frag.msl`
- **Pack:** `crt.ceshad`  ·  **Meta:** `meta.json` (`sceneRead:1, fullScreen:1`)
- **Params:** `{ curvature scanline aberration scanlines }` (default `{ 0.14 0.32 0.0018 220 }`)
