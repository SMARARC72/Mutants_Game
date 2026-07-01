# Creatures — project-generated bestiary plates (Wave 7 keystone)

All plates are project-original AI renders (`gpt-image-1`, prompts per
`docs/Mutants_Game_ImageGen_Prompts.md`) from the gitignored bulk library under the main repo's
`/art`, promoted here by `tools/promote_creatures.py` (source resolution: registry `art_ref` +
`tools/art_origins.json`). No third-party art; commit via Git LFS.

- `cutout/<species_id>.png` — RGBA knockout (border-ring-median background removal, C3), max dim
  512, preferred by `SpeciesArt.plate()` for battle/party/lab/camp surfaces over INK.
- `flat/<species_id>.png` — the flat original plate, max dim 512, for codex/parchment surfaces.
- `manifest.json` — GENERATED map `species_id -> {cutout, flat}`; never hand-edit (pipeline
  output only — hand-grown entries are banned, see Realization_Master_Plan Wave 7).
- Root-level `*.png` (halo_sprout, leaf_hare, …) — legacy hand-curated plates kept as the
  fallback chain (`halo_sprout.png` is the generic unmapped-species fallback).

Rejected knockouts (`tools/creature_art_rejects.json`) ship flat-only. Gaps:
`tools/creature_art_gaps.json` → `tools/gen_art.py --only` gap-fill.
