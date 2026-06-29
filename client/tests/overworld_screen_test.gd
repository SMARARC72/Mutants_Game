extends GdUnitTestSuite
## Phase 5 · Slice 1 — Overworld screen DoD, driven HEADLESSLY (instantiate, call, assert).
##   * the overworld generates its region DETERMINISTICALLY from run.seed and PERSISTS it into
##     world_state (generate-once);
##   * on reload the persisted layout is REUSED, not re-solved (load_layout returns it without the
##     solver; tiles are identical even with a generator whose catalog is absent);
##   * try_move respects wall collision + bounds and advances the run step counter;
##   * driving moves triggers a canonical wild encounter that emits encounter_started + stashes the
##     pending battle (the overworld -> battle hand-off contract).
## Auto scene-swap is disabled so the encounter flow runs without changing the SceneTree.

const GameControllerScript := preload("res://application/game/game_controller.gd")
const FakeDalScript := preload("res://infrastructure/dal/fake_dal.gd")
const OverworldScreenScript := preload("res://presentation/overworld/overworld_screen.gd")
const WorldGeneratorScript := preload("res://infrastructure/worldgen/world_generator.gd")
const RegionRulesScript := preload("res://infrastructure/worldgen/region_rules.gd")
const EncounterDirectorScript := preload("res://application/overworld/encounter_director.gd")
const OverworldTileSetScript := preload("res://presentation/overworld/overworld_tileset.gd")

const TEST_SEED := 0x0CEA_2026


func _make_game() -> Node:
	var gc: Node = GameControllerScript.new()
	add_child(gc)
	gc.call("configure", FakeDalScript.make())
	return gc


func _make_overworld(game: Node) -> Node2D:
	var ow: Node2D = OverworldScreenScript.new()
	ow.call("set_game", game)
	ow.call("set_auto_hand_off", false)
	add_child(ow)  # _ready grabs autoloads; the injected game takes precedence on build.
	ow.call("build_from_game")
	return ow


func test_region_generates_and_persists_to_world_state() -> void:
	var gc := _make_game()
	var run: RunContext = gc.call("new_run", TEST_SEED)
	var ow := _make_overworld(gc)
	var layout: Layout = ow.call("layout")
	assert_object(layout).is_not_null()
	assert_int(layout.width).is_greater(0)
	assert_int(layout.height).is_greater(0)
	# The generated grid is persisted into world_state under the worldgen key (generate-once).
	var key := WorldGeneratorScript.WORLD_STATE_KEY
	(
		assert_bool((run.world_state.get(key, {}) as Dictionary).has(gc.call("active_region")))
		. is_true()
	)
	ow.queue_free()
	gc.queue_free()


func test_persisted_layout_is_reused_not_resolved() -> void:
	var gc := _make_game()
	var run: RunContext = gc.call("new_run", TEST_SEED)
	var ow := _make_overworld(gc)
	var first: Layout = ow.call("layout")

	# Reload from the PERSISTED dict with a generator whose catalog is intentionally ABSENT: if the
	# layout were re-solved it would hit the fallback (different tiles); load_layout must return the
	# stored grid unchanged (the reuse-on-load invariant, ADR-014).
	var bare_gen: WorldGenerator = WorldGeneratorScript.new(RegionRulesScript.new())
	var reloaded: Layout = bare_gen.load_layout(gc.call("active_region"), run.world_state)
	assert_object(reloaded).is_not_null()
	assert_bool(first.tiles_equal(reloaded)).is_true()
	ow.queue_free()
	gc.queue_free()


func test_region_generation_is_deterministic_across_runs() -> void:
	# Two independent runs with the same seed generate identical region tiles.
	var gc_a := _make_game()
	gc_a.call("new_run", TEST_SEED)
	var ow_a := _make_overworld(gc_a)
	var a: Layout = ow_a.call("layout")

	var gc_b := _make_game()
	gc_b.call("new_run", TEST_SEED)
	var ow_b := _make_overworld(gc_b)
	var b: Layout = ow_b.call("layout")

	assert_bool(a.tiles_equal(b)).is_true()
	ow_a.queue_free()
	ow_b.queue_free()
	gc_a.queue_free()
	gc_b.queue_free()


