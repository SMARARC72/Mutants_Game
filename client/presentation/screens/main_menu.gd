extends Control
## Main menu (D5) — the Maaack-style menu shell, themed (D6) + driving our facades.
##
## PRESENTATION layer. Proves the menu/settings/loading flow: Play runs the ritual transition
## with a THREADED load to the sample screen (D8 "loading transition"), Options pushes the
## themed options menu wired to Settings + rebinding (D5), Quit leaves. Talks only to the facades
## (Transition / InputService / ThemeService), never an addon directly.

const InputActions := preload("res://infrastructure/input/input_actions.gd")
const SAMPLE_SCENE := "res://presentation/screens/sample_grimoire_screen.tscn"
const OPTIONS_SCENE := "res://presentation/screens/options_menu.tscn"

var _transition: Node


func _ready() -> void:
	var theme_service := get_node_or_null("/root/ThemeService")
	if theme_service != null:
		theme_service.call("apply_to", self)
	var input := get_node_or_null("/root/InputService")
	if input != null:
		input.call("switch_context", InputActions.CTX_MENU)
	_transition = get_node_or_null("/root/Transition")
	_build()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.075, 0.11)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.custom_minimum_size = Vector2(360, 0)
	center.add_child(box)

	var title := Label.new()
	title.text = "MUTANTS"
	title.theme_type_variation = "TitleLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var tagline := Label.new()
	tagline.text = "Catch. Splice. Ascend. Regret."
	tagline.theme_type_variation = "MutedLabel"
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tagline)

	_add_button(box, "Begin the Descent", _on_play)
	_add_button(box, "Options", _on_options)
	_add_button(box, "Abandon Hope (Quit)", _on_quit)


func _add_button(parent: VBoxContainer, text: String, handler: Callable) -> void:
	var button := Button.new()
	button.text = text
	parent.add_child(button)
	button.pressed.connect(handler)


func _on_play() -> void:
	# D8: ritual transition + threaded-load cover instead of a flat loading screen.
	if _transition != null:
		await _transition.call("change_scene_ritual", SAMPLE_SCENE)
	else:
		get_tree().change_scene_to_file(SAMPLE_SCENE)


func _on_options() -> void:
	if _transition != null:
		await _transition.call("change_scene_ritual", OPTIONS_SCENE)
	else:
		get_tree().change_scene_to_file(OPTIONS_SCENE)


func _on_quit() -> void:
	get_tree().quit()
