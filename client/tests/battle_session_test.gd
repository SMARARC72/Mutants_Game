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
