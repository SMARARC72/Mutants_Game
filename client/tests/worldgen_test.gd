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

# Backtracking fixture (see test_backtracking_path_actually_fires): seeds 1/4/7 are pre-verified
# against the canonical PCG32 to UNWIND on a 16x16 grid with the frustrated ruleset below.
const BACKTRACK_SEEDS := [1, 4, 7]
const BACKTRACK_W := 16
const BACKTRACK_H := 16


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
	# threshold (the hub) authors 3 set-piece rooms (lab/market/arena) and is sized so all THREE fit.
	# Assert all three are present (not just one) — a silently-dropped market/arena must fail — and
	# that they survive the world_state round-trip FIELD-BY-FIELD (kind/x/y/w/h), not count-only.
	var gen := _gen()
	var world_state: Dictionary = {}
	var layout: Layout = gen.get_or_generate("threshold", TEST_SEED, world_state)
	assert_int(layout.rooms.size()).is_equal(3)
	var kinds: Array = []
	for r in layout.rooms:
		kinds.append(str((r as Dictionary).get("kind", "")))
	assert_bool(kinds.has("lab")).is_true()
	assert_bool(kinds.has("market")).is_true()
	assert_bool(kinds.has("arena")).is_true()
	# Persisted rooms survive reload — compare each room dict field-by-field, not just the count.
	var loader: WorldGenerator = WorldGeneratorScript.new(null)
	var reloaded: Layout = loader.load_layout("threshold", world_state)
	assert_int(reloaded.rooms.size()).is_equal(layout.rooms.size())
	for i in layout.rooms.size():
		var orig: Dictionary = layout.rooms[i]
		var back: Dictionary = reloaded.rooms[i]
		assert_str(str(back["kind"])).is_equal(str(orig["kind"]))
		assert_int(int(back["x"])).is_equal(int(orig["x"]))
		assert_int(int(back["y"])).is_equal(int(orig["y"]))
		assert_int(int(back["w"])).is_equal(int(orig["w"]))
		assert_int(int(back["h"])).is_equal(int(orig["h"]))


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


# === BACKTRACKING is actually exercised (the determinism-fragile path) ======================= #
# The permissive rulesets above never make a cell dead-end, so the unwind code (_retry_or_backtrack
# / _backtrack — the part that RE-DRAWS from the canonical RNG on retry) never runs. A "frustrated"
# ruleset (tile 3 has no horizontal neighbours; tile 0 has no vertical neighbours) forces the solver
# to paint itself into corners and UNWIND. We assert backtracking genuinely fired (backtracks_used()
# > 0, a direct signal — not just attempts > w*h) AND that the result is still bit-identical for the
# same seed and differs for a different seed. This gives the reproducibility contract teeth over the
# backtrack path. (BACKTRACK_SEEDS / BACKTRACK_W / BACKTRACK_H are declared in the consts block.)
func test_backtracking_path_fires_and_is_reproducible() -> void:
	var rules := _backtrack_forcing_rules()
	# (a) The fragile unwind path ACTUALLY RUNS for each pre-verified seed, still solving a valid,
	# fully-tiled grid. backtracks_used() > 0 is the direct proof; attempts > w*h corroborates.
	for seed in BACKTRACK_SEEDS:
		var solver: WfcSolver = WfcSolverScript.new(BACKTRACK_W, BACKTRACK_H, rules, 1_000_000)
		var grid: PackedInt32Array = solver.solve(CanonicalRNG.new(seed))
		assert_int(grid.size()).is_equal(BACKTRACK_W * BACKTRACK_H)
		assert_int(solver.last_result()).is_equal(WfcSolverScript.Result.OK)
		assert_int(solver.backtracks_used()).is_greater(0)
		assert_int(solver.attempts_used()).is_greater(BACKTRACK_W * BACKTRACK_H)
	# (b) Reproducibility OVER the backtrack path: same seed -> bit-identical grid (the re-draw +
	# snapshot/restore on unwind are deterministic); different seed -> a different grid; and the
	# produced grid satisfies every adjacency rule (validity survives the unwind path).
	var a: PackedInt32Array = WfcSolverScript.new(BACKTRACK_W, BACKTRACK_H, rules, 1_000_000).solve(
		CanonicalRNG.new(7)
	)
	var b: PackedInt32Array = WfcSolverScript.new(BACKTRACK_W, BACKTRACK_H, rules, 1_000_000).solve(
		CanonicalRNG.new(7)
	)
	var c: PackedInt32Array = WfcSolverScript.new(BACKTRACK_W, BACKTRACK_H, rules, 1_000_000).solve(
		CanonicalRNG.new(8)
	)
	assert_bool(a == b).is_true()
	assert_bool(a == c).is_false()
	assert_bool(_grid_satisfies_rules(a, BACKTRACK_W, BACKTRACK_H, rules)).is_true()


