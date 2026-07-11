extends GdUnitTestSuite
## Wave 16a — Dialogic CHOICE spine, headless.
##   * DialogicFacade re-emits the timeline's `[signal arg="choice:<tag>"]` convention as
##     `choice_made(scene_id, branch_tag)` and ignores non-choice signal events;
##   * headless play resolves the caller's canon branch instantly, BEFORE scene_finished,
##     so choice-gated quests stay completable in CI;
##   * old_garran.dtl actually parses (Dialogic 2's native `- choice` events) with both
##     branch signals, and its speaker resolves through the registered .dch directory;
##   * the overworld wires a resolved branch into QuestService: refuse (canon/headless
##     default) completes SQ-05 with the creed flag; accept completes it too — wrong-bright
##     flag + corruption — and NEVER double-applies on a re-fire.

const GameControllerScript := preload("res://application/game/game_controller.gd")
const FakeDalScript := preload("res://infrastructure/dal/fake_dal.gd")
const OverworldScreenScript := preload("res://presentation/overworld/overworld_screen.gd")
const DialogicFacadeScript := preload("res://presentation/narrative/dialogic_facade.gd")

const TEST_SEED := 0x16AC01CE
const QUEST_ID := "six_petals_true_bred"


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


func test_facade_emits_choice_made_for_choice_signal_events() -> void:
	var facade: DialogicFacade = DialogicFacadeScript.new()
	var seen: Array = []
	facade.choice_made.connect(
		func(scene_id: String, tag: String) -> void: seen.append([scene_id, tag])
	)
	facade.play_timeline("old_garran")  # headless: sets the active scene, finishes instantly
	facade._on_dialogic_signal("choice:refuse")
	assert_array(seen).is_equal([["old_garran", "refuse"]])
	# Non-choice signal events pass through untouched — the facade never swallows or
	# misreads them as branches.
	facade._on_dialogic_signal("some_other_cue")
	facade._on_dialogic_signal({"not": "a string"})
	assert_int(seen.size()).is_equal(1)


func test_headless_play_resolves_canon_branch_before_scene_finished() -> void:
	var facade: DialogicFacade = DialogicFacadeScript.new()
	var order: Array = []
	facade.choice_made.connect(
		func(_scene_id: String, tag: String) -> void: order.append("choice:" + tag)
	)
	facade.scene_finished.connect(func(_tid: String) -> void: order.append("finished"))
	var on_screen: bool = facade.play_timeline("old_garran", "refuse")
	assert_bool(on_screen).is_false()  # headless never renders
	assert_array(order).is_equal(["choice:refuse", "finished"])


func test_headless_play_without_branch_only_finishes() -> void:
	var facade: DialogicFacade = DialogicFacadeScript.new()
	var order: Array = []
	facade.choice_made.connect(func(_s: String, tag: String) -> void: order.append(tag))
	facade.scene_finished.connect(func(_tid: String) -> void: order.append("finished"))
	facade.play_timeline("marsh_oracle")
	assert_array(order).is_equal(["finished"])


func test_old_garran_timeline_parses_choices_and_branch_signals() -> void:
	# Dialogic 2 parses `- choice` natively; the rewritten old_garran.dtl must yield two
	# choice events and both branch signal events (the facade's pass-through convention).
	var timeline: DialogicTimeline = load("res://presentation/dialogue/old_garran.dtl")
	assert_object(timeline).is_not_null()
	timeline.process()
	var choices := 0
	var signal_args: Array = []
	for event: Variant in timeline.events:
		if event is DialogicChoiceEvent:
			choices += 1
		elif event is DialogicSignalEvent:
			signal_args.append(str(event.argument))
	assert_int(choices).is_equal(2)
	assert_array(signal_args).contains(["choice:refuse", "choice:accept"])


