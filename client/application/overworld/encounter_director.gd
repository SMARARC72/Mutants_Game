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
## step_index, tile_class), so the result of step N is a pure function of those four — independent
## of how many steps came before, how the player wandered, or load/save. This makes "same seed +
## same tile classes => same encounter sequence" a clean, position-independent property the test
## can assert by replay. Wave 13: thin-place cells gate the rate (~0.30 vs ~0.04), a ~1/6 kind
## sub-roll marks peculiar (non-battle) encounters, and ~1/12 of thin battle hits MISBEHAVE
## (one T3 from the region elite pool — "the veil coughs").
##
## NO Node / scene here (headless-testable). The overworld calls roll_step() each tile move and, on
## a hit, hands the assembled enemy party + battle seed to a BattleSession.

const EncounterCatalogScript := preload("res://application/overworld/encounter_catalog.gd")

# Disjoint purpose salts so the encounter-trigger stream, the team-pick stream, the battle-seed
# stream, the boss-fight seed stream, and the Wave-13 sub-rolls (kind / misbehavior / elite pick)
# never collide within the same (run, region, step, tile-class) sub-stream.
const _TRIGGER_SALT := 0x454E_4352  # "ENCR"
const _TEAM_SALT := 0x5445_414D  # "TEAM"
const _BATTLE_SALT := 0x4254_4C53  # "BTLS"
const _BOSS_SALT := 0x424F_5353  # "BOSS"
const _KIND_SALT := 0x4B49_4E44  # "KIND" — battle-vs-peculiar sub-stream (W13 seam, W16b consumes)
const _MISBEHAVIOR_SALT := 0x4D49_5342  # "MISB" — the thin-cell "veil coughs" sub-roll
const _ELITE_SALT := 0x454C_4954  # "ELIT" — the misbehavior elite-pick stream

## Wave 13 THIN-PLACE GATING (supersedes the Wave 3 interim flat retune — master-plan tension 8):
## the ritual-accent cells (OverworldTileSet.is_thin_place over feature cells) are the REAL
## encounter surface. Paths and open ground are near-safe; shimmering veil tiles are a visible,
## chosen dare. The overworld folds the stepped cell's class into roll_step(step, tile_class).
const ENCOUNTER_CHANCE := 0.04  # base per-step chance OFF the veil (paths/ground)
const ENCOUNTER_CHANCE_THIN := 0.30  # per-step chance ON a thin-place cell
## The tile-class token the overworld passes for a thin-place cell ("" = everything else).
const TILE_CLASS_THIN := "thin"
## ~1 in 6 triggered encounters are PECULIAR (kind:"peculiar") — non-battle beats the W16b
## sibling wires; the overworld routes them to peculiar_encounter(), never the battle scene.
const PECULIAR_ODDS := 6
## ~1 in 12 thin-cell BATTLE hits misbehave: the veil coughs up a T3 from the elite pool.
const MISBEHAVIOR_ODDS := 12
const KIND_BATTLE := "battle"
const KIND_PECULIAR := "peculiar"
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
var _elite_pool: Array  # Array[String] T3 elite ids (misbehavior draws; may be empty)
var _elite_weights: Array  # Array[int], 1:1 with _elite_pool


## `run_seed` ties every roll to the run; `region_id` salts the region's stream; `wild_pool` is the
## region's wild species id list; `wild_weights` (optional) is the parallel weight list (uniform when
## omitted/mismatched). `elite_pool`/`elite_weights` (optional, W13) feed the thin-cell misbehavior
## draw; an empty elite pool simply never misbehaves. All defaulted so pre-W13 callers compile.
## The caller resolves the lists from EncounterCatalog/SpeciesCatalog.
func _init(
	run_seed: int,
	region_id: String,
	wild_pool: Array,
	wild_weights: Array = [],
	elite_pool: Array = [],
	elite_weights: Array = []
) -> void:
	_run_seed = run_seed
	_region_id = region_id
	_wild_pool = wild_pool.duplicate()
	_wild_weights = _aligned_weights(wild_weights, _wild_pool.size())
	_elite_pool = elite_pool.duplicate()
	_elite_weights = _aligned_weights(elite_weights, _elite_pool.size())


