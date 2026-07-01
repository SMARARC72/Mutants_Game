extends GdUnitTestSuite
## Wave 2 overflow guard — no primary Button may ever sit outside the viewport again (the class of
## bug where Flee/Capture rendered clipped off-screen and the verb was unreachable).
##   * battle screen (stub session via the battle_screen_test harness), lab screen and camp menu are
##     instantiated HEADLESSLY at the project viewport size (1920x1080 canvas_items stretch);
##   * after layout settles, the whole Control tree is walked and every VISIBLE Button's
##     get_global_rect() must be enclosed by the viewport rect;
##   * robustness: zero-size/unrendered buttons are skipped, and buttons inside a ScrollContainer
##     are exempt (overflow there is reachable by scrolling, by design — W0 wrapped the battle
##     root box + lab picker stack in scrolls); each screen must still yield >0 checked buttons
##     so the guard can never go vacuously green.

const GameControllerScript := preload("res://application/game/game_controller.gd")
const FakeDalScript := preload("res://infrastructure/dal/fake_dal.gd")
const BattleScreenScript := preload("res://presentation/battle/battle_screen.gd")
const LabScreenScript := preload("res://presentation/lab/lab_screen.gd")
const CampMenuScript := preload("res://presentation/camp/camp_menu.gd")

const TEST_SEED := 0xBA771E5
const BATTLE_SEED := 0x5117E1

# Mirror of battle_screen_test: a weak wild enemy team so the stub session builds interactively,
# and a known-LEGAL lab party (SB07 Eros/Gaia T1 + AD10 Eros/Gaia T2) so the lab bench populates.
const ENEMY_PARTY := [{"species_id": "SB33"}, {"species_id": "SB14"}]
const PARTY_LAB := [{"species_id": "SB07"}, {"species_id": "AD10"}]

# --- harness ---------------------------------------------------------------------------------- #


func _make_game(party: Array = []) -> Node:
	var gc: Node = GameControllerScript.new()
	add_child(gc)
	gc.call("configure", FakeDalScript.make())
	var run: RunContext = gc.call("new_run", TEST_SEED)
	if not party.is_empty():
		run.party = party.duplicate(true)
	return gc


## True when any ancestor between `node` (exclusive) and `stop` (inclusive) is a ScrollContainer —
## such a button may legitimately lie outside the viewport (the player scrolls to it).
func _inside_scroll(node: Node, stop: Node) -> bool:
	var cursor := node.get_parent()
	while cursor != null:
		if cursor is ScrollContainer:
			return true
		if cursor == stop:
			return false
		cursor = cursor.get_parent()
	return false


## Walk `screen`'s Control tree and assert every visible, laid-out, non-scrollable Button fits
## inside the viewport rect. Returns the number of buttons actually checked.
func _assert_buttons_on_screen(screen: Control, label: String) -> int:
	# Two frames so containers resolve their layout (anchors + minimum-size sorting).
	await get_tree().process_frame
	await get_tree().process_frame
	var viewport_rect := screen.get_viewport_rect()
	assert_bool(viewport_rect.size.x > 0.0 and viewport_rect.size.y > 0.0).is_true()
	var checked := 0
	var pending: Array[Node] = [screen]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		for child in node.get_children():
			pending.append(child)
		var button := node as Button
		if button == null:
			continue
		if not button.is_visible_in_tree():
			continue  # hidden affordances (e.g. state-gated) are not reachable targets
		var rect := button.get_global_rect()
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue  # unrendered/collapsed — never laid out this frame
		if _inside_scroll(button, screen):
			continue  # scrollable overflow is reachable by design
		checked += 1
		(
			assert_bool(viewport_rect.grow(1.0).encloses(rect))
			. override_failure_message(
				(
					"%s: Button '%s' (\"%s\") rect %s overflows the %s viewport"
					% [label, button.name, button.text, rect, viewport_rect]
				)
			)
			. is_true()
		)
	(
		assert_int(checked)
		. override_failure_message(
			"%s: the walk found no checkable Buttons — guard is vacuous" % label
		)
		. is_greater(0)
	)
	return checked


# --- screens ---------------------------------------------------------------------------------- #


func test_battle_screen_primary_buttons_fit_the_viewport() -> void:
	var gc := _make_game()
	var run: RunContext = gc.call("run")
	run.flags["pending_battle"] = {
		"enemy_party": ENEMY_PARTY.duplicate(true),
		"battle_seed": BATTLE_SEED,
		"is_wild": true,
	}
	var screen: Control = BattleScreenScript.new()
	screen.call("set_game", gc)
	screen.call("set_auto_run", false)
	add_child(screen)
	var step: Dictionary = screen.call("run_pending_battle")
	assert_str(str(step.get("kind", ""))).is_equal("await_player")
	await _assert_buttons_on_screen(screen, "battle_screen")
	# The wild-battle verbs specifically — the exact buttons the W0 audit found clipped.
	assert_object(screen.find_child("FleeButton", true, false)).is_not_null()
	assert_object(screen.find_child("CaptureButton", true, false)).is_not_null()
	screen.queue_free()
	gc.queue_free()


func test_lab_screen_action_buttons_fit_the_viewport() -> void:
	var gc := _make_game(PARTY_LAB)
	var screen: Control = LabScreenScript.new()
	screen.call("set_game", gc)
	screen.call("set_auto_build", false)
	add_child(screen)
	screen.call("build")
	await _assert_buttons_on_screen(screen, "lab_screen")
	screen.queue_free()
	gc.queue_free()


func test_camp_menu_buttons_fit_the_viewport() -> void:
	var menu: Control = CampMenuScript.new()
	menu.call("set_auto_navigate", false)
	add_child(menu)
	await _assert_buttons_on_screen(menu, "camp_menu")
	assert_object(menu.find_child("ResumeButton", true, false)).is_not_null()
	menu.queue_free()
