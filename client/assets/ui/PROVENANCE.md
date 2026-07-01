# UI assets — Kenney (CC0)

CC0 (public domain), no attribution required. **Phase 0.5 status:** curated starter subset pending —
the full Kenney UI pack is large and lives in the local library `../_asset-library/kenney/` (NOT
committed); a curated subset (frames/buttons/cursors) lands here via Git LFS. Source: https://kenney.nl/assets

## Procedural grimoire surfaces (Wave 4 — first-party, no license concerns)

Generated deterministically by `tools/gen_ui_kit.py` (PIL + numpy, fixed seed) from
`GrimoirePalette` hexes only — regenerate by re-running the script, never hand-edit:

- `parchment_tile.png` — 256px seamless aged-parchment texture (PARCHMENT base, fibre + mottle).
- `parchment_frame.png` — 96px 9-patch panel frame (parchment fill, 3px BRASS double-rule border,
  corner notches); consumed by `GrimoireTheme`'s `ParchmentPanel` StyleBoxTexture (24px margins).
- `boot_splash.png` — 1152x648 boot splash (Wave 6): the brass eight-point sigil star + ring on
  INK, pure geometry (no rng); wired via `application/boot_splash` in `project.godot` (bg = INK).
