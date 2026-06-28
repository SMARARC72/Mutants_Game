class_name BattleController
extends RefCounted
## BattleController (ADR-016) — the interactive/AI battle mode. It DRIVES the turn loop and obtains
## each actor's TARGET from the CombatBrain, then RESOLVES every strike via the oracle
## (BattleEngine.attack). The pure auto-battler BattleEngine.simulate stays UNTOUCHED as the
## parity/auto oracle; THIS controller is the layer where "AI SELECTS, the engine RESOLVES" lives.
##
## APPLICATION/battle layer. It mirrors simulate()'s structure EXACTLY so the two agree:
##   - initiative = STABLE sort by -Celerity (teamA+teamB decorate order),
##   - per-turn entropy = rnd_dp(1.0 + (turn-1)*step, 2),
##   - chain x1.3 when an actor repeats its team's previous force this turn,
##   - opposed-force OVERLOAD roll (consumes one rng.random() ONLY when the OPP check passes),
##   - BattleEngine.attack resolves the strike (one rng.random() crit roll, after the overload roll).
##
## THE DETERMINISM CONTRACT (TDD §6 replay): the RESOLUTION RNG stream (overload roll + attack's crit
## roll) is a dedicated sub-stream, drawn in EXACTLY simulate()'s order. The brain's SELECTION RNG is
## a SEPARATE sub-stream (RES_SALT vs SEL_SALT) so AI choices NEVER perturb the resolver's numbers.
## With the neutral brain (first-alive target = simulate's _first_alive), the controller's transcript
## is byte-identical to simulate() for the same seed+teams (proven by battle_controller_parity_test).

const Bt := preload("res://application/ai/behavior_tree.gd")

# Disjoint sub-stream salts: resolution (oracle numbers) vs selection (AI choices) never collide.
const RES_SALT := 0x524553  # "RES" — the overload+crit resolution stream
const SEL_SALT := 0x53454C  # "SEL" — the AI selection stream

var _brain: CombatBrain
var _res_rng: CanonicalRNG
var _sel_rng: CanonicalRNG


## Inject the brain (the facade) + the run RNG. The two disjoint sub-streams are derived here so a
## test (or a replay) can reproduce them exactly from the same `run_rng`.
func _init(brain: CombatBrain, run_rng: CanonicalRNG) -> void:
	_brain = brain
	_res_rng = run_rng.substream(RES_SALT)
	_sel_rng = run_rng.substream(SEL_SALT)


## Static helpers so a replay/test can rebuild the EXACT sub-streams the controller used.
static func resolution_rng(run_rng: CanonicalRNG) -> CanonicalRNG:
	return run_rng.substream(RES_SALT)


static func selection_rng(run_rng: CanonicalRNG) -> CanonicalRNG:
	return run_rng.substream(SEL_SALT)


