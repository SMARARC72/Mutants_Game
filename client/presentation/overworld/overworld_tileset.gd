class_name OverworldTileSet
extends RefCounted
## OverworldTileSet (Phase 5 · Slice 1) — builds a code-only TileSet for the overworld TileMapLayer
## from a Layout's small int tile palette (0=ground, 1=feature, 2=path, 3=wall; -1=void). PRESENTATION
## layer. No art dependency for the spine: each tile id maps to a flat colour swatch generated at
## runtime (an ImageTexture), so the overworld renders headlessly-buildable and self-contained until
## the real Verdant tileset art is wired (a later art slice swaps these swatches for real atlases).
##
## The Layout tile-id meaning mirrors catalog/region_layouts.json's `_tiles` doc. WALKABLE tile ids
## are everything except the wall id (3) and void (-1) — the overworld uses `is_walkable` for
## collision against the grid.

const TILE_SIZE := 16
const WALL_TILE := 3
const VOID_TILE := -1

## Verdant-leaning swatch palette per tile id (cosmetic placeholder, design §2 ink/verdure).
const TILE_COLORS := {
	0: Color(0.22, 0.42, 0.26),  # ground — mossy green
	1: Color(0.34, 0.55, 0.30),  # feature — brighter verdure / fungal bloom
	2: Color(0.46, 0.40, 0.26),  # path — trodden earth
	3: Color(0.11, 0.10, 0.13),  # wall/edge — ink
}
const VOID_COLOR := Color(0.05, 0.045, 0.06)


## True if a tile id can be walked onto (everything but the wall id and the void sentinel).
static func is_walkable(tile_id: int) -> bool:
	return tile_id != WALL_TILE and tile_id != VOID_TILE


## Build a TileSet whose source 0 is a flat-colour atlas with one cell per palette tile id. The
## atlas coords equal the tile id (so set_cell(coords, 0, Vector2i(tile_id, 0)) Just Works).
static func build() -> TileSet:
	var ids := TILE_COLORS.keys()
	ids.sort()
	var max_id := 0
	for id in ids:
		max_id = maxi(max_id, int(id))
	var atlas_width := max_id + 1
	var image := Image.create(atlas_width * TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(VOID_COLOR)
	for id in ids:
		var color: Color = TILE_COLORS[id]
		var x0 := int(id) * TILE_SIZE
		for px in TILE_SIZE:
			for py in TILE_SIZE:
				image.set_pixel(x0 + px, py, color)
	var texture := ImageTexture.create_from_image(image)

	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for id in ids:
		source.create_tile(Vector2i(int(id), 0))
	tile_set.add_source(source, 0)
	return tile_set


## Paint a Layout onto a TileMapLayer (source 0; atlas coords = tile id). Skips void cells. The
## layer must already have a TileSet from build(). Returns the TileMapLayer for chaining.
static func paint(layer: TileMapLayer, layout: Layout) -> TileMapLayer:
	for y in layout.height:
		for x in layout.width:
			var tile_id := layout.get_cell(x, y)
			if tile_id == VOID_TILE or not TILE_COLORS.has(tile_id):
				continue
			layer.set_cell(Vector2i(x, y), 0, Vector2i(tile_id, 0))
	return layer
