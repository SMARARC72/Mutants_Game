extends GdUnitTestSuite
## Wave 10 — "Battle Stage & Impact" DoD, driven HEADLESSLY (instant/drain mode, no awaits):
##   * the STAGE builds: player plate bottom-left, enemy plate top-right, both showing real
##     textures at ~2.6x card scale, over the arena backdrop;
##   * plates TRACK actors: the awaiting player actor is staged; targeting stages the victim;
##     the instant drain routes every beat's actor through stage_track;
##   * BOSS dressing: a full-width threat bar tracking the boss side's HP + a name splash that
##     never animates (built, text set, hidden) under the instant contract;
##   * FORCE LEGIBILITY (Wave 10 commit 2): matchup badges come from the controller's THIN
##     SkillEngine read (never UI math) and land on the target picker exactly when non-neutral;
##   * JUICE: the JuiceDirector autoload records every routed call headless while performing
##     NO visual work (no labels, no timescale dips) — the no-op-but-recorded contract.

const GameControllerScript := preload("res://application/game/game_controller.gd")
const FakeDalScript := preload("res://infrastructure/dal/fake_dal.gd")
const BattleScreenScript := preload("res://presentation/battle/battle_screen.gd")
const BattleStageScript := preload("res://presentation/battle/battle_stage.gd")
const BattleCardKitScript := preload("res://presentation/battle/battle_card_kit.gd")
const SkillBattleControllerScript := preload("res://application/battle/skill_battle_controller.gd")

const TEST_SEED := 0xBA771E5
const BATTLE_SEED := 0x5117E1
const ENEMY_PARTY := [{"species_id": "SB33"}, {"species_id": "SB14"}]


func _make_game(pending_extra: Dictionary = {}) -> Node:
	var gc: Node = GameControllerScript.new()
	add_child(gc)
	gc.call("configure", FakeDalScript.make())
	var run: RunContext = gc.call("new_run", TEST_SEED)
	var pending := {
		"enemy_party": ENEMY_PARTY.duplicate(true),
		"battle_seed": BATTLE_SEED,
		"is_wild": true,
	}
	pending.merge(pending_extra, true)
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


func _stage_of(screen: Control) -> BattleStageScript:
	return screen.find_child("BattleStage", true, false) as BattleStageScript


func test_stage_builds_both_plates_over_the_backdrop() -> void:
	var gc := _make_game({"force": "Eros"})
	var screen := _make_screen(gc)
	var step: Dictionary = screen.call("run_pending_battle")
	assert_str(str(step.get("kind", ""))).is_equal("await_player")
	var stage := _stage_of(screen)
	assert_object(stage).is_not_null()
	# The arena backdrop now lives INSIDE the stage layer (below the plates).
	assert_object(stage.find_child("ArenaBackdrop", false, false)).is_not_null()
	# Both plates exist, sized at stage scale, and show a real creature texture.
	for is_enemy in [false, true]:
		var plate: LivingPlate = stage.plate(bool(is_enemy))
		assert_object(plate).is_not_null()
		assert_object(plate.texture()).is_not_null()
		assert_vector(plate.custom_minimum_size).is_equal(BattleStageScript.PLATE_SIZE)
	# Player plate hugs the bottom-left corner; enemy plate the top-right (anchor presets).
	assert_float(stage.plate(false).anchor_top).is_equal(1.0)
	assert_float(stage.plate(false).anchor_left).is_equal(0.0)
	assert_float(stage.plate(true).anchor_top).is_equal(0.0)
	assert_float(stage.plate(true).anchor_left).is_equal(1.0)
	screen.queue_free()
	gc.queue_free()


