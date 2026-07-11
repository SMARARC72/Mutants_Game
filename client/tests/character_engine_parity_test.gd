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


func test_apply_event_moves_axes_rank_and_notoriety_without_mutating_input() -> void:
	var original := {
		"order_chaos": 95, "purity_corrupt": 0, "deeds": 0, "corruption": 0, "notoriety": 25
	}
	var result := CharacterEngine.apply_event(original, "break a taboo")
	assert_bool(bool(result["ok"])).is_true()
	var state: Dictionary = result["state"]
	assert_int(state["order_chaos"]).is_equal(100)  # clamped like the oracle
	assert_int(state["notoriety"]).is_equal(33)
	assert_int(original["order_chaos"]).is_equal(95)  # pure: input untouched
	assert_int((result["triggered"] as Array).size()).is_equal(1)
	assert_int(result["triggered"][0]["threshold"]).is_equal(30)

	var deed := CharacterEngine.apply_event(state, "kill a god", result["fired_thresholds"])
	assert_int(deed["state"]["deeds"]).is_equal(1)
	assert_str(deed["state"]["rank"]).is_equal("Adept")
	assert_str(deed["rank_up"]).is_equal("Adept")


func test_apply_event_rejects_unknown_ids_and_latches_thresholds() -> void:
	var state := {"notoriety": 29}
	var first := CharacterEngine.apply_event(state, "break a taboo")
	var second := CharacterEngine.apply_event(first["state"], "break a taboo", [30])
	assert_int((first["triggered"] as Array).size()).is_equal(1)
	assert_int((second["triggered"] as Array).size()).is_equal(0)
	var unknown := CharacterEngine.apply_event(state, "not authored")
	assert_bool(bool(unknown["ok"])).is_false()
	assert_int(unknown["state"]["notoriety"]).is_equal(29)
