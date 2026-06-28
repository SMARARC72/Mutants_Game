class_name MonFactory
extends RefCounted
## MonFactory (Phase 5 · Slice 1) — builds a BattleEngine.Mon from a party/wild creature dict by
## reading the species row through the SpeciesCatalog facade. APPLICATION/battle layer: it composes
## the DOMAIN BattleEngine.Mon (which itself calls StatEngine.stat_block) from CATALOG data; it
## computes NO numbers of its own (the oracle does all stat math). It never touches `client/domain/`
## internals beyond the public Mon constructor.
##
## A "creature dict" is the data-only party/wild entry the run carries (RunContext.party shape):
##   { "species_id": String, "nickname": String (optional) }
## The Mon's stat block is derived from the species' force_primary / force_secondary / rank / tier /
## class — exactly the inputs BattleEngine.Mon.new(name, prim, sec, rank, tier, cls) wants. With a
## null/empty genome the stat block falls back to all-1.0 genome (deterministic), so a given
## species id always yields the SAME Mon — the determinism the slice's battle round-trip needs.

const DEFAULT_CLASS := "organic"


## Build one BattleEngine.Mon from a creature dict + the catalog. Returns null if the species id is
## absent from the catalog (caller decides how to handle a missing-content gap).
static func from_creature(creature: Dictionary, catalog: SpeciesCatalog) -> BattleEngine.Mon:
	var species_id := str(creature.get("species_id", ""))
	if species_id == "":
		return null
	var species: SpeciesData = catalog.get_by_id(species_id)
	if species == null:
		return null
	var display_name := str(creature.get("nickname", ""))
	if display_name == "":
		display_name = species.name
	var cls := species.species_class if species.species_class != "" else DEFAULT_CLASS
	return BattleEngine.Mon.new(
		display_name,
		species.force_primary,
		species.force_secondary,
		species.rank,
		species.tier,
		cls
	)


## Build a team (Array[BattleEngine.Mon]) from an Array of creature dicts. Skips any entry whose
## species id is missing from the catalog, so a partial-content team still battles.
static func team_from_creatures(creatures: Array, catalog: SpeciesCatalog) -> Array:
	var team: Array = []
	for entry in creatures:
		if entry is Dictionary:
			var mon := from_creature(entry as Dictionary, catalog)
			if mon != null:
				team.append(mon)
	return team
