class_name QuestService
extends RefCounted
## The narrative quest facade (ADR-017, deliverable D1). It is the ONLY thing that
## reads + writes RUN STATE on narrative's behalf, to **trigger** and **gate** — and
## it NEVER computes gameplay outcomes (no stats, no damage, no splice/capture math;
## that is the oracle's job in `client/domain/`). Quests only flip narrative flags:
## region access, unlocks, capture marks, corruption nudges, faction standing.
##
## Public API: start / advance / complete / is_active / is_done / state.
##
## Layering: lives in `application/`. The Questify addon is reached ONLY through
## `QuestTrackerFacade` (infrastructure) — no addon type crosses into here. Run state
## is `NarrativeRunState`. Everything serializes to the versioned-JSON save (ADR-012).
##
## A quest DEFINITION is plain data:
##   {
##     "id": String,
##     "name": String,
##     "description": String,
##     "trigger": { <run-state predicate>, optional },
##     "steps": [ { "id": String, "description": String,
##                  "on_complete": { <run-state effect> } }, ... ],
##     "on_complete": { <run-state effect>, applied when the whole quest finishes }
##   }
## A run-state EFFECT is data the service interprets (it does the flipping itself, so
## the gating logic is auditable and lives nowhere near the engines):
##   { "unlock_region": "id", "grant_creature": "id", "mark_captured": "id",
##     "set_flag": "key", "add_corruption": int, "nudge_standing": ["faction", int] }

signal quest_started(quest_id: String)
signal quest_advanced(quest_id: String, step_id: String)
signal quest_completed(quest_id: String)
signal run_state_changed(reason: String)

const SAVE_SECTION := "narrative"
const QUEST_STATE_VERSION := 1

var _run_state: NarrativeRunState
var _tracker: QuestTrackerFacade
var _definitions: Dictionary = {}  # quest_id -> definition dict
var _statuses: Dictionary = {}  # quest_id -> "inactive"|"active"|"done"
var _step_cursor: Dictionary = {}  # quest_id -> int (index of next step)


func _init(run_state: NarrativeRunState = null, tracker: QuestTrackerFacade = null) -> void:
	_run_state = run_state if run_state != null else NarrativeRunState.new()
	_tracker = tracker if tracker != null else QuestTrackerFacade.new()


func run_state() -> NarrativeRunState:
	return _run_state


## Registers quest definitions (data-only). Idempotent; does not start them.
func register(definitions: Array) -> void:
	for definition in definitions:
		var quest_id: String = str(definition.get("id", ""))
		if quest_id == "":
			continue
		_definitions[quest_id] = definition
		if not _statuses.has(quest_id):
			_statuses[quest_id] = "inactive"
			_step_cursor[quest_id] = 0


## Starts a quest by id. Honors an optional data `trigger` predicate against run
## state — if present and unmet, the quest stays inactive and we return false.
func start(quest_id: String) -> bool:
	var definition: Dictionary = _definitions.get(quest_id, {})
	if definition.is_empty():
		push_error("QuestService.start: unknown quest '%s'." % quest_id)
		return false
	if _statuses.get(quest_id, "inactive") != "inactive":
		return false
	var trigger: Dictionary = definition.get("trigger", {})
	if not trigger.is_empty() and not _trigger_met(trigger):
		return false
	_statuses[quest_id] = "active"
	_step_cursor[quest_id] = 0
	_tracker.start_quest(definition)
	quest_started.emit(quest_id)
	return true


## Advances a quest by one step (or a named step). Applies that step's run-state
## effect (the gate write), advances the addon tracker, and auto-completes the quest
## when the last step is done. Returns true if a step was advanced.
func advance(quest_id: String, step: Variant = null) -> bool:
	if not is_active(quest_id):
		return false
	var definition: Dictionary = _definitions.get(quest_id, {})
	var steps: Array = definition.get("steps", [])
	var cursor: int = _step_cursor.get(quest_id, 0)
	var index: int = cursor
	if step is String:
		# A named step (the Ink `quest_<id>_advance` path) must be exactly the next
		# expected step. Reject naming a later step (would skip earlier effects and
		# auto-complete) or an earlier/already-applied step (would re-apply corruption,
		# flags, etc.). Sequential advances (step == null) already follow the cursor.
		var named: int = _index_of_step(steps, step)
		if named != cursor:
			return false
		index = named
	if index >= steps.size():
		return complete(quest_id)
	var step_def: Dictionary = steps[index]
	var step_id: String = str(step_def.get("id", ""))
	_apply_effect(step_def.get("on_complete", {}), "step:%s/%s" % [quest_id, step_id])
	# The addon tracks objective bookkeeping (active/completed + serialization); Quest
	# service stays authoritative on quest completion via its own ordered cursor.
	_tracker.complete_step(quest_id, step_id)
	_step_cursor[quest_id] = index + 1
	quest_advanced.emit(quest_id, step_id)
	if _step_cursor[quest_id] >= steps.size():
		complete(quest_id)
	return true


