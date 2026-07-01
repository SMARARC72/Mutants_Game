class_name LevelingService
extends RefCounted
## LevelingService (Phase 5 · Slice 3b) — the headless LEVELING orchestration the party screen calls.
## APPLICATION/game layer: it ORCHESTRATES the DOMAIN oracle, it REIMPLEMENTS no growth math.
##
## Two player actions on a selected creature_instance:
##   * RESONANCE awaken — spend essence to trigger a natural awakening. The numbers (the expression
##     surge, the maybe-gene, the maybe-branch) are computed by LevelEngine.awaken (the oracle). We
##     apply the returned result onto the creature_instance (expression / gene_bonus / genes /
##     awakenings) and debit essence.
##   * OVERCLOCK gamble — when essence is short / a measured awaken stalls, FORCE an awakening by
##     banking ENTROPY (instability) + adding run CORRUPTION. The forced-entropy magnitude is a
##     CANONICAL roll (rng.randint over Constants.level.overclock_entropy_lo..hi) and the awakening
##     itself is again LevelEngine.awaken — so the WHOLE gamble is deterministic from the seed.
##
## DETERMINISM (the slice DoD): every roll draws from a CANONICAL sub-stream derived from
## (run.seed + an op id). The op id folds in WHICH creature + its awakening count, so each awaken on
## each creature draws a fresh, replayable value and two identical runs gamble identically.
##   rng = CanonicalRNG.new(run.seed).substream(op_id(creature, salt))
##
## PURE w.r.t. the SceneTree (no Node) — the caller (party screen) owns persistence + the run.

## Sub-stream salts (disjoint op ids so resonance and overclock never share a draw sequence).
const RESONANCE_SALT := 0x4C56_5200  # "LVR" — resonance awaken
const OVERCLOCK_SALT := 0x4C56_4F00  # "LVO" — overclock gamble

## Essence cost of a resonance awaken (Slice-1/2 fold battle xp into run.essence; awakening spends
## it). A flat MVP cost; a later slice scales it by awakening count.
const RESONANCE_ESSENCE_COST := 20

## The expression a creature starts at if it carries none yet (the caught baseline).
const DEFAULT_EXPRESSION := 0.30


static func _level() -> Dictionary:
	return Constants.BALANCE["level"]


## True if the run can AFFORD a resonance awaken (>= RESONANCE_ESSENCE_COST essence).
static func can_afford_resonance(run: RunContext) -> bool:
	return run != null and run.essence >= RESONANCE_ESSENCE_COST


## The resonance success CHANCE for a creature, per the oracle's table (Constants.level): it climbs
## with attempts and the creature's Luck, capped. `attempts` is the number of stalls since the last
## awaken (0 for the MVP single-shot button); `luck` is the ceiling Luck stat. This is the SAME
## formula the oracle's level simulate() uses (chance = min(cap, base + per_attempt*attempts +
## luck*luck_factor)) — read from the single-sourced constants, not invented here.
static func resonance_chance(attempts: int, luck: float) -> float:
	var lvl := _level()
	var chance := (
		float(lvl["resonance_chance_base"])
		+ float(lvl["resonance_chance_per_attempt"]) * float(attempts)
		+ luck * float(lvl["resonance_chance_luck_factor"])
	)
	return minf(float(lvl["resonance_chance_cap"]), chance)


## RESONANCE AWAKEN a creature_instance, spending essence. Computes the awakening via the ORACLE
## (LevelEngine.awaken) on a canonical sub-stream, applies the result onto the creature in place, and
## debits the run's essence. Returns a ledger dict for the UI:
##   { "ok": bool, "reason": String, "events": Array[String],
##     "expression_before": float, "expression_after": float,
##     "essence_spent": int, "essence_after": int, "awakenings": int }
## ok=false (with a reason) when there is no creature/run or the essence is short — no mutation then.
static func awaken_resonance(run: RunContext, creature: Dictionary) -> Dictionary:
	if run == null or creature == null or creature.is_empty():
		return _fail("no_target")
	if not can_afford_resonance(run):
		return _fail("insufficient_essence")
	var expr_before := _expression_of(creature)
	var rng := _rng_for(run, creature, RESONANCE_SALT)
	var result := _apply_awaken(rng, creature)
	run.essence -= RESONANCE_ESSENCE_COST
	return {
		"ok": true,
		"reason": "resonance",
		"events": result["events"],
		"expression_before": expr_before,
		"expression_after": _expression_of(creature),
		"essence_spent": RESONANCE_ESSENCE_COST,
		"essence_after": run.essence,
		"awakenings": int(creature.get("awakenings", 0)),
	}


