class_name EncounterCatalog
extends RefCounted
## EncounterCatalog (Phase 5 · Slices 1+4) — the slice's CONTENT PICKS, by id, from the 406-species
## DB. APPLICATION/overworld layer: it NAMES which catalog ids the slice uses (starter party + per-
## region wild pools + the Verdant boss). The actual species data is always read through
## SpeciesCatalog; this file computes nothing and stores no stats.
##
## SLICE 4 — DATA-DRIVEN ROSTER. The curated Verdant-fringe roster now lives in the data file
## res://catalog/slice_verdant.json (~25 ids: ~18 T1/T2 wild Eros/Gaia, ~5 T3 elite, + 1 Legendary
## boss), loaded lazily + cached. The Slice-1 const tables remain as a FALLBACK (used when the data
## file is missing / fails to parse) so the spine stays playable and the old wiring is still
## auditable. The wild pool carries per-id WEIGHTS (a typo'd/absent id is dropped against the
## SpeciesCatalog before it ever reaches battle).
##
## E1b — ELEVEN REGIONS. Every OTHER region reads the SAME shapes from the generated data file
## res://catalog/region_pools.json (tools/gen_region_pools.py over docs/creature_registry.csv):
## weighted wild pools filtered by the region's force climate + tier band, a T3 elite pool, the
## region's BOSS slot, and its deterministic boss trigger (per-region cleared/victory flags).
## slice_verdant.json stays the verdant source; the pools file serves the rest through this same
## API, so the EncounterDirector is data-driven for ANY region id.

## The starting region for a fresh run (the Verdant fringe — the Eros region in
## catalog/region_layouts.json).
const HUB_REGION := "threshold"
const STARTING_REGION := "verdant_glut"

## The curated slice roster data file (Slice 4). The single source for the slice's content picks.
const SLICE_PATH := "res://catalog/slice_verdant.json"

## The generated per-region pools file (E1b): wild/elite/boss data for every non-verdant region.
const POOLS_PATH := "res://catalog/region_pools.json"

## The starter party (3) FALLBACK, as creature dicts the run carries (RunContext.party shape).
## Eros/Gaia tilted: a striker-support, a tank, and a sturdier T2 regenerator anchor. The data file
## (slice_verdant.json -> starter_party) overrides this when present.
const STARTER_PARTY := [
	{"species_id": "SB07", "nickname": "Leaf-hare"},  # Eros/Gaia, support
	{"species_id": "SB05", "nickname": "Sprout-shell"},  # Gaia/Eros, tank
	{"species_id": "AD10", "nickname": "Thornmane"},  # Eros/Gaia T2, regenerator
]

## Per-region wild pool FALLBACK (species ids). Verdant fringe = gentle Eros/Gaia T1/T2 organics.
## Other regions fall back to the default pool until their content slice lands. Slice 4's
## slice_verdant.json supplies the weighted, curated pool for verdant_glut.
const REGION_WILD_POOLS := {
	"verdant_glut":
	[
		"SB33",  # Wild-stag-calf — Eros/Gaia
		"SB32",  # Spore-cub — Gaia/Eros
		"SB18",  # Leaf-gecko — Eros/Ouranos
		"SB09",  # Sprite-blob — Eros/Ouranos
		"SB14",  # Quill-hog — Gaia
		"AD04",  # Palehart — Cosmos/Eros, T2
	],
}

## Fallback wild pool for any region without an explicit table entry (keeps the slice playable
## everywhere without a soft-lock — mirrors worldgen's no-soft-lock philosophy).
const DEFAULT_WILD_POOL := ["SB33", "SB32", "SB14"]

## Lazily-loaded + cached slice roster (the parsed slice_verdant.json), or {} when unavailable.
static var _slice_cache: Dictionary = {}
static var _slice_loaded: bool = false

## Lazily-loaded + cached region pools (the parsed region_pools.json), or {} when unavailable.
static var _pools_cache: Dictionary = {}
static var _pools_loaded: bool = false


## The starter party as a fresh, mutable Array[Dictionary] (deep copy so a caller cannot mutate the
## shared table). These become RunContext.party on new_run. Prefers the data file's starter_party.
static func starter_party() -> Array:
	var slice := _slice()
	var party: Variant = slice.get("starter_party", null)
	if party is Array and not (party as Array).is_empty():
		var out: Array = []
		for entry in party as Array:
			if entry is Dictionary:
				out.append((entry as Dictionary).duplicate(true))
		if not out.is_empty():
			return out
	return STARTER_PARTY.duplicate(true)


