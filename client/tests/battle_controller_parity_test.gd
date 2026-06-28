extends GdUnitTestSuite
## BattleController parity + replay determinism (ADR-016, TDD §6).
##
## Proves two things about the "AI SELECTS, the engine RESOLVES" controller:
##   1. PARITY: with the neutral brain (first-alive target = simulate()'s hardcoded _first_alive),
##      and fed the SAME resolution RNG sub-stream the engine would use, BattleController.run()
##      reproduces BattleEngine.simulate() byte-for-byte. The oracle (simulate) is untouched; the
##      controller routes every strike through CombatBrain -> BattleEngine.attack and still agrees.
##   2. REPLAY: same (seed, teams, brain) -> byte-identical controller transcript across repeated
##      runs (fresh Mons + fresh RNG each time). Selection RNG and resolution RNG are disjoint
##      sub-streams, so AI choices never perturb the resolver's numbers.

const CombatBrainScript := preload("res://application/ai/combat_brain.gd")
const BattleControllerScript := preload("res://application/battle/battle_controller.gd")

const GOLDEN_PATH := "res://tests/golden/battle_engine.jsonl"

var _sim_records: Array = []


func before() -> void:
	var f := FileAccess.open(GOLDEN_PATH, FileAccess.READ)
	assert_object(f).is_not_null()
	while not f.eof_reached():
		var line := f.get_line()
		if line.strip_edges() == "":
			continue
		var rec: Variant = JSON.parse_string(line)
		if rec is Dictionary and str((rec as Dictionary).get("fn", "")) == "simulate":
			_sim_records.append(rec)
	f.close()
	assert_int(_sim_records.size()).is_greater(0)


func _build_team(rows: Array) -> Array:
	var team: Array = []
	for row in rows:
		var arr: Array = row
		var mon := BattleEngine.Mon.new(str(arr[0]), str(arr[1]), str(arr[2]), arr[3], arr[4])
		team.append(mon)
	return team


## With the neutral brain and the SAME resolution sub-stream, the controller == simulate(),
## char-for-char, across a sample of golden seeds. This is the core determinism-boundary proof.
func test_controller_matches_simulate_with_neutral_brain() -> void:
	var checked := 0
	for rec in _sim_records:
		var inp: Dictionary = rec["inputs"]
		var seed: int = int(inp["seed"])
		if seed > 12:
			continue  # a representative sample (every team set is covered across seeds 0..12)
		checked += 1

		# Engine oracle: feed simulate the controller's RESOLUTION sub-stream so both consume the
		# SAME crit/overload stream in the same order.
		var run_rng_sim := CanonicalRNG.new(seed)
		var sim_log: Array = BattleEngine.simulate(
			_build_team(inp["teamA"]),
			_build_team(inp["teamB"]),
			BattleControllerScript.resolution_rng(run_rng_sim)
		)

		# Controller: neutral brain, same run seed -> same RES sub-stream internally.
		var brain := CombatBrainScript.new()
		var ctrl := BattleControllerScript.new(brain, CanonicalRNG.new(seed))
		var ctrl_log: Array = ctrl.run(_build_team(inp["teamA"]), _build_team(inp["teamB"]))

		assert_int(ctrl_log.size()).is_equal(sim_log.size())
		var n: int = mini(ctrl_log.size(), sim_log.size())
		for i in range(n):
			assert_str(str(ctrl_log[i])).is_equal(str(sim_log[i]))
	assert_int(checked).is_greater(0)


## Same (seed, teams, brain) -> identical controller transcript across two independent runs.
func test_controller_replay_is_byte_identical() -> void:
	var inp: Dictionary = _sim_records[0]["inputs"]
	var seed: int = int(inp["seed"])

	var brain_a := CombatBrainScript.new()
	var run_a := BattleControllerScript.new(brain_a, CanonicalRNG.new(seed))
	var log_a: Array = run_a.run(_build_team(inp["teamA"]), _build_team(inp["teamB"]))

	var brain_b := CombatBrainScript.new()
	var run_b := BattleControllerScript.new(brain_b, CanonicalRNG.new(seed))
	var log_b: Array = run_b.run(_build_team(inp["teamA"]), _build_team(inp["teamB"]))

	assert_int(log_a.size()).is_equal(log_b.size())
	for i in range(log_a.size()):
		assert_str(str(log_a[i])).is_equal(str(log_b[i]))


## A role brain (aggressor) also replays identically: AI selection draws only from the canonical
## selection sub-stream, so two runs at the same seed agree byte-for-byte even with non-neutral
## target policies (the AI choices are themselves deterministic).
func test_role_brain_battle_is_deterministic() -> void:
	var inp: Dictionary = _sim_records[0]["inputs"]
	var seed: int = int(inp["seed"])

	var logs: Array = []
	for _i in range(2):
		var brain := CombatBrainScript.new()
		var teamA := _build_team(inp["teamA"])
		var teamB := _build_team(inp["teamB"])
		for m in teamA:
			brain.assign_role(m, "aggressor")
		for m in teamB:
			brain.assign_role(m, "controller")
		var ctrl := BattleControllerScript.new(brain, CanonicalRNG.new(seed))
		logs.append(ctrl.run(teamA, teamB))

	var log0: Array = logs[0]
	var log1: Array = logs[1]
	assert_int(log0.size()).is_equal(log1.size())
	for i in range(log0.size()):
		assert_str(str(log0[i])).is_equal(str(log1[i]))
	# And it actually produced a real battle (header + result lines at minimum).
	assert_int(log0.size()).is_greater(2)
