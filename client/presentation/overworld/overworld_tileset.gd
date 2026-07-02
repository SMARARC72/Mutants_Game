class_name OverworldTileSet
extends RefCounted
## OverworldTileSet (Wave 6.5 · terrain thin slice) — builds the overworld TileMapLayer's TileSet
## from a Layout's small int palette (0=ground, 1=feature, 2=path, 3=wall; -1=void). PRESENTATION.
##
## The tile-id MEANING is unchanged from the spine (the headless try_move/walkability tests are
## untouched): WALKABLE = everything except the wall id (3) and void (-1). What changed is the
## LOOK — every force-climate now resolves to a REAL curated terrain set (hero ground + two ground
## variants + path + a DISTINCT wall texture + a ritual/thin-place accent), processed seamless by
## tools/make_tiles.py from the audited plates in tools/tile_remap.json. Walls are their own art
## (cliff strata / stone brick), never a tinted ground. If a texture is missing the cell falls
## back to a flat swatch, so the scene still builds headless.

const TILE_SIZE := 64
const WALL_TILE := 3
const VOID_TILE := -1
const FEATURE_TILE := 1
## Extra atlas column for the ritual/thin-place accent. Layouts never emit it; paint() promotes a
## deterministic minority of feature cells to it, so thin places visibly manifest on the map.
const RITUAL_TILE := 4

## Flat-swatch fallback palette (used only if a real texture fails to load) — keeps scenes building.
const TILE_COLORS := {
	0: Color(0.22, 0.42, 0.26),
	1: Color(0.34, 0.55, 0.30),
	2: Color(0.46, 0.40, 0.26),
	3: Color(0.11, 0.10, 0.13),
	4: Color(0.30, 0.18, 0.38),
}
const VOID_COLOR := Color(0.05, 0.045, 0.06)

## The ground tile id and how many texture-variant rows its atlas column carries. Ground cells pick
## a hashed row (hero-weighted, see _atlas_coord) × a per-cell flip, so one region reads as varied
## terrain instead of a repeated square.
const GROUND_TILE := 0
const GROUND_VARIANTS := 3

const _T := "res://assets/tiles/topdown/"
const _P := "res://assets/tiles/props/"
const _W := Color(1, 1, 1)
const _FLAT_NORMAL := Color(0.5, 0.5, 1.0)  # tangent-space "straight up" (unshaded fallback)