## The wild pool species ids for a region, FILTERED to ids that actually exist in the catalog (a
## typo'd id is dropped, never handed to battle). Slice 4: the verdant_glut pool comes from
## slice_verdant.json (wild_pool); other regions use the const table / default. Returns Array[String]
## in the data's declared order (so a weighted draw aligned to weights() stays positionally stable).
static func wild_pool_for(region_id: String, catalog: SpeciesCatalog) -> Array:
	var raw: Array = _raw_wild_ids(region_id)
	var out: Array = []
	for id in raw:
		var species_id := str(id)
		if catalog.get_by_id(species_id) != null:
			out.append(species_id)
	return out


## The wild-encounter WEIGHTS for a region, ALIGNED 1:1 with wild_pool_for(region_id, catalog) (a
## dropped/absent id is skipped in BOTH lists so they stay parallel). Each weight is a positive int
## (JSON numbers parse as float; coerced to int). Regions without per-id weights (the const fallback)
## get a uniform weight of 1. Returns Array[int].
static func wild_weights_for(region_id: String, catalog: SpeciesCatalog) -> Array:
	var weight_by_id := _weight_by_id(region_id)
	var out: Array = []
	for id in _raw_wild_ids(region_id):
		var species_id := str(id)
		if catalog.get_by_id(species_id) != null:
			out.append(int(weight_by_id.get(species_id, 1)))
	return out


## The T3 ELITE pool ids for a region (Wave 13 misbehavior — the thin-cell "veil coughs" draw),
## FILTERED against the catalog like the wild pool. Verdant reads slice_verdant.json's elite_pool
## (previously dead data); regions without one return [] and simply never misbehave.
static func elite_pool_for(region_id: String, catalog: SpeciesCatalog) -> Array:
	var out: Array = []
	for row in _raw_elite_rows(region_id):
		var species_id := str((row as Dictionary).get("species_id", ""))
		if species_id != "" and catalog.get_by_id(species_id) != null:
			out.append(species_id)
	return out


## The elite-pool WEIGHTS, ALIGNED 1:1 with elite_pool_for (dropped ids skipped in both lists).
static func elite_weights_for(region_id: String, catalog: SpeciesCatalog) -> Array:
	var out: Array = []
	for row in _raw_elite_rows(region_id):
		var species_id := str((row as Dictionary).get("species_id", ""))
		if species_id != "" and catalog.get_by_id(species_id) != null:
			out.append(int((row as Dictionary).get("weight", 1)))
	return out


## The region BOSS config: { species_id, name, brain, rank, ... }. VERDANT (Slice 4) keeps its
## hand-wired slice_verdant.json Legendary — canonical, byte-identical to the shipped slice.
## Every OTHER region prefers its authored ACT BOSS (E1c: region_bosses.json -> boss_kits.json
## via BossKitCatalog, carrying { boss_id, kit, intro_line, defeat_line } for the kit-override +
## presentation path) and falls back to the E1b region_pools.json stand-in slot when the
## authored data lacks the region. Returns {} when neither has one (the hub — the trigger then
## simply never fires). The brain key names a strong role brain ("controller"/"aggressor"/...)
## the CombatBrain assigns — NOT the Succession HSM (reserved for god-tier).
static func boss_for(region_id: String) -> Dictionary:
	if region_id == HUB_REGION:
		# The hub holds the Standstill — no throne, no act boss, no ambush trigger. (The
		# pool's arena-exhibition slot is reserved for the future Competitions system.)
		return {}
	if region_id != STARTING_REGION:
		var authored := BossKitCatalog.boss_config_for_region(region_id)
		if not authored.is_empty():
			return authored
		var stand_in: Variant = _pool_region(region_id).get("boss", null)
		return stand_in if stand_in is Dictionary else {}
	var slice := _slice()
	var boss: Variant = slice.get("boss", null)
	if boss is Dictionary and str((boss as Dictionary).get("species_id", "")) != "":
		return (boss as Dictionary).duplicate(true)
	return {}


## The boss-trigger config: { min_steps:int, cleared_flag:String, victory_flag:String }. VERDANT
## reads slice_verdant.json (boss_trigger) with the Slice-4 defaults, unchanged. Every OTHER region
## gets REGION-SCOPED flags ("<region>_boss_cleared"/"<region>_boss_victory") at the same 30-step
## threshold, so GameController's cleared/victory path generalizes per region (Batch E1c) — one
## region's felled god never marks another's lair cleared. min_steps is the explored-step
## threshold for the region climax.
static func boss_trigger_for(region_id: String) -> Dictionary:
	var defaults := {
		"min_steps": 30,
		"cleared_flag": "verdant_boss_cleared",
		"victory_flag": "slice_verdant_victory",
	}
	var trig: Variant = null
	if region_id == STARTING_REGION:
		trig = _slice().get("boss_trigger", null)
	else:
		defaults = {
			"min_steps": 30,
			"cleared_flag": "%s_boss_cleared" % region_id,
			"victory_flag": "%s_boss_victory" % region_id,
		}
		trig = _pool_region(region_id).get("boss_trigger", null)
	if trig is Dictionary:
		var t := trig as Dictionary
		return {
			"min_steps": int(t.get("min_steps", defaults["min_steps"])),
			"cleared_flag": str(t.get("cleared_flag", defaults["cleared_flag"])),
			"victory_flag": str(t.get("victory_flag", defaults["victory_flag"])),
		}
	return defaults


