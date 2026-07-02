extends GdUnitTestSuite
## Wave 8 — "Battle Time Axis" DoD, driven HEADLESSLY (instant/drain mode).
##   * headless defaults to INSTANT beats: the whole pump stays synchronous (no awaits) and the
##     public verbs (run_pending_battle / player_use_skill / last_step) behave exactly as before;
##   * ONE BEAT PER ACTION: every resolved action is captured as a beat carrying its own transcript
##     delta; deltas are contiguous within a batch (drain preserves order) and the drained
##     transcript equals the controller's, line for line, via RichTextLabel appends;
##   * HP CORRECT: after the drain every card's bar/bookkeeping equals the live engine HP;
##   * the "Swift Rites" pacing setting cycles x1 -> x2 -> instant and PERSISTS via Settings;
##   * the transcript is a COLLAPSIBLE drawer (collapsed by default — HAWKING veto: never deleted);
##   * the arena backdrop resolves from the hand-off force (dim battle variant), with a fallback.

const GameControllerScript := preload("res://application/game/game_controller.gd")
const FakeDalScript := preload("res://infrastructure/dal/fake_dal.gd")
const BattleScreenScript := preload("res://presentation/battle/battle_screen.gd")
const SettingsScript := preload("res://autoload/settings.gd")
const SkillBattleControllerScript := preload("res://application/battle/skill_battle_controller.gd")

const TEST_SEED := 0xBA771E5
const BATTLE_SEED := 0x5117E1
const ENEMY_PARTY := [{"species_id": "SB33"}, {"species_id": "SB14"}]


func _make_game(battle_seed: int = BATTLE_SEED, force: String = "") -> Node:
	var gc: Node = GameControllerScript.new()
	add_child(gc)
	gc.call("configure", FakeDalScript.make())
	var run: RunContext = gc.call("new_run", TEST_SEED)
	var pending := {
		"enemy_party": ENEMY_PARTY.duplicate(true),
		"battle_seed": battle_seed,
		"is_wild": true,
	}
	if force != "":
		pending["force"] = force
	run.flags["pending_battle"] = pending
	return gc


func _make_screen(gc: Node) -> Control:
	var screen: Control = BattleScreenScript.new()
	screen.call("set_game", gc)
	screen.call("set_auto_run", false)
	add_child(screen)
	return screen


func _first_damage_skill(actor: Variant) -> String:
	if actor == null:
		return ""
	for skill: String in (actor as AbilityContainer).abilities():
		var verb := SkillBattleControllerScript.verb_of(skill)
		if not SkillBattleControllerScript.is_support_verb(verb):
			return skill
	return ""


## Drive the battle to its end with first-damage-skill choices, accumulating every beat batch the
## screen routed (one batch per pump). Returns the accumulated beats in play order.
func _play_collecting_beats(screen: Control) -> Array:
	var all_beats: Array = []
	var step: Dictionary = screen.call("run_pending_battle")
	all_beats.append_array(screen.call("last_beat_batch"))
	var guard := 0
	while str(step.get("kind", "")) != "ended" and guard < 300:
		guard += 1
		if str(step.get("kind", "")) != "await_player":
			break
		var actor: Variant = step.get("actor")
		var skill := _first_damage_skill(actor)
		if skill == "":
			var kit: Array = (actor as AbilityContainer).abilities() if actor != null else []
			skill = str(kit[0]) if not kit.is_empty() else ""
		if skill == "":
			break
		step = screen.call("player_use_skill", skill, 0)
		all_beats.append_array(screen.call("last_beat_batch"))
	return all_beats


func test_headless_defaults_to_instant_and_stays_synchronous() -> void:
	var gc := _make_game()
	var screen := _make_screen(gc)
	# The make-or-break contract: headless => instant/drain mode, no awaits anywhere.
	assert_bool(bool(screen.get("_instant_beats"))).is_true()
	var step: Dictionary = screen.call("run_pending_battle")
	# The pump returned the first decision point synchronously (same public API as ever).
	assert_str(str(step.get("kind", ""))).is_equal("await_player")
	assert_bool(bool(screen.get("_beats_playing"))).is_false()
	screen.queue_free()
	gc.queue_free()


