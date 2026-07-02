extends GdUnitTestSuite
## Batch E1a — quest & timeline ingest PARITY suite. The authored docs are the
## source (story_quests.md 24 main / side_quests.md 28 side; scripts_mvp.md 8 +
## scripts_acts2to5.md 10 scenes); tools/ingest_quests.py + tools/gen_timelines.py
## are the deterministic transforms. This suite proves the generated artifacts
## hold their contract:
##   * counts match the docs (24 main + 28 side = 52), ids unique, every step
##     carries a per-quest-unique step_key + verbatim non-empty objective text;
##   * the Act-0 / SQ-04..06 catalog ids COLLIDE with the hand-wired canon ids so
##     the union dedupes in the hand-wired defs' favor (they stay canonical);
##   * OverworldContent.quest_defs() unions catalog quests for the ACTIVE region
##     (threshold hub + verdant_glut + region-agnostic spine), boss floor last;
##   * the act-gate chain walks END TO END on the raw catalog (Q X.4 opens act
##     X+1) and bridges from the hand-wired Act-0 climax via ACT_GATE_ALIASES;
##   * QuestService can register + walk EVERY catalog quest's steps headless;
##   * every generated .dtl parses via DialogicResourceUtil (post
##     ensure_directories) and the Knack scene carries its authored branch
##     signals; every generated .dch loads with a display name.

const GENERATED_DTL_DIR := "res://presentation/dialogue/generated"
const GENERATED_DCH_DIR := "res://presentation/dialogue/characters/generated"
const EXPECTED_MAIN := 24
const EXPECTED_SIDE := 28
const EXPECTED_SCENES := 18

const KNOWN_REGIONS := [
	"",
	"threshold",
	"verdant_glut",
	"mournmarch",
	"forgefell",
	"storm_vault",
	"sunder",
	"titanfall",
	"tideless",
	"astral_tier",
	"maw_beneath",
	"hollow_atelier",
]


func test_counts_match_the_authored_docs() -> void:
	assert_int(QuestCatalog.count("main")).is_equal(EXPECTED_MAIN)
	assert_int(QuestCatalog.count("side")).is_equal(EXPECTED_SIDE)
	assert_int(QuestCatalog.entries().size()).is_equal(EXPECTED_MAIN + EXPECTED_SIDE)


func test_every_entry_is_structurally_sound() -> void:
	var ids: Dictionary = {}
	for e: Dictionary in QuestCatalog.entries():
		var quest_id := str(e.get("id", ""))
		assert_str(quest_id).is_not_empty()
		(
			assert_bool(ids.has(quest_id))
			. override_failure_message("duplicate quest id: " + quest_id)
			. is_false()
		)
		ids[quest_id] = true
		assert_bool(["main", "side"].has(str(e.get("kind", "")))).is_true()
		(
			assert_bool(KNOWN_REGIONS.has(str(e.get("region", ""))))
			. override_failure_message(
				"%s: unknown region '%s'" % [quest_id, str(e.get("region", ""))]
			)
			. is_true()
		)
		var act := int(e.get("act", -99))
		assert_bool(act >= -1 and act <= 5).is_true()
		assert_bool((e.get("prereq_flags", []) as Array).size() <= 1).is_true()
		var steps: Array = e.get("steps", []) as Array
		assert_bool(steps.is_empty()).is_false()
		var step_keys: Dictionary = {}
		var step_ids: Dictionary = {}
		for s: Dictionary in steps:
			(
				assert_str(str(s.get("objective_text", "")))
				. override_failure_message(quest_id + ": empty objective_text")
				. is_not_empty()
			)
			var step_key := str(s.get("step_key", ""))
			assert_str(step_key).is_not_empty()
			(
				assert_bool(step_keys.has(step_key))
				. override_failure_message("%s: duplicate step_key %s" % [quest_id, step_key])
				. is_false()
			)
			step_keys[step_key] = true
			var step_id := str(s.get("id", ""))
			assert_bool(step_ids.has(step_id)).is_false()
			step_ids[step_id] = true
		assert_str(str((e.get("on_complete", {}) as Dictionary).get("set_flag", ""))).is_not_empty()


