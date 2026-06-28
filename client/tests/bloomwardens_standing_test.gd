extends GdUnitTestSuite
## Phase 5 · Slice 4 — Bloomwardens FACTION STANDING DoD, headless.
##   * a CATCH (befriend) nudges standing UP; a KILL (won + downed, captured nothing) nudges it DOWN
##     ("tend, heal, befriend; never butcher") — only in the Verdant region;
##   * standing maps to the named tier ladder (Stranger -> Associate -> Sworn -> Champion -> Hand);
##   * the reactivity is region-scoped (a non-Verdant battle is standing-neutral);
##   * standing PERSISTS across a save -> continue round-trip (it lives in run.flags).
## Drives a CODE-INSTANTIATED GameController (not the /root autoload) with an injected FakeDal so the
## test is isolated + offline.

const GameControllerScript := preload("res://application/game/game_controller.gd")
const FakeDalScript := preload("res://infrastructure/dal/fake_dal.gd")
const SaveEnvelopeScript := preload("res://application/persistence/save_envelope.gd")

const TEST_SEED := 0xB1005EED


func _make_controller() -> Node:
	var gc: Node = GameControllerScript.new()
	add_child(gc)
	gc.call("configure", FakeDalScript.make())
	return gc


func _clear_saves() -> void:
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


func test_fresh_run_starts_at_stranger_zero() -> void:
	var gc := _make_controller()
	gc.call("new_run", TEST_SEED)
	assert_int(int(gc.call("bloomwardens_standing"))).is_equal(0)
	assert_str(str(gc.call("bloomwardens_tier"))).is_equal("Stranger")
	gc.queue_free()


func test_catch_raises_standing() -> void:
	var gc := _make_controller()
	gc.call("new_run", TEST_SEED)
	# A caught wild creature joins the party AND raises Bloomwardens standing.
	var caught := {"species_id": "SB33", "nickname": "befriended"}
	var result := {"player_won": true, "enemy_defeated": 0, "caught": caught, "xp": 12}
	gc.call("apply_battle_result", result)
	assert_int(int(gc.call("bloomwardens_standing"))).is_greater(0)
	gc.queue_free()


func test_kill_lowers_standing() -> void:
	var gc := _make_controller()
	gc.call("new_run", TEST_SEED)
	# First build some standing via catches, then a KILL (won, downed, no catch) lowers it.
	for _i in 3:
		gc.call("apply_battle_result", {"player_won": true, "caught": {"species_id": "SB33"}})
	var before := int(gc.call("bloomwardens_standing"))
	gc.call("apply_battle_result", {"player_won": true, "enemy_defeated": 1, "caught": {}})
	var after := int(gc.call("bloomwardens_standing"))
	assert_int(after).is_less(before)
	gc.queue_free()


func test_standing_clamps_at_zero_floor() -> void:
	var gc := _make_controller()
	gc.call("new_run", TEST_SEED)
	# A kill from a zero baseline never goes negative (MVP keeps standing non-negative).
	gc.call("apply_battle_result", {"player_won": true, "enemy_defeated": 2, "caught": {}})
	assert_int(int(gc.call("bloomwardens_standing"))).is_equal(0)
	gc.queue_free()


func test_standing_resolves_to_named_tiers() -> void:
	var gc := _make_controller()
	gc.call("new_run", TEST_SEED)
	gc.call("adjust_bloomwardens_standing", 8)
	assert_str(str(gc.call("bloomwardens_tier"))).is_equal("Associate")
	gc.call("adjust_bloomwardens_standing", 12)  # 20 total
	assert_str(str(gc.call("bloomwardens_tier"))).is_equal("Sworn")
	gc.call("adjust_bloomwardens_standing", 40)  # 60 total
	assert_str(str(gc.call("bloomwardens_tier"))).is_equal("Hand")
	gc.queue_free()


func test_reactivity_is_region_scoped() -> void:
	var gc := _make_controller()
	var run: RunContext = gc.call("new_run", TEST_SEED)
	# Move the active region off the Verdant fringe; a catch there must NOT touch Bloomwardens standing.
	run.world_state["active_region"] = "mournmarch"
	gc.call("apply_battle_result", {"player_won": true, "caught": {"species_id": "SB33"}})
	assert_int(int(gc.call("bloomwardens_standing"))).is_equal(0)
	gc.queue_free()


func test_standing_persists_across_save_continue() -> void:
	_clear_saves()
	var gc := _make_controller()
	gc.call("new_run", TEST_SEED)
	gc.call("adjust_bloomwardens_standing", 22)
	var expected := int(gc.call("bloomwardens_standing"))
	assert_bool(bool(gc.call("save_run"))).is_true()

	var gc2 := _make_controller()
	assert_bool(bool(gc2.call("continue_run"))).is_true()
	assert_int(int(gc2.call("bloomwardens_standing"))).is_equal(expected)
	assert_str(str(gc2.call("bloomwardens_tier"))).is_equal("Sworn")
	gc.queue_free()
	gc2.queue_free()
	_clear_saves()


func test_boss_win_marks_slice_cleared() -> void:
	var gc := _make_controller()
	gc.call("new_run", TEST_SEED)
	assert_bool(bool(gc.call("slice_cleared"))).is_false()
	gc.call("apply_battle_result", {"player_won": true, "boss_win": true, "enemy_defeated": 1})
	assert_bool(bool(gc.call("slice_cleared"))).is_true()
	gc.queue_free()
