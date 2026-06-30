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
## `with_statuses` enables the STATUS layer (Slice 4): per-turn DOT ticks, control-skip, and Hex-applied
## statuses, all via StatusEngine through a parallel StatusContainer. It is OFF by default so the parity
## proof (skill_battle_controller_parity_test) drives the pure loop, byte-identical to SkillEngine.battle().
func interactive(
	team_a: Array, team_b: Array, player_side: String = "A", with_statuses: bool = false
) -> InteractiveSession:
	return InteractiveSession.new(self, team_a, team_b, player_side, with_statuses)


## The verb of a skill id, from the single-sourced library (presentation/routing only).
static func verb_of(skill: String) -> String:
	var lib: Dictionary = Constants.BALANCE["skill"]["library"]
	if not lib.has(skill):
		return ""
	return String((lib[skill] as Dictionary).get("verb", ""))


## True if `verb` is a SUPPORT verb (targets allies; the engine picks the specific ally).
static func is_support_verb(verb: String) -> bool:
	return verb == "Mend" or verb == "Ward" or verb == "Rouse"


## The STATUS whose force-signature matches `force` (Thanatos->Wither, Cosmos->Seal, ...), or "" if the
## force owns no status. Data-driven from Constants so a Hex skill applies its force's signature status.
static func status_for_force(force: String) -> String:
	var table: Dictionary = Constants.BALANCE["status"]["statuses"]
	for status_name in table:
		var s: Dictionary = table[status_name]
		if str(s.get("kind", "")) != "meta" and str(s.get("force", "")) == force:
			return status_name
	return ""


## True if `status_name` is a CONTROL status (skips the afflicted actor's action while active).
static func is_control_status(status_name: String) -> bool:
	var table: Dictionary = Constants.BALANCE["status"]["statuses"]
	if not table.has(status_name):
		return false
	return str((table[status_name] as Dictionary).get("kind", "")) == "control"


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
	# STATUS layer (Slice 4, opt-in). When on: a parallel StatusContainer per combatant (AbilityContainer
	# -> StatusContainer) carries DOTs / controls / corruption; the canonical combat HP stays on the Mon
	# and DOT damage is folded back onto it. OFF leaves the loop byte-identical to SkillEngine.battle().
	var _with_statuses: bool = false
	var _status: Dictionary = {}

	func _init(
		ctrl: SkillBattleController,
		team_a: Array,
		team_b: Array,
		player_side: String,
		with_statuses: bool = false
	) -> void:
		_ctrl = ctrl
		_team_a = team_a
		_team_b = team_b
		_player_side = player_side
		_with_statuses = with_statuses
		var sb: Dictionary = Constants.BALANCE["skill"]
		_turn_cap = int(sb["turn_cap"])
		_entropy_step = float(sb["entropy_step_per_turn"])
		if _with_statuses:
			for ac in _team_a + _team_b:
				var c := ac as AbilityContainer
				# StatusEngine.C derives its HP assuming a WILD rank, so it only accepts wild tiers
				# (T1/T2/T3). A legendary/god creature's tier ("x"/rank tier) would crash its hp calc —
				# but the C's HP is a throwaway here (we reconcile it from the canonical Mon before every
				# tick), so a non-wild tier maps to a safe stand-in. Statuses themselves are tier-agnostic.
				var safe_tier := c.tier()
				if not (safe_tier == "T1" or safe_tier == "T2" or safe_tier == "T3"):
					safe_tier = "T3"
				var sc := StatusContainer.new(
					c.combatant_name(), c.primary_force(), c.secondary_force(), safe_tier
				)
				sc.set_hp(c.hp(), c.max_hp())
				_status[c] = sc

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
			# STATUS layer: a controlled actor (Petrify/Shock/Seal/Madness) forfeits its action this turn.
			if _with_statuses and _is_controlled(actor):
				_log.append("   " + actor.combatant_name() + " is held by a status — skips")
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
			# STATUS layer: a Hex also inflicts its force's signature status (Wither->Wither DOT,
			# Bind/Cosmos->Seal control) on the target, beyond the engine's inline defdown.
			if _with_statuses and verb == "Hex":
				_apply_hex_status(skill, tgt)
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

	## The StatusContainer fronting `actor` (statuses / corruption / feral), or null when the status layer
	## is off / the actor is unknown. The UI reads this to render status icons + a corruption meter.
	func status_of(actor: AbilityContainer) -> StatusContainer:
		return _status.get(actor, null)

	# --- internals -------------------------------------------------------------------------------- #

	## Tick every alive combatant's statuses in initiative order: DOT damage (folded onto the canonical
	## Mon HP) + control countdown, with same-side allies for DOT spread. StatusEngine has no RNG, so this
	## is deterministic. The Mon stays canonical: its HP seeds the scratch C, then the post-tick HP is
	## written back (so a DOT can down a creature exactly as a strike would).
	func _tick_statuses() -> void:
		for ac in _order:
			var c := ac as AbilityContainer
			if not c.is_alive():
				continue
			var sc := _status.get(c, null) as StatusContainer
			if sc == null:
				continue
			sc.set_hp(c.hp(), c.max_hp())
			var delta := sc.tick(_ally_status_containers(c))
			c.set_hp(sc.hp())
			for line in delta:
				_log.append(line)

	## The StatusContainers of `actor`'s living same-side allies (for DOT spread targeting).
	func _ally_status_containers(actor: AbilityContainer) -> Array:
		var out: Array = []
		for ally in _allies_of(actor):
			var sc: Variant = _status.get(ally, null)
			if sc != null:
				out.append(sc)
		return out

	## True if `actor` currently carries any CONTROL status (so it forfeits its action this turn).
	func _is_controlled(actor: AbilityContainer) -> bool:
		var sc := _status.get(actor, null) as StatusContainer
		if sc == null:
			return false
		for status_name in sc.active_statuses():
			if SkillBattleController.is_control_status(str(status_name)):
				return true
		return false

	## Apply a Hex skill's force-signature status to `target` (Wither->Wither, Bind/Cosmos->Seal, ...),
	## folding the engine's apply log into the transcript. No-op if the force owns no status.
	func _apply_hex_status(skill: String, target: AbilityContainer) -> void:
		var lib: Dictionary = Constants.BALANCE["skill"]["library"]
		var force := str((lib.get(skill, {}) as Dictionary).get("force", ""))
		var status_name := SkillBattleController.status_for_force(force)
		if status_name == "":
			return
		var sc := _status.get(target, null) as StatusContainer
		if sc == null:
			return
		var delta := sc.apply(status_name)
		for line in delta:
			_log.append(line)

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
		# STATUS layer: at the top of each turn, tick DOTs (damage folded onto the canonical Mon) and
		# count down controls — in initiative order, with same-side allies for DOT spread. No-op when off.
		if _with_statuses:
			_tick_statuses()

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
