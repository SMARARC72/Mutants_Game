extends GdUnitTestSuite
## W-DRESS "quest markers" — the floating brass markers over the cast, driven from the LIVE
## QuestService state, headless:
##   * KIND mapping is pure and mirrors the screen's dispatch: an NPC driving a start-able
##     quest's first step pulses AVAILABLE (star); the step that would COMPLETE the quest
##     right now shows the hollow TURN-IN ring; done quests / wrong-order steps show nothing;
##   * Act-0 trigger gating holds (no marker before the gating flag exists);
##   * the built overworld hangs real marker nodes off the NPCs and clears them as quests
##     advance (refresh rides quest transitions + dialogue-finished, never mid-scene);
##   * the boss-lair altar carries the ember glow while the boss-goal quest is live.

const GameControllerScript := preload("res://application/game/game_controller.gd")
const FakeDalScript := preload("res://infrastructure/dal/fake_dal.gd")
const OverworldScreenScript := preload("res://presentation/overworld/overworld_screen.gd")
const QuestMarkersScript := preload("res://presentation/overworld/quest_markers.gd")

const TEST_SEED := 0x0CEA_2026


func _quests() -> QuestService:
	var qs := QuestService.new()
	qs.register(OverworldContent.quest_defs())
	return qs


func _def_named(wanted: String) -> Dictionary:
	for def: Dictionary in OverworldContent.NPC_DEFS:
		if str(def["name"]) == wanted:
			return def
	return {}


func test_kind_follows_the_marsh_quest_lifecycle() -> void:
	var qs := _quests()
	var marrow := _def_named("Old Marrow")
	var wretch := _def_named("Bog-Wretch")
	# Fresh run: Marrow can START the quest (first step) — star; the Wretch's step is second
	# in line, so talking to it first would advance nothing: no marker.
	assert_str(QuestMarkersScript.kind_for(marrow, qs)).is_equal(QuestMarkersScript.KIND_AVAILABLE)
	assert_str(QuestMarkersScript.kind_for(wretch, qs)).is_equal(QuestMarkersScript.KIND_NONE)
	# After Marrow: the cursor sits on meet_wretch — the LAST step — the Wretch shows the
	# turn-in ring and Marrow goes quiet.
	qs.start("marsh_welcome")
	qs.advance("marsh_welcome", "hear_marrow")
	assert_str(QuestMarkersScript.kind_for(marrow, qs)).is_equal(QuestMarkersScript.KIND_NONE)
	assert_str(QuestMarkersScript.kind_for(wretch, qs)).is_equal(QuestMarkersScript.KIND_TURNIN)
	# Quest done: everyone goes quiet.
	qs.advance("marsh_welcome", "meet_wretch")
	assert_bool(qs.is_done("marsh_welcome")).is_true()
	assert_str(QuestMarkersScript.kind_for(marrow, qs)).is_equal(QuestMarkersScript.KIND_NONE)
	assert_str(QuestMarkersScript.kind_for(wretch, qs)).is_equal(QuestMarkersScript.KIND_NONE)


func test_act0_trigger_gates_the_marker() -> void:
	var qs := _quests()
	var veil := _def_named("Surgeon-Lab-Tech Veil")
	# Altar Hours is gated behind capture_unlocked: no marker before the flag exists.
	assert_str(QuestMarkersScript.kind_for(veil, qs)).is_equal(QuestMarkersScript.KIND_NONE)
	qs.run_state().set_flag("capture_unlocked", true)
	# Its single step both starts AND completes the quest — the ring, not the star.
	assert_str(QuestMarkersScript.kind_for(veil, qs)).is_equal(QuestMarkersScript.KIND_TURNIN)


func test_choice_npcs_earn_markers_through_their_choice_config() -> void:
	var qs := _quests()
	var garran := _def_named("Old Garran")
	# SQ-05 not started: Garran drives answer_garran (step 2) — nothing yet.
	assert_str(QuestMarkersScript.kind_for(garran, qs)).is_equal(QuestMarkersScript.KIND_NONE)
	qs.start("six_petals_true_bred")
	qs.advance("six_petals_true_bred", "tend_with_ona")
	# Now his choice-driven step is the live cursor AND the finisher: the turn-in ring.
	assert_str(QuestMarkersScript.kind_for(garran, qs)).is_equal(QuestMarkersScript.KIND_TURNIN)


func test_signpost_never_carries_a_marker() -> void:
	var qs := _quests()
	assert_str(QuestMarkersScript.kind_for(_def_named("Weathered Signpost"), qs)).is_equal(
		QuestMarkersScript.KIND_NONE
	)


func test_overworld_hangs_markers_and_clears_them_on_advance() -> void:
	var gc: Node = GameControllerScript.new()
	add_child(gc)
	gc.call("configure", FakeDalScript.make())
	gc.call("new_run", TEST_SEED)
	var ow: Node2D = OverworldScreenScript.new()
	ow.call("set_game", gc)
	ow.call("set_auto_hand_off", false)
	add_child(ow)
	ow.call("build_from_game")
	var world := ow.call("world_root") as Node2D
	var marrow_node := world.find_child("NPC_OldMarrow", false, false) as Node2D
	assert_object(marrow_node).is_not_null()
	var marker := marrow_node.get_node_or_null("QuestMarker") as Sprite2D
	assert_object(marker).is_not_null()
	assert_str(str(marker.get_meta("kind", ""))).is_equal(QuestMarkersScript.KIND_AVAILABLE)
	assert_object(marker.texture).is_not_null()
	# Speak to Old Marrow (index 0; headless resolves the scene instantly): the quest advances,
	# dialogue finishes, and the deferred marker sync moves the marker down the chain.
	ow.call("speak_to", 0)
	assert_bool(bool(ow.call("quest_active", "marsh_welcome"))).is_true()
	assert_object(marrow_node.get_node_or_null("QuestMarker")).is_null()
	var wretch_node := world.find_child("NPC_Bog-Wretch", false, false) as Node2D
	assert_object(wretch_node).is_not_null()
	var ring := wretch_node.get_node_or_null("QuestMarker") as Sprite2D
	assert_object(ring).is_not_null()
	assert_str(str(ring.get_meta("kind", ""))).is_equal(QuestMarkersScript.KIND_TURNIN)
	ow.queue_free()
	gc.queue_free()


func test_boss_lair_carries_the_ember_while_the_goal_is_live() -> void:
	var gc: Node = GameControllerScript.new()
	add_child(gc)
	gc.call("configure", FakeDalScript.make())
	gc.call("new_run", TEST_SEED)
	var ow: Node2D = OverworldScreenScript.new()
	ow.call("set_game", gc)
	ow.call("set_auto_hand_off", false)
	add_child(ow)
	ow.call("build_from_game")
	# The boss-goal quest auto-starts on build, and the lair altar is planned for this region.
	assert_bool(bool(ow.call("quest_active", "what_guards_the_deep"))).is_true()
	var kit: OverworldStructures = ow.call("structures")
	var lair: Dictionary = kit.lair()
	assert_bool(lair.is_empty()).is_false()
	var lair_node := lair.get("node") as Node2D
	assert_object(lair_node).is_not_null()
	assert_object(lair_node.get_node_or_null("LairEmber")).is_not_null()
	ow.queue_free()
	gc.queue_free()
