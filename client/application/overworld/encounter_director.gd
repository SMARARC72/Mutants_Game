class_name EncounterDirector
extends RefCounted
## EncounterDirector (Phase 5 · Slices 1+4) — the deterministic WILD-ENCOUNTER core the overworld
## drives. APPLICATION/overworld layer. It owns:
##   * the per-STEP encounter roll (does this step trigger a wild fight?),
##   * the enemy-TEAM assembly from the region's WEIGHTED wild pool (SpeciesCatalog),
##   * the per-encounter BATTLE seed,
##   * (Slice 4) the deterministic LEGENDARY-BOSS trigger — the region climax.
## ALL drawn from a CANONICAL sub-stream of the run seed (CanonicalRNG.new(run_seed).substream(...)),
## never global randf/randi — so an entire run's encounter SEQUENCE is reproducible (the slice DoD).
##
## STEP-INDEXED DETERMINISM: each step rolls from a FRESH sub-stream seeded by (run_seed, region,
## step_index), so the result of step N is a pure function of those three — independent of how many
## steps came before, how the player wandered, or load/save. This makes "same seed => same encounter
## sequence" a clean, position-independent property the test can assert by replay.
##
## NO Node / scene here (headless-testable). The overworld calls roll_step() each tile move and, on
## a hit, hands the assembled enemy party + battle seed to a BattleSession.

const EncounterCatalogScript := preload("res://application/overworld/encounter_catalog.gd")

# Disjoint purpose salts so the encounter-trigger stream, the team-pick stream, the battle-seed
# stream, and the boss-fight seed stream never collide within the same (run, region, step) sub-stream.
const _TRIGGER_SALT := 0x454E_4352  # "ENCR"
const _TEAM_SALT := 0x5445_414D  # "TEAM"
const _BATTLE_SALT := 0x4254_4C53  # "BTLS"
const _BOSS_SALT := 0x424F_5353  # "BOSS"

## Per-step probability a wild encounter fires. Wave 3 retune (EXPLICITLY INTERIM, master-plan
## tension 8): 0.22 made walking a battle treadmill; ~0.09 + the overworld's post-battle grace
## window kills it today. Wave 13 REPLACES this flat dial with thin-place gating (~0.30 on veil
## tiles / ~0.04 elsewhere) — do not hand-tune it further here.
const ENCOUNTER_CHANCE := 0.09
## Steps of post-battle breathing room the overworld grants before wild rolls resume (persisted in
## run.world_state by the overworld; the dial lives here beside its sibling ENCOUNTER_CHANCE).
const POST_BATTLE_GRACE_STEPS := 5
## Wild teams in the Verdant fringe are small (1-2) so early fights stay readable.
const ENEMY_TEAM_MIN := 1
const ENEMY_TEAM_MAX := 2

var _run_seed: int
var _region_id: String
var _wild_pool: Array  # Array[String] species ids (declared order)
var _wild_weights: Array  # Array[int], 1:1 with _wild_pool


## `run_seed` ties every roll to the run; `region_id` salts the region's stream; `wild_pool` is the
## region's wild species id list; `wild_weights` (optional) is the parallel weight list (uniform when
## omitted/mismatched). The caller resolves both from EncounterCatalog/SpeciesCatalog.
func _init(run_seed: int, region_id: String, wild_pool: Array, wild_weights: Array = []) -> void:
	_run_seed = run_seed
	_region_id = region_id
	_wild_pool = wild_pool.duplicate()
	if wild_weights.size() == _wild_pool.size():
		_wild_weights = wild_weights.duplicate()
	else:
		_wild_weights = []
		for _i in _wild_pool.size():
			_wild_weights.append(1)


## Build a director for a region by resolving its WEIGHTED wild pool from the static EncounterCatalog.
## The pool ids are validated against the SpeciesCatalog so a typo'd id never reaches battle; the
## weights are returned aligned 1:1 with the surviving ids.
static func for_region(
	run_seed: int, region_id: String, catalog: SpeciesCatalog = null
) -> EncounterDirector:
	var species: SpeciesCatalog = catalog if catalog != null else SpeciesCatalog.new()
	var pool := EncounterCatalogScript.wild_pool_for(region_id, species)
	var weights := EncounterCatalogScript.wild_weights_for(region_id, species)
	return EncounterDirector.new(run_seed, region_id, pool, weights)


## The region wild pool this director draws from (read-only copy).
func wild_pool() -> Array:
	return _wild_pool.duplicate()


## The region wild weights, aligned 1:1 with wild_pool() (read-only copy).
func wild_weights() -> Array:
	return _wild_weights.duplicate()


