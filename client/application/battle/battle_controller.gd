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
##
## SLICE 2 — INTERACTIVE MODE. `run()` is the Slice 1 AUTO path (untouched, parity-preserving). A new
## STEP-WISE driver (`InteractiveSession`, built via `interactive(teamA, player_controlled)`) advances
## the SAME turn loop one actor at a time: on a PLAYER-controlled actor it YIELDS for a player Action
## (attack target / capture / flee) instead of consulting the brain; every OTHER actor uses the brain
## exactly as `run()` does. Strikes resolve through ONE shared `_resolve_strike()` so the interactive
## resolution sequence (chain → conditional overload → crit) is identical to `run()` / simulate(). A
## player CAPTURE/FLEE draws NOTHING from the RESOLUTION stream (capture rolls on a DISJOINT capture
## sub-stream owned by the caller), so a fixed (seed, teams, player-choice sequence) is byte-identical.

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

			# 1) AI SELECTS — the brain picks the target (+offense), drawing only from the SELECTION
			#    sub-stream (ADR-016). The resolution stream is untouched here.
			var action := _brain_action(mon, allies, foes, turn, ent)
			var tgt: BattleEngine.Mon = null
			if not action.is_empty():
				tgt = action.get("target") as BattleEngine.Mon
			if tgt == null or not tgt.alive:
				# No valid selection (no foe alive) — mirror simulate()'s `if tgt == null: break`.
				break

			# Surface the boss phase for transcript readability (does NOT alter resolution).
			if _brain.is_boss(mon) and action.has("phase"):
				log.append("   ~ " + mon.name + " enters " + str(action["phase"]) + " ~")

			# 2) ENGINE RESOLVES — the shared resolver draws the SAME RES sequence as simulate().
			_resolve_strike(mon, tgt, ent, sideprev, log)
		log.append("")

	log.append(_result_line(teamA, teamB, turn))
	return log


## Build an interactive, step-wise session over the SAME turn loop. `player_side` ("A"/"B") is the
## side the player drives; every actor on the OTHER side is brain-driven exactly as `run()` does. The
## caller advances the battle via the returned InteractiveSession (see that class). The two teams are
## side-tagged here (object identity), identical to `run()` / simulate().
func interactive(teamA: Array, teamB: Array, player_side: String = "A") -> InteractiveSession:
	for m in teamA:
		(m as BattleEngine.Mon).side = "A"
	for m in teamB:
		(m as BattleEngine.Mon).side = "B"
	return InteractiveSession.new(self, teamA, teamB, player_side)


# --- the shared resolver (single source of truth for the RES stream order) ----------------------- #


## Resolve ONE strike (actor → target) drawing the RESOLUTION sub-stream in EXACTLY simulate()'s
## order: chain x1.3 (same-force repeat) → conditional overload roll (only when the OPP check passes)
## → attack()'s single crit roll. Updates `sideprev[actor.side]`. Used by BOTH the auto loop and the
## interactive driver so the two share one byte-identical resolution sequence.
func _resolve_strike(
	actor: BattleEngine.Mon, tgt: BattleEngine.Mon, ent: float, sideprev: Dictionary, log: Array
) -> void:
	var b: Dictionary = Constants.BALANCE["battle"]
	var chain_mult: float = float(b["chain_mult"])
	var overload_chance: float = float(b["overload_chance"])
	var side: String = actor.side
	var chain: float = chain_mult if sideprev[side] == actor.prim else 1.0
	var overload := false
	if BattleEngine.OPP.get(actor.prim, null) == tgt.prim and _res_rng.random() < overload_chance:
		overload = true
	BattleEngine.attack(actor, tgt, ent, chain, overload, _res_rng, log)
	sideprev[side] = actor.prim