func test_plates_track_the_awaiting_actor_and_the_chosen_target() -> void:
	var gc := _make_game()
	var screen := _make_screen(gc)
	var step: Dictionary = screen.call("run_pending_battle")
	var stage := _stage_of(screen)
	var battle: Variant = screen.call("battle")
	# The awaiting player actor is staged on the player side the moment the menu opens.
	assert_object(stage.shown_actor(false)).is_equal(step.get("actor"))
	# Explicit tracking: staging a specific foe swaps the enemy plate to it.
	var foes: Array = battle.call("enemy_team")
	screen.call("stage_track", foes[1])
	assert_object(stage.shown_actor(true)).is_equal(foes[1])
	assert_object(stage.plate_of(foes[1])).is_equal(stage.plate(true))
	assert_object(stage.plate_of(foes[0])).is_null()
	# Playing a damage skill at foe 0 re-stages the victim, then the drain routes every beat's
	# actor through stage_track — the enemy plate ends on a live enemy-team member.
	var skill := _first_damage_skill(step.get("actor"))
	assert_str(skill).is_not_empty()
	screen.call("player_use_skill", skill, 0)
	var shown: Variant = stage.shown_actor(true)
	assert_object(shown).is_not_null()
	assert_bool(foes.has(shown)).is_true()
	screen.queue_free()
	gc.queue_free()


func test_dead_staged_actor_is_replaced_by_first_living_teammate() -> void:
	var gc := _make_game()
	var screen := _make_screen(gc)
	screen.call("run_pending_battle")
	var stage := _stage_of(screen)
	var battle: Variant = screen.call("battle")
	var foes: Array = battle.call("enemy_team")
	# Kill the staged foe directly, then refresh: the stage swaps to the first living teammate.
	screen.call("stage_track", foes[0])
	(foes[0] as AbilityContainer).set_hp(0)
	screen.call("_refresh_combatants")
	assert_object(stage.shown_actor(true)).is_equal(foes[1])
	screen.queue_free()
	gc.queue_free()


func test_boss_battle_dresses_the_stage() -> void:
	var gc := _make_game({"is_wild": false, "is_boss": true, "boss_brain": "controller"})
	var screen := _make_screen(gc)
	screen.call("run_pending_battle")
	var stage := _stage_of(screen)
	var battle: Variant = screen.call("battle")
	# Full-width boss threat bar: sums the boss side's live HP (a boss with adds reads as one bar).
	var bar := stage.find_child("BossBar", true, false) as ProgressBar
	assert_object(bar).is_not_null()
	var total := 0
	var total_max := 0
	for ac_v in battle.call("enemy_team"):
		total += maxi(0, (ac_v as AbilityContainer).hp())
		total_max += (ac_v as AbilityContainer).max_hp()
	assert_int(int(bar.value)).is_equal(total)
	assert_int(int(bar.max_value)).is_equal(total_max)
	# Name splash: text landed (Cinzel TitleLabel), but the instant contract keeps it hidden —
	# no timer/tween may ever block a headless suite.
	var splash_name := stage.find_child("BossSplashName", true, false) as Label
	assert_object(splash_name).is_not_null()
	var first_enemy := battle.call("enemy_team")[0] as AbilityContainer
	assert_str(splash_name.text).is_equal(first_enemy.combatant_name())
	assert_bool(stage.splash_active()).is_false()
	screen.queue_free()
	gc.queue_free()


func test_wild_battle_has_no_boss_dressing() -> void:
	var gc := _make_game()
	var screen := _make_screen(gc)
	screen.call("run_pending_battle")
	var stage := _stage_of(screen)
	assert_object(stage.find_child("BossBar", true, false)).is_null()
	assert_object(stage.find_child("BossSplash", true, false)).is_null()
	screen.queue_free()
	gc.queue_free()


