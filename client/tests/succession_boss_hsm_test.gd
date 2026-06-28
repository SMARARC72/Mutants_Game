extends GdUnitTestSuite
## Succession boss HSM phase-gate transitions (ADR-016, Integrations §A2).
##
## Proves the boss HSM (Opening -> Pressure -> Desperation -> Apotheosis) advances on the
## BLACKBOARD gates the controller writes each turn: turn count, own HP%, squad losses, the entropy
## clock. Transitions are pure reads of those gates in authored (priority) order, so the phase path
## is a deterministic function of the battle state — the basis of replayable boss decisions.

const HsmScript := preload("res://application/ai/hsm.gd")
const BlackboardScript := preload("res://application/ai/blackboard.gd")
const RngServiceScript := preload("res://application/ai/rng_service.gd")
const SuccessionBossScript := preload("res://application/ai/succession_boss.gd")
const CombatBrainScript := preload("res://application/ai/combat_brain.gd")
const RoleBrainsScript := preload("res://application/ai/role_brains.gd")


func _bb(gates: Dictionary) -> AiBlackboard:
	# A blackboard with a canonical RngService and the given gate values + a live foe to select.
	var rng := RngServiceScript.new(CanonicalRNG.new(7))
	var bb := BlackboardScript.new(rng, {})
	var actor := BattleEngine.Mon.new("Boss", "Chaos", "Thanatos", "god", "god")
	var foe := BattleEngine.Mon.new("Hero", "Cosmos", "Eros", "wild", "T3")
	bb.set_value("actor", actor)
	bb.set_value("foes", [foe])
	bb.set_value("allies", [actor])
	for k in gates:
		bb.set_value(k, gates[k])
	return bb


func test_starts_in_opening() -> void:
	var hsm := SuccessionBossScript.build()
	var bb := _bb({"turn": 1, "boss_hp_frac": 1.0, "boss_squad_losses": 0, "entropy": 1.0})
	hsm.start(bb)
	assert_str(hsm.current_state()).is_equal(SuccessionBossScript.PHASE_OPENING)


func test_turn_gate_advances_opening_to_pressure() -> void:
	var hsm := SuccessionBossScript.build()
	# Turn 1: stays Opening. Turn >= pressure_turn (2): advances to Pressure.
	var action1 := hsm.update(_bb({"turn": 1, "boss_hp_frac": 1.0, "entropy": 1.0}))
	assert_str(hsm.current_state()).is_equal(SuccessionBossScript.PHASE_OPENING)
	assert_bool(action1.is_empty()).is_false()  # it still selected a move

	var action2 := hsm.update(_bb({"turn": 2, "boss_hp_frac": 1.0, "entropy": 1.0}))
	assert_str(hsm.current_state()).is_equal(SuccessionBossScript.PHASE_PRESSURE)
	assert_bool(action2.is_empty()).is_false()


func test_hp_gate_advances_to_desperation() -> void:
	var hsm := SuccessionBossScript.build()
	# Boss at 45% HP (<= desperation_hp_frac 0.5) jumps to Desperation even from Opening.
	hsm.update(_bb({"turn": 2, "boss_hp_frac": 0.45, "boss_squad_losses": 0, "entropy": 1.2}))
	assert_str(hsm.current_state()).is_equal(SuccessionBossScript.PHASE_DESPERATION)


func test_squad_loss_gate_advances_to_desperation() -> void:
	var hsm := SuccessionBossScript.build()
	# A squad loss (>= desperation_losses 1) forces Desperation even at full HP.
	hsm.update(_bb({"turn": 1, "boss_hp_frac": 0.95, "boss_squad_losses": 1, "entropy": 1.0}))
	assert_str(hsm.current_state()).is_equal(SuccessionBossScript.PHASE_DESPERATION)


func test_low_hp_gate_advances_to_apotheosis() -> void:
	var hsm := SuccessionBossScript.build()
	# <= apotheosis_hp_frac 0.2 -> Apotheosis (terminal), skipping intermediate phases in one update.
	hsm.update(_bb({"turn": 3, "boss_hp_frac": 0.15, "boss_squad_losses": 0, "entropy": 1.3}))
	assert_str(hsm.current_state()).is_equal(SuccessionBossScript.PHASE_APOTHEOSIS)


func test_entropy_gate_advances_to_apotheosis() -> void:
	var hsm := SuccessionBossScript.build()
	# Entropy clock past x1.6 -> Apotheosis even at healthy HP (the fight has dragged into ascension).
	hsm.update(_bb({"turn": 6, "boss_hp_frac": 0.8, "boss_squad_losses": 0, "entropy": 1.6}))
	assert_str(hsm.current_state()).is_equal(SuccessionBossScript.PHASE_APOTHEOSIS)


func test_apotheosis_is_terminal() -> void:
	var hsm := SuccessionBossScript.build()
	hsm.update(_bb({"turn": 6, "boss_hp_frac": 0.1, "entropy": 1.7}))
	assert_str(hsm.current_state()).is_equal(SuccessionBossScript.PHASE_APOTHEOSIS)
	# Even with "recovered" gates, Apotheosis has no outgoing transition — it stays put.
	hsm.update(_bb({"turn": 7, "boss_hp_frac": 1.0, "entropy": 1.0}))
	assert_str(hsm.current_state()).is_equal(SuccessionBossScript.PHASE_APOTHEOSIS)


func test_custom_gate_thresholds_apply() -> void:
	# Override pressure_turn to 4: turn 2/3 stay Opening, turn 4 advances.
	var hsm := SuccessionBossScript.build({"pressure_turn": 4})
	hsm.update(_bb({"turn": 3, "boss_hp_frac": 1.0, "entropy": 1.0}))
	assert_str(hsm.current_state()).is_equal(SuccessionBossScript.PHASE_OPENING)
	hsm.update(_bb({"turn": 4, "boss_hp_frac": 1.0, "entropy": 1.0}))
	assert_str(hsm.current_state()).is_equal(SuccessionBossScript.PHASE_PRESSURE)


func test_boss_phase_progression_is_deterministic_through_brain() -> void:
	# Two identical brains driven through the same gate sequence reach the same phase + same action.
	var phases: Array = []
	for _i in range(2):
		var brain := CombatBrainScript.new({"name": "Ascended Tyrant"})
		var boss := BattleEngine.Mon.new("Tyrant", "Chaos", "Thanatos", "god", "god")
		var foe := BattleEngine.Mon.new("Hero", "Cosmos", "Eros", "wild", "T3")
		brain.assign_boss(boss)
		var seq: Array = []
		var sel_rng := CanonicalRNG.new(99)
		for turn in [1, 2, 3]:
			var st := {
				"actor": boss,
				"allies": [boss],
				"foes": [foe],
				"turn": turn,
				"entropy": 1.0 + float(turn - 1) * 0.12,
				"boss_hp_frac": 1.0 - 0.3 * float(turn - 1),
				"boss_squad_losses": 0,
			}
			var action := brain.choose_action(st, sel_rng)
			seq.append(str(action.get("phase", "")))
		phases.append(seq)
	assert_array(phases[0]).is_equal(phases[1])
	# Opening -> (turn2) Pressure -> (turn3, hp 0.4) Desperation.
	assert_str(str(phases[0][0])).is_equal(SuccessionBossScript.PHASE_OPENING)
	assert_str(str(phases[0][1])).is_equal(SuccessionBossScript.PHASE_PRESSURE)
	assert_str(str(phases[0][2])).is_equal(SuccessionBossScript.PHASE_DESPERATION)