func test_try_move_blocks_walls_and_advances_steps() -> void:
	var gc := _make_game()
	gc.call("new_run", TEST_SEED)
	var ow := _make_overworld(gc)
	var layout: Layout = ow.call("layout")
	var spawn: Vector2i = ow.call("player_cell")
	var before := int(gc.call("current_step"))

	# OUT OF BOUNDS: a far step leaves the region entirely; it is rejected and never advances the
	# step counter. (The spawn is now the walkable cell nearest centre, so no single cardinal is
	# guaranteed off-grid — a deliberately huge delta is.)
	var oob: Dictionary = ow.call("try_move", Vector2i(-1000, 0))
	assert_bool(bool(oob.get("moved", false))).is_false()
	assert_int(int(gc.call("current_step"))).is_equal(before)

	# WALL COLLISION (best-effort): if the spawn borders a wall, stepping into it is blocked and the
	# counter still holds. A wall neighbour is not guaranteed for every layout, so only assert when
	# one exists.
	var wall_dir := _wall_dir(layout, spawn)
	if wall_dir != Vector2i.ZERO:
		var into_wall: Dictionary = ow.call("try_move", wall_dir)
		assert_bool(bool(into_wall.get("moved", false))).is_false()
		assert_int(int(gc.call("current_step"))).is_equal(before)

	# A valid step into a walkable neighbour advances the step counter by exactly one.
	var open_dir := _walkable_dir(layout, spawn)
	assert_bool(open_dir != Vector2i.ZERO).is_true()
	var moved: Dictionary = ow.call("try_move", open_dir)
	assert_bool(bool(moved.get("moved", false))).is_true()
	assert_int(int(gc.call("current_step"))).is_equal(before + 1)

	ow.queue_free()
	gc.queue_free()


func test_sigil_dash_crosses_up_to_three_tiles_and_advances_by_exactly_that() -> void:
	# Sigil-dash hops up to DASH_TILES (3) along a direction, stopping at walls/edges/encounters; the
	# avatar ends exactly `crossed` tiles further along, and the step counter advanced once per tile.
	var gc := _make_game()
	gc.call("new_run", TEST_SEED)
	var ow := _make_overworld(gc)
	var layout: Layout = ow.call("layout")
	var before: Vector2i = ow.call("player_cell")
	var dir := _walkable_dir(layout, before)
	assert_bool(dir != Vector2i.ZERO).is_true()
	var steps_before := int(gc.call("current_step"))
	var crossed: int = ow.call("sigil_dash", dir)
	assert_int(crossed).is_greater(0)
	assert_int(crossed).is_less_equal(3)
	var after: Vector2i = ow.call("player_cell")
	assert_int(after.x).is_equal(before.x + dir.x * crossed)
	assert_int(after.y).is_equal(before.y + dir.y * crossed)
	assert_int(int(gc.call("current_step"))).is_equal(steps_before + crossed)
	ow.queue_free()
	gc.queue_free()


func test_spawn_is_in_the_largest_reachable_area_not_a_sealed_room() -> void:
	# The player must spawn in the LARGEST 4-connected walkable component (the open field), never
	# inside a sealed DungeonAssembler set-piece room (a walled interior with no doorway) — a spawn
	# there could move within the room but never leave, soft-locking the run.
	var gc := _make_game()
	gc.call("new_run", TEST_SEED)
	var ow := _make_overworld(gc)
	var layout: Layout = ow.call("layout")
	var spawn: Vector2i = ow.call("player_cell")
	var spawn_size := _component_size(layout, spawn)
	var max_size := 0
	for y in layout.height:
		for x in layout.width:
			if OverworldTileSetScript.is_walkable(layout.get_cell(x, y)):
				max_size = maxi(max_size, _component_size(layout, Vector2i(x, y)))
	assert_int(spawn_size).is_equal(max_size)
	assert_int(spawn_size).is_greater(1)  # not a one-tile pocket
	ow.queue_free()
	gc.queue_free()


