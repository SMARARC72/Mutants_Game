extends GdUnitTestSuite
## Phase 5 · Slice 2 — INTERACTIVE BattleController DoD (the step-wise seam), headless.
##   * the interactive session resolves strikes through the SAME RES/SEL streams as the auto run() —
##     so when the player mirrors the neutral brain (always first-alive target) the interactive
##     transcript is BYTE-IDENTICAL to run() (the seam adds no perturbation, parity preserved);
##   * a scripted player-choice sequence is DETERMINISTIC (same seed+teams+choices => same transcript);
##   * the auto run() still equals BattleEngine.simulate (the Slice 1 parity contract is intact);
##   * a player FLEE ends the battle immediately; CAPTURE success/failure are driven by the caller.
## Teams are built from catalog species (the same MonFactory the battle session uses).

const CombatBrainScript := preload("res://application/ai/combat_brain.gd")
const BattleControllerScript := preload("res://application/battle/battle_controller.gd")
const MonFactoryScript := preload("res://application/battle/mon_factory.gd")
const EncounterCatalogScript := preload("res://application/overworld/encounter_catalog.gd")

const SEED := 0xC0FFEE

var _catalog: SpeciesCatalog


func before() -> void:
	_catalog = SpeciesCatalog.new()


func _player_team() -> Array:
	return MonFactoryScript.team_from_creatures(EncounterCatalogScript.starter_party(), _catalog)


func _enemy_team() -> Array:
	return MonFactoryScript.team_from_creatures(
		[{"species_id": "SB33"}, {"species_id": "SB14"}], _catalog
	)


## First alive foe in a team (the neutral brain's policy), or null.
func _first_alive(team: Array) -> BattleEngine.Mon:
	for m in team:
		if (m as BattleEngine.Mon).alive:
			return m as BattleEngine.Mon
	return null


## Drive an interactive session where the player always attacks the first alive enemy (mirroring the
## neutral brain). Returns the final transcript. Bounded so a stuck pump fails fast.
func _play_neutral(session: BattleController.InteractiveSession) -> Array:
	var step := session.advance()
	var guard := 0
	while str(step.get("kind", "")) != "ended" and guard < 500:
		guard += 1
		if str(step.get("kind", "")) == "await_player":
			step = session.attack(_first_alive(session.enemy_team()))
		else:
			step = session.advance()
	return session.transcript()


func test_interactive_neutral_player_matches_auto_run() -> void:
	# run() with the neutral brain (player side A also neutral) is the baseline.
	var brain_auto := CombatBrainScript.new()
	var ctrl_auto := BattleControllerScript.new(brain_auto, CanonicalRNG.new(SEED))
	var auto_log: Array = ctrl_auto.run(_player_team(), _enemy_team())

	# The interactive session with the player choosing first-alive each turn must reproduce it
	# byte-for-byte: the seam draws the SAME RES/SEL streams in the SAME order.
	var brain_int := CombatBrainScript.new()
	var ctrl_int := BattleControllerScript.new(brain_int, CanonicalRNG.new(SEED))
	var session := ctrl_int.interactive(_player_team(), _enemy_team(), "A")
	var int_log := _play_neutral(session)

	assert_int(int_log.size()).is_equal(auto_log.size())
	for i in range(mini(int_log.size(), auto_log.size())):
		assert_str(str(int_log[i])).is_equal(str(auto_log[i]))


## Parity must hold ACROSS battle shapes (not just one seed): the per-turn blank-line separator is
## the easy thing to get wrong, and a one-off shift only shows on some seeds. Sweep several seeds and
## assert the interactive (neutral-player) transcript is element-for-element equal to run().
func test_interactive_matches_run_across_seeds() -> void:
	for seed in [0, 1, 7, 42, 0xC0FFEE, 0xBEEF, 12345]:
		var auto_log: Array = (
			BattleControllerScript
			. new(CombatBrainScript.new(), CanonicalRNG.new(seed))
			. run(_player_team(), _enemy_team())
		)
		var session := (
			BattleControllerScript
			. new(CombatBrainScript.new(), CanonicalRNG.new(seed))
			. interactive(_player_team(), _enemy_team(), "A")
		)
		var int_log := _play_neutral(session)
		assert_int(int_log.size()).is_equal(auto_log.size())
		for i in range(mini(int_log.size(), auto_log.size())):
			assert_str(str(int_log[i])).is_equal(str(auto_log[i]))


