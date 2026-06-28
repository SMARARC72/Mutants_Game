extends GdUnitTestSuite
## Parity: proves LevelEngine reproduces oracle/level_engine.py EXACTLY by asserting the
## committed golden vectors (res://tests/golden/level_engine.jsonl).
## One test func per fn; each loops every matching record in the file.

const GOLDEN_PATH := "res://tests/golden/level_engine.jsonl"


func _load_records() -> Array:
	var f := FileAccess.open(GOLDEN_PATH, FileAccess.READ)
	assert_object(f).is_not_null()
	var records: Array = []
	while not f.eof_reached():
		var line := f.get_line()
		if line.strip_edges() == "":
			continue
		var rec: Variant = JSON.parse_string(line)
		assert_that(rec).is_not_null()
		records.append(rec)
	f.close()
	return records


func test_awaken() -> void:
	for rec in _load_records():
		if rec["fn"] != "awaken":
			continue
		var inp: Dictionary = rec["inputs"]
		var exp: Dictionary = rec["expected"]

		# Build fresh mutable inputs (awaken mutates gene_bonus + genes in place).
		var gene_bonus: Dictionary = {}
		for k in inp["gene_bonus"] as Dictionary:
			gene_bonus[k] = float(inp["gene_bonus"][k])
		var genes: Array = []
		for g in inp["genes"] as Array:
			genes.append(g)

		var rng := CanonicalRNG.new(int(inp["seed"]))
		var got: Dictionary = LevelEngine.awaken(rng, float(inp["expression"]), gene_bonus, genes)

		# expression: golden is round(expr, 6); compare at 6dp.
		assert_float(CanonicalMath.rnd_dp(float(got["expression"]), 6)).is_equal_approx(
			float(exp["expression"]), 1e-9
		)

		# events: list of strings, exact order + content.
		var got_events: Array = got["events"]
		var exp_events: Array = exp["events"]
		assert_int(got_events.size()).is_equal(exp_events.size())
		for i in exp_events.size():
			assert_str(got_events[i]).is_equal(str(exp_events[i]))

		# gene_bonus (mutated in place): same keys + approx float values.
		var exp_gb: Dictionary = exp["gene_bonus"]
		assert_int(gene_bonus.size()).is_equal(exp_gb.size())
		for k in exp_gb:
			assert_bool(gene_bonus.has(k)).is_true()
			assert_float(float(gene_bonus[k])).is_equal_approx(float(exp_gb[k]), 1e-9)

		# genes (mutated in place): same order + content.
		var exp_genes: Array = exp["genes"]
		assert_int(genes.size()).is_equal(exp_genes.size())
		for i in exp_genes.size():
			assert_str(str(genes[i])).is_equal(str(exp_genes[i]))


func test_current_stats() -> void:
	for rec in _load_records():
		if rec["fn"] != "current_stats":
			continue
		var inp: Dictionary = rec["inputs"]
		var exp: Dictionary = rec["expected"]

		var ceiling: Dictionary = inp["ceiling"]
		var gene_bonus: Dictionary = inp["gene_bonus"]
		var got: Dictionary = LevelEngine.current_stats(
			ceiling, float(inp["expression"]), gene_bonus
		)

		assert_int(got.size()).is_equal(exp.size())
		for k in exp:
			assert_bool(got.has(k)).is_true()
			assert_int(int(got[k])).is_equal(int(exp[k]))
