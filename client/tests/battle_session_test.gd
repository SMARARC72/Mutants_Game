extends GdUnitTestSuite
## Phase 5 · Slice 1 — BattleSession round-trip DoD, headless.
##   * a battle round-trip returns a structured RESULT (winner / survivors / xp / transcript) via
##     the BattleController (the transcript carries the controller's RESULT line);
##   * it is DETERMINISTIC: same battle seed + same teams -> identical result + transcript;
##   * an invalid team (unknown species id) returns a graceful invalid result, never a crash;
##   * the MonFactory builds a Mon from a catalog species id.
## Pure RefCounted/domain wiring — no scene, canonical RNG only.

const BattleSessionScript := preload("res://application/battle/battle_session.gd")
const MonFactoryScript := preload("res://application/battle/mon_factory.gd")
const EncounterCatalogScript := preload("res://application/overworld/encounter_catalog.gd")

const BATTLE_SEED := 0xB47711E

var _catalog: SpeciesCatalog


func before() -> void:
	_catalog = SpeciesCatalog.new()


func _player_party() -> Array:
	return EncounterCatalogScript.starter_party()


func _enemy_party() -> Array:
	return [{"species_id": "SB33"}, {"species_id": "SB14"}]


func test_round_trip_returns_a_result_via_controller() -> void:
	var session: BattleSession = BattleSessionScript.new(_catalog)
	var result := session.run(_player_party(), _enemy_party(), BATTLE_SEED)
	assert_bool(bool(result["valid"])).is_true()
	assert_str(str(result["winner"])).is_not_empty()
	assert_bool(result["winner"] == "player" or result["winner"] == "enemy").is_true()
	assert_int(int(result["turns"])).is_greater(0)
	# The transcript is the BattleController's log; its final line is the RESULT summary.
	var transcript: Array = result["transcript"]
	assert_int(transcript.size()).is_greater(0)
	assert_str(str(transcript[transcript.size() - 1])).starts_with("RESULT:")


func test_round_trip_is_deterministic() -> void:
	var session: BattleSession = BattleSessionScript.new(_catalog)
	var a := session.run(_player_party(), _enemy_party(), BATTLE_SEED)
	var b := session.run(_player_party(), _enemy_party(), BATTLE_SEED)
	assert_str(str(a["winner"])).is_equal(str(b["winner"]))
	assert_int(int(a["turns"])).is_equal(int(b["turns"]))
	assert_int(int(a["xp"])).is_equal(int(b["xp"]))
	# Byte-identical transcripts (the canonical-RNG determinism guarantee).
	assert_str(str(a["transcript"])).is_equal(str(b["transcript"]))


func test_different_seed_can_change_transcript() -> void:
	# The transcript is a function of the seed (crit/overload rolls differ), so across a spread of
	# seeds at least one must diverge from the baseline. Robust to the rare case where one offset
	# happens to reproduce the baseline's rolls.
	var session: BattleSession = BattleSessionScript.new(_catalog)
	var base := str(session.run(_player_party(), _enemy_party(), BATTLE_SEED)["transcript"])
	var any_differs := false
	for offset in [1, 7, 13, 101, 9999]:
		var other := str(
			session.run(_player_party(), _enemy_party(), BATTLE_SEED + offset)["transcript"]
		)
		if other != base:
			any_differs = true
			break
	assert_bool(any_differs).is_true()


func test_invalid_team_returns_graceful_result() -> void:
	var session: BattleSession = BattleSessionScript.new(_catalog)
	var result := session.run([{"species_id": "NOPE-missing"}], _enemy_party(), BATTLE_SEED)
	assert_bool(bool(result["valid"])).is_false()
	assert_bool(bool(result["player_won"])).is_false()
	assert_int((result["transcript"] as Array).size()).is_equal(0)


## A minimal stand-in for a FINISHED SkillBattleController.InteractiveSession (duck-typed — the
## real skill_result_for reads exactly these members), so the stalemate contract is testable
## without steering a live battle into the turn cap.
class StubSkillSession:
	extends RefCounted

	var team_a: Array = []
	var team_b: Array = []
	var reason := "enemy_defeated"

	func player_team() -> Array:
		return team_a

	func enemy_team() -> Array:
		return team_b

	func end_reason() -> String:
		return reason

	func player_won() -> bool:
		for ac in team_a:
			if (ac as AbilityContainer).is_alive():
				return true
		return false

	func turn() -> int:
		return 10

	func transcript() -> Array:
		return ["RESULT: TEAM A wins (turn 10)"]


func test_skill_result_flags_stalemate_and_halves_the_reward() -> void:
	# Wave 3 honesty: END_DEFEAT with BOTH sides standing (the turn cap expired) is a STALEMATE —
	# flagged on the result, and the spoils are HALVED (reduced reward). A genuine wipe stays a
	# full-reward, non-stalemate win.
	var stub := StubSkillSession.new()
	var ally: AbilityContainer = SkillMonFactory.from_creature({"species_id": "SB07"}, _catalog)
	var foe_down: AbilityContainer = SkillMonFactory.from_creature({"species_id": "SB33"}, _catalog)
	var foe_up: AbilityContainer = SkillMonFactory.from_creature({"species_id": "SB14"}, _catalog)
	foe_down.set_hp(0)
	stub.team_a = [ally]
	stub.team_b = [foe_down, foe_up]
	var session: BattleSession = BattleSessionScript.new(_catalog)

	var result := session.skill_result_for(stub)
	assert_bool(bool(result["stalemate"])).is_true()
	assert_bool(bool(result["player_won"])).is_true()
	# One downed foe would pay 12 xp; the stalemate halves it.
	assert_int(int(result["xp"])).is_equal(int(BattleSessionScript.XP_PER_DEFEAT / 2.0))
	assert_int((result["enemy_survivors"] as Array).size()).is_equal(1)

	# A clean wipe of the same team is NOT a stalemate and pays in full.
	foe_up.set_hp(0)
	var win := session.skill_result_for(stub)
	assert_bool(bool(win["stalemate"])).is_false()
	assert_int(int(win["xp"])).is_equal(BattleSessionScript.XP_PER_DEFEAT * 2)


func test_mon_factory_builds_from_catalog_species() -> void:
	var mon: BattleEngine.Mon = MonFactoryScript.from_creature({"species_id": "SB07"}, _catalog)
	assert_object(mon).is_not_null()
	assert_str(mon.name).is_equal("Leaf-hare")
	assert_str(mon.prim).is_equal("Eros")
	assert_int(mon.maxhp).is_greater(0)
	assert_bool(mon.alive).is_true()
	# A nickname overrides the species display name.
	var nicked: BattleEngine.Mon = MonFactoryScript.from_creature(
		{"species_id": "SB07", "nickname": "Hopper"}, _catalog
	)
	assert_str(nicked.name).is_equal("Hopper")
	# An unknown id yields null (caller skips it).
	assert_object(MonFactoryScript.from_creature({"species_id": "ZZZZ"}, _catalog)).is_null()
