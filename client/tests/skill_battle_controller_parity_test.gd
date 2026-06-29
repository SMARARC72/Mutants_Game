extends GdUnitTestSuite
## SkillBattleController parity + replay (Phase 10 · Slice 1, ADR-016, TDD §6).
##
## Proves the interactive SKILL driver is a faithful, deterministic front-end to the pure SkillEngine:
##   1. PARITY: a NEUTRAL player (one that replays SkillEngine.act() for its own mons via act_neutral),
##      fed the SAME act sub-stream the controller derives, reproduces SkillEngine.battle() BYTE-FOR-BYTE
##      across a sample of the golden seeds. The oracle (battle) is untouched; the controller routes
##      every action through AbilityContainer -> SkillEngine and still agrees char-for-char.
##   2. REPLAY: same (seed, teams, neutral choices) -> byte-identical interactive transcript across runs.
##
## Golden record shape (all "battle"): {"fn":"battle","inputs":{"A":[[name,prim,sec,rank,tier,[kit],{ranks}],..],
## "B":[..],"seed":int},"expected":{"log":[str,..]}}. We rebuild AbilityContainer teams for the driver and
## SkillEngine.Mon teams for the direct oracle call, then diff the two transcripts.

const GOLDEN_PATH := "res://tests/golden/skill_engine.jsonl"
const AWAIT := "await_player"

var _records: Array = []


func before() -> void:
	var f := FileAccess.open(GOLDEN_PATH, FileAccess.READ)
	assert_object(f).is_not_null()
	while not f.eof_reached():
		var line := f.get_line()
		if line.strip_edges() == "":
			continue
		var rec: Variant = JSON.parse_string(line)
		if rec is Dictionary and str((rec as Dictionary).get("fn", "")) == "battle":
			_records.append(rec)
	f.close()
	assert_int(_records.size()).is_greater(0)


func _ability_team(rows: Array) -> Array:
	var team: Array = []
	for row in rows:
		var arr: Array = row
		var ranks: Dictionary = {}
		if arr.size() > 6 and arr[6] != null:
			ranks = arr[6]
		team.append(
			AbilityContainer.new(
				str(arr[0]), str(arr[1]), str(arr[2]), str(arr[3]), str(arr[4]), arr[5], ranks
			)
		)
	return team


func _mon_team(rows: Array) -> Array:
	var team: Array = []
	for row in rows:
		team.append(SkillEngine.mon_from_tuple(row))
	return team


## Drive the interactive session to the end with a NEUTRAL player (player mons replay act()). Returns
## the full transcript. A guard bounds the loop so a logic bug fails loudly instead of hanging.
func _neutral_interactive_log(rows_a: Array, rows_b: Array, seed: int) -> Array:
	var ctrl := SkillBattleController.new(CanonicalRNG.new(seed))
	var sess := ctrl.interactive(_ability_team(rows_a), _ability_team(rows_b), "A")
	var step := sess.advance()
	var guard := 0
	while not sess.is_ended() and guard < 100000:
		guard += 1
		if str(step.get("kind", "")) == AWAIT:
			step = sess.act_neutral()
		else:
			step = sess.advance()
	assert_bool(sess.is_ended()).is_true()
	return sess.transcript()


func test_neutral_interactive_matches_skillengine_battle() -> void:
	var checked := 0
	for rec in _records:
		var inp: Dictionary = rec["inputs"]
		var seed := int(inp["seed"])
		if seed > 12:
			continue  # a representative sample (the 6-creature team set is fixed; seeds vary the rolls)
		checked += 1
		# Oracle: feed battle() the controller's ACT sub-stream so both consume RNG in the same order.
		var engine_log: Array = SkillEngine.battle(
			_mon_team(inp["A"]),
			_mon_team(inp["B"]),
			SkillBattleController.act_rng(CanonicalRNG.new(seed))
		)
		var inter_log := _neutral_interactive_log(inp["A"], inp["B"], seed)
		(
			assert_int(inter_log.size())
			. override_failure_message(
				(
					"seed %d: log length %d != expected %d"
					% [seed, inter_log.size(), engine_log.size()]
				)
			)
			. is_equal(engine_log.size())
		)
		var n: int = mini(inter_log.size(), engine_log.size())
		for i in range(n):
			(
				assert_str(str(inter_log[i]))
				. override_failure_message(
					(
						"seed %d line %d:\n  got: %s\n  exp: %s"
						% [seed, i, str(inter_log[i]), str(engine_log[i])]
					)
				)
				. is_equal(str(engine_log[i]))
			)
	assert_int(checked).is_greater(0)


func test_interactive_replay_is_byte_identical() -> void:
	var inp: Dictionary = _records[0]["inputs"]
	var seed := int(inp["seed"])
	var log_a := _neutral_interactive_log(inp["A"], inp["B"], seed)
	var log_b := _neutral_interactive_log(inp["A"], inp["B"], seed)
	assert_int(log_a.size()).is_equal(log_b.size())
	for i in range(log_a.size()):
		assert_str(str(log_a[i])).is_equal(str(log_b[i]))
