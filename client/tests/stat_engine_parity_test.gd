extends GdUnitTestSuite
## Parity proof: StatEngine (domain/stat_engine.gd) reproduces oracle/stat_engine.py EXACTLY,
## asserted against the committed golden vectors (tests/golden/stat_engine.jsonl).
## A green run ⇒ the GDScript stat spine matches the oracle bit-for-bit (TDD §1, §6).
##
## Record shape: {"fn": <name>, "inputs": {...}, "expected": {...}}.
## For stat_block, the genome is rebuilt via roll_genome(CanonicalRNG.new(inputs.seed)) then
## stat_block(...) is called (same construction the oracle generator used).

const GOLDEN_PATH := "res://tests/golden/stat_engine.jsonl"

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


func test_stat_block_matches() -> void:
	var recs := _records_for("stat_block")
	assert_int(recs.size()).is_greater(0)
	for rec in recs:
		var inp: Dictionary = rec["inputs"]
		var exp: Dictionary = rec["expected"]
		var rng := CanonicalRNG.new(int(inp["seed"]))
		var genome := StatEngine.roll_genome(rng)
		var result := StatEngine.stat_block(
			inp["prim"], inp["sec"], inp["rank"], inp["tier"], inp["cls"], genome
		)
		# hp / bst are ints.
		assert_int(int(result["hp"])).is_equal(int(exp["hp"]))
		assert_int(int(result["bst"])).is_equal(int(exp["bst"]))
		# stats: every expected key present and integer-equal; result has no extra keys.
		var rstats: Dictionary = result["stats"]
		var estats: Dictionary = exp["stats"]
		assert_int(rstats.size()).is_equal(estats.size())
		for k in estats:
			assert_bool(rstats.has(k)).is_true()
			assert_int(int(rstats[k])).is_equal(int(estats[k]))


func test_roll_genome_matches() -> void:
	var recs := _records_for("roll_genome")
	assert_int(recs.size()).is_greater(0)
	for rec in recs:
		var inp: Dictionary = rec["inputs"]
		var exp: Dictionary = rec["expected"]
		var rng := CanonicalRNG.new(int(inp["seed"]))
		var result := StatEngine.roll_genome(rng)
		assert_int(result.size()).is_equal(exp.size())
		for k in exp:
			assert_bool(result.has(k)).is_true()
			assert_float(float(result[k])).is_equal_approx(float(exp[k]), 1e-9)