## Ask the brain for an Action for `mon` against `foes`, drawing only the SELECTION sub-stream. Mirrors
## the battle_state the auto loop builds. Returns the Action dict (may be empty when no foe is alive).
func _brain_action(
	mon: BattleEngine.Mon, allies: Array, foes: Array, turn: int, ent: float
) -> Dictionary:
	var battle_state := {
		"actor": mon,
		"allies": allies,
		"foes": foes,
		"turn": turn,
		"entropy": ent,
		"boss_hp_frac": float(mon.hp) / float(mon.maxhp),
		"boss_squad_losses": _losses(allies),
	}
	return _brain.choose_action(battle_state, _sel_rng)


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


## The simulate()-format RESULT line. TEAM A wins iff it has a survivor (else TEAM B).
static func _result_line(teamA: Array, teamB: Array, turn: int) -> String:
	var winner: String = "TEAM A" if _any_alive(teamA) else "TEAM B"
	var win_team: Array = teamA if winner == "TEAM A" else teamB
	var surv: PackedStringArray = PackedStringArray()
	for m in win_team:
		if (m as BattleEngine.Mon).alive:
			surv.append((m as BattleEngine.Mon).name)
	return "RESULT: " + winner + " wins on turn " + str(turn) + " | survivors: " + ", ".join(surv)


static func _py_float_str(v: float) -> String:
	# Reproduce Python str(float) for entropy values (<=2 decimals), exactly as BattleEngine does.
	var s := "%.2f" % v
	while s.ends_with("0"):
		s = s.substr(0, s.length() - 1)
	if s.ends_with("."):
		s += "0"
	return s


