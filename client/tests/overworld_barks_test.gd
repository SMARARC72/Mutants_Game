extends GdUnitTestSuite
## Wave 16b — ambient proximity BARKS + the 5th-repeat swap + the signpost crack, headless.
##   * a bark fires only with a wired NPC within 2 cells, picks its authored line
##     DETERMINISTICALLY (VoiceBook local hash of key+step), and honours a HARD cooldown of
##     >= 25 steps between ANY two barks (a run.world_state counter a test can drive);
##   * barks never fire during dialogue;
##   * talking to the SAME NPC a 5th+ time swaps the replayed scene for the authored
##     out-of-lines beat (no dialogue_started re-emission — the scene never replays);
##   * the weathered signpost reads once per run — the authored fourth-wall line formatted
##     with the run's save name — then never again (FourthWall's one-shot registry).

const GameControllerScript := preload("res://application/game/game_controller.gd")
const FakeDalScript := preload("res://infrastructure/dal/fake_dal.gd")
const OverworldScreenScript := preload("res://presentation/overworld/overworld_screen.gd")
const OverworldBarksScript := preload("res://presentation/overworld/overworld_barks.gd")
const OverworldTileSetScript := preload("res://presentation/overworld/overworld_tileset.gd")
const FourthWallScript := preload("res://presentation/narrative/fourth_wall.gd")

const TEST_SEED := 0x16BBA24E


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


func test_barks_are_deterministic_and_the_cooldown_is_hard() -> void:
	var gc := _make_game()
	var run: RunContext = gc.call("new_run", TEST_SEED)
	var ow := _make_overworld(gc)
	# The cast rings the spawn (manhattan radius 2+), so someone is always within earshot.
	var first := OverworldBarksScript.step_tick(ow, run, 25)
	assert_str(first).is_not_empty()
	assert_int(int(run.world_state.get(OverworldBarksScript.LAST_BARK_KEY, -1))).is_equal(25)
	# HARD cooldown: nothing for the next COOLDOWN_STEPS-1 steps, no matter who is nearby.
	assert_str(OverworldBarksScript.step_tick(ow, run, 26)).is_equal("")
	assert_str(OverworldBarksScript.step_tick(ow, run, 49)).is_equal("")
	var second := OverworldBarksScript.step_tick(ow, run, 50)
	assert_str(second).is_not_empty()
	# Deterministic pick: the same (region key, step) always mutters the same authored line.
	assert_str(second).is_equal(VoiceBook.pick("bark.region.verdant_glut", 50))
	ow.queue_free()
	gc.queue_free()


func test_barks_never_fire_during_dialogue() -> void:
	var gc := _make_game()
	var run: RunContext = gc.call("new_run", TEST_SEED)
	var ow := _make_overworld(gc)
	ow.set("_in_dialogue", true)
	assert_str(OverworldBarksScript.step_tick(ow, run, 200)).is_equal("")
	assert_bool(run.world_state.has(OverworldBarksScript.LAST_BARK_KEY)).is_false()
	ow.set("_in_dialogue", false)
	assert_str(OverworldBarksScript.step_tick(ow, run, 200)).is_not_empty()
	ow.queue_free()
	gc.queue_free()


func test_fifth_repeat_talk_swaps_to_the_out_of_lines_beat() -> void:
	var gc := _make_game()
	var run: RunContext = gc.call("new_run", TEST_SEED)
	var ow := _make_overworld(gc)
	var emitted: Array = []
	ow.connect("dialogue_started", func(timeline: String) -> void: emitted.append(timeline))
	for _i in 4:
		ow.call("speak_to", 0)  # Old Marrow, four honest replays
	assert_int(emitted.size()).is_equal(4)
	assert_bool(OverworldBarksScript.out_of_lines(run, "Old Marrow")).is_false()
	# The 5th talk swaps: the scene does NOT replay (no dialogue_started), the interact
	# contract still returns the timeline id, and the tally is persisted world_state.
	assert_str(str(ow.call("speak_to", 0))).is_equal("marsh_oracle")
	assert_int(emitted.size()).is_equal(4)
	assert_bool(OverworldBarksScript.out_of_lines(run, "Old Marrow")).is_true()
	var talks: Dictionary = run.world_state.get(OverworldBarksScript.TALKS_KEY, {})
	assert_int(int(talks.get("Old Marrow", 0))).is_equal(5)
	ow.queue_free()
	gc.queue_free()


func test_out_of_lines_swap_never_locks_an_unresolved_choice() -> void:
	# An NPC still holding an unresolved choice quest keeps its real scene even past the
	# tally (the branch must stay reachable) — the swap only claims NPCs with nothing left.
	var gc := _make_game()
	var run: RunContext = gc.call("new_run", TEST_SEED)
	var ow := _make_overworld(gc)
	ow.call("speak_to", 6)  # Hearthward Ona starts SQ-05 (Garran's step is next)
	for _i in 6:
		OverworldBarksScript.count_talk(run, "Old Garran")  # farm the tally past the cap
	var emitted: Array = []
	ow.connect("dialogue_started", func(timeline: String) -> void: emitted.append(timeline))
	ow.call("speak_to", 7)  # Old Garran: choice pending -> the real scene still plays
	assert_array(emitted).contains(["old_garran"])
	assert_bool(bool(ow.call("quest_done", "six_petals_true_bred"))).is_true()
	ow.queue_free()
	gc.queue_free()


func test_signpost_reads_once_and_knows_your_name() -> void:
	var gc := _make_game()
	var run: RunContext = gc.call("new_run", TEST_SEED)
	var ow := _make_overworld(gc)
	# The sign is the last cast entry — placed like any token, but it reads, never mutters.
	var sign_index := OverworldContent.NPC_DEFS.size() - 1
	assert_int(int(ow.call("npc_count"))).is_equal(OverworldContent.NPC_DEFS.size())
	assert_str(str(ow.call("speak_to", sign_index))).is_equal("signpost")
	assert_bool(FourthWallScript.seen(run, FourthWallScript.CRACK_SIGNPOST)).is_true()
	# Ever after it is just a sign (the ration holds, across this run's whole life).
	assert_str(str(ow.call("speak_to", sign_index))).is_equal("")
	ow.queue_free()
	gc.queue_free()


func test_step_tick_is_wired_into_try_move() -> void:
	# The overworld's per-step ambient tick actually runs on real moves: pacing back and
	# forth beside the cast, the world_state bark counter appears (state, not presentation).
	var gc := _make_game()
	var run: RunContext = gc.call("new_run", TEST_SEED)
	var ow := _make_overworld(gc)
	var dir := _walkable_dir(ow.call("layout"), ow.call("player_cell"))
	assert_bool(dir != Vector2i.ZERO).is_true()
	for _i in 60:
		if run.world_state.has(OverworldBarksScript.LAST_BARK_KEY):
			break
		var res: Dictionary = ow.call("try_move", dir, false)  # counter ticks; no wild roll
		if not bool(res.get("moved", false)):
			break
		dir = -dir  # pace: step out, step home — the cast rings the spawn
	assert_bool(run.world_state.has(OverworldBarksScript.LAST_BARK_KEY)).is_true()
	ow.queue_free()
	gc.queue_free()


func _walkable_dir(layout: Layout, cell: Vector2i) -> Vector2i:
	for dir: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		var target := cell + dir
		if not layout.in_bounds(target.x, target.y):
			continue
		if OverworldTileSetScript.is_walkable(layout.get_cell(target.x, target.y)):
			return dir
	return Vector2i.ZERO
