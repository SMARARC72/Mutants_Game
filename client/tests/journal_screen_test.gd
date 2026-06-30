extends GdUnitTestSuite
## JournalScreen (Phase 13) — the quest log, driven HEADLESSLY.
##   * rebuilds a QuestService from the authored defs (OverworldContent.quest_defs) + the run's persisted
##     quest_state, and surfaces only DISCOVERED quests (active or done) with status + current objective;
##   * an undiscovered quest stays hidden (no spoilers); a fresh run shows the empty state;
##   * the camp menu wires a "Journal" button to the journal scene.
## Drives a CODE-INSTANTIATED GameController with an injected FakeDal.

const GameControllerScript := preload("res://application/game/game_controller.gd")
const FakeDalScript := preload("res://infrastructure/dal/fake_dal.gd")
const JournalScreenScript := preload("res://presentation/journal/journal_screen.gd")
const CampMenuScript := preload("res://presentation/camp/camp_menu.gd")

const TEST_SEED := 0x70DD

var _gc: Node = null


func _make_game() -> Node:
	var gc: Node = GameControllerScript.new()
	add_child(gc)
	gc.call("configure", FakeDalScript.make())
	gc.call("new_run", TEST_SEED)
	return gc


## Seed the run with a serialized quest_state: marsh_welcome ACTIVE (step 1 done, objective = step 2),
## the_melon_that_waits DONE (both steps), bramble + wenlow untouched (undiscovered).
func _seed_quest_state(gc: Node) -> void:
	var run: RunContext = gc.call("run")
	var qs := QuestService.new()
	qs.register(OverworldContent.quest_defs())
	qs.start("marsh_welcome")
	qs.advance("marsh_welcome", "hear_marrow")  # active, cursor now at "meet_wretch"
	qs.start("the_melon_that_waits")
	qs.advance("the_melon_that_waits", "covet_melon")
	qs.advance("the_melon_that_waits", "wait_with_melon")  # completes -> done
	run.flags["quest_state"] = qs.serialize()


func _make_journal(gc: Node) -> Control:
	var screen: Control = JournalScreenScript.new()
	screen.call("set_game", gc)
	screen.call("set_auto_build", false)
	add_child(screen)
	screen.call("build_from_game")
	return screen


func test_journal_surfaces_only_discovered_quests() -> void:
	var gc := _make_game()
	_seed_quest_state(gc)
	var screen := _make_journal(gc)
	# Two discovered (marsh active + melon done); bramble + wenlow stay hidden.
	assert_int(int(screen.call("quest_count"))).is_equal(2)
	var by_id := {}
	for e: Dictionary in screen.call("entries"):
		by_id[str(e["id"])] = e
	assert_bool(by_id.has("marsh_welcome")).is_true()
	assert_bool(by_id.has("the_melon_that_waits")).is_true()
	assert_bool(by_id.has("six_petals_true_bred")).is_false()  # undiscovered, hidden
	screen.queue_free()
	gc.queue_free()


func test_active_quest_shows_its_current_objective() -> void:
	var gc := _make_game()
	_seed_quest_state(gc)
	var screen := _make_journal(gc)
	var marsh := {}
	for e: Dictionary in screen.call("entries"):
		if str(e["id"]) == "marsh_welcome":
			marsh = e
	assert_str(str(marsh.get("status", ""))).is_equal("active")
	# The objective is the step at the cursor — step 2 "Meet the Bog-Wretch."
	assert_str(str(marsh.get("objective", ""))).is_equal("Meet the Bog-Wretch.")
	screen.queue_free()
	gc.queue_free()


func test_completed_quest_reads_as_done() -> void:
	var gc := _make_game()
	_seed_quest_state(gc)
	var screen := _make_journal(gc)
	var melon := {}
	for e: Dictionary in screen.call("entries"):
		if str(e["id"]) == "the_melon_that_waits":
			melon = e
	assert_str(str(melon.get("status", ""))).is_equal("done")
	screen.queue_free()
	gc.queue_free()


func test_fresh_run_shows_empty_state() -> void:
	var gc := _make_game()  # no quest_state seeded
	var screen := _make_journal(gc)
	assert_int(int(screen.call("quest_count"))).is_equal(0)
	assert_object(screen.find_child("EmptyNote", true, false)).is_not_null()
	assert_object(screen.find_child("BackButton", true, false)).is_not_null()
	screen.queue_free()
	gc.queue_free()


func test_journal_builds_quest_cards_ui() -> void:
	var gc := _make_game()
	_seed_quest_state(gc)
	var screen := _make_journal(gc)
	assert_object(screen.find_child("JournalTitle", true, false)).is_not_null()
	assert_object(screen.find_child("QuestList", true, false)).is_not_null()
	# One card per discovered quest.
	var cards := 0
	for child in (screen.find_child("QuestList", true, false) as Node).get_children():
		if str(child.name).begins_with("QuestCard"):  # Godot suffixes duplicate names (QuestCard, QuestCard2)
			cards += 1
	assert_int(cards).is_equal(2)
	screen.queue_free()
	gc.queue_free()


func test_journal_surfaces_bloomwarden_standing() -> void:
	# The journal reads the GameController's authoritative standing + tier; a few catches lift the tier
	# off Stranger, and the line reflects it (the quests nudge this meter; now it's visible).
	var gc := _make_game()
	for _i in range(3):
		gc.call("adjust_bloomwardens_standing", 5)  # 3 catches' worth -> above Stranger
	var screen := _make_journal(gc)
	var line := str(screen.call("standing_text"))
	assert_str(line).starts_with("Bloomwardens —")
	assert_int(int(gc.call("bloomwardens_standing"))).is_equal(15)
	# The rendered line carries the live value.
	assert_bool(line.contains("15")).is_true()
	assert_object(screen.find_child("StandingLine", true, false)).is_not_null()
	screen.queue_free()
	gc.queue_free()


func test_camp_menu_wires_journal_button() -> void:
	var camp: Node = CampMenuScript.new()
	camp.call("set_auto_navigate", false)
	add_child(camp)
	assert_object(camp.find_child("JournalButton", true, false)).is_not_null()
	assert_str(str(camp.call("open_journal"))).is_equal(CampMenuScript.JOURNAL_SCENE)
	camp.queue_free()