func test_canon_ids_collide_so_hand_wired_defs_win_the_dedupe() -> void:
	# The ingest's id scheme intentionally reproduces the wired canon ids.
	for quest_id: String in [
		"act0_the_knack",
		"act0_altar_hours",
		"act0_the_mark",
		"act0_registered",
		"the_melon_that_waits",
		"six_petals_true_bred",
		"the_bloom_that_wont_bury",
	]:
		(
			assert_bool(QuestCatalog.entry(quest_id).is_empty())
			. override_failure_message("catalog is missing the canon-id entry " + quest_id)
			. is_false()
		)


func test_overworld_union_dedupes_filters_and_keeps_the_boss_floor_last() -> void:
	var defs: Array = OverworldContent.quest_defs()
	var ids: Array = []
	var seen: Dictionary = {}
	for def: Dictionary in defs:
		var quest_id := str(def.get("id", ""))
		(
			assert_bool(seen.has(quest_id))
			. override_failure_message("union carries a duplicate id: " + quest_id)
			. is_false()
		)
		seen[quest_id] = true
		ids.append(quest_id)
	# Hand-wired wins: the Knack keeps its authored two-step shape.
	var knack: Dictionary = OverworldQuestsGlue.quest_def_by_id("act0_the_knack")
	assert_int((knack.get("steps", []) as Array).size()).is_equal(2)
	# SQ-05 keeps the wired choice-driven def (step 'answer_garran' exists).
	(
		assert_bool(
			(
				OverworldQuestsGlue
				. quest_step_effect("six_petals_true_bred", "answer_garran")
				. is_empty()
			)
		)
		. is_false()
	)
	# Catalog additions ride: the Threshold hub side quests + the Act-1 opener.
	assert_bool(ids.has("the_confident_pigeon")).is_true()
	assert_bool(ids.has("what_the_tent_keeps_count_of")).is_true()
	assert_bool(ids.has("act1_greener_pastures_hungrier_ones")).is_true()
	# Region-agnostic spine quests ride the act chain (gated, but registered).
	assert_bool(ids.has("act2_the_sworn_rite")).is_true()
	# Other regions' side quests stay out of the shipped region.
	assert_bool(ids.has("the_bride_still_waiting")).is_false()
	assert_bool(ids.has("her_name_every_day")).is_false()
	# The boss goal remains the HUD floor (last).
	assert_str(str((defs[defs.size() - 1] as Dictionary).get("id", ""))).is_equal(
		"what_guards_the_deep"
	)


func test_act1_gate_bridges_from_the_hand_wired_act0_climax() -> void:
	var quests := QuestService.new()
	quests.register(OverworldContent.quest_defs())
	# Gated: the Act-1 opener refuses to start before the Act-0 climax flag.
	assert_bool(quests.start("act1_greener_pastures_hungrier_ones")).is_false()
	# The hand-wired climax flag (registered_aspirant) opens it via the alias.
	quests.run_state().set_flag("registered_aspirant", true)
	assert_bool(quests.start("act1_greener_pastures_hungrier_ones")).is_true()
	assert_bool(quests.advance("act1_greener_pastures_hungrier_ones", "objective")).is_true()
	assert_bool(quests.is_done("act1_greener_pastures_hungrier_ones")).is_true()
	assert_bool(quests.run_state().flag("act1_q1_done")).is_true()


