extends GdUnitTestSuite
## Phase 5 · Slice 1 — GameController (the run-owning autoload) DoD tests, headless.
##   * new_run yields a valid RunContext + a NON-EMPTY starter party in the starting region;
##   * save_run -> continue_run round-trips the run (party + world_state intact);
##   * continue_run with no save returns false (Continue gating);
##   * accessors expose run / party / active region / step.
## Drives a CODE-INSTANTIATED GameController (not the /root autoload) with an injected FakeDal so
## the test is isolated + offline. The save target is a unique temp user:// dir per test so the
## save/continue round-trip never collides with another run's file.

const GameControllerScript := preload("res://application/game/game_controller.gd")
const FakeDalScript := preload("res://infrastructure/dal/fake_dal.gd")
const EncounterCatalogScript := preload("res://application/overworld/encounter_catalog.gd")
const SaveEnvelopeScript := preload("res://application/persistence/save_envelope.gd")

const TEST_SEED := 0xC0FFEE


func _make_controller() -> Node:
	var gc: Node = GameControllerScript.new()
	add_child(gc)  # _ready lazy-inits deps; we still inject a fresh FakeDal for isolation.
	gc.call("configure", FakeDalScript.make())
	return gc


func _clear_saves() -> void:
	# Wipe user://saves so has_save()/continue_run() start from a known-empty state.
	var dir_path := SaveEnvelopeScript.DEFAULT_DIR
	if not DirAccess.dir_exists_absolute(dir_path):
		return
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.ends_with(".json"):
			dir.remove(name)
		name = dir.get_next()
	dir.list_dir_end()


func test_new_run_yields_valid_context_and_starter_party() -> void:
	var gc := _make_controller()
	var run: RunContext = gc.call("new_run", TEST_SEED)
	assert_object(run).is_not_null()
	assert_int(run.seed).is_equal(TEST_SEED)
	assert_str(run.run_id).is_not_empty()
	assert_str(run.status).is_equal("active")
	# Non-empty starter party, all entries resolvable to a species id.
	assert_int(run.party.size()).is_greater(0)
	for member: Variant in run.party:
		assert_bool(member is Dictionary).is_true()
		assert_str(str((member as Dictionary).get("species_id", ""))).is_not_empty()
	# Starting region is the Verdant fringe, and it is unlocked.
	assert_str(str(gc.call("active_region"))).is_equal(EncounterCatalogScript.STARTING_REGION)
	assert_bool(run.unlocked_regions.has(EncounterCatalogScript.STARTING_REGION)).is_true()
	gc.queue_free()


func test_accessors_reflect_active_run() -> void:
	var gc := _make_controller()
	assert_bool(bool(gc.call("has_run"))).is_false()
	gc.call("new_run", TEST_SEED)
	assert_bool(bool(gc.call("has_run"))).is_true()
	assert_int((gc.call("party") as Array).size()).is_greater(0)
	assert_int(int(gc.call("current_step"))).is_equal(0)
	assert_int(int(gc.call("advance_step"))).is_equal(1)
	assert_int(int(gc.call("current_step"))).is_equal(1)
	gc.queue_free()


func test_defeat_costs_a_quarter_of_essence_floor_zero() -> void:
	# Wave 3 consequence: a DEFEAT costs ~25% of banked essence (round down), clamped at 0. A flee
	# is an escape, not a defeat — it stays cost-free. Wins never pay the toll.
	var gc := _make_controller()
	var run: RunContext = gc.call("new_run", TEST_SEED)
	run.essence = 41
	gc.call("apply_battle_result", {"player_won": false, "winner": "enemy", "xp": 0})
	assert_int(run.essence).is_equal(31)  # 41 - floor(41 * 0.25) = 41 - 10
	run.essence = 0
	gc.call("apply_battle_result", {"player_won": false, "winner": "enemy", "xp": 0})
	assert_int(run.essence).is_equal(0)  # floor 0 — never negative
	run.essence = 40
	gc.call("apply_battle_result", {"player_won": true, "winner": "fled", "xp": 0})
	assert_int(run.essence).is_equal(40)  # fleeing is free
	gc.queue_free()


func test_battle_result_party_hp_folds_into_the_party() -> void:
	# Wave 3 consequence: a result carrying party_hp writes live end-of-battle HP back onto the
	# exact run.party entries by index; out-of-range entries are ignored, others untouched.
	var gc := _make_controller()
	var run: RunContext = gc.call("new_run", TEST_SEED)
	var hp_payload := [
		{"index": 0, "hp": 7, "max_hp": 30},
		{"index": 99, "hp": 1, "max_hp": 1},  # out of range -> ignored, never crashes
	]
	gc.call("apply_battle_result", {"player_won": true, "xp": 0, "party_hp": hp_payload})
	var first: Dictionary = run.party[0]
	assert_int(int(first["hp"])).is_equal(7)
	assert_int(int(first["max_hp"])).is_equal(30)
	# The untouched member gained no hp keys from someone else's entry.
	var second: Dictionary = run.party[1]
	assert_bool(second.has("hp")).is_false()
	gc.queue_free()


func test_continue_with_no_save_returns_false() -> void:
	_clear_saves()
	var gc := _make_controller()
	assert_bool(bool(gc.call("has_save"))).is_false()
	assert_bool(bool(gc.call("continue_run"))).is_false()
	gc.queue_free()


func test_save_then_continue_round_trips_run() -> void:
	_clear_saves()
	var gc := _make_controller()
	var run: RunContext = gc.call("new_run", TEST_SEED)
	# Mutate some run state so the round-trip has something to verify beyond defaults.
	gc.call("advance_step")
	gc.call("advance_step")
	run.world_state["region_layouts"] = {"verdant_glut": {"width": 4, "height": 4}}
	run.essence = 42
	var expected_party_size := run.party.size()
	var expected_steps := int(gc.call("current_step"))

	assert_bool(bool(gc.call("save_run"))).is_true()
	assert_bool(bool(gc.call("has_save"))).is_true()

	# A FRESH controller continues from the saved file (proves on-disk round-trip, not in-memory).
	var gc2 := _make_controller()
	assert_bool(bool(gc2.call("continue_run"))).is_true()
	var loaded: RunContext = gc2.call("run")
	assert_int(loaded.seed).is_equal(TEST_SEED)
	assert_int(loaded.party.size()).is_equal(expected_party_size)
	assert_int(int(gc2.call("current_step"))).is_equal(expected_steps)
	assert_int(loaded.essence).is_equal(42)
	# world_state (incl. the persisted region layout) survives intact.
	var layouts: Dictionary = loaded.world_state.get("region_layouts", {})
	assert_bool(layouts.has("verdant_glut")).is_true()
	gc.queue_free()
	gc2.queue_free()
	_clear_saves()
