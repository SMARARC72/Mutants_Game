# Backdrops — project-generated battle backgrounds (sliced contact sheets)

Sliced from the project's own AI-generated contact sheets `assets/tiles/backdrop/TILE-061..072.png`
(main-repo art dump, gitignored) by `tools/slice_backdrops.py` — no third-party assets. Panels are
cut at detected black gutters / caption-banner strips (banner text cropped out), fragments split
across neighbouring sheets are butt-joint stitched (verified pixel-continuous, no resampling), and
residual black frame bands are trimmed. Native panel resolution kept.

- `<name>.png` — sliced panel; `_b` suffix = alternate take of the same scene.
- `<name>_battle.png` — dimmed variant of each force's primary panel (brightness x0.62,
  saturation x0.85) for HUD readability in battle.
- `manifest.json` — `{force_or_biome_key: [files]}`; six occult forces (gaia/ouranos/cosmos/
  chaos/eros/thanatos) plus ten biome keys. List order: primary, `_battle` variant, `_b` variants.

Regenerate: `python tools/slice_backdrops.py` (PIL + numpy only). Binaries commit via Git LFS.

## Wave 12 — horizon strips (`horizon/<force>.png`)

DERIVED from each force's primary panel above by `tools/gen_horizon.py` (heavy gaussian blur,
darken x0.52, vertical ink fade into GrimoirePalette INK at both edges) — no new sources. Kept at
1024x320 (the asset-contract 1024px cap) and upscaled in-scene on the overworld's Parallax2D
horizon layer. Regenerate: `python tools/gen_horizon.py` (PIL + numpy only). Git LFS.
