extends GdUnitTestSuite
## Proves CanonicalRNG / CanonicalMath are BIT-IDENTICAL to the Python oracle RNG (ADR-001/002),
## by asserting the committed tests/rng_vectors.json (generated from oracle/canonical_rng.py).
## A green run here ⇒ the GDScript determinism core matches the oracle exactly.

var vectors: Dictionary


func before() -> void:
	var f := FileAccess.open("res://tests/rng_vectors.json", FileAccess.READ)
	assert_object(f).is_not_null()
	vectors = JSON.parse_string(f.get_as_text())
	f.close()


func test_u32_streams_match() -> void:
	for s in vectors["u32"]:
		var r := CanonicalRNG.new(int(s))
		var exp: Array = vectors["u32"][s]
		for i in exp.size():
			assert_int(r.next_u32()).is_equal(int(exp[i]))


func test_next_float_matches() -> void:
	for s in vectors["next_float"]:
		var r := CanonicalRNG.new(int(s))
		var exp: Array = vectors["next_float"][s]
		for i in exp.size():
			assert_float(r.next_float()).is_equal_approx(float(exp[i]), 1e-12)


func test_randint_matches() -> void:
	for c in vectors["randint"]:
		var r := CanonicalRNG.new(int(c["seed"]))
		var exp: Array = c["vals"]
		for i in exp.size():
			assert_int(r.randint(int(c["a"]), int(c["b"]))).is_equal(int(exp[i]))


func test_uniform_matches() -> void:
	for c in vectors["uniform"]:
		var r := CanonicalRNG.new(int(c["seed"]))
		var exp: Array = c["vals"]
		for i in exp.size():
			assert_float(r.uniform(float(c["a"]), float(c["b"]))).is_equal_approx(
				float(exp[i]), 1e-12
			)


func test_substream_matches() -> void:
	for c in vectors["substream"]:
		var sub := CanonicalRNG.new(int(c["seed"])).substream(int(c["purpose"]))
		assert_int(sub.next_u32()).is_equal(int(c["first_u32"]))


func test_rnd_half_to_even() -> void:
	for c in vectors["rnd"]:
		assert_int(CanonicalMath.rnd(float(c["x"]))).is_equal(int(c["r"]))


func test_rnd_dp_fixed_decimal() -> void:
	for c in vectors["rnd_dp"]:
		assert_float(CanonicalMath.rnd_dp(float(c["x"]), int(c["n"]))).is_equal_approx(
			float(c["r"]), 1e-9
		)
