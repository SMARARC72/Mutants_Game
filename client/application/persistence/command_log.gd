class_name CommandLog
extends RefCounted
## Append-only DETERMINISTIC command list (ADR-005, TDD §6.6 / §10.1). Because the sim is
## deterministic, the durable record of a run is `(seed, ordered command log)` and the full
## state is a fold of the commands over the seed. We persist this log ALONGSIDE the
## materialized snapshot for audit / replay / reproducible bug reports.
##
## Each command is a plain dict: { "seq": int, "type": String, "payload": Dictionary }.
## `seq` is a monotonic 0-based counter assigned on append. Data only (ADR-012) — a command
## is JSON, never a callable/Resource.
##
## Phase 3 scope: the log is LOCAL (lives inside the JSON save) + an offline queue of
## not-yet-synced commands. FUTURE SEAM: a cloud `command_log` table (keyed by run_id + seq)
## for server-side re-validation (TDD §8.4); the offline queue below is what flushes to it.
## Nothing here computes gameplay numbers — `replay` delegates each command to a caller-
## supplied applier; the oracle owns the math.

const LOG_VERSION := 1

## Ordered commands: each { seq, type, payload }.
var _commands: Array = []
## seq values not yet acknowledged by the cloud (the offline write queue, TDD §10.3).
var _pending_seqs: Array = []


## Appends a command and returns its assigned seq. New commands enter the offline queue
## until `mark_synced` clears them.
func append(type: String, payload: Dictionary = {}) -> int:
	var seq := _commands.size()
	_commands.append({"seq": seq, "type": type, "payload": payload.duplicate(true)})
	_pending_seqs.append(seq)
	return seq


func size() -> int:
	return _commands.size()


func is_empty() -> bool:
	return _commands.is_empty()


## Read-only copy of the ordered command list.
func commands() -> Array:
	return _commands.duplicate(true)


# --- offline sync queue (TDD §10.3) ------------------------------------------ #


## Commands awaiting a cloud write, in seq order (what the reconnect flush sends).
func pending() -> Array:
	var out: Array = []
	for cmd in _commands:
		if _pending_seqs.has(int((cmd as Dictionary).get("seq", -1))):
			out.append((cmd as Dictionary).duplicate(true))
	return out


func has_pending() -> bool:
	return not _pending_seqs.is_empty()


## Clears the offline queue up to AND INCLUDING `up_to_seq` (the server's last accepted seq).
func mark_synced(up_to_seq: int) -> void:
	var remaining: Array = []
	for seq in _pending_seqs:
		if int(seq) > up_to_seq:
			remaining.append(int(seq))
	_pending_seqs = remaining


# --- deterministic replay ---------------------------------------------------- #


## Folds the commands over an initial state, IN ORDER, by calling `applier` once per
## command. `applier` is a Callable(state: Variant, command: Dictionary) -> Variant that
## returns the next state. The fold is deterministic: identical (initial_state, log,
## applier) ALWAYS yields the identical result (TDD §11.4 replay test). We never read
## wall-clock or RNG here; determinism is the applier's + oracle's responsibility.
func replay(initial_state: Variant, applier: Callable) -> Variant:
	var state: Variant = initial_state
	for cmd in _commands:
		state = applier.call(state, (cmd as Dictionary).duplicate(true))
	return state


# --- serialization (data-only; ADR-012) -------------------------------------- #


func to_dict() -> Dictionary:
	return {
		"version": LOG_VERSION,
		"commands": _commands.duplicate(true),
		"pending_seqs": _pending_seqs.duplicate(true),
	}


func load_from(data: Dictionary) -> void:
	_commands = []
	for cmd in _as_array(data.get("commands", [])):
		if cmd is Dictionary:
			var d: Dictionary = cmd
			var normalized := {
				"seq": int(d.get("seq", _commands.size())),
				"type": str(d.get("type", "")),
				"payload": _as_dict(d.get("payload", {})),
			}
			_commands.append(normalized)
	_pending_seqs = []
	for seq in _as_array(data.get("pending_seqs", [])):
		_pending_seqs.append(int(seq))


static func from_dict(data: Dictionary) -> CommandLog:
	var log := CommandLog.new()
	log.load_from(data)
	return log


static func _as_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


static func _as_array(value: Variant) -> Array:
	if value is Array:
		return (value as Array).duplicate(true)
	return []
