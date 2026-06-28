class_name RoleBrains
extends RefCounted
## RoleBrains (ADR-016) — lightweight behaviour trees for the three battle creature roles
## (aggressor / support / controller), built on the self-contained BehaviorTree kernel and reading
## the shared AiBlackboard. Each role is a different TARGET-SELECTION policy expressed as a BT; the
## brain SELECTS a target (and the offense kind the oracle will use), the controller RESOLVES the
## strike via BattleEngine.attack. NO outcome math here.
##
## The blackboard contract each tree reads (written by BattleController before ticking):
##   "actor"      : BattleEngine.Mon            -- the deciding combatant
##   "foes"       : Array[BattleEngine.Mon]     -- the opposing team (team order preserved)
##   "allies"     : Array[BattleEngine.Mon]     -- the actor's own team
## The Action dict an Action leaf writes (ctx "result"):
##   { "actor": Mon, "target": Mon, "offense": [power:int, kind:String, defstat:String] }
## offense mirrors BattleEngine.Mon.offense() (Spike vs Bane, Spike wins ties) so the brain's choice
## stays consistent with the oracle's strike resolver.

const Bt := preload("res://application/ai/behavior_tree.gd")

# --- target-selection policies -----------------------------------------------------------------
#
# ADR-016 SELECTION RNG: the role policies draw from the injected canonical SEL sub-stream ONLY to
# break a TIE among equally-best targets (a pure selection choice, never a resolution number). A draw
# happens ONLY when 2+ candidates are equally best — a single best target consumes NO randomness, so
# replay stays a clean function of (seed, teams). The NEUTRAL policy (first_alive) is RNG-free by
# design, so the controller-vs-simulate parity for a neutral brain is byte-identical (it draws
# nothing from SEL, exactly like simulate's hardcoded _first_alive). Tie-break uses rng.choice over
# the equally-best set in TEAM ORDER, so the candidate list is itself deterministic.


## First alive foe in team order — the oracle's default (_first_alive). RNG-FREE (neutral baseline).
static func first_alive(foes: Array) -> BattleEngine.Mon:
	for f in foes:
		if (f as BattleEngine.Mon).alive:
			return f as BattleEngine.Mon
	return null


## All alive foes tied at the minimum HP, in team order. >1 element ⇒ a genuine tie to break.
static func lowest_hp_candidates(foes: Array) -> Array:
	var best := first_alive(foes)
	if best == null:
		return []
	var min_hp := best.hp
	for f in foes:
		var m := f as BattleEngine.Mon
		if m.alive and m.hp < min_hp:
			min_hp = m.hp
	var out: Array = []
	for f in foes:
		var m := f as BattleEngine.Mon
		if m.alive and m.hp == min_hp:
			out.append(m)
	return out


## Lowest-HP foe, canonical tie-break among equals via the SEL sub-stream (rng). FIRST-wins only
## when there is no tie. A draw is consumed ONLY when 2+ foes share the minimum HP.
static func lowest_hp(foes: Array, rng: RngService) -> BattleEngine.Mon:
	var cands := lowest_hp_candidates(foes)
	if cands.is_empty():
		return null
	if cands.size() == 1:
		return cands[0] as BattleEngine.Mon
	return rng.choice(cands) as BattleEngine.Mon


## All alive foes whose pole the actor's primary force OVERWHELMS (opposed pole), in team order.
static func overwhelmed_candidates(actor: BattleEngine.Mon, foes: Array) -> Array:
	var opposed: Variant = BattleEngine.OPP.get(actor.prim, null)
	var out: Array = []
	if opposed == null:
		return out
	for f in foes:
		var m := f as BattleEngine.Mon
		if m.alive and m.prim == opposed:
			out.append(m)
	return out


## A foe the actor overwhelms (opposed pole, force_mult 1.5), canonical tie-break among equals via
## the SEL sub-stream; else first alive. A draw is consumed ONLY when 2+ overwhelmed foes exist.
static func best_matchup(actor: BattleEngine.Mon, foes: Array, rng: RngService) -> BattleEngine.Mon:
	var cands := overwhelmed_candidates(actor, foes)
	if cands.is_empty():
		return first_alive(foes)
	if cands.size() == 1:
		return cands[0] as BattleEngine.Mon
	return rng.choice(cands) as BattleEngine.Mon


# --- the Action a role commits (target + offense), or null when no foe is alive ------------------


static func _commit(actor: BattleEngine.Mon, target: BattleEngine.Mon) -> Variant:
	if target == null:
		return null
	return {"actor": actor, "target": target, "offense": actor.offense()}


