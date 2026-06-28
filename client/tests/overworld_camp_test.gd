extends GdUnitTestSuite
## Phase 5 · Slice 3b — the overworld -> camp-menu trigger, driven HEADLESSLY.
##   * open_camp() raises the camp menu as an OVERLAY (a CanvasLayer child, NOT a scene swap, so the
##     overworld stays live beneath it) and is idempotent;
##   * the camp menu's `resumed` signal tears the overlay down (closes back to the overworld).
## This is additive to the overworld (behind the _camp_enabled flag), so the Slice-1 try_move tests
## are untouched (they never pump _process).

const GameControllerScript := preload("res://application/game/game_controller.gd")
const FakeDalScript := preload("res://infrastructure/dal/fake_dal.gd")
const OverworldScreenScript := preload("res://presentation/overworld/overworld_screen.gd")

const TEST_SEED := 0x0CEA_3B0B


func _make_game() -> Node:
	var gc: Node = GameControllerScript.new()
	add_child(gc)
	gc.call("configure", FakeDalScript.make())
	gc.call("new_run", TEST_SEED)
	return gc


func _make_overworld(game: Node) -> Node2D:
	var ow: Node2D = OverworldScreenScript.new()
	ow.call("set_game", game)
	ow.call("set_auto_hand_off", false)
	add_child(ow)
	ow.call("build_from_game")
	return ow


func test_open_camp_raises_an_overlay() -> void:
	var gc := _make_game()
	var ow := _make_overworld(gc)
	var menu: Node = ow.call("open_camp")
	assert_object(menu).is_not_null()
	# The overlay is a live child of the overworld (no scene swap).
	assert_object(ow.call("camp_overlay")).is_not_null()
	# The camp menu carries its buttons.
	assert_object((menu as Node).find_child("ResumeButton", true, false)).is_not_null()
	ow.queue_free()
	gc.queue_free()


func test_open_camp_is_idempotent() -> void:
	var gc := _make_game()
	var ow := _make_overworld(gc)
	var first: Node = ow.call("open_camp")
	var second: Node = ow.call("open_camp")
	# A second open while the menu is up returns the SAME overlay (no duplicate).
	assert_object(ow.call("camp_overlay")).is_same(ow.call("camp_overlay"))
	assert_bool(is_instance_valid(first)).is_true()
	assert_bool(is_instance_valid(second)).is_true()
	ow.queue_free()
	gc.queue_free()


func test_resume_closes_the_overlay() -> void:
	var gc := _make_game()
	var ow := _make_overworld(gc)
	var menu: Node = ow.call("open_camp")
	menu.call("resume")
	await get_tree().process_frame
	# The overlay reference is cleared and the node is freed.
	assert_object(ow.call("camp_overlay")).is_null()
	ow.queue_free()
	gc.queue_free()
