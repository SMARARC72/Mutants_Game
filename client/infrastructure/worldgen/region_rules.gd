class_name RegionRules
extends RefCounted
## RegionRules — loader for res://catalog/region_layouts.json (ADR-014, D2/D5). INFRASTRUCTURE
## layer: pure generation DATA (tile palette, WFC adjacency, set-piece room specs, sizes). Holds NO
## gameplay math (Cluster 4 §3). Mirrors the SpliceRules loader pattern: parse + return an instance
## or null on failure, with a static last_error so a caller that got null can report it.
##
## A region's effective rule set is the catalog `defaults` block MERGED with the per-region entry
## (region keys override defaults). This lets every region inherit a sane WFC adjacency/weight base
## and only override what differs (force-climate tile weights, a set-piece spec).
##
## NUMERIC NOTE: JSON.parse_string decodes bare numbers as FLOAT in GDScript ("0" weight key stays a
## STRING key, but a tile id 0 in an array arrives as 0.0). Tile-id arrays and adjacency neighbour
## lists are therefore int()-normalised here so the solver compares ints, not int-vs-float.

const DEFAULT_PATH := "res://catalog/region_layouts.json"

static var last_error: String = ""

var data: Dictionary = {}


static func load_default() -> RegionRules:
	return load_from(DEFAULT_PATH)


static func load_from(path: String) -> RegionRules:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		last_error = "region_rules: cannot open " + path
		return null
	var text := f.get_as_text()
	f.close()
	return load_text(text)


static func load_text(text: String) -> RegionRules:
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		last_error = "region_rules: root is not a JSON object"
		return null
	var inst := RegionRules.new()
	inst.data = parsed
	if not inst.data.has("regions") or not (inst.data["regions"] is Dictionary):
		last_error = "region_rules: missing 'regions' object"
		return null
	last_error = ""
	return inst


func has_region(region_id: String) -> bool:
	return (data.get("regions", {}) as Dictionary).has(region_id)


## The effective WFC rule set for a region: defaults merged with the region override, with tile
## ids + adjacency neighbour lists normalised to ints. Returns {} for an unknown region (the facade
## then uses its built-in authored fallback for that region).
func wfc_rules(region_id: String) -> Dictionary:
	var regions: Dictionary = data.get("regions", {})
	if not regions.has(region_id):
		return {}
	var defaults: Dictionary = data.get("defaults", {})
	var region: Dictionary = regions[region_id]
	var tiles: Array = _int_array(region.get("tiles", defaults.get("tiles", [0, 1, 2])))
	var weights: Dictionary = region.get("weights", defaults.get("weights", {}))
	var adjacency: Dictionary = _normalise_adjacency(region.get("adjacency", defaults.get("adjacency", {})))
	return {
		"tiles": tiles,
		"weights": _int_keyed_weights(weights),
		"adjacency": adjacency,
		"width": int(region.get("width", defaults.get("width", 16))),
		"height": int(region.get("height", defaults.get("height", 16))),
		"attempt_limit": int(region.get("attempt_limit", defaults.get("attempt_limit", 20000))),
	}


## The SimpleDungeons set-piece spec for a region, or {} if the region has no authored rooms.
func setpiece(region_id: String) -> Dictionary:
	var regions: Dictionary = data.get("regions", {})
	if not regions.has(region_id):
		return {}
	return (regions[region_id] as Dictionary).get("setpiece", {})


func region_ids() -> Array:
	return (data.get("regions", {}) as Dictionary).keys()


# --- numeric normalisation (JSON floats -> ints) --------------------------------------------- #


func _int_array(arr: Variant) -> Array:
	var out: Array = []
	if arr is Array:
		for v in arr:
			out.append(int(v))
	return out


## Weights arrive keyed by STRING (JSON object keys are strings) -> rekey to int tile ids so the
## solver's `_weights.get(tile_id, 1.0)` lookup (int key) hits.
func _int_keyed_weights(weights: Variant) -> Dictionary:
	var out: Dictionary = {}
	if weights is Dictionary:
		for k in weights as Dictionary:
			out[int(str(k))] = float((weights as Dictionary)[k])
	return out


## Adjacency: { dir: { "<tile_id>": [neighbour ids...] } } -> { dir: { tile_id(int): [ints] } }.
func _normalise_adjacency(adj: Variant) -> Dictionary:
	var out: Dictionary = {}
	if not (adj is Dictionary):
		return out
	for dir in adj as Dictionary:
		var dir_rules: Dictionary = (adj as Dictionary)[dir]
		var norm: Dictionary = {}
		for tile_key in dir_rules:
			norm[int(str(tile_key))] = _int_array(dir_rules[tile_key])
		out[str(dir)] = norm
	return out
