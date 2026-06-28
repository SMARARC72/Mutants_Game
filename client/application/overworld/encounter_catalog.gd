class_name EncounterCatalog
extends RefCounted
## EncounterCatalog (Phase 5 · Slice 1) — the slice's CONTENT PICKS, by id, from the 406-species DB.
## APPLICATION/overworld layer: pure static data tables (starter party + per-region wild pools) that
## select EXISTING catalog rows — it computes nothing and stores no stats. The actual species data is
## always read through SpeciesCatalog; this file only names which ids the slice uses.
##
## Picks are Verdant-fringe appropriate (Eros/Gaia-tilted, T1/T2 wild organics), per the MVP slice
## (the gentle, forgiving onboarding region). A later content slice replaces these literals with a
## data-driven region<->pool table; for the spine they live here so the wiring is auditable.

## The starting region for a fresh run (the Verdant fringe — the Eros region in
## catalog/region_layouts.json).
const STARTING_REGION := "verdant_glut"

## The starter party (3), as creature dicts the run carries (RunContext.party shape). Eros/Gaia
## tilted: a striker-support, a tank, and a sturdier T2 regenerator anchor.
const STARTER_PARTY := [
	{"species_id": "SB07", "nickname": "Leaf-hare"},  # Eros/Gaia, support
	{"species_id": "SB05", "nickname": "Sprout-shell"},  # Gaia/Eros, tank
	{"species_id": "AD10", "nickname": "Thornmane"},  # Eros/Gaia T2, regenerator
]

## Per-region wild pools (species ids). Verdant fringe = gentle Eros/Gaia T1/T2 organics. Other
## regions fall back to the default pool until their content slice lands.
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


## The starter party as a fresh, mutable Array[Dictionary] (deep copy so a caller cannot mutate the
## shared const table). These become RunContext.party on new_run.
static func starter_party() -> Array:
	return STARTER_PARTY.duplicate(true)


## The wild pool species ids for a region, FILTERED to ids that actually exist in the catalog (a
## typo'd id is dropped, never handed to battle). Falls back to DEFAULT_WILD_POOL for unknown
## regions. Returns Array[String].
static func wild_pool_for(region_id: String, catalog: SpeciesCatalog) -> Array:
	var raw: Array = REGION_WILD_POOLS.get(region_id, DEFAULT_WILD_POOL)
	var out: Array = []
	for id in raw:
		var species_id := str(id)
		if catalog.get_by_id(species_id) != null:
			out.append(species_id)
	return out
