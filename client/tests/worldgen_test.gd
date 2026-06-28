extends GdUnitTestSuite
## Cluster 4 D2 (WorldGenerator / WFC) + D5 (SimpleDungeons set-pieces) — ADR-014.
## Asserts the four DoD properties:
##   1. REPRODUCIBLE     — same (region_id, seed) -> identical Layout (deep-equal tiles).
##   2. PERSISTED, NOT RE-SIMULATED — serialize to a world_state dict, reload, equal WITHOUT
##      calling the solver again.
##   3. AUTHORED FALLBACK — a forced solver failure (over-constrained ruleset / 0 attempts) makes
##      the facade return the authored fallback layout, not a crash/empty grid.
##   4. DETERMINISM ACROSS RUNS — two independent generators, same inputs, agree.
## Plus: the WorkerThreadPool path equals the synchronous one (thread-order-independent), set-piece
## rooms are stitched + persisted, and the canonical sub-stream is the SOLE randomness source.

const LayoutScript := preload("res://infrastructure/worldgen/layout.gd")
const WfcSolverScript := preload("res://infrastructure/worldgen/wfc_solver.gd")
const RegionRulesScript := preload("res://infrastructure/worldgen/region_rules.gd")
const WorldGeneratorScript := preload("res://infrastructure/worldgen/world_generator.gd")
const DungeonAssemblerScript := preload("res://infrastructure/worldgen/dungeon_assembler.gd")

const TEST_SEED := 0x5EED_1234
const REGION := "verdant_glut"


func _gen() -> WorldGenerator:
	var rules: RegionRules = RegionRulesScript.load_default()
	assert_object(rules).is_not_null()  # catalog must load.
	return WorldGeneratorScript.new(rules)


# === 1. REPRODUCIBLE — same (region_id, seed) -> identical tiles ============================== #
func test_same_region_seed_gives_identical_layout() -> void:
	var gen := _gen()
	var a: Layout = gen.generate(REGION, TEST_SEED)
	var b: Layout = gen.generate(REGION, TEST_SEED)
	assert_str(a.region_id).is_equal(REGION)
	assert_int(a.width).is_greater(0)
	assert_int(a.height).is_greater(0)
	# Deep-equal tiles (the canonical generated output).
	assert_bool(a.tiles_equal(b)).is_true()
	# A successful WFC run produces a fully-tiled grid (no EMPTY left).
	assert_bool(a.is_filled()).is_true()
	assert_str(str(a.metadata.get("source", ""))).is_equal("wfc")


# === 4. DETERMINISM ACROSS RUNS — two independent generators agree ============================ #
func test_two_independent_generators_agree() -> void:
	var g1 := _gen()
	var g2 := _gen()
	var a: Layout = g1.generate(REGION, TEST_SEED)
	var b: Layout = g2.generate(REGION, TEST_SEED)
	assert_bool(a.tiles_equal(b)).is_true()
	# And the rooms (set-piece placement) match too — placement draws from the same sub-stream.
	assert_int(a.rooms.size()).is_equal(b.rooms.size())


# A different seed yields a different layout (the generator is seed-sensitive, not constant).
func test_different_seed_differs() -> void:
	var gen := _gen()
	var a: Layout = gen.generate(REGION, TEST_SEED)
	var b: Layout = gen.generate(REGION, TEST_SEED + 1)
	assert_bool(a.tiles_equal(b)).is_false()


# The threaded WorkerThreadPool path yields the SAME layout as the synchronous one (determinism is
# independent of thread scheduling — randomness is the injected canonical sub-stream, ADR-014).
func test_threaded_matches_synchronous() -> void:
	var gen := _gen()
	var sync_layout: Layout = gen.generate(REGION, TEST_SEED)
	var threaded: Layout = gen.generate_threaded(REGION, TEST_SEED)
	assert_bool(sync_layout.tiles_equal(threaded)).is_true()


# === 2. PERSISTED, NOT RE-SIMULATED ========================================================== #
func test_layout_persists_to_world_state_and_reloads_without_solver() -> void:
	var gen := _gen()
	var world_state: Dictionary = {}
	# First visit: generate ONCE + persist into world_state.
	var first: Layout = gen.get_or_generate(REGION, TEST_SEED, world_state)
	assert_bool(world_state.has(WorldGeneratorScript.WORLD_STATE_KEY)).is_true()
	# Round-trip the world_state through JSON (proves it is pure, JSON-stringifiable data).
	var json := JSON.stringify(world_state)
	var reloaded_state: Variant = JSON.parse_string(json)
	assert_bool(reloaded_state is Dictionary).is_true()

	# Reload from the PERSISTED dict with a FRESH generator whose catalog is intentionally absent
	# (rules=null). If load tried to re-run the solver it would have to use the fallback (different
	# tiles); instead load_layout rehydrates the stored grid, so it must equal the original exactly.
	var loader: WorldGenerator = WorldGeneratorScript.new(null)
	var reloaded: Layout = loader.load_layout(REGION, reloaded_state)
	assert_object(reloaded).is_not_null()
	assert_bool(reloaded.tiles_equal(first)).is_true()
	assert_int(reloaded.rooms.size()).is_equal(first.rooms.size())