## OVERCLOCK gamble a creature_instance: FORCE an awakening, banking ENTROPY (a canonical roll over
## the oracle's overclock_entropy_lo..hi range) onto the creature and adding that as run CORRUPTION
## (the player track). The awakening itself is again LevelEngine.awaken. Whole thing is canonical:
## the SAME (run.seed, creature, awakening count) gambles identically. Returns the cost ledger:
##   { "ok": bool, "reason": "overclock", "events": Array[String],
##     "expression_before": float, "expression_after": float,
##     "entropy_gained": int, "entropy_after": int,
##     "corruption_gained": int, "corruption_after": int, "burnout": bool, "awakenings": int }
## No essence cost — the overclock pays in instability, not growth resource (design §4.1).
static func overclock(run: RunContext, creature: Dictionary) -> Dictionary:
	if run == null or creature == null or creature.is_empty():
		return _fail("no_target")
	var lvl := _level()
	var expr_before := _expression_of(creature)
	var rng := _rng_for(run, creature, OVERCLOCK_SALT)
	# Bank entropy FIRST (matches the oracle simulate(): forced -> entropy += randint(lo,hi), THEN
	# awaken) so the awaken draws the next canonical value, keeping the stream order oracle-faithful.
	var entropy_gain := rng.randint(
		int(lvl["overclock_entropy_lo"]), int(lvl["overclock_entropy_hi"])
	)
	var entropy_after := int(creature.get("entropy", 0)) + entropy_gain
	creature["entropy"] = entropy_after
	var result := _apply_awaken(rng, creature)
	# Overclock instability feeds the run's cumulative CORRUPTION track (ADR-014: carried unclamped).
	run.corruption += entropy_gain
	var burnout := entropy_after >= int(lvl["burnout"])
	return {
		"ok": true,
		"reason": "overclock",
		"events": result["events"],
		"expression_before": expr_before,
		"expression_after": _expression_of(creature),
		"entropy_gained": entropy_gain,
		"entropy_after": entropy_after,
		"corruption_gained": entropy_gain,
		"corruption_after": run.corruption,
		"burnout": burnout,
		"awakenings": int(creature.get("awakenings", 0)),
	}


# --- internals -------------------------------------------------------------------------------- #


## Run LevelEngine.awaken (the ORACLE) on `creature`'s mutable growth state, writing the mutated
## expression / gene_bonus / genes / awakenings BACK onto the creature_instance in place. Returns the
## oracle result { "expression": float, "events": Array }. gene_bonus + genes are mutated by awaken
## itself (by-reference) — we read them back from the creature dict's own containers, so the mutation
## persists on the instance.
static func _apply_awaken(rng: CanonicalRNG, creature: Dictionary) -> Dictionary:
	var expression := _expression_of(creature)
	# Use the instance's OWN containers so LevelEngine.awaken mutates them in place (by-reference).
	# Coerce via Variant first: a typed `var d: Dictionary = creature.get(...)` would ERROR (not
	# fall through) if the stored value were ever a non-Dictionary, so guard the type explicitly.
	var gene_bonus_raw: Variant = creature.get("gene_bonus", {})
	var gene_bonus: Dictionary = gene_bonus_raw if gene_bonus_raw is Dictionary else {}
	var genes_raw: Variant = creature.get("genes", [])
	var genes: Array = genes_raw if genes_raw is Array else []
	# Ensure the containers live ON the creature (a freshly-caught instance may lack the keys).
	creature["gene_bonus"] = gene_bonus
	creature["genes"] = genes
	var result := LevelEngine.awaken(rng, expression, gene_bonus, genes)
	creature["expression"] = float(result["expression"])
	creature["awakenings"] = int(creature.get("awakenings", 0)) + 1
	# Invalidate any cached display stats so the screen recomputes from the new expression — but
	# NEVER for a spliced hybrid (species_id == ""): its stats_cached IS the oracle ceiling cached at
	# lab commit (there is no species row to re-derive from), so wiping it would orphan the creature.
	if str(creature.get("species_id", "")) != "":
		creature["stats_cached"] = {}
	return result


## Build a CANONICAL sub-stream for an op on a specific creature. The op id folds in the run seed,
## the salt (resonance vs overclock), a stable creature key, and the creature's awakening count so
## each awaken draws a fresh, replayable value. Same (seed, creature, count) => same stream.
static func _rng_for(run: RunContext, creature: Dictionary, salt: int) -> CanonicalRNG:
	var op := salt ^ _creature_key(creature) ^ (int(creature.get("awakenings", 0)) << 8)
	return CanonicalRNG.new(run.seed).substream(op)


## A stable integer key for a creature_instance, derived from its species id + nickname so two
## different party members awaken on disjoint streams (and the same member is reproducible).
static func _creature_key(creature: Dictionary) -> int:
	var ident := str(creature.get("species_id", "")) + "|" + str(creature.get("nickname", ""))
	return int(ident.hash())


static func _expression_of(creature: Dictionary) -> float:
	return float(creature.get("expression", DEFAULT_EXPRESSION))


static func _fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason, "events": []}
