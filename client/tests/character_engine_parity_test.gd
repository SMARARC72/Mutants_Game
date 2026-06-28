extends GdUnitTestSuite
## Parity: proves CharacterEngine reproduces oracle/character_engine.py EXACTLY by asserting
## the committed golden vectors (res://tests/golden/character_engine.jsonl).
## One test func per fn; each loops every matching record in the file.

const GOLDEN_PATH := "res://tests/golden/character_engine.jsonl"


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


func test_rank_for() -> void:
	for rec in _load_records():
		if rec["fn"] != "rank_for":
			continue
		var deeds := int(rec["inputs"]["deeds"])
		var got := CharacterEngine.rank_for(deeds)
		assert_str(got).is_equal(str(rec["expected"]))


func test_band3_oc() -> void:
	for rec in _load_records():
		if rec["fn"] != "band3_oc":
			continue
		var v := int(rec["inputs"]["v"])
		var got := CharacterEngine.band3(v, ["Order", "Balanced", "Chaos"])
		assert_str(got).is_equal(str(rec["expected"]))


func test_band3_pc() -> void:
	for rec in _load_records():
		if rec["fn"] != "band3_pc":
			continue
		var v := int(rec["inputs"]["v"])
		var got := CharacterEngine.band3(v, ["Pure", "Tainted", "Corrupt"])
		assert_str(got).is_equal(str(rec["expected"]))


func test_gods() -> void:
	for rec in _load_records():
		if rec["fn"] != "gods":
			continue
		var grid: Array = rec["inputs"]["grid"]
		var got := CharacterEngine.gods(grid)
		assert_str(got).is_equal(str(rec["expected"]))
