extends GdUnitTestSuite
## Wave 16b — PECULIAR encounters (the content side of the W13 seam), headless.
##   * every PECULIAR_DEFS def is well-formed: its timeline(s) are registered in the
##     [dialogic] dtl_directory, parse, and every speaking character resolves to a .dch;
##   * pick_peculiar is a PURE function of the roll (same roll => same beat) and all four
##     authored beats are reachable;
##   * the Conscientious Objector lands in run.party through the existing capture shape and
##     the peculiar path never stashes a pending battle;
##   * Dree's cursed trinket lands in run.inventory and arms the deterministic step-count
##     "the bag screams, briefly" follow-up, which fires on schedule and re-arms;
##   * the Greenwatcher omen goes corruption-reactive past its threshold;
##   * the fourth-wall registry (tension 11) latches each crack exactly ONCE per run —
##     Cessil's rare variant fires once then falls back to the omen; the signpost knows the
##     save's name once; the menu tagline is a pure function of the run identity.

const GameControllerScript := preload("res://application/game/game_controller.gd")
const FakeDalScript := preload("res://infrastructure/dal/fake_dal.gd")
const OverworldScreenScript := preload("res://presentation/overworld/overworld_screen.gd")
const OverworldPeculiarsScript := preload("res://presentation/overworld/overworld_peculiars.gd")
const FourthWallScript := preload("res://presentation/narrative/fourth_wall.gd")

const TEST_SEED := 0x16BC01AE


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


## The first roll (scanning steps deterministically) that pick_peculiar resolves to `id`.
func _roll_for(id: String) -> Dictionary:
	for step in 1000:
		var roll := {"step": step, "battle_seed": 7}
		if str(OverworldContent.pick_peculiar(roll).get("id", "")) == id:
			return roll
	assert_bool(false).override_failure_message("no roll resolves to '%s' in 1000 steps" % id)
	return {}


func test_peculiar_defs_are_well_formed() -> void:
	DialogicFacade.ensure_directories()
	var dtl_dir: Dictionary = DialogicResourceUtil.get_directory("dtl")
	assert_int(OverworldContent.PECULIAR_DEFS.size()).is_greater_equal(4)
	for def: Dictionary in OverworldContent.PECULIAR_DEFS:
		assert_str(str(def.get("id", ""))).is_not_empty()
		for key in ["timeline", "corrupt_timeline"]:
			if not def.has(key):
				continue
			var tid := str(def[key])
			(
				assert_bool(dtl_dir.has(tid))
				. override_failure_message("timeline '%s' is not in dtl_directory" % tid)
				. is_true()
			)
			_assert_timeline_speakers_exist(str(dtl_dir[tid]))


func test_act0_npc_timelines_are_registered() -> void:
	# The W16b cast additions (Act-0 + peculiar speakers) ride the same registration contract
	# as the original ten NPCs: every non-sign NPC timeline resolves through dtl_directory.
	DialogicFacade.ensure_directories()
	var dtl_dir: Dictionary = DialogicResourceUtil.get_directory("dtl")
	for def: Dictionary in OverworldContent.NPC_DEFS:
		var tid := str(def.get("timeline", ""))
		if tid == "":
			assert_bool(bool(def.get("sign", false))).is_true()  # only props stay silent
			continue
		(
			assert_bool(dtl_dir.has(tid))
			. override_failure_message("NPC timeline '%s' is not in dtl_directory" % tid)
			. is_true()
		)
		_assert_timeline_speakers_exist(str(dtl_dir[tid]))


func _assert_timeline_speakers_exist(path: String) -> void:
	var timeline: DialogicTimeline = load(path)
	assert_object(timeline).override_failure_message("timeline missing at %s" % path).is_not_null()
	timeline.process()
	assert_int(timeline.events.size()).is_greater(0)
	for event: Variant in timeline.events:
		if event is DialogicTextEvent:
			var ident := str((event as DialogicTextEvent).character_identifier)
			if ident != "":
				(
					assert_object(DialogicResourceUtil.get_character_resource(ident))
					. override_failure_message("speaker '%s' (%s) has no .dch" % [ident, path])
					. is_not_null()
				)


func test_pick_peculiar_is_deterministic_and_every_beat_is_reachable() -> void:
	var seen := {}
	for step in 240:
		var roll := {"step": step, "battle_seed": 12345}
		var a: Dictionary = OverworldContent.pick_peculiar(roll)
		var b: Dictionary = OverworldContent.pick_peculiar(roll)
		assert_str(str(a.get("id", ""))).is_equal(str(b.get("id", "")))
		seen[str(a.get("id", ""))] = true
	for id in [
		"conscientious_objector", "dree_cursed_trinket", "greenwatcher_omen", "cessil_reading"
	]:
		assert_bool(seen.has(id)).override_failure_message("beat '%s' unreachable" % id).is_true()


func test_cessil_crack_is_rationed_to_one_per_run() -> void:
	var gc := _make_game()
	var run: RunContext = gc.call("new_run", TEST_SEED)
	var roll := _roll_for("cessil_reading")
	var first: Dictionary = OverworldPeculiarsScript.resolve_def(roll, run)
	assert_str(str(first.get("id", ""))).is_equal("cessil_reading")
	assert_bool(FourthWallScript.seen(run, "cessil")).is_true()
	# Every later rare pick falls back to the omen beat — the wall breaks once per run.
	var second: Dictionary = OverworldPeculiarsScript.resolve_def(roll, run)
	assert_str(str(second.get("id", ""))).is_equal("greenwatcher_omen")
	gc.queue_free()


