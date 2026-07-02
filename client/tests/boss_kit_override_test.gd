extends GdUnitTestSuite
## Batch E1c — the KIT-OVERRIDE seam + a NON-VERDANT boss battle, headless:
##   * a pantheon region's lair triggers at the threshold and boss_step folds the AUTHORED
##     library-only kit into the enemy dict (kit_override) + carries the VERBATIM lines;
##   * SkillMonFactory builds the boss enemy WITH the authored kit (the application-layer
##     override); unknown skill names are dropped and a bogus override falls back to the
##     canonical force-derived kit (a malformed catalog row can never brick a creature);
##   * the verdant slice boss dict stays byte-identical (no override keys);
##   * a full interactive SKILL battle against the pantheon boss completes headless through
##     the battle screen, which carries the authored intro/defeat lines;
##   * the auto boss round-trip (run_boss) stays valid + deterministic for the new region.

const EncounterDirectorScript := preload("res://application/overworld/encounter_director.gd")
const EncounterCatalogScript := preload("res://application/overworld/encounter_catalog.gd")
const BattleSessionScript := preload("res://application/battle/battle_session.gd")
const SkillMonFactoryScript := preload("res://application/battle/skill_mon_factory.gd")
const GameControllerScript := preload("res://application/game/game_controller.gd")
const FakeDalScript := preload("res://infrastructure/dal/fake_dal.gd")
const BattleScreenScript := preload("res://presentation/battle/battle_screen.gd")
const SkillBattleControllerScript := preload("res://application/battle/skill_battle_controller.gd")

const TEST_SEED := 0xE1C_B055
const REGION := "mournmarch"  # Aidaneus, the Underlord — the Mournmarch act boss

var _catalog: SpeciesCatalog


func before() -> void:
	_catalog = SpeciesCatalog.new()


func _director() -> EncounterDirector:
	return EncounterDirectorScript.for_region(TEST_SEED, REGION, _catalog)


func _boss_roll() -> Dictionary:
	var trigger := EncounterCatalogScript.boss_trigger_for(REGION)
	return _director().boss_step(int(trigger["min_steps"]))


func test_pantheon_lair_triggers_at_threshold() -> void:
	var d := _director()
	var min_steps := int(EncounterCatalogScript.boss_trigger_for(REGION)["min_steps"])
	assert_bool(d.should_trigger_boss(min_steps - 1, false)).is_false()
	assert_bool(d.should_trigger_boss(min_steps, false)).is_true()
	assert_bool(d.should_trigger_boss(min_steps + 10, true)).is_false()  # cleared never re-fires


func test_boss_step_folds_the_authored_kit_and_lines() -> void:
	var roll := _boss_roll()
	assert_bool(roll.is_empty()).is_false()
	assert_str(str(roll["boss_id"])).is_equal("ol_10_aidaneus")
	assert_str(str(roll["intro_line"])).is_not_empty()
	assert_str(str(roll["defeat_line"])).is_not_empty()
	var member: Dictionary = (roll["enemy_party"] as Array)[0]
	# The boss keeps its AUTHORED name via the nickname (the species is a force-proxy).
	assert_str(str(member["nickname"])).is_equal("Aidaneus, the Underlord")
	var kit := BossKitCatalog.boss_by_id("ol_10_aidaneus").get("kit", []) as Array
	assert_that(member.get("kit_override")).is_equal(kit)
	# Determinism: the same (seed, region, step) rolls the same boss seed.
	assert_int(int(roll["battle_seed"])).is_equal(int(_boss_roll()["battle_seed"]))


func test_kit_override_lands_on_the_built_enemy() -> void:
	var member: Dictionary = (_boss_roll()["enemy_party"] as Array)[0]
	var ac := SkillMonFactoryScript.from_creature(member, _catalog)
	assert_object(ac).is_not_null()
	assert_that(ac.abilities()).is_equal(member["kit_override"])


