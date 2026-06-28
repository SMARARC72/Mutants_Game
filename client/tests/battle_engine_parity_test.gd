extends GdUnitTestSuite
## Parity proof: BattleEngine (domain/battle_engine.gd) reproduces oracle/battle_engine.py EXACTLY,
## asserted against the committed golden vectors (tests/golden/battle_engine.jsonl).
## A green run => the GDScript battle core matches the oracle char-for-char (TDD §1, §6).
##
## Record shapes:
##   {"fn":"force_mult","inputs":{"att":<force>,"dfn":<force>},"expected":<float>}
##   {"fn":"simulate","inputs":{"teamA":[[name,prim,sec,rank,tier],...],
##                              "teamB":[...],"seed":<int>},"expected":{"log":[<str>,...]}}
## For simulate, Mon objects are reconstructed (cls defaults to organic, like the oracle
## generator) and BattleEngine.simulate(A, B, CanonicalRNG.new(seed)) is asserted line-for-line.

const GOLDEN_PATH := "res://tests/golden/battle_engine.jsonl"

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
	# Each row: [name, prim, sec, rank, tier]; cls defaults to "organic".
	var team: Array = []
	for row in rows:
		var arr: Array = row
		var mon := BattleEngine.Mon.new(str(arr[0]), str(arr[1]), str(arr[2]), arr[3], arr[4])
		team.append(mon)
	return team


func test_force_mult_matches() -> void:
	var recs := _records_for("force_mult")
	assert_int(recs.size()).is_greater(0)
	for rec in recs:
		var inp: Dictionary = rec["inputs"]
		var result := BattleEngine.force_mult(str(inp["att"]), str(inp["dfn"]))
		assert_float(result).is_equal_approx(float(rec["expected"]), 1e-9)


func test_simulate_matches() -> void:
	var recs := _records_for("simulate")
	assert_int(recs.size()).is_greater(0)
	for rec in recs:
		var inp: Dictionary = rec["inputs"]
		var exp: Dictionary = rec["expected"]
		var expected_log: Array = exp["log"]
		var teamA := _build_team(inp["teamA"])
		var teamB := _build_team(inp["teamB"])
		var rng := CanonicalRNG.new(int(inp["seed"]))
		var result: Array = BattleEngine.simulate(teamA, teamB, rng)
		# Same number of log lines.
		assert_int(result.size()).is_equal(expected_log.size())
		# Every line equal, char-for-char.
		var n: int = mini(result.size(), expected_log.size())
		for i in range(n):
			assert_str(str(result[i])).is_equal(str(expected_log[i]))