func test_matchup_badges_read_the_engine_table() -> void:
	# A Thanatos foe (SB10) against the Eros starters — a KNOWN opposed pair. The badge chain is
	# controller (thin SkillEngine read) -> BattleCardKit.matchup_badge -> target-picker chips.
	var gc := _make_game({"enemy_party": [{"species_id": "SB10"}, {"species_id": "SB14"}]})
	var screen := _make_screen(gc)
	var step: Dictionary = screen.call("run_pending_battle")
	var battle: Variant = screen.call("battle")
	var foes: Array = battle.call("enemy_team")
	var eros: AbilityContainer = null
	for ac_v in battle.call("player_team"):
		if (ac_v as AbilityContainer).primary_force() == "Eros":
			eros = ac_v
	assert_object(eros).is_not_null()
	# The thin accessor surfaces the ENGINE multiplier: Eros overwhelms Thanatos at 1.5.
	assert_float(SkillBattleControllerScript.matchup_mult(eros, foes[0])).is_equal(1.5)
	# The badge dictionary is glyph + WORD + colour (grayscale-safe), {} when neutral.
	assert_str(str(BattleCardKitScript.matchup_badge(1.5)["text"])).is_equal("▲ OVERWHELMS")
	assert_str(str(BattleCardKitScript.matchup_badge(0.7)["text"])).is_equal("▼ resisted")
	assert_bool(BattleCardKitScript.matchup_badge(1.0).is_empty()).is_true()
	# UI wiring: each target button carries the chip exactly when the engine says non-neutral.
	var actor := step.get("actor") as AbilityContainer
	var skill := _first_damage_skill(actor)
	assert_str(skill).is_not_empty()
	screen.call("show_target_picker", skill)
	var picker: Control = screen.find_child("TargetPicker", true, false)
	var checked := 0
	for btn in picker.get_children():
		if not (btn is Button):
			continue
		var idx := int(str(btn.name).trim_prefix("Target"))
		var mult: float = SkillBattleControllerScript.matchup_mult(actor, foes[idx])
		var chip := (btn as Button).find_child("MatchupBadge", false, false) as Label
		if mult == 1.0:
			assert_object(chip).is_null()
		else:
			assert_object(chip).is_not_null()
			var badge: Dictionary = BattleCardKitScript.matchup_badge(mult)
			assert_str(chip.text).is_equal(str(badge["text"]))
		checked += 1
	assert_int(checked).is_greater(0)
	screen.queue_free()
	gc.queue_free()


func test_juice_director_headless_noops_are_recorded() -> void:
	var juice := get_node_or_null("/root/Juice")
	assert_object(juice).is_not_null()
	juice.call("clear_recorded")
	var gc := _make_game()
	var screen := _make_screen(gc)
	var step: Dictionary = screen.call("run_pending_battle")
	# Drive damaging actions until something lands (deterministic fixed-seed walk).
	var guard := 0
	while str(step.get("kind", "")) == "await_player" and guard < 60:
		guard += 1
		var skill := _first_damage_skill(step.get("actor"))
		if skill == "":
			break
		step = screen.call("player_use_skill", skill, 0)
		if int(juice.call("recorded", "pop_number")) > 0:
			break
	# The drain routed the impact stack through the director: the pop + the plate hit flash
	# were RECORDED... (the headless bookkeeping suites hang assertions on)
	assert_int(int(juice.call("recorded", "pop_number"))).is_greater(0)
	assert_int(int(juice.call("recorded", "hit"))).is_greater(0)
	# ...but NO-OPPED visually: no floating labels, no timescale dip, no pacing juice on the
	# instant path (hitstop/shake/lunge stay un-routed entirely while instant).
	assert_float(Engine.time_scale).is_equal(1.0)
	assert_int((screen.call("fx_layer") as Control).get_child_count()).is_equal(0)
	assert_int(int(juice.call("recorded", "hitstop"))).is_equal(0)
	assert_int(int(juice.call("recorded", "shake"))).is_equal(0)
	screen.queue_free()
	gc.queue_free()


func test_acting_outline_rides_the_staged_plate() -> void:
	var gc := _make_game()
	var screen := _make_screen(gc)
	var step: Dictionary = screen.call("run_pending_battle")
	var stage := _stage_of(screen)
	# The awaiting player actor is outlined in brass on its stage plate; the enemy side is not.
	var actor: Variant = step.get("actor")
	assert_object(stage.plate_of(actor)).is_not_null()
	var mat := stage.plate_of(actor).plate_material()
	assert_float(float(mat.get_shader_parameter("outline_width"))).is_equal(
		BattleStageScript.ACTING_OUTLINE
	)
	var other := stage.plate(true)
	assert_float(float(other.plate_material().get_shader_parameter("outline_width"))).is_equal(0.0)
	screen.queue_free()
	gc.queue_free()