# get_or_generate REUSES the stored layout (never regenerates): a stored grid is returned verbatim
# even if the seed argument changes — the persisted output is canonical (ADR-014).
func test_get_or_generate_reuses_stored_layout() -> void:
	var gen := _gen()
	var world_state: Dictionary = {}
	var first: Layout = gen.get_or_generate(REGION, TEST_SEED, world_state)
	# Same region, DIFFERENT seed: must return the already-stored layout, NOT a freshly generated one.
	var second: Layout = gen.get_or_generate(REGION, TEST_SEED + 999, world_state)
	assert_bool(second.tiles_equal(first)).is_true()


# === 3. AUTHORED FALLBACK — forced solver failure -> authored layout, never crash/empty ====== #
func test_zero_attempt_budget_triggers_authored_fallback() -> void:
	# An over-constrained ruleset OR a zero attempt budget forces the WFC solver to fail. Build a
	# minimal RegionRules whose region has a 0 attempt_limit and assert the facade returns the
	# authored fallback (a filled, walled room) — not a crash or an empty grid.
	var rules := _rules_with_zero_attempts()
	var gen: WorldGenerator = WorldGeneratorScript.new(rules)
	var layout: Layout = gen.generate("forced_fail", TEST_SEED)
	assert_object(layout).is_not_null()
	assert_bool(layout.is_filled()).is_true()  # fallback is fully tiled (no soft-lock).
	assert_bool(bool(layout.metadata.get("fallback", false))).is_true()
	assert_str(str(layout.metadata.get("source", ""))).is_equal("authored_fallback")


func test_over_constrained_ruleset_triggers_authored_fallback() -> void:
	# A ruleset where every adjacency list is empty makes any >1 grid contradictory.
	var rules := _rules_over_constrained()
	var gen: WorldGenerator = WorldGeneratorScript.new(rules)
	var layout: Layout = gen.generate("forced_fail", TEST_SEED)
	assert_bool(layout.is_filled()).is_true()
	assert_bool(bool(layout.metadata.get("fallback", false))).is_true()


# An unknown region (not in the catalog) also falls back cleanly (no crash).
func test_unknown_region_falls_back() -> void:
	var gen := _gen()
	var layout: Layout = gen.generate("no_such_region", TEST_SEED)
	assert_object(layout).is_not_null()
	assert_bool(layout.is_filled()).is_true()
	assert_bool(bool(layout.metadata.get("fallback", false))).is_true()


# A generator with NO catalog at all still produces a valid fallback for any region (no soft-lock
# even when the ruleset file is missing).
func test_generator_without_catalog_still_returns_layout() -> void:
	var gen: WorldGenerator = WorldGeneratorScript.new(null)
	var layout: Layout = gen.generate(REGION, TEST_SEED)
	assert_object(layout).is_not_null()
	assert_bool(layout.is_filled()).is_true()


# === D5 — SimpleDungeons set-pieces ========================================================== #
func test_setpiece_rooms_are_stitched_and_persisted() -> void:
	# threshold (the hub) authors 3 set-piece rooms (lab/market/arena). They must appear on the
	# layout AND survive the world_state round-trip.
	var gen := _gen()
	var world_state: Dictionary = {}
	var layout: Layout = gen.get_or_generate("threshold", TEST_SEED, world_state)
	assert_int(layout.rooms.size()).is_greater(0)
	var kinds: Array = []
	for r in layout.rooms:
		kinds.append(str((r as Dictionary).get("kind", "")))
	assert_bool(kinds.has("lab")).is_true()
	# Persisted rooms survive reload.
	var loader: WorldGenerator = WorldGeneratorScript.new(null)
	var reloaded: Layout = loader.load_layout("threshold", world_state)
	assert_int(reloaded.rooms.size()).is_equal(layout.rooms.size())


# Stitched rooms never overlap (the assembler rejects overlapping placements, +margin).
func test_setpiece_rooms_do_not_overlap() -> void:
	var gen := _gen()
	var layout: Layout = gen.generate("threshold", TEST_SEED)
	var rooms: Array = layout.rooms
	for i in rooms.size():
		for j in range(i + 1, rooms.size()):
			assert_bool(_rooms_overlap(rooms[i], rooms[j])).is_false()


# === Layout serialization (versioned-JSON, data-only; ADR-012) =============================== #
func test_layout_serialization_is_pure_data() -> void:
	var gen := _gen()
	var layout: Layout = gen.generate(REGION, TEST_SEED)
	var data := layout.to_dict()
	var json := JSON.stringify(data)
	var parsed: Variant = JSON.parse_string(json)
	assert_bool(parsed is Dictionary).is_true()
	var back: Layout = LayoutScript.from_dict(parsed)
	# tiles survive the JSON float-decode (int()-wrapped on rehydrate, not turned into 0.0 floats).
	assert_bool(back.tiles_equal(layout)).is_true()
	assert_int(back.width).is_equal(layout.width)
	assert_str(back.region_id).is_equal(layout.region_id)