## Completes a quest wholesale: applies the quest-level effect + marks done.
func complete(quest_id: String) -> bool:
	if _statuses.get(quest_id, "inactive") == "done":
		return false
	var definition: Dictionary = _definitions.get(quest_id, {})
	if definition.is_empty():
		return false
	_tracker.complete_quest(quest_id)
	_apply_effect(definition.get("on_complete", {}), "complete:%s" % quest_id)
	_statuses[quest_id] = "done"
	_step_cursor[quest_id] = (definition.get("steps", []) as Array).size()
	quest_completed.emit(quest_id)
	return true


func is_active(quest_id: String) -> bool:
	return _statuses.get(quest_id, "inactive") == "active"


func is_done(quest_id: String) -> bool:
	return _statuses.get(quest_id, "inactive") == "done"


## A data-only snapshot of all quest progress (for UI + debugging).
func state() -> Dictionary:
	var quests: Dictionary = {}
	for quest_id in _statuses:
		quests[quest_id] = {
			"status": _statuses[quest_id],
			"step_cursor": _step_cursor.get(quest_id, 0),
			"active_steps": _tracker.active_step_ids(quest_id),
			"completed_steps": _tracker.completed_step_ids(quest_id),
		}
	return quests


# --- run-state predicates + effects (the gate/trigger logic) --- #


func _trigger_met(trigger: Dictionary) -> bool:
	if (
		trigger.has("region_unlocked")
		and not _run_state.region_unlocked(str(trigger.region_unlocked))
	):
		return false
	if trigger.has("has_creature") and not _run_state.has_creature(str(trigger.has_creature)):
		return false
	if trigger.has("min_corruption") and _run_state.corruption < int(trigger.min_corruption):
		return false
	if trigger.has("flag") and not _run_state.flag(str(trigger.flag)):
		return false
	if trigger.has("min_standing"):
		var pair: Array = trigger.min_standing
		if pair.size() == 2 and _run_state.standing_with(str(pair[0])) < int(pair[1]):
			return false
	return true


func _apply_effect(effect: Dictionary, reason: String) -> void:
	if effect.is_empty():
		return
	if effect.has("unlock_region"):
		_run_state.unlock_region(str(effect.unlock_region))
	if effect.has("grant_creature"):
		_run_state.grant_creature(str(effect.grant_creature))
	if effect.has("mark_captured"):
		_run_state.mark_captured(str(effect.mark_captured))
	if effect.has("set_flag"):
		_run_state.set_flag(str(effect.set_flag), true)
	if effect.has("add_corruption"):
		_run_state.add_corruption(int(effect.add_corruption))
	if effect.has("nudge_standing"):
		var pair: Array = effect.nudge_standing
		if pair.size() == 2:
			_run_state.nudge_standing(str(pair[0]), int(pair[1]))
	run_state_changed.emit(reason)


func _index_of_step(steps: Array, step_id: String) -> int:
	for i in steps.size():
		if str(steps[i].get("id", "")) == step_id:
			return i
	return -1


# --- persistence: versioned-JSON, data-only (ADR-012) --- #


## The narrative payload to embed in the versioned-JSON save under SAVE_SECTION.
func serialize() -> Dictionary:
	return {
		"version": QUEST_STATE_VERSION,
		"run_state": _run_state.to_dict(),
		"statuses": _statuses.duplicate(true),
		"step_cursor": _step_cursor.duplicate(true),
		"tracker": _tracker.serialize(),
	}


## Restores from a save payload (the SAVE_SECTION dict). Definitions must already be
## registered so quest graphs can be rebuilt with their original shape.
func deserialize(data: Dictionary) -> void:
	if data.is_empty():
		return
	# Restore IN PLACE (not by replacement) so cached references stay valid — the
	# InkBridge holds this exact object and reads it through its Ink externals.
	_run_state.load_from(data.get("run_state", {}))
	_statuses = (data.get("statuses", {}) as Dictionary).duplicate(true)
	_step_cursor = (data.get("step_cursor", {}) as Dictionary).duplicate(true)
	var tracker_data: Dictionary = data.get("tracker", {})
	_tracker.deserialize(tracker_data, _definitions)