## InteractiveSession — the step-wise driver over BattleController's turn loop (Slice 2). It owns the
## live loop position (turn / initiative order / per-turn sideprev) and advances ONE actor per
## `advance()`. On a player-side actor it returns an AWAIT_PLAYER step (the caller then calls
## `attack(target)` / `capture()` / `flee()`); every other actor is brain-resolved inline and an
## auto-RESOLVED step is returned. Battle end returns an ENDED step carrying the simulate()-format
## RESULT line appended to the transcript. The transcript it builds is byte-identical to `run()` when
## the player happens to mirror the neutral brain's choices (parity is a property of the SHARED loop).
class InteractiveSession:
	extends RefCounted

	## Step kinds the caller (the battle UI) reacts to.
	const AWAIT_PLAYER := "await_player"  # a player actor's turn — call attack/capture/flee next
	const RESOLVED := "resolved"  # a brain (or just-resolved player) strike happened
	const ENDED := "ended"  # the battle is over (win/lose/flee/caught)

	## End reasons surfaced on an ENDED step.
	const END_DEFEAT_ENEMY := "enemy_defeated"  # a team was wiped (normal win/lose)
	const END_FLED := "fled"  # the player fled
	const END_CAUGHT := "caught"  # the player captured the wild target

	var _ctrl: BattleController
	var _team_a: Array
	var _team_b: Array
	var _player_side: String
	var _turn_cap: int
	var _entropy_step: float

	var _log: Array = []
	var _turn: int = 0
	var _ent: float = 1.0
	var _order: Array = []
	var _order_idx: int = 0
	var _sideprev: Dictionary = {"A": null, "B": null}
	var _ended: bool = false
	var _end_reason: String = ""
	# True while the CURRENT turn still owes its trailing blank line. run() appends ONE "" after every
	# turn's actors; the pump must emit that same separator at each turn boundary (and before the
	# RESULT line) so the interactive transcript stays element-for-element identical to run().
	var _turn_open: bool = false
	# The actor currently awaiting a player action (set on an AWAIT_PLAYER step, consumed by the
	# player verbs). null whenever no player decision is pending.
	var _pending_actor: BattleEngine.Mon = null

	func _init(ctrl: BattleController, team_a: Array, team_b: Array, player_side: String) -> void:
		_ctrl = ctrl
		_team_a = team_a
		_team_b = team_b
		_player_side = player_side
		var b: Dictionary = Constants.BALANCE["battle"]
		_turn_cap = int(b["turn_cap"])
		_entropy_step = float(b["entropy_step_per_turn"])

	# --- the step pump ---------------------------------------------------------------------------- #

	## Advance the battle to the NEXT decision point and return a step dict:
	##   {"kind": AWAIT_PLAYER, "actor": Mon, "foes": Array, "allies": Array, "turn": int}
	##   {"kind": RESOLVED, "actor": Mon, "target": Mon, "turn": int}
	##   {"kind": ENDED, "reason": String, "player_won": bool, "transcript": Array}
	## Brain-driven actors resolve INLINE (their RESOLVED step is still returned, one per call) so the
	## UI can animate each strike; only a player-side actor pauses the pump (AWAIT_PLAYER).
	func advance() -> Dictionary:
		if _ended:
			return _ended_step()
		# A player decision is still pending — the caller must resolve it via a verb first.
		if _pending_actor != null:
			return _await_step(_pending_actor)
		# Single return point (keeps the function within the linter's max-returns); the loop assigns
		# `step` and breaks. Each iteration consumes one actor (or starts a turn / ends the battle).
		var step: Dictionary = {}
		while step.is_empty():
			# At a TURN boundary (no actors left in this turn's order): first emit run()'s trailing ""
			# for the turn that just finished, THEN apply the auto loop's while-head (both sides alive
			# AND turn < turn_cap to begin another turn; else the battle ends).
			if _order_idx >= _order.size():
				_close_turn()
				if not _both_sides_alive() or _turn >= _turn_cap:
					step = _finish(END_DEFEAT_ENEMY)
					break
				_begin_turn()
			# Pull the next actor in the initiative order.
			var mon := _order[_order_idx] as BattleEngine.Mon
			_order_idx += 1
			if not mon.alive:
				continue
			if mon.side == _player_side:
				_pending_actor = mon
				step = _await_step(mon)
			else:
				# Brain-driven actor — resolve inline, exactly as run() does. An empty result means no
				# legal selection (no foe alive) — mirror run()'s `break`: end the turn + battle.
				var resolved := _resolve_brain(mon)
				step = resolved if not resolved.is_empty() else _finish(END_DEFEAT_ENEMY)
		return step

	# --- player verbs (consume the pending player actor) ------------------------------------------ #

	## Player ATTACK the chosen foe. Resolves through the SHARED resolver (same RES sequence as the
	## auto loop). Returns a RESOLVED step (or ENDED if the strike ends the battle). Falls back to the
	## first alive foe when `target` is null/dead, so the UI can pass an index that just died.
	func attack(target: BattleEngine.Mon) -> Dictionary:
		var actor := _take_pending()
		if actor == null:
			return advance()
		var foes := _foes_of(actor)
		var tgt := target
		if tgt == null or not tgt.alive:
			tgt = RoleBrains.first_alive(foes)
		if tgt == null:
			return _finish(END_DEFEAT_ENEMY)
		_ctrl._resolve_strike(actor, tgt, _ent, _sideprev, _log)
		if not _both_sides_alive():
			return _finish(END_DEFEAT_ENEMY)
		return {"kind": RESOLVED, "actor": actor, "target": tgt, "turn": _turn}

	## Player CAPTURE outcome. The CAPTURE ROLL itself is the CALLER's (it owns the gear-/HP-modified
	## loot_engine chance + the disjoint capture sub-stream — this controller never touches the RES
	## stream for a capture). `success` is that pre-computed result.
	##   * SUCCESS → end the battle as CAUGHT (the caller adds the wild target to the party).
	##   * FAILURE → consume the player's turn (NO strike, NO RES draw) and continue: the pump resumes,
	##     so the enemy then acts. Returns the next step.
	func capture(success: bool) -> Dictionary:
		var actor := _take_pending()
		if actor == null:
			return advance()
		if success:
			return _finish(END_CAUGHT)
		# Failure: the player's action is spent; advance the pump so the enemy acts next.
		return advance()

	## Player FLEE — ends the battle immediately as FLED (the player keeps the run, loses the fight's
	## rewards). Consumes the player's pending turn.
	func flee() -> Dictionary:
		var actor := _take_pending()
		if actor == null and not _ended:
			return advance()
		return _finish(END_FLED)

	# --- read-only accessors (for the UI + tests) ------------------------------------------------- #

	func transcript() -> Array:
		return _log

	func is_ended() -> bool:
		return _ended

	func end_reason() -> String:
		return _end_reason

	func turn() -> int:
		return _turn

	func player_team() -> Array:
		return _team_a if _player_side == "A" else _team_b

	func enemy_team() -> Array:
		return _team_b if _player_side == "A" else _team_a

	## True iff the player's side has a living member (the win condition for the player).
	func player_won() -> bool:
		return BattleController._any_alive(player_team())

	# --- internals -------------------------------------------------------------------------------- #

	func _begin_turn() -> void:
		_turn += 1
		_ent = CanonicalMath.rnd_dp(1.0 + float(_turn - 1) * _entropy_step, 2)
		_log.append(
			(
				"== TURN "
				+ str(_turn)
				+ "   entropy x"
				+ BattleController._py_float_str(_ent)
				+ " (escalating) =="
			)
		)
		_order = BattleController._initiative_order(_team_a, _team_b)
		_order_idx = 0
		_sideprev = {"A": null, "B": null}
		_turn_open = true

	## Emit run()'s per-turn trailing blank line ONCE for the current turn (idempotent: a no-op when
	## the turn is already closed). Keeps the pump's blank-line placement identical to run().
	func _close_turn() -> void:
		if _turn_open:
			_log.append("")
			_turn_open = false

	func _resolve_brain(mon: BattleEngine.Mon) -> Dictionary:
		var foes := _foes_of(mon)
		var allies := _allies_of(mon)
		var action := _ctrl._brain_action(mon, allies, foes, _turn, _ent)
		var tgt: BattleEngine.Mon = null
		if not action.is_empty():
			tgt = action.get("target") as BattleEngine.Mon
		if tgt == null or not tgt.alive:
			return {}
		if _ctrl._brain.is_boss(mon) and action.has("phase"):
			_log.append("   ~ " + mon.name + " enters " + str(action["phase"]) + " ~")
		_ctrl._resolve_strike(mon, tgt, _ent, _sideprev, _log)
		if not _both_sides_alive():
			return _finish(END_DEFEAT_ENEMY)
		return {"kind": RESOLVED, "actor": mon, "target": tgt, "turn": _turn}

	## Finalise: append the turn's blank-line separator + the RESULT line (simulate() format), mark
	## ended, and return the ENDED step. Idempotent — a second call just returns the cached step.
	func _finish(reason: String) -> Dictionary:
		if _ended:
			return _ended_step()
		# Close the current turn block (run()'s one trailing "" for this turn), then the RESULT line.
		_close_turn()
		_log.append(BattleController._result_line(_team_a, _team_b, _turn))
		_ended = true
		_end_reason = reason
		_pending_actor = null
		return _ended_step()

	func _ended_step() -> Dictionary:
		return {
			"kind": ENDED,
			"reason": _end_reason,
			"player_won": player_won(),
			"transcript": _log,
		}

	func _await_step(actor: BattleEngine.Mon) -> Dictionary:
		return {
			"kind": AWAIT_PLAYER,
			"actor": actor,
			"foes": _foes_of(actor),
			"allies": _allies_of(actor),
			"turn": _turn,
		}

	## Consume the pending player actor (the verb is being applied). Returns null if there is no
	## pending decision (a stray verb call) so the caller can no-op gracefully.
	func _take_pending() -> BattleEngine.Mon:
		var actor := _pending_actor
		_pending_actor = null
		return actor

	func _foes_of(mon: BattleEngine.Mon) -> Array:
		return _team_b if mon.side == "A" else _team_a

	func _allies_of(mon: BattleEngine.Mon) -> Array:
		return _team_a if mon.side == "A" else _team_b

	func _both_sides_alive() -> bool:
		return BattleController._any_alive(_team_a) and BattleController._any_alive(_team_b)