# --- role trees ---------------------------------------------------------------------------------


## Aggressor: go for the kill — target lowest-HP foe (canonical tie-break via ctx.rng among equals);
## fall back to first-alive. Draws from the SEL sub-stream ONLY when foes tie at minimum HP.
static func aggressor() -> BehaviorTree.BtNode:
	var act: BehaviorTree.Action = Bt.Action.new(
		func(ctx: AiBlackboard) -> Variant:
			var actor := ctx.get_value("actor") as BattleEngine.Mon
			var foes: Array = ctx.get_value("foes", [])
			var tgt := lowest_hp(foes, ctx.rng)
			if tgt == null:
				tgt = first_alive(foes)
			return _commit(actor, tgt)
	)
	return act


## Controller: exploit force matchups — target a pole this actor overwhelms (canonical tie-break via
## ctx.rng among equals); else first-alive. Draws from SEL ONLY when 2+ overwhelmed foes exist.
static func controller() -> BehaviorTree.BtNode:
	var act: BehaviorTree.Action = Bt.Action.new(
		func(ctx: AiBlackboard) -> Variant:
			var actor := ctx.get_value("actor") as BattleEngine.Mon
			var foes: Array = ctx.get_value("foes", [])
			return _commit(actor, best_matchup(actor, foes, ctx.rng))
	)
	return act


## Support: in the auto-battler strike model there is no heal verb (battle_engine.attack only
## strikes), so the support role plays conservatively — protect tempo by finishing the weakest foe
## (canonical tie-break via ctx.rng among equals), else strike first-alive. (When a skill-based
## controller is wired, this is where a Mend/Ward selection BT slots in, still SELECTING only.)
static func support() -> BehaviorTree.BtNode:
	var act: BehaviorTree.Action = Bt.Action.new(
		func(ctx: AiBlackboard) -> Variant:
			var actor := ctx.get_value("actor") as BattleEngine.Mon
			var foes: Array = ctx.get_value("foes", [])
			var tgt := lowest_hp(foes, ctx.rng)
			if tgt == null:
				tgt = first_alive(foes)
			return _commit(actor, tgt)
	)
	return act


## Default/neutral brain: parity with the oracle's hardcoded selection (first-alive + native
## offense). RNG-FREE by design — it draws NOTHING from SEL, so the BattleController reproduces
## simulate()'s target choices byte-for-byte while still routing every strike through the
## brain->oracle path (the determinism showcase).
static func neutral() -> BehaviorTree.BtNode:
	var act: BehaviorTree.Action = Bt.Action.new(
		func(ctx: AiBlackboard) -> Variant:
			var actor := ctx.get_value("actor") as BattleEngine.Mon
			var foes: Array = ctx.get_value("foes", [])
			return _commit(actor, first_alive(foes))
	)
	return act


## All alive foes in team order (a deterministic candidate list to draw over).
static func alive_foes(foes: Array) -> Array:
	var out: Array = []
	for f in foes:
		if (f as BattleEngine.Mon).alive:
			out.append(f)
	return out


## Unpredictable: with probability `lash_chance` (a SEL `chance` roll EVERY decision) the actor
## "lashes out" at a canonically-chosen random alive foe (a SEL `choice` draw); otherwise it exploits
## the best force matchup. Used by the boss's Apotheosis phase so the HSM path genuinely consumes the
## canonical sub-stream on every turn (ADR-016), not only on ties. Selection-only: it picks WHO, never
## a damage number. Two equal seeds ⇒ identical picks; different seeds ⇒ the picks CAN differ.
static func unpredictable(lash_chance: float = 0.5) -> BehaviorTree.BtNode:
	var act: BehaviorTree.Action = Bt.Action.new(
		func(ctx: AiBlackboard) -> Variant:
			var actor := ctx.get_value("actor") as BattleEngine.Mon
			var foes: Array = ctx.get_value("foes", [])
			var living := alive_foes(foes)
			if living.is_empty():
				return null
			if ctx.rng.chance(lash_chance):
				return _commit(actor, ctx.rng.choice(living) as BattleEngine.Mon)
			return _commit(actor, best_matchup(actor, foes, ctx.rng))
	)
	return act


## Map a role name -> its BT. Unknown roles fall back to neutral (oracle-parity).
static func for_role(role: String) -> BehaviorTree.BtNode:
	match role:
		"aggressor":
			return aggressor()
		"support":
			return support()
		"controller":
			return controller()
		"unpredictable":
			return unpredictable()
		_:
			return neutral()
