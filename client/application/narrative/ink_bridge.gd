class_name InkBridge
extends Node
## The Ink <-> game bridge (ADR-017, deliverable D2) — **the only coupling** between
## the narrative layer and run state. It:
##   1. loads a compiled `.ink.json` through `InkFacade` (the addon stays in infra),
##   2. binds READ-ONLY game queries the story can call:
##        has_creature(id), corruption(), faction_standing(f), owns(id),
##        region_unlocked(id),
##   3. wires signal-based variable observers so Ink DECISIONS push out to
##      `QuestService` + world state,
##   4. round-trips the Ink story state into the versioned-JSON save.
##
## It NEVER computes gameplay outcomes. The external functions are queries (read run
## state); the observers translate story variables into quest triggers/advances. The
## oracle (`client/domain/`) is never touched from here.
##
## Convention for the variable -> quest wiring: an Ink variable named like
##   VAR quest_<questid>_start = false      -> start that quest when it flips true
##   VAR quest_<questid>_advance = ""       -> advance that quest to the named step
##   VAR quest_<questid>_complete = false   -> complete that quest when it flips true
## so designers drive quests purely from ink, with no GDScript per quest.

signal line_ready(text: String, tags: Array)
signal story_finished

const InkFacadeScript := preload("res://infrastructure/narrative/ink_facade.gd")

var _ink: RefCounted  # InkFacade (kept loosely typed so the addon type never leaks)
var _quests: QuestService
var _run_state: NarrativeRunState
var _observed_vars: Array = []


func _init(quest_service: QuestService = null) -> void:
	_quests = quest_service if quest_service != null else QuestService.new()
	_run_state = _quests.run_state()


## Loads + prepares a story: builds the InkFacade, binds queries, observes the quest
## driver variables. `quest_driver_vars` is the set of Ink VARs to watch (see header).
## Returns true if the story loaded. Must be `await`ed.
func load_story(ink_json_path: String, quest_driver_vars: Array = []) -> bool:
	_ink = InkFacadeScript.new()
	_ink.setup(self)
	_ink.story_continued.connect(_on_story_continued)
	_ink.story_ended.connect(_on_story_ended)
	var ok: bool = await _ink.load_story(ink_json_path)
	if not ok:
		return false
	_bind_queries()
	_observe_quest_drivers(quest_driver_vars)
	return true


func quest_service() -> QuestService:
	return _quests


## Restores Ink story state (from the versioned-JSON save) into the live player.
func restore_ink_state(state_json: String) -> void:
	if _ink != null:
		_ink.set_state_json(state_json)


## The Ink state String for the save (data-only; goes under the "ink" save section).
func ink_state_json() -> String:
	if _ink == null:
		return ""
	return _ink.get_state_json()


# --- story flow passthrough --- #


func can_continue() -> bool:
	return _ink != null and _ink.can_continue()


func continue_story() -> String:
	if _ink == null:
		return ""
	return _ink.continue_story()


func has_choices() -> bool:
	return _ink != null and _ink.has_choices()


func current_choices() -> Array:
	if _ink == null:
		return []
	return _ink.current_choices()


func choose(index: int) -> void:
	if _ink != null:
		_ink.choose(index)


# --- read-only external functions exposed to Ink stories --- #


func _bind_queries() -> void:
	_ink.bind_external_function("has_creature", self, "_ext_has_creature")
	_ink.bind_external_function("owns", self, "_ext_owns")
	_ink.bind_external_function("corruption", self, "_ext_corruption")
	_ink.bind_external_function("faction_standing", self, "_ext_faction_standing")
	_ink.bind_external_function("region_unlocked", self, "_ext_region_unlocked")


func _ext_has_creature(creature_id: String) -> bool:
	return _run_state.has_creature(creature_id)


func _ext_owns(creature_id: String) -> bool:
	return _run_state.owns(creature_id)


func _ext_corruption() -> int:
	return _run_state.corruption


func _ext_faction_standing(faction_id: String) -> int:
	return _run_state.standing_with(faction_id)


func _ext_region_unlocked(region_id: String) -> bool:
	return _run_state.region_unlocked(region_id)


# --- variable observers: Ink decisions -> QuestService / world state --- #


func _observe_quest_drivers(var_names: Array) -> void:
	for var_name in var_names:
		_observed_vars.append(str(var_name))
		_ink.observe_variable(str(var_name), self, "_on_quest_var_changed")


## Fired by inkgd whenever an observed VAR changes. We map the variable name to a
## quest action. This is the ONLY place story decisions become state changes.
func _on_quest_var_changed(variable_name: String, new_value: Variant) -> void:
	if variable_name.begins_with("quest_") and variable_name.ends_with("_start"):
		if _truthy(new_value):
			_quests.start(_quest_id_from_var(variable_name, "_start"))
	elif variable_name.begins_with("quest_") and variable_name.ends_with("_advance"):
		var step_id: String = str(new_value)
		if step_id != "":
			_quests.advance(_quest_id_from_var(variable_name, "_advance"), step_id)
	elif variable_name.begins_with("quest_") and variable_name.ends_with("_complete"):
		if _truthy(new_value):
			_quests.complete(_quest_id_from_var(variable_name, "_complete"))


func _quest_id_from_var(variable_name: String, suffix: String) -> String:
	return variable_name.trim_prefix("quest_").trim_suffix(suffix)


func _truthy(value: Variant) -> bool:
	if value is bool:
		return value
	if value is int or value is float:
		return value != 0
	if value is String:
		return value != "" and value != "false"
	return false


func _on_story_continued(text: String, tags: Array) -> void:
	line_ready.emit(text, tags)


func _on_story_ended() -> void:
	story_finished.emit()
