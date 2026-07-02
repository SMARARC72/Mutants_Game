extends GdUnitTestSuite
## Batch E1c — NPC SPAWN FROM THE CATALOG for a NON-VERDANT region, headless:
##   * the overworld builds a pantheon region (mournmarch) and populates it from
##     npc_casts.json (leader first, then Hands, then the living-world cast);
##   * every spawned token is a catalog def (name/ring/timeline carried onto the entry);
##   * speaking to a cast NPC whose generated timeline has not landed yet bubbles its
##     AUTHORED bark (the talk counts in world_state) instead of playing a missing scene;
##   * verdant keeps its hand-wired cast (regression pin).
## Drives a CODE-INSTANTIATED GameController + overworld screen with an injected FakeDal.

const GameControllerScript := preload("res://application/game/game_controller.gd")
const FakeDalScript := preload("res://infrastructure/dal/fake_dal.gd")
const OverworldScreenScript := preload("res://presentation/overworld/overworld_screen.gd")

const TEST_SEED := 0xCA57_2026
const REGION := "mournmarch"


func _make_game(region: String) -> Node:
	var gc: Node = GameControllerScript.new()
	add_child(gc)
	gc.call("configure", FakeDalScript.make())
	var run: RunContext = gc.call("new_run", TEST_SEED)
	run.world_state["active_region"] = region
	return gc


func _make_overworld(game: Node) -> Node2D:
	var ow: Node2D = OverworldScreenScript.new()
	ow.call("set_game", game)
	ow.call("set_auto_hand_off", false)
	add_child(ow)
	ow.call("build_from_game")
	return ow


func test_non_verdant_region_spawns_the_catalog_cast() -> void:
	var gc := _make_game(REGION)
	var ow := _make_overworld(gc)
	var count := int(ow.call("npc_count"))
	assert_int(count).is_greater(0)
	var catalog_names: Array = []
	for def: Dictionary in NpcCastCatalog.defs_for_region(REGION):
		catalog_names.append(str(def["name"]))
	var npcs: Array = ow.get("_npcs")
	assert_int(npcs.size()).is_equal(count)
	for npc: Dictionary in npcs:
		(
			assert_bool(catalog_names.has(str(npc["name"])))
			. override_failure_message(
				"spawned NPC %s is not in the %s catalog cast" % [str(npc["name"]), REGION]
			)
			. is_true()
		)
		assert_bool(bool(npc.get("cast", false))).is_true()
		assert_bool(npc["ring"] is Color).is_true()
	# The def order holds: the faction leader anchors the cast.
	assert_str(str((npcs[0] as Dictionary)["name"])).is_equal(
		"The Pale Steward, Wessel Graf von Underhart"
	)
	ow.queue_free()
	gc.queue_free()


func test_speaking_to_a_cast_npc_bubbles_its_authored_bark() -> void:
	var gc := _make_game(REGION)
	var ow := _make_overworld(gc)
	assert_int(int(ow.call("npc_count"))).is_greater(0)
	var npcs: Array = ow.get("_npcs")
	var npc: Dictionary = npcs[0]
	# The generated timeline has not landed yet (E1a builds them in parallel) — the talk
	# returns the CONVENTION id and falls back to the authored bark, counting the visit.
	var returned := str(ow.call("speak_to", 0))
	assert_str(returned).is_equal(str(npc["timeline"]))
	var run: RunContext = gc.call("run")
	var talks: Dictionary = run.world_state.get("npc_talks", {})
	assert_int(int(talks.get(str(npc["name"]), 0))).is_equal(1)
	# A second talk keeps counting (the bark walk is deterministic per visit).
	ow.call("speak_to", 0)
	talks = run.world_state.get("npc_talks", {})
	assert_int(int(talks.get(str(npc["name"]), 0))).is_equal(2)
	ow.queue_free()
	gc.queue_free()


func test_verdant_keeps_its_hand_wired_cast() -> void:
	var gc := _make_game("verdant_glut")
	var ow := _make_overworld(gc)
	var npcs: Array = ow.get("_npcs")
	assert_bool(npcs.is_empty()).is_false()
	assert_str(str((npcs[0] as Dictionary)["name"])).is_equal("Old Marrow")
	for npc: Dictionary in npcs:
		assert_bool(bool(npc.get("cast", false))).is_false()
	ow.queue_free()
	gc.queue_free()
