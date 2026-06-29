extends Node
## InputService facade autoload (D4) — the ONLY thing that touches G.U.I.D.E.
##
## INFRASTRUCTURE/input layer. The app asks for ACTIONS (`InputService.is_pressed("confirm")`),
## never raw keys (D4 acceptance). Owns the four input contexts (Menu / Overworld / Battle /
## Lab), runtime rebinding, and KB+mouse+gamepad. G.U.I.D.E types never cross this boundary —
## callers see only the string action ids in `InputActions`.
##
## REBINDING PERSISTENCE (D4/D5, ADR-012): rebinds are serialised to a plain JSON dict
## (action -> {device, code}) and stored in the `Settings` autoload, NOT as a GUIDERemappingConfig
## Resource — so they survive a restart without deserialising a Godot Resource (ADR-012).
##
## When G.U.I.D.E is unavailable (e.g. a stripped build), this falls back to Godot's own
## `InputMap`, so action queries still work and the project never errors.

const InputActions := preload("res://infrastructure/input/input_actions.gd")

const DEVICE_KEY := "key"
const DEVICE_MOUSE := "mouse"
const DEVICE_JOY := "joy"

var _contexts := {}  # context id -> GUIDEMappingContext
var _actions := {}  # action id -> GUIDEAction
var _current_context := ""
var _guide_ready := false
## action id -> {device, code} override (JSON-serialisable; mirrored into Settings).
var _remaps := {}


func _ready() -> void:
	_guide_ready = _has_guide()
	_load_remaps_from_settings()
	if _guide_ready:
		_build_guide()
	else:
		_build_godot_fallback()
	switch_context(InputActions.CTX_MENU)


# === public action API (what the app calls) =========================================
## True while the action is held / active this frame.
func is_pressed(action_id: String) -> bool:
	if _guide_ready and _actions.has(action_id):
		return (_actions[action_id] as Object).is_triggered()
	return InputMap.has_action(action_id) and Input.is_action_pressed(action_id)


## True only on the frame the action began (edge).
func just_pressed(action_id: String) -> bool:
	if _guide_ready and _actions.has(action_id):
		var act: Object = _actions[action_id]
		return act.is_triggered() and act.is_ongoing() == false
	return InputMap.has_action(action_id) and Input.is_action_just_pressed(action_id)


## A 2D movement vector from the four directional actions of the active context. In the OVERWORLD,
## WASD (MOVE_*) is primary but the ARROW keys (NAV_*) drive movement too — players reach for the
## arrows by instinct, and an avatar that ignored them read as "the game is frozen". Either set steps
## the avatar; WASD wins when both are held the same frame.
func movement_vector() -> Vector2:
	if _current_context == InputActions.CTX_OVERWORLD:
		var move := Vector2(
			_axis(InputActions.MOVE_LEFT, InputActions.MOVE_RIGHT),
			_axis(InputActions.MOVE_UP, InputActions.MOVE_DOWN)
		)
		if move != Vector2.ZERO:
			return move
		return Vector2(
			_axis(InputActions.NAV_LEFT, InputActions.NAV_RIGHT),
			_axis(InputActions.NAV_UP, InputActions.NAV_DOWN)
		)
	return Vector2(
		_axis(InputActions.NAV_LEFT, InputActions.NAV_RIGHT),
		_axis(InputActions.NAV_UP, InputActions.NAV_DOWN)
	)


func _axis(neg: String, pos: String) -> float:
	return (1.0 if is_pressed(pos) else 0.0) - (1.0 if is_pressed(neg) else 0.0)


# === context switching (on screen transitions) =====================================
func switch_context(context_id: String) -> void:
	if not InputActions.context_actions().has(context_id):
		push_warning("InputService.switch_context: unknown context '%s'" % context_id)
		return
	_current_context = context_id
	if _guide_ready and _contexts.has(context_id):
		var guide: Object = Engine.get_singleton("GUIDE")
		if guide != null and guide.has_method("enable_mapping_context"):
			guide.call("enable_mapping_context", _contexts[context_id], true)


func current_context() -> String:
	return _current_context


# === rebinding (D4) =================================================================
## Rebind an action to a new physical input. `device` in {key, mouse, joy}; `code` is the
## Key/MouseButton/JoyButton enum value. Persists via Settings (ADR-012 JSON).
func rebind(action_id: String, device: String, code: int) -> void:
	_remaps[action_id] = {"device": device, "code": code}
	_apply_remap(action_id)
	_save_remaps_to_settings()


## Clear a custom binding, reverting to default. Persists.
func clear_rebind(action_id: String) -> void:
	_remaps.erase(action_id)
	if _guide_ready:
		_rebuild_action_mappings(action_id)
	_save_remaps_to_settings()


## The currently-bound input for an action, as a display dict {device, code}.
func binding_of(action_id: String) -> Dictionary:
	if _remaps.has(action_id):
		return (_remaps[action_id] as Dictionary).duplicate()
	var keys: Dictionary = InputActions.default_keys()
	if keys.has(action_id):
		return {"device": DEVICE_KEY, "code": keys[action_id]}
	return {}


# === G.U.I.D.E construction (the only place addon types appear) =====================
func _has_guide() -> bool:
	return ClassDB.class_exists("GUIDEAction") and Engine.has_singleton("GUIDE")


