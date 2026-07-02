extends GdUnitTestSuite
## Wave 17 — press-any-key REBIND capture in the options menu (replacing the F/G demo cycler),
## driven HEADLESSLY through the exact _unhandled_input path (crafted InputEvents):
##   * arming a row + feeding a key press binds it through InputService.rebind (ADR-012 plumbing);
##   * a joypad button binds with device "joy";
##   * Esc CANCELS the capture and leaves the binding untouched.
## Every rebind is cleared afterwards so the shared InputService/Settings state never leaks.

const OptionsMenuScript := preload("res://presentation/screens/options_menu.gd")
const InputActions := preload("res://infrastructure/input/input_actions.gd")


func _input_service() -> Node:
	return get_node_or_null("/root/InputService")


func _make_menu() -> Control:
	var menu: Control = OptionsMenuScript.new()
	add_child(menu)  # _ready builds the sheet from the live autoloads
	return menu


func _key_event(keycode: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.physical_keycode = keycode
	ev.keycode = keycode
	return ev


func test_key_capture_rebinds_through_input_service() -> void:
	var input := _input_service()
	assert_object(input).is_not_null()
	var menu := _make_menu()
	menu.call("begin_rebind_capture", InputActions.INTERACT)
	assert_str(str(menu.call("capture_action"))).is_equal(InputActions.INTERACT)

	var consumed: bool = menu.call("feed_capture_event", _key_event(KEY_J))
	assert_bool(consumed).is_true()
	assert_str(str(menu.call("capture_action"))).is_equal("")  # capture finished
	var binding: Dictionary = input.call("binding_of", InputActions.INTERACT)
	assert_str(str(binding.get("device", ""))).is_equal("key")
	assert_int(int(binding.get("code", 0))).is_equal(KEY_J)

	input.call("clear_rebind", InputActions.INTERACT)
	menu.queue_free()


func test_joypad_capture_binds_the_pad_button() -> void:
	var input := _input_service()
	var menu := _make_menu()
	menu.call("begin_rebind_capture", InputActions.CONFIRM)
	var ev := InputEventJoypadButton.new()
	ev.pressed = true
	ev.button_index = JOY_BUTTON_Y
	assert_bool(bool(menu.call("feed_capture_event", ev))).is_true()
	var binding: Dictionary = input.call("binding_of", InputActions.CONFIRM)
	assert_str(str(binding.get("device", ""))).is_equal("joy")
	assert_int(int(binding.get("code", -1))).is_equal(JOY_BUTTON_Y)

	input.call("clear_rebind", InputActions.CONFIRM)
	menu.queue_free()


func test_escape_cancels_the_capture_without_binding() -> void:
	var input := _input_service()
	var before: Dictionary = input.call("binding_of", InputActions.INTERACT)
	var menu := _make_menu()
	menu.call("begin_rebind_capture", InputActions.INTERACT)
	assert_bool(bool(menu.call("feed_capture_event", _key_event(KEY_ESCAPE)))).is_true()
	assert_str(str(menu.call("capture_action"))).is_equal("")
	var after: Dictionary = input.call("binding_of", InputActions.INTERACT)
	assert_str(str(after.get("device", ""))).is_equal(str(before.get("device", "")))
	assert_int(int(after.get("code", -1))).is_equal(int(before.get("code", -1)))
	menu.queue_free()


func test_idle_menu_ignores_fed_events() -> void:
	var menu := _make_menu()
	assert_bool(bool(menu.call("feed_capture_event", _key_event(KEY_J)))).is_false()
	menu.queue_free()
