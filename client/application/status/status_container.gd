class_name StatusContainer
extends RefCounted
## StatusContainer — the buff/debuff & status SHELL (Cluster 4 D4, ADR-015 §B1, OctoD adapter).
## APPLICATION layer: a presentation/scheduling container for the 6 force-signature statuses +
## Corruption. It HOLDS and PRESENTS status state; it computes NO number. Every value (DOT damage,
## control duration countdown, corruption burnout) is produced by client/domain/status_engine.gd
## (the oracle). This container is the OctoD-style "effect container" shell: it owns the lifecycle
## (apply / tick / cleanse) by DELEGATING each call to StatusEngine on a StatusEngine.C state and
## reading back the resulting state + log. Swap in OctoD's GameplayEffectContainer => reimplement
## this one file; the contract (the methods + the data the shell exposes) is what callers depend on.
##
## Why a self-contained shell (not vendored OctoD nodes): OctoD's gameplay-systems ship their OWN
## attribute/ability MATH (a second source of truth) and are Node-based (scene-tree); adopting them
## here would either (a) drag addon math into the status path — forbidden by ADR-015 — or (b) require
## stripping them down to exactly this delegating shell. Godot is not installable here to verify a
## clean 4.7 vendor, so per the brief ("the adapter contract matters more than the lib") this is the
## minimal self-contained container that fulfils the SAME contract. See THIRD_PARTY.md (D4).

const StatusEngineScript := preload("res://domain/status_engine.gd")

## The backing combatant state the oracle mutates. data-only (name/hp/status/corruption/feral);
## NEVER a Node — this shell is a RefCounted wrapper, not a scene node.
var _c: StatusEngine.C
## The running effect log (the human-facing strings the oracle emits). Presentation only.
var _log: Array = []


func _init(c_name: String, prim: String, sec: String, tier: String) -> void:
	# HP and the initial state come from the ORACLE (StatusEngine.C derives HP via StatEngine). The
	# shell never computes the starting HP — it asks the engine.
	_c = StatusEngineScript.C.new(c_name, prim, sec, tier)


## Apply a status by name (Wither/Bloom-rot/Petrify/Shock/Seal/Madness). DELEGATES to the oracle:
## stacking (DOTs) vs refresh (control) is the engine's rule, not the shell's. Returns the new log
## lines so a UI can surface them. The shell adds NOTHING to the number of stacks / the duration.
func apply(status_name: String) -> Array:
	var before := _log.size()
	StatusEngineScript.apply(_c, status_name, _log)
	return _log.slice(before)


## Feed the Corruption meta-meter by `amt` (the oracle clamps to 130 and flips feral at threshold).
func add_corruption(amt: int, src: String) -> Array:
	var before := _log.size()
	StatusEngineScript.add_corruption(_c, amt, src, _log)
	return _log.slice(before)


## Advance one tick: DOT damage (+ spread), control countdown — ALL computed by the oracle. `allies`
## is an Array of StatusContainer (for DOT spread); we pass their underlying C states to the engine.
func tick(allies: Array = []) -> Array:
	var before := _log.size()
	var ally_states: Array = []
	for a in allies:
		ally_states.append((a as StatusContainer)._c)
	if ally_states.is_empty():
		ally_states = [_c]
	StatusEngineScript.tick(_c, ally_states, _log)
	return _log.slice(before)


## Cleanse battle statuses (Corruption persists) — the oracle decides what is cleansable (kind!="meta").
func cleanse() -> Array:
	var before := _log.size()
	StatusEngineScript.cleanse(_c, _log)
	return _log.slice(before)


# --- presentation reads (no math; pure state surface) ----------------------------------------- #


func combatant_name() -> String:
	return _c.name


## True if a status name is currently active on this combatant.
func has_status(status_name: String) -> bool:
	return _c.status.has(status_name)


## Stacks of a DOT status (0 if absent). Read straight off the engine-owned state.
func stacks_of(status_name: String) -> int:
	if not _c.status.has(status_name):
		return 0
	return int((_c.status[status_name] as Dictionary).get("stacks", 0))


## Remaining duration of a control status (0 if absent). Engine-owned countdown.
func duration_of(status_name: String) -> int:
	if not _c.status.has(status_name):
		return 0
	return int((_c.status[status_name] as Dictionary).get("dur", 0))


func hp() -> int:
	return _c.hp


func max_hp() -> int:
	return _c.maxhp


func corruption() -> int:
	return _c.corruption


func is_feral() -> bool:
	return _c.feral


func active_statuses() -> Array:
	return _c.status.keys()


func log_lines() -> Array:
	return _log.duplicate()


# --- persistence (data-only JSON; ADR-012) --------------------------------------------------- #


## Snapshot the status state as a plain dict (NEVER a Node/Resource). The status map carries
## stacks/dur ints; round-tripping re-hydrates the oracle's C state field-for-field.
func to_dict() -> Dictionary:
	return {
		"name": _c.name,
		"hp": _c.hp,
		"maxhp": _c.maxhp,
		"corruption": _c.corruption,
		"feral": _c.feral,
		"status": _status_to_dict(),
	}


## Restore IN PLACE from a snapshot. Re-int()-wraps numeric fields (JSON decodes bare numbers as
## float in GDScript) so stacks/dur/hp stay integral after a save round-trip.
func load_from(data: Dictionary) -> void:
	_c.name = str(data.get("name", _c.name))
	_c.hp = int(data.get("hp", _c.hp))
	_c.maxhp = int(data.get("maxhp", _c.maxhp))
	_c.corruption = int(data.get("corruption", 0))
	_c.feral = bool(data.get("feral", false))
	_c.status = {}
	var raw: Dictionary = data.get("status", {}) if data.get("status", {}) is Dictionary else {}
	for k in raw:
		var entry: Dictionary = raw[k] if raw[k] is Dictionary else {}
		_c.status[str(k)] = {
			"stacks": int(entry.get("stacks", 0)),
			"dur": int(entry.get("dur", 0)),
		}


func _status_to_dict() -> Dictionary:
	var out: Dictionary = {}
	for k in _c.status:
		var entry: Dictionary = _c.status[k]
		out[str(k)] = {"stacks": int(entry.get("stacks", 0)), "dur": int(entry.get("dur", 0))}
	return out
