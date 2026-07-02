extends GdUnitTestSuite
## Wave 17 — the SCREEN ROUTER (UiRouter autoload), driven HEADLESSLY.
##   * overworld -> camp -> party -> camp -> resume: every hop is a PUSHED overlay and the
##     overworld node SURVIVES the whole walk (same instance, same player cell) — a black screen
##     is structurally unreachable because current_scene is never swapped;
##   * push/pop restores the InputService context recorded at push time;
##   * pop() on an empty stack is a safe no-op; a missing scene path pushes nothing;
##   * a buried camp menu SWALLOWS its resume verb (Esc pops exactly one level).

const GameControllerScript := preload("res://application/game/game_controller.gd")
const FakeDalScript := preload("res://infrastructure/dal/fake_dal.gd")
const OverworldScreenScript := preload("res://presentation/overworld/overworld_screen.gd")
const InputActions := preload("res://infrastructure/input/input_actions.gd")

const TEST_SEED := 0x0CEA_3B0B


func after_test() -> void:
	# Never leak overlays into the next test — the router is a shared autoload.
	var router := get_node_or_null("/root/UiRouter")
	if router != null:
		router.call("pop_all")


## HERMETIC: the router is an AUTOLOAD — an overlay another suite pushed (the ending
## screen fires on finale flags) must never leak into this suite's depth math.
func before_test() -> void:
	var router := get_node_or_null("/root/UiRouter")
	if router != null and router.has_method("pop_all"):
		router.call("pop_all")


func _router() -> Node:
	return get_node_or_null("/root/UiRouter")


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


func test_full_walk_preserves_the_live_overworld() -> void:
	var router := _router()
	assert_object(router).is_not_null()
	var gc := _make_game()
	var ow := _make_overworld(gc)
	var cell_before: Vector2i = ow.call("player_cell")

	# overworld -> camp: pushed as a router overlay (depth 1), never a scene swap.
	var menu: Node = ow.call("open_camp")
	assert_object(menu).is_not_null()
	assert_int(int(router.call("depth"))).is_equal(1)
	assert_bool(bool(router.call("is_top", menu))).is_true()

	# camp -> party: pushed ABOVE the camp (depth 2); the camp instance stays alive beneath.
	menu.call("open_party")
	assert_int(int(router.call("depth"))).is_equal(2)
	var party: Node = router.call("top_scene")
	assert_object(party).is_not_null()
	assert_bool(str(party.get_script().resource_path).ends_with("party_screen.gd")).is_true()
	assert_bool(bool(router.call("is_top", menu))).is_false()

	# party back -> camp: pop exactly one level; the SAME camp menu is on top again.
	party.call("return_to_camp")
	assert_int(int(router.call("depth"))).is_equal(1)
	assert_object(router.call("top_scene")).is_same(menu)

	# camp resume -> the LIVE overworld: depth 0, context restored, SAME overworld node + cell.
	menu.call("resume")
	assert_int(int(router.call("depth"))).is_equal(0)
	assert_object(ow.call("camp_overlay")).is_null()
	assert_bool(is_instance_valid(ow)).is_true()
	assert_bool(ow.is_inside_tree()).is_true()
	assert_that(ow.call("player_cell")).is_equal(cell_before)
	var input := get_node_or_null("/root/InputService")
	if input != null:
		assert_str(str(input.call("current_context"))).is_equal(InputActions.CTX_OVERWORLD)

	await get_tree().process_frame
	ow.queue_free()
	gc.queue_free()


func test_buried_camp_swallows_resume_esc_pops_one_level() -> void:
	var router := _router()
	var gc := _make_game()
	var ow := _make_overworld(gc)
	var menu: Node = ow.call("open_camp")
	menu.call("open_party")
	assert_int(int(router.call("depth"))).is_equal(2)

	# The BURIED camp's resume verb is swallowed — the party page above keeps its level, and the
	# overworld's camp refs are untouched (resumed was never emitted).
	menu.call("resume")
	assert_int(int(router.call("depth"))).is_equal(2)
	assert_object(ow.call("camp_overlay")).is_not_null()

	# Unwind properly: party pops, then camp resumes for real.
	(router.call("top_scene") as Node).call("return_to_camp")
	menu.call("resume")
	assert_int(int(router.call("depth"))).is_equal(0)

	await get_tree().process_frame
	ow.queue_free()
	gc.queue_free()


func test_pop_on_empty_is_a_safe_noop() -> void:
	var router := _router()
	assert_int(int(router.call("depth"))).is_equal(0)
	assert_bool(bool(router.call("pop"))).is_false()
	assert_int(int(router.call("depth"))).is_equal(0)


func test_push_missing_scene_returns_null() -> void:
	var router := _router()
	var pushed: Variant = router.call("push_scene", "res://presentation/does_not_exist.tscn")
	assert_object(pushed).is_null()
	assert_int(int(router.call("depth"))).is_equal(0)


func test_externally_freed_overlay_self_heals() -> void:
	var router := _router()
	var gc := _make_game()
	var ow := _make_overworld(gc)
	ow.call("open_camp")
	assert_int(int(router.call("depth"))).is_equal(1)
	# The overworld dies with its camp open (e.g. a scene swap) — the router heals its stack.
	# (Two frames: the overlay's own queue_free lands one deletion flush after the overworld's.)
	ow.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_int(int(router.call("depth"))).is_equal(0)
	gc.queue_free()
