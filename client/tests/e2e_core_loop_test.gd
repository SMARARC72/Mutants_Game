extends GdUnitTestSuite
## Phase 6 — END-TO-END core-loop integration test (headless).
##
## Drives the ENTIRE MVP loop through ONE run, through the REAL systems (no engine mocks), asserting
## state COMPOSES across the slices that were built independently:
##   new run -> overworld generates + persists -> interactive wild battle -> capture (party grows) ->
##   Lab fuse (party grows, oracle-owned) -> resonance awaken (essence) -> equip gear ->
##   Bloomwardens standing (a befriend nudges it) -> Legendary boss climax -> save -> continue (ALL
##   accumulated state intact on a FRESH controller).
##
## This is the capstone that catches CROSS-SLICE integration regressions in one test — each stage uses
## the same idioms its own slice test proved (so it composes the verified building blocks, not new code).
## Deterministic: fixed seeds + scripted choices. Capture seed reuses battle_capture_test's verified
## value (battle_seed 1 => first canonical capture roll ~0.0539 < the full-HP T1 befriend chance 0.245).

const GameControllerScript := preload("res://application/game/game_controller.gd")
const FakeDalScript := preload("res://infrastructure/dal/fake_dal.gd")
const SaveEnvelopeScript := preload("res://application/persistence/save_envelope.gd")
const EncounterCatalogScript := preload("res://application/overworld/encounter_catalog.gd")
const EncounterDirectorScript := preload("res://application/overworld/encounter_director.gd")
const BattleSessionScript := preload("res://application/battle/battle_session.gd")
const SkillBattleControllerScript := preload("res://application/battle/skill_battle_controller.gd")
const OverworldScreenScript := preload("res://presentation/overworld/overworld_screen.gd")
const BattleScreenScript := preload("res://presentation/battle/battle_screen.gd")
const LabScreenScript := preload("res://presentation/lab/lab_screen.gd")
const PartyScreenScript := preload("res://presentation/party/party_screen.gd")
const LegalitySolverScript := preload("res://infrastructure/lab/legality_solver.gd")

const E2E_SEED := 0xE2E10097
const WILD_BATTLE_SEED := 0x5117E1
const CAPTURE_SUCCESS_SEED := 1  # full-HP SB33 first capture roll succeeds (battle_capture_test)
const GEAR_ID := "luckbone_charm"  # a gear.json id with numeric effects (party_screen_test)


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


func _new_game() -> Node:
	var gc: Node = GameControllerScript.new()
	add_child(gc)
	gc.call("configure", FakeDalScript.make())
	return gc


## Drive an interactive SKILL battle to its end: each player turn use the actor's first damage skill on
## the first enemy (or its first skill if it's a pure support). Bounded.
func _play_attacking(screen: Control) -> Dictionary:
	var step: Dictionary = screen.call("run_pending_battle")
	var guard := 0
	while str(step.get("kind", "")) != "ended" and guard < 300:
		guard += 1
		if str(step.get("kind", "")) == "await_player":
			var actor: Variant = step.get("actor")
			var skill := _first_damage_skill(actor)
			if skill == "":
				var kit: Array = (actor as AbilityContainer).abilities() if actor != null else []
				skill = str(kit[0]) if not kit.is_empty() else ""
			if skill == "":
				break
			step = screen.call("player_use_skill", skill, 0)
		else:
			break
	return screen.call("result")


## The first DAMAGE skill in a combatant's kit (Strike/Drain/Gambit/Hex), else "" (pure support).
func _first_damage_skill(actor: Variant) -> String:
	if actor == null:
		return ""
	for skill: String in (actor as AbilityContainer).abilities():
		var verb := SkillBattleControllerScript.verb_of(skill)
		if not SkillBattleControllerScript.is_support_verb(verb):
			return skill
	return ""