## A battle that ends MID-TURN (a killing strike wipes the foe before the turn's remaining actors
## act) must still match run() — the in-progress turn gets exactly ONE trailing blank then RESULT,
## with no extra/missing separator. A strong player team vs a single weak foe forces an early wipe.
func test_interactive_matches_run_on_midturn_kill() -> void:
	var strong := MonFactoryScript.team_from_creatures(
		[{"species_id": "AD10"}, {"species_id": "AD10"}], _catalog
	)
	var weak := MonFactoryScript.team_from_creatures([{"species_id": "SB33"}], _catalog)
	var strong2 := MonFactoryScript.team_from_creatures(
		[{"species_id": "AD10"}, {"species_id": "AD10"}], _catalog
	)
	var weak2 := MonFactoryScript.team_from_creatures([{"species_id": "SB33"}], _catalog)

	var auto_log: Array = (
		BattleControllerScript
		. new(CombatBrainScript.new(), CanonicalRNG.new(SEED))
		. run(strong, weak)
	)
	var session := (
		BattleControllerScript
		. new(CombatBrainScript.new(), CanonicalRNG.new(SEED))
		. interactive(strong2, weak2, "A")
	)
	var int_log := _play_neutral(session)
	assert_int(int_log.size()).is_equal(auto_log.size())
	for i in range(mini(int_log.size(), auto_log.size())):
		assert_str(str(int_log[i])).is_equal(str(auto_log[i]))


func test_interactive_scripted_choices_are_deterministic() -> void:
	var brain_a := CombatBrainScript.new()
	var sess_a := BattleControllerScript.new(brain_a, CanonicalRNG.new(SEED)).interactive(
		_player_team(), _enemy_team(), "A"
	)
	var log_a := _play_neutral(sess_a)

	var brain_b := CombatBrainScript.new()
	var sess_b := BattleControllerScript.new(brain_b, CanonicalRNG.new(SEED)).interactive(
		_player_team(), _enemy_team(), "A"
	)
	var log_b := _play_neutral(sess_b)

	assert_int(log_a.size()).is_equal(log_b.size())
	for i in range(log_a.size()):
		assert_str(str(log_a[i])).is_equal(str(log_b[i]))


func test_auto_run_still_equals_simulate() -> void:
	# The Slice 1 parity contract: run() with neutral brain == simulate() fed the SAME RES sub-stream.
	var sim_log: Array = BattleEngine.simulate(
		_player_team(), _enemy_team(), BattleControllerScript.resolution_rng(CanonicalRNG.new(SEED))
	)
	var brain := CombatBrainScript.new()
	var ctrl := BattleControllerScript.new(brain, CanonicalRNG.new(SEED))
	var run_log: Array = ctrl.run(_player_team(), _enemy_team())

	assert_int(run_log.size()).is_equal(sim_log.size())
	for i in range(mini(run_log.size(), sim_log.size())):
		assert_str(str(run_log[i])).is_equal(str(sim_log[i]))


func test_player_flee_ends_the_battle_immediately() -> void:
	var brain := CombatBrainScript.new()
	var session := BattleControllerScript.new(brain, CanonicalRNG.new(SEED)).interactive(
		_player_team(), _enemy_team(), "A"
	)
	var first := session.advance()
	assert_str(str(first.get("kind", ""))).is_equal("await_player")
	var ended := session.flee()
	assert_str(str(ended.get("kind", ""))).is_equal("ended")
	assert_str(str(ended.get("reason", ""))).is_equal("fled")
	assert_bool(session.is_ended()).is_true()
	# The transcript closes with the simulate()-format RESULT line.
	var t: Array = session.transcript()
	assert_str(str(t[t.size() - 1])).starts_with("RESULT:")


func test_capture_failure_continues_the_pump() -> void:
	# A failed capture (success=false passed to session.capture) consumes the player's turn WITHOUT
	# drawing the RES stream; the pump advances so the next actor (ally or enemy) acts.
	var brain := CombatBrainScript.new()
	var session := BattleControllerScript.new(brain, CanonicalRNG.new(SEED)).interactive(
		_player_team(), _enemy_team(), "A"
	)
	session.advance()  # to the first player turn
	var step := session.capture(false)
	assert_str(str(step.get("kind", ""))).is_not_equal("ended")  # the battle continues
	assert_bool(session.is_ended()).is_false()


func test_capture_success_ends_as_caught() -> void:
	var brain := CombatBrainScript.new()
	var session := BattleControllerScript.new(brain, CanonicalRNG.new(SEED)).interactive(
		_player_team(), _enemy_team(), "A"
	)
	session.advance()
	var step := session.capture(true)
	assert_str(str(step.get("kind", ""))).is_equal("ended")
	assert_str(str(step.get("reason", ""))).is_equal("caught")
	assert_bool(session.player_won()).is_true()
