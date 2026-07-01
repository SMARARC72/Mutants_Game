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
