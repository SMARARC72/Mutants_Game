extends Control
## EndingScreen (Batch E2b "The Endings Surface") — the run's CLOSING PAGE, pushed as a UiRouter
## full overlay the moment the finale flag lands (EndingGate, the slice_cleared hook pattern).
## PRESENTATION layer, CODE-BUILT (the thin .tscn just loads this script) so it is headless-
## testable: a test injects a GameController, calls begin(), and asserts the resolved ending,
## the latched flag and the rendered ledger WITHOUT rendering.
##
## The page (E2b contract):
##   * an ink scrim (full-rect, opaque — the world beneath is over);
##   * the resolved ending's NAME in Cinzel (TitleLabel) + its authored epithet;
##   * the epigraph TYPE-ON (skippable — CONFIRM/CANCEL completes it instantly; reduce_motion
##     and headless run instant, the CaptureMoment contract);
##   * the run's LEDGER on ParchmentPanel — creatures caught / spliced / lost, corruption,
##     Bloomwarden standing — every number read from run fields via EndingsService.run_ledger;
##   * "The record closes." and one verb: Save & return to the title.
## The resolved ending id is latched into run.flags (EndingsService.record) the moment the page
## begins, so the SAVE is a closed ledger — the main menu's Continue gate answers "This ledger
## is closed — begin anew?" from then on. Every word here is the catalog's; the screen invents
## no line and computes no number.

const InputActions := preload("res://infrastructure/input/input_actions.gd")
const MAIN_MENU_SCENE := "res://presentation/screens/main_menu.tscn"

## Type-on pacing (seconds per character) + the surrounding reveal beats. Presentation only.
const TYPE_ON_PER_CHAR := 0.018
const NAME_FADE_TIME := 0.6
const LEDGER_FADE_TIME := 0.5
const CLOSING_LINE := "The record closes."

var _game: Node = null
var _input: Node = null
## Instant mode: headless always; windowed play honours reduce_motion (CaptureMoment pattern).
var _instant: bool = DisplayServer.get_name() == "headless"

var _ending: Dictionary = {}
var _name_label: Label = null
var _epithet_label: Label = null
var _epigraph_label: Label = null
var _ledger_box: VBoxContainer = null
var _ledger_panel: PanelContainer = null
var _closing_label: Label = null
var _close_button: Button = null
var _reveal: Tween = null


func _ready() -> void:
	if _game == null:
		_game = get_node_or_null("/root/GameController")
	_input = get_node_or_null("/root/InputService")
	var theme_service := get_node_or_null("/root/ThemeService")
	if theme_service != null and theme_service.has_method("apply_to"):
		theme_service.call("apply_to", self)
	if _input != null and _input.has_method("switch_context"):
		_input.call("switch_context", InputActions.CTX_MENU)
	if not _instant and _reduce_motion():
		_instant = true


## Inject the GameController (tests / the EndingGate push). Call BEFORE begin().
func set_game(game: Node) -> void:
	_game = game


## Force instant mode on/off (tests exercise both routes).
func set_instant(enabled: bool) -> void:
	_instant = enabled


## Resolve the run's ending, LATCH it into run.flags (the ledger closes here), build the page
## and start the reveal (instant mode lands fully-shown synchronously). Returns the resolved
## ending (tests assert on it). Safe to call once per push.
func begin() -> Dictionary:
	var run := _run()
	_ending = EndingsService.resolve(run)
	EndingsService.record(run, str(_ending.get("id", "")))
	_build_ui()
	if _instant:
		_show_all()
	else:
		_play_reveal()
	return _ending


# === accessors (tests) ======================================================================== #


func ending_id() -> String:
	return str(_ending.get("id", ""))


func name_text() -> String:
	return _name_label.text if _name_label != null else ""


func epigraph_text() -> String:
	return _epigraph_label.text if _epigraph_label != null else ""


func ledger_row_count() -> int:
	return _ledger_box.get_child_count() if _ledger_box != null else 0


func closing_text() -> String:
	return _closing_label.text if _closing_label != null else ""


# === the reveal (skippable; instant mode never awaits) ======================================== #


func _process(_delta: float) -> void:
	if _input == null or not _input.has_method("just_pressed"):
		return
	# The reveal is SKIPPABLE: either edge completes it instantly. A finished page swallows both
	# (the record only closes forward, through the one verb).
	if (
		bool(_input.call("just_pressed", InputActions.CONFIRM))
		or bool(_input.call("just_pressed", InputActions.CANCEL))
	):
		skip_reveal()


## Complete the staged reveal NOW: kill the tween, show everything, focus the verb.
func skip_reveal() -> void:
	if _reveal != null and _reveal.is_valid():
		_reveal.kill()
	_reveal = null
	_show_all()


func _play_reveal() -> void:
	if _epigraph_label == null:
		return
	_epigraph_label.visible_ratio = 0.0
	_ledger_panel.modulate.a = 0.0
	_closing_label.modulate.a = 0.0
	_close_button.modulate.a = 0.0
	_name_label.modulate.a = 0.0
	_epithet_label.modulate.a = 0.0
	var type_time := maxf(0.6, _epigraph_label.text.length() * TYPE_ON_PER_CHAR)
	_reveal = create_tween()
	_reveal.tween_property(_name_label, "modulate:a", 1.0, NAME_FADE_TIME)
	_reveal.parallel().tween_property(_epithet_label, "modulate:a", 1.0, NAME_FADE_TIME).set_delay(
		NAME_FADE_TIME * 0.5
	)
	_reveal.tween_property(_epigraph_label, "visible_ratio", 1.0, type_time)
	_reveal.tween_property(_ledger_panel, "modulate:a", 1.0, LEDGER_FADE_TIME)
	_reveal.tween_property(_closing_label, "modulate:a", 1.0, LEDGER_FADE_TIME)
	_reveal.tween_property(_close_button, "modulate:a", 1.0, LEDGER_FADE_TIME)
	_reveal.tween_callback(_focus_verb)