func _build_guide() -> void:
	for action_id: String in _all_action_ids():
		var action: Object = ClassDB.instantiate("GUIDEAction")
		action.set("name", StringName(action_id))
		action.set("display_name", _humanise(action_id))
		action.set("is_remappable", true)
		_actions[action_id] = action

	for ctx_id: String in InputActions.context_actions().keys():
		var context: Object = ClassDB.instantiate("GUIDEMappingContext")
		context.set("display_name", ctx_id)
		var mappings: Array = []
		for action_id: String in InputActions.context_actions()[ctx_id]:
			mappings.append(_make_action_mapping(action_id))
		context.set("mappings", mappings)
		_contexts[ctx_id] = context


func _make_action_mapping(action_id: String) -> Object:
	var action_mapping: Object = ClassDB.instantiate("GUIDEActionMapping")
	action_mapping.set("action", _actions[action_id])
	action_mapping.set("input_mappings", _inputs_for(action_id))
	return action_mapping


## Build the GUIDE input mappings for an action: a custom remap if present, else the default
## keyboard binding + the default gamepad binding.
func _inputs_for(action_id: String) -> Array:
	var result: Array = []
	if _remaps.has(action_id):
		var input := _make_input(_remaps[action_id]["device"], _remaps[action_id]["code"])
		if input != null:
			result.append(_wrap_input(input))
		return result
	var keys: Dictionary = InputActions.default_keys()
	if keys.has(action_id):
		var key_input := _make_input(DEVICE_KEY, keys[action_id])
		if key_input != null:
			result.append(_wrap_input(key_input))
	var pads: Dictionary = InputActions.default_gamepad()
	if pads.has(action_id) and pads[action_id] != -1:
		var pad_input := _make_input(DEVICE_JOY, pads[action_id])
		if pad_input != null:
			result.append(_wrap_input(pad_input))
	return result


func _wrap_input(input: Object) -> Object:
	var input_mapping: Object = ClassDB.instantiate("GUIDEInputMapping")
	input_mapping.set("input", input)
	input_mapping.set("is_remappable", true)
	return input_mapping


func _make_input(device: String, code: int) -> Object:
	match device:
		DEVICE_KEY:
			var k: Object = ClassDB.instantiate("GUIDEInputKey")
			k.set("key", code)
			return k
		DEVICE_JOY:
			var j: Object = ClassDB.instantiate("GUIDEInputJoyButton")
			j.set("button", code)
			return j
		DEVICE_MOUSE:
			var m: Object = ClassDB.instantiate("GUIDEInputMouseButton")
			if m != null:
				m.set("button", code)
			return m
		_:
			return null


func _apply_remap(action_id: String) -> void:
	if _guide_ready:
		_rebuild_action_mappings(action_id)


## Rebuild the input mappings for one action's mapping in every context that holds it.
func _rebuild_action_mappings(action_id: String) -> void:
	for ctx_id: String in _contexts.keys():
		var context: Object = _contexts[ctx_id]
		var mappings: Array = context.get("mappings")
		for action_mapping: Object in mappings:
			if action_mapping.get("action") == _actions.get(action_id):
				action_mapping.set("input_mappings", _inputs_for(action_id))
	# Re-enable the active context so G.U.I.D.E re-parses the new mappings.
	if _current_context != "":
		switch_context(_current_context)


# === Godot InputMap fallback (no G.U.I.D.E) ========================================
func _build_godot_fallback() -> void:
	var keys: Dictionary = InputActions.default_keys()
	var pads: Dictionary = InputActions.default_gamepad()
	for action_id: String in _all_action_ids():
		if not InputMap.has_action(action_id):
			InputMap.add_action(action_id)
		var binding: Dictionary = binding_of(action_id)
		if binding.has("device") and binding["device"] == DEVICE_KEY:
			var ev := InputEventKey.new()
			ev.physical_keycode = binding["code"]
			InputMap.action_add_event(action_id, ev)
		elif keys.has(action_id):
			var kev := InputEventKey.new()
			kev.physical_keycode = keys[action_id]
			InputMap.action_add_event(action_id, kev)
		if pads.has(action_id) and pads[action_id] != -1:
			var jev := InputEventJoypadButton.new()
			jev.button_index = pads[action_id]
			InputMap.action_add_event(action_id, jev)


# === persistence (ADR-012 JSON via Settings) =======================================
func _save_remaps_to_settings() -> void:
	var settings := get_node_or_null("/root/Settings")
	if settings != null and settings.has_method("set_input_remaps"):
		settings.call("set_input_remaps", _remaps)
		settings.call("save_settings")


func _load_remaps_from_settings() -> void:
	var settings := get_node_or_null("/root/Settings")
	if settings != null and settings.has_method("get_input_remaps"):
		var stored: Variant = settings.call("get_input_remaps")
		if typeof(stored) == TYPE_DICTIONARY:
			_remaps = stored


# === helpers =======================================================================
func _all_action_ids() -> Array:
	var ids := {}
	for ctx_id: String in InputActions.context_actions().keys():
		for action_id: String in InputActions.context_actions()[ctx_id]:
			ids[action_id] = true
	return ids.keys()


func _humanise(action_id: String) -> String:
	return action_id.replace("_", " ").capitalize()
