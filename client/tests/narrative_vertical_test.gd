extends GdUnitTestSuite
## Cluster 3 (ADR-017, D4): the sample vertical runs end-to-end headless.
##   Ink lore branch (EXTERNAL query) -> Dialogic encounter -> quest gates run state.
## Then save -> reload -> state intact. Exercises inkgd + Questify + Dialogic through
## their facades, proving the bridge is the only coupling.

const NarrativeVerticalScript := preload("res://application/narrative/narrative_vertical.gd")


func test_vertical_runs_and_gates_run_state() -> void:
	var vertical: Node = NarrativeVerticalScript.new()
	add_child(vertical)
	auto_free(vertical)
	vertical.setup()

	var loaded: bool = await vertical.load()
	assert_bool(loaded).is_true()

	var transcript: Array = await vertical.run()
	# The Ink branch produced lines, offered choices, then Dialogic rendered.
	var sources: Array = transcript.map(func(entry: Dictionary): return entry.get("source", ""))
	assert_array(sources).contains(["ink"])
	assert_array(sources).contains(["dialogic"])
	assert_array(sources).contains(["quest"])

	# The quest gated the real things via run state (no stats computed anywhere).
	var quests = vertical.quest_service()
	assert_bool(quests.is_done("rust_marsh_omen")).is_true()
	var run = quests.run_state()
	assert_bool(run.region_unlocked("rust_marsh")).is_true()
	assert_bool(run.flag("lab_op_unlocked:necropsy")).is_true()
	assert_bool(run.has_captured("bog_wretch")).is_true()


func test_vertical_save_reload_intact() -> void:
	var vertical: Node = NarrativeVerticalScript.new()
	add_child(vertical)
	auto_free(vertical)
	vertical.setup()
	assert_bool(await vertical.load()).is_true()
	await vertical.run()

	assert_int(vertical.save()).is_equal(OK)

	# Fresh vertical, restore from the versioned-JSON save on disk.
	var reloaded: Node = NarrativeVerticalScript.new()
	add_child(reloaded)
	auto_free(reloaded)
	reloaded.setup()
	assert_bool(await reloaded.load()).is_true()
	assert_bool(reloaded.restore()).is_true()

	var quests = reloaded.quest_service()
	assert_bool(quests.is_done("rust_marsh_omen")).is_true()
	var run = quests.run_state()
	assert_bool(run.region_unlocked("rust_marsh")).is_true()
	assert_bool(run.has_captured("bog_wretch")).is_true()
