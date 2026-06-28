extends GdUnitTestSuite
## Parity proof: LabEngine (domain/lab_engine.gd) reproduces oracle/lab_engine.py EXACTLY,
## asserted against the committed golden vectors (tests/golden/lab_engine.jsonl).
## A green run ⇒ the GDScript LAB engine matches the oracle bit-for-bit (TDD §1, §6).
##
## Record shape: {"fn": <name>, "inputs": {...}, "expected": {...}}.
##   fuse  : inputs {a:[name,prim,sec,tier], b:[...], method, seed} ; rng = CanonicalRNG.new(seed)
##   blend : inputs {parts:[[prim,sec],...]}                         ; pure (no rng)

const GOLDEN_PATH := "res://tests/golden/lab_engine.jsonl"

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


func test_fuse_matches() -> void:
	var recs := _records_for("fuse")
	assert_int(recs.size()).is_greater(0)
	for rec in recs:
		var inp: Dictionary = rec["inputs"]
		var exp: Dictionary = rec["expected"]
		var a: Array = inp["a"]
		var b: Array = inp["b"]
		var rng := CanonicalRNG.new(int(inp["seed"]))
		var result := LabEngine.fuse(a, b, inp["method"], rng)

		# Scalar string / bool / int fields.
		assert_str(str(result["name"])).is_equal(str(exp["name"]))
		assert_str(str(result["prim"])).is_equal(str(exp["prim"]))
		assert_str(str(result["sec"])).is_equal(str(exp["sec"]))
		assert_str(str(result["tier"])).is_equal(str(exp["tier"]))
		assert_str(str(result["method"])).is_equal(str(exp["method"]))
		assert_bool(bool(result["taboo"])).is_equal(bool(exp["taboo"]))
		assert_int(int(result["hp"])).is_equal(int(exp["hp"]))
		assert_int(int(result["bst"])).is_equal(int(exp["bst"]))
		assert_int(int(result["entropy"])).is_equal(int(exp["entropy"]))
		assert_int(int(result["corruption"])).is_equal(int(exp["corruption"]))

		# stats: every expected key present and integer-equal; result has no extra keys.
		var rstats: Dictionary = result["stats"]
		var estats: Dictionary = exp["stats"]
		assert_int(rstats.size()).is_equal(estats.size())
		for k in estats:
			assert_bool(rstats.has(k)).is_true()
			assert_int(int(rstats[k])).is_equal(int(estats[k]))


func test_blend_matches() -> void:
	var recs := _records_for("blend")
	assert_int(recs.size()).is_greater(0)
	for rec in recs:
		var inp: Dictionary = rec["inputs"]
		var exp: Dictionary = rec["expected"]
		var parts: Array = inp["parts"]
		var result := LabEngine.blend(parts)
		assert_str(str(result["prim"])).is_equal(str(exp["prim"]))
		assert_str(str(result["sec"])).is_equal(str(exp["sec"]))