# --- internals -------------------------------------------------------------------------------- #


## The raw (unfiltered) wild-pool ids for a region, in declared order: prefers slice_verdant.json's
## wild_pool (Slice 4) for verdant_glut, region_pools.json (E1b) for every other region, else the
## const table / default (the no-soft-lock floor).
static func _raw_wild_ids(region_id: String) -> Array:
	var rows := _wild_rows(region_id)
	if not rows.is_empty():
		var ids: Array = []
		for row in rows:
			ids.append(str((row as Dictionary).get("species_id", "")))
		return ids
	return REGION_WILD_POOLS.get(region_id, DEFAULT_WILD_POOL)


## species_id -> weight map for a region (slice_verdant.json / region_pools.json wild_pool rows);
## {} for const-fallback regions (uniform weighting applies).
static func _weight_by_id(region_id: String) -> Dictionary:
	var out: Dictionary = {}
	for row in _wild_rows(region_id):
		var sid := str((row as Dictionary).get("species_id", ""))
		if sid != "":
			out[sid] = int((row as Dictionary).get("weight", 1))
	return out


## The region's wild_pool rows ([{species_id, weight, ...}, ...]): the slice file for verdant,
## the generated pools file for anywhere else, [] when neither carries the region.
static func _wild_rows(region_id: String) -> Array:
	if region_id == STARTING_REGION:
		return _slice_rows("wild_pool")
	return _pool_rows(region_id, "wild_pool")


## The elite_pool rows for a region (the slice for verdant, the pools file elsewhere), or [].
static func _raw_elite_rows(region_id: String) -> Array:
	if region_id == STARTING_REGION:
		return _slice_rows("elite_pool")
	return _pool_rows(region_id, "elite_pool")


## The slice data file's dictionary rows under `key`, or [] when absent/malformed.
static func _slice_rows(key: String) -> Array:
	var rows: Variant = _slice().get(key, null)
	if rows is Array:
		var out: Array = []
		for row in rows as Array:
			if row is Dictionary:
				out.append(row)
		return out
	return []


## The parsed slice roster (lazy, cached once). Returns {} when the file is missing / not valid JSON
## (the const fallbacks then carry the slice). JSON numbers parse as FLOAT — callers int()-coerce
## weights/steps at the read sites above.
static func _slice() -> Dictionary:
	if _slice_loaded:
		return _slice_cache
	_slice_loaded = true
	if not FileAccess.file_exists(SLICE_PATH):
		push_warning("EncounterCatalog: missing slice roster at %s (using fallback)" % SLICE_PATH)
		return _slice_cache
	var text := FileAccess.get_file_as_string(SLICE_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		_slice_cache = parsed as Dictionary
	else:
		push_warning("EncounterCatalog: slice roster is not a JSON object (using fallback)")
	return _slice_cache


## The pools entry for one region ({forces, wild_pool, elite_pool, boss, boss_trigger, ...}), or
## {} when the pools file / region is absent (the const fallbacks then keep the region playable).
static func _pool_region(region_id: String) -> Dictionary:
	var regions: Variant = _pools().get("regions", null)
	if regions is Dictionary:
		var entry: Variant = (regions as Dictionary).get(region_id, null)
		if entry is Dictionary:
			return entry
	return {}


## A pools-file row list for a region under `key` (dictionary rows only), or [].
static func _pool_rows(region_id: String, key: String) -> Array:
	var rows: Variant = _pool_region(region_id).get(key, null)
	if rows is Array:
		var out: Array = []
		for row in rows as Array:
			if row is Dictionary:
				out.append(row)
		return out
	return []


## The parsed region pools (lazy, cached once; E1b). {} when missing/malformed — every consumer
## degrades to the const fallbacks, mirroring the slice loader's no-soft-lock contract.
static func _pools() -> Dictionary:
	if _pools_loaded:
		return _pools_cache
	_pools_loaded = true
	if not FileAccess.file_exists(POOLS_PATH):
		push_warning("EncounterCatalog: missing region pools at %s (using fallback)" % POOLS_PATH)
		return _pools_cache
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(POOLS_PATH))
	if parsed is Dictionary:
		_pools_cache = parsed as Dictionary
	else:
		push_warning("EncounterCatalog: region pools file is not a JSON object (using fallback)")
	return _pools_cache
