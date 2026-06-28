extends GdUnitTestSuite
## Phase 0.5 sample GdUnit4 test (TDD §11). Proves the test harness runs headless in CI and
## that the generated domain constants load in Godot. Real parity suites arrive in Phase 1-2.


func test_sanity() -> void:
	assert_int(2 + 2).is_equal(4)


func test_generated_constants_load() -> void:
	# Constants is the generated class_name from client/domain/constants.gd (D4).
	assert_float(Constants.PHI).is_equal(0.5)
	assert_float(Constants.DAMAGE_K).is_equal(4.5)  # Slice 4 balance tune (1.5 -> 4.5)
	assert_int(Constants.CORRUPTION_CAP).is_equal(130)


func test_balance_tree_has_all_engine_sections() -> void:
	var keys := Constants.BALANCE.keys()
	for section in [
		"forces", "stat", "level", "lab", "battle", "skill", "status", "loot", "character"
	]:
		assert_bool(keys.has(section)).is_true()
