class_name OverworldTileSet
extends RefCounted
## OverworldTileSet (Phase 7 · overworld visuals) — builds the overworld TileMapLayer's TileSet from
## a Layout's small int palette (0=ground, 1=feature, 2=path, 3=wall; -1=void). PRESENTATION layer.
##
## The tile-id MEANING is unchanged from the spine (so the headless try_move/walkability tests are
## untouched): WALKABLE = everything except the wall id (3) and void (-1). What changed is the LOOK —
## each id now samples a real painterly terrain texture (curated under res://assets/tiles/topdown),
## centre-cropped to drop the source plate's vignette border, downscaled to the cell, and tinted per
## force-climate. If a texture is missing it falls back to the flat swatch, so the scene still builds.

const TILE_SIZE := 64
const WALL_TILE := 3
const VOID_TILE := -1

## Flat-swatch fallback palette (used only if a real texture fails to load) — keeps the scene building.
const TILE_COLORS := {
	0: Color(0.22, 0.42, 0.26),
	1: Color(0.34, 0.55, 0.30),
	2: Color(0.46, 0.40, 0.26),
	3: Color(0.11, 0.10, 0.13),
}
const VOID_COLOR := Color(0.05, 0.045, 0.06)

## Fraction cropped off EACH edge of a source plate before downscale, to drop its painterly vignette
## (a deeper crop = flatter, more uniform cell edges = far less visible grid seam).
const _VIGNETTE_INSET := 0.18

## The ground tile id, and how many brightness variants of it the atlas carries. Painting ground with
## a per-cell variant (× the per-cell flip) turns one source texture into many reads, killing the
## "same square repeated" grid look without more art.
const GROUND_TILE := 0
const GROUND_VARIANTS := 3
const _GROUND_VAR_BRIGHT := [0.88, 1.0, 1.12]

## Region force-climate palettes: force name -> {tile_id: [texture_path, modulate]}. The modulate
## multiplies the sampled pixels so ONE ground texture yields distinct ground/feature/wall reads
## (brighter bloom for features, deep ink for impassable walls) until more terrain plates are curated.
const _GROUND_EROS := "res://assets/tiles/topdown/eros-bloom.png"
const _GROUND_PATH := "res://assets/tiles/topdown/worn-path.png"

const PALETTES := {
	"Eros":
	{
		0: [_GROUND_EROS, Color(0.90, 0.96, 0.84)],
		1: [_GROUND_EROS, Color(1.22, 1.16, 0.92)],
		2: [_GROUND_PATH, Color(1.0, 0.98, 0.94)],
		3: [_GROUND_EROS, Color(0.24, 0.26, 0.30)],
	}
}
const _DEFAULT_FORCE := "Eros"


## True if a tile id can be walked onto (everything but the wall id and the void sentinel).
static func is_walkable(tile_id: int) -> bool:
	return tile_id != WALL_TILE and tile_id != VOID_TILE


## Build a TileSet whose source 0 is a real-terrain atlas. Column = tile id. The GROUND column also
## stacks GROUND_VARIANTS brightness rows (atlas coords (0,0..2)); every other id sits at row 0. So
## set_cell(pos, 0, Vector2i(tile_id, 0)) Just Works for non-ground, and ground uses (0, variant).
## `force_climate` picks the region palette; unknown forces fall back to the default.
static func build(force_climate: String = _DEFAULT_FORCE) -> TileSet:
	var palette: Dictionary = PALETTES.get(force_climate, PALETTES[_DEFAULT_FORCE])
	var ids := palette.keys()
	ids.sort()
	var max_id := 0
	for id in ids:
		max_id = maxi(max_id, int(id))
	var atlas := Image.create(
		(max_id + 1) * TILE_SIZE, GROUND_VARIANTS * TILE_SIZE, false, Image.FORMAT_RGBA8
	)
	atlas.fill(VOID_COLOR)
	var full := Rect2i(0, 0, TILE_SIZE, TILE_SIZE)
	for id in ids:
		var entry: Array = palette[id]
		var base_mod := entry[1] as Color
		if int(id) == GROUND_TILE:
			for v in GROUND_VARIANTS:
				var b: float = _GROUND_VAR_BRIGHT[v]
				var vmod := Color(base_mod.r * b, base_mod.g * b, base_mod.b * b, base_mod.a)
				var gimg := _tile_image(str(entry[0]), vmod, int(id))
				atlas.blit_rect(gimg, full, Vector2i(int(id) * TILE_SIZE, v * TILE_SIZE))
		else:
			var tile_img := _tile_image(str(entry[0]), base_mod, int(id))
			atlas.blit_rect(tile_img, full, Vector2i(int(id) * TILE_SIZE, 0))
	var texture := ImageTexture.create_from_image(atlas)

	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for id in ids:
		if int(id) == GROUND_TILE:
			for v in GROUND_VARIANTS:
				source.create_tile(Vector2i(int(id), v))
		else:
			source.create_tile(Vector2i(int(id), 0))
	tile_set.add_source(source, 0)
	return tile_set


