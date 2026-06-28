class_name Layout
extends RefCounted
## Layout — the plain-data result of a region generation (ADR-014). INFRASTRUCTURE layer:
## a serializable tile grid + metadata, NO gameplay math (it lays out tiles; it does not
## compute stats — Cluster 4 §3 / domain-purity gate). Produced by WorldGenerator (WFC fill +
## SimpleDungeons set-piece rooms) and PERSISTED to RunContext.world_state.region_layouts as a
## versioned-JSON dict (ADR-012, never a .tres). On load the stored dict is rehydrated here and
## REUSED — never regenerated (the generate-once invariant, ADR-007/014).
##
## Coordinate convention: `tiles` is a ROW-MAJOR flat Array[int] of length width*height; the cell
## at (x, y) is tiles[y * width + x]. Tile ids are small ints into a region tile palette (the
## meaning of each id is the renderer's concern; -1 is the EMPTY/void sentinel). `rooms` records
## the authored set-piece footprints SimpleDungeons stitched in (for spawn anchoring + minimap).
##
## Schema is versioned so a future tile-format change can migrate old saves (ADR-012). A bare
## numeric JSON value decodes as FLOAT in GDScript (JSON.parse_string: "1" -> 1.0), so every
## numeric read below is int()-wrapped on rehydrate.

const SCHEMA_VERSION := 1
const EMPTY := -1

## The region this layout was generated for (canonical-RNG sub-stream key, ADR-014).
var region_id: String = ""
## The seed the layout was generated from (run.seed). Recorded for audit / reproducibility checks.
var seed: int = 0
var width: int = 0
var height: int = 0
## Row-major flat tile grid, length == width * height. Tile ids index a region palette; EMPTY = void.
var tiles: PackedInt32Array = PackedInt32Array()
## Authored set-piece rooms stitched in by SimpleDungeons:
## [{ "kind": String, "x": int, "y": int, "w": int, "h": int }]. Data only.
var rooms: Array = []
## Free-form generation metadata (e.g. {"source": "wfc", "fallback": false, "attempts": 3}).
var metadata: Dictionary = {}


func _init(p_region_id: String = "", p_seed: int = 0, p_width: int = 0, p_height: int = 0) -> void:
	region_id = p_region_id
	seed = p_seed
	width = p_width
	height = p_height
	tiles = PackedInt32Array()
	if p_width > 0 and p_height > 0:
		tiles.resize(p_width * p_height)
		tiles.fill(EMPTY)


# --- cell access (bounds-checked sugar; no math) --------------------------------------------- #


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height


func get_cell(x: int, y: int) -> int:
	if not in_bounds(x, y):
		return EMPTY
	return tiles[y * width + x]


func set_cell(x: int, y: int, value: int) -> void:
	if in_bounds(x, y):
		tiles[y * width + x] = value


func cell_count() -> int:
	return width * height


## True when every cell holds a non-EMPTY tile id (a complete WFC collapse).
func is_filled() -> bool:
	for t in tiles:
		if t == EMPTY:
			return false
	return true


# --- serialization (versioned-JSON, ADR-012; data only) ------------------------------------- #


## A plain JSON-stringifiable dict mirroring this layout. `tiles` becomes a plain Array[int] so
## it round-trips through JSON (PackedInt32Array is not a JSON primitive). Deep-copies nested
## containers so a caller cannot mutate our state through the returned dict.
func to_dict() -> Dictionary:
	var tile_list: Array = []
	tile_list.resize(tiles.size())
	for i in tiles.size():
		tile_list[i] = tiles[i]
	return {
		"schema_version": SCHEMA_VERSION,
		"region_id": region_id,
		"seed": seed,
		"width": width,
		"height": height,
		"tiles": tile_list,
		"rooms": rooms.duplicate(true),
		"metadata": metadata.duplicate(true),
	}


## Rehydrate a Layout from a persisted dict WITHOUT regenerating (the reuse-on-load path,
## ADR-014). Every numeric field is int()-wrapped because JSON.parse_string decodes bare numbers
## as FLOAT in GDScript (a tile id 1 would otherwise arrive as 1.0 and break PackedInt32Array).
static func from_dict(data: Dictionary) -> Layout:
	var out := Layout.new()
	out.region_id = str(data.get("region_id", ""))
	out.seed = int(data.get("seed", 0))
	out.width = int(data.get("width", 0))
	out.height = int(data.get("height", 0))
	var raw_tiles: Array = data.get("tiles", []) if data.get("tiles", []) is Array else []
	var packed := PackedInt32Array()
	packed.resize(raw_tiles.size())
	for i in raw_tiles.size():
		packed[i] = int(raw_tiles[i])
	out.tiles = packed
	out.rooms = (
		(data.get("rooms", []) as Array).duplicate(true) if data.get("rooms", []) is Array else []
	)
	out.metadata = (
		(data.get("metadata", {}) as Dictionary).duplicate(true)
		if data.get("metadata", {}) is Dictionary
		else {}
	)
	return out


## Structural deep-equality of two layouts' TILES + size (the reproducibility assertion, ADR-014).
## Compares geometry + every tile id; metadata/rooms are excluded (a re-run may carry different
## bookkeeping like attempt counts, but the deterministic OUTPUT — the grid — must be identical).
func tiles_equal(other: Layout) -> bool:
	if other == null:
		return false
	if width != other.width or height != other.height:
		return false
	if tiles.size() != other.tiles.size():
		return false
	for i in tiles.size():
		if tiles[i] != other.tiles[i]:
			return false
	return true