# === WFC solver unit checks (the core, in isolation) ========================================= #
func test_wfc_solver_fills_a_valid_grid() -> void:
	var rules := _toy_wfc_rules()
	var solver: WfcSolver = WfcSolverScript.new(8, 8, rules, 20000)
	var rng := CanonicalRNG.new(TEST_SEED)
	var grid: PackedInt32Array = solver.solve(rng)
	assert_int(grid.size()).is_equal(64)
	assert_int(solver.last_result()).is_equal(WfcSolverScript.Result.OK)
	# No EMPTY sentinel remains.
	for t in grid:
		assert_int(t).is_not_equal(LayoutScript.EMPTY)


func test_wfc_solver_same_seed_same_grid() -> void:
	var rules := _toy_wfc_rules()
	var a: PackedInt32Array = WfcSolverScript.new(8, 8, rules, 20000).solve(CanonicalRNG.new(7))
	var b: PackedInt32Array = WfcSolverScript.new(8, 8, rules, 20000).solve(CanonicalRNG.new(7))
	assert_bool(a == b).is_true()


func test_wfc_solver_zero_budget_fails_cleanly() -> void:
	var rules := _toy_wfc_rules()
	var solver: WfcSolver = WfcSolverScript.new(8, 8, rules, 0)
	var grid: PackedInt32Array = solver.solve(CanonicalRNG.new(7))
	assert_int(grid.size()).is_equal(0)
	assert_int(solver.last_result()).is_equal(WfcSolverScript.Result.BUDGET_EXHAUSTED)


# === canonical RNG derivation =============================================================== #
func test_region_rng_is_pure_and_reproducible() -> void:
	# The facade's sub-stream is rebuildable from (seed, region_id) — the property a replay/parity
	# check relies on. Two derivations draw the SAME first float.
	var r1 := WorldGeneratorScript.region_rng(TEST_SEED, REGION)
	var r2 := WorldGeneratorScript.region_rng(TEST_SEED, REGION)
	assert_float(r1.next_float()).is_equal(r2.next_float())
	# Different regions derive different streams.
	var ra := WorldGeneratorScript.region_rng(TEST_SEED, "verdant_glut")
	var rb := WorldGeneratorScript.region_rng(TEST_SEED, "mournmarch")
	assert_float(ra.next_float()).is_not_equal(rb.next_float())


# --- fixtures / helpers ---------------------------------------------------------------------- #


func _toy_wfc_rules() -> Dictionary:
	# A permissive 3-tile ruleset that always solves: 0 neighbours anything; 1 neighbours 0/1;
	# 2 neighbours 0/2 (same shape as the catalog defaults, normalised to int keys/ids).
	return {
		"tiles": [0, 1, 2],
		"weights": {0: 6.0, 1: 1.0, 2: 2.0},
		"adjacency":
		{
			"N": {0: [0, 1, 2], 1: [0, 1], 2: [0, 2]},
			"E": {0: [0, 1, 2], 1: [0, 1], 2: [0, 2]},
			"S": {0: [0, 1, 2], 1: [0, 1], 2: [0, 2]},
			"W": {0: [0, 1, 2], 1: [0, 1], 2: [0, 2]},
		},
	}


func _rules_with_zero_attempts() -> RegionRules:
	var text := (
		'{"schema_version":1,"defaults":{"width":12,"height":12,"attempt_limit":20000},'
		+ '"regions":{"forced_fail":{"tiles":[0,1,2],"attempt_limit":0,'
		+ '"weights":{"0":1,"1":1,"2":1},'
		+ '"adjacency":{"N":{"0":[0,1,2],"1":[0],"2":[0]},"E":{"0":[0,1,2],"1":[0],"2":[0]},'
		+ '"S":{"0":[0,1,2],"1":[0],"2":[0]},"W":{"0":[0,1,2],"1":[0],"2":[0]}}}}}'
	)
	return RegionRulesScript.load_text(text)


func _rules_over_constrained() -> RegionRules:
	# Every adjacency list empty -> any grid larger than 1x1 is contradictory.
	var text := (
		'{"schema_version":1,"defaults":{"width":8,"height":8,"attempt_limit":5000},'
		+ '"regions":{"forced_fail":{"tiles":[0,1],"weights":{"0":1,"1":1},'
		+ '"adjacency":{"N":{"0":[],"1":[]},"E":{"0":[],"1":[]},'
		+ '"S":{"0":[],"1":[]},"W":{"0":[],"1":[]}}}}}'
	)
	return RegionRulesScript.load_text(text)


func _rooms_overlap(a: Dictionary, b: Dictionary) -> bool:
	var ax: int = int(a["x"])
	var ay: int = int(a["y"])
	var aw: int = int(a["w"])
	var ah: int = int(a["h"])
	var bx: int = int(b["x"])
	var by: int = int(b["y"])
	var bw: int = int(b["w"])
	var bh: int = int(b["h"])
	return ax < bx + bw and bx < ax + aw and ay < by + bh and by < ay + ah
