extends GdUnitTestSuite
## Parity: LootEngine (GDScript) vs oracle/loot_engine.py via committed golden vectors.
## Each JSONL record = {fn, inputs, expected}. capture_chance returns a clamped float (golden is
## rounded to 6dp for storage → compare with 1e-6 tol). breed_roll returns {rare, chance, iv_ceiling}
## and takes an injected CanonicalRNG built from the record's integer seed.

const GOLDEN_PATH := "res://tests/golden/loot_engine.jsonl"


func _load_records() -> Array:
	var f := FileAccess.open(GOLDEN_PATH, FileAccess.READ)
	assert_object(f).is_not_null()
	var records: Array = []
	while not f.eof_reached():
		var line := f.get_line()
		if line.strip_edges() == "":
			continue
		var rec: Variant = JSON.parse_string(line)
		assert_object(rec).is_not_null()
		records.append(rec)
	f.close()
	return records


func test_capture_chance_parity() -> void:
	var n := 0
	for rec in _load_records():
		if rec["fn"] != "capture_chance":
			continue
		n += 1
		var inp: Dictionary = rec["inputs"]
		var gear: Array = inp["gear"]
		var result := LootEngine.capture_chance(
			str(inp["method"]),
			str(inp["tier"]),
			float(inp["hp_frac"]),
			float(inp["bond"]),
			gear,
			float(inp["morality_fit"])
		)
		assert_float(result).is_equal_approx(float(rec["expected"]), 1e-6)
	assert_int(n).is_greater(0)


func test_breed_roll_parity() -> void:
	var n := 0
	for rec in _load_records():
		if rec["fn"] != "breed_roll":
			continue
		n += 1
		var inp: Dictionary = rec["inputs"]
		var gear: Array = inp["gear"]
		var rng := CanonicalRNG.new(int(inp["seed"]))
		var result := LootEngine.breed_roll(gear, rng)
		var expected: Dictionary = rec["expected"]
		assert_bool(bool(result["rare"])).is_equal(bool(expected["rare"]))
		assert_float(float(result["chance"])).is_equal_approx(float(expected["chance"]), 1e-9)
		assert_float(float(result["iv_ceiling"])).is_equal_approx(
			float(expected["iv_ceiling"]), 1e-9
		)
	assert_int(n).is_greater(0)