func test_driving_a_move_into_an_encounter_step_hands_off() -> void:
	# Determinism lets us PRE-COMPUTE the first step index that triggers an encounter for this
	# (seed, region), align the run's step counter just before it, then make ONE walkable move so
	# the very next advance_step lands on the encounter step. This proves the overworld -> battle
	# hand-off contract deterministically, without relying on a long random walk.
	var gc := _make_game()
	var run: RunContext = gc.call("new_run", TEST_SEED)
	var ow := _make_overworld(gc)
	var layout: Layout = ow.call("layout")
	var region := str(gc.call("active_region"))

	var director: EncounterDirector = EncounterDirectorScript.for_region(TEST_SEED, region)
	var encounter_step := -1
	for i in range(1, 500):
		if bool((director.roll_step(i) as Dictionary)["encounter"]):
			encounter_step = i
			break
	assert_int(encounter_step).is_greater(0)  # the stream must fire within the window.

	# Find a walkable neighbour of the spawn so the move is guaranteed to succeed.
	var spawn: Vector2i = ow.call("player_cell")
	var step_dir := _walkable_dir(layout, spawn)
	assert_bool(step_dir != Vector2i.ZERO).is_true()

	# Align the counter so the next advance_step == encounter_step.
	run.world_state["steps"] = encounter_step - 1

	var seen := {"hit": false, "party": [], "seed": 0}
	ow.connect(
		"encounter_started",
		func(party: Array, seed: int) -> void:
			seen["hit"] = true
			seen["party"] = party
			seen["seed"] = seed
	)
	var roll: Dictionary = ow.call("try_move", step_dir)
	assert_bool(bool(roll.get("moved", false))).is_true()
	assert_bool(bool(roll.get("encounter", false))).is_true()
	assert_bool(bool(seen["hit"])).is_true()
	assert_int((seen["party"] as Array).size()).is_greater(0)
	# The hand-off stashed the pending battle on the run (overworld -> battle contract).
	var pending: Dictionary = run.flags.get("pending_battle", {})
	assert_bool(pending.has("enemy_party")).is_true()
	assert_int(int(pending.get("battle_seed", 0))).is_equal(int(roll["battle_seed"]))
	ow.queue_free()
	gc.queue_free()


func test_overworld_places_talkable_npcs() -> void:
	var gc := _make_game()
	gc.call("new_run", TEST_SEED)
	var ow := _make_overworld(gc)
	assert_int(int(ow.call("npc_count"))).is_greater(0)
	ow.queue_free()
	gc.queue_free()


func test_speaking_to_an_npc_emits_its_dialogue_timeline() -> void:
	# speak_to plays the NPC's authored Dialogic timeline; headless it resolves immediately, but the
	# dialogue_started signal + returned timeline id prove the beat fired (the overworld<->narrative seam).
	var gc := _make_game()
	gc.call("new_run", TEST_SEED)
	var ow := _make_overworld(gc)
	var seen := {"id": ""}
	ow.connect("dialogue_started", func(tid: String) -> void: seen["id"] = tid)
	var timeline: String = ow.call("speak_to", 0)
	assert_str(timeline).is_not_empty()
	assert_str(str(seen["id"])).is_equal(timeline)
	ow.queue_free()
	gc.queue_free()


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


## A cardinal direction from `cell` into an IN-BOUNDS but NON-walkable (wall) neighbour, or ZERO if
## the cell has no immediate wall neighbour (all borders are floor or the region edge).
func _wall_dir(layout: Layout, cell: Vector2i) -> Vector2i:
	for dir: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
		var n := cell + dir
		if (
			layout.in_bounds(n.x, n.y)
			and not OverworldTileSetScript.is_walkable(layout.get_cell(n.x, n.y))
		):
			return dir
	return Vector2i.ZERO


## Size of the 4-connected walkable component containing `start` (independent flood fill, used to
## verify the spawn lands in the largest reachable area). 0 if `start` itself is not walkable.
func _component_size(layout: Layout, start: Vector2i) -> int:
	if not OverworldTileSetScript.is_walkable(layout.get_cell(start.x, start.y)):
		return 0
	var visited := {start: true}
	var queue: Array[Vector2i] = [start]
	var count := 0
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		count += 1
		for dir: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := cell + dir
			if visited.has(n) or not layout.in_bounds(n.x, n.y):
				continue
			if OverworldTileSetScript.is_walkable(layout.get_cell(n.x, n.y)):
				visited[n] = true
				queue.append(n)
	return count
