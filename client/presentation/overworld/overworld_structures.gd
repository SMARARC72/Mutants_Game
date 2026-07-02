class_name OverworldStructures
extends RefCounted
## OverworldStructures (W-DRESS) — painterly LANDMARK STRUCTURES for the overworld: temple,
## ruin, market stall, ascension altar, summon portal, forge, bridge, grove — the repo's iso
## dioramas cut out by tools/make_structures.py and mapped in assets/tiles/structures/
## structures.json. PRESENTATION + a screen-local BLOCKED-SET only:
##   * PLACEMENT is a pure function of (layout, force, home): per force-climate, 2-4 landmarks
##     land on deterministic feature-cell clusters (FNV-1a picks, spaced apart), the LAIR
##     structure (the ascension altar) marks the deep boss-goal region — the run's objective
##     has a VISIBLE destination — and a market stall near spawn anchors the cast;
##   * each structure y-sorts with actors via a feet-level origin (it occludes and is occluded);
##   * its footprint cells join a small OCCUPANCY set the screen's try_move consults — the
##     Layout / worldgen determinism is UNTOUCHED (saves, encounter streams, walkability tests
##     of the spine all read the same Layout they always did).
## LOCAL FNV-1a hashes only (SigilGen.fnv1a_32) — never the canonical RNG streams.

const OverworldTileSetScript := preload("res://presentation/overworld/overworld_tileset.gd")

const DIR := "res://assets/tiles/structures/"
const MANIFEST_PATH := DIR + "structures.json"

## Per-force landmark pools (semantic manifest ids, cycled in order by the placement picks).
## The LAIR structure is the same everywhere — the altar IS the visual language of the climax.
const POOLS := {
	"Eros": ["temple", "grove", "bridge"],
	"Gaia": ["ruin", "bridge", "grove"],
	"Ouranos": ["temple", "bridge", "portal"],
	"Cosmos": ["ruin", "portal", "temple"],
	"Chaos": ["forge", "portal", "ruin"],
	"Thanatos": ["portal", "ruin", "temple"],
	"Cosmos+Gaia": ["ruin", "portal", "bridge"],
	"Ouranos+Gaia": ["bridge", "temple", "grove"],
	# E1b — the eleven-region force combos: the city hub, the rot-sump, the half-drafted atelier.
	"neutral": ["temple", "bridge", "ruin"],
	"Chaos+Thanatos": ["ruin", "forge", "temple"],
	"Cosmos+Chaos": ["temple", "ruin", "bridge"],
}
const DEFAULT_FORCE := "Eros"
const LAIR_ID := "altar"
const HOME_ID := "market_stall"
## E1b — the Threshold-network ritual circle (design §3.5): every region raises ONE waygate
## portal near the spawn field; interacting beside it opens the travel overlay.
const WAYGATE_ID := "portal"

const MIN_LANDMARKS := 2
const MAX_LANDMARKS := 4
const LANDMARK_MIN_HOME_DIST := 6  # landmarks stay off the spawn field
const LANDMARK_SPACING := 5  # min manhattan distance between structure anchors
const HOME_STALL_DIST := [3, 8]  # the cast-anchor stall sits just off spawn
const WAYGATE_DIST := [3, 10]  # the ritual circle stands just past the spawn field
const ROLE_LANDMARK := "landmark"
const ROLE_LAIR := "lair"
const ROLE_HOME := "home"
const ROLE_WAYGATE := "waygate"

## Manifest cache (semantic id -> {texture, height_tiles, footprint}) — loaded once per session.
static var _manifest: Dictionary = {}
## Built cutout textures cached by id (the spike-diet rule: never reload on battle return).
static var _textures: Dictionary = {}

## The live placement plan: Array of {id, role, cell (anchor, top-left), w, h, cells (footprint)}.
var _plan: Array = []
## Footprint occupancy: Vector2i -> true. The screen's try_move consults this.
var _blocked: Dictionary = {}
var _holder: Node2D = null


## The parsed structures manifest (id -> {texture, height_tiles, footprint:[w,h]}), cached.
static func manifest() -> Dictionary:
	if not _manifest.is_empty():
		return _manifest
	var out := {}
	var f := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if f == null:
		return out
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		return out
	for key in parsed as Dictionary:
		if str(key).begins_with("_"):
			continue
		var entry: Variant = (parsed as Dictionary)[key]
		if entry is Dictionary:
			out[str(key)] = entry
	_manifest = out
	return _manifest


