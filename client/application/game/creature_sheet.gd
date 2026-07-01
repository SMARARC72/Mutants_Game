class_name CreatureSheet
extends RefCounted
## CreatureSheet (Phase 5 · Slice 3b) — derives a creature_instance's DISPLAY stats from the ORACLE.
## APPLICATION/game layer: it ORCHESTRATES the domain engines, it INVENTS no numbers.
##
## A creature_instance (RunContext.party shape) is data only — { species_id, nickname, genome,
## expression, gene_bonus, genes, entropy, awakenings, equipped_gear, ... }. To SHOW its stats the
## party screen needs the engine's numbers, never hand-math:
##   * the CEILING stat block comes from StatEngine.stat_block (species force/rank/tier/class),
##   * the EFFECTIVE pole-stats come from LevelEngine.current_stats(ceiling, expression, gene_bonus)
##     — exactly the awakening growth model (stats = ceiling x expression),
##   * HP comes straight from the stat block.
## The gear EFFECT delta is the sum of the equipped gear's numeric `effects` (the SAME field-sum
## LootEngine.bonus performs for capture/breed bonuses) — gear in this catalog boosts CAPABILITY
## chances (capture/tame/breed/lab), so the "effective stats" we surface include that effect ledger.
##
## PURE: no Node/SceneTree/RNG/wall-clock. Catalogs are injected (read-only facades).

const DEFAULT_CLASS := "organic"
const DEFAULT_EXPRESSION := 0.30


## The oracle CEILING stat block for a creature_instance via its species row. A spliced hybrid
## (species_id == "") falls back to the oracle numbers cached at lab commit (stats_cached) — its
## ceiling IS the cached block, there is no species row to re-derive from. Returns the
## StatEngine.stat_block-shaped dict { "stats": Dictionary, "hp": int, "bst": int }, or {} if the
## species id is missing from the catalog (the caller shows a content-gap placeholder).
static func ceiling_block(creature: Dictionary, catalog: SpeciesCatalog) -> Dictionary:
	var species_id := str(creature.get("species_id", ""))
	if species_id == "":
		return _cached_block(creature)
	var species: SpeciesData = catalog.get_by_id(species_id)
	if species == null:
		return {}
	var cls := species.species_class if species.species_class != "" else DEFAULT_CLASS
	# Empty genome -> stat_block falls back to all-1.0 (deterministic), matching MonFactory.
	return StatEngine.stat_block(
		species.force_primary, species.force_secondary, species.rank, species.tier, cls
	)


## The creature's DISPLAY identity { "prim", "sec", "tier" } — from its species row, or (for a
## spliced hybrid) from the oracle identity cached at lab commit. {} when unresolvable, so the
## caller can fall back to a "?" placeholder. Data reads only — no numbers computed.
static func identity_of(creature: Dictionary, catalog: SpeciesCatalog) -> Dictionary:
	var species_id := str(creature.get("species_id", ""))
	if species_id == "":
		var cached := stats_cached_of(creature)
		if str(cached.get("prim", "")) == "":
			return {}
		return {
			"prim": str(cached.get("prim", "")),
			"sec": str(cached.get("sec", "")),
			"tier": str(cached.get("tier", "")),
		}
	var species: SpeciesData = catalog.get_by_id(species_id)
	if species == null:
		return {}
	return {
		"prim": species.force_primary,
		"sec": species.force_secondary,
		"tier": species.tier,
	}


## The creature's stats_cached dict ({} when absent/malformed). For a spliced hybrid this is the
## oracle's verbatim commit block (prim/sec/tier/hp/bst/stats); for species creatures it is a
## transient display cache the leveling path may clear.
static func stats_cached_of(creature: Dictionary) -> Dictionary:
	var raw: Variant = creature.get("stats_cached", {})
	return raw if raw is Dictionary else {}


## A ceiling block assembled from stats_cached (the hybrid path). The numbers were computed by
## LabEngine/StatEngine at commit and cached verbatim — nothing is recomputed here. {} when the
## cache is absent or carries no usable block.
static func _cached_block(creature: Dictionary) -> Dictionary:
	var cached := stats_cached_of(creature)
	if cached.is_empty():
		return {}
	var stats_raw: Variant = cached.get("stats", {})
	var stats: Dictionary = stats_raw if stats_raw is Dictionary else {}
	var hp := int(cached.get("hp", 0))
	if stats.is_empty() and hp <= 0:
		return {}
	return {"stats": stats.duplicate(true), "hp": hp, "bst": int(cached.get("bst", 0))}


## The creature's EFFECTIVE pole-stats = LevelEngine.current_stats(ceiling, expression, gene_bonus).
## This is the awakening growth model (the oracle), NOT a reimplementation. Returns {} on a missing
## species. expression/gene_bonus default to the freshly-caught baseline / no gene bonuses.
static func effective_stats(creature: Dictionary, catalog: SpeciesCatalog) -> Dictionary:
	var block := ceiling_block(creature, catalog)
	if block.is_empty():
		return {}
	var ceiling: Dictionary = block["stats"]
	var expression := expression_of(creature)
	var gene_bonus := gene_bonus_of(creature)
	return LevelEngine.current_stats(ceiling, expression, gene_bonus)


## The creature's current expression (growth fraction). Defaults to the caught baseline.
static func expression_of(creature: Dictionary) -> float:
	return float(creature.get("expression", DEFAULT_EXPRESSION))


## The creature's gene-bonus map { stat: bonus } (mutated by awakenings). Defaults to empty.
static func gene_bonus_of(creature: Dictionary) -> Dictionary:
	var gb: Variant = creature.get("gene_bonus", {})
	return (gb as Dictionary).duplicate(true) if gb is Dictionary else {}


## The creature's banked entropy (overclock instability). Defaults to 0.
static func entropy_of(creature: Dictionary) -> int:
	return int(creature.get("entropy", 0))


## The creature's awakening count. Defaults to 0.
static func awakenings_of(creature: Dictionary) -> int:
	return int(creature.get("awakenings", 0))


## The creature's HP ceiling from the stat block (Vitality-driven). 0 on a missing species.
static func hp_of(creature: Dictionary, catalog: SpeciesCatalog) -> int:
	var block := ceiling_block(creature, catalog)
	return int(block.get("hp", 0)) if not block.is_empty() else 0


## The summed numeric EFFECTS of a creature's equipped gear (the gear effect ledger). Sums every
## numeric field across the equipped gear ids, the SAME field-sum LootEngine.bonus performs — so a
## charm with {"capture": 0.08} contributes +0.08 capture. Non-numeric effects (e.g. "combat":
## "Dominion aura") are surfaced under their own key as a label, never summed. Returns
##   { "<field>": float (summed numerics), "<field>": String (last label) }.
static func gear_effect_totals(creature: Dictionary, gear_catalog: GearCatalog) -> Dictionary:
	var totals: Dictionary = {}
	for gid in equipped_gear_ids(creature):
		var row := gear_catalog.get_by_id(str(gid))
		var effects: Dictionary = row.get("effects", {})
		for field in effects:
			var val: Variant = effects[field]
			if val is float or val is int:
				totals[field] = float(totals.get(field, 0.0)) + float(val)
			else:
				totals[field] = str(val)
	return totals


## The equipped gear ids on a creature_instance. The MVP is ONE slot (`equipped_gear`: String), but
## this returns an Array so the UI/totals path generalises cleanly. [] when nothing is equipped.
static func equipped_gear_ids(creature: Dictionary) -> Array:
	var single := str(creature.get("equipped_gear", ""))
	return [single] if single != "" else []
