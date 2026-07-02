# UI assets — Kenney (CC0)

CC0 (public domain), no attribution required. The full Kenney UI Pack + UI Pack RPG
Expansion now live in the local library `../_asset-library/kenney/` (NOT committed;
`LICENSE_NOTES.md` there). Source: https://kenney.nl/assets

**Curation verdict (2026-07-02, wave/w-oss-assets):** Kenney's `panel_beige` /
`panelInset_beige` were recolored to the GrimoirePalette via PIL and QA-sheeted against
the first-party `parchment_frame.png`. The Kenney panels read flat/cartoony (rounded
vector, no texture, weak border) — NOT visibly superior to the painterly first-party
frame, so nothing shipped. They remain library-only wireframing material.

## Procedural grimoire surfaces (Wave 4 — first-party, no license concerns)

Generated deterministically by `tools/gen_ui_kit.py` (PIL + numpy, fixed seed) from
`GrimoirePalette` hexes only — regenerate by re-running the script, never hand-edit:

- `parchment_tile.png` — 256px seamless aged-parchment texture (PARCHMENT base, fibre + mottle).
- `parchment_frame.png` — 96px 9-patch panel frame (parchment fill, 3px BRASS double-rule border,
  corner notches); consumed by `GrimoireTheme`'s `ParchmentPanel` StyleBoxTexture (24px margins).
- `boot_splash.png` — 1152x648 boot splash (Wave 6): the brass eight-point sigil star + ring on
  INK, pure geometry (no rng); wired via `application/boot_splash` in `project.godot` (bg = INK).
