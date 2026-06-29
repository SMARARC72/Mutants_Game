class_name SkillBattleController
extends RefCounted
## SkillBattleController (Phase 10 · Slice 1) — the INTERACTIVE driver for the SKILL battle: the richer
## combat system (force-pool skills, 8 verbs, ranks, combos, shields/buffs/defdown) that SkillEngine
## models but that the attack-only BattleEngine interactive path never surfaced. It mirrors
## SkillEngine.battle()'s turn loop EXACTLY — initiative = STABLE sort by -Celerity over A+B; per-turn
## entropy = rnd_dp(1 + (turn-1)*0.12, 2); a per-side COMBO chain (x1.4) when an actor repeats its
## side's previous force — but advances ONE actor per advance() so a PLAYER-side actor YIELDS for a
## chosen skill instead of being AI-driven. Every other actor resolves through SkillEngine.act() (the
## oracle AI). It computes NO numbers: damage/heal/shield/combo all come from the pure SkillEngine via
## the AbilityContainer shell. This layer owns only loop position + which actor is the player's.
##
## DETERMINISM (TDD §6, ADR-016): the ONLY RNG SkillEngine consumes is act()'s Rouse gate. The AI act()
## draws from a dedicated ACT sub-stream consumed in initiative order, identical to SkillEngine.battle().
## A player skill choice (use_damage/use_support) draws NOTHING — so a fixed (seed, teams, player-choice
## sequence) is byte-identical across runs. With a "neutral player" that replays act() for its OWN mons
## (act_neutral), the transcript is byte-identical to SkillEngine.battle() — proven by
## skill_battle_controller_parity_test. BattleEngine + its auto/boss path stay UNTOUCHED.

# Dedicated act sub-stream salt — disjoint from BattleController's RES/SEL so the two paths never collide.
const ACT_SALT := 0x53414354  # "SACT" — the SkillEngine.act() selection/Rouse stream

var _act_rng: CanonicalRNG


## Inject the run RNG; the ACT sub-stream is derived here so a test/replay can reproduce it exactly.
func _init(run_rng: CanonicalRNG) -> void:
	_act_rng = run_rng.substream(ACT_SALT)


## Static helper so a replay/test can rebuild the EXACT sub-stream the controller uses: feed this to
## SkillEngine.battle() to compare byte-for-byte (mirrors BattleController.resolution_rng).
static func act_rng(run_rng: CanonicalRNG) -> CanonicalRNG:
	return run_rng.substream(ACT_SALT)


## Build an interactive, step-wise session over the skill turn loop. teamA/teamB: Array[AbilityContainer].
## `player_side` ("A"/"B") is the side the player drives; every other actor is AI-driven via act().
func interactive(team_a: Array, team_b: Array, player_side: String = "A") -> InteractiveSession:
	return InteractiveSession.new(self, team_a, team_b, player_side)


## The verb of a skill id, from the single-sourced library (presentation/routing only).
static func verb_of(skill: String) -> String:
	var lib: Dictionary = Constants.BALANCE["skill"]["library"]
	if not lib.has(skill):
		return ""
	return String((lib[skill] as Dictionary).get("verb", ""))


## True if `verb` is a SUPPORT verb (targets allies; the engine picks the specific ally).
static func is_support_verb(verb: String) -> bool:
	return verb == "Mend" or verb == "Ward" or verb == "Rouse"


