class_name RegionCatalog
extends RefCounted
## RegionCatalog (E1b "Eleven Regions") — the WORLD-DATA reader over the region entries in
## res://catalog/region_layouts.json (docs/content/regions.md, ingested). APPLICATION/overworld
## layer: it NAMES the regions (ids in authored order), their display titles, force climates,
## tier bands, and the Threshold-network TRAVEL GATES (a run.flags story flag per region; an
## empty gate = always open — verdant + threshold). It computes nothing and stores no stats;
## the WFC solver reads the SAME file through RegionRules (infrastructure) — one source, two
## consumers, each taking only its own keys.

const PATH := "res://catalog/region_layouts.json"

## Lazily-loaded + cached region entries ({region_id: {...}}, authored order), or {} on failure.
static var _regions_cache: Dictionary = {}
static var _regions_loaded: bool = false


## Every region id, in the catalog's authored order (Threshold first, the Atelier last).
static func region_ids() -> Array:
	return _regions().keys()


static func has_region(region_id: String) -> bool:
	return _regions().has(region_id)


## The display title ("The Verdant Glut"), falling back to the raw id for unknown regions.
static func title(region_id: String) -> String:
	return str(_entry(region_id).get("title", region_id))


## The region's force-climate string ("Eros", "Cosmos+Gaia", "neutral", ...).
static func force(region_id: String) -> String:
	return str(_entry(region_id).get("force", ""))


## The VoiceBook key of the region's authored entry sting ("region.<id>.enter" by default).
static func blurb_key(region_id: String) -> String:
	return str(_entry(region_id).get("blurb_key", "region.%s.enter" % region_id))


## The wild-pool tier span (["T1","T2"], ...) as Array[String]; [] for unknown regions.
static func tier_band(region_id: String) -> Array:
	var band: Variant = _entry(region_id).get("tier_band", [])
	var out: Array = []
	if band is Array:
		for tier in band as Array:
			out.append(str(tier))
	return out


## The run.flags STORY GATE that opens this region on the Threshold network, or "" when the
## region is always open (verdant + threshold). Quests set these flags (act gates).
static func gate_flag(region_id: String) -> String:
	return str(_entry(region_id).get("gate_flag", ""))


## The locked-row copy for the travel overlay, or "" when the region carries none.
static func gate_hint(region_id: String) -> String:
	return str(_entry(region_id).get("gate_hint", ""))


## True when the region needs no story flag at all (its gate is empty).
static func always_open(region_id: String) -> bool:
	return has_region(region_id) and gate_flag(region_id) == ""


# --- internals -------------------------------------------------------------------------------- #


static func _entry(region_id: String) -> Dictionary:
	var entry: Variant = _regions().get(region_id, {})
	return entry if entry is Dictionary else {}


static func _regions() -> Dictionary:
	if _regions_loaded:
		return _regions_cache
	_regions_loaded = true
	if not FileAccess.file_exists(PATH):
		push_warning("RegionCatalog: missing region catalog at %s" % PATH)
		return _regions_cache
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary and (parsed as Dictionary).get("regions", null) is Dictionary:
		_regions_cache = (parsed as Dictionary)["regions"]
	else:
		push_warning("RegionCatalog: region catalog is not a JSON object with 'regions'")
	return _regions_cache
