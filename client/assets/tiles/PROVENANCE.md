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
