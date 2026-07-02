extends GdUnitTestSuite
## Wave 16b (correction C14) — the ACT-0 quest spine, wired via the proven SQ-06 data pattern
## and walked HEADLESSLY through QuestService:
##   * 0.1 The Knack: Maddox starts it; Mother Kestrel's first-catch CHOICE (not the visit)
##     completes it — headless canon is the gentle path; the completion sets the
##     capture-unlock gate flag;
##   * 0.2 Altar Hours is GATED behind the Knack (talking to Veil early starts nothing);
##   * 0.3 The Mark is Vael's three-way brand choice — canon seal costs nothing; feeding
##     the mark is the one Act-0 tick that costs corruption;
##   * 0.4 Registered closes the act on Thessaly's rolls;
##   * every step surfaces in the shipped HUD tracker/journal path and survives a rebuild.

const GameControllerScript := preload("res://application/game/game_controller.gd")
const FakeDalScript := preload("res://infrastructure/dal/fake_dal.gd")
const OverworldScreenScript := preload("res://presentation/overworld/overworld_screen.gd")

const TEST_SEED := 0x0AC7_0016

## NPC_DEFS indices of the Act-0 cast (appended after the original ten wired NPCs).
const MADDOX := 10
const KESTREL := 11
const VEIL := 12
const VAEL := 13
const THESSALY := 14


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


func test_act0_spine_walks_from_the_knack_to_registered() -> void:
	var gc := _make_game()
	var run: RunContext = gc.call("new_run", TEST_SEED)
	var ow := _make_overworld(gc)
	# GATE: the bench takes specimens only after the Knack — an early visit starts nothing.
	ow.call("speak_to", VEIL)
	assert_bool(bool(ow.call("quest_active", "act0_altar_hours"))).is_false()
	# 0.1 The Knack — Maddox's mercy-and-math beat starts it...
	ow.call("speak_to", MADDOX)
	assert_bool(bool(ow.call("quest_active", "act0_the_knack"))).is_true()
	assert_bool(bool(run.flags.get("maddox_mercy_heard", false))).is_true()
	# ...and the HUD tracker surfaces the next objective (the shipped journal path).
	assert_str(str(ow.call("objective_text"))).contains("Let one choose you")
	# The pens' CHOICE (headless canon: offer the hand) completes it -> capture unlocks.
	ow.call("speak_to", KESTREL)
	assert_bool(bool(ow.call("quest_done", "act0_the_knack"))).is_true()
	assert_bool(bool(run.flags.get("first_catch_clean", false))).is_true()
	assert_bool(bool(run.flags.get("capture_unlocked", false))).is_true()
	# 0.2 Altar Hours — now unlocked; a single authored bench beat.
	ow.call("speak_to", VEIL)
	assert_bool(bool(ow.call("quest_done", "act0_altar_hours"))).is_true()
	assert_bool(bool(run.flags.get("altar_hours_kept", false))).is_true()
	# 0.3 The Mark — Vael's brand choice; the canon seal costs no corruption.
	var before_corruption := run.corruption
	ow.call("speak_to", VAEL)
	assert_bool(bool(ow.call("quest_done", "act0_the_mark"))).is_true()
	assert_bool(bool(run.flags.get("mark_sealed", false))).is_true()
	assert_bool(run.flags.has("mark_fed")).is_false()
	assert_int(run.corruption).is_equal(before_corruption)
	assert_bool(bool(run.flags.get("arena_opened", false))).is_true()
	# 0.4 Registered — Thessaly enters you on the rolls; the Nobody act closes.
	ow.call("speak_to", THESSALY)
	assert_bool(bool(ow.call("quest_done", "act0_registered"))).is_true()
	assert_bool(bool(run.flags.get("on_the_rolls", false))).is_true()
	assert_bool(bool(run.flags.get("registered_aspirant", false))).is_true()
	ow.queue_free()
	gc.queue_free()


func test_feeding_the_mark_is_the_corruption_tick() -> void:
	var gc := _make_game()
	var run: RunContext = gc.call("new_run", TEST_SEED)
	var ow := _make_overworld(gc)
	ow.call("speak_to", MADDOX)
	ow.call("speak_to", KESTREL)
	ow.call("speak_to", VEIL)
	var before_corruption := run.corruption
	# Drive the fed branch directly (on screen this arrives via choice_made).
	ow.call("_on_dialogue_choice", "vael_mark", "feed")
	assert_bool(bool(ow.call("quest_done", "act0_the_mark"))).is_true()
	assert_bool(bool(run.flags.get("mark_fed", false))).is_true()
	assert_int(run.corruption).is_equal(before_corruption + 2)
	# Re-firing after completion never re-applies (the ordered cursor rejects it).
	ow.call("_on_dialogue_choice", "vael_mark", "feed")
	assert_int(run.corruption).is_equal(before_corruption + 2)
	ow.queue_free()
	gc.queue_free()


func test_harsh_first_catch_carries_its_cost() -> void:
	var gc := _make_game()
	var run: RunContext = gc.call("new_run", TEST_SEED)
	var ow := _make_overworld(gc)
	ow.call("speak_to", MADDOX)
	var before_corruption := run.corruption
	ow.call("_on_dialogue_choice", "mother_kestrel", "bind_fast")
	assert_bool(bool(ow.call("quest_done", "act0_the_knack"))).is_true()
	assert_bool(bool(run.flags.get("first_catch_harsh", false))).is_true()
	assert_bool(run.flags.has("first_catch_clean")).is_false()
	assert_int(run.corruption).is_equal(before_corruption + 1)
	assert_bool(bool(run.flags.get("capture_unlocked", false))).is_true()
	ow.queue_free()
	gc.queue_free()


func test_act0_progress_survives_a_rebuild() -> void:
	var gc := _make_game()
	gc.call("new_run", TEST_SEED)
	var ow := _make_overworld(gc)
	ow.call("speak_to", MADDOX)
	ow.call("speak_to", KESTREL)
	ow.queue_free()
	var ow2 := _make_overworld(gc)
	assert_bool(bool(ow2.call("quest_done", "act0_the_knack"))).is_true()
	# The gate survives too: Veil's bench opens on the restored flags.
	ow2.call("speak_to", VEIL)
	assert_bool(bool(ow2.call("quest_done", "act0_altar_hours"))).is_true()
	ow2.queue_free()
	gc.queue_free()
