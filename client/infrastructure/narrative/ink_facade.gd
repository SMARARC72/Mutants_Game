class_name InkFacade
extends RefCounted
## Thin facade over the vendored **inkgd** addon (ADR-017, P3). This is the ONLY
## place that touches `InkPlayer`/`InkResource` types — no inkgd type ever crosses
## a layer boundary. Everything above us (the Ink<->game bridge, QuestService) sees
## plain Strings / Arrays / Dictionaries.
##
## Responsibilities: load a compiled `.ink.json` (imported as an InkResource),
## drive `continue_story()` / choices, expose `bind_external_function` and
## `observe_variable`, and round-trip the story state String for the JSON save.
## It computes NO gameplay outcomes — Ink only DECIDES branches; the oracle resolves
## numbers elsewhere.
##
## inkgd's `InkPlayer` is a Node, so the facade owns one and parents it under a host
## node supplied by the caller (the bridge), keeping the addon node inside this layer.

signal story_continued(text: String, tags: Array)
signal story_ended
signal load_failed(message: String)

const InkPlayerScene := preload("res://addons/inkgd/ink_player.gd")

var _player: Node = null
var _loaded: bool = false


## Builds the InkPlayer and parents it under `host` (a live Node in the tree, so the
## player can spin its background-load thread / timers). Synchronous story creation
## is forced (`loads_in_background = false`) so headless flows are deterministic.
func setup(host: Node) -> void:
	_player = InkPlayerScene.new()
	_player.loads_in_background = false
	host.add_child(_player)
	_player.continued.connect(_on_continued)
	_player.ended.connect(_on_ended)
	_player.loaded.connect(_on_loaded)


## Loads a compiled ink story. `ink_json_path` points at the imported `.ink.json`
## (an InkResource). Returns true once the story is created. Must be `await`ed
## because inkgd creates the story deferred and reports via the `loaded` signal.
func load_story(ink_json_path: String) -> bool:
	if _player == null:
		push_error("InkFacade.load_story called before setup().")
		return false
	var resource: Resource = load(ink_json_path)
	if resource == null:
		load_failed.emit("Could not load InkResource at %s" % ink_json_path)
		return false
	_player.ink_file = resource
	_loaded = false
	var result: int = _player.create_story()
	if result != OK:
		load_failed.emit("InkPlayer.create_story failed (code %d)." % result)
		return false
	# create_story finalizes via call_deferred + emits `loaded`; wait for it.
	var ok: bool = await _player.loaded
	_loaded = ok
	if not ok:
		load_failed.emit("Ink story failed to load.")
	return ok


func is_loaded() -> bool:
	return _loaded


func can_continue() -> bool:
	return _player != null and _player.get_can_continue()


## Advances the story one line, returning the line text (tags arrive via the signal).
func continue_story() -> String:
	if not can_continue():
		return ""
	return _player.continue_story()


## Continues until a choice point or the end; returns the accumulated text.
func continue_maximally() -> String:
	if _player == null:
		return ""
	return _player.continue_story_maximally()


func has_choices() -> bool:
	return _player != null and _player.get_has_choices()


## Returns the current choice texts as plain Strings (no InkChoice types leak out).
func current_choices() -> Array:
	var out: Array = []
	if _player == null:
		return out
	for choice in _player.get_current_choices():
		# inkgd choices expose `.text`; fall back to a String cast defensively.
		if choice != null and "text" in choice:
			out.append(str(choice.text))
		else:
			out.append(str(choice))
	return out


func choose(index: int) -> void:
	if _player != null:
		_player.choose_choice_index(index)


## Binds a read-only game query so Ink can call `EXTERNAL name(...)`. The bound
## method must NOT mutate gameplay state — these are queries the story reads to
## decide branches (has_creature/corruption/owns/region_unlocked/faction_standing).
func bind_external_function(func_name: String, target: Object, method_name: String) -> void:
	if _player != null:
		_player.bind_external_function(func_name, target, method_name, true)


## Observes an Ink variable; `target.method(var_name, new_value)` fires on change.
## This is how story DECISIONS push out to QuestService / world state.
func observe_variable(variable_name: String, target: Object, method_name: String) -> void:
	if _player != null:
		_player.observe_variable(variable_name, target, method_name)


func get_variable(variable_name: String) -> Variant:
	if _player == null:
		return null
	return _player.get_variable(variable_name)


# --- persistence: the Ink state is a String we drop into the JSON save --- #


func get_state_json() -> String:
	if _player == null:
		return ""
	return _player.get_state()


func set_state_json(state: String) -> void:
	if _player != null and state != "":
		_player.set_state(state)


func _on_continued(text: String, tags: Array) -> void:
	story_continued.emit(text, tags)


func _on_ended() -> void:
	story_ended.emit()


func _on_loaded(_successfully: bool) -> void:
	pass