func test_the_raw_main_spine_chains_all_six_acts_without_manual_flags() -> void:
	var quests := QuestService.new()
	var defs: Array = []
	for e: Dictionary in QuestCatalog.entries():
		if str(e.get("kind", "")) == "main":
			defs.append(QuestCatalog.to_def(e))
	assert_int(defs.size()).is_equal(EXPECTED_MAIN)
	quests.register(defs)
	# Catalog order IS doc order (act, quest number): walking it front to back
	# must open every act gate in turn — no flag is ever set by hand.
	for def: Dictionary in defs:
		var quest_id := str(def.get("id", ""))
		(
			assert_bool(quests.start(quest_id))
			. override_failure_message("act gate did not open for " + quest_id)
			. is_true()
		)
		for s: Dictionary in def.get("steps", []) as Array:
			assert_bool(quests.advance(quest_id, str(s.get("id", "")))).is_true()
		assert_bool(quests.is_done(quest_id)).is_true()
	assert_bool(quests.run_state().flag("act5_q4_done")).is_true()


func test_quest_service_walks_every_side_quest_headless() -> void:
	var quests := QuestService.new()
	var defs: Array = []
	for e: Dictionary in QuestCatalog.entries():
		if str(e.get("kind", "")) == "side":
			defs.append(QuestCatalog.to_def(e))
	assert_int(defs.size()).is_equal(EXPECTED_SIDE)
	quests.register(defs)
	for def: Dictionary in defs:
		var quest_id := str(def.get("id", ""))
		assert_bool(quests.start(quest_id)).is_true()
		for s: Dictionary in def.get("steps", []) as Array:
			assert_bool(quests.advance(quest_id, str(s.get("id", "")))).is_true()
		assert_bool(quests.is_done(quest_id)).is_true()
		var done_flag := str((def.get("on_complete", {}) as Dictionary).get("set_flag", ""))
		assert_bool(quests.run_state().flag(done_flag)).is_true()


func test_every_generated_timeline_parses_with_events() -> void:
	DialogicFacade.ensure_directories()  # CI import wipes [dialogic]; self-heal first
	var names := _files_in(GENERATED_DTL_DIR, ".dtl")
	assert_int(names.size()).is_equal(EXPECTED_SCENES)
	var directory: Dictionary = DialogicResourceUtil.get_directory("dtl")
	for name: String in names:
		var scene_id := name.trim_suffix(".dtl")
		(
			assert_bool(directory.has(scene_id))
			. override_failure_message("dtl directory is missing generated timeline " + scene_id)
			. is_true()
		)
		var timeline: DialogicTimeline = load(GENERATED_DTL_DIR + "/" + name)
		assert_object(timeline).is_not_null()
		timeline.process()
		(
			assert_bool(timeline.events.is_empty())
			. override_failure_message(scene_id + " parsed to zero events")
			. is_false()
		)


func test_the_knack_scene_carries_its_authored_branch_signals() -> void:
	DialogicFacade.ensure_directories()
	var timeline: DialogicTimeline = load(GENERATED_DTL_DIR + "/mvp_s01_the_knack.dtl")
	assert_object(timeline).is_not_null()
	timeline.process()
	var choices := 0
	var signal_args: Array = []
	for event: Variant in timeline.events:
		if event is DialogicChoiceEvent:
			choices += 1
		elif event is DialogicSignalEvent:
			signal_args.append(str(event.argument))
	assert_int(choices).is_equal(3)
	(
		assert_array(signal_args)
		. contains(
			[
				"choice:first_catch_clean",
				"choice:first_catch_harsh",
				"choice:first_catch_wild",
			]
		)
	)


func test_every_generated_character_stub_loads_with_a_display_name() -> void:
	DialogicFacade.ensure_directories()
	var names := _files_in(GENERATED_DCH_DIR, ".dch")
	assert_bool(names.is_empty()).is_false()
	for name: String in names:
		var character: DialogicCharacter = load(GENERATED_DCH_DIR + "/" + name)
		(
			assert_object(character)
			. override_failure_message("could not load generated character " + name)
			. is_not_null()
		)
		assert_str(character.display_name).is_not_empty()


func _files_in(path: String, extension: String) -> Array:
	var out: Array = []
	var dir := DirAccess.open(path)
	assert_object(dir).is_not_null()
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.ends_with(extension):
			out.append(name)
		name = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out