func test_objector_joins_the_coven_and_never_starts_a_battle() -> void:
	var gc := _make_game()
	var run: RunContext = gc.call("new_run", TEST_SEED)
	var ow := _make_overworld(gc)
	var before := run.party.size()
	var result: Dictionary = OverworldPeculiarsScript.play(ow, _roll_for("conscientious_objector"))
	assert_str(str(result.get("timeline", ""))).is_equal("peculiar_objector")
	assert_str(str(result.get("joined", ""))).is_equal("SB22")
	assert_int(run.party.size()).is_equal(before + 1)
	var newcomer: Dictionary = run.party.back()
	assert_str(str(newcomer.get("species_id", ""))).is_equal("SB22")
	assert_str(str(newcomer.get("nickname", ""))).is_equal("The Objector")
	# The peculiar path NEVER hands off to the battle scene (no pending battle stashed).
	assert_bool(run.flags.has("pending_battle")).is_false()
	ow.queue_free()
	gc.queue_free()


func test_dree_trinket_lands_in_the_bag_and_screams_on_schedule() -> void:
	var gc := _make_game()
	var run: RunContext = gc.call("new_run", TEST_SEED)
	var ow := _make_overworld(gc)
	var result: Dictionary = OverworldPeculiarsScript.play(ow, _roll_for("dree_cursed_trinket"))
	assert_str(str(result.get("item", ""))).is_equal("dree_cursed_trinket")
	var inventory: InventoryAdapter = gc.call("inventory")
	assert_int(inventory.count("key", "dree_cursed_trinket")).is_equal(1)
	var interval := int(OverworldContent.peculiar_def("dree_cursed_trinket").get("interval", 0))
	assert_int(interval).is_greater(0)
	var due := int(run.world_state.get(OverworldPeculiarsScript.SCREAM_AT_KEY, -1))
	assert_int(due).is_equal(int(gc.call("current_step")) + interval)
	# Silent before the due step; fires ON it; re-arms exactly one interval out (deterministic).
	assert_str(OverworldPeculiarsScript.tick_bag_scream(run, due - 1, null)).is_equal("")
	var line := OverworldPeculiarsScript.tick_bag_scream(run, due, null)
	assert_str(line).is_not_empty()
	assert_str(line).is_equal(VoiceBook.pick("shop.cursed", due))
	var next_due := int(run.world_state.get(OverworldPeculiarsScript.SCREAM_AT_KEY, -1))
	assert_int(next_due).is_equal(due + interval)
	ow.queue_free()
	gc.queue_free()


func test_omen_flags_the_witness_and_goes_corrupt_past_the_threshold() -> void:
	var gc := _make_game()
	var run: RunContext = gc.call("new_run", TEST_SEED)
	var ow := _make_overworld(gc)
	var roll := _roll_for("greenwatcher_omen")
	var plain: Dictionary = OverworldPeculiarsScript.play(ow, roll)
	assert_str(str(plain.get("timeline", ""))).is_equal("peculiar_omen")
	assert_bool(bool(run.flags.get("greenwatcher_omen_seen", false))).is_true()
	# Once the rot shows, the SAME roll reads the run back through the corrupt variant.
	run.corruption = int(
		OverworldContent.peculiar_def("greenwatcher_omen").get("corrupt_threshold", 2)
	)
	var corrupt: Dictionary = OverworldPeculiarsScript.play(ow, roll)
	assert_str(str(corrupt.get("timeline", ""))).is_equal("peculiar_omen_corrupt")
	ow.queue_free()
	gc.queue_free()


func test_fourth_wall_cracks_latch_once_and_ride_world_state() -> void:
	var gc := _make_game()
	var run: RunContext = gc.call("new_run", TEST_SEED)
	assert_bool(FourthWallScript.latch(run, "signpost")).is_true()
	assert_bool(FourthWallScript.latch(run, "signpost")).is_false()  # the ration holds
	assert_bool(FourthWallScript.seen(run, "signpost")).is_true()
	var cracks: Dictionary = run.world_state.get(FourthWallScript.CRACKS_KEY, {})
	assert_bool(bool(cracks.get("signpost", false))).is_true()  # JSON-safe -> rides the save
	gc.queue_free()


func test_signpost_line_names_the_save_and_speaks_once() -> void:
	var gc := _make_game()
	var run: RunContext = gc.call("new_run", TEST_SEED)
	var line := FourthWallScript.signpost_line(run)
	assert_str(line).contains(str(run.run_id))  # it KNOWS it's you
	assert_bool(line.contains("{save}")).is_false()  # placeholder interpolated, never raw
	assert_str(FourthWallScript.signpost_line(run)).is_equal("")  # said everything it knows
	gc.queue_free()


func test_menu_tagline_is_a_pure_function_of_the_run_identity() -> void:
	# No game / no run identity: fresh installs never flicker (the wall stays rationed).
	assert_str(FourthWallScript.menu_tagline(null)).is_equal("")
	var gc := _make_game()
	gc.call("new_run", TEST_SEED)
	var first := FourthWallScript.menu_tagline(gc)
	assert_str(FourthWallScript.menu_tagline(gc)).is_equal(first)  # same run, same menu
	gc.queue_free()
