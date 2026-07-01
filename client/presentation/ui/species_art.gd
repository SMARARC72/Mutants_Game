class_name SpeciesArt
extends RefCounted
## Maps a species id to its promoted bestiary-plate art (PRESENTATION layer). The bulk plate
## library is gitignored under /art; the plates the game ships live under res://assets/creatures,
## promoted by tools/promote_creatures.py which also GENERATES manifest.json — the mapping here is
## pipeline output, never hand-grown entries (Realization_Master_Plan Wave 7).
##
## Two variants per species: `cutout/` (transparent RGBA knockout — battle cards, party, lab,
## camp, anything sitting on INK) and `flat/` (the original plate — codex/parchment surfaces).
## plate() prefers the cutout; flat_plate() prefers the flat. Unmapped ids fall back to a generic
## plate so every screen still shows *something* rather than a blank.

const _DIR := "res://assets/creatures/"
const _MANIFEST_PATH := _DIR + "manifest.json"
const _FALLBACK := "halo_sprout.png"

## Lazily-parsed manifest.json cache: species_id -> {"cutout": rel_path, "flat": rel_path}.
static var _manifest: Dictionary = {}
static var _manifest_loaded: bool = false


## True if `species_id` has a dedicated promoted plate (vs falling back to the generic one).
static func has_art(species_id: String) -> bool:
	return _entries().has(species_id)


## The res:// path to a species' plate — the RGBA cutout when promoted (preferred: no white
## rectangle on dark surfaces), else its flat plate, else the generic fallback.
static func plate_path(species_id: String) -> String:
	return _variant_path(species_id, ["cutout", "flat"])


## The res:// path to a species' FLAT plate (codex/parchment surfaces), else its cutout, else
## the generic fallback.
static func flat_plate_path(species_id: String) -> String:
	return _variant_path(species_id, ["flat", "cutout"])


## The species' plate texture (cutout if promoted, else flat, else fallback, else null).
static func plate(species_id: String) -> Texture2D:
	return _load_or_fallback(plate_path(species_id))


## The species' transparent RGBA cutout (alias of plate(), which already prefers the cutout).
static func cutout(species_id: String) -> Texture2D:
	return plate(species_id)


## The species' flat plate texture for codex/parchment surfaces (else cutout/fallback/null).
static func flat_plate(species_id: String) -> Texture2D:
	return _load_or_fallback(flat_plate_path(species_id))


## Resolve the first available variant path for a species, else the generic fallback plate.
static func _variant_path(species_id: String, preference: Array) -> String:
	var entry: Variant = _entries().get(species_id, null)
	if entry is Dictionary:
		for variant in preference:
			var rel := str((entry as Dictionary).get(variant, ""))
			if rel != "":
				return _DIR + rel
	return _DIR + _FALLBACK


static func _load_or_fallback(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	var fb := _DIR + _FALLBACK
	return load(fb) if ResourceLoader.exists(fb) else null


## The parsed manifest (lazy, cached once). {} when the file is missing/invalid — every consumer
## then rides the fallback chain. JSON parse note: values here are strings only, but any numeric
## field added later parses as FLOAT (int()-coerce at the read site).
static func _entries() -> Dictionary:
	if _manifest_loaded:
		return _manifest
	_manifest_loaded = true
	_manifest = {}
	if not FileAccess.file_exists(_MANIFEST_PATH):
		push_warning("SpeciesArt: missing %s (all species on fallback art)" % _MANIFEST_PATH)
		return _manifest
	var text := FileAccess.get_file_as_string(_MANIFEST_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_warning("SpeciesArt: %s is not a JSON object (fallback art)" % _MANIFEST_PATH)
		return _manifest
	for key: Variant in (parsed as Dictionary).keys():
		var species_id := str(key)
		if species_id.begins_with("_"):
			continue  # "_note" metadata key
		var entry: Variant = (parsed as Dictionary)[key]
		if entry is Dictionary:
			_manifest[species_id] = entry
	return _manifest