## `weights` when it aligns 1:1 with a pool of `size`, else a uniform all-ones list.
static func _aligned_weights(weights: Array, size: int) -> Array:
	if weights.size() == size:
		return weights.duplicate()
	var out: Array = []
	for _i in size:
		out.append(1)
	return out


## Build a director for a region by resolving its WEIGHTED wild pool (and the W13 elite pool)
## from the static EncounterCatalog. The pool ids are validated against the SpeciesCatalog so a
## typo'd id never reaches battle; the weights are returned aligned 1:1 with the surviving ids.
static func for_region(
	run_seed: int, region_id: String, catalog: SpeciesCatalog = null
) -> EncounterDirector:
	var species: SpeciesCatalog = catalog if catalog != null else SpeciesCatalog.new()
	var pool := EncounterCatalogScript.wild_pool_for(region_id, species)
	var weights := EncounterCatalogScript.wild_weights_for(region_id, species)
	var elites := EncounterCatalogScript.elite_pool_for(region_id, species)
	var elite_weights := EncounterCatalogScript.elite_weights_for(region_id, species)
	return EncounterDirector.new(run_seed, region_id, pool, weights, elites, elite_weights)


## The region wild pool this director draws from (read-only copy).
func wild_pool() -> Array:
	return _wild_pool.duplicate()


## The region wild weights, aligned 1:1 with wild_pool() (read-only copy).
func wild_weights() -> Array:
	return _wild_weights.duplicate()


## The region's T3 elite pool the misbehavior sub-roll draws from (read-only copy; may be empty).
func elite_pool() -> Array:
	return _elite_pool.duplicate()


