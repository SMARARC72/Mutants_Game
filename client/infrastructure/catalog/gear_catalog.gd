class_name GearCatalog
extends RefCounted
## GearCatalog facade (Phase 5 · Slice 3b) — the ONLY way the rest of the game reads GEAR data.
##
## INFRASTRUCTURE/catalog layer. Loads res://catalog/gear.json (the SAME static catalog the
## supabase `gear` seed is generated from via tools/gen_seed.mjs — id/name/slot/rarity/force/
## effects). Pure read-only static data; it computes NOTHING (no stats, no RNG). Mirrors the
## SpeciesCatalog facade shape (`get_by_id`, `all`, `count`) so callers read gear the same way they
## read species.
##
## NOTE: lookup is `get_by_id`, NOT `get` — overriding native Object.get() does not dispatch (the
## SpeciesCatalog comment explains why). A distinct name the engine never shadows is used.

const DB_PATH := "res://catalog/gear.json"

var _by_id: Dictionary = {}
var _all: Array = []


func _init(db_path: String = DB_PATH) -> void:
	_load(db_path)


func _load(db_path: String) -> void:
	_by_id.clear()
	_all.clear()
	if not FileAccess.file_exists(db_path):
		push_error("GearCatalog: missing gear catalog at %s" % db_path)
		return
	var text := FileAccess.get_file_as_string(db_path)
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("GearCatalog: gear catalog is not a JSON object")
		return
	var entries: Variant = (parsed as Dictionary).get("gear", [])
	if not (entries is Array):
		return
	for entry in entries as Array:
		if entry is Dictionary:
			var row := _normalize(entry as Dictionary)
			_all.append(row)
			_by_id[str(row["id"])] = row


## One gear row by id (e.g. "luckbone_charm"), or {} if absent. Returns a defensive copy so a
## caller can never mutate the shared catalog row.
func get_by_id(id: String) -> Dictionary:
	var row: Dictionary = _by_id.get(id, {})
	return row.duplicate(true)


## Every gear row, in catalog order. Returns Array[Dictionary] (defensive copies).
func all() -> Array:
	var out: Array = []
	for row in _all:
		out.append((row as Dictionary).duplicate(true))
	return out


## How many gear rows are loaded.
func count() -> int:
	return _all.size()


## True if `id` names a real catalog gear row.
func has(id: String) -> bool:
	return _by_id.has(id)


## The display name for a gear id, or the id itself if unknown (never crashes the UI).
func name_of(id: String) -> String:
	var row: Dictionary = _by_id.get(id, {})
	return str(row.get("name", id))


## All gear rows whose `slot` equals `slot_name` (e.g. "Charm"). Returns Array[Dictionary] copies.
func by_slot(slot_name: String) -> Array:
	var out: Array = []
	for row in _all:
		if str((row as Dictionary).get("slot", "")) == slot_name:
			out.append((row as Dictionary).duplicate(true))
	return out


# --- internals -------------------------------------------------------------------------------- #


## Coerce one parsed JSON gear row into the canonical shape, JSON-number-safe (JSON parses every
## number as FLOAT — effect magnitudes stay float; that is correct for the chance/capability deltas).
func _normalize(entry: Dictionary) -> Dictionary:
	var effects_in: Variant = entry.get("effects", {})
	var effects: Dictionary = {}
	if effects_in is Dictionary:
		for k in effects_in as Dictionary:
			effects[str(k)] = (effects_in as Dictionary)[k]
	return {
		"id": str(entry.get("id", "")),
		"name": str(entry.get("name", "")),
		"slot": str(entry.get("slot", "")),
		"rarity": str(entry.get("rarity", "")),
		"force": entry.get("force", null),
		"effects": effects,
	}
