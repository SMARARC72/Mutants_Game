extends GdUnitTestSuite
## Wave 17 · C16 — battle SPOILS through the loot path, driven HEADLESSLY.
##   * gear drops are DETERMINISTIC per (run.seed, step) — the CanonicalRNG sub-stream contract;
##   * the schedule is occasional (some steps drop, most do not) and draws only field rarities;
##   * apply_battle_result credits the drop into the run inventory + flags it, and pays drachma
##     per defeated enemy on a WIN; a loss/flee pays nothing and drops nothing.

const GameControllerScript := preload("res://application/game/game_controller.gd")
const FakeDalScript := preload("res://infrastructure/dal/fake_dal.gd")
const LootDropServiceScript := preload("res://application/game/loot_drop_service.gd")
const GearCatalogScript := preload("res://infrastructure/catalog/gear_catalog.gd")

const TEST_SEED := 0xD209_51E7


func _make_game() -> Node:
	var gc: Node = GameControllerScript.new()
	add_child(gc)
	gc.call("configure", FakeDalScript.make())
	gc.call("new_run", TEST_SEED)
	return gc


func test_drop_roll_is_deterministic_and_occasional() -> void:
	var catalog: GearCatalog = GearCatalogScript.new()
	var drops := 0
	var blanks := 0
	for step in range(1, 81):
		var a := LootDropServiceScript.roll_drop(TEST_SEED, step, catalog)
		var b := LootDropServiceScript.roll_drop(TEST_SEED, step, catalog)
		assert_str(a).is_equal(b)  # same (seed, step) => same answer, always
		if a == "":
			blanks += 1
		else:
			drops += 1
			assert_bool(catalog.has(a)).is_true()
			# Only field-plausible rarities drop from wild fights (Mythic stays behind bosses).
			var rarity := str(catalog.get_by_id(a).get("rarity", ""))
			assert_bool(LootDropServiceScript.DROP_RARITIES.has(rarity)).is_true()
	assert_int(drops).is_greater(0)  # occasional — but real
	assert_int(blanks).is_greater(drops)  # ...and rationed (most victories pay coin, not gear)


func test_winning_battle_credits_drop_and_drachma() -> void:
	var gc := _make_game()
	var run: RunContext = gc.call("run")
	var catalog: GearCatalog = gc.call("gear_catalog")
	# Find a step whose canonical roll DROPS (deterministic, so the test is stable).
	var drop_step := -1
	for step in range(1, 200):
		if LootDropServiceScript.roll_drop(TEST_SEED, step, catalog) != "":
			drop_step = step
			break
	assert_int(drop_step).is_greater(0)
	run.world_state["steps"] = drop_step
	var expected := LootDropServiceScript.roll_drop(TEST_SEED, drop_step, catalog)

	gc.call("apply_battle_result", {"player_won": true, "enemy_defeated": 2, "xp": 24})
	# The drop landed in the run drawer + the flag; drachma paid per defeated enemy.
	var inv: InventoryAdapter = gc.call("inventory")
	assert_int(inv.count("gear", expected)).is_equal(1)
	assert_str(str(run.flags.get("last_gear_drop", ""))).is_equal(expected)
	assert_int(run.drachma).is_equal(LootDropServiceScript.DRACHMA_PER_DEFEAT * 2)
	gc.queue_free()


func test_loss_and_flee_pay_no_spoils() -> void:
	var gc := _make_game()
	var run: RunContext = gc.call("run")
	gc.call("apply_battle_result", {"player_won": false, "enemy_defeated": 1, "xp": 0})
	assert_int(run.drachma).is_equal(0)
	assert_bool(run.flags.has("last_gear_drop")).is_false()
	(
		gc
		. call(
			"apply_battle_result",
			{"player_won": false, "winner": "fled", "enemy_defeated": 0, "xp": 0},
		)
	)
	assert_int(run.drachma).is_equal(0)
	gc.queue_free()


func test_drachma_for_reads_only_the_result() -> void:
	(
		assert_int(LootDropServiceScript.drachma_for({"player_won": true, "enemy_defeated": 3}))
		. is_equal(LootDropServiceScript.DRACHMA_PER_DEFEAT * 3)
	)
	(
		assert_int(LootDropServiceScript.drachma_for({"player_won": false, "enemy_defeated": 3}))
		. is_equal(0)
	)