func test_full_core_loop_composes_end_to_end() -> void:
	_clear_saves()

	# --- 1. New run ------------------------------------------------------------------------------ #
	var gc := _new_game()
	var run: RunContext = gc.call("new_run", E2E_SEED)
	assert_object(run).is_not_null()
	assert_int(run.seed).is_equal(E2E_SEED)
	assert_int(run.party.size()).is_greater(0)
	var region := str(gc.call("active_region"))
	assert_str(region).is_equal(EncounterCatalogScript.STARTING_REGION)

	# --- 2. Overworld generates + persists (reused on reload, not re-solved) ---------------------- #
	var ow: Node2D = OverworldScreenScript.new()
	ow.call("set_game", gc)
	ow.call("set_auto_hand_off", false)
	add_child(ow)
	ow.call("build_from_game")
	var layout: Variant = ow.call("layout")
	assert_object(layout).is_not_null()
	# The generated layout was persisted into the run's world_state.
	assert_bool(run.world_state.has("region_layouts")).is_true()
	assert_bool((run.world_state["region_layouts"] as Dictionary).has(region)).is_true()
	ow.queue_free()

	# --- 3. Wild encounter -> interactive battle (player drives, enemy is brain) ------------------ #
	var essence_before_battle := run.essence
	run.flags["pending_battle"] = {
		"enemy_party": [{"species_id": "SB33"}, {"species_id": "SB14"}],
		"battle_seed": WILD_BATTLE_SEED,
		"is_wild": true,
	}
	var battle: Control = BattleScreenScript.new()
	battle.call("set_game", gc)
	battle.call("set_auto_run", false)
	add_child(battle)
	var result := _play_attacking(battle)
	assert_bool(bool(result["valid"])).is_true()
	assert_int((result["transcript"] as Array).size()).is_greater(0)
	assert_bool(run.flags.has("pending_battle")).is_false()  # consumed
	# xp folds into essence on a win (loss leaves it unchanged) — either way essence never shrinks.
	assert_int(run.essence).is_greater_equal(essence_before_battle)
	battle.queue_free()

	# --- 4. Capture (success seed) grows the party by exactly one well-shaped creature ------------ #
	var party_before_catch := run.party.size()
	run.flags["pending_battle"] = {
		"enemy_party": [{"species_id": "SB33"}],
		"battle_seed": CAPTURE_SUCCESS_SEED,
		"is_wild": true,
	}
	var catch_screen: Control = BattleScreenScript.new()
	catch_screen.call("set_game", gc)
	catch_screen.call("set_auto_run", false)
	add_child(catch_screen)
	catch_screen.call("run_pending_battle")  # pump to the first player turn (full HP)
	catch_screen.call("player_capture")
	var catch_result: Dictionary = catch_screen.call("result")
	assert_str(str(catch_result["reason"])).is_equal("caught")
	assert_int(run.party.size()).is_equal(party_before_catch + 1)
	var caught: Dictionary = run.party[run.party.size() - 1]
	assert_str(str(caught["species_id"])).is_equal("SB33")
	assert_bool(bool((caught["lineage"] as Dictionary).get("captured", false))).is_true()
	catch_screen.queue_free()

	# --- 5. Lab fuse: two starter creatures -> a new spliced instance (oracle owns the numbers) --- #
	# Starter party indices 0 (SB07 Eros/Gaia) + 2 (AD10 Eros/Gaia) are a known-LEGAL fuse.
	var party_before_lab := run.party.size()
	var lab: Control = LabScreenScript.new()
	lab.call("set_game", gc)
	lab.call("set_auto_build", false)
	add_child(lab)
	lab.call("build")
	lab.call("select_op", "fuse")
	lab.call("set_creature_a", 0)
	lab.call("set_creature_b", 2)
	var lab_res: Dictionary = lab.call("commit")
	assert_int(int(lab_res["verdict"])).is_equal(LegalitySolverScript.Verdict.LEGAL)
	assert_int(run.party.size()).is_equal(party_before_lab + 1)
	var spliced: Dictionary = run.party[run.party.size() - 1]
	assert_bool(bool((spliced["lineage"] as Dictionary).get("spliced", false))).is_true()
	lab.queue_free()

	# --- 6 + 7. Party: resonance awaken (costs essence) + equip a gear slot ----------------------- #
	run.essence = 100  # fund the awaken (matches party_screen_test)
	var party_screen: Control = PartyScreenScript.new()
	party_screen.call("set_game", gc)
	party_screen.call("set_auto_build", false)
	add_child(party_screen)
	party_screen.call("build_from_game")
	party_screen.call("select_creature", 0)
	var awaken: Dictionary = party_screen.call("awaken_resonance")
	assert_bool(bool(awaken["ok"])).is_true()
	assert_int(run.essence).is_less(100)  # essence debited by the resonance cost
	assert_int(int(run.party[0].get("awakenings", 0))).is_greater(0)
	var equip: Dictionary = party_screen.call("equip_gear", GEAR_ID)
	assert_bool(bool(equip["ok"])).is_true()
	assert_str(str(run.party[0]["equipped_gear"])).is_equal(GEAR_ID)
	party_screen.queue_free()

	# --- 8. Bloomwardens standing: a befriend in the Verdant region nudges standing up ----------- #
	var party_before_befriend := run.party.size()
	(
		gc
		. call(
			"apply_battle_result",
			{"player_won": true, "caught": {"species_id": "SB18"}, "xp": 8},
		)
	)
	assert_int(int(gc.call("bloomwardens_standing"))).is_greater(0)
	assert_int(run.party.size()).is_equal(party_before_befriend + 1)  # the befriended joins too

	# --- 9. Legendary boss climax: deterministic trigger + run_boss round-trip -------------------- #
	var director: EncounterDirector = EncounterDirectorScript.for_region(
		run.seed, region, gc.call("catalog")
	)
	var boss_step := int(EncounterCatalogScript.boss_trigger_for(region)["min_steps"])
	assert_bool(director.should_trigger_boss(boss_step, false)).is_true()
	var boss_roll := director.boss_step(boss_step)
	var session: BattleSession = BattleSessionScript.new(gc.call("catalog"))
	var boss_result := session.run_boss(
		run.party,
		boss_roll["enemy_party"],
		int(boss_roll["battle_seed"]),
		str(boss_roll["boss_brain"])
	)
	assert_bool(bool(boss_result["valid"])).is_true()
	assert_bool(boss_result.has("boss_win")).is_true()
	gc.call("apply_battle_result", boss_result)  # if boss_win, the slice is marked cleared

	# --- 10. Save -> continue: ALL accumulated state survives on a FRESH controller --------------- #
	var expected_party := run.party.size()
	var expected_essence := run.essence
	var expected_standing := int(gc.call("bloomwardens_standing"))
	assert_bool(bool(gc.call("save_run"))).is_true()

	var gc2 := _new_game()
	assert_bool(bool(gc2.call("continue_run"))).is_true()
	var loaded: RunContext = gc2.call("run")
	assert_int(loaded.seed).is_equal(E2E_SEED)
	assert_int(loaded.party.size()).is_equal(expected_party)  # starter + caught + spliced + befriended
	assert_int(loaded.essence).is_equal(expected_essence)
	assert_int(int(gc2.call("bloomwardens_standing"))).is_equal(expected_standing)
	assert_str(str(loaded.party[0].get("equipped_gear", ""))).is_equal(GEAR_ID)
	assert_bool(loaded.world_state.has("region_layouts")).is_true()
	assert_bool((loaded.world_state["region_layouts"] as Dictionary).has(region)).is_true()

	gc.queue_free()
	gc2.queue_free()
	_clear_saves()