## Region force-climate palettes: force -> {ground: [[texture, modulate] hero/common/rare],
## feature/path/wall/ritual: [texture, modulate]}. Textures are the semantic outputs of
## tools/make_tiles.py; modulates are gentle force-tints only (walls are DISTINCT art, not tints).
const PALETTES := {
	"Eros":
	{
		0:
		[
			[_T + "moss-bloom-meadow.png", _W],
			[_T + "forest-floor.png", Color(0.98, 1.0, 0.95)],
			[_T + "bloom-tapestry.png", _W],
		],
		1: [_T + "tidewater.png", _W],
		2: [_T + "mossy-cobble-path.png", _W],
		3: [_T + "cliff-wall.png", Color(0.86, 0.92, 0.86)],
		4: [_T + "ritual-circle.png", _W],
	},
	"Gaia":
	{
		0:
		[
			[_T + "amber-grass.png", _W],
			[_T + "sand-dunes.png", _W],
			[_T + "forest-floor.png", _W],
		],
		1: [_T + "stone-slabs.png", _W],
		2: [_T + "mossy-cobble-path.png", Color(1.02, 0.98, 0.9)],
		3: [_T + "cliff-wall.png", _W],
		4: [_T + "sigil-slab.png", _W],
	},
	"Ouranos":
	{
		0:
		[
			[_T + "cloud-field.png", _W],
			[_T + "tundra-frost.png", _W],
			[_T + "ice-cracks.png", _W],
		],
		1: [_T + "ice-cracks.png", _W],
		2: [_T + "mossy-cobble-path.png", Color(0.9, 0.95, 1.06)],
		3: [_T + "stone-brick-wall.png", Color(0.72, 0.78, 0.92)],
		4: [_T + "ritual-circle.png", Color(0.85, 0.95, 1.15)],
	},
	"Cosmos":
	{
		0:
		[
			[_T + "order-floor.png", _W],
			[_T + "order-floor.png", Color(0.92, 0.92, 0.96)],
			[_T + "stone-slabs.png", _W],
		],
		1: [_T + "crystal-cavern.png", _W],
		2: [_T + "mossy-cobble-path.png", Color(1.0, 1.0, 1.05)],
		3: [_T + "stone-brick-wall.png", Color(0.82, 0.82, 0.95)],
		4: [_T + "sigil-slab.png", _W],
	},
	"Chaos":
	{
		0:
		[
			[_T + "basalt-lava.png", _W],
			[_T + "lava-flow.png", _W],
			[_T + "basalt-lava.png", Color(0.8, 0.78, 0.8)],
		],
		1: [_T + "lava-flow.png", _W],
		2: [_T + "mossy-cobble-path.png", Color(0.85, 0.75, 0.7)],
		3: [_T + "cliff-wall.png", Color(0.72, 0.66, 0.68)],
		4: [_T + "ritual-circle.png", Color(1.1, 0.85, 0.8)],
	},
	"Thanatos":
	{
		0:
		[
			[_T + "grave-ash.png", _W],
			[_T + "grave-ash.png", Color(0.9, 0.88, 0.92)],
			[_T + "grave-ash.png", Color(1.06, 1.04, 1.08)],
		],
		1: [_T + "void-null.png", _W],
		2: [_T + "mossy-cobble-path.png", Color(0.85, 0.82, 0.88)],
		3: [_T + "cliff-wall.png", Color(0.8, 0.78, 0.85)],
		4: [_T + "ritual-circle.png", _W],
	},
	"Cosmos+Gaia":
	{
		0:
		[
			[_T + "stone-slabs.png", _W],
			[_T + "order-floor.png", Color(0.9, 0.9, 0.92)],
			[_T + "stone-slabs.png", Color(0.9, 0.9, 0.9)],
		],
		1: [_T + "crystal-cavern.png", _W],
		2: [_T + "mossy-cobble-path.png", _W],
		3: [_T + "stone-brick-wall.png", Color(0.9, 0.88, 0.86)],
		4: [_T + "sigil-slab.png", _W],
	},
	"Ouranos+Gaia":
	{
		0:
		[
			[_T + "reef-shallows.png", _W],
			[_T + "tidewater.png", _W],
			[_T + "sand-dunes.png", _W],
		],
		1: [_T + "tidewater.png", _W],
		2: [_T + "sand-dunes.png", Color(0.95, 0.95, 0.9)],
		3: [_T + "cliff-wall.png", Color(0.85, 0.9, 0.95)],
		4: [_T + "ritual-circle.png", Color(0.9, 1.0, 1.1)],
	},
	# E1b — the three force combos the eleven-region catalog adds. Threshold (neutral): the last
	# mortal city — flagstones, cobbled lanes, a canal, Standstill ward-slabs. The Maw Beneath
	# (Chaos+Thanatos): ash over cooling rot, bruise-lit Rot pools. The Hollow Atelier
	# (Cosmos+Chaos): ordered drafting floor smeared with un-rendered void patches.
	"neutral":
	{
		0:
		[
			[_T + "stone-slabs.png", _W],
			[_T + "order-floor.png", Color(0.95, 0.93, 0.9)],
			[_T + "amber-grass.png", Color(0.92, 0.92, 0.88)],
		],
		1: [_T + "tidewater.png", Color(0.9, 0.95, 1.0)],
		2: [_T + "mossy-cobble-path.png", _W],
		3: [_T + "stone-brick-wall.png", _W],
		4: [_T + "sigil-slab.png", _W],
	},
	"Chaos+Thanatos":
	{
		0:
		[
			[_T + "grave-ash.png", _W],
			[_T + "basalt-lava.png", Color(0.85, 0.8, 0.85)],
			[_T + "void-null.png", Color(1.05, 1.0, 1.1)],
		],
		1: [_T + "lava-flow.png", Color(0.8, 0.6, 0.78)],
		2: [_T + "mossy-cobble-path.png", Color(0.75, 0.68, 0.78)],
		3: [_T + "cliff-wall.png", Color(0.7, 0.66, 0.75)],
		4: [_T + "ritual-circle.png", Color(1.05, 0.8, 1.1)],
	},
	"Cosmos+Chaos":
	{
		0:
		[
			[_T + "order-floor.png", _W],
			[_T + "order-floor.png", Color(0.9, 0.9, 0.98)],
			[_T + "void-null.png", Color(1.1, 1.05, 1.15)],
		],
		1: [_T + "crystal-cavern.png", _W],
		2: [_T + "mossy-cobble-path.png", Color(1.0, 1.0, 1.08)],
		3: [_T + "stone-brick-wall.png", Color(0.85, 0.82, 0.95)],
		4: [_T + "sigil-slab.png", Color(1.05, 1.0, 1.1)],
	},
}
const _DEFAULT_FORCE := "Eros"