## Roll ONE overworld step at `step_index`. `tile_class` is the stepped cell's encounter class
## (TILE_CLASS_THIN on a thin-place cell, "" elsewhere — DEFAULTED so pre-W13 callers compile;
## it is folded into the purpose-hash salt, so the two classes are disjoint canonical streams).
## Returns a result dict:
##   { "encounter": bool, "enemy_party": Array[Dictionary], "battle_seed": int, "step": int,
##     "kind": "battle"|"peculiar"|"" (miss), "misbehavior": bool }
## When `encounter` is false the party/seed/kind fields are empty/0. Deterministic: the same
## (run_seed, region, step_index, tile_class) always yields the same result. Sub-roll order:
## trigger -> kind (~1/6 peculiar) -> misbehavior (battle-kind thin hits only, ~1/12, drawing ONE
## T3 from the elite pool — "the veil coughs"). Peculiars keep their ordinary wild party (the
## W16b consumer may ignore it) and NEVER misbehave — they must never become a battle. (Boss
## steps are handled by boss_step(); the overworld checks should_trigger_boss() FIRST.)
func roll_step(step_index: int, tile_class: String = "") -> Dictionary:
	var base := _step_rng(step_index, tile_class)
	var chance := ENCOUNTER_CHANCE_THIN if tile_class == TILE_CLASS_THIN else ENCOUNTER_CHANCE
	var triggered := base.substream(_TRIGGER_SALT).random() < chance
	if not triggered:
		return {
			"encounter": false,
			"enemy_party": [],
			"battle_seed": 0,
			"step": step_index,
			"kind": "",
			"misbehavior": false,
		}
	var kind := KIND_BATTLE
	if base.substream(_KIND_SALT).randint(1, PECULIAR_ODDS) == 1:
		kind = KIND_PECULIAR
	var enemy_party := _assemble_enemy_party(base.substream(_TEAM_SALT))
	var misbehavior := false
	if kind == KIND_BATTLE and tile_class == TILE_CLASS_THIN and not _elite_pool.is_empty():
		if base.substream(_MISBEHAVIOR_SALT).randint(1, MISBEHAVIOR_ODDS) == 1:
			misbehavior = true
			var elite := _weighted_pick(base.substream(_ELITE_SALT), _elite_pool, _elite_weights)
			enemy_party = [{"species_id": elite}]
	var battle_seed := base.substream(_BATTLE_SALT).next_u32()
	return {
		"encounter": true,
		"enemy_party": enemy_party,
		"battle_seed": battle_seed,
		"step": step_index,
		"kind": kind,
		"misbehavior": misbehavior,
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


## The deterministic boss encounter at `step_index`: a single-creature boss team + a battle seed
## drawn from a DISJOINT boss sub-stream (so it never collides with the wild streams). Returns:
##   { "boss": true, "enemy_party": Array[Dictionary], "battle_seed": int, "step": int,
##     "boss_brain": String, "species_id": String,
##     "boss_id": String, "intro_line": String, "defeat_line": String }
## or {} when the region has no boss configured. The brain key names the strong role brain the
## BattleSession/CombatBrain assigns (NOT the Succession HSM). Same (seed, region, step) => same seed.
## Batch E1c: a PANTHEON boss config (BossKitCatalog via EncounterCatalog.boss_for) additionally
## carries its authored library-only kit — folded into the party dict as `kit_override` so the
## SkillMonFactory builds the enemy with the AUTHORED kit; the boss_id + VERBATIM intro/defeat
## lines ride the roll for the presentation layer. The verdant slice boss carries none of these
## keys, so its party dict (and battle stream) stays byte-identical.
func boss_step(step_index: int) -> Dictionary:
	var boss := EncounterCatalogScript.boss_for(_region_id)
	if boss.is_empty():
		return {}
	var species_id := str(boss.get("species_id", ""))
	var member := {"species_id": species_id, "nickname": str(boss.get("name", species_id))}
	var kit: Variant = boss.get("kit", null)
	if kit is Array and not (kit as Array).is_empty():
		member["kit_override"] = (kit as Array).duplicate()
	if str(boss.get("boss_id", "")) != "":
		member["boss_id"] = str(boss["boss_id"])
	var battle_seed := _step_rng(step_index).substream(_BOSS_SALT).next_u32()
	return {
		"boss": true,
		"enemy_party": [member],
		"battle_seed": battle_seed,
		"step": step_index,
		"boss_brain": str(boss.get("brain", "controller")),
		"species_id": species_id,
		"boss_id": str(boss.get("boss_id", "")),
		"intro_line": str(boss.get("intro_line", "")),
		"defeat_line": str(boss.get("defeat_line", "")),
	}


# --- internals -------------------------------------------------------------------------------- #


## The canonical sub-stream for one step: derived from the run seed, salted by region + step (+ the
## W13 tile class) so the per-step roll is position-independent and reproducible. `region_purpose`
## reuses the worldgen FNV-1a hashing so region AND tile-class salting stay consistent across
## systems. An empty tile_class folds to 0, keeping the pre-W13 stream bit-identical for defaulted
## callers (boss_step, older tests) — correction C7.
func _step_rng(step_index: int, tile_class: String = "") -> CanonicalRNG:
	var region_salt := WorldGenerator.region_purpose(_region_id)
	# Combine region + step + class into one purpose; substream() splitmix-mixes it with the seed.
	var purpose := region_salt ^ (step_index * 0x9E3779B1) ^ _tile_class_salt(tile_class)
	return CanonicalRNG.new(_run_seed).substream(purpose)


## Deterministic salt for a tile class: 0 for the default class (stream unchanged vs pre-W13),
## else the same FNV-1a string purpose the worldgen uses for region ids.
static func _tile_class_salt(tile_class: String) -> int:
	if tile_class == "":
		return 0
	return WorldGenerator.region_purpose(tile_class)


## Pick an enemy team of canonical size from the WEIGHTED wild pool, each member a creature dict the
## BattleSession/MonFactory understands. Draws size + each weighted pick from the given sub-stream.
func _assemble_enemy_party(rng: CanonicalRNG) -> Array:
	if _wild_pool.is_empty():
		return []
	var size := rng.randint(ENEMY_TEAM_MIN, ENEMY_TEAM_MAX)
	var party: Array = []
	for _i in size:
		var species_id := _weighted_pick(rng, _wild_pool, _wild_weights)
		party.append({"species_id": species_id})
	return party


## A single weighted draw from `pool` via the canonical sub-stream. Uses one rng.random() to land
## in the cumulative-weight interval (deterministic + position-stable for a given stream state).
## Falls back to the first id if weights are degenerate (all <= 0).
static func _weighted_pick(rng: CanonicalRNG, pool: Array, weights: Array) -> String:
	var total := 0
	for w in weights:
		total += int(w)
	if total <= 0:
		return str(pool[0])
	var roll := rng.random() * float(total)
	var acc := 0.0
	for i in pool.size():
		acc += float(int(weights[i]))
		if roll < acc:
			return str(pool[i])
	return str(pool[pool.size() - 1])
