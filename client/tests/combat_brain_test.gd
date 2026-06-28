extends GdUnitTestSuite
## CombatBrain facade + role-brain selection policies (ADR-016).
##
## Proves the facade contract: choose_action(battle_state, rng) -> Action, where Action is a plain
## Dictionary {actor, target, offense} (no Resource — ADR-012). The brain SELECTS only; it never
## mutates HP / computes damage (that stays in the oracle). Role policies pick the documented target.

const CombatBrainScript := preload("res://application/ai/combat_brain.gd")
const RoleBrainsScript := preload("res://application/ai/role_brains.gd")


func _mon(name: String, prim: String, sec: String) -> BattleEngine.Mon:
	return BattleEngine.Mon.new(name, prim, sec, "wild", "T2")


func test_choose_action_returns_action_shape() -> void:
	var brain := CombatBrainScript.new()
	var actor := _mon("A", "Chaos", "Thanatos")
	var foe := _mon("F", "Cosmos", "Eros")
	var st := {"actor": actor, "allies": [actor], "foes": [foe], "turn": 1, "entropy": 1.0}
	var action := brain.choose_action(st, CanonicalRNG.new(1))

	assert_bool(action.has("actor")).is_true()
	assert_bool(action.has("target")).is_true()
	assert_bool(action.has("offense")).is_true()
	assert_object(action["actor"]).is_same(actor)
	assert_object(action["target"]).is_same(foe)
	# offense mirrors Mon.offense(): [power:int, kind:String, defstat:String].
	var off: Array = action["offense"]
	assert_int(off.size()).is_equal(3)
	assert_bool(str(off[1]) == "Spike" or str(off[1]) == "Bane").is_true()


func test_brain_never_mutates_combatants() -> void:
	# The brain only selects — HP/alive of every combatant is untouched by choose_action.
	var brain := CombatBrainScript.new()
	var actor := _mon("A", "Chaos", "Thanatos")
	var foe := _mon("F", "Cosmos", "Eros")
	var foe_hp_before := foe.hp
	var actor_hp_before := actor.hp
	var st := {"actor": actor, "allies": [actor], "foes": [foe], "turn": 1, "entropy": 1.0}
	brain.choose_action(st, CanonicalRNG.new(1))
	assert_int(foe.hp).is_equal(foe_hp_before)
	assert_int(actor.hp).is_equal(actor_hp_before)
	assert_bool(foe.alive).is_true()


func test_no_foe_alive_returns_empty_action() -> void:
	var brain := CombatBrainScript.new()
	var actor := _mon("A", "Chaos", "Thanatos")
	var dead := _mon("D", "Cosmos", "Eros")
	dead.alive = false
	var st := {"actor": actor, "allies": [actor], "foes": [dead], "turn": 1, "entropy": 1.0}
	var action := brain.choose_action(st, CanonicalRNG.new(1))
	assert_bool(action.is_empty()).is_true()


func test_aggressor_targets_lowest_hp() -> void:
	var foes: Array = [_mon("Full", "Gaia", "Ouranos"), _mon("Hurt", "Cosmos", "Eros")]
	(foes[1] as BattleEngine.Mon).hp = 1  # the weakest
	var tgt := RoleBrainsScript.lowest_hp(foes)
	assert_object(tgt).is_same(foes[1])


func test_controller_targets_opposed_force() -> void:
	# A Chaos actor overwhelms Cosmos (opposed pole) — controller should pick the Cosmos foe even
	# though it is not first in team order.
	var actor := _mon("Caster", "Chaos", "Thanatos")
	var foes: Array = [_mon("Neutral", "Gaia", "Ouranos"), _mon("Weak", "Cosmos", "Eros")]
	var tgt := RoleBrainsScript.best_matchup(actor, foes)
	assert_object(tgt).is_same(foes[1])


func test_neutral_brain_picks_first_alive() -> void:
	# Parity policy: skip dead, pick first alive in team order (== oracle _first_alive).
	var foes: Array = [_mon("Dead", "Gaia", "Ouranos"), _mon("Alive", "Cosmos", "Eros")]
	(foes[0] as BattleEngine.Mon).alive = false
	var tgt := RoleBrainsScript.first_alive(foes)
	assert_object(tgt).is_same(foes[1])


func test_is_boss_and_phase_reporting() -> void:
	var brain := CombatBrainScript.new()
	var boss := BattleEngine.Mon.new("Boss", "Chaos", "Thanatos", "god", "god")
	var grunt := _mon("Grunt", "Gaia", "Ouranos")
	brain.assign_boss(boss)
	brain.assign_role(grunt, "aggressor")
	assert_bool(brain.is_boss(boss)).is_true()
	assert_bool(brain.is_boss(grunt)).is_false()
	# Before any decision the HSM has not started -> empty phase; after a decision it reports Opening.
	var foe := _mon("Hero", "Cosmos", "Eros")
	var st := {"actor": boss, "allies": [boss], "foes": [foe], "turn": 1, "entropy": 1.0}
	brain.choose_action(st, CanonicalRNG.new(5))
	assert_str(brain.boss_phase(boss)).is_equal("Opening")
