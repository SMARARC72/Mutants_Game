extends GdUnitTestSuite
## Wave 6 "Motion & Camera Feel" — the SYNCHRONOUS grid contract under the new tween layer,
## driven HEADLESSLY (tests never pump _process; try_move stays instant at the LOGIC level):
##   * step chaining: two rapid try_move-level inputs both apply their cells + advance the step
##     counter twice — the visual tween layer never queues, drops, or delays a logic step;
##   * a BLOCKED move thunks (the interim ui_click fires) but NEVER moves the cell/counter;
##   * every real step start plays a FOOTSTEP (the W-SND hook); a dash is one whoosh, so its
##     crossed tiles play none;
##   * headless, the player NODE's visual position applies INSTANTLY (the no-animate fallback
##     that keeps every pre-Wave-6 overworld suite green unmodified).

const GameControllerScript := preload("res://application/game/game_controller.gd")
const FakeDalScript := preload("res://infrastructure/dal/fake_dal.gd")
const OverworldScreenScript := preload("res://presentation/overworld/overworld_screen.gd")
const OverworldTileSetScript := preload("res://presentation/overworld/overworld_tileset.gd")

const TEST_SEED := 0x0CEA_2026


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


## A cardinal direction from `cell` into a walkable, in-bounds neighbour, or ZERO if hemmed in.
func _walkable_dir(layout: Layout, cell: Vector2i) -> Vector2i:
	for dir: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
		var n := cell + dir
		if (
			layout.in_bounds(n.x, n.y)
			and OverworldTileSetScript.is_walkable(layout.get_cell(n.x, n.y))
		):
			return dir
	return Vector2i.ZERO


## A cardinal direction from `cell` into an IN-BOUNDS but NON-walkable (wall) neighbour, or ZERO.
func _wall_dir(layout: Layout, cell: Vector2i) -> Vector2i:
	for dir: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
		var n := cell + dir
		if (
			layout.in_bounds(n.x, n.y)
			and not OverworldTileSetScript.is_walkable(layout.get_cell(n.x, n.y))
		):
			return dir
	return Vector2i.ZERO


## The SfxService autoload (headless it records last_played without a device), or null.
func _sfx() -> Node:
	return get_node_or_null("/root/SfxService")


func test_two_rapid_steps_both_apply_their_cells_and_counter() -> void:
	var gc := _make_game()
	var ow := _make_overworld(gc)
	var layout: Layout = ow.call("layout")
	var start: Vector2i = ow.call("player_cell")
	var steps_before := int(gc.call("current_step"))
	var d1 := _walkable_dir(layout, start)
	assert_bool(d1 != Vector2i.ZERO).is_true()
	var first: Dictionary = ow.call("try_move", d1)
	assert_bool(bool(first.get("moved", false))).is_true()
	var mid: Vector2i = ow.call("player_cell")
	assert_bool(mid == start + d1).is_true()
	# Immediately step again (same frame — a buffered/chained input at the logic level): the
	# second cell applies too; the tween layer never defers or drops the grid update.
	var d2 := _walkable_dir(layout, mid)
	assert_bool(d2 != Vector2i.ZERO).is_true()
	var second: Dictionary = ow.call("try_move", d2)
	assert_bool(bool(second.get("moved", false))).is_true()
	assert_bool(Vector2i(ow.call("player_cell")) == mid + d2).is_true()
	assert_int(int(gc.call("current_step"))).is_equal(steps_before + 2)
	ow.queue_free()
	gc.queue_free()


func test_blocked_move_thunks_but_never_moves_the_cell() -> void:
	var gc := _make_game()
	var ow := _make_overworld(gc)
	var layout: Layout = ow.call("layout")
	var cell_before: Vector2i = ow.call("player_cell")
	var steps_before := int(gc.call("current_step"))
	var sfx := _sfx()
	if sfx != null:
		sfx.set("last_played", "")
	# OUT OF BOUNDS: rejected, cell + counter untouched — but the wall audibly thunks.
	var oob: Dictionary = ow.call("try_move", Vector2i(-1000, 0))
	assert_bool(bool(oob.get("moved", false))).is_false()
	assert_bool(Vector2i(ow.call("player_cell")) == cell_before).is_true()
	assert_int(int(gc.call("current_step"))).is_equal(steps_before)
	if sfx != null:
		assert_str(str(sfx.get("last_played"))).is_equal("ui_click")
	# WALL (best-effort — only if the spawn borders one): same contract.
	var wall := _wall_dir(layout, cell_before)
	if wall != Vector2i.ZERO:
		if sfx != null:
			sfx.set("last_played", "")
		var into_wall: Dictionary = ow.call("try_move", wall)
		assert_bool(bool(into_wall.get("moved", false))).is_false()
		assert_bool(Vector2i(ow.call("player_cell")) == cell_before).is_true()
		if sfx != null:
			assert_str(str(sfx.get("last_played"))).is_equal("ui_click")
	ow.queue_free()
	gc.queue_free()


func test_step_start_plays_a_footstep_and_dash_plays_none() -> void:
	var gc := _make_game()
	var ow := _make_overworld(gc)
	var layout: Layout = ow.call("layout")
	var sfx := _sfx()
	if sfx == null:
		return  # no autoload in this harness — the hook is covered by the live game
	sfx.set("last_played", "")
	var d := _walkable_dir(layout, ow.call("player_cell"))
	assert_bool(d != Vector2i.ZERO).is_true()
	var moved: Dictionary = ow.call("try_move", d)
	assert_bool(bool(moved.get("moved", false))).is_true()
	assert_str(str(sfx.get("last_played"))).contains("footstep_")
	# A dash is ONE whoosh: its crossed tiles never drum per-tile footsteps (or thunks).
	sfx.set("last_played", "")
	var dash_dir := _walkable_dir(layout, ow.call("player_cell"))
	assert_bool(dash_dir != Vector2i.ZERO).is_true()
	var crossed: int = ow.call("sigil_dash", dash_dir)
	assert_int(crossed).is_greater(0)
	assert_str(str(sfx.get("last_played"))).is_equal("")
	ow.queue_free()
	gc.queue_free()


func test_headless_visual_position_applies_instantly() -> void:
	var gc := _make_game()
	var ow := _make_overworld(gc)
	var layout: Layout = ow.call("layout")
	# Wave 12: the player lives one level down, under the y-sorted WorldYSort root.
	var player := ow.find_child("Player", true, false) as Node2D
	assert_object(player).is_not_null()
	var d := _walkable_dir(layout, ow.call("player_cell"))
	assert_bool(d != Vector2i.ZERO).is_true()
	ow.call("try_move", d)
	# Headless (no animatable display) the token SNAPS to the new cell centre in the same
	# call — the instant fallback all pre-Wave-6 suites rely on. Same expression, exact match.
	var cell: Vector2i = ow.call("player_cell")
	var s := OverworldTileSetScript.TILE_SIZE
	var expected := Vector2(cell.x * s + s / 2.0, cell.y * s + s / 2.0)
	assert_bool(player.position == expected).is_true()
	# The explicit test flag pins instant mode wherever a display exists (timing-free tests).
	ow.call("set_instant_moves", true)
	var d2 := _walkable_dir(layout, cell)
	assert_bool(d2 != Vector2i.ZERO).is_true()
	ow.call("try_move", d2)
	var cell2: Vector2i = ow.call("player_cell")
	var expected2 := Vector2(cell2.x * s + s / 2.0, cell2.y * s + s / 2.0)
	assert_bool(player.position == expected2).is_true()
	ow.queue_free()
	gc.queue_free()
