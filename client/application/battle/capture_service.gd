class_name CaptureService
extends RefCounted
## CaptureService (Phase 5 · Slice 2) — the headless CAPTURE math + party-add the interactive battle
## calls when the player chooses Capture on a wild target. APPLICATION/battle layer: it ORCHESTRATES
## the oracle, it does NOT reimplement it. The CHANCE + the gear/HP modifiers are computed by the
## DOMAIN oracle (`LootEngine.capture_chance`); the ROLL is a single draw on a CANONICAL capture
## sub-stream derived from the battle seed (never global randf/randi). On success it shapes the wild
## target into a creature_instance dict (the RunContext.party / `creature_instances` column contract)
## the caller appends to the run's party.
##
## DETERMINISM: the capture sub-stream is `CanonicalRNG.new(battle_seed).substream(CAPTURE_SALT)`,
## disjoint from the BattleController's RES/SEL streams, so a capture roll NEVER perturbs the strike
## resolver and same (battle_seed, attempt index) → same roll. The caller advances the SAME service
## RNG for each attempt so multiple attempts in one battle each draw the next canonical value.
##
## NO Node / scene here — unit-testable headless. The chance comes from the DOMAIN LootEngine global
## (referenced directly, like BattleController references BattleEngine — no preload const needed).

## Disjoint capture sub-stream salt ("CAP" + tag) — never collides with BattleController's RES/SEL.
const CAPTURE_SALT := 0x434150_31

## Default capture METHOD when the catalog row carries no acquisition hint (SpeciesData drops the CSV
## `acquisition` column). "befriend" is the gentle Verdant default; "trap" is the alternative dial.
const DEFAULT_METHOD := "befriend"

## creature_instance defaults mirroring the `creature_instances` column contract (data only — the
## oracle derives real stats from the genome later; a caught wild starts at the catalog baseline).
const DEFAULT_EXPRESSION := 0.30
const DEFAULT_BOND := 0

var _rng: CanonicalRNG


## Build a capture service bound to `battle_seed`. The capture roll sub-stream is derived once here so
## successive attempt() calls advance the SAME stream (attempt N is the Nth canonical draw).
func _init(battle_seed: int) -> void:
	_rng = CanonicalRNG.new(battle_seed).substream(CAPTURE_SALT)


## Compute the gear-/HP-modified capture CHANCE for `target` via the oracle, WITHOUT rolling. Pure
## passthrough to LootEngine.capture_chance so callers + tests read the same number the roll uses.
##   target  : the wild BattleEngine.Mon being captured (its live hp/maxhp set hp_frac)
##   species : the target's SpeciesData (its tier feeds the tier_factor)
##   gear    : Array[String] of equipped gear ids (LootEngine.bonus sums their "capture" field)
##   method  : "befriend" | "trap" (DEFAULT_METHOD when "")
##   bond    : befriend-only bond modifier (0 for a wild stranger)
static func chance_for(
	target: BattleEngine.Mon,
	species: SpeciesData,
	gear: Array,
	method: String = "",
	bond: float = 0.0
) -> float:
	var use_method := method if method != "" else DEFAULT_METHOD
	var tier := species.tier if species != null else "T1"
	var hp_frac := _hp_frac(target)
	return LootEngine.capture_chance(use_method, tier, hp_frac, bond, gear)


## Attempt a capture of `target`. Computes the chance (chance_for) then draws ONE value from the
## canonical capture sub-stream. Returns a result dict:
##   { "success": bool, "chance": float, "roll": float,
##     "creature_instance": Dictionary }   # the shaped party entry on success, {} on failure
## The roll is `rng.random() < chance` — the same comparison the loot oracle uses elsewhere.
func attempt(
	target: BattleEngine.Mon,
	species: SpeciesData,
	gear: Array,
	method: String = "",
	bond: float = 0.0
) -> Dictionary:
	var chance := chance_for(target, species, gear, method, bond)
	var roll := _rng.random()
	var success := roll < chance
	var instance: Dictionary = {}
	if success:
		instance = to_creature_instance(target, species)
	return {
		"success": success,
		"chance": chance,
		"roll": roll,
		"creature_instance": instance,
	}


## Shape a caught wild `target` into a creature_instance dict matching the RunContext.party shape +
## the `creature_instances` columns. Data only (no stat math — the oracle derives stats from the
## genome later). `lineage.captured` records the provenance (caught wild, not bred/fused).
static func to_creature_instance(target: BattleEngine.Mon, species: SpeciesData) -> Dictionary:
	var species_id := species.id if species != null else ""
	var nickname := target.name if target != null else ""
	return {
		"species_id": species_id,
		"nickname": nickname,
		"genome": {},  # empty genome → oracle stat_block falls back to all-1.0 (deterministic)
		"expression": DEFAULT_EXPRESSION,
		"bond": DEFAULT_BOND,
		"entropy": 0,
		"awakenings": 0,
		"stats_cached": {},
		"skills": [],
		"status_effects": {},
		"lineage": {"captured": true, "from_species": species_id},
		"is_dead": false,
	}


## The equipped-gear id list from a run's gear map ({slot: gear_id}); the order is the slot insertion
## order (stable). LootEngine.bonus sums each id's "capture" field, so this is what modifies a chance.
static func gear_ids(gear_map: Dictionary) -> Array:
	var out: Array = []
	for slot in gear_map:
		out.append(str(gear_map[slot]))
	return out


# --- internals -------------------------------------------------------------------------------- #


static func _hp_frac(target: BattleEngine.Mon) -> float:
	if target == null or target.maxhp <= 0:
		return 1.0
	return clampf(float(target.hp) / float(target.maxhp), 0.0, 1.0)
