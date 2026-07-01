extends GdUnitTestSuite
## Phase 5 · Slice 4 — the LEGENDARY-BOSS trigger + fight DoD, headless.
##   * the boss trigger fires DETERMINISTICALLY: it does NOT fire before min_steps, fires at/after it,
##     and never fires once the slice is cleared;
##   * boss_step builds a VALID boss team (a single real Legendary creature) + a battle seed, and the
##     seed is reproducible for a fixed (run seed, region, step);
##   * the BattleSession boss round-trip runs the boss via the strong role brain and returns a
##     structured result carrying `boss_win`.
## Pure RefCounted logic — no scene, canonical RNG only.

const EncounterDirectorScript := preload("res://application/overworld/encounter_director.gd")
const EncounterCatalogScript := preload("res://application/overworld/encounter_catalog.gd")
const BattleSessionScript := preload("res://application/battle/battle_session.gd")

const TEST_SEED := 0xB0550001
const REGION := "verdant_glut"

var _catalog: SpeciesCatalog


func before() -> void:
	_catalog = SpeciesCatalog.new()


func _director() -> EncounterDirector:
	return EncounterDirectorScript.for_region(TEST_SEED, REGION, _catalog)


func test_boss_does_not_trigger_before_min_steps() -> void:
	var trigger := EncounterCatalogScript.boss_trigger_for(REGION)
	var min_steps := int(trigger["min_steps"])
	var d := _director()
	# A step well below the threshold must NOT trigger the climax.
	assert_bool(d.should_trigger_boss(min_steps - 1, false)).is_false()
	assert_bool(d.should_trigger_boss(0, false)).is_false()


func test_boss_triggers_at_or_after_min_steps() -> void:
	var trigger := EncounterCatalogScript.boss_trigger_for(REGION)
	var min_steps := int(trigger["min_steps"])
	var d := _director()
	assert_bool(d.should_trigger_boss(min_steps, false)).is_true()
	assert_bool(d.should_trigger_boss(min_steps + 5, false)).is_true()


func test_boss_never_triggers_once_cleared() -> void:
	var trigger := EncounterCatalogScript.boss_trigger_for(REGION)
	var min_steps := int(trigger["min_steps"])
	var d := _director()
	# already_cleared = true -> never fires, even past the threshold.
	assert_bool(d.should_trigger_boss(min_steps + 100, true)).is_false()


func test_boss_lair_is_one_shot_via_the_fired_flag() -> void:
	# Wave 3: the climax is a ONE-SHOT lair trigger. Once it has ambushed (already_fired), it never
	# re-fires on later steps — even while the slice is still uncleared (a lost/fled boss fight).
	var trigger := EncounterCatalogScript.boss_trigger_for(REGION)
	var min_steps := int(trigger["min_steps"])
	var d := _director()
	assert_bool(d.should_trigger_boss(min_steps, false, true)).is_false()
	assert_bool(d.should_trigger_boss(min_steps + 50, false, true)).is_false()
	# The default (not yet fired) still triggers at the threshold — the added flag changed nothing.
	assert_bool(d.should_trigger_boss(min_steps, false)).is_true()


func test_boss_step_builds_a_valid_legendary_team() -> void:
	var d := _director()
	var step := int(EncounterCatalogScript.boss_trigger_for(REGION)["min_steps"])
	var roll := d.boss_step(step)
	assert_bool(roll.is_empty()).is_false()
	assert_bool(bool(roll["boss"])).is_true()
	var party: Array = roll["enemy_party"]
	assert_int(party.size()).is_equal(1)
	var sid := str((party[0] as Dictionary)["species_id"])
	var species: SpeciesData = _catalog.get_by_id(sid)
	assert_object(species).is_not_null()
	assert_str(species.rank).is_equal("legendary")
	assert_str(str(roll["boss_brain"])).is_not_empty()


func test_boss_seed_is_deterministic() -> void:
	var step := int(EncounterCatalogScript.boss_trigger_for(REGION)["min_steps"])
	var a := _director().boss_step(step)
	var b := _director().boss_step(step)
	assert_int(int(a["battle_seed"])).is_equal(int(b["battle_seed"]))
	# A different step (or run seed) yields a different boss seed (it is seed-sensitive).
	var c := _director().boss_step(step + 1)
	assert_int(int(a["battle_seed"])).is_not_equal(int(c["battle_seed"]))


func test_boss_battle_round_trip_returns_boss_result() -> void:
	var d := _director()
	var step := int(EncounterCatalogScript.boss_trigger_for(REGION)["min_steps"])
	var roll := d.boss_step(step)
	var session: BattleSession = BattleSessionScript.new(_catalog)
	var player := EncounterCatalogScript.starter_party()
	var result := session.run_boss(
		player, roll["enemy_party"], int(roll["battle_seed"]), str(roll["boss_brain"])
	)
	assert_bool(bool(result["valid"])).is_true()
	assert_bool(result.has("boss_win")).is_true()
	assert_int(int(result["turns"])).is_greater(0)
	# Determinism: same inputs -> identical result.
	var result2 := session.run_boss(
		player, roll["enemy_party"], int(roll["battle_seed"]), str(roll["boss_brain"])
	)
	assert_str(str(result["transcript"])).is_equal(str(result2["transcript"]))


func test_invalid_boss_team_returns_graceful_result() -> void:
	var session: BattleSession = BattleSessionScript.new(_catalog)
	var result := session.run_boss(
		EncounterCatalogScript.starter_party(), [{"species_id": "NOPE_404"}], 123, "controller"
	)
	assert_bool(bool(result["valid"])).is_false()
	assert_bool(bool(result["boss_win"])).is_false()
