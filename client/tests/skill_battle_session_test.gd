extends GdUnitTestSuite
## BattleSession SKILL interactive round-trip (Phase 10 · Slice 2), headless.
##   * begin_skill_interactive builds AbilityContainer teams from catalog species + a SkillBattleController
##     session the wrapper drives;
##   * a scripted player-choice playthrough is DETERMINISTIC (same seed+teams+choices => same transcript);
##   * skill_result_for shapes a valid Slice-1-style result (winner / xp / turns / survivors);
##   * a capture attempt resolves the oracle chance + canonical roll, and on success caches a shaped
##     creature_instance.
## Teams come from the same catalog the production battle session uses.

const SkillBattleControllerScript := preload("res://application/battle/skill_battle_controller.gd")
const EncounterCatalogScript := preload("res://application/overworld/encounter_catalog.gd")

const SEED := 0xC0FFEE

var _catalog: SpeciesCatalog


func before() -> void:
	_catalog = SpeciesCatalog.new()


func _session_obj() -> BattleSession:
	return BattleSession.new(_catalog)


func _enemy_party() -> Array:
	return [{"species_id": "SB33"}, {"species_id": "SB14"}]


## The first DAMAGE skill in a container's kit (Strike/Drain/Gambit/Hex target a foe), or "" if the
## creature is a pure support (then the caller falls back to the neutral AI action).
func _first_damage_skill(actor: AbilityContainer) -> String:
	for skill: String in actor.abilities():
		var verb := SkillBattleControllerScript.verb_of(skill)
		if not SkillBattleControllerScript.is_support_verb(verb):
			return skill
	return ""


## Drive a skill battle to the end with a fixed policy: a player actor uses its first damage skill on
## the first alive foe, or the neutral AI action if it has none. Returns the final transcript. Bounded.
func _play_damage_first(battle: BattleSession.SkillInteractiveBattle) -> Array:
	var step := battle.advance()
	var guard := 0
	while not battle.is_ended() and guard < 5000:
		guard += 1
		if str(step.get("kind", "")) == "await_player":
			var actor := step["actor"] as AbilityContainer
			var skill := _first_damage_skill(actor)
			if skill == "":
				step = battle.act_neutral()
			else:
				step = battle.use_skill(skill, _first_alive(battle.enemy_team()))
		else:
			step = battle.advance()
	return battle.transcript()


func _first_alive(team: Array) -> AbilityContainer:
	for ac in team:
		if (ac as AbilityContainer).is_alive():
			return ac as AbilityContainer
	return null


func test_begin_skill_interactive_builds_a_drivable_battle() -> void:
	var battle := _session_obj().begin_skill_interactive(
		EncounterCatalogScript.starter_party(), _enemy_party(), SEED
	)
	assert_object(battle).is_not_null()
	assert_int(battle.player_team().size()).is_greater(0)
	assert_int(battle.enemy_team().size()).is_greater(0)
	var transcript := _play_damage_first(battle)
	assert_bool(battle.is_ended()).is_true()
	# A real battle ran: at least a turn header + a RESULT line.
	assert_int(transcript.size()).is_greater(2)
	assert_str(str(transcript[transcript.size() - 1])).starts_with("RESULT:")


func test_skill_result_for_shapes_a_valid_result() -> void:
	var session := _session_obj()
	var battle := session.begin_skill_interactive(
		EncounterCatalogScript.starter_party(), _enemy_party(), SEED
	)
	_play_damage_first(battle)
	var result := session.skill_result_for(battle.session(), battle.caught())
	assert_bool(bool(result["valid"])).is_true()
	assert_array(["player", "enemy", "fled"]).contains([str(result["winner"])])
	assert_int(int(result["turns"])).is_greater(0)
	assert_bool(result.has("xp")).is_true()
	assert_bool(result.has("transcript")).is_true()


func test_skill_battle_playthrough_is_deterministic() -> void:
	var a := _session_obj().begin_skill_interactive(
		EncounterCatalogScript.starter_party(), _enemy_party(), SEED
	)
	var log_a := _play_damage_first(a)
	var b := _session_obj().begin_skill_interactive(
		EncounterCatalogScript.starter_party(), _enemy_party(), SEED
	)
	var log_b := _play_damage_first(b)
	assert_int(log_a.size()).is_equal(log_b.size())
	for i in range(log_a.size()):
		assert_str(str(log_a[i])).is_equal(str(log_b[i]))


func test_capture_attempt_resolves_chance_and_roll() -> void:
	var battle := _session_obj().begin_skill_interactive(
		EncounterCatalogScript.starter_party(), _enemy_party(), SEED
	)
	# Pump to the first player decision, then attempt a capture on the first wild foe.
	var step := battle.advance()
	var guard := 0
	while str(step.get("kind", "")) != "await_player" and not battle.is_ended() and guard < 500:
		guard += 1
		step = battle.advance()
	assert_str(str(step.get("kind", ""))).is_equal("await_player")
	battle.attempt_capture(_first_alive(battle.enemy_team()), [])
	var cap := battle.last_capture()
	assert_bool(cap.has("success")).is_true()
	assert_float(float(cap["chance"])).is_between(0.0, 1.0)
	assert_float(float(cap["roll"])).is_between(0.0, 1.0)
	# On success the caught instance is shaped with a species id; on failure it stays empty.
	if bool(cap["success"]):
		assert_str(str(battle.caught().get("species_id", ""))).is_not_empty()
		assert_bool(battle.is_ended()).is_true()


func test_unassemblable_team_returns_null() -> void:
	# An enemy party of unknown species ids yields no team -> null wrapper (caller handles the gap).
	var battle := _session_obj().begin_skill_interactive(
		EncounterCatalogScript.starter_party(), [{"species_id": "NOPE_NOT_REAL"}], SEED
	)
	assert_object(battle).is_null()
