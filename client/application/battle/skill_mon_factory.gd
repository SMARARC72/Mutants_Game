class_name SkillMonFactory
extends RefCounted
## SkillMonFactory (Phase 10 · Slice 2) — builds an AbilityContainer (the SkillEngine reuse shell) from
## a party/wild creature dict, deriving the skill kit from the species' forces via KitFactory. The SKILL
## counterpart to MonFactory (which builds the attack-only BattleEngine.Mon). APPLICATION/battle layer:
## it composes the container from CATALOG data + the force->kit mapping; it computes NO numbers (stats +
## HP come from the oracle inside the container -> SkillEngine.Mon -> StatEngine). A given species id +
## forces always yields the same container, the determinism the interactive round-trip needs.

const DEFAULT_CLASS := "organic"

## The rank a spliced hybrid's stats derive from. LabEngine.fuse cached its stat block via
## StatEngine.stat_block(prim, sec, "wild", tier, "organic") — rebuilding the container through the
## SAME oracle inputs reproduces the stats_cached numbers verbatim (deterministic, no genome).
const HYBRID_RANK := "wild"

## The display name a nameless hybrid falls back to (a lab creature always carries its oracle name).
const HYBRID_FALLBACK_NAME := "Splice"


## Build one AbilityContainer from a creature dict + the catalog. A spliced hybrid (species_id == "")
## is built from the oracle numbers cached at lab commit (stats_cached.prim/sec/tier). Returns null if
## the species id is absent from the catalog AND no cached stats exist (caller decides how to handle
## the missing-content gap).
static func from_creature(creature: Dictionary, catalog: SpeciesCatalog) -> AbilityContainer:
	var species_id := str(creature.get("species_id", ""))
	if species_id == "":
		return _from_cached_stats(creature)
	var species: SpeciesData = catalog.get_by_id(species_id)
	if species == null:
		return null
	var display_name := str(creature.get("nickname", ""))
	if display_name == "":
		display_name = species.name
	var kit := _kit_for(creature, species.force_primary, species.force_secondary)
	var ac := AbilityContainer.new(
		display_name,
		species.force_primary,
		species.force_secondary,
		species.rank,
		species.tier,
		kit
	)
	_compose_growth(ac, creature)
	_apply_persisted_hp(ac, creature)
	return ac


## Build a spliced hybrid's AbilityContainer from the stats_cached the Lab commit wrote (the oracle's
## own prim/sec/tier). The container re-derives the stat block through the SAME oracle call LabEngine
## used (rank "wild", no genome), so its stats + HP EQUAL the cached numbers — no number is computed
## here. The kit derives from the cached forces (the same KitFactory policy every species uses).
## Returns null when the cache is absent/incomplete (a malformed entry).
static func _from_cached_stats(creature: Dictionary) -> AbilityContainer:
	var cached_raw: Variant = creature.get("stats_cached", {})
	if not (cached_raw is Dictionary):
		return null
	var cached: Dictionary = cached_raw
	var prim := str(cached.get("prim", ""))
	var tier := str(cached.get("tier", ""))
	if prim == "" or tier == "":
		return null
	var sec := str(cached.get("sec", ""))
	var display_name := str(creature.get("nickname", ""))
	if display_name == "":
		display_name = HYBRID_FALLBACK_NAME
	var kit := _kit_for(creature, prim, sec)
	var ac := AbilityContainer.new(display_name, prim, sec, HYBRID_RANK, tier, kit)
	_compose_growth(ac, creature)
	_apply_persisted_hp(ac, creature)
	return ac


## The skill kit for a creature dict (Batch E1c): a `kit_override` on the dict — an Array of
## skill names, e.g. the AUTHORED pantheon-boss kit from BossKitCatalog, folded into the boss
## enemy dict by EncounterDirector.boss_step — replaces the force-derived KitFactory kit.
## APPLICATION-layer policy only: every override name is validated against the SkillEngine
## library (Constants.BALANCE.skill.library); unknown names are dropped, and an empty/absent/
## fully-invalid override falls back to the canonical KitFactory derivation — so a malformed
## catalog row can never hand a creature an unusable kit. Dicts without the key (every wild/
## party creature today) build byte-identical to the pre-E1c path.
static func _kit_for(creature: Dictionary, prim: String, sec: String) -> Array:
	var override: Variant = creature.get("kit_override", null)
	if override is Array:
		var library: Dictionary = Constants.BALANCE["skill"]["library"]
		var kit: Array = []
		for skill_name in override as Array:
			var skill := str(skill_name)
			if library.has(skill) and not kit.has(skill):
				kit.append(skill)
		if not kit.is_empty():
			return kit
	return KitFactory.kit_for(prim, sec)


## AWAKENINGS FELT (application-layer composition; the domain stays untouched): scale the container's
## engine-built CEILING stat block by the creature's growth state via the ORACLE's own model —
## LevelEngine.current_stats(ceiling, expression, gene_bonus). A dict WITHOUT growth state (wild
## enemies, starter/legacy entries) composes at expression 1.0 — the full ceiling, exactly the
## pre-composition behavior — so canonical battle streams over growth-less teams are unchanged.
## HP stays ceiling-derived (the growth model scales pole stats, not HP — mirrors
## CreatureSheet.effective_stats / hp_of).
static func _compose_growth(ac: AbilityContainer, creature: Dictionary) -> void:
	var expression := float(creature.get("expression", 1.0))
	var gene_bonus_raw: Variant = creature.get("gene_bonus", {})
	var gene_bonus: Dictionary = gene_bonus_raw if gene_bonus_raw is Dictionary else {}
	if expression == 1.0 and gene_bonus.is_empty():
		return
	ac.compose_growth(expression, gene_bonus)


## FIGHTS LEAVE MARKS (Codex #54 P2): a creature dict carrying persisted battle wounds ("hp"
## written back by GameController.apply_battle_result) enters the next battle at that HP, not
## the rebuilt ceiling. Clamped to [1, max_hp] — the 1-floor keeps a 0-HP survivor playable
## until permadeath (plan W18) owns death for real. Dicts without the key (fresh captures,
## wild enemies) keep the full-HP rebuild, so canonical enemy streams are untouched.
static func _apply_persisted_hp(ac: AbilityContainer, creature: Dictionary) -> void:
	if not creature.has("hp"):
		return
	var stored := int(creature.get("hp", 0))
	ac.set_hp(clampi(stored, 1, ac.max_hp()))


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
		if entry is Dictionary and not bool((entry as Dictionary).get("is_dead", false)):
			# W18 permadeath guard: the dead never fight again (they also leave run.party for the
			# graveyard, so this is belt-and-braces; wild enemies never carry the flag).
			var ac := from_creature(entry as Dictionary, catalog)
			if ac != null:
				team.append(ac)
				source[ac] = entry
	return {"team": team, "source": source}