func test_one_beat_per_action_with_ordered_transcript_deltas() -> void:
	var gc := _make_game()
	var screen := _make_screen(gc)
	var beats := _play_collecting_beats(screen)
	# The battle produced beats (a player action + enemy responses per round) and every routed
	# beat was counted exactly once (N actions -> N beats).
	assert_int(beats.size()).is_greater(0)
	assert_int(int(screen.call("beats_processed"))).is_equal(beats.size())
	var prev_to := 0
	var non_empty := 0
	for beat_v in beats:
		var beat: Dictionary = beat_v
		assert_object(beat.get("actor")).is_not_null()
		# Each beat owns its own transcript delta [log_from, log_to), in strict play order.
		assert_int(int(beat["log_from"])).is_greater_equal(prev_to)
		assert_int(int(beat["log_to"])).is_greater_equal(int(beat["log_from"]))
		prev_to = int(beat["log_to"])
		if int(beat["log_to"]) > int(beat["log_from"]):
			non_empty += 1
		# Every beat snapshots BOTH sides' post-action HP for the glide targets.
		assert_bool(beat.has("party_hp")).is_true()
		assert_bool(beat.has("enemy_hp")).is_true()
	assert_int(non_empty).is_greater(0)
	screen.queue_free()
	gc.queue_free()


func test_drain_applies_hp_correctly_and_preserves_transcript_order() -> void:
	var gc := _make_game()
	var screen := _make_screen(gc)
	_play_collecting_beats(screen)
	var battle: Variant = screen.call("battle")
	assert_bool(bool(battle.call("is_ended"))).is_true()
	# HP correct: every card's bar + bookkeeping equals the live engine HP after the drain.
	for is_enemy in [false, true]:
		var cards: Array = screen.call("side_cards", is_enemy)
		var team: Array = (
			battle.call("enemy_team") if bool(is_enemy) else battle.call("player_team")
		)
		assert_int(cards.size()).is_equal(team.size())
		for i in team.size():
			var ac := team[i] as AbilityContainer
			var c: Dictionary = cards[i]
			assert_int(int((c["bar"] as ProgressBar).value)).is_equal(maxi(0, ac.hp()))
			assert_int(int(c["last_hp"])).is_equal(maxi(0, ac.hp()))
	# Order preserved: the appended drawer text IS the controller transcript, line for line
	# (per-beat RichTextLabel appends — the O(n^2) full rebuild is gone).
	var label := screen.find_child("TranscriptLog", true, false) as RichTextLabel
	assert_object(label).is_not_null()
	var lines: Array = battle.call("transcript")
	var joined := "\n".join(PackedStringArray(lines.map(func(s: Variant) -> String: return str(s))))
	assert_str(label.get_parsed_text().strip_edges()).is_equal(joined.strip_edges())
	screen.queue_free()
	gc.queue_free()


func test_record_drawer_is_collapsed_by_default_and_toggles() -> void:
	var gc := _make_game()
	var screen := _make_screen(gc)
	screen.call("run_pending_battle")
	# HAWKING veto honored: the transcript survives as a drawer — collapsed, never deleted.
	var drawer := screen.find_child("RecordDrawer", true, false) as Control
	assert_object(drawer).is_not_null()
	assert_bool(drawer.visible).is_false()
	assert_object(screen.find_child("TranscriptLog", true, false)).is_not_null()
	var toggle := screen.find_child("RecordToggle", true, false) as Button
	assert_object(toggle).is_not_null()
	screen.call("toggle_record")
	assert_bool(drawer.visible).is_true()
	screen.queue_free()
	gc.queue_free()