## Per-force prop decals (RGBA knockouts from tools/make_tiles.py) scattered on feature cells by
## the overworld screen via prop_texture(). Order matters: the per-cell hash indexes this list.
const PROPS := {
	"Eros": [_P + "moss-mound.png", _P + "ward-stone.png"],
	"Gaia": [_P + "rock-ledge.png", _P + "moss-mound.png"],
	"Ouranos": [_P + "crystal-cluster.png", _P + "ward-stone.png"],
	"Cosmos": [_P + "crystal-cluster.png", _P + "ruin-bricks.png"],
	"Chaos": [_P + "rock-ledge.png", _P + "crystal-cluster.png"],
	"Thanatos": [_P + "bone-pile.png", _P + "ward-stone.png"],
	"Cosmos+Gaia": [_P + "ruin-bricks.png", _P + "crystal-cluster.png"],
	"Ouranos+Gaia": [_P + "moss-mound.png", _P + "ward-stone.png"],
	"neutral": [_P + "ruin-bricks.png", _P + "ward-stone.png"],
	"Chaos+Thanatos": [_P + "bone-pile.png", _P + "rock-ledge.png"],
	"Cosmos+Chaos": [_P + "crystal-cluster.png", _P + "ruin-bricks.png"],
}

## Wave 12 y-sort: believable prop HEIGHT in tiles, keyed by texture stem. Tall props (ward
## stones, crystal growths) reach ~1.4 tiles so an actor can visibly walk BEHIND them; mounds
## and bone piles stay squat. Unlisted props fall back to just under one tile.
const PROP_HEIGHTS := {
	"ward-stone": 1.4,
	"crystal-cluster": 1.35,
	"ruin-bricks": 1.05,
	"rock-ledge": 1.0,
	"moss-mound": 0.9,
	"bone-pile": 0.8,
}

const _REGION_CATALOG := "res://catalog/region_layouts.json"

## region id -> force cache (loaded once from the region catalog).
static var _region_forces: Dictionary = {}

## Wave 6 spike diet: built TileSets cached per force-climate. A rebuild measured 55.8ms on
## EVERY battle return; the atlas is a pure function of the force palette, so one build per
## force serves the whole session (the TileSet is shared read-only by the map layer).
static var _built_sets: Dictionary = {}


## True if a tile id can be walked onto (everything but the wall id and the void sentinel).
static func is_walkable(tile_id: int) -> bool:
	return tile_id != WALL_TILE and tile_id != VOID_TILE


## The force-climate palette key for a region id ("verdant_glut" -> "Eros"), read from
## res://catalog/region_layouts.json. Compound forces resolve to their own palette when one
## exists, else to their first "+" token; unknown regions/forces fall back to the default.
static func force_for_region(region_id: String) -> String:
	if _region_forces.is_empty():
		_region_forces = _load_region_forces()
	var force := str(_region_forces.get(region_id, _DEFAULT_FORCE))
	if PALETTES.has(force):
		return force
	var head := force.get_slice("+", 0)
	if PALETTES.has(head):
		return head
	return _DEFAULT_FORCE


static func _load_region_forces() -> Dictionary:
	var out := {"": _DEFAULT_FORCE}  # never-empty sentinel so a failed load is not re-read
	var f := FileAccess.open(_REGION_CATALOG, FileAccess.READ)
	if f == null:
		return out
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		return out
	var raw: Variant = (parsed as Dictionary).get("regions", {})
	if not (raw is Dictionary):
		return out
	var regions: Dictionary = raw
	for region_id in regions:
		var entry: Variant = regions[region_id]
		if entry is Dictionary:
			out[str(region_id)] = str((entry as Dictionary).get("force", _DEFAULT_FORCE))
	return out