## Roll ONE overworld step at `step_index`. Returns a result dict:
##   { "encounter": bool, "enemy_party": Array[Dictionary], "battle_seed": int, "step": int }
## When `encounter` is false the party/seed fields are empty/0. Deterministic: same (run_seed,
## region, step_index) always yields the same result. (Boss steps are handled by boss_step(); the
## overworld checks should_trigger_boss() FIRST, then falls through to roll_step for a wild roll.)
func roll_step(step_index: int) -> Dictionary:
	var base := _step_rng(step_index)
	var triggered := base.substream(_TRIGGER_SALT).random() < ENCOUNTER_CHANCE
	if not triggered:
		return {"encounter": false, "enemy_party": [], "battle_seed": 0, "step": step_index}
	var enemy_party := _assemble_enemy_party(base.substream(_TEAM_SALT))
	var battle_seed := base.substream(_BATTLE_SALT).next_u32()
	return {
		"encounter": true,
		"enemy_party": enemy_party,
		"battle_seed": battle_seed,
		"step": step_index,
	}


# === Slice 4: the deterministic legendary-boss trigger (the region climax) ===================== #


## True when the region's boss fight should fire at `step_index`: the player has explored at least
## `min_steps` steps AND the boss has not already been cleared (`already_cleared`) AND the lair has
## not already ambushed this run (`already_fired` — Wave 3: the climax is a ONE-SHOT lair trigger;
## a lost/fled boss fight must never re-ambush on every subsequent step). A pure function of
## (step_index, the slice's boss-trigger config, the two flags) — no RNG, fully reproducible. The
## overworld checks this BEFORE the wild roll so the climax takes precedence at the threshold step.
func should_trigger_boss(
	step_index: int, already_cleared: bool, already_fired: bool = false
) -> bool:
	if already_cleared or already_fired:
		return false
	var boss := EncounterCatalogScript.boss_for(_region_id)
	if boss.is_empty():
		return false
	var trigger := EncounterCatalogScript.boss_trigger_for(_region_id)
	return step_index >= int(trigger.get("min_steps", 30))


## The deterministic boss encounter at `step_index`: a single-creature legendary team + a battle seed
## drawn from a DISJOINT boss sub-stream (so it never collides with the wild streams). Returns:
##   { "boss": true, "enemy_party": Array[Dictionary], "battle_seed": int, "step": int,
##     "boss_brain": String, "species_id": String }
## or {} when the region has no boss configured. The brain key names the strong role brain the
## BattleSession/CombatBrain assigns (NOT the Succession HSM). Same (seed, region, step) => same seed.
func boss_step(step_index: int) -> Dictionary:
	var boss := EncounterCatalogScript.boss_for(_region_id)
	if boss.is_empty():
		return {}
	var species_id := str(boss.get("species_id", ""))
	var party: Array = [{"species_id": species_id, "nickname": str(boss.get("name", species_id))}]
	var battle_seed := _step_rng(step_index).substream(_BOSS_SALT).next_u32()
	return {
		"boss": true,
		"enemy_party": party,
		"battle_seed": battle_seed,
		"step": step_index,
		"boss_brain": str(boss.get("brain", "controller")),
		"species_id": species_id,
	}


# --- internals -------------------------------------------------------------------------------- #


## The canonical sub-stream for one step: derived from the run seed, salted by region + step so the
## per-step roll is position-independent and reproducible. `region_purpose` reuses the worldgen
## FNV-1a region hashing so region salting is consistent across systems.
func _step_rng(step_index: int) -> CanonicalRNG:
	var region_salt := WorldGenerator.region_purpose(_region_id)
	# Combine region + step into one purpose; substream() splitmix-mixes it with the run seed.
	var purpose := region_salt ^ (step_index * 0x9E3779B1)
	return CanonicalRNG.new(_run_seed).substream(purpose)


## Pick an enemy team of canonical size from the WEIGHTED wild pool, each member a creature dict the
## BattleSession/MonFactory understands. Draws size + each weighted pick from the given sub-stream.
func _assemble_enemy_party(rng: CanonicalRNG) -> Array:
	if _wild_pool.is_empty():
		return []
	var size := rng.randint(ENEMY_TEAM_MIN, ENEMY_TEAM_MAX)
	var party: Array = []
	for _i in size:
		var species_id := _weighted_pick(rng)
		party.append({"species_id": species_id})
	return party


## A single weighted draw from the wild pool via the canonical sub-stream. Uses one rng.random() to
## land in the cumulative-weight interval (deterministic + position-stable for a given stream state).
## Falls back to the first id if weights are degenerate (all <= 0).
func _weighted_pick(rng: CanonicalRNG) -> String:
	var total := 0
	for w in _wild_weights:
		total += int(w)
	if total <= 0:
		return str(_wild_pool[0])
	var roll := rng.random() * float(total)
	var acc := 0.0
	for i in _wild_pool.size():
		acc += float(int(_wild_weights[i]))
		if roll < acc:
			return str(_wild_pool[i])
	return str(_wild_pool[_wild_pool.size() - 1])
