class_name SpeciesCatalog
extends RefCounted
## SpeciesCatalog facade (Cluster 2, D3) — the ONLY way the rest of the game reads species data.
##
## INFRASTRUCTURE/catalog layer. Wraps the packed res://catalog/species/species_db.tres (an
## array of typed SpeciesData Resources, generated from docs/creature_registry.csv at build time
## by tools/gen_species_db.mjs). Callers NEVER touch the csv-data-importer addon or the raw
## Resources — only this facade. Pure read-only static data; computes nothing (no stats, no RNG).
##
## Usage:
##   var catalog := SpeciesCatalog.new()
##   var s := catalog.get_by_id("AD01")      # SpeciesData or null
##   for sp in catalog.all(): ...
##   catalog.by_force("Chaos"); catalog.by_tier("T2"); catalog.by_rank("wild")
##
## NOTE: the lookup is `get_by_id`, NOT `get`. Overriding the native Object.get(property) does not
## work — Godot never dispatches `catalog.get("AD01")` to a user override; it calls the built-in
## property getter (returns null). So we use a distinct name the engine never shadows.

const DB_PATH := "res://catalog/species/species_db.tres"

var _by_id: Dictionary = {}
var _all: Array[SpeciesData] = []


func _init(db_path: String = DB_PATH) -> void:
	_load(db_path)


func _load(db_path: String) -> void:
	_by_id.clear()
	_all.clear()
	var db: SpeciesDB = load(db_path)
	if db == null:
		push_error("SpeciesCatalog: failed to load species DB at %s" % db_path)
		return
	for sp: SpeciesData in db.species:
		_all.append(sp)
		_by_id[sp.id] = sp


## Lookup a single species by id (e.g. "AD01"). Returns the SpeciesData, or null if absent.
func get_by_id(id: String) -> SpeciesData:
	return _by_id.get(id)


## Every species, in registry order. Returns Array[SpeciesData].
func all() -> Array[SpeciesData]:
	return _all


## How many species are loaded (== committed catalog count).
func count() -> int:
	return _all.size()


## All species whose force_primary OR force_secondary equals `f` (case-sensitive, e.g. "Chaos").
func by_force(f: String) -> Array[SpeciesData]:
	var out: Array[SpeciesData] = []
	for sp: SpeciesData in _all:
		if sp.force_primary == f or sp.force_secondary == f:
			out.append(sp)
	return out


## All species with tier `t` (e.g. "T1"/"T2"/"T3").
func by_tier(t: String) -> Array[SpeciesData]:
	var out: Array[SpeciesData] = []
	for sp: SpeciesData in _all:
		if sp.tier == t:
			out.append(sp)
	return out


## All species with rank `r` (e.g. "wild"/"legendary"/"god"/"primordial").
func by_rank(r: String) -> Array[SpeciesData]:
	var out: Array[SpeciesData] = []
	for sp: SpeciesData in _all:
		if sp.rank == r:
			out.append(sp)
	return out
