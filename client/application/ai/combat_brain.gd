class_name CombatBrain
extends RefCounted
## CombatBrain (ADR-016) — THE FACADE. `choose_action(battle_state, rng) -> Action`. The battle
## controller calls it, passes the injected canonical RNG sub-stream, gets a chosen Action, and
## RESOLVES it via the oracle (battle_engine.attack). The brain NEVER resolves and NEVER computes a
## number — it only SELECTS (target + offense). Swapping the AI backend = reimplement THIS file; the
## controller is untouched (Integrations §P3 "adapter/facade per addon").
##
## Backed by a self-contained GDScript BT (role brains) + HSM (the Succession boss) on a shared
## AiBlackboard whose ONLY randomness source is the RngService wrapping the injected CanonicalRNG
## (ADR-016: never LimboAI/Beehave/global randf/randi). See the report + addons/THIRD_PARTY.md for
## why a self-contained kernel rather than the vendored LimboAI GDExtension.
##
## THE Action TYPE (a plain Dictionary so it serialises into a transcript / save without a custom
## Resource — ADR-012):
##   { "actor":  BattleEngine.Mon,            # the deciding combatant (object identity)
##     "target": BattleEngine.Mon,            # who to strike (chosen by the brain)
##     "offense":[power:int, kind:String, defstat:String] }  # the offense the oracle will use
## On "no legal action" (no foe alive) choose_action returns {} (empty) — the controller treats that
## as "skip / battle effectively over", never a crash.

const RoleBrainsScript := preload("res://application/ai/role_brains.gd")
const SuccessionBossScript := preload("res://application/ai/succession_boss.gd")
const BlackboardScript := preload("res://application/ai/blackboard.gd")
const RngServiceScript := preload("res://application/ai/rng_service.gd")

# Per-actor brain assignment. Keyed by the Mon (object identity). A boss actor maps to an Hsm; a
# role actor maps to a BehaviorTree.BtNode. Unassigned actors use the neutral (oracle-parity) brain.
var _brains: Dictionary = {}
var _snapshot: Dictionary = {}
var _default_tree: BehaviorTree.BtNode


func _init(snapshot: Dictionary = {}) -> void:
	_snapshot = snapshot
	_default_tree = RoleBrainsScript.neutral()


## Assign a creature role brain ("aggressor"/"support"/"controller"/"neutral") to a combatant.
func assign_role(actor: BattleEngine.Mon, role: String) -> void:
	_brains[actor] = {"kind": "role", "tree": RoleBrainsScript.for_role(role)}


## Assign the Succession boss HSM to a combatant. `gates` overrides default phase thresholds.
func assign_boss(actor: BattleEngine.Mon, gates: Dictionary = {}) -> void:
	_brains[actor] = {"kind": "boss", "hsm": SuccessionBossScript.build(gates)}


## Is this combatant driven by the boss HSM? (Lets the controller surface phase info in a transcript.)
func is_boss(actor: BattleEngine.Mon) -> bool:
	var b: Variant = _brains.get(actor, null)
	return b != null and str((b as Dictionary).get("kind", "")) == "boss"


## The boss HSM's current phase for `actor`, or "" if `actor` is not a boss / not yet started.
func boss_phase(actor: BattleEngine.Mon) -> String:
	var b: Variant = _brains.get(actor, null)
	if b == null or str((b as Dictionary).get("kind", "")) != "boss":
		return ""
	return ((b as Dictionary)["hsm"] as Hsm).current_state()


## THE FACADE METHOD. Select an Action for `battle_state.actor`, drawing any selection randomness
## from the injected canonical sub-stream `rng` (ADR-016). `battle_state` is a Dictionary:
##   { "actor": Mon, "allies": Array[Mon], "foes": Array[Mon],
##     "turn": int, "entropy": float,                # the entropy clock (phase gate)
##     "boss_hp_frac": float, "boss_squad_losses": int }   # boss phase gates (optional)
## Returns the chosen Action dict, or {} when no selection is possible.
func choose_action(battle_state: Dictionary, rng: CanonicalRNG) -> Dictionary:
	var actor := battle_state.get("actor") as BattleEngine.Mon
	if actor == null:
		return {}

	# Build the per-decision blackboard: the RngService wrapping the injected canonical sub-stream is
	# the ONLY randomness source (the BBNode->RngService pattern). All gate values come from the
	# controller-supplied battle_state (live, not recomputed here).
	var rng_service := RngServiceScript.new(rng)
	var bb := BlackboardScript.new(rng_service, _snapshot)
	bb.set_value("actor", actor)
	bb.set_value("allies", battle_state.get("allies", []))
	bb.set_value("foes", battle_state.get("foes", []))
	bb.set_value("turn", int(battle_state.get("turn", 0)))
	bb.set_value("entropy", float(battle_state.get("entropy", 1.0)))
	bb.set_value("boss_hp_frac", float(battle_state.get("boss_hp_frac", 1.0)))
	bb.set_value("boss_squad_losses", int(battle_state.get("boss_squad_losses", 0)))

	var entry: Variant = _brains.get(actor, null)
	if entry != null and str((entry as Dictionary)["kind"]) == "boss":
		var hsm := (entry as Dictionary)["hsm"] as Hsm
		var action := hsm.update(bb)
		if not action.is_empty():
			action["phase"] = hsm.current_state()
		return action

	var tree: BehaviorTree.BtNode = _default_tree
	if entry != null and (entry as Dictionary).has("tree"):
		tree = (entry as Dictionary)["tree"]
	bb.erase_value("result")
	tree.tick(bb)
	var res: Variant = bb.get_value("result", {})
	return res if res is Dictionary else {}