## One cell texture: load the plate, centre-crop the vignette, downscale to the cell, tint. Falls
## back to the flat swatch if the texture is absent so the overworld still renders.
static func _tile_image(path: String, modulate: Color, tile_id: int) -> Image:
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	if tex == null:
		var flat := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
		flat.fill(TILE_COLORS.get(tile_id, VOID_COLOR))
		return flat
	var img := tex.get_image()
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var ix := int(w * _VIGNETTE_INSET)
	var iy := int(h * _VIGNETTE_INSET)
	var region := img.get_region(Rect2i(ix, iy, w - 2 * ix, h - 2 * iy))
	region.resize(TILE_SIZE, TILE_SIZE, Image.INTERPOLATE_LANCZOS)
	for py in TILE_SIZE:
		for px in TILE_SIZE:
			var c := region.get_pixel(px, py)
			c.r = clampf(c.r * modulate.r, 0.0, 1.0)
			c.g = clampf(c.g * modulate.g, 0.0, 1.0)
			c.b = clampf(c.b * modulate.b, 0.0, 1.0)
			c.a = clampf(c.a * modulate.a, 0.0, 1.0)  # preserve source alpha (soft edges/overlays)
			region.set_pixel(px, py, c)
	return region


## Paint a Layout onto a TileMapLayer (source 0; atlas coords == tile id). Skips void cells. Each
## cell gets a DETERMINISTIC flip/transpose so the single source texture reads as organic terrain
## (8 orientations) instead of a visibly repeating grid. Validity is checked against the tiles the
## layer's OWN TileSet actually has (whatever force palette built it), so no region's tiles are
## wrongly skipped. The layer must already have a TileSet from build(). Returns it for chaining.
static func paint(layer: TileMapLayer, layout: Layout) -> TileMapLayer:
	var source: TileSetAtlasSource = null
	if layer.tile_set != null and layer.tile_set.get_source_count() > 0:
		source = layer.tile_set.get_source(0) as TileSetAtlasSource
	for y in layout.height:
		for x in layout.width:
			var tile_id := layout.get_cell(x, y)
			if tile_id == VOID_TILE:
				continue
			var coord := _atlas_coord(tile_id, x, y)
			if source == null or not source.has_tile(coord):
				continue
			layer.set_cell(Vector2i(x, y), 0, coord, _cell_orientation(x, y))
	return layer


## Atlas coord for a cell: ground picks one of its brightness variants (hashed from the cell so it's
## stable), everything else uses its single row-0 tile.
static func _atlas_coord(tile_id: int, x: int, y: int) -> Vector2i:
	if tile_id == GROUND_TILE:
		return Vector2i(GROUND_TILE, absi((x * 2654435761) ^ (y * 40503)) % GROUND_VARIANTS)
	return Vector2i(tile_id, 0)


## A stable per-cell transform (flip-h / flip-v / transpose bits) hashed from the cell coords, so the
## same map always varies the same way (determinism) while breaking the repeated-texture grid look.
static func _cell_orientation(x: int, y: int) -> int:
	var hsh := absi((x * 73856093) ^ (y * 19349663))
	var alt := 0
	if hsh & 1:
		alt |= TileSetAtlasSource.TRANSFORM_FLIP_H
	if hsh & 2:
		alt |= TileSetAtlasSource.TRANSFORM_FLIP_V
	if hsh & 4:
		alt |= TileSetAtlasSource.TRANSFORM_TRANSPOSE
	return alt
