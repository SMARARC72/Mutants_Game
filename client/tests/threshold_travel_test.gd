extends GdUnitTestSuite
## E1b "Eleven Regions" — the THRESHOLD NETWORK (ritual-circle fast travel), headless.
##   * unlock GATING: verdant + threshold are always open; a gated region refuses travel until
##     its story flag lands in run.flags (or a quest unlocked it directly);
##   * TRAVEL switches run.world_state.active_region, the overworld rebuilds through the EXISTING
##     WorldGenerator path (layouts persist PER REGION — a return trip rehydrates, never
##     re-solves), and the tamer stands at the new region's canonical spawn;
##   * a LOCKED region refuses and the run does not move;
##   * every region raises a WAYGATE structure (the travel interactable) and the overlay lists
##     all eleven regions with an honest lock state;
##   * arriving somewhere new NEVER inherits the global step count as instant boss-bait (the
##     per-region explored ledger starts at zero).

const GameControllerScript := preload("res://application/game/game_controller.gd")
const FakeDalScript := preload("res://infrastructure/dal/fake_dal.gd")
const OverworldScreenScript := preload("res://presentation/overworld/overworld_screen.gd")
const OverworldStructuresScript := preload("res://presentation/overworld/overworld_structures.gd")
const OverworldSpawnScript := preload("res://presentation/overworld/overworld_spawn.gd")
const WorldGeneratorScript := preload("res://infrastructure/worldgen/world_generator.gd")
const RegionCatalogScript := preload("res://application/overworld/region_catalog.gd")
const RegionTravelScript := preload("res://application/overworld/region_travel.gd")

const TEST_SEED := 0x7247_0E1B


func _make_game() -> Node:
	var gc: Node = GameControllerScript.new()
	add_child(gc)
	gc.call("configure", FakeDalScript.make())
	return gc


func _make_overworld(game: Node) -> Node2D:
	var ow: Node2D = OverworldScreenScript.new()
	ow.call("set_game", game)
	ow.call("set_auto_hand_off", false)
	ow.call("set_camp_enabled", false)
	add_child(ow)
	ow.call("build_from_game")
	return ow


func test_gating_verdant_and_threshold_open_the_rest_sealed() -> void:
	var gc := _make_game()
	var run: RunContext = gc.call("new_run", TEST_SEED)
	assert_bool(RegionTravelScript.unlocked(run, "verdant_glut")).is_true()
	assert_bool(RegionTravelScript.unlocked(run, "threshold")).is_true()
	assert_bool(RegionTravelScript.unlocked(run, "mournmarch")).is_false()
	assert_bool(RegionTravelScript.unlocked(run, "maw_beneath")).is_false()
	assert_bool(RegionTravelScript.unlocked(run, "nowhere_at_all")).is_false()
	# The act gate flag opens its regions; a direct quest unlock opens one region alone.
	run.flags["registered_aspirant"] = true
	assert_bool(RegionTravelScript.unlocked(run, "mournmarch")).is_true()
	assert_bool(RegionTravelScript.unlocked(run, "forgefell")).is_true()
	assert_bool(RegionTravelScript.unlocked(run, "storm_vault")).is_false()
	assert_bool(RegionTravelScript.unlock(run, "storm_vault")).is_true()
	assert_bool(RegionTravelScript.unlock(run, "nowhere_at_all")).is_false()
	assert_bool(RegionTravelScript.unlocked(run, "storm_vault")).is_true()
	gc.queue_free()


func test_locked_region_refuses_travel_and_run_stays_put() -> void:
	var gc := _make_game()
	var run: RunContext = gc.call("new_run", TEST_SEED)
	assert_bool(RegionTravelScript.travel(run, "mournmarch")).is_false()
	assert_bool(RegionTravelScript.travel(run, "nowhere_at_all")).is_false()
	assert_str(str(gc.call("active_region"))).is_equal("verdant_glut")
	# Traveling to where you already stand is a refusal too (the overlay disables the row).
	assert_bool(RegionTravelScript.travel(run, "verdant_glut")).is_false()
	gc.queue_free()


