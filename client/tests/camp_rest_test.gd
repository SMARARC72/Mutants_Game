extends GdUnitTestSuite
## Wave 18 "Camp Becomes a Camp" — Rest + the currency strip + Save & Quit, headless.
##   * GameController.rest_at_camp heals every persisted wound to its ceiling, clears the
##     "scarred" mark, and debits the essence fee (insufficient essence -> no-op refusal);
##   * the camp menu builds the Rest / Save & Quit verbs and the drachma/essence/ichor strip;
##   * menu Rest drives the controller and refreshes the essence readout;
##   * Save & Quit targets the title scene through the witnessed save path.

const GameControllerScript := preload("res://application/game/game_controller.gd")
const FakeDalScript := preload("res://infrastructure/dal/fake_dal.gd")
const CampMenuScript := preload("res://presentation/camp/camp_menu.gd")

const TEST_SEED := 0xCA3B


func _make_game() -> Node:
	var gc: Node = GameControllerScript.new()
	add_child(gc)
	gc.call("configure", FakeDalScript.make())
	gc.call("new_run", TEST_SEED)
	return gc


func _make_menu(gc: Node) -> Control:
	var menu: Control = CampMenuScript.new()
	menu.call("set_auto_navigate", false)
	menu.call("set_game", gc)
	add_child(menu)
	return menu


func test_rest_heals_wounds_clears_scars_and_debits_essence() -> void:
	var gc := _make_game()
	var run: RunContext = gc.call("run")
	run.essence = 50
	var wounded: Dictionary = run.party[0]
	wounded["hp"] = 3
	wounded["max_hp"] = 20
	wounded["scarred"] = true
	var report: Dictionary = gc.call("rest_at_camp")
	assert_bool(bool(report["ok"])).is_true()
	assert_int(int(report["healed"])).is_greater_equal(1)
	assert_int(int(wounded["hp"])).is_equal(20)
	assert_bool(wounded.has("scarred")).is_false()
	assert_int(run.essence).is_equal(50 - GameControllerScript.REST_ESSENCE_FEE)
	gc.queue_free()


func test_rest_refuses_without_the_essence_fee() -> void:
	var gc := _make_game()
	var run: RunContext = gc.call("run")
	run.essence = GameControllerScript.REST_ESSENCE_FEE - 1
	var wounded: Dictionary = run.party[0]
	wounded["hp"] = 2
	wounded["max_hp"] = 20
	var report: Dictionary = gc.call("rest_at_camp")
	assert_bool(bool(report["ok"])).is_false()
	assert_str(str(report["reason"])).is_equal("essence")
	assert_int(int(wounded["hp"])).is_equal(2)  # untouched — no free heals
	assert_int(run.essence).is_equal(GameControllerScript.REST_ESSENCE_FEE - 1)
	gc.queue_free()


func test_camp_builds_rest_savequit_and_currency_strip() -> void:
	var gc := _make_game()
	var menu := _make_menu(gc)
	assert_object(menu.find_child("RestButton", true, false)).is_not_null()
	assert_object(menu.find_child("SaveQuitButton", true, false)).is_not_null()
	assert_object(menu.find_child("CurrencyStrip", true, false)).is_not_null()
	for wallet in ["DrachmaValue", "EssenceValue", "IchorValue"]:
		assert_object(menu.find_child(wallet, true, false)).is_not_null()
	menu.queue_free()
	gc.queue_free()


func test_menu_rest_drives_the_controller_and_refreshes_the_strip() -> void:
	var gc := _make_game()
	var run: RunContext = gc.call("run")
	run.essence = 40
	var wounded: Dictionary = run.party[1]
	wounded["hp"] = 5
	wounded["max_hp"] = 22
	var menu := _make_menu(gc)
	var report: Dictionary = menu.call("rest")
	assert_bool(bool(report["ok"])).is_true()
	assert_int(int(wounded["hp"])).is_equal(22)
	var essence_label: Label = menu.find_child("EssenceValue", true, false)
	assert_str(essence_label.text).is_equal(str(40 - GameControllerScript.REST_ESSENCE_FEE))
	menu.queue_free()
	gc.queue_free()


func test_save_and_quit_targets_the_title_scene() -> void:
	var gc := _make_game()
	var menu := _make_menu(gc)
	var target: String = menu.call("save_and_quit")
	assert_str(target).is_equal("res://presentation/screens/main_menu.tscn")
	# The witnessed save landed (the run is continuable after quitting to title).
	assert_bool(bool(gc.call("has_save"))).is_true()
	menu.queue_free()
	gc.queue_free()


func test_heal_voucher_waives_the_essence_fee_and_is_consumed() -> void:
	# Codex #57 P2: the Trader's voucher must WORK — it pays for one rest instead of essence.
	var gc := _make_game()
	var run: RunContext = gc.call("run")
	var inv: InventoryAdapter = gc.call("inventory")
	inv.add("consumable", "camp_heal_voucher", 1)
	(run.party[0] as Dictionary)["hp"] = 1
	(run.party[0] as Dictionary)["max_hp"] = 20
	var essence_before: int = run.essence
	var report: Dictionary = gc.call("rest_at_camp")
	assert_bool(bool(report.get("ok", false))).is_true()
	assert_int(run.essence).is_equal(essence_before)  # fee waived
	assert_int(inv.count("consumable", "camp_heal_voucher")).is_equal(0)  # consumed
	assert_int(int((run.party[0] as Dictionary).get("hp", 0))).is_equal(20)
	gc.queue_free()


func test_save_ordinal_round_trips_through_the_envelope() -> void:
	# Codex #57 P2: the ordinal must be read from the RUN payload — a fresh save's ordinal
	# parses as a positive number (not the silent -1 mtime fallback).
	var gc := _make_game()
	assert_bool(bool(gc.call("save_run"))).is_true()
	var path: String = gc.call("_latest_save_path")
	assert_str(path).is_not_empty()
	assert_int(int(gc.call("_save_ordinal_of", path))).is_greater(0)
	gc.queue_free()
