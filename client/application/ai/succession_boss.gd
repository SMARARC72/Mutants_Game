class_name SuccessionBoss
extends RefCounted
## SuccessionBoss (ADR-016) — the Succession invasion boss brain: an HSM of phases
## Opening -> Pressure -> Desperation -> Apotheosis, each phase a BehaviorTree that SELECTS the
## boss's target + offense from the imported `god_snapshot` kit. Phase transitions are
## BLACKBOARD-GATED on own HP%, turn count, squad losses, and the entropy clock (the values the
## BattleController writes onto the AiBlackboard each turn). Mirrors LimboAI's HSM + per-phase BT
## design (Integrations §A2 "the showcase"). Pure GDScript; NO outcome math.
##
## The boss is driven by the `god_snapshot` row (supabase god_snapshots: forces/team/
## signature_moves) loaded into the blackboard. Each phase escalates target priority; the boss never
## computes damage — the oracle (battle_engine.attack) resolves the strike the boss selected.
##
## DETERMINISM: phase path is a pure function of the blackboard gates (which the controller derives
## from live battle state); any selection randomness inside a phase draws ONLY from ctx.rng
## (RngService). Same (seed, teams, snapshot) -> identical phase progression -> identical decisions.

const Bt := preload("res://application/ai/behavior_tree.gd")
const HsmScript := preload("res://application/ai/hsm.gd")
const RoleBrainsScript := preload("res://application/ai/role_brains.gd")

# Phase names (also used as blackboard "phase" markers a dev HUD / log can read).
const PHASE_OPENING := "Opening"
const PHASE_PRESSURE := "Pressure"
const PHASE_DESPERATION := "Desperation"
const PHASE_APOTHEOSIS := "Apotheosis"

# Default blackboard gate thresholds (Integrations §A2: HP%, turns, squad losses, entropy clock).
# Tunable per snapshot via build(thresholds) — designer-facing, not outcome math.
const DEFAULT_GATES := {
	"pressure_turn": 2,  # Opening -> Pressure once the fight is joined (turn >= 2)
	"desperation_hp_frac": 0.5,  # -> Desperation when boss HP <= 50%
	"desperation_losses": 1,  # ...or once the boss squad has lost a member
	"apotheosis_hp_frac": 0.2,  # -> Apotheosis when boss HP <= 20%
	"apotheosis_entropy": 1.6,  # ...or when the entropy clock has escalated past x1.6
}


## Build the boss HSM. `snapshot` is the god_snapshot kit (may be {}). `gates` overrides the
## default phase thresholds. The HSM + its phase BTs read the blackboard; nothing is computed here.
static func build(gates: Dictionary = {}) -> Hsm:
	var g := DEFAULT_GATES.duplicate(true)
	for k in gates:
		g[k] = gates[k]

	var hsm: Hsm = HsmScript.new()

	# --- phase behaviour trees (each SELECTS a target+offense; escalating priority) ---
	# Opening: measured — neutral first-alive pressure while reading the field.
	var opening_tree: BehaviorTree.BtNode = RoleBrainsScript.neutral()
	# Pressure: aggressor — lean on the matchup, push the front line.
	var pressure_tree: BehaviorTree.BtNode = RoleBrainsScript.controller()
	# Desperation: finisher — collapse onto the weakest target to claw back tempo.
	var desperation_tree: BehaviorTree.BtNode = RoleBrainsScript.aggressor()
	# Apotheosis: the ascended turn — exploit force weakness, then finish (Selector: matchup else kill).
	var apotheosis_tree: BehaviorTree.Selector = Bt.Selector.new()
	apotheosis_tree.add(RoleBrainsScript.controller())
	apotheosis_tree.add(RoleBrainsScript.aggressor())

	var opening: Hsm.State = HsmScript.State.new(PHASE_OPENING, opening_tree)
	var pressure: Hsm.State = HsmScript.State.new(PHASE_PRESSURE, pressure_tree)
	var desperation: Hsm.State = HsmScript.State.new(PHASE_DESPERATION, desperation_tree)
	var apotheosis: Hsm.State = HsmScript.State.new(PHASE_APOTHEOSIS, apotheosis_tree)

	# Record the active phase onto the blackboard on enter (dev HUD / transcript readability).
	opening.set_on_enter(func(ctx: AiBlackboard) -> void: ctx.set_value("phase", PHASE_OPENING))
	pressure.set_on_enter(func(ctx: AiBlackboard) -> void: ctx.set_value("phase", PHASE_PRESSURE))
	desperation.set_on_enter(
		func(ctx: AiBlackboard) -> void: ctx.set_value("phase", PHASE_DESPERATION)
	)
	apotheosis.set_on_enter(
		func(ctx: AiBlackboard) -> void: ctx.set_value("phase", PHASE_APOTHEOSIS)
	)

	# --- blackboard-gated transitions (authored order = priority; first satisfied guard wins) ---
	# Gates the controller writes each turn: "turn" (int), "boss_hp_frac" (float),
	# "boss_squad_losses" (int), "entropy" (float). Late phases are reachable from earlier ones so a
	# sudden collapse (e.g. squad wipe) can skip straight ahead in a single update().
	var pressure_turn := int(g["pressure_turn"])
	var desp_hp := float(g["desperation_hp_frac"])
	var desp_losses := int(g["desperation_losses"])
	var apo_hp := float(g["apotheosis_hp_frac"])
	var apo_entropy := float(g["apotheosis_entropy"])

	var to_apotheosis := func(ctx: AiBlackboard) -> bool:
		return (
			ctx.get_float("boss_hp_frac", 1.0) <= apo_hp
			or ctx.get_float("entropy", 1.0) >= apo_entropy
		)
	var to_desperation := func(ctx: AiBlackboard) -> bool:
		return (
			ctx.get_float("boss_hp_frac", 1.0) <= desp_hp
			or ctx.get_int("boss_squad_losses", 0) >= desp_losses
		)
	var to_pressure := func(ctx: AiBlackboard) -> bool:
		return ctx.get_int("turn", 0) >= pressure_turn

	# Apotheosis is terminal (the ascension); every earlier phase can jump to it directly.
	opening.add_transition(PHASE_APOTHEOSIS, to_apotheosis)
	opening.add_transition(PHASE_DESPERATION, to_desperation)
	opening.add_transition(PHASE_PRESSURE, to_pressure)

	pressure.add_transition(PHASE_APOTHEOSIS, to_apotheosis)
	pressure.add_transition(PHASE_DESPERATION, to_desperation)

	desperation.add_transition(PHASE_APOTHEOSIS, to_apotheosis)

	hsm.add_state(opening)
	hsm.add_state(pressure)
	hsm.add_state(desperation)
	hsm.add_state(apotheosis)
	hsm.set_initial(PHASE_OPENING)
	return hsm