func test_bogus_override_falls_back_to_the_derived_kit() -> void:
	var species: SpeciesData = _catalog.get_by_id("SB33")
	var derived := KitFactory.kit_for(species.force_primary, species.force_secondary)
	var bogus := {"species_id": "SB33", "kit_override": ["No Such Skill", "Also Fake"]}
	var ac := SkillMonFactoryScript.from_creature(bogus, _catalog)
	assert_that(ac.abilities()).is_equal(derived)
	# A partial override keeps only the REAL library names.
	var mixed := {"species_id": "SB33", "kit_override": ["Wither", "No Such Skill", "Bloom"]}
	var ac2 := SkillMonFactoryScript.from_creature(mixed, _catalog)
	assert_that(ac2.abilities()).is_equal(["Wither", "Bloom"])


func test_verdant_boss_dict_stays_byte_identical() -> void:
	var d := EncounterDirectorScript.for_region(TEST_SEED, "verdant_glut", _catalog)
	var roll := d.boss_step(30)
	var member: Dictionary = (roll["enemy_party"] as Array)[0]
	assert_bool(member.has("kit_override")).is_false()
	assert_bool(member.has("boss_id")).is_false()
	assert_str(str(roll["boss_id"])).is_equal("")
	assert_str(str(roll["intro_line"])).is_equal("")


func test_headless_boss_battle_completes_through_the_screen() -> void:
	var roll := _boss_roll()
	var gc: Node = GameControllerScript.new()
	add_child(gc)
	gc.call("configure", FakeDalScript.make())
	var run: RunContext = gc.call("new_run", TEST_SEED)
	run.flags["pending_battle"] = {
		"enemy_party": roll["enemy_party"],
		"battle_seed": int(roll["battle_seed"]),
		"is_wild": false,
		"is_boss": true,
		"boss_brain": str(roll["boss_brain"]),
		"boss_id": str(roll["boss_id"]),
		"intro_line": str(roll["intro_line"]),
		"defeat_line": str(roll["defeat_line"]),
	}
	var screen: Control = BattleScreenScript.new()
	screen.call("set_game", gc)
	screen.call("set_auto_run", false)
	add_child(screen)
	var step: Dictionary = screen.call("run_pending_battle")
	# The screen carries the AUTHORED presentation lines from the hand-off.
	assert_str(str(screen.get("_boss_intro_line"))).is_equal(str(roll["intro_line"]))
	assert_str(str(screen.get("_boss_defeat_line"))).is_equal(str(roll["defeat_line"]))
	# Drive the fight to its end (the turn cap bounds a god-rank stalemate) — it COMPLETES.
	var guard := 0
	while str(step.get("kind", "")) == "await_player" and guard < 300:
		guard += 1
		var actor: Variant = step.get("actor")
		var skill := _first_damage_skill(actor)
		if skill == "":
			step = screen.call("player_pass")
			continue
		step = screen.call("player_use_skill", skill, 0)
	var result: Dictionary = screen.call("result")
	assert_bool(bool(result["valid"])).is_true()
	assert_str(str(result["winner"])).is_not_empty()
	assert_bool(result.has("boss_win")).is_true()  # the boss path reports the climax verdict
	screen.queue_free()
	gc.queue_free()


func test_auto_boss_round_trip_is_valid_and_deterministic() -> void:
	var roll := _boss_roll()
	var session: BattleSession = BattleSessionScript.new(_catalog)
	var player := EncounterCatalogScript.starter_party()
	var a := session.run_boss(
		player, roll["enemy_party"], int(roll["battle_seed"]), str(roll["boss_brain"])
	)
	assert_bool(bool(a["valid"])).is_true()
	assert_bool(a.has("boss_win")).is_true()
	var b := session.run_boss(
		player, roll["enemy_party"], int(roll["battle_seed"]), str(roll["boss_brain"])
	)
	assert_str(str(a["transcript"])).is_equal(str(b["transcript"]))


## The first DAMAGE skill in a combatant's kit (Strike/Drain/Gambit/Hex), else "".
func _first_damage_skill(actor: Variant) -> String:
	if actor == null:
		return ""
	for skill: String in (actor as AbilityContainer).abilities():
		if not SkillBattleControllerScript.is_support_verb(
			SkillBattleControllerScript.verb_of(skill)
		):
			return skill
	return ""
