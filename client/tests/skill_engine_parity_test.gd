extends GdUnitTestSuite
## Parity proof: SkillEngine (domain/skill_engine.gd) reproduces oracle/skill_engine.py EXACTLY,
## asserted against the committed golden vectors (tests/golden/skill_engine.jsonl).
## A green run => the GDScript skill core matches the oracle char-for-char (TDD §1, §6).
##
## Record shape (all 200 records are "battle"):
##   {"fn":"battle",
##    "inputs":{"A":[[name,prim,sec,rank,tier,[kit...],{ranks}], ...],
##              "B":[...], "seed":<int>},
##    "expected":{"log":[<str>, ...]}}
## Mon objects are reconstructed via SkillEngine.mon_from_tuple (cls defaults to organic,
## genome=None, like the oracle generator), then SkillEngine.battle(A, B, CanonicalRNG.new(seed))
## is asserted line-for-line.

const GOLDEN_PATH := "res://tests/golden/skill_engine.jsonl"

var _records: Array = []


func before() -> void:
	var f := FileAccess.open(GOLDEN_PATH, FileAccess.READ)
	assert_object(f).is_not_null()
	while not f.eof_reached():
		var line := f.get_line()
		if line.strip_edges() == "":
			continue
		var rec: Variant = JSON.parse_string(line)
		assert_object(rec).is_not_null()
		_records.append(rec)
	f.close()
	assert_int(_records.size()).is_greater(0)


func _records_for(fn: String) -> Array:
	var out: Array = []
	for r in _records:
		if r["fn"] == fn:
			out.append(r)
	return out


func _build_team(rows: Array) -> Array:
	# Each row: [name, prim, sec, rank, tier, [kit...], {ranks}].
	var team: Array = []
	for row in rows:
		team.append(SkillEngine.mon_from_tuple(row))
	return team


func test_battle_matches() -> void:
	var recs := _records_for("battle")
	assert_int(recs.size()).is_greater(0)
	for rec in recs:
		var inp: Dictionary = rec["inputs"]
		var exp: Dictionary = rec["expected"]
		var expected_log: Array = exp["log"]
		var seed := int(inp["seed"])
		var team_a := _build_team(inp["A"])
		var team_b := _build_team(inp["B"])
		var rng := CanonicalRNG.new(seed)
		var result: Array = SkillEngine.battle(team_a, team_b, rng)
		# Same number of log lines first, so per-line asserts stay meaningful.
		(
			assert_int(result.size())
			. override_failure_message(
				"seed %d: log length %d != expected %d" % [seed, result.size(), expected_log.size()]
			)
			. is_equal(expected_log.size())
		)
		# Every line equal, char-for-char.
		var n: int = mini(result.size(), expected_log.size())
		for i in range(n):
			(
				assert_str(str(result[i]))
				. override_failure_message(
					(
						"seed %d line %d:\n  got: %s\n  exp: %s"
						% [seed, i, str(result[i]), str(expected_log[i])]
					)
				)
				. is_equal(str(expected_log[i]))
			)