## InteractiveSession — the step-wise driver over the skill turn loop. Owns the live loop position
## (turn / initiative order / per-side combo prev) and advances ONE actor per advance(). On a player
## actor it returns an AWAIT_PLAYER step (the caller then calls use_skill / capture / flee / act_neutral);
## every other actor is AI-resolved inline (a RESOLVED step). Battle end returns an ENDED step carrying
## the SkillEngine.battle()-format transcript. That transcript is byte-identical to SkillEngine.battle()
## when the player replays act() for its own mons (parity is a property of the SHARED loop + RNG order).
class InteractiveSession:
	extends RefCounted

	## Step kinds the caller (the battle UI) reacts to.
	const AWAIT_PLAYER := "await_player"  # a player actor's turn — call use_skill/capture/flee next
	const RESOLVED := "resolved"  # an AI (or just-resolved player) action happened
	const ENDED := "ended"  # the battle is over (win/lose/flee/caught)

	## End reasons surfaced on an ENDED step.
	const END_DEFEAT := "enemy_defeated"  # a team was wiped / turn cap (normal win/lose)
	const END_FLED := "fled"  # the player fled
	const END_CAUGHT := "caught"  # the player captured the wild target

	const _COMBO_MULT := 1.4  # SkillEngine.act()'s same-force chain multiplier (Constants combo_mult)

	var _ctrl: SkillBattleController
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
	# Per-side previous force this turn ("" = none, matching SkillEngine's prev_a/prev_b = "" sentinel).
	var _prev: Dictionary = {"A": "", "B": ""}
	var _ended: bool = false
	var _end_reason: String = ""
	# True while the CURRENT turn still owes its trailing blank line. SkillEngine.battle() appends ONE ""
	# after every turn's actors; the pump emits that same separator at each turn boundary (and before the
	# RESULT line) so the interactive transcript stays element-for-element identical.
	var _turn_open: bool = false
	# The actor currently awaiting a player action (set on AWAIT_PLAYER, consumed by the verbs).
	var _pending_actor: AbilityContainer = null

	func _init(
		ctrl: SkillBattleController, team_a: Array, team_b: Array, player_side: String
	) -> void:
		_ctrl = ctrl
		_team_a = team_a
		_team_b = team_b
		_player_side = player_side
		var sb: Dictionary = Constants.BALANCE["skill"]
		_turn_cap = int(sb["turn_cap"])
		_entropy_step = float(sb["entropy_step_per_turn"])

	# --- the step pump ---------------------------------------------------------------------------- #

	## Advance the battle to the NEXT decision point and return a step dict:
	##   {"kind": AWAIT_PLAYER, "actor": AbilityContainer, "foes": Array, "allies": Array, "turn": int}
	##   {"kind": RESOLVED, "actor": AbilityContainer, "turn": int}
	##   {"kind": ENDED, "reason": String, "player_won": bool, "transcript": Array}
	## AI actors resolve INLINE (their RESOLVED step is still returned, one per call) so the UI can
	## animate each action; only a player actor pauses the pump (AWAIT_PLAYER).
	func advance() -> Dictionary:
		if _ended:
			return _ended_step()
		if _pending_actor != null:
			return _await_step(_pending_actor)
		# Single return point (linter max-returns); the loop assigns `step` and breaks.
		var step: Dictionary = {}
		while step.is_empty():
			if _order_idx >= _order.size():
				_close_turn()
				if not _both_sides_alive() or _turn >= _turn_cap:
					step = _finish(END_DEFEAT)
					break
				_begin_turn()
			var actor := _order[_order_idx] as AbilityContainer
			_order_idx += 1
			if not actor.is_alive():
				continue
			# Mirror SkillEngine.battle()'s `if not _any_alive(foes): break` — end turn + battle
			# (_finish appends the turn's trailing "" + the RESULT line, exactly as battle() does).
			if not _any_alive(_foes_of(actor)):
				step = _finish(END_DEFEAT)
				break
			if _side_of(actor) == _player_side:
				_pending_actor = actor
				step = _await_step(actor)
			else:
				step = _resolve_via_act(actor)
		return step

	# --- player verbs (consume the pending player actor) ------------------------------------------ #

	## Player uses `skill` from the pending actor's kit. A SUPPORT skill (Mend/Ward/Rouse) ignores
	## `target` (the engine picks the ally); a DAMAGE/Hex skill hits `target` (falls back to the first
	## alive foe when null/dead). Draws NOTHING from the act stream (the pure damage/support don't roll).
	## Returns a RESOLVED step (or ENDED if it ends the battle).
	func use_skill(skill: String, target: AbilityContainer = null) -> Dictionary:
		var actor := _take_pending()
		if actor == null:
			return advance()
		var side := _side_of(actor)
		var verb := SkillBattleController.verb_of(skill)
		var before := actor.log_lines().size()
		if SkillBattleController.is_support_verb(verb):
			actor.use_support(skill, _allies_of(actor))
		else:
			var tgt := target
			if tgt == null or not tgt.is_alive():
				tgt = _first_alive(_foes_of(actor))
			if tgt == null:
				return _finish(END_DEFEAT)
			# Combo chain mirrors act(): x1.4 when this actor repeats its side's previous force.
			var combo := 1.0
			if _prev[side] == actor.primary_force():
				combo = _COMBO_MULT
				_log.append("   >> RESONANCE COMBO (" + actor.primary_force() + " chain) <<")
			actor.use_damage(skill, tgt, _ent, combo)
		_append_delta(actor, before)
		# act() always returns user.prim — a player action sets the side's prev to the actor's force too.
		_prev[side] = actor.primary_force()
		if not _both_sides_alive():
			return _finish(END_DEFEAT)
		return {"kind": RESOLVED, "actor": actor, "turn": _turn}

	## Drive the pending PLAYER actor by the oracle AI (act()) — identical to an enemy turn. Used by the
	## parity test (a "neutral player") and as a safe default/auto action. Draws the act stream exactly
	## where SkillEngine.battle() would for that initiative slot.
	func act_neutral() -> Dictionary:
		var actor := _take_pending()
		if actor == null:
			return advance()
		return _resolve_via_act(actor)

	## Player CAPTURE outcome (the roll is the CALLER's, on a disjoint capture sub-stream — this
	## controller never touches the act stream for a capture). SUCCESS → end as CAUGHT; FAILURE →
	## consume the turn (no action, no draw) and continue so the enemy acts next.
	func capture(success: bool) -> Dictionary:
		var actor := _take_pending()
		if actor == null:
			return advance()
		if success:
			return _finish(END_CAUGHT)
		return advance()

	## Player FLEE — ends the battle immediately as FLED. Consumes the pending turn.
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

	func entropy() -> float:
		return _ent

	func player_team() -> Array:
		return _team_a if _player_side == "A" else _team_b

	func enemy_team() -> Array:
		return _team_b if _player_side == "A" else _team_a

	## True iff the player's side has a living member (the player's win condition).
	func player_won() -> bool:
		return _any_alive(player_team())

	# --- internals -------------------------------------------------------------------------------- #

	## Resolve an actor via SkillEngine.act() (AI selects + the engine resolves), drawing the act stream
	## and folding the produced log lines into the shared transcript in order. Shared by enemy turns and
	## the neutral-player replay so both consume RNG identically to SkillEngine.battle().
	func _resolve_via_act(actor: AbilityContainer) -> Dictionary:
		var side := _side_of(actor)
		var before := actor.log_lines().size()
		var force := actor.choose_and_act(
			_allies_of(actor), _foes_of(actor), _ent, str(_prev[side]), _ctrl._act_rng
		)
		_append_delta(actor, before)
		_prev[side] = force
		if not _both_sides_alive():
			return _finish(END_DEFEAT)
		return {"kind": RESOLVED, "actor": actor, "turn": _turn}

	## Append the log lines a container produced since `before` to the shared transcript, in order. The
	## shell logs into each container's OWN _log; this folds them back into the single battle transcript
	## (so the unified log matches SkillEngine.battle()'s single-log ordering).
	func _append_delta(actor: AbilityContainer, before: int) -> void:
		var lines := actor.log_lines()
		for i in range(before, lines.size()):
			_log.append(lines[i])

	func _begin_turn() -> void:
		_turn += 1
		_ent = CanonicalMath.rnd_dp(1.0 + float(_turn - 1) * _entropy_step, 2)
		_log.append("== TURN " + str(_turn) + "   entropy x" + str(_ent) + " ==")
		_order = _turn_order()
		_order_idx = 0
		_prev = {"A": "", "B": ""}
		_turn_open = true

	## Emit SkillEngine.battle()'s per-turn trailing blank line ONCE (idempotent: a no-op when already
	## closed). Keeps the pump's blank-line placement identical to battle().
	func _close_turn() -> void:
		if _turn_open:
			_log.append("")
			_turn_open = false

	## Finalise: close the current turn block (battle()'s one trailing ""), append the RESULT line
	## (battle() format), mark ended, return the ENDED step. Idempotent.
	func _finish(reason: String) -> Dictionary:
		if _ended:
			return _ended_step()
		_close_turn()
		var winner := "TEAM A" if _any_alive(_team_a) else "TEAM B"
		_log.append("RESULT: " + winner + " wins (turn " + str(_turn) + ")")
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

	func _await_step(actor: AbilityContainer) -> Dictionary:
		return {
			"kind": AWAIT_PLAYER,
			"actor": actor,
			"foes": _foes_of(actor),
			"allies": _allies_of(actor),
			"turn": _turn,
		}

	func _take_pending() -> AbilityContainer:
		var actor := _pending_actor
		_pending_actor = null
		return actor

	## STABLE sort of alive combatants by -Celerity, team_a then team_b on ties — identical to
	## SkillEngine._turn_order (so initiative + RNG-draw order match battle()).
	func _turn_order() -> Array:
		var combined: Array = []
		for ac in _team_a:
			if (ac as AbilityContainer).is_alive():
				combined.append(ac)
		for ac in _team_b:
			if (ac as AbilityContainer).is_alive():
				combined.append(ac)
		var dec: Array = []
		for i in combined.size():
			dec.append(
				{
					"i": i,
					"m": combined[i],
					"cel": (combined[i] as AbilityContainer).stat("Celerity")
				}
			)
		dec.sort_custom(
			func(p: Dictionary, q: Dictionary) -> bool:
				if int(p["cel"]) != int(q["cel"]):
					return int(p["cel"]) > int(q["cel"])
				return int(p["i"]) < int(q["i"])
		)
		var out: Array = []
		for d in dec:
			out.append(d["m"])
		return out

	func _side_of(actor: AbilityContainer) -> String:
		for x in _team_a:
			if x == actor:
				return "A"
		return "B"

	func _foes_of(actor: AbilityContainer) -> Array:
		return _team_b if _side_of(actor) == "A" else _team_a

	func _allies_of(actor: AbilityContainer) -> Array:
		return _team_a if _side_of(actor) == "A" else _team_b

	func _any_alive(team: Array) -> bool:
		for ac in team:
			if (ac as AbilityContainer).is_alive():
				return true
		return false

	func _first_alive(team: Array) -> AbilityContainer:
		for ac in team:
			if (ac as AbilityContainer).is_alive():
				return ac
		return null

	func _both_sides_alive() -> bool:
		return _any_alive(_team_a) and _any_alive(_team_b)
