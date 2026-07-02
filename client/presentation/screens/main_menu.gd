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
const OVERWORLD_SCENE := "res://presentation/overworld/overworld_screen.tscn"
const SIGIL := "✵"  # 8-pointed grimoire sigil (matches the ritual Transition)
const BRASS_BRIGHT := Color(0.878431, 0.72549, 0.352941)

var _transition: Node
var _game: Node


func _ready() -> void:
	var theme_service := get_node_or_null("/root/ThemeService")
	if theme_service != null:
		theme_service.call("apply_to", self)
	var input := get_node_or_null("/root/InputService")
	if input != null:
		input.call("switch_context", InputActions.CTX_MENU)
	_transition = get_node_or_null("/root/Transition")
	_game = get_node_or_null("/root/GameController")
	_build()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.075, 0.11)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Atmosphere: drifting motes + a radial vignette, so the menu feels like an open grimoire.
	# Geometry derives from the live viewport so the 1920x1080 baseline (and any window
	# size) fills edge to edge instead of assuming the old 1152x648 default.
	var vp := get_viewport_rect().size
	var motes := CPUParticles2D.new()
	motes.position = Vector2(vp.x * 0.5, vp.y * 0.97)
	motes.amount = 30
	motes.lifetime = 8.0
	motes.preprocess = 6.0
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(vp.x * 0.62, 60)
	motes.gravity = Vector2(0, -7)
	motes.initial_velocity_min = 3.0
	motes.initial_velocity_max = 12.0
	motes.scale_amount_min = 1.0
	motes.scale_amount_max = 2.6
	motes.color = Color(0.88, 0.78, 0.42, 0.45)
	add_child(motes)
	var vig := TextureRect.new()
	vig.texture = _make_vignette(256)
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vig)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.custom_minimum_size = Vector2(360, 0)
	center.add_child(box)

	var crest := Label.new()
	crest.text = SIGIL
	crest.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crest.add_theme_font_size_override("font_size", 64)
	crest.add_theme_color_override("font_color", BRASS_BRIGHT)
	box.add_child(crest)

	var title := Label.new()
	title.text = "MUTANTS"
	title.theme_type_variation = "TitleLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var tagline := Label.new()
	tagline.text = "Catch. Splice. Ascend. Regret."
	# W16b fourth-wall crack #3 (rationed): on ~1 run in 8 (seeded by the run-seed hash, so the
	# same run always reads the same menu) the subtitle flickers to the authored watched line.
	var flicker := FourthWall.menu_tagline(_game)
	if flicker != "":
		tagline.text = flicker
	tagline.theme_type_variation = "MutedLabel"
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tagline)

	var first := _add_button(box, "Begin the Descent (New Run)", _on_new_run)
	var continue_button := _add_button(box, "Continue", _on_continue)
	continue_button.name = "ContinueButton"
	# W18 continue gate: no save at all -> Continue stays disabled; an ILLEGIBLE save (bad JSON /
	# checksum / empty run) keeps the button LIVE and answers with an in-world dialog instead of a
	# dead click (the player learns WHY, not just that nothing happens).
	if _continue_health() == "none":
		continue_button.disabled = true
	_add_button(box, "Sample Plate", _on_play)
	_add_button(box, "Options", _on_options)
	_add_button(box, "Abandon Hope (Quit)", _on_quit)
	# W1 focus pass: the first verb owns focus so keyboard/gamepad play works from frame one
	# (container order gives the column its focus neighbours automatically).
	if first.is_inside_tree():
		first.grab_focus()


func _add_button(parent: VBoxContainer, text: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = text
	parent.add_child(button)
	button.pressed.connect(handler)
	return button


## A radial vignette texture (transparent centre → soft dark corners) for menu atmosphere.
func _make_vignette(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) * 0.5
	var maxd := Vector2(c, c).length()
	for y in size:
		for x in size:
			var t := clampf((Vector2(x - c, y - c).length() / maxd - 0.5) / 0.5, 0.0, 1.0)
			img.set_pixel(x, y, Color(0.02, 0.015, 0.03, t * t * 0.7))
	return ImageTexture.create_from_image(img)


## New Run: seed a fresh run via GameController, then ritual-swap to the overworld.
func _on_new_run() -> void:
	if _game != null and _game.has_method("new_run"):
		_game.call("new_run", _fresh_seed())
	_go_to_overworld()


## Continue: load the latest local save via GameController, then swap to the overworld. A failed
## load (illegible envelope) answers with the in-world dialog instead of silently doing nothing.
func _on_continue() -> void:
	if _game == null or not _game.has_method("continue_run"):
		return
	if bool(_game.call("continue_run")):
		_go_to_overworld()
		return
	_show_illegible_dialog()


## The GameController's save health ("none" / "ok" / "illegible"), guarded for stub games.
func _continue_health() -> String:
	if _game == null:
		return "none"
	if _game.has_method("continue_health"):
		return str(_game.call("continue_health"))
	if _game.has_method("has_save") and bool(_game.call("has_save")):
		return "ok"
	return "none"


## W18: the corrupt-save dialog — a legible in-world error, never a dead button.
func _show_illegible_dialog() -> void:
	var dialog := AcceptDialog.new()
	dialog.name = "IllegibleLedgerDialog"
	dialog.title = "The Ledger"
	dialog.dialog_text = (
		"The ledger is illegible.\n"
		+ "Its ink has run — the last record cannot be trusted.\n"
		+ "Begin the descent anew; the marsh keeps no other copy."
	)
	dialog.ok_button_text = "So be it"
	add_child(dialog)
	dialog.popup_centered()


func _go_to_overworld() -> void:
	if _transition != null:
		await _transition.call("change_scene_ritual", OVERWORLD_SCENE)
	else:
		get_tree().change_scene_to_file(OVERWORLD_SCENE)


## A fresh run seed. Uses the system RNG here (PRESENTATION layer — NOT a deterministic gameplay
## draw; the chosen seed then roots every canonical stream for the run). A given seed replays
## identically, which is what determinism requires.
func _fresh_seed() -> int:
	return int(Time.get_unix_time_from_system()) ^ (randi() << 16)


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
