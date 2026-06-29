class_name SpeciesArt
extends RefCounted
## Maps a species id to its curated bestiary-plate art (PRESENTATION layer). The bulk plate library
## is gitignored under /art; the curated single-creature plates the game actually ships live under
## res://assets/creatures. Returns a Texture2D the caller turns into a portrait / overworld cameo.
##
## Mapping grows as creatures are curated (see docs/creature_registry.csv `art_ref`). Unmapped ids
## fall back to a generic plate so every screen still shows *something* rather than a blank.

const _DIR := "res://assets/creatures/"
const _FALLBACK := "halo_sprout.png"

## species id -> curated plate filename under _DIR.
const MANIFEST := {
	"SB07": "leaf_hare.png",  # Leaf-hare (Eros/Gaia, starter lead)
	"SB05": "sprout_shell.png",  # Sprout-shell (Gaia/Eros, starter tank)
	"AD10": "thornmane.png",  # Thornmane (Eros/Gaia, starter regenerator)
}


## True if `species_id` has a dedicated curated plate (vs falling back to the generic one).
static func has_art(species_id: String) -> bool:
	return MANIFEST.has(species_id)


## The res:// path to a species' plate (its own if curated, else the generic fallback).
static func plate_path(species_id: String) -> String:
	if MANIFEST.has(species_id):
		return _DIR + str(MANIFEST[species_id])
	return _DIR + _FALLBACK


## The species' plate texture (own if curated, else fallback, else null if nothing ships).
static func plate(species_id: String) -> Texture2D:
	var path := plate_path(species_id)
	if ResourceLoader.exists(path):
		return load(path)
	var fb := _DIR + _FALLBACK
	return load(fb) if ResourceLoader.exists(fb) else null
