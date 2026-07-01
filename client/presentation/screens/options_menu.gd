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

	_add_volume_row(box, "Master", "audio", "master_volume")
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
	back.grab_focus()


## ESC / cancel always exits Options — the screen must never trap the player.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back()


func _on_back() -> void:
	var transition := get_node_or_null("/root/Transition")
	if transition != null:
		await transition.call("change_scene_ritual", MAIN_MENU_SCENE)
	else:
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _add_volume_row(
	parent: VBoxContainer, label_text: String, section: String, key: String
) -> void:
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
	)


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
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text = _binding_text(action_id)
	row.add_child(button)
	# Cycle through a couple of demo keys to prove rebinding flows to InputService + Settings.
	# A full build opens an input-capture dialog; the data path is identical.
	button.pressed.connect(
		func() -> void:
			if _input != null:
				var next_key := KEY_F if _binding_text(action_id) != "F" else KEY_G
				_input.call("rebind", action_id, "key", next_key)
				button.text = _binding_text(action_id)
	)


func _binding_text(action_id: String) -> String:
	if _input == null:
		return "?"
	var binding: Dictionary = _input.call("binding_of", action_id)
	if binding.has("code"):
		return OS.get_keycode_string(int(binding["code"]))
	return "Unbound"


## NOTE: deliberately NOT named `_get` — that would override Object's native virtual
## with an incompatible signature and break the script under Godot 4.
func _setting_value(section: String, key: String, fallback: Variant) -> Variant:
	if _settings != null:
		return _settings.call("get_value", section, key, fallback)
	return fallback
