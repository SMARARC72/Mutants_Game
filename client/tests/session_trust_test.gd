extends GdUnitTestSuite
## Wave 18 "Session Trust" — the witnessed save path, headless.
##   * request_save emits save_succeeded on a clean save and save_failed when the DAL write
##     errors (fake failing repo);
##   * new_run writes the local ledger immediately (continuable from step 0);
##   * continue_health gates Continue: "none" (no file) / "ok" / "illegible" (corrupt envelope);
##   * SaveSentry: the quit-gate autosave is drivable headless (autosave_and_quit(false)) and
##     the persistent warning banner toggles with the save outcome signals.

const GameControllerScript := preload("res://application/game/game_controller.gd")
const FakeDalScript := preload("res://infrastructure/dal/fake_dal.gd")
const SaveEnvelopeScript := preload("res://application/persistence/save_envelope.gd")
const SaveResultScript := preload("res://infrastructure/dal/save_result.gd")
const SaveSentryScript := preload("res://autoload/save_sentry.gd")

const TEST_SEED := 0x5A4E


## A run repository whose every write fails — the fake DAL failure the signals must surface.
class FailingRunRepository:
	extends RefCounted

	func save_run(_aggregate: Dictionary, _base_save_version: int) -> SaveResult:
		return SaveResult.error("the ink refuses the page")


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


func _make_controller(dal: Dictionary = {}) -> Node:
	var gc: Node = GameControllerScript.new()
	add_child(gc)
	gc.call("configure", dal if not dal.is_empty() else FakeDalScript.make())
	return gc


func test_request_save_emits_save_succeeded() -> void:
	_clear_saves()
	var gc := _make_controller()
	gc.call("new_run", TEST_SEED)
	var seen := {"ok": 0, "fail": 0}
	gc.connect("save_succeeded", func() -> void: seen["ok"] += 1)
	gc.connect("save_failed", func(_reason: String) -> void: seen["fail"] += 1)
	assert_bool(bool(await gc.call("request_save"))).is_true()
	assert_int(int(seen["ok"])).is_equal(1)
	assert_int(int(seen["fail"])).is_equal(0)
	gc.queue_free()
	_clear_saves()


func test_request_save_emits_save_failed_on_dal_error() -> void:
	_clear_saves()
	var gc := _make_controller({"runs": FailingRunRepository.new()})
	gc.call("new_run", TEST_SEED)
	var seen := {"ok": 0, "fail": 0, "reason": ""}
	gc.connect("save_succeeded", func() -> void: seen["ok"] += 1)
	gc.connect(
		"save_failed",
		func(reason: String) -> void:
			seen["fail"] += 1
			seen["reason"] = reason
	)
	assert_bool(bool(await gc.call("request_save"))).is_false()
	assert_int(int(seen["fail"])).is_equal(1)
	assert_int(int(seen["ok"])).is_equal(0)
	assert_str(str(seen["reason"])).is_not_empty()
	gc.queue_free()
	_clear_saves()


func test_new_run_writes_the_ledger_immediately() -> void:
	_clear_saves()
	var gc := _make_controller()
	assert_bool(bool(gc.call("has_save"))).is_false()
	gc.call("new_run", TEST_SEED)
	# A brand-new run is continuable BEFORE any battle/step (the W18 save-inside-new_run truth).
	assert_bool(bool(gc.call("has_save"))).is_true()
	assert_str(str(gc.call("continue_health"))).is_equal("ok")
	gc.queue_free()
	_clear_saves()


func test_continue_health_gates_none_ok_illegible() -> void:
	_clear_saves()
	var gc := _make_controller()
	assert_str(str(gc.call("continue_health"))).is_equal("none")
	gc.call("new_run", TEST_SEED)
	assert_str(str(gc.call("continue_health"))).is_equal("ok")
	# Corrupt the newest save on disk: the envelope no longer parses -> "illegible", and
	# continue_run refuses it (the menu answers with "The ledger is illegible." instead).
	var path := SaveEnvelopeScript.path_for_run("run-%d" % TEST_SEED)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{ this is not a ledger")
	file.close()
	assert_str(str(gc.call("continue_health"))).is_equal("illegible")
	var gc2 := _make_controller()
	assert_bool(bool(gc2.call("continue_run"))).is_false()
	gc.queue_free()
	gc2.queue_free()
	_clear_saves()


func test_tampered_envelope_reads_illegible() -> void:
	_clear_saves()
	var gc := _make_controller()
	gc.call("new_run", TEST_SEED)
	var path := SaveEnvelopeScript.path_for_run("run-%d" % TEST_SEED)
	var text := SaveEnvelopeScript.load_from_path(path)
	# Flip a run field WITHOUT restamping the checksum: parse_json's tamper gate refuses it.
	var tampered := text.replace('"essence": 0', '"essence": 9999')
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(tampered)
	file.close()
	assert_str(str(gc.call("continue_health"))).is_equal("illegible")
	gc.queue_free()
	_clear_saves()


func test_save_sentry_autosaves_headless_without_quitting() -> void:
	_clear_saves()
	var gc := _make_controller()
	gc.call("new_run", TEST_SEED)
	_clear_saves()  # drop the new_run write so the sentry's save is what we detect
	assert_bool(bool(gc.call("has_save"))).is_false()
	var sentry: Node = SaveSentryScript.new()
	sentry.call("set_game", gc)
	add_child(sentry)
	await sentry.call("autosave_and_quit", false)  # the WM_CLOSE path, minus the quit
	assert_bool(bool(gc.call("has_save"))).is_true()
	sentry.queue_free()
	gc.queue_free()
	_clear_saves()


func test_save_sentry_warning_toggles_with_save_outcomes() -> void:
	_clear_saves()
	var failing := _make_controller({"runs": FailingRunRepository.new()})
	failing.call("new_run", TEST_SEED)
	var sentry: Node = SaveSentryScript.new()
	sentry.call("set_game", failing)
	add_child(sentry)
	assert_bool(bool(sentry.call("warning_visible"))).is_false()
	await failing.call("request_save")
	# The persistent warning is up until a save lands again.
	assert_bool(bool(sentry.call("warning_visible"))).is_true()
	# Heal the DAL (fresh fake) and save again: the warning clears.
	failing.call("configure", FakeDalScript.make())
	await failing.call("request_save")
	assert_bool(bool(sentry.call("warning_visible"))).is_false()
	sentry.queue_free()
	failing.queue_free()
	_clear_saves()
