extends GdUnitTestSuite
## Wave 1 "input truth" — the just_pressed EDGE contract: a held key fires exactly ONCE.
##
## InputService has two paths. The Godot-InputMap fallback is the one ACTIVE at runtime (G.U.I.D.E
## ships as a plain autoload node, not an engine singleton, so _guide_ready is false); it rides
## Input.is_action_just_pressed, already a true one-frame edge. The GUIDE path stamps each
## action's one-shot just_triggered signal into a per-action frame dict. Both are pinned here,
## plus the W1 gamepad fallback bindings (D-pad + left stick + face buttons).

const InputActions := preload("res://infrastructure/input/input_actions.gd")
const InputServiceScript := preload("res://infrastructure/input/input_service.gd")
const GUIDEActionScript := preload("res://addons/guide/guide_action.gd")


func _make_service() -> Node:
	var svc: Node = auto_free(InputServiceScript.new())
	add_child(svc)
	return svc


# === fallback path (the runtime path) ==========================================================


func test_fallback_just_pressed_fires_exactly_once_while_held() -> void:
	var svc := _make_service()
	# Headless there is no GUIDE engine singleton — the fallback MUST be the live path.
	assert_bool(bool(svc.get("_guide_ready"))).is_false()
	var fires := 0
	Input.action_press(InputActions.CONFIRM)
	for _i in 2:  # two process frames with the key held (the audit's hold-E / hold-Enter case)
		if bool(svc.call("just_pressed", InputActions.CONFIRM)):
			fires += 1
		await get_tree().process_frame
	assert_bool(bool(svc.call("is_pressed", InputActions.CONFIRM))).is_true()
	Input.action_release(InputActions.CONFIRM)
	assert_int(fires).is_equal(1)


func test_fallback_release_then_repress_fires_again() -> void:
	var svc := _make_service()
	Input.action_press(InputActions.INTERACT)
	assert_bool(bool(svc.call("just_pressed", InputActions.INTERACT))).is_true()
	Input.action_release(InputActions.INTERACT)
	await get_tree().process_frame
	assert_bool(bool(svc.call("just_pressed", InputActions.INTERACT))).is_false()
	Input.action_press(InputActions.INTERACT)
	assert_bool(bool(svc.call("just_pressed", InputActions.INTERACT))).is_true()
	Input.action_release(InputActions.INTERACT)


# === GUIDE frame-stamp path =====================================================================


func test_guide_stamp_path_fires_exactly_once_while_held() -> void:
	var svc := _make_service()
	# Simulate the GUIDE path headless: register a real GUIDEAction, subscribe its edge, force
	# the branch on, then drive the addon's own state transitions. GUIDEAction emits
	# just_triggered ONLY on the COMPLETED→TRIGGERED transition, so a held input stamps once.
	var action: Resource = GUIDEActionScript.new()
	var actions: Dictionary = svc.get("_actions")
	actions[InputActions.CONFIRM] = action
	svc.call("_subscribe_edge", InputActions.CONFIRM, action)
	svc.set("_guide_ready", true)

	action.call("_triggered", Vector3(1, 0, 0), 0.0)  # the press frame
	assert_bool(bool(svc.call("just_pressed", InputActions.CONFIRM))).is_true()
	await get_tree().process_frame
	action.call("_triggered", Vector3(1, 0, 0), 0.016)  # still held next frame — no re-fire
	assert_bool(bool(svc.call("just_pressed", InputActions.CONFIRM))).is_false()
	assert_bool(bool(svc.call("is_pressed", InputActions.CONFIRM))).is_true()
	# Release + a fresh press stamps a fresh edge.
	action.call("_completed", Vector3.ZERO)
	action.call("_triggered", Vector3(1, 0, 0), 0.0)
	assert_bool(bool(svc.call("just_pressed", InputActions.CONFIRM))).is_true()


# === gamepad fallback bindings (W1) =============================================================


func test_fallback_gamepad_bindings_registered() -> void:
	_make_service()  # (re)builds the fallback InputMap idempotently
	assert_bool(_has_joy_button(InputActions.CONFIRM, JOY_BUTTON_A)).is_true()
	assert_bool(_has_joy_button(InputActions.INTERACT, JOY_BUTTON_A)).is_true()
	assert_bool(_has_joy_button(InputActions.CANCEL, JOY_BUTTON_B)).is_true()
	assert_bool(_has_joy_button(InputActions.PAUSE, JOY_BUTTON_START)).is_true()
	assert_bool(_has_joy_button(InputActions.OPEN_MENU, JOY_BUTTON_START)).is_true()
	assert_bool(_has_joy_button(InputActions.SIGIL_DASH, JOY_BUTTON_X)).is_true()
	# Left stick: axes 0/1 drive MOVE_*/NAV_* with a 0.5 deadzone (alongside the D-pad).
	assert_bool(_has_joy_axis(InputActions.MOVE_LEFT, JOY_AXIS_LEFT_X, -1.0)).is_true()
	assert_bool(_has_joy_axis(InputActions.MOVE_RIGHT, JOY_AXIS_LEFT_X, 1.0)).is_true()
	assert_bool(_has_joy_axis(InputActions.MOVE_UP, JOY_AXIS_LEFT_Y, -1.0)).is_true()
	assert_bool(_has_joy_axis(InputActions.MOVE_DOWN, JOY_AXIS_LEFT_Y, 1.0)).is_true()
	assert_bool(_has_joy_axis(InputActions.NAV_UP, JOY_AXIS_LEFT_Y, -1.0)).is_true()
	assert_bool(_has_joy_button(InputActions.NAV_UP, JOY_BUTTON_DPAD_UP)).is_true()
	assert_float(InputMap.action_get_deadzone(InputActions.MOVE_LEFT)).is_equal(0.5)


func test_fallback_rebuild_does_not_duplicate_events() -> void:
	_make_service()
	var before := InputMap.action_get_events(InputActions.CONFIRM).size()
	_make_service()  # a second instance rebuilds the SAME global InputMap
	var after := InputMap.action_get_events(InputActions.CONFIRM).size()
	assert_int(after).is_equal(before)


func _has_joy_button(action: String, button: int) -> bool:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton and (ev as InputEventJoypadButton).button_index == button:
			return true
	return false


func _has_joy_axis(action: String, axis: int, value: float) -> bool:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadMotion:
			var motion := ev as InputEventJoypadMotion
			if motion.axis == axis and is_equal_approx(motion.axis_value, value):
				return true
	return false
