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

## The rank a spliced hybrid's stats derive from. LabEngine.fuse cached its stat block via
## StatEngine.stat_block(prim, sec, "wild", tier, "organic") — rebuilding the Mon through the SAME
## oracle inputs reproduces the stats_cached numbers verbatim (deterministic, no genome).
const HYBRID_RANK := "wild"

## The display name a nameless hybrid falls back to (a lab creature always carries its oracle name).
const HYBRID_FALLBACK_NAME := "Splice"


## Build one BattleEngine.Mon from a creature dict + the catalog. A spliced hybrid (species_id == "")
## is built from the oracle numbers cached at lab commit (stats_cached.prim/sec/tier). Returns null if
## the species id is absent from the catalog AND no cached stats exist (caller decides how to handle
## the missing-content gap).
static func from_creature(creature: Dictionary, catalog: SpeciesCatalog) -> BattleEngine.Mon:
	var species_id := str(creature.get("species_id", ""))
	if species_id == "":
		return _from_cached_stats(creature)
	var species: SpeciesData = catalog.get_by_id(species_id)
	if species == null:
		return null
	var display_name := str(creature.get("nickname", ""))
	if display_name == "":
		display_name = species.name
	var cls := species.species_class if species.species_class != "" else DEFAULT_CLASS
	var mon := BattleEngine.Mon.new(
		display_name,
		species.force_primary,
		species.force_secondary,
		species.rank,
		species.tier,
		cls
	)
	_compose_growth(mon, creature)
	return mon


## Build a spliced hybrid's Mon from the stats_cached the Lab commit wrote (the oracle's own prim /
## sec / tier). The Mon constructor re-derives the stat block through the SAME oracle call LabEngine
## used (rank "wild", class "organic", no genome), so its stats + HP EQUAL the cached numbers — no
## number is computed here. Returns null when the cache is absent/incomplete (a malformed entry).
static func _from_cached_stats(creature: Dictionary) -> BattleEngine.Mon:
	var cached_raw: Variant = creature.get("stats_cached", {})
	if not (cached_raw is Dictionary):
		return null
	var cached: Dictionary = cached_raw
	var prim := str(cached.get("prim", ""))
	var tier := str(cached.get("tier", ""))
	if prim == "" or tier == "":
		return null
	var display_name := str(creature.get("nickname", ""))
	if display_name == "":
		display_name = HYBRID_FALLBACK_NAME
	var mon := BattleEngine.Mon.new(
		display_name, prim, str(cached.get("sec", "")), HYBRID_RANK, tier, DEFAULT_CLASS
	)
	_compose_growth(mon, creature)
	return mon


## AWAKENINGS FELT (application-layer composition; the domain stays untouched): scale the Mon's
## engine-built CEILING stat block by the creature's growth state via the ORACLE's own model —
## LevelEngine.current_stats(ceiling, expression, gene_bonus). A dict WITHOUT growth state (wild
## enemies, starter/legacy entries) composes at expression 1.0 — the full ceiling, exactly the
## pre-composition behavior — so canonical battle streams over growth-less teams are unchanged.
## HP stays ceiling-derived (the growth model scales pole stats, not HP — mirrors
## CreatureSheet.effective_stats / hp_of).
static func _compose_growth(mon: BattleEngine.Mon, creature: Dictionary) -> void:
	var expression := float(creature.get("expression", 1.0))
	var gene_bonus_raw: Variant = creature.get("gene_bonus", {})
	var gene_bonus: Dictionary = gene_bonus_raw if gene_bonus_raw is Dictionary else {}
	if expression == 1.0 and gene_bonus.is_empty():
		return
	mon.stats = LevelEngine.current_stats(mon.stats, expression, gene_bonus)


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


## Build a team AND a parallel Mon→source-creature-dict map (object identity keyed). The interactive
## battle needs this to map a captured wild Mon back to its species_id / creature dict (the Mon object
## itself — a DOMAIN type — carries no species_id, and we never modify client/domain/). Skipped
## (missing-id) entries are absent from both, so the two stay aligned. Returns
##   { "team": Array[BattleEngine.Mon], "source": Dictionary }  # source: Mon -> creature dict
static func team_with_source(creatures: Array, catalog: SpeciesCatalog) -> Dictionary:
	var team: Array = []
	var source: Dictionary = {}
	for entry in creatures:
		if entry is Dictionary:
			var mon := from_creature(entry as Dictionary, catalog)
			if mon != null:
				team.append(mon)
				source[mon] = entry
	return {"team": team, "source": source}
