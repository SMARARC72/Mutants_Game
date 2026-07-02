extends GdUnitTestSuite
## Wave 3 "Loop Truth" — the overworld side of the loop-honesty pass, driven HEADLESSLY.
##   * POSITION PERSISTENCE: the pre-battle autosave stashes the exact cell + facing; a rebuilt
##     (post-battle) overworld AND a from-disk continue both restore the player to that tile; a
##     stale/blocked saved cell falls back to the canonical spawn (never soft-locks);
##   * POST-BATTLE GRACE: the five steps after a fight never roll a wild encounter — even on a step
##     whose canonical stream WOULD fire — then the world's teeth come back;
##   * ONE ROLL PER DASH: a sigil-dash rolls the wild encounter once, at its LANDING step, matching
##     what walking to that step would have met (crossed tiles roll nothing);
##   * ONE-SHOT BOSS LAIR: the climax ambushes exactly once per run — a lost/fled boss fight never
##     re-ambushes on every subsequent step;
##   * BOSS-GOAL QUEST (C13): active from run start (the HUD tracker names the run's goal from step
##     zero) and completes through the quest_state flags path once the slice reads cleared;
##   * REGION TITLE: the HUD names the region the systems actually run (data-driven, id fallback).
## Deterministic: fixed seeds, canonical streams, no scene swaps (auto hand-off disabled).

const GameControllerScript := preload("res://application/game/game_controller.gd")
const FakeDalScript := preload("res://infrastructure/dal/fake_dal.gd")
const OverworldScreenScript := preload("res://presentation/overworld/overworld_screen.gd")
const EncounterDirectorScript := preload("res://application/overworld/encounter_director.gd")
const EncounterCatalogScript := preload("res://application/overworld/encounter_catalog.gd")
const OverworldTileSetScript := preload("res://presentation/overworld/overworld_tileset.gd")
const SaveEnvelopeScript := preload("res://application/persistence/save_envelope.gd")

const TEST_SEED := 0x100B_7247  # "LOOP TRuTh"
const REGION := "verdant_glut"


func _make_game() -> Node:
	var gc: Node = GameControllerScript.new()
	add_child(gc)
	gc.call("configure", FakeDalScript.make())
	return gc


func _make_overworld(game: Node) -> Node2D:
	var ow: Node2D = OverworldScreenScript.new()
	ow.call("set_game", game)
	ow.call("set_auto_hand_off", false)
	add_child(ow)
	ow.call("build_from_game")
	return ow


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


## The first step index (>=1) whose canonical wild roll fires a BATTLE for (seed, REGION) on a
## cell of `tile_class` (W13: the landing cell's class salts the stream, and only battle kinds
## arm the hand-off/grace machinery these tests exercise), or -1.
func _first_encounter_step(seed: int, tile_class: String = "") -> int:
	var director: EncounterDirector = EncounterDirectorScript.for_region(seed, REGION)
	for i in range(1, 500):
		var probe: Dictionary = director.roll_step(i, tile_class)
		if bool(probe["encounter"]) and str(probe["kind"]) == EncounterDirectorScript.KIND_BATTLE:
			return i
	return -1


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


## Park the run just before the given encounter step and keep the boss lair out of the way (these
## tests target the WILD roll; the climax precedence is proven separately below).
func _suppress_boss(run: RunContext) -> void:
	run.flags["verdant_boss_cleared"] = true


func test_prebattle_position_round_trips_in_memory_and_from_disk() -> void:
	_clear_saves()
	var gc := _make_game()
	var run: RunContext = gc.call("new_run", TEST_SEED)
	_suppress_boss(run)
	var ow := _make_overworld(gc)
	var dir := _walkable_dir(ow.call("layout"), ow.call("player_cell"))
	assert_bool(dir != Vector2i.ZERO).is_true()
	var landing: Vector2i = ow.call("player_cell")
	var landing_class := str(ow.call("tile_class_at", landing + dir))
	var encounter_step := _first_encounter_step(TEST_SEED, landing_class)
	assert_int(encounter_step).is_greater(0)
	run.world_state["steps"] = encounter_step - 1
	var roll: Dictionary = ow.call("try_move", dir)
	assert_bool(bool(roll.get("encounter", false))).is_true()
	var fight_cell: Vector2i = ow.call("player_cell")
	# The pre-battle autosave stashed the exact cell + facing (JSON-safe int pairs).
	var saved: Array = run.world_state.get("player_cell", [])
	assert_int(saved.size()).is_equal(2)
	assert_int(int(saved[0])).is_equal(fight_cell.x)
	assert_int(int(saved[1])).is_equal(fight_cell.y)
	ow.queue_free()

	# A REBUILT overworld (the post-battle return) restores the player to the exact tile + facing.
	var ow2 := _make_overworld(gc)
	var restored: Vector2i = ow2.call("player_cell")
	assert_bool(restored == fight_cell).is_true()
	ow2.queue_free()

	# And a FRESH controller continuing from disk restores it too (the full save round-trip).
	var gc2 := _make_game()
	assert_bool(bool(gc2.call("continue_run"))).is_true()
	var ow3 := _make_overworld(gc2)
	var from_disk: Vector2i = ow3.call("player_cell")
	assert_bool(from_disk == fight_cell).is_true()
	ow3.queue_free()
	gc.queue_free()
	gc2.queue_free()
	_clear_saves()


