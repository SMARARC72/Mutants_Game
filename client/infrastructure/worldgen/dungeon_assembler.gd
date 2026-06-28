class_name DungeonAssembler
extends RefCounted
## DungeonAssembler — the SimpleDungeons set-piece layer (D5, ADR-014). INFRASTRUCTURE layer:
## prefab-room procedural ASSEMBLY for authored occult set-pieces (boss lairs, ritual sites). It
## STITCHES authored room prefabs onto a grid and stamps their floor/wall tiles; it computes NO
## gameplay number (purity gate, Cluster 4 §3). Composes with the WFC fill (WfcSolver): WFC paints
## the organic biome/connective tissue, this stamps the hand-authored rooms ON TOP.
##
## Why self-contained (vs vendoring SimpleDungeons): upstream SimpleDungeons is a runtime SCENE/Node
## graph (rooms-as-PackedScenes, a generator Node walking the tree) that draws placement randomness
## from Godot's own RNG — which, like the WFC addon, cannot satisfy ADR-014's cross-platform
## canonical-PCG32 seeding without forking, and Godot is not installable here to verify a clean 4.7
## vendor (see THIRD_PARTY.md). We implement the deterministic prefab-stitch core (the part the spec
## cares about: "seeded + persisted, behind the same WorldGenerator facade") and keep the upstream
## room-prefab CONCEPT (a prefab = a footprint + a tile stamp + door anchors).
##
## DETERMINISM (ADR-014/001): placement order, room selection, and jitter ALL draw from the injected
## CanonicalRNG sub-stream — never global RNG/wall-clock/thread order. Rooms are placed in a stable
## scan order; a candidate that overlaps an already-placed room (respecting a margin) is rejected and
## the next stable candidate tried. The SAME (set-piece spec, seed) yields a bit-identical stamp.
##
## SET-PIECE SPEC (data): {
##   "tile_floor": int, "tile_wall": int,
##   "rooms": [ { "kind": String, "w": int, "h": int, "count": int (default 1),
##               "tile_floor": int (optional override), "tile_wall": int (optional override) } ],
##   "margin": int (cells kept clear between rooms, default 1),
##   "place_attempts": int (per-room placement tries before giving up, default 64) }
## Each placed room is recorded on Layout.rooms as { kind, x, y, w, h } (top-left origin) for spawn
## anchoring + the minimap. Rooms that cannot be placed are SKIPPED (never overlapped) — assembly
## never fails the whole layout; the WFC fill already guarantees a traversable base.

const DEFAULT_MARGIN := 1
const DEFAULT_PLACE_ATTEMPTS := 64


## Stamp the set-piece rooms of `spec` into `layout` in place, drawing all randomness from `rng`
## (the injected canonical sub-stream). Appends each placed room to layout.rooms. Pure w.r.t. the
## RNG: same (spec, seed, grid size) -> identical placements + tiles.
static func stitch(layout: Layout, spec: Dictionary, rng: CanonicalRNG) -> void:
	if layout == null or spec.is_empty():
		return
	var margin: int = int(spec.get("margin", DEFAULT_MARGIN))
	var place_attempts: int = int(spec.get("place_attempts", DEFAULT_PLACE_ATTEMPTS))
	var default_floor: int = int(spec.get("tile_floor", 0))
	var default_wall: int = int(spec.get("tile_wall", default_floor))
	for room_spec in spec.get("rooms", []):
		var count: int = int((room_spec as Dictionary).get("count", 1))
		for _i in count:
			_place_one(layout, room_spec, default_floor, default_wall, margin, place_attempts, rng)


static func _place_one(
	layout: Layout,
	room_spec: Dictionary,
	default_floor: int,
	default_wall: int,
	margin: int,
	place_attempts: int,
	rng: CanonicalRNG
) -> void:
	var rw: int = int(room_spec.get("w", 1))
	var rh: int = int(room_spec.get("h", 1))
	if rw <= 0 or rh <= 0 or rw > layout.width or rh > layout.height:
		return  # cannot fit at all.
	var floor_tile: int = int(room_spec.get("tile_floor", default_floor))
	var wall_tile: int = int(room_spec.get("tile_wall", default_wall))
	var kind: String = str(room_spec.get("kind", "room"))
	# Try canonical-RNG-chosen origins until one fits without overlapping a placed room (+margin).
	var max_x := layout.width - rw
	var max_y := layout.height - rh
	for _attempt in place_attempts:
		var ox := rng.randint(0, max_x)
		var oy := rng.randint(0, max_y)
		if _fits(layout, ox, oy, rw, rh, margin):
			_stamp(layout, ox, oy, rw, rh, floor_tile, wall_tile)
			layout.rooms.append({"kind": kind, "x": ox, "y": oy, "w": rw, "h": rh})
			return
	# No spot found within budget -> skip this room (never overlap; WFC base stays traversable).


## True if a room at (ox,oy) of size rw*rh, expanded by `margin`, overlaps no already-placed room.
static func _fits(layout: Layout, ox: int, oy: int, rw: int, rh: int, margin: int) -> bool:
	var ax0 := ox - margin
	var ay0 := oy - margin
	var ax1 := ox + rw + margin
	var ay1 := oy + rh + margin
	for placed in layout.rooms:
		var p: Dictionary = placed
		var px: int = int(p["x"])
		var py: int = int(p["y"])
		var pw: int = int(p["w"])
		var ph: int = int(p["h"])
		# AABB overlap test (half-open ranges).
		if ax0 < px + pw and px < ax1 and ay0 < py + ph and py < ay1:
			return false
	return true


## Stamp a room's tiles: a wall ring on the border, floor inside. A 1- or 2-wide room is all wall.
static func _stamp(
	layout: Layout, ox: int, oy: int, rw: int, rh: int, floor_tile: int, wall_tile: int
) -> void:
	for dy in rh:
		for dx in rw:
			var x := ox + dx
			var y := oy + dy
			var is_border := dx == 0 or dy == 0 or dx == rw - 1 or dy == rh - 1
			layout.set_cell(x, y, wall_tile if is_border else floor_tile)