func test_garran_speaker_resolves_through_registered_dch_directory() -> void:
	# The 10 wired NPCs ship .dch character files registered in [dialogic] dch_directory;
	# the identifier used by old_garran.dtl's text events must load as a real character.
	DialogicFacade.ensure_directories()  # CI import wipes [dialogic] maps; the game self-heals
	# Assert the directory resolves our identifier to OUR file first — if this fails on a
	# fresh-import runner, the message carries the wrongly-resolved path (diagnosis built in).
	var dch_dir: Dictionary = DialogicResourceUtil.get_directory("dch")
	assert_str(str(dch_dir.get("old_garran", "<missing>"))).is_equal(
		"res://presentation/dialogue/characters/old_garran.dch"
	)
	var character: DialogicCharacter = DialogicResourceUtil.get_character_resource("old_garran")
	assert_object(character).is_not_null()
	assert_str(character.display_name).is_equal("Old Garran")


func test_refuse_branch_is_the_headless_canon_and_completes_the_quest() -> void:
	var gc := _make_game()
	var run: RunContext = gc.call("new_run", TEST_SEED)
	var before_corruption: int = run.corruption
	var ow := _make_overworld(gc)
	ow.call("speak_to", 6)  # Hearthward Ona starts SQ-05
	assert_bool(bool(ow.call("quest_active", QUEST_ID))).is_true()
	ow.call("speak_to", 7)  # Old Garran: headless resolves the canon "refuse" branch
	assert_bool(bool(ow.call("quest_done", QUEST_ID))).is_true()
	assert_bool(bool(run.flags.get("refused_the_shortcut", false))).is_true()
	assert_bool(run.flags.has("took_the_shortcut")).is_false()
	assert_int(run.corruption).is_equal(before_corruption)  # the creed path costs nothing
	assert_int(run.purity_corrupt).is_equal(-11)  # authored "refuse power" morality movement
	ow.queue_free()
	gc.queue_free()


func test_accept_branch_also_completes_but_wrong_bright() -> void:
	var gc := _make_game()
	var run: RunContext = gc.call("new_run", TEST_SEED)
	var before_corruption: int = run.corruption
	var ow := _make_overworld(gc)
	ow.call("speak_to", 6)  # Hearthward Ona starts SQ-05
	# Drive the branch dispatch directly (on screen this arrives via choice_made).
	ow.call("_on_dialogue_choice", "old_garran", "accept")
	assert_bool(bool(ow.call("quest_done", QUEST_ID))).is_true()
	assert_bool(bool(run.flags.get("took_the_shortcut", false))).is_true()
	assert_bool(run.flags.has("refused_the_shortcut")).is_false()
	assert_int(run.corruption).is_equal(before_corruption + 1)
	assert_int(run.order_chaos).is_equal(12)  # authored "break a taboo" morality movement
	# Re-firing the branch after completion must not re-apply corruption (idempotence).
	ow.call("_on_dialogue_choice", "old_garran", "accept")
	assert_int(run.corruption).is_equal(before_corruption + 1)
	assert_int(run.order_chaos).is_equal(12)  # idempotent: the event is not applied twice
	ow.queue_free()
	gc.queue_free()


func test_out_of_order_choice_applies_nothing() -> void:
	# A branch resolved before Ona's step (out-of-order talk) is rejected by QuestService's
	# ordered cursor — and the branch effect must NOT leak onto the run.
	var gc := _make_game()
	var run: RunContext = gc.call("new_run", TEST_SEED)
	var before_corruption: int = run.corruption
	var ow := _make_overworld(gc)
	ow.call("_on_dialogue_choice", "old_garran", "accept")
	assert_bool(bool(ow.call("quest_done", QUEST_ID))).is_false()
	assert_bool(run.flags.has("took_the_shortcut")).is_false()
	assert_int(run.corruption).is_equal(before_corruption)
	ow.queue_free()
	gc.queue_free()


func test_unknown_branch_tag_is_ignored() -> void:
	var gc := _make_game()
	gc.call("new_run", TEST_SEED)
	var ow := _make_overworld(gc)
	ow.call("speak_to", 6)
	ow.call("_on_dialogue_choice", "old_garran", "no_such_branch")
	assert_bool(bool(ow.call("quest_done", QUEST_ID))).is_false()
	ow.queue_free()
	gc.queue_free()
