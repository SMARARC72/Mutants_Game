class_name OverworldControlsChip
extends PanelContainer
## The always-on overworld CONTROLS CHIP (Wave 1 / red-team C13): a small bottom-left HUD chip
## naming the LIVE verbs — "Arrows/WASD move · E interact · Shift dash · Tab camp · H hide" — so
## the first five minutes never hide the controls. Collapsible with the toggle-controls action;
## collapsed it shrinks to a one-verb reminder ("H controls") instead of vanishing, so it can
## always be found again. Key names derive from InputService.binding_of, so a rebind never makes
## the chip lie. Extracted from overworld_screen (line-cap rule, the OverworldCameraRig pattern).

const InputActions := preload("res://infrastructure/input/input_actions.gd")

var _label: Label = null
var _collapsed := false
var _input: Node = null


func _init(input: Node = null) -> void:
	_input = input
	name = "ControlsChip"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(GrimoirePalette.INK_PANEL, 0.85)
	style.border_color = GrimoirePalette.BRASS
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	add_theme_stylebox_override("panel", style)
	_label = Label.new()
	_label.name = "ControlsLabel"
	_label.theme_type_variation = "MutedLabel"
	_label.add_theme_font_size_override("font_size", 13)
	add_child(_label)
	refresh_text()


func _ready() -> void:
	# Bottom-left corner of the HUD layer, growing upward from a 14px margin.
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 14)


## Collapse/expand the chip (the H toggle). The screen's _process drives this via the
## TOGGLE_CONTROLS action so the chip itself never reads raw input.
func toggle() -> void:
	_collapsed = not _collapsed
	refresh_text()


func is_collapsed() -> bool:
	return _collapsed


## The current chip line (exposed for tests).
func chip_text() -> String:
	return _label.text if _label != null else ""


## Rebuild the verb line from the LIVE bindings (rebind-safe). Collapsed shows only the way back.
func refresh_text() -> void:
	if _label == null:
		return
	if _collapsed:
		_label.text = "%s controls" % _key_of(InputActions.TOGGLE_CONTROLS, "H")
		return
	_label.text = (
		"Arrows/WASD move · %s interact · %s dash · %s camp · %s hide"
		% [
			_key_of(InputActions.INTERACT, "E"),
			_key_of(InputActions.SIGIL_DASH, "Shift"),
			_key_of(InputActions.OPEN_MENU, "Tab"),
			_key_of(InputActions.TOGGLE_CONTROLS, "H"),
		]
	)


## The display name of the key bound to `action_id`, via the InputService facade; `fallback`
## covers headless/no-autoload runs and non-key bindings.
func _key_of(action_id: String, fallback: String) -> String:
	if _input == null or not _input.has_method("binding_of"):
		return fallback
	var binding: Dictionary = _input.call("binding_of", action_id)
	if str(binding.get("device", "")) == "key" and binding.has("code"):
		return OS.get_keycode_string(int(binding["code"]))
	return fallback
