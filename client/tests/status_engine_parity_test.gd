extends GdUnitTestSuite
## Parity test for StatusEngine vs oracle/status_engine.py golden vectors.
## Loads res://tests/golden/status_engine.jsonl (one {fn, inputs, expected} record per line),
## reproduces the exact oracle harness (gen_golden.gen_status) for each fn, and asserts the
## resulting state snapshot + log deep-equal `expected`. Green ⇒ the port matches the oracle.

const GOLDEN := "res://tests/golden/status_engine.jsonl"


func _load_records() -> Array:
	var f := FileAccess.open(GOLDEN, FileAccess.READ)
	assert_object(f).is_not_null()
	var recs: Array = []
	while not f.eof_reached():
		var line := f.get_line()
		if line.strip_edges() == "":
			continue
		var rec: Variant = JSON.parse_string(line)
		assert_object(rec).is_not_null()
		recs.append(rec)
	f.close()
	return recs


# Build the snapshot the oracle's gen_status.snap(c) emits.
func _snap(c: StatusEngine.C) -> Dictionary:
	var status: Dictionary = {}
	for k in c.status.keys():
		var v: Dictionary = c.status[k]
		status[k] = {"stacks": int(v["stacks"]), "dur": int(v["dur"])}
	return {
		"hp": c.hp,
		"maxhp": c.maxhp,
		"corruption": c.corruption,
		"feral": c.feral,
		"status": status,
	}


# Deep-assert a produced state snapshot against the golden `expected.state`.
# JSON numbers parse to float in GDScript, so cast every numeric to int/bool explicitly.
func _assert_state(got: Dictionary, exp: Dictionary) -> void:
	assert_int(int(got["hp"])).is_equal(int(exp["hp"]))
	assert_int(int(got["maxhp"])).is_equal(int(exp["maxhp"]))
	assert_int(int(got["corruption"])).is_equal(int(exp["corruption"]))
	assert_bool(bool(got["feral"])).is_equal(bool(exp["feral"]))
	var got_status: Dictionary = got["status"]
	var exp_status: Dictionary = exp["status"]
	assert_int(got_status.size()).is_equal(exp_status.size())
	for k in exp_status.keys():
		assert_bool(got_status.has(k)).is_true()
		var gv: Dictionary = got_status[k]
		var ev: Dictionary = exp_status[k]
		assert_int(int(gv["stacks"])).is_equal(int(ev["stacks"]))
		assert_int(int(gv["dur"])).is_equal(int(ev["dur"]))


# Assert two log lists are equal line-by-line (exact strings).
func _assert_log(got: Array, exp: Array) -> void:
	assert_int(got.size()).is_equal(exp.size())
	for i in exp.size():
		assert_str(str(got[i])).is_equal(str(exp[i]))


func test_apply_tick() -> void:
	for rec in _load_records():
		if rec["fn"] != "apply_tick":
			continue
		var status_name: String = str(rec["inputs"]["status"])
		# gen_status: C("V","Gaia","Eros","T3"); apply; apply if STATUSES[name].stack; tick(c,[c]).
		var c := StatusEngine.C.new("V", "Gaia", "Eros", "T3")
		var log: Array = []
		StatusEngine.apply(c, status_name, log)
		if StatusEngine._statuses()[status_name].get("stack", false):
			StatusEngine.apply(c, status_name, log)
		StatusEngine.tick(c, [c], log)
		var exp: Dictionary = rec["expected"]
		_assert_state(_snap(c), exp["state"])
		_assert_log(log, exp["log"])


func test_add_corruption() -> void:
	for rec in _load_records():
		if rec["fn"] != "add_corruption":
			continue
		var amt: int = int(rec["inputs"]["amt"])
		# gen_status: C("V","Thanatos","Gaia","T3"); add_corruption(c, amt, "test").
		var c := StatusEngine.C.new("V", "Thanatos", "Gaia", "T3")
		var log: Array = []
		StatusEngine.add_corruption(c, amt, "test", log)
		var exp: Dictionary = rec["expected"]
		_assert_state(_snap(c), exp["state"])
		_assert_log(log, exp["log"])