func test_blocked_saved_cell_falls_back_to_the_canonical_spawn() -> void:
	var gc := _make_game()
	var run: RunContext = gc.call("new_run", TEST_SEED)
	var ow := _make_overworld(gc)
	var spawn: Vector2i = ow.call("player_cell")
	var layout: Layout = ow.call("layout")
	# Find a NON-walkable cell and stash it as the "saved" position (a stale/corrupt save).
	var wall := Vector2i(-1, -1)
	for y in layout.height:
		for x in layout.width:
			if not OverworldTileSetScript.is_walkable(layout.get_cell(x, y)):
				wall = Vector2i(x, y)
				break
		if wall.x >= 0:
			break
	assert_bool(wall.x >= 0).is_true()
	run.world_state["player_cell"] = [wall.x, wall.y]
	ow.queue_free()
	var ow2 := _make_overworld(gc)
	var restored: Vector2i = ow2.call("player_cell")
	# Never spawns inside a wall: it falls back to the canonical spawn cell.
	assert_bool(restored == spawn).is_true()
	(
		assert_bool(OverworldTileSetScript.is_walkable(layout.get_cell(restored.x, restored.y)))
		. is_true()
	)
	ow2.queue_free()
	gc.queue_free()


func test_post_battle_grace_suppresses_five_would_fire_steps_then_expires() -> void:
	var gc := _make_game()
	var run: RunContext = gc.call("new_run", TEST_SEED)
	_suppress_boss(run)
	var ow := _make_overworld(gc)
	var d := _walkable_dir(ow.call("layout"), ow.call("player_cell"))
	assert_bool(d != Vector2i.ZERO).is_true()
	# W13: the first move (and the post-grace re-fire below) lands on the same cell, so ONE
	# landing class picks the canonical stream both alignments replay.
	var landing: Vector2i = ow.call("player_cell") + d
	var encounter_step := _first_encounter_step(TEST_SEED, str(ow.call("tile_class_at", landing)))
	assert_int(encounter_step).is_greater(0)
	# Fire the first battle: the hand-off arms the grace window.
	run.world_state["steps"] = encounter_step - 1
	var first: Dictionary = ow.call("try_move", d)
	assert_bool(bool(first.get("encounter", false))).is_true()
	var grace := int(run.world_state.get("encounter_grace", 0))
	assert_int(grace).is_equal(EncounterDirectorScript.POST_BATTLE_GRACE_STEPS)
	# Each of the next 5 steps is re-aligned onto a step whose canonical stream WOULD fire — and
	# the grace window suppresses every one of them (the world grants breathing room).
	var back_and_forth := -d
	for _i in EncounterDirectorScript.POST_BATTLE_GRACE_STEPS:
		run.world_state["steps"] = encounter_step - 1
		var graced: Dictionary = ow.call("try_move", back_and_forth)
		assert_bool(bool(graced.get("moved", false))).is_true()
		assert_bool(bool(graced.get("encounter", false))).is_false()
		assert_bool(bool(graced.get("graced", false))).is_true()
		back_and_forth = -back_and_forth
	assert_int(int(run.world_state.get("encounter_grace", 0))).is_equal(0)
	# Grace spent: the same aligned step now fires again — the world keeps its teeth.
	run.world_state["steps"] = encounter_step - 1
	var after: Dictionary = ow.call("try_move", back_and_forth)
	assert_bool(bool(after.get("encounter", false))).is_true()
	ow.queue_free()
	gc.queue_free()


