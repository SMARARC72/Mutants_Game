# Tiles — repo-authored AI art, processed by tools/make_tiles.py

## Wave 6.5 (overworld terrain thin slice)

`topdown/*.png` (terrain, RGB 512px, seamless) and `props/*.png` (decal knockouts, RGBA,
tight-cropped): **repo-authored AI art** — sourced from the main repo's gitignored staging area
`/assets/tiles/topdown/TILE-031..060` (30 painterly 512px plates generated for this project) and
processed deterministically by `tools/make_tiles.py` (frame/plate crop, offset-wrap + cross-fade
seamless, background knockout for props). The raw plates' FILENAMES ARE UNRELIABLE; the by-eye
audit that maps each raw plate to its true content, role, and output asset is
`tools/tile_remap.json`. No third-party assets. Binaries commit via Git LFS.

Earlier files `topdown/eros-bloom.png` + `topdown/worn-path.png` (Phase 7) share the same
provenance (repo-authored AI art, curated crops of the same plate set); superseded by the Wave 6.5
set but kept as fallbacks.

## Wave 12 (overworld depth)

`topdown/normal/<name>_n.png`: tangent-space normal maps DERIVED from the shipped
`topdown/*.png` diffuse tiles by `tools/gen_normalmaps.py` (blurred-luminance height field,
wrap-edge Sobel, OpenGL packing) — no external sources. `OverworldTileSet.build()` composes them
into a normal atlas paired with the diffuse atlas in one `CanvasTexture` so the player's
PointLight2D shades the ground. Regenerate: `python tools/gen_normalmaps.py` (PIL + numpy only).
Binaries commit via Git LFS.

## W-DRESS (overworld structures)

`structures/*.png` + `structures/structures.json`: landmark STRUCTURE cutouts (temple, ruin,
market stall, ascension altar, summon portal, forge, bridge, grove) — **repo-authored AI art**,
sourced from the main repo's gitignored staging area `/assets/tiles/iso/TILE-021..030` (painterly
512px iso dioramas generated for this project; filenames eye-verified against a rendered contact
sheet) and processed deterministically by `tools/make_structures.py`. The raw plates flattened
their transparency to pure black (the shipped alpha channel is junk), so the pipeline
RECONSTRUCTS each structure body: stroke threshold -> morphological close -> main-cluster keep ->
border flood hole-fill -> solid grimoire-ink wash behind the painted strokes. TILE-021
(graveyard plot) was REJECTED on the QA sheet (too sparse to reconstruct). The manifest maps
semantic id -> texture / height_tiles / blocking footprint; `OverworldStructures` consumes it.
No third-party assets. Binaries commit via Git LFS.
