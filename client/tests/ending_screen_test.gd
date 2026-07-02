extends GdUnitTestSuite
## Batch E2b — the ENDING SCREEN + its gate + the closed-ledger Continue gate, headless.
##   * begin() resolves the run's ending, latches it into run.flags, and builds the page
##     (name / epigraph / 5-row ledger / "The record closes.") with no awaits (instant mode);
##   * EndingGate fires EXACTLY once: finale flag up + no latched ending -> a UiRouter push;
##     the latch stops every later check;
##   * a saved closed ledger reads continue_health() == "closed" and the main menu answers
##     "This ledger is closed — begin anew?" instead of reloading the record;
##   * the character sheet's "The path of ..." preview tracks the same resolver.

const GameControllerScript := preload("res://application/game/game_controller.gd")
const FakeDalScript := preload("res://infrastructure/dal/fake_dal.gd")
const EndingScreenScript := preload("res://presentation/endings/ending_screen.gd")
const EndingGateScript := preload("res://presentation/endings/ending_gate.gd")
const MainMenuScript := preload("res://presentation/screens/main_menu.gd")
const CharacterSheetScript := preload("res://presentation/character/character_sheet.gd")
const SaveEnvelopeScript := preload("res://application/persistence/save_envelope.gd")

const TEST_SEED := 0xE2B


func after_test() -> void:
	# Never leak overlays into the next test — the router is a shared autoload.
	var router := get_node_or_null("/root/UiRouter")
	if router != null:
		router.call("pop_all")


func _clear_saves() -> void:
	var dir_path := SaveEnvelopeScript.DEFAULT_DIR
	if not DirAccess.dir_exists_absolute(dir_path):
		return
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".json"):
			dir.remove(entry)
		entry = dir.get_next()
	dir.list_dir_end()


func _make_game() -> Node:
	var gc: Node = GameControllerScript.new()
	add_child(gc)
	gc.call("configure", FakeDalScript.make())
	gc.call("new_run", TEST_SEED)
	return gc


func test_begin_builds_the_page_and_latches_the_ending() -> void:
	var gc := _make_game()
	var run: RunContext = gc.call("run")
	run.order_chaos = -80
	run.purity_corrupt = 80
	run.corruption = 65
	var page: Control = EndingScreenScript.new()
	page.call("set_game", gc)
	add_child(page)
	page.call("set_instant", true)
	var ending: Dictionary = page.call("begin")
	# The Iron Throne cell (Order|Corrupt) — the same cell the character sheet shows.
	assert_str(str(ending.get("id", ""))).is_equal("the_iron_throne")
	assert_str(str(page.call("ending_id"))).is_equal("the_iron_throne")
	assert_str(str(page.call("name_text"))).is_equal("The Iron Throne")
	assert_str(str(page.call("epigraph_text"))).contains("FOR YOUR COMFORT")
	assert_int(int(page.call("ledger_row_count"))).is_equal(5)
	assert_str(str(page.call("closing_text"))).is_equal("The record closes.")
	# The latch: the run's ledger is CLOSED the moment the page begins.
	assert_str(str(run.flags.get("ending_id", ""))).is_equal("the_iron_throne")
	page.queue_free()
	gc.queue_free()


func test_ending_gate_fires_exactly_once_via_the_router() -> void:
	var router := get_node_or_null("/root/UiRouter")
	assert_object(router).is_not_null()
	var gc := _make_game()
	var host := Control.new()
	add_child(host)
	# No finale flag yet: the gate holds.
	assert_bool(bool(EndingGateScript.should_fire(gc))).is_false()
	assert_object(EndingGateScript.maybe_push(host, gc)).is_null()
	assert_int(int(router.call("depth"))).is_equal(0)
	# The finale flag lands (the e2-arc seam): the gate pushes ONE full overlay.
	var run: RunContext = gc.call("run")
	run.flags["succession_begins"] = true
	assert_bool(bool(EndingGateScript.should_fire(gc))).is_true()
	var page: Node = EndingGateScript.maybe_push(host, gc)
	assert_object(page).is_not_null()
	assert_int(int(router.call("depth"))).is_equal(1)
	assert_str(str(page.call("ending_id"))).is_not_empty()
	# The latch stops every later check — no double push on the next quest transition.
	assert_bool(bool(EndingGateScript.should_fire(gc))).is_false()
	assert_object(EndingGateScript.maybe_push(host, gc)).is_null()
	assert_int(int(router.call("depth"))).is_equal(1)
	router.call("pop_all")
	host.queue_free()
	gc.queue_free()


func test_closed_ledger_gates_continue() -> void:
	_clear_saves()
	var gc := _make_game()
	assert_str(str(gc.call("continue_health"))).is_equal("ok")
	var run: RunContext = gc.call("run")
	EndingsService.record(run, "the_broker")
	assert_bool(bool(await gc.call("request_save"))).is_true()
	# The saved envelope carries the latched ending id -> the ledger reads CLOSED.
	assert_str(str(gc.call("continue_health"))).is_equal("closed")
	# The menu answers with the begin-anew dialog instead of reloading the record.
	var menu: Control = MainMenuScript.new()
	menu.call("set_game", gc)
	add_child(menu)
	assert_object(menu.find_child("ClosedLedgerDialog", true, false)).is_null()
	menu.call("_on_continue")
	var dialog: Node = menu.find_child("ClosedLedgerDialog", true, false)
	assert_object(dialog).is_not_null()
	assert_str(str(dialog.get("dialog_text"))).is_equal("This ledger is closed — begin anew?")
	menu.queue_free()
	gc.queue_free()
	_clear_saves()


func test_character_sheet_previews_the_ending_path() -> void:
	var gc := _make_game()
	var sheet: Control = CharacterSheetScript.new()
	sheet.call("set_game", gc)
	sheet.call("set_auto_build", false)
	add_child(sheet)
	sheet.call("build_from_game")
	# A fresh run trends toward the gray god — the same resolver the ending screen uses.
	assert_str(str(sheet.call("ending_path_text"))).contains("The path of The Broker")
	# The preview tracks the axes live (no finale flag needed)...
	var run: RunContext = gc.call("run")
	run.order_chaos = 80
	run.purity_corrupt = 80
	sheet.call("build_from_game")
	assert_str(str(sheet.call("ending_path_text"))).contains("The Devourer")
	# ...and a latched refusal door legitimately outranks the grid cell.
	run.flags["unmaking"] = true
	sheet.call("build_from_game")
	assert_str(str(sheet.call("ending_path_text"))).contains("The Unmaking")
	sheet.queue_free()
	gc.queue_free()
