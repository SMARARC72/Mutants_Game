extends Control
## Options menu (D5) — the Maaack-style options shell, themed (D6) + wired to OUR Settings
## autoload (JSON, ADR-012) and G.U.I.D.E rebinding via InputService (D4).
##
## PRESENTATION layer. Audio/accessibility controls write straight to `Settings` (persisted as
## versioned JSON, never a Resource — ADR-012); the keybind row drives `InputService.rebind`,
## whose remaps also persist through `Settings`. This is the concrete proof that Maaack's
## settings backbone is wired to our Settings autoload + G.U.I.D.E (D5 acceptance), not to its
## own Resource-based config.

const InputActions := preload("res://infrastructure/input/input_actions.gd")
const MAIN_MENU_SCENE := "res://presentation/screens/main_menu.tscn"

var _settings: Node
var _input: Node
## W17 press-any-key rebinding: the action currently capturing ("" = idle) + its row button.
var _capture_action := ""
var _capture_button: Button = null


func _ready() -> void:
	var theme_service := get_node_or_null("/root/ThemeService")
	if theme_service != null:
		theme_service.call("apply_to", self)
	_settings = get_node_or_null("/root/Settings")
	_input = get_node_or_null("/root/InputService")
	if _input != null:
		_input.call("switch_context", InputActions.CTX_MENU)
	_build()


func _build() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 24)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)

	var title := Label.new()
	title.text = "Options"
	title.theme_type_variation = "TitleLabel"
	box.add_child(title)

	var first_row := _add_volume_row(box, "Master", "audio", "master_volume")
	_add_volume_row(box, "Music", "audio", "music_volume")
	_add_volume_row(box, "Effects", "audio", "sfx_volume")
	_add_toggle_row(box, "Fullscreen", "video", "fullscreen")
	_add_toggle_row(box, "Reduce motion", "accessibility", "reduce_motion")

	box.add_child(HSeparator.new())
	var rebind_title := Label.new()
	rebind_title.text = "Keybinds"
	rebind_title.theme_type_variation = "TitleLabel"
	rebind_title.add_theme_font_size_override("font_size", 20)
	box.add_child(rebind_title)
	_add_rebind_row(box, "Confirm", InputActions.CONFIRM)
	_add_rebind_row(box, "Interact", InputActions.INTERACT)

	box.add_child(HSeparator.new())
	var back := Button.new()
	back.text = "Back"
	box.add_child(back)
	back.pressed.connect(_on_back)
	# W1 focus pass: land on the FIRST setting (W0 focused Back) — up/down walks the sheet,
	# left/right adjusts the focused slider, Back stays reachable at the bottom of the chain.
	if first_row != null and first_row.is_inside_tree():
		first_row.grab_focus()


## ESC / cancel always exits Options — the screen must never trap the player. While a rebind row
## is CAPTURING, the very next press belongs to the capture instead (Esc there cancels the capture,
## never the screen — one press, one meaning).
func _unhandled_input(event: InputEvent) -> void:
	if _capture_action != "":
		if feed_capture_event(event):
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back()


func _on_back() -> void:
	var transition := get_node_or_null("/root/Transition")
	if transition != null:
		await transition.call("change_scene_ritual", MAIN_MENU_SCENE)
	else:
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)


## Build one volume row; returns its slider so the focus pass can land on the first row.
func _add_volume_row(
	parent: VBoxContainer, label_text: String, section: String, key: String
) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(140, 0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value = float(_setting_value(section, key, 1.0))
	row.add_child(slider)
	slider.value_changed.connect(
		func(v: float) -> void:
			if _settings != null:
				_settings.call("set_value", section, key, v)
				_settings.call("save_settings")
			# WAVE-SND: the sliders stopped lying — apply to the live AudioServer buses,
			# and let SFX-affecting rows audibly demonstrate the new level.
			var sfx := get_node_or_null("/root/SfxService")
			if sfx != null:
				sfx.call("apply_volumes")
				if key != "music_volume":
					sfx.call("play", "ui_click")
	)
	return slider


func _add_toggle_row(
	parent: VBoxContainer, label_text: String, section: String, key: String
) -> void:
	var check := CheckButton.new()
	check.text = label_text
	check.button_pressed = bool(_setting_value(section, key, false))
	parent.add_child(check)
	check.toggled.connect(
		func(on: bool) -> void:
			if _settings != null:
				_settings.call("set_value", section, key, on)
				_settings.call("save_settings")
	)


func _add_rebind_row(parent: VBoxContainer, label_text: String, action_id: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(140, 0)
	row.add_child(label)
	var button := Button.new()
	button.name = "RebindButton_" + action_id
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text = _binding_text(action_id)
	row.add_child(button)
	# W17: press-any-key capture — the click arms the row, the NEXT key/pad/mouse press becomes the
	# binding through InputService.rebind (persisted via Settings, ADR-012). Esc cancels the capture.
	button.pressed.connect(func() -> void: begin_rebind_capture(action_id, button))


# === press-any-key rebinding (W17 — replaces the F/G demo cycler) ============================= #


## Arm the capture for `action_id`: the next physical press binds it. Public for tests; `button`
## optional (the armed row shows the listening prompt).
func begin_rebind_capture(action_id: String, button: Button = null) -> void:
	# Re-arming another row first restores the previous row's label.
	if _capture_button != null and is_instance_valid(_capture_button) and _capture_action != "":
		_capture_button.text = _binding_text(_capture_action)
	_capture_action = action_id
	_capture_button = button
	if button != null:
		button.text = "Press a key… (Esc cancels)"


## The action currently capturing, or "" (for tests).
func capture_action() -> String:
	return _capture_action


## Feed one InputEvent into the armed capture. Returns true when the event was CONSUMED (bound or
## cancelled). Public so a headless test can drive the exact _unhandled_input path with a crafted
## event. Esc cancels; key / joypad button / mouse button presses bind through InputService.rebind.
func feed_capture_event(event: InputEvent) -> bool:
	if _capture_action == "" or event == null or event.is_echo():
		return false
	if event is InputEventKey and (event as InputEventKey).pressed:
		var key := event as InputEventKey
		if key.physical_keycode == KEY_ESCAPE or key.keycode == KEY_ESCAPE:
			_finish_capture()  # cancelled — binding untouched
			return true
		_apply_capture("key", int(key.physical_keycode))
		return true
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		_apply_capture("joy", int((event as InputEventJoypadButton).button_index))
		return true
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_apply_capture("mouse", int((event as InputEventMouseButton).button_index))
		return true
	return false


func _apply_capture(device: String, code: int) -> void:
	if _input != null:
		_input.call("rebind", _capture_action, device, code)
	_finish_capture()


func _finish_capture() -> void:
	if _capture_button != null and is_instance_valid(_capture_button):
		_capture_button.text = _binding_text(_capture_action)
	_capture_action = ""
	_capture_button = null


## The display text for an action's current binding (key name / pad button / mouse button).
func _binding_text(action_id: String) -> String:
	if _input == null:
		return "?"
	var binding: Dictionary = _input.call("binding_of", action_id)
	if not binding.has("code"):
		return "Unbound"
	match str(binding.get("device", "key")):
		"joy":
			return "Pad %d" % int(binding["code"])
		"mouse":
			return "Mouse %d" % int(binding["code"])
		_:
			return OS.get_keycode_string(int(binding["code"]))


## NOTE: deliberately NOT named `_get` — that would override Object's native virtual
## with an incompatible signature and break the script under Godot 4.
func _setting_value(section: String, key: String, fallback: Variant) -> Variant:
	if _settings != null:
		return _settings.call("get_value", section, key, fallback)
	return fallback