func test_swift_rites_setting_cycles_and_persists() -> void:
	var gc := _make_game()
	var screen := _make_screen(gc)
	screen.call("run_pending_battle")
	assert_object(screen.find_child("SwiftRitesButton", true, false)).is_not_null()
	var settings := get_node_or_null("/root/Settings")
	var prior := "x1"
	if settings != null:
		prior = str(settings.call("get_value", "battle", "swift_rites", "x1"))
	# The cycle walks x1 -> x2 -> instant -> x1 from wherever the setting currently sits.
	var order: Array = BattleScreenScript.SWIFT_RITES_ORDER
	var expected := str(order[(order.find(prior) + 1) % order.size()])
	var got := str(screen.call("cycle_swift_rites"))
	assert_str(got).is_equal(expected)
	if settings != null:
		# Persisted through the Settings autoload (battle section, versioned JSON)...
		assert_str(str(settings.call("get_value", "battle", "swift_rites", "x1"))).is_equal(
			expected
		)
		# ...and a FRESH Settings instance re-reads it from disk (survives a restart).
		var fresh: Node = SettingsScript.new()
		add_child(fresh)
		assert_str(str(fresh.call("get_value", "battle", "swift_rites", "x1"))).is_equal(expected)
		fresh.queue_free()
		# Leave the player's real setting as we found it.
		settings.call("set_value", "battle", "swift_rites", prior)
		settings.call("save_settings")
	screen.queue_free()
	gc.queue_free()


func test_backdrop_resolves_from_force_with_wild_fallback() -> void:
	# An Eros hand-off picks the eros arena (dim battle variant preferred).
	var gc := _make_game(BATTLE_SEED, "Eros")
	var screen := _make_screen(gc)
	screen.call("run_pending_battle")
	var backdrop := screen.find_child("ArenaBackdrop", true, false) as TextureRect
	assert_object(backdrop).is_not_null()
	assert_object(backdrop.texture).is_not_null()
	assert_int(backdrop.stretch_mode).is_equal(TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	screen.queue_free()
	gc.queue_free()
	# No force in the hand-off (legacy pending shape): a wild battle still gets the eros fallback.
	var gc2 := _make_game()
	var screen2 := _make_screen(gc2)
	screen2.call("run_pending_battle")
	var fallback := screen2.find_child("ArenaBackdrop", true, false) as TextureRect
	assert_object(fallback).is_not_null()
	assert_object(fallback.texture).is_not_null()
	screen2.queue_free()
	gc2.queue_free()


func test_instant_drain_keeps_the_stage_on_living_actors() -> void:
	# Wave 10: apply_instant routes every beat's actor through stage_track/stage_acting, and the
	# terminal refresh re-stages any dead side — after a full drained battle both stage plates
	# show a member of their own team (the last living one when the side was wiped).
	var gc := _make_game()
	var screen := _make_screen(gc)
	_play_collecting_beats(screen)
	var battle: Variant = screen.call("battle")
	assert_bool(bool(battle.call("is_ended"))).is_true()
	var stage: Variant = screen.call("stage")
	assert_object(stage).is_not_null()
	for is_enemy in [false, true]:
		var shown: Variant = stage.call("shown_actor", bool(is_enemy))
		assert_object(shown).is_not_null()
		var team: Array = (
			battle.call("enemy_team") if bool(is_enemy) else battle.call("player_team")
		)
		assert_bool(team.has(shown)).is_true()
	screen.queue_free()
	gc.queue_free()


func test_verbs_are_latched_while_beats_play() -> void:
	var gc := _make_game()
	var screen := _make_screen(gc)
	var step: Dictionary = screen.call("run_pending_battle")
	assert_str(str(step.get("kind", ""))).is_equal("await_player")
	# Simulate the animated-playback latch: every player verb becomes a no-op returning last_step.
	screen.set("_beats_playing", true)
	var before: Dictionary = screen.call("last_step")
	var during: Dictionary = screen.call("player_use_skill", "Strike", 0)
	assert_str(str(during)).is_equal(str(before))
	var fled: Dictionary = screen.call("player_flee")
	assert_str(str(fled.get("kind", ""))).is_equal(str(before.get("kind", "")))
	screen.set("_beats_playing", false)
	screen.queue_free()
	gc.queue_free()
