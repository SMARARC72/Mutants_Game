extends GdUnitTestSuite
## Wave 18 — the Journal's GRAVEYARD tab, driven headlessly.
##   * the Ledger grows two tab verbs (Errands / The Graveyard); the errand page stays default
##     so every pre-W18 journal behavior is untouched;
##   * the Graveyard page renders one memorial per run.flags["graveyard"] entry: the plate as
##     an INK SILHOUETTE (modulate = ink), name, cause and the parts the death funded;
##   * an empty graveyard shows the authored empty state.

const GameControllerScript := preload("res://application/game/game_controller.gd")
const FakeDalScript := preload("res://infrastructure/dal/fake_dal.gd")
const JournalScreenScript := preload("res://presentation/journal/journal_screen.gd")

const TEST_SEED := 0x6EA7


func _make_game() -> Node:
	var gc: Node = GameControllerScript.new()
	add_child(gc)
	gc.call("configure", FakeDalScript.make())
	gc.call("new_run", TEST_SEED)
	return gc


func _seed_graveyard(gc: Node) -> void:
	var run: RunContext = gc.call("run")
	run.flags["graveyard"] = [
		{
			"name": "Thornlash",
			"species_id": "SB07",
			"sigil": "thornlash-1",
			"force": "Eros",
			"cause": "Felled by Grave-Boar",
			"turn": 6,
			"region": "verdant_glut",
			"parts": ["claw", "horn"],
			"creature": {"species_id": "SB07", "is_dead": true},
		}
	]


func _make_journal(gc: Node) -> Control:
	var screen: Control = JournalScreenScript.new()
	screen.call("set_game", gc)
	screen.call("set_auto_build", false)
	add_child(screen)
	screen.call("build_from_game")
	return screen


func test_ledger_builds_both_tab_verbs_default_quests() -> void:
	var gc := _make_game()
	var screen := _make_journal(gc)
	assert_str(str(screen.call("current_tab"))).is_equal("quests")
	assert_object(screen.find_child("QuestsTab", true, false)).is_not_null()
	assert_object(screen.find_child("GraveyardTab", true, false)).is_not_null()
	# The errand page is untouched by the new tab (pre-W18 journal tests keep passing).
	assert_object(screen.find_child("QuestList", true, false)).is_not_null()
	screen.queue_free()
	gc.queue_free()


func test_graveyard_tab_renders_memorials() -> void:
	var gc := _make_game()
	_seed_graveyard(gc)
	var screen := _make_journal(gc)
	assert_int((screen.call("graveyard_entries") as Array).size()).is_equal(1)
	screen.call("show_graveyard")
	assert_str(str(screen.call("current_tab"))).is_equal("graveyard")
	var card: Node = screen.find_child("MemorialCard_0", true, false)
	assert_object(card).is_not_null()
	var name_label: Label = screen.find_child("MemorialName", true, false)
	assert_str(name_label.text).is_equal("Thornlash")
	var cause: Label = screen.find_child("MemorialCause", true, false)
	assert_bool(cause.text.contains("Grave-Boar")).is_true()
	assert_bool(cause.text.to_lower().contains("faint")).is_false()  # never the word
	var parts: Label = screen.find_child("MemorialParts", true, false)
	assert_bool(parts.text.contains("Claw")).is_true()
	screen.queue_free()
	gc.queue_free()


func test_memorial_plate_is_an_ink_silhouette() -> void:
	var gc := _make_game()
	_seed_graveyard(gc)
	var screen := _make_journal(gc)
	screen.call("show_graveyard")
	var plate: Control = screen.find_child("MemorialPlate", true, false)
	assert_object(plate).is_not_null()
	# The silhouette read: the plate is modulated to INK (near-black), not shown in life colours.
	assert_float(plate.modulate.r).is_less(0.2)
	assert_float(plate.modulate.g).is_less(0.2)
	assert_float(plate.modulate.b).is_less(0.2)
	screen.queue_free()
	gc.queue_free()


func test_empty_graveyard_shows_the_authored_empty_state() -> void:
	var gc := _make_game()
	var screen := _make_journal(gc)
	screen.call("show_graveyard")
	assert_int((screen.call("graveyard_entries") as Array).size()).is_equal(0)
	var empty: Label = screen.find_child("EmptyNote", true, false)
	assert_object(empty).is_not_null()
	assert_str(empty.text).is_not_empty()
	screen.queue_free()
	gc.queue_free()


func test_tabs_switch_back_to_quests() -> void:
	var gc := _make_game()
	_seed_graveyard(gc)
	var screen := _make_journal(gc)
	screen.call("show_graveyard")
	screen.call("show_quests")
	assert_str(str(screen.call("current_tab"))).is_equal("quests")
	assert_object(screen.find_child("MemorialCard_0", true, false)).is_null()
	screen.queue_free()
	gc.queue_free()