## The prop decal texture for a feature cell, or null when the cell gets no prop (most cells:
## props land on a deterministic ~1-in-5 of feature cells, and never on thin-place cells, which
## already read as ritual ground). Pure function of (force, x, y) — stable across rebuilds.
static func prop_texture(force_climate: String, x: int, y: int) -> Texture2D:
	if is_thin_place(x, y):
		return null
	if absi((x * 83492791) ^ (y * 52237)) % 5 != 1:
		return null
	var pool: Array = PROPS.get(force_climate, PROPS[_DEFAULT_FORCE])
	var pick := absi((x * 40503) ^ (y * 2654435761)) % pool.size()
	var path := str(pool[pick])
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


## Deterministic thin-place pick: ~1-in-7 feature cells render as the ritual accent tile.
static func is_thin_place(x: int, y: int) -> bool:
	return absi((x * 92821) ^ (y * 68917)) % 7 == 0


## The believable height (in tiles) a scattered prop should stand, from PROP_HEIGHTS by the
## texture's file stem. Pure function; unknown textures read just under a tile.
static func prop_height_tiles(tex: Texture2D) -> float:
	if tex == null:
		return 0.95
	var stem := tex.resource_path.get_file().get_basename()
	return float(PROP_HEIGHTS.get(stem, 0.95))


## Build a TileSet whose source 0 is a real-terrain atlas. Column = tile id. The GROUND column
## stacks GROUND_VARIANTS texture rows (atlas coords (0, 0..2) = hero/common/rare ground); every
## other id sits at row 0. So set_cell(pos, 0, Vector2i(tile_id, 0)) Just Works for non-ground,
## and ground uses (0, variant). `force_climate` picks the region palette (see force_for_region);
## unknown forces fall back to the default. Cached per force (Wave 6 spike diet).
static func build(force_climate: String = _DEFAULT_FORCE) -> TileSet:
	var cached: Variant = _built_sets.get(force_climate)
	if cached is TileSet:
		return cached
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
	# Wave 12: a parallel NORMAL atlas (tools/gen_normalmaps.py outputs) with the same geometry.
	# TileSetAtlasSource has no normal slot; the pair ships as ONE CanvasTexture below.
	var normals := Image.create(
		(max_id + 1) * TILE_SIZE, GROUND_VARIANTS * TILE_SIZE, false, Image.FORMAT_RGBA8
	)
	normals.fill(_FLAT_NORMAL)
	var normal_found := false
	var full := Rect2i(0, 0, TILE_SIZE, TILE_SIZE)
	for id in ids:
		if int(id) == GROUND_TILE:
			var variants: Array = palette[id]
			for v in GROUND_VARIANTS:
				var entry: Array = variants[v % variants.size()]
				var gimg := _tile_image(str(entry[0]), entry[1] as Color, int(id))
				var gat := Vector2i(int(id) * TILE_SIZE, v * TILE_SIZE)
				atlas.blit_rect(gimg, full, gat)
				normal_found = _blit_normal(normals, str(entry[0]), gat) or normal_found
		else:
			var entry: Array = palette[id]
			var tile_img := _tile_image(str(entry[0]), entry[1] as Color, int(id))
			var at := Vector2i(int(id) * TILE_SIZE, 0)
			atlas.blit_rect(tile_img, full, at)
			normal_found = _blit_normal(normals, str(entry[0]), at) or normal_found
	var texture: Texture2D = ImageTexture.create_from_image(atlas)
	if normal_found:
		# The diffuse+normal pair rides a CanvasTexture (a Texture2D, so the atlas source takes
		# it directly) — this is how TileMapLayer cells react to Light2D in Godot 4. Flipped/
		# transposed cell orientations shade slightly off-axis; at this strength it never reads.
		var lit := CanvasTexture.new()
		lit.diffuse_texture = texture
		lit.normal_texture = ImageTexture.create_from_image(normals)
		texture = lit

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
	_built_sets[force_climate] = tile_set
	return tile_set


