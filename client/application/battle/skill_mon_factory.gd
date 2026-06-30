class_name SkillMonFactory
extends RefCounted
## SkillMonFactory (Phase 10 · Slice 2) — builds an AbilityContainer (the SkillEngine reuse shell) from
## a party/wild creature dict, deriving the skill kit from the species' forces via KitFactory. The SKILL
## counterpart to MonFactory (which builds the attack-only BattleEngine.Mon). APPLICATION/battle layer:
## it composes the container from CATALOG data + the force->kit mapping; it computes NO numbers (stats +
## HP come from the oracle inside the container -> SkillEngine.Mon -> StatEngine). A given species id +
## forces always yields the same container, the determinism the interactive round-trip needs.

const DEFAULT_CLASS := "organic"


## Build one AbilityContainer from a creature dict + the catalog. Returns null if the species id is
## absent from the catalog (caller decides how to handle the missing-content gap).
static func from_creature(creature: Dictionary, catalog: SpeciesCatalog) -> AbilityContainer:
	var species_id := str(creature.get("species_id", ""))
	if species_id == "":
		return null
	var species: SpeciesData = catalog.get_by_id(species_id)
	if species == null:
		return null
	var display_name := str(creature.get("nickname", ""))
	if display_name == "":
		display_name = species.name
	var kit := KitFactory.kit_for(species.force_primary, species.force_secondary)
	return AbilityContainer.new(
		display_name,
		species.force_primary,
		species.force_secondary,
		species.rank,
		species.tier,
		kit
	)


## Build a team (Array[AbilityContainer]) from an Array of creature dicts. Skips any entry whose
## species id is missing from the catalog, so a partial-content team still battles.
static func team_from_creatures(creatures: Array, catalog: SpeciesCatalog) -> Array:
	return team_with_source(creatures, catalog)["team"]


## Build a team AND a parallel AbilityContainer→source-creature-dict map (object-identity keyed), so the
## interactive battle can map a captured wild combatant back to its species_id / creature dict. Mirrors
## MonFactory.team_with_source. Skipped (missing-id) entries are absent from both, so the two stay
## aligned. Returns { "team": Array[AbilityContainer], "source": Dictionary }.
static func team_with_source(creatures: Array, catalog: SpeciesCatalog) -> Dictionary:
	var team: Array = []
	var source: Dictionary = {}
	for entry in creatures:
		if entry is Dictionary:
			var ac := from_creature(entry as Dictionary, catalog)
			if ac != null:
				team.append(ac)
				source[ac] = entry
	return {"team": team, "source": source}