## Run a full battle. teamA/teamB: Array[BattleEngine.Mon]. Returns Array[String] — the transcript,
## reproduced in simulate()'s exact log format (so it diffs cleanly against the auto oracle).
func run(teamA: Array, teamB: Array) -> Array:
	var b: Dictionary = Constants.BALANCE["battle"]
	var turn_cap: int = int(b["turn_cap"])
	var entropy_step: float = float(b["entropy_step_per_turn"])
	var chain_mult: float = float(b["chain_mult"])
	var overload_chance: float = float(b["overload_chance"])

	# Tag side by identity (mirrors simulate(): object identity, not value equality).
	for m in teamA:
		(m as BattleEngine.Mon).side = "A"
	for m in teamB:
		(m as BattleEngine.Mon).side = "B"

	var log: Array = []
	var turn := 0
	while _any_alive(teamA) and _any_alive(teamB) and turn < turn_cap:
		turn += 1
		var ent := CanonicalMath.rnd_dp(1.0 + float(turn - 1) * entropy_step, 2)
		log.append(
			(
				"== TURN "
				+ str(turn)
				+ "   entropy x"
				+ BattleController._py_float_str(ent)
				+ " (escalating) =="
			)
		)

		var order := _initiative_order(teamA, teamB)
		var sideprev: Dictionary = {"A": null, "B": null}
		for m in order:
			var mon := m as BattleEngine.Mon
			if not mon.alive:
				continue
			var foes: Array = teamB if mon.side == "A" else teamA
			var allies: Array = teamA if mon.side == "A" else teamB
			var side: String = mon.side

			# 1) AI SELECTS — the brain picks the target (+offense), drawing only from the SELECTION
			#    sub-stream (ADR-016). The resolution stream is untouched here.
			var battle_state := {
				"actor": mon,
				"allies": allies,
				"foes": foes,
				"turn": turn,
				"entropy": ent,
				"boss_hp_frac": float(mon.hp) / float(mon.maxhp),
				"boss_squad_losses": _losses(allies),
			}
			var action := _brain.choose_action(battle_state, _sel_rng)
			var tgt: BattleEngine.Mon = null
			if not action.is_empty():
				tgt = action.get("target") as BattleEngine.Mon
			if tgt == null or not tgt.alive:
				# No valid selection (no foe alive) — mirror simulate()'s `if tgt == null: break`.
				break

			# Surface the boss phase for transcript readability (does NOT alter resolution).
			if _brain.is_boss(mon) and action.has("phase"):
				log.append("   ~ " + mon.name + " enters " + str(action["phase"]) + " ~")

			# 2) ENGINE RESOLVES — chain + overload computed exactly as simulate(), then the oracle's
			#    attack() does the strike. The overload roll consumes the RESOLUTION stream ONLY when
			#    the OPP check passes (Python short-circuit), then attack() consumes one crit roll.
			var chain: float = chain_mult if sideprev[side] == mon.prim else 1.0
			var overload := false
			if (
				BattleEngine.OPP.get(mon.prim, null) == tgt.prim
				and _res_rng.random() < overload_chance
			):
				overload = true
			BattleEngine.attack(mon, tgt, ent, chain, overload, _res_rng, log)
			sideprev[side] = mon.prim
		log.append("")

	var winner: String = "TEAM A" if _any_alive(teamA) else "TEAM B"
	var win_team: Array = teamA if winner == "TEAM A" else teamB
	var surv: PackedStringArray = PackedStringArray()
	for m in win_team:
		if (m as BattleEngine.Mon).alive:
			surv.append((m as BattleEngine.Mon).name)
	log.append(
		"RESULT: " + winner + " wins on turn " + str(turn) + " | survivors: " + ", ".join(surv)
	)
	return log


# --- helpers (mirror simulate()'s, so the two transcripts agree) --------------------------------


static func _any_alive(team: Array) -> bool:
	for m in team:
		if (m as BattleEngine.Mon).alive:
			return true
	return false


static func _losses(team: Array) -> int:
	var n := 0
	for m in team:
		if not (m as BattleEngine.Mon).alive:
			n += 1
	return n


static func _initiative_order(teamA: Array, teamB: Array) -> Array:
	# Identical to BattleEngine._initiative_order: STABLE sort by -Celerity, teamA+teamB order ties.
	var decorated: Array = []
	var idx := 0
	for m in teamA:
		if (m as BattleEngine.Mon).alive:
			decorated.append({"i": idx, "m": m})
		idx += 1
	for m in teamB:
		if (m as BattleEngine.Mon).alive:
			decorated.append({"i": idx, "m": m})
		idx += 1
	decorated.sort_custom(
		func(a: Dictionary, c: Dictionary) -> bool:
			var ca := int((a["m"] as BattleEngine.Mon).stats["Celerity"])
			var cb := int((c["m"] as BattleEngine.Mon).stats["Celerity"])
			if ca != cb:
				return ca > cb
			return int(a["i"]) < int(c["i"])
	)
	var out: Array = []
	for d in decorated:
		out.append(d["m"])
	return out


static func _py_float_str(v: float) -> String:
	# Reproduce Python str(float) for entropy values (<=2 decimals), exactly as BattleEngine does.
	var s := "%.2f" % v
	while s.ends_with("0"):
		s = s.substr(0, s.length() - 1)
	if s.ends_with("."):
		s += "0"
	return s