## Blit `path`'s generated normal map (…/normal/<stem>_n.png, from tools/gen_normalmaps.py) into
## the normal atlas at `at`. Returns true when a real normal map landed; on a miss the flat-normal
## fill stays for that cell (correct, just unshaded).
static func _blit_normal(normals: Image, path: String, at: Vector2i) -> bool:
	var npath := path.get_base_dir() + "/normal/" + path.get_file().get_basename() + "_n.png"
	if not ResourceLoader.exists(npath):
		return false
	var tex := load(npath) as Texture2D
	if tex == null:
		return false
	var img := tex.get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(TILE_SIZE, TILE_SIZE, Image.INTERPOLATE_LANCZOS)
	normals.blit_rect(img, Rect2i(0, 0, TILE_SIZE, TILE_SIZE), at)
	return true


## One cell texture: load the (pre-cropped, seamless) plate, downscale to the cell, tint. Falls
## back to the flat swatch if the texture is absent so the overworld still renders.
static func _tile_image(path: String, modulate: Color, tile_id: int) -> Image:
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	if tex == null:
		var flat := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
		flat.fill(TILE_COLORS.get(tile_id, VOID_COLOR))
		return flat
	var img := tex.get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(TILE_SIZE, TILE_SIZE, Image.INTERPOLATE_LANCZOS)
	if modulate == _W:
		return img
	for py in TILE_SIZE:
		for px in TILE_SIZE:
			var c := img.get_pixel(px, py)
			c.r = clampf(c.r * modulate.r, 0.0, 1.0)
			c.g = clampf(c.g * modulate.g, 0.0, 1.0)
			c.b = clampf(c.b * modulate.b, 0.0, 1.0)
			c.a = clampf(c.a * modulate.a, 0.0, 1.0)  # preserve source alpha (soft edges)
			img.set_pixel(px, py, c)
	return img


## Paint a Layout onto a TileMapLayer (source 0; atlas coords == tile id). Skips void cells. Each
## cell gets a DETERMINISTIC flip/transpose so the source textures read as organic terrain
## (8 orientations) instead of a visibly repeating grid, and a deterministic minority of feature
## cells promote to the RITUAL_TILE accent (thin places). Validity is checked against the tiles
## the layer's OWN TileSet actually has (whatever force palette built it), so no region's tiles
## are wrongly skipped. The layer must already have a TileSet from build(). Returns it.
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
			if tile_id == FEATURE_TILE:
				if is_thin_place(x, y):
					var ritual := Vector2i(RITUAL_TILE, 0)
					if source != null and source.has_tile(ritual):
						coord = ritual
				else:
					# Ordinary feature cells read as GROUND (props + thin places carry
					# the accent): full-tile feature textures peppered the map as a
					# salt-and-pepper checkerboard.
					coord = _atlas_coord(GROUND_TILE, x, y)
			if source == null or not source.has_tile(coord):
				continue
			var flip_x := x / 3 if coord.x == GROUND_TILE else x
			var flip_y := y / 3 if coord.x == GROUND_TILE else y
			layer.set_cell(Vector2i(x, y), 0, coord, _cell_orientation(flip_x, flip_y))
	return layer


## Atlas coord for a cell: ground picks one of its texture-variant rows with a hero-weighted hash
## sampled per 3x3 BLOB (72% hero / 22% common / 6% rare) so variant terrain arrives as coherent
## patches, not per-cell salt-and-pepper; everything else uses its row-0 tile.
static func _atlas_coord(tile_id: int, x: int, y: int) -> Vector2i:
	if tile_id == GROUND_TILE:
		var bx := x / 3
		var by := y / 3
		var pct := absi((bx * 2654435761) ^ (by * 40503)) % 100
		var row := 0
		if pct >= 94:
			row = 2
		elif pct >= 72:
			row = 1
		return Vector2i(GROUND_TILE, row)
	return Vector2i(tile_id, 0)


## A stable transform (flip-h / flip-v / transpose bits) hashed from the given coords. Ground
## passes BLOB coords (flips inside a seamless texture break edge continuity, so orientation
## changes only at 3x3 patch boundaries); other tiles pass cell coords. Deterministic.
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