# === malformed ruleset never crashes (bug_risk guard) ======================================== #
func test_malformed_adjacency_referencing_unknown_tile_fails_cleanly() -> void:
	# Adjacency references tile 9 (not in the palette) — and tile 0 may ONLY sit next to 9, so once a
	# cell needs a 0-neighbour, the only candidate is the absent tile 9. _weighted_pick must not index
	# an empty array (a crash); the solver returns a clean CONTRADICTION (-> the facade fallback).
	var rules := {
		"tiles": [0, 1],
		"weights": {0: 1.0, 1: 1.0},
		"adjacency":
		{
			"N": {0: [9], 1: [9]},
			"E": {0: [9], 1: [9]},
			"S": {0: [9], 1: [9]},
			"W": {0: [9], 1: [9]},
		},
	}
	var solver: WfcSolver = WfcSolverScript.new(6, 6, rules, 10000)
	var grid: PackedInt32Array = solver.solve(CanonicalRNG.new(TEST_SEED))
	assert_int(grid.size()).is_equal(0)  # clean empty result, not a crash.
	assert_int(solver.last_result()).is_equal(WfcSolverScript.Result.CONTRADICTION)


# === RegionRules adjacency DEFAULTS are MERGED, not overridden (P2 Codex) ===================== #
func test_region_adjacency_partial_override_merges_with_defaults() -> void:
	# A region overrides adjacency for ONE direction (N) and within it ONE tile (1). The other
	# directions (E/S/W) and the other N tiles (0/2) must keep the DEFAULTS — not be dropped.
	var text := (
		'{"schema_version":1,'
		+ '"defaults":{"width":8,"height":8,"attempt_limit":1000,"tiles":[0,1,2],'
		+ '"weights":{"0":1,"1":1,"2":1},'
		+ '"adjacency":{"N":{"0":[0,1,2],"1":[0,1],"2":[0,2]},"E":{"0":[0,1,2],"1":[0,1],"2":[0,2]},'
		+ '"S":{"0":[0,1,2],"1":[0,1],"2":[0,2]},"W":{"0":[0,1,2],"1":[0,1],"2":[0,2]}}},'
		+ '"regions":{"r":{"adjacency":{"N":{"1":[2]}}}}}'
	)
	var rules: RegionRules = RegionRulesScript.load_text(text)
	assert_object(rules).is_not_null()
	var adj: Dictionary = rules.wfc_rules("r")["adjacency"]
	# N tile 1 took the region override...
	assert_array(adj["N"][1]).contains_exactly([2])
	# ...but N tiles 0 and 2 kept the defaults (NOT dropped).
	assert_array(adj["N"][0]).contains_exactly([0, 1, 2])
	assert_array(adj["N"][2]).contains_exactly([0, 2])
	# ...and the other directions kept the defaults entirely.
	assert_array(adj["E"][1]).contains_exactly([0, 1])
	assert_array(adj["S"][2]).contains_exactly([0, 2])
	assert_array(adj["W"][0]).contains_exactly([0, 1, 2])


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


func _backtrack_forcing_rules() -> Dictionary:
	# A "frustrated" 4-tile ruleset that is locally satisfiable but makes greedy collapses dead-end,
	# forcing the solver to UNWIND. Symmetric H/V (E==W, N==S). tile 3 has NO horizontal neighbour;
	# tile 0 has NO vertical neighbour — so a 0 above a 3 (or similar) strands a cell, triggering the
	# retry/backtrack path. Verified (canonical PCG32) to solve every seed yet unwind on seeds 1/4/7.
	return {
		"tiles": [0, 1, 2, 3],
		"weights": {0: 1.0, 1: 1.0, 2: 1.0, 3: 1.0},
		"adjacency":
		{
			"E": {0: [1, 2], 1: [0, 1, 2], 2: [0, 1, 2], 3: []},
			"W": {0: [1, 2], 1: [0, 1, 2], 2: [0, 1, 2], 3: []},
			"N": {0: [], 1: [1, 2], 2: [1, 2, 3], 3: [2]},
			"S": {0: [], 1: [1, 2], 2: [1, 2, 3], 3: [2]},
		},
	}


## True if every cell's 4 edges in `grid` are permitted by `rules.adjacency` (validity over the
## backtrack path). Mirrors the solver's direction deltas; ignores out-of-bounds edges.
func _grid_satisfies_rules(grid: PackedInt32Array, w: int, h: int, rules: Dictionary) -> bool:
	var adj: Dictionary = rules["adjacency"]
	var deltas := {
		"N": Vector2i(0, -1), "E": Vector2i(1, 0), "S": Vector2i(0, 1), "W": Vector2i(-1, 0)
	}
	for y in h:
		for x in w:
			var t: int = grid[y * w + x]
			for dir in deltas:
				var d: Vector2i = deltas[dir]
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				var nt: int = grid[ny * w + nx]
				var allowed: Array = (adj[dir] as Dictionary).get(t, [])
				if not allowed.has(nt):
					return false
	return true


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