## The cutout texture for a manifest id, or null when absent (scenes still build headless).
static func texture_for(id: String) -> Texture2D:
	var hit: Variant = _textures.get(id)
	if hit is Texture2D:
		return hit
	var entry: Dictionary = manifest().get(id, {})
	var path := DIR + str(entry.get("texture", ""))
	if entry.is_empty() or not ResourceLoader.exists(path):
		return null
	var tex := load(path) as Texture2D
	if tex != null:
		_textures[id] = tex
	return tex


## How tall (in tiles) a structure stands (manifest height_tiles; safe fallback).
static func height_tiles(id: String) -> float:
	return float((manifest().get(id, {}) as Dictionary).get("height_tiles", 1.6))


## The [w, h] blocking footprint of a structure (manifest; safe fallback 1x1).
static func footprint(id: String) -> Vector2i:
	var fp: Array = (manifest().get(id, {}) as Dictionary).get("footprint", [1, 1])
	if fp.size() != 2:
		return Vector2i.ONE
	return Vector2i(maxi(1, int(fp[0])), maxi(1, int(fp[1])))


# === deterministic placement (pure functions of layout + force + home) ======================== #


## Build the deterministic placement plan for a region: 2-4 force-pool landmarks on hashed
## feature-cell clusters, the LAIR altar on the deepest candidate (the boss goal's visible
## destination), the WAYGATE ritual circle just off the spawn field (E1b — the Threshold
## network's door), and the HOME stall near spawn. Pure function — same inputs => same plan.
static func plan_for(layout: Layout, force_climate: String, home: Vector2i) -> Array:
	if layout == null or manifest().is_empty():
		return []
	var out: Array = []
	var taken := {}
	_place_lair(layout, home, out, taken)
	_place_waygate(layout, force_climate, home, out, taken)
	_place_home_stall(layout, force_climate, home, out, taken)
	_place_landmarks(layout, force_climate, home, out, taken)
	_enforce_reachability(layout, home, out)
	return out


## Occupancy set for a plan (footprint cell -> true).
static func blocked_cells(plan: Array) -> Dictionary:
	var out := {}
	for entry: Dictionary in plan:
		for c: Vector2i in entry.get("cells", []) as Array:
			out[c] = true
	return out


## The plan's lair entry, or {}.
static func lair_entry(plan: Array) -> Dictionary:
	for entry: Dictionary in plan:
		if str(entry.get("role", "")) == ROLE_LAIR:
			return entry
	return {}


## The plan's waygate (ritual circle) entry, or {}.
static func waygate_entry(plan: Array) -> Dictionary:
	for entry: Dictionary in plan:
		if str(entry.get("role", "")) == ROLE_WAYGATE:
			return entry
	return {}


## E1b — the Threshold-network ritual circle: ONE portal in a near-spawn band, picked like the
## home stall (lowest FNV key over any-ground candidates) so every region raises a reachable
## waygate a short, visible walk from where the tamer arrives.
static func _place_waygate(
	layout: Layout, force_climate: String, home: Vector2i, out: Array, taken: Dictionary
) -> void:
	var near := _anchor_candidates(layout, WAYGATE_ID, home, 0, taken, true)
	var best := Vector2i(-1, -1)
	var best_key := -1
	for c: Vector2i in near:
		var d := _manhattan(c, home)
		if d < int(WAYGATE_DIST[0]) or d > int(WAYGATE_DIST[1]):
			continue
		var key := SigilGen.fnv1a_32("gate|%s|%d|%d" % [force_climate, c.x, c.y])
		if best_key < 0 or key < best_key:
			best_key = key
			best = c
	if best.x >= 0:
		_commit(out, taken, WAYGATE_ID, ROLE_WAYGATE, best)


static func _place_lair(layout: Layout, home: Vector2i, out: Array, taken: Dictionary) -> void:
	var candidates := _anchor_candidates(layout, LAIR_ID, home, 0, taken)
	if candidates.is_empty():
		return
	# The DEEPEST candidate marks the lair (ties broken by the FNV order the sort fixed);
	# among the deepest quartile, one adjacent to the worn path wins — the altar reads as
	# standing off the deep path, where the boss-goal quest points.
	candidates.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool: return _manhattan(a, home) > _manhattan(b, home)
	)
	var deep_count := maxi(1, candidates.size() / 4)
	var pick: Vector2i = candidates[0]
	for i in deep_count:
		if _near_path(layout, candidates[i]):
			pick = candidates[i]
			break
	_commit(out, taken, LAIR_ID, ROLE_LAIR, pick)


