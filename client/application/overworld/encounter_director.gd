class_name EncounterDirector
extends RefCounted
## EncounterDirector (Phase 5 · Slice 1) — the deterministic WILD-ENCOUNTER core the overworld
## drives. APPLICATION/overworld layer. It owns:
##   * the per-STEP encounter roll (does this step trigger a wild fight?),
##   * the enemy-TEAM assembly from the region's wild pool (SpeciesCatalog),
##   * the per-encounter BATTLE seed,
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

# Disjoint purpose salts so the encounter-trigger stream, the team-pick stream, and the battle-seed
# stream never collide within the same (run, region, step) sub-stream derivation.
const _TRIGGER_SALT := 0x454E_4352  # "ENCR"
const _TEAM_SALT := 0x5445_414D  # "TEAM"
const _BATTLE_SALT := 0x4254_4C53  # "BTLS"

## Per-step probability a wild encounter fires (Slice 1 dial; gentle Verdant onboarding).
const ENCOUNTER_CHANCE := 0.22
## Wild teams in the Verdant fringe are small (1-2) so early fights stay readable.
const ENEMY_TEAM_MIN := 1
const ENEMY_TEAM_MAX := 2

var _run_seed: int
var _region_id: String
var _wild_pool: Array  # Array[String] species ids


## `run_seed` ties every roll to the run; `region_id` salts the region's stream; `wild_pool` is the
## region's wild species id list (the caller resolves it from EncounterCatalog/SpeciesCatalog).
func _init(run_seed: int, region_id: String, wild_pool: Array) -> void:
	_run_seed = run_seed
	_region_id = region_id
	_wild_pool = wild_pool.duplicate()


## Build a director for a region by resolving its wild pool from the static EncounterCatalog. The
## pool ids are validated against the SpeciesCatalog so a typo'd id never reaches battle.
static func for_region(
	run_seed: int, region_id: String, catalog: SpeciesCatalog = null
) -> EncounterDirector:
	var species: SpeciesCatalog = catalog if catalog != null else SpeciesCatalog.new()
	var pool := EncounterCatalogScript.wild_pool_for(region_id, species)
	return EncounterDirector.new(run_seed, region_id, pool)


## The region wild pool this director draws from (read-only copy).
func wild_pool() -> Array:
	return _wild_pool.duplicate()


## Roll ONE overworld step at `step_index`. Returns a result dict:
##   { "encounter": bool, "enemy_party": Array[Dictionary], "battle_seed": int, "step": int }
## When `encounter` is false the party/seed fields are empty/0. Deterministic: same (run_seed,
## region, step_index) always yields the same result.
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


# --- internals -------------------------------------------------------------------------------- #


## The canonical sub-stream for one step: derived from the run seed, salted by region + step so the
## per-step roll is position-independent and reproducible. `region_purpose` reuses the worldgen
## FNV-1a region hashing so region salting is consistent across systems.
func _step_rng(step_index: int) -> CanonicalRNG:
	var region_salt := WorldGenerator.region_purpose(_region_id)
	# Combine region + step into one purpose; substream() splitmix-mixes it with the run seed.
	var purpose := region_salt ^ (step_index * 0x9E3779B1)
	return CanonicalRNG.new(_run_seed).substream(purpose)


## Pick an enemy team of canonical size from the wild pool, each member a creature dict the
## BattleSession/MonFactory understands. Draws size + each pick from the given sub-stream.
func _assemble_enemy_party(rng: CanonicalRNG) -> Array:
	if _wild_pool.is_empty():
		return []
	var size := rng.randint(ENEMY_TEAM_MIN, ENEMY_TEAM_MAX)
	var party: Array = []
	for _i in size:
		var species_id := str(rng.choice(_wild_pool))
		party.append({"species_id": species_id})
	return party
