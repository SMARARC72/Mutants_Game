# MUTANTS_GAME — FRONT-END ASSET REGISTRY

**222 production-ready UI/UX art assets** sliced, background-knocked-out, standardized, and cataloged from the 24 generated sheets — organized the same way as the creature registry. Source of truth: **`asset_registry.csv`** (one row per asset). Art lives in **`assets/`**.

| Category | Count | Sizes / format |
|---|---|---|
| **Icons** (HUD glyphs) | 40 | 256² transparent PNG |
| **Items** (inventory) | 110 | 512² transparent PNG |
| **Tiles** (world + battle) | 72 | iso 512² transparent · top-down 512² opaque · backdrops 1024×576 opaque |
| **TOTAL on disk** | **222** | + 10 duplicates set aside, + 4 backdrops art-pending |

---

## `asset_registry.csv` schema (one row per asset)
`id` · `name` · `category` (icon/item/tile) · `subcategory` · `force` (if force-coded) · `intended_use` · `source_sheet` (uploaded PNG) · `source_prompt` (prompt-pack sheet id) · `cell` (grid r/c) · `file` (path under assets/) · `size` · `bg` (transparent/opaque) · `status` (confirmed / art-pending) · `notes`.

IDs are stable: `ICON-001…040`, `ITEM-001…110`, `TILE-001…076`.

## Folder structure
```
assets/
  icons/   forces(6) ranks(4) stats(8) class(2) skill_verbs(8) acquisition(3) lab_verbs(5) status(4)
  items/   organs cores genes scrap kits_mods mutagens recovery skill_vials essences ritual acquisition  (10 each)
  tiles/   iso(30) topdown(30) backdrop(12)
  _duplicates/      ICON_04 — a duplicate generation of the skill-verb sheet (kept, not registered)
  _contact_sheets/  labeled visual index of every named asset (icons / items / tiles)
```

## Force-coded assets (48) — palette legend
Force is tagged in the registry for force-cores, force gene-strands, force mutagens, force essences, the 6 force icons, and the 6 force-climate tiles. Canon palette:
- **Gaia** earthen brown / stone-grey / moss-green · **Ouranos** sky-blue / white / silver · **Cosmos** white-gold / soft violet / azure · **Chaos** ember red-orange / magenta / smoke-black · **Eros** verdant green / warm gold / rose · **Thanatos** violet-black / bone-white / sickly green.

## Enhancement applied
Every asset was: **sliced** from its sheet → **background knocked out** to transparent (white, dark, and baked-in checkerboard backgrounds all handled via border flood-fill; top-down tiles & backdrops kept full-bleed) → **trimmed** to content → **padded & resized** to standard square canvases → **mild sharpen + contrast** pass. Edges feathered 0.6px.

## Source-sheet → asset map (the 24 uploaded PNGs)
- **Icons:** ICON_01→forces+ranks · ICON_05→stats+class · ICON_02→skill-verbs+acquisition · ICON_03→summon+lab-verbs+status · **ICON_04→duplicate of ICON_02** (in `_duplicates/`).
- **Items:** ITEM_11→organs · ITEM_01→cores · ITEM_03→genes · ITEM_02→scrap · ITEM_04→kits_mods · ITEM_07→mutagens · ITEM_05→recovery · ITEM_06→skill_vials · ITEM_08→essences · ITEM_10→ritual · ITEM_09→acquisition.
- **Tiles:** TILE_01/02/07→iso (grounds/biomes/zones) · TILE_03/04/08→top-down (grounds/biomes/objects) · TILE_05→6 force-climate backdrops · TILE_06→6 biome backdrops.

## Coordination notes (for the design session)
1. **Per-item names within a sheet are best-effort** (assigned by prompt order; the image model mostly preserved order). The `_contact_sheets/` montages show every asset with its assigned name — eyeball them and correct any swapped names directly in `asset_registry.csv`. Category/subcategory/force are reliable.
2. **Duplicate icon sheet** (ICON_04 = a second render of skill-verbs+acquisition) is parked in `assets/_duplicates/`, not registered — delete or swap in if preferred.
3. **4 backdrops art-pending:** the BG-S02 prompt intended 10 biome arenas but the generation delivered 6; rows `TILE-073…076` are `status=art-pending` — regenerate via `Mutants_Game_UIArtPrompts_Tiles.md` (TILE-BG-S02) when ready.
4. **Top-down "object/overlay" tiles** (TILE-051…060: boulder, tree, ward-stone, etc.) rendered as full square tiles rather than transparent overlays — usable as-is, or regenerate on transparent if you want true overlays.
5. **Knockout is non-destructive** to originals: the untouched source sheets remain in your uploads; re-slice anytime.

## How to consume
Query `asset_registry.csv` by `category` + `subcategory` (+ `force`) to pull the right art for any UI surface — inventory slots (items), the HUD (icons: forces/stats/verbs/ranks), the overworld map (tiles/iso or tiles/topdown), and battle screens (tiles/backdrop). Every `file` path is relative to the project root.