func _show_all() -> void:
	if _epigraph_label == null:
		return
	_name_label.modulate.a = 1.0
	_epithet_label.modulate.a = 1.0
	_epigraph_label.visible_ratio = 1.0
	_ledger_panel.modulate.a = 1.0
	_closing_label.modulate.a = 1.0
	_close_button.modulate.a = 1.0
	_focus_verb()


func _focus_verb() -> void:
	if _close_button != null and _close_button.is_inside_tree():
		_close_button.grab_focus()


# === the one verb: save & return to the title ================================================= #


## Persist the closed ledger (the ending id is already latched) and return to the title. As a
## router overlay the whole stack unwinds first; the scene swap goes through the ritual
## Transition when present.
func save_and_close() -> void:
	set_process(false)
	if _game != null and _game.has_method("request_save"):
		await _game.call("request_save")
	var router := get_node_or_null("/root/UiRouter")
	if router != null and router.has_method("pop_all"):
		router.call("pop_all")
	var transition := get_node_or_null("/root/Transition")
	if transition != null and transition.has_method("change_scene_ritual"):
		await transition.call("change_scene_ritual", MAIN_MENU_SCENE)
	elif is_inside_tree():
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)


# === data ===================================================================================== #


func _run() -> RunContext:
	if _game == null or not _game.has_method("run"):
		return null
	return _game.call("run")


func _reduce_motion() -> bool:
	var settings := get_node_or_null("/root/Settings")
	if settings == null or not settings.has_method("get_value"):
		return false
	return bool(settings.call("get_value", "accessibility", "reduce_motion", false))


# === UI (code-built, ink + parchment) ========================================================= #


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# The ink scrim — OPAQUE: the world beneath this page is over.
	var scrim := ColorRect.new()
	scrim.name = "InkScrim"
	scrim.color = GrimoirePalette.INK
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.name = "EndingBox"
	box.add_theme_constant_override("separation", 14)
	box.custom_minimum_size = Vector2(720, 0)
	center.add_child(box)

	_name_label = Label.new()
	_name_label.name = "EndingName"
	_name_label.text = str(_ending.get("name", ""))
	_name_label.theme_type_variation = "TitleLabel"
	_name_label.add_theme_font_size_override("font_size", 44)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_name_label)

	_epithet_label = Label.new()
	_epithet_label.name = "EndingEpithet"
	_epithet_label.text = str(_ending.get("epithet", ""))
	_epithet_label.theme_type_variation = "MutedLabel"
	_epithet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_epithet_label.visible = str(_ending.get("epithet", "")) != ""
	box.add_child(_epithet_label)

	_epigraph_label = Label.new()
	_epigraph_label.name = "EndingEpigraph"
	_epigraph_label.text = str(_ending.get("epigraph", ""))
	_epigraph_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_epigraph_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_epigraph_label.add_theme_color_override("font_color", GrimoirePalette.TEXT_ON_INK)
	box.add_child(_epigraph_label)

	_build_ledger(box)

	_closing_label = Label.new()
	_closing_label.name = "ClosingLine"
	_closing_label.text = CLOSING_LINE
	_closing_label.theme_type_variation = "MutedLabel"
	_closing_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_closing_label)

	_close_button = Button.new()
	_close_button.name = "SaveAndCloseButton"
	_close_button.text = "Save & return to the title"
	_close_button.pressed.connect(save_and_close)
	box.add_child(_close_button)


## The run's ledger on parchment: what the climb cost, itemized. Numbers via
## EndingsService.run_ledger (data-only run fields — this screen computes nothing).
func _build_ledger(box: VBoxContainer) -> void:
	_ledger_panel = PanelContainer.new()
	_ledger_panel.name = "LedgerPanel"
	_ledger_panel.theme_type_variation = "ParchmentPanel"
	box.add_child(_ledger_panel)
	_ledger_box = VBoxContainer.new()
	_ledger_box.name = "LedgerBox"
	_ledger_box.add_theme_constant_override("separation", 4)
	_ledger_panel.add_child(_ledger_box)
	var ledger := EndingsService.run_ledger(_run())
	var tier := ""
	if _game != null and _game.has_method("bloomwardens_tier"):
		tier = "  (%s)" % str(_game.call("bloomwardens_tier"))
	_ledger_row("Creatures caught", str(int(ledger.get("caught", 0))))
	_ledger_row("Creatures spliced", str(int(ledger.get("spliced", 0))))
	_ledger_row("Lost to the graveyard", str(int(ledger.get("lost", 0))))
	_ledger_row("Corruption", str(int(ledger.get("corruption", 0))))
	_ledger_row("Bloomwarden standing", str(int(ledger.get("standing", 0))) + tier)


func _ledger_row(label_text: String, value_text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var name_label := Label.new()
	name_label.text = label_text
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", GrimoirePalette.TEXT_ON_PARCHMENT)
	row.add_child(name_label)
	var value_label := Label.new()
	value_label.text = value_text
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_color_override("font_color", GrimoirePalette.TEXT_ON_PARCHMENT)
	row.add_child(value_label)
	_ledger_box.add_child(row)