func test_travel_switches_region_and_layouts_persist_per_region() -> void:
	var gc := _make_game()
	var run: RunContext = gc.call("new_run", TEST_SEED)
	var ow := _make_overworld(gc)
	var verdant_layout: Layout = ow.call("layout")

	# Every region raises the waygate (the ritual circle the INTERACT verb opens).
	var structures: OverworldStructures = ow.call("structures")
	assert_bool(structures.waygate().is_empty()).is_false()

	# Ride the circle to the hub (always open) through the overlay itself.
	var screen: Node = ow.call("open_threshold")
	assert_object(screen).is_not_null()
	assert_bool(bool(screen.call("travel", "threshold"))).is_true()

	assert_str(str(gc.call("active_region"))).is_equal("threshold")
	var hub_layout: Layout = ow.call("layout")
	assert_str(hub_layout.region_id).is_equal("threshold")
	# Both layouts persist per region id in world_state (generate-once, keyed by region).
	var layouts: Dictionary = run.world_state.get(WorldGeneratorScript.WORLD_STATE_KEY, {})
	assert_bool(layouts.has("verdant_glut")).is_true()
	assert_bool(layouts.has("threshold")).is_true()
	# The tamer stands at the NEW region's canonical spawn (the stale stash never leaks across).
	var spawn: Vector2i = OverworldSpawnScript.spawn_cell(hub_layout)
	assert_that(ow.call("player_cell")).is_equal(spawn)

	# The return trip REHYDRATES the persisted verdant grid (never a re-solve).
	var back: Node = ow.call("open_threshold")
	assert_bool(bool(back.call("travel", "verdant_glut"))).is_true()
	var again: Layout = ow.call("layout")
	assert_bool(verdant_layout.tiles_equal(again)).is_true()
	ow.queue_free()
	gc.queue_free()


func test_overlay_lists_all_regions_with_honest_lock_state() -> void:
	var gc := _make_game()
	gc.call("new_run", TEST_SEED)
	var ow := _make_overworld(gc)
	var screen: Node = ow.call("open_threshold")
	var rows: Array = screen.call("regions")
	assert_int(rows.size()).is_equal(RegionCatalogScript.region_ids().size())
	var by_id := {}
	for row: Dictionary in rows:
		by_id[str(row["id"])] = row
	assert_bool(bool((by_id["verdant_glut"] as Dictionary)["here"])).is_true()
	assert_bool(bool((by_id["threshold"] as Dictionary)["unlocked"])).is_true()
	assert_bool(bool((by_id["mournmarch"] as Dictionary)["unlocked"])).is_false()
	# A sealed region's travel is refused through the overlay too; the run stays put.
	assert_bool(bool(screen.call("travel", "mournmarch"))).is_false()
	assert_str(str(gc.call("active_region"))).is_equal("verdant_glut")
	screen.call("close")
	ow.queue_free()
	gc.queue_free()


func test_arrival_starts_the_boss_ledger_at_zero() -> void:
	var gc := _make_game()
	var run: RunContext = gc.call("new_run", TEST_SEED)
	var ow := _make_overworld(gc)
	# Walk the global counter well past every region's boss threshold.
	for i in 60:
		gc.call("advance_step")
	assert_int(int(gc.call("current_step"))).is_equal(60)
	assert_int(RegionTravelScript.explored_steps(run, "verdant_glut")).is_equal(60)
	var screen: Node = ow.call("open_threshold")
	assert_bool(bool(screen.call("travel", "threshold"))).is_true()
	# The hub's explored ledger starts fresh — the climax cannot fire off the global count.
	assert_int(RegionTravelScript.explored_steps(run, "threshold")).is_equal(0)
	var layout: Layout = ow.call("layout")
	var spawn: Vector2i = ow.call("player_cell")
	var moved := false
	for dir: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
		var res: Dictionary = ow.call("try_move", dir)
		if bool(res.get("moved", false)):
			moved = true
			assert_bool(bool(res.get("boss", false))).is_false()
			break
	assert_bool(moved).is_true()
	assert_object(layout).is_not_null()
	assert_bool(spawn.x >= 0 and spawn.y >= 0).is_true()
	# LEGACY EQUIVALENCE: a pre-E1b save carries no ledger — the whole global count reads as the
	# ACTIVE region's exploration (the only region a pre-travel save ever walked), and the first
	# tick backfills the ledger from it, so a resumed run keeps its climax progress exactly.
	var global_steps := int(gc.call("current_step"))
	run.world_state.erase("region_steps")
	assert_int(RegionTravelScript.explored_steps(run, "threshold")).is_equal(global_steps)
	assert_int(RegionTravelScript.explored_steps(run, "verdant_glut")).is_equal(0)
	gc.call("advance_step")
	assert_int(RegionTravelScript.explored_steps(run, "threshold")).is_equal(global_steps + 1)
	ow.queue_free()
	gc.queue_free()


func test_legacy_saves_seed_the_ledger_on_the_origin_not_the_destination() -> void:
	# Codex #59 P2: a pre-E1b save (global steps, no ledger) travels — the legacy count
	# must land on the ORIGIN region's ledger, never the destination's (which would
	# inherit instant boss-climax progress).
	var gc := _make_game()
	var run: RunContext = gc.call("run")
	run.world_state["steps"] = 40
	run.world_state.erase("region_steps")
	RegionTravelScript.unlock(run, "mournmarch")
	assert_bool(RegionTravelScript.travel(run, "mournmarch")).is_true()
	assert_int(RegionTravelScript.explored_steps(run, "verdant_glut")).is_equal(40)
	assert_int(RegionTravelScript.explored_steps(run, "mournmarch")).is_equal(0)
	gc.queue_free()