func test_sigil_dash_rolls_exactly_once_at_the_landing_step() -> void:
	var gc := _make_game()
	var run: RunContext = gc.call("new_run", TEST_SEED)
	_suppress_boss(run)
	var ow := _make_overworld(gc)
	var d := _walkable_dir(ow.call("layout"), ow.call("player_cell"))
	assert_bool(d != Vector2i.ZERO).is_true()
	# W13: the first dashed tile's class picks the alignment stream (a dash meets exactly what
	# walking would have met, class and all).
	var first_tile: Vector2i = ow.call("player_cell") + d
	var encounter_step := _first_encounter_step(
		TEST_SEED, str(ow.call("tile_class_at", first_tile))
	)
	assert_int(encounter_step).is_greater(0)
	# Align so the FIRST dashed tile lands on a would-fire step: with per-tile rolls this dash would
	# stop at tile one; with the Wave-3 one-roll-per-dash it only fires if the LANDING step's own
	# canonical roll does — exactly what walking to that step would have met.
	run.world_state["steps"] = encounter_step - 1
	var seen := {"count": 0}
	ow.connect(
		"encounter_started",
		func(_party: Array, _seed: int) -> void: seen["count"] = int(seen["count"]) + 1
	)
	var crossed: int = ow.call("sigil_dash", d)
	assert_int(crossed).is_greater(0)
	var landing := encounter_step - 1 + crossed
	var director: EncounterDirector = EncounterDirectorScript.for_region(TEST_SEED, REGION)
	# The landing roll folds the LANDING cell's class in; encounter_started counts BATTLE kinds
	# only (a peculiar landing routes to the W16b seam instead).
	var landing_roll: Dictionary = director.roll_step(
		landing, str(ow.call("tile_class_at", ow.call("player_cell")))
	)
	var fired := (
		bool(landing_roll["encounter"])
		and str(landing_roll["kind"]) == EncounterDirectorScript.KIND_BATTLE
	)
	var expected := 1 if fired else 0
	assert_int(int(seen["count"])).is_equal(expected)
	# If the dash crossed PAST the would-fire step, its suppression is proven: crossing it fired
	# nothing unless the landing step itself rolled a hit.
	if crossed > 1 and expected == 0:
		assert_int(int(seen["count"])).is_equal(0)
	ow.queue_free()
	gc.queue_free()


func test_boss_lair_ambushes_once_and_never_again_uncleared() -> void:
	var gc := _make_game()
	var run: RunContext = gc.call("new_run", TEST_SEED)
	var ow := _make_overworld(gc)
	var min_steps := int(EncounterCatalogScript.boss_trigger_for(REGION)["min_steps"])
	var d := _walkable_dir(ow.call("layout"), ow.call("player_cell"))
	assert_bool(d != Vector2i.ZERO).is_true()
	run.world_state["steps"] = min_steps - 1
	var first: Dictionary = ow.call("try_move", d)
	assert_bool(bool(first.get("boss", false))).is_true()
	# The hand-off stashed a boss-tagged pending battle + the one-shot lair flag (persisted).
	var pending: Dictionary = run.flags.get("pending_battle", {})
	assert_bool(bool(pending.get("is_boss", false))).is_true()
	assert_bool(bool(run.world_state.get("boss_lair_fired_" + REGION, false))).is_true()
	# The slice is NOT cleared (the player will lose/flee this fight) — yet the lair never
	# re-ambushes: every later step is an ordinary wild roll, not the climax again.
	assert_bool(bool(gc.call("slice_cleared"))).is_false()
	var back_and_forth := -d
	for _i in 8:
		var again: Dictionary = ow.call("try_move", back_and_forth)
		assert_bool(bool(again.get("moved", false))).is_true()
		assert_bool(bool(again.get("boss", false))).is_false()
		back_and_forth = -back_and_forth
	ow.queue_free()
	gc.queue_free()


func test_boss_goal_quest_is_active_from_run_start_and_completes_on_victory() -> void:
	var gc := _make_game()
	gc.call("new_run", TEST_SEED)
	var ow := _make_overworld(gc)
	var qid := str(OverworldContent.BOSS_QUEST["id"])
	# Active from run start — the HUD tracker names the run's goal before any NPC is met.
	assert_bool(bool(ow.call("quest_active", qid))).is_true()
	assert_str(str(ow.call("objective_text"))).contains("deep glut")
	ow.queue_free()
	# A boss victory sets the slice flags (the same path a played win drives via the battle
	# screen); the next overworld build completes the quest through the quest_state flags path.
	gc.call("apply_battle_result", {"player_won": true, "boss_win": true, "enemy_defeated": 1})
	assert_bool(bool(gc.call("slice_cleared"))).is_true()
	var ow2 := _make_overworld(gc)
	assert_bool(bool(ow2.call("quest_done", qid))).is_true()
	ow2.queue_free()
	gc.queue_free()


func test_hud_names_the_region_the_systems_actually_run() -> void:
	var gc := _make_game()
	gc.call("new_run", TEST_SEED)
	var ow := _make_overworld(gc)
	var title := ow.find_child("RegionTitle", true, false) as Label
	assert_object(title).is_not_null()
	assert_str(title.text).is_equal("The Verdant Glut")
	assert_str(str(gc.call("active_region"))).is_equal(REGION)
	# The map is data-driven with an id fallback — an unmapped region names itself, never lies.
	assert_str(OverworldContent.region_title("somewhere_unmapped")).is_equal("somewhere_unmapped")
	ow.queue_free()
	gc.queue_free()
