class_name AiBlackboard
extends RefCounted
## AiBlackboard (ADR-016) — the data-exchange substrate every battle brain reads/writes, mirroring
## LimboAI's Blackboard (BBInt/BBBool/BBNode...). Named AiBlackboard (not Blackboard) so it never
## collides with Beehave's own Blackboard class_name (which is a SceneTree node).
##
## APPLICATION/ai layer. Holds:
##   - rng: the ONE RngService (the BBNode->RngService pattern; the ONLY randomness source, ADR-016),
##   - snapshot: the boss's god_snapshot kit (forces/team/signature_moves) when driving the boss,
##   - a free-form key/value store for BT leaves + HSM phase gates (HP%, turn, squad losses, entropy).
##
## It carries NO outcome math. Phase-gate values (own HP%, turn count, squad losses, the entropy
## clock) are WRITTEN here each turn by the controller/brain from the live battle_state, and READ by
## HSM transition guards + BT conditions. The brain SELECTS from these; the oracle RESOLVES.

var rng: RngService
var snapshot: Dictionary = {}
var _store: Dictionary = {}


func _init(p_rng: RngService, p_snapshot: Dictionary = {}) -> void:
	rng = p_rng
	snapshot = p_snapshot


## Set a blackboard value (BBVar write).
func set_value(key: String, value: Variant) -> void:
	_store[key] = value


## Get a blackboard value, or `default` when absent (BBVar read).
func get_value(key: String, default: Variant = null) -> Variant:
	return _store.get(key, default)


func has_value(key: String) -> bool:
	return _store.has(key)


func erase_value(key: String) -> void:
	_store.erase(key)


# --- typed convenience reads (JSON.parse_string decodes bare numbers as FLOAT; these coerce
# explicitly so phase gates never compare a float to an int by accident — CLAUDE.md lesson (b)). ---


func get_int(key: String, default: int = 0) -> int:
	var v: Variant = _store.get(key, default)
	return int(v)


func get_float(key: String, default: float = 0.0) -> float:
	var v: Variant = _store.get(key, default)
	return float(v)


func get_bool(key: String, default: bool = false) -> bool:
	var v: Variant = _store.get(key, default)
	return bool(v)