static func _place_home_stall(
	layout: Layout, force_climate: String, home: Vector2i, out: Array, taken: Dictionary
) -> void:
	var near := _anchor_candidates(layout, HOME_ID, home, 0, taken, true)
	var best := Vector2i(-1, -1)
	var best_key := -1
	for c: Vector2i in near:
		var d := _manhattan(c, home)
		if d < int(HOME_STALL_DIST[0]) or d > int(HOME_STALL_DIST[1]):
			continue
		var key := SigilGen.fnv1a_32("home|%s|%d|%d" % [force_climate, c.x, c.y])
		if best_key < 0 or key < best_key:
			best_key = key
			best = c
	if best.x >= 0:
		_commit(out, taken, HOME_ID, ROLE_HOME, best)


static func _place_landmarks(
	layout: Layout, force_climate: String, home: Vector2i, out: Array, taken: Dictionary
) -> void:
	var pool: Array = POOLS.get(force_climate, POOLS[DEFAULT_FORCE])
	var count := (
		MIN_LANDMARKS
		+ (
			SigilGen.fnv1a_32("count|%s|%s" % [force_climate, layout.region_id])
			% (MAX_LANDMARKS - MIN_LANDMARKS + 1)
		)
	)
	var placed := 0
	for i in count:
		var id := str(pool[i % pool.size()])
		var candidates := _anchor_candidates(layout, id, home, LANDMARK_MIN_HOME_DIST, taken)
		if candidates.is_empty():
			continue
		candidates.sort_custom(
			func(a: Vector2i, b: Vector2i) -> bool:
				var ka := SigilGen.fnv1a_32("lm|%s|%d|%d" % [force_climate, a.x, a.y])
				var kb := SigilGen.fnv1a_32("lm|%s|%d|%d" % [force_climate, b.x, b.y])
				return ka < kb if ka != kb else (a.y < b.y or (a.y == b.y and a.x < b.x))
		)
		_commit(out, taken, id, ROLE_LANDMARK, candidates[0])
		placed += 1


## Anchor candidates for a structure: top-left cells whose whole footprint sits in-bounds on
## WALKABLE, non-thin, unclaimed cells, spaced off every committed anchor — anchored on FEATURE
## cells (the worldgen's clusters) unless `any_ground` lets the stall sit on plain field.
static func _anchor_candidates(
	layout: Layout,
	id: String,
	home: Vector2i,
	min_home_dist: int,
	taken: Dictionary,
	any_ground: bool = false
) -> Array:
	var fp := footprint(id)
	var found: Array = []
	for y in range(0, layout.height - fp.y + 1):
		for x in range(0, layout.width - fp.x + 1):
			var anchor := Vector2i(x, y)
			if _manhattan(anchor, home) < min_home_dist:
				continue
			var is_feature := layout.get_cell(x, y) == OverworldTileSetScript.FEATURE_TILE
			if not (is_feature or any_ground):
				continue
			if not _footprint_fits(layout, anchor, fp, home, taken):
				continue
			found.append(anchor)
	return found


static func _footprint_fits(
	layout: Layout, anchor: Vector2i, fp: Vector2i, home: Vector2i, taken: Dictionary
) -> bool:
	for dy in fp.y:
		for dx in fp.x:
			var c := anchor + Vector2i(dx, dy)
			if not layout.in_bounds(c.x, c.y):
				return false
			if not OverworldTileSetScript.is_walkable(layout.get_cell(c.x, c.y)):
				return false
			if OverworldTileSetScript.is_thin_place(c.x, c.y):
				return false  # never bury a shimmering veil cell under a structure
			if taken.has(c) or _manhattan(c, home) <= 1:
				return false
	for entry_cell: Vector2i in taken.get("_anchors", []) as Array:
		if _manhattan(anchor, entry_cell) < LANDMARK_SPACING:
			return false
	return true


static func _commit(
	out: Array, taken: Dictionary, id: String, role: String, anchor: Vector2i
) -> void:
	var fp := footprint(id)
	var cells: Array = []
	for dy in fp.y:
		for dx in fp.x:
			var c := anchor + Vector2i(dx, dy)
			cells.append(c)
			taken[c] = true
	var anchors: Array = taken.get("_anchors", [])
	anchors.append(anchor)
	taken["_anchors"] = anchors
	out.append({"id": id, "role": role, "cell": anchor, "w": fp.x, "h": fp.y, "cells": cells})


