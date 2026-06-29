extends GdUnitTestSuite
## Phase 8 — CharacterSheet DoD, driven HEADLESSLY. The sheet surfaces the player's morality grid
## (Order⇄Chaos × Purity⇄Corrupt → one of nine gods), rank, notoriety and the corruption meter from
## the run, using the SAME CharacterEngine banding as the oracle golden surface.

const GameControllerScript := preload("res://application/game/game_controller.gd")
const FakeDalScript := preload("res://infrastructure/dal/fake_dal.gd")
const CharacterSheetScript := preload("res://presentation/character/character_sheet.gd")

const TEST_SEED := 0x0CEA_2026


func _make_game() -> Node:
	var gc: Node = GameControllerScript.new()
	add_child(gc)
	gc.call("configure", FakeDalScript.make())
	gc.call("new_run", TEST_SEED)
	return gc


func _make_sheet(gc: Node) -> Control:
	var s: Control = CharacterSheetScript.new()
	s.call("set_game", gc)
	s.call("set_auto_build", false)
	add_child(s)
	return s


func test_sheet_shows_default_god_rank_and_meters() -> void:
	var gc := _make_game()
	var s := _make_sheet(gc)
	s.call("build_from_game")
	# A fresh run sits at neutral on both axes; band3's middle bands are Balanced + Tainted, so the
	# default god is The Broker (the gray god), rank Mortal.
	assert_str(str(s.call("god_text"))).contains("Broker")
	assert_str(str(s.call("rank_text"))).contains("Mortal")
	assert_object(s.find_child("OrderChaosBar", true, false)).is_not_null()
	assert_object(s.find_child("PurityCorruptBar", true, false)).is_not_null()
	assert_object(s.find_child("CorruptionBar", true, false)).is_not_null()
	s.queue_free()
	gc.queue_free()


func test_sheet_classifies_a_corrupted_order_player_as_the_iron_throne() -> void:
	# band3: order_chaos <= -34 => Order, purity_corrupt >= 34 => Corrupt => GODS["Order|Corrupt"].
	var gc := _make_game()
	var run: RunContext = gc.call("run")
	run.order_chaos = -80
	run.purity_corrupt = 80
	run.corruption = 65
	var s := _make_sheet(gc)
	s.call("build_from_game")
	assert_str(str(s.call("god_text"))).contains("Iron Throne")
	var bar: ProgressBar = s.find_child("CorruptionBar", true, false)
	assert_object(bar).is_not_null()
	assert_int(int(bar.value)).is_equal(65)
	s.queue_free()
	gc.queue_free()
