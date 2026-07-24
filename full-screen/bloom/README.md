# Bloom (full‑screen)

A full‑screen **bloom**: bright‑pass threshold, a cheap blur, and an additive glow over the composited frame.

**Source only** — a full‑screen CESHAD pack (META `flags` bit 1 set), *not* a
packaged pick‑up agent. Apply it as a whole‑frame post‑process through your
engine's rendering settings, or wrap it in your own carrier agent.

- **Shader source:** `bloom.frag.msl`
- **Pack:** `bloom.ceshad`  ·  **Meta:** `meta.json` (`sceneRead:1, fullScreen:1`)
- **Params:** `{ threshold intensity radius }` (default `{ 0.7 1.2 2.0 }`)