## Drop landmarks (never the lair, never the waygate — losing the ritual circle would seal the
## Threshold network in that region) whose footprints would strand the spawn field: flood the
## walkable-minus-blocked component containing `home` and require it to keep all but the
## footprint cells (+ a small allowance for pocketed corners).
static func _enforce_reachability(layout: Layout, home: Vector2i, out: Array) -> void:
	var open := _open_size(layout, home, {})
	var guard := 0
	while out.size() > 0 and guard < 8:
		guard += 1
		var blocked := blocked_cells(out)
		var reachable := _open_size(layout, home, blocked)
		if reachable >= open - blocked.size() - 8:
			return
		var dropped := false
		for i in range(out.size() - 1, -1, -1):
			var role := str((out[i] as Dictionary).get("role", ""))
			if role != ROLE_LAIR and role != ROLE_WAYGATE:
				out.remove_at(i)
				dropped = true
				break
		if not dropped:
			return


static func _open_size(layout: Layout, home: Vector2i, blocked: Dictionary) -> int:
	if not OverworldTileSetScript.is_walkable(layout.get_cell(home.x, home.y)):
		return 0
	var visited := {home: true}
	var queue: Array = [home]
	var count := 0
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		count += 1
		for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cell + step
			if visited.has(n) or not layout.in_bounds(n.x, n.y) or blocked.has(n):
				continue
			if not OverworldTileSetScript.is_walkable(layout.get_cell(n.x, n.y)):
				continue
			visited[n] = true
			queue.append(n)
	return count


static func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


static func _near_path(layout: Layout, cell: Vector2i) -> bool:
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var c := cell + Vector2i(dx, dy)
			if layout.in_bounds(c.x, c.y) and layout.get_cell(c.x, c.y) == 2:
				return true
	return false


# === instance state (the screen owns one) ====================================================== #


## (Re)build the structures for a region under the y-sorted world root. Frees the old holder,
## computes the deterministic plan + occupancy set, and spawns feet-origined sprites (each
## occludes actors behind it and is occluded from in front — same contract as the props).
func build(world: Node2D, layout: Layout, force_climate: String, home: Vector2i) -> Node2D:
	if _holder != null and is_instance_valid(_holder):
		var old_parent := _holder.get_parent()
		if old_parent != null:
			old_parent.remove_child(_holder)
		_holder.queue_free()
	_plan = plan_for(layout, force_climate, home)
	_blocked = blocked_cells(_plan)
	_holder = Node2D.new()
	_holder.name = "Structures"
	_holder.y_sort_enabled = true
	world.add_child(_holder)
	var s := OverworldTileSetScript.TILE_SIZE
	for entry: Dictionary in _plan:
		var id := str(entry["id"])
		var tex := texture_for(id)
		if tex == null:
			continue
		var sprite := Sprite2D.new()
		sprite.name = (
			"Structure_%s_%d_%d"
			% [id, int((entry["cell"] as Vector2i).x), int((entry["cell"] as Vector2i).y)]
		)
		sprite.texture = tex
		var height := s * height_tiles(id)
		var fit := height / float(tex.get_height())
		# Width cap: a landmark may spill past its footprint by half a tile a side — it reads
		# as a monument on the field, not a sprite bug — but never swallow the walk lanes.
		fit = minf(fit, (s * (float(entry["w"]) + 1.0)) / float(tex.get_width()))
		sprite.scale = Vector2(fit, fit)
		# Feet origin at the footprint's base line (the y-sort key of a standing thing).
		sprite.offset = Vector2(0, -tex.get_height() * 0.5)
		var anchor: Vector2i = entry["cell"]
		sprite.position = Vector2(
			(anchor.x + float(entry["w"]) * 0.5) * s, (anchor.y + float(entry["h"])) * s - s * 0.18
		)
		_holder.add_child(sprite)
		entry["node"] = sprite
	return _holder


## True when a structure footprint occupies `cell` (the screen's try_move consults this).
func blocks(cell: Vector2i) -> bool:
	return _blocked.has(cell)


## The live plan (for markers + tests).
func plan() -> Array:
	return _plan


## The live occupancy set (cell -> true).
func blocked() -> Dictionary:
	return _blocked


## The lair entry of the live plan, or {}.
func lair() -> Dictionary:
	return lair_entry(_plan)


## The waygate (ritual circle) entry of the live plan, or {} (E1b — the travel interactable).
func waygate() -> Dictionary:
	return waygate_entry(_plan)


## True when `cell` stands on/next to any footprint cell of the waygate (the INTERACT reach —
## the same 1.5-cell ring NPC talks use).
func waygate_adjacent(cell: Vector2i) -> bool:
	for c: Vector2i in waygate().get("cells", []) as Array:
		if (c - cell).length() <= 1.5:
			return true
	return false


## The structures holder node (or null before build).
func holder() -> Node2D:
	return _holder
