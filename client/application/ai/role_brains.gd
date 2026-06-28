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

# --- target-selection policies (pure reads; ties resolve FIRST-wins = team order, matching the
#     oracle's _first_alive stability) -------------------------------------------------------------


## First alive foe in team order — the oracle's default (_first_alive). The neutral baseline policy.
static func first_alive(foes: Array) -> BattleEngine.Mon:
	for f in foes:
		if (f as BattleEngine.Mon).alive:
			return f as BattleEngine.Mon
	return null


## Lowest absolute HP alive foe (FIRST-wins on ties) — the "finisher" policy (mirrors
## skill_engine._min_by_hp). Presses a kill to remove an enemy action economy.
static func lowest_hp(foes: Array) -> BattleEngine.Mon:
	var best: BattleEngine.Mon = null
	for f in foes:
		var m := f as BattleEngine.Mon
		if not m.alive:
			continue
		if best == null or m.hp < best.hp:
			best = m
	return best


## Foe the actor's primary force OVERWHELMS (opposed pole, force_mult 1.5), else first alive. The
## "exploit weakness" policy: pick the matchup the oracle will score hardest.
static func best_matchup(actor: BattleEngine.Mon, foes: Array) -> BattleEngine.Mon:
	var opposed: Variant = BattleEngine.OPP.get(actor.prim, null)
	if opposed != null:
		for f in foes:
			var m := f as BattleEngine.Mon
			if m.alive and m.prim == opposed:
				return m
	return first_alive(foes)


# --- the Action a role commits (target + offense), or null when no foe is alive ------------------


static func _commit(actor: BattleEngine.Mon, target: BattleEngine.Mon) -> Variant:
	if target == null:
		return null
	return {"actor": actor, "target": target, "offense": actor.offense()}


# --- role trees ---------------------------------------------------------------------------------


## Aggressor: go for the kill — target lowest-HP foe; fall back to first-alive.
static func aggressor() -> BehaviorTree.BtNode:
	var act: BehaviorTree.Action = Bt.Action.new(
		func(ctx: AiBlackboard) -> Variant:
			var actor := ctx.get_value("actor") as BattleEngine.Mon
			var foes: Array = ctx.get_value("foes", [])
			var tgt := lowest_hp(foes)
			if tgt == null:
				tgt = first_alive(foes)
			return _commit(actor, tgt)
	)
	return act


## Controller: exploit force matchups — target a pole this actor overwhelms; else first-alive.
static func controller() -> BehaviorTree.BtNode:
	var act: BehaviorTree.Action = Bt.Action.new(
		func(ctx: AiBlackboard) -> Variant:
			var actor := ctx.get_value("actor") as BattleEngine.Mon
			var foes: Array = ctx.get_value("foes", [])
			return _commit(actor, best_matchup(actor, foes))
	)
	return act


## Support: in the auto-battler strike model there is no heal verb (battle_engine.attack only
## strikes), so the support role plays conservatively — protect tempo by finishing the weakest foe,
## else strike first-alive. (When a skill-based controller is wired, this is where a Mend/Ward
## selection BT slots in, still SELECTING only.)
static func support() -> BehaviorTree.BtNode:
	var act: BehaviorTree.Action = Bt.Action.new(
		func(ctx: AiBlackboard) -> Variant:
			var actor := ctx.get_value("actor") as BattleEngine.Mon
			var foes: Array = ctx.get_value("foes", [])
			var tgt := lowest_hp(foes)
			if tgt == null:
				tgt = first_alive(foes)
			return _commit(actor, tgt)
	)
	return act


## Default/neutral brain: parity with the oracle's hardcoded selection (first-alive + native
## offense). The BattleController uses THIS to reproduce simulate()'s target choices exactly while
## still routing every strike through the brain->oracle path (the determinism showcase).
static func neutral() -> BehaviorTree.BtNode:
	var act: BehaviorTree.Action = Bt.Action.new(
		func(ctx: AiBlackboard) -> Variant:
			var actor := ctx.get_value("actor") as BattleEngine.Mon
			var foes: Array = ctx.get_value("foes", [])
			return _commit(actor, first_alive(foes))
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
		_:
			return neutral()
