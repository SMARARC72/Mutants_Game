extends Control
## CharacterSheet (Phase 8) — surfaces the player's MORALITY / APOTHEOSIS trajectory, which the engine
## has tracked all along (run.order_chaos / purity_corrupt / corruption / deeds / notoriety) but no
## screen ever showed. PRESENTATION layer, CODE-BUILT (a thin .tscn loads this) so it is headless-
## testable: inject a GameController, call build_from_game(), assert the god / rank readouts.
##
## The two hidden morality axes (each split in 3 by CharacterEngine.band3) form the 3x3 grid of nine
## emergent gods (CharacterEngine.GODS) — the destination of Apotheosis. This sheet reads, never
## writes: it shows where the player currently sits on Order⇄Chaos × Purity⇄Corruption, their rank on
## the god-ladder, notoriety (how hard the world hunts them), and the unified corruption meter.

const InputActions := preload("res://infrastructure/input/input_actions.gd")
const OVERWORLD_SCENE := "res://presentation/overworld/overworld_screen.tscn"
const OC_LABELS: Array = ["Order", "Balanced", "Chaos"]  # band3 order matches oracle/character_engine
const PC_LABELS: Array = ["Pure", "Tainted", "Corrupt"]

var _game: Node = null
var _transition: Node = null
var _input: Node = null
var _auto_build: bool = true

var _god_label: Label = null
var _rank_label: Label = null
var _oc_bar: ProgressBar = null
var _pc_bar: ProgressBar = null
var _corruption_bar: ProgressBar = null
var _corruption_label: Label = null


func _ready() -> void:
	if _game == null:
		_game = get_node_or_null("/root/GameController")
	_transition = get_node_or_null("/root/Transition")
	_input = get_node_or_null("/root/InputService")
	var theme_service := get_node_or_null("/root/ThemeService")
	if theme_service != null and theme_service.has_method("apply_to"):
		theme_service.call("apply_to", self)
	if _input != null and _input.has_method("switch_context"):
		_input.call("switch_context", InputActions.CTX_MENU)
	if _auto_build and _game != null and _game.has_method("has_run") and _game.call("has_run"):
		build_from_game()


## Inject the GameController (tests / non-autoload). Call BEFORE add_child/build_from_game.
func set_game(game: Node) -> void:
	_game = game


## Disable the auto build on _ready (tests inject + drive build_from_game()).
func set_auto_build(enabled: bool) -> void:
	_auto_build = enabled


## Build the sheet from the run's morality state. Public so a test drives it headlessly.
func build_from_game() -> void:
	_build_ui()
	_refresh()


# === accessors (tests) ======================================================================== #


## The current god archetype text (e.g. "The Warden  (Steward)").
func god_text() -> String:
	return _god_label.text if _god_label != null else ""


## The current rank text.
func rank_text() -> String:
	return _rank_label.text if _rank_label != null else ""


# === navigation =============================================================================== #


func return_to_overworld() -> void:
	if _transition != null and _transition.has_method("change_scene_ritual"):
		await _transition.call("change_scene_ritual", OVERWORLD_SCENE)
	elif is_inside_tree():
		get_tree().change_scene_to_file(OVERWORLD_SCENE)


func _process(_delta: float) -> void:
	if _input == null or not _input.has_method("just_pressed"):
		return
	if bool(_input.call("just_pressed", InputActions.CANCEL)):
		set_process(false)
		return_to_overworld()


# === data ===================================================================================== #


func _run() -> RunContext:
	if _game == null or not _game.has_method("run"):
		return null
	return _game.call("run")


func _refresh() -> void:
	var run := _run()
	if run == null:
		return
	var oc := CharacterEngine.clamp_axis(run.order_chaos)
	var pc := CharacterEngine.clamp_axis(run.purity_corrupt)
	var oc_band := CharacterEngine.band3(oc, OC_LABELS)
	var pc_band := CharacterEngine.band3(pc, PC_LABELS)
	if _god_label != null:
		_god_label.text = CharacterEngine.gods([oc_band, pc_band])
	if _rank_label != null:
		var rank := run.rank if run.rank != "" else CharacterEngine.rank_for(run.deeds)
		_rank_label.text = (
			"Rank %s   ·   Deeds %d   ·   Notoriety %d" % [rank, run.deeds, run.notoriety]
		)
	if _oc_bar != null:
		_oc_bar.value = oc
	if _pc_bar != null:
		_pc_bar.value = pc
	if _corruption_bar != null:
		var c := clampi(run.corruption, 0, 100)
		_corruption_bar.value = c
		var fill := StyleBoxFlat.new()
		fill.bg_color = GrimoirePalette.corruption_color(float(c) / 100.0)
		fill.set_corner_radius_all(3)
		_corruption_bar.add_theme_stylebox_override("fill", fill)
		if _corruption_label != null:
			_corruption_label.text = (
				"Corruption  %d / 100%s" % [c, "   — FERAL" if c >= 100 else ""]
			)


# === UI (code-built, themed) ================================================================== #


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.06, 0.09)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)

	var box := VBoxContainer.new()
	box.name = "RootBox"
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	var title := Label.new()
	title.name = "SheetTitle"
	title.text = "The Self — your road to Apotheosis"
	title.theme_type_variation = "TitleLabel"
	box.add_child(title)

	var panel := PanelContainer.new()
	box.add_child(panel)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	panel.add_child(inner)

	_god_label = Label.new()
	_god_label.name = "GodLabel"
	_god_label.theme_type_variation = "TitleLabel"
	inner.add_child(_god_label)
	var god_sub := Label.new()
	god_sub.text = "the god you are becoming (the grid you sit in)"
	god_sub.theme_type_variation = "MutedLabel"
	inner.add_child(god_sub)

	_rank_label = Label.new()
	_rank_label.name = "RankLabel"
	inner.add_child(_rank_label)

	_oc_bar = _add_axis(inner, "Order", "Chaos", "OrderChaosBar", Color(0.808, 0.722, 0.42))
	# The Purity⇄Corrupt fill leans toward the Corrupt pole — the palette's rot rule owns
	# that colour (full bruise-purple), never a hand-picked hex.
	_pc_bar = _add_axis(
		inner, "Pure", "Corrupt", "PurityCorruptBar", GrimoirePalette.corruption_color(1.0)
	)

	var corruption_title := Label.new()
	corruption_title.text = "The price of playing god"
	corruption_title.theme_type_variation = "MutedLabel"
	inner.add_child(corruption_title)
	_corruption_label = Label.new()
	_corruption_label.name = "CorruptionLabel"
	inner.add_child(_corruption_label)
	_corruption_bar = ProgressBar.new()
	_corruption_bar.name = "CorruptionBar"
	_corruption_bar.min_value = 0
	_corruption_bar.max_value = 100
	_corruption_bar.show_percentage = false
	_corruption_bar.custom_minimum_size = Vector2(0, 18)
	_style_track(_corruption_bar)
	inner.add_child(_corruption_bar)

	var back := Button.new()
	back.name = "BackButton"
	back.text = "Return to the descent"
	back.pressed.connect(return_to_overworld)
	box.add_child(back)
	# W1 focus pass: the sheet is read-only, so its one verb (Back) owns focus.
	if back.is_inside_tree():
		back.grab_focus()


## One morality axis row: left pole label, a track ProgressBar (-100..100), right pole label. The fill
## leans toward the right pole as the value rises (a quick "where do I sit" read).
func _add_axis(
	parent: VBoxContainer, left: String, right: String, bar_name: String, tint: Color
) -> ProgressBar:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var left_label := Label.new()
	left_label.text = left
	left_label.custom_minimum_size = Vector2(70, 0)
	left_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(left_label)
	var bar := ProgressBar.new()
	bar.name = bar_name
	bar.min_value = -100
	bar.max_value = 100
	bar.value = 0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 18)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_track(bar)
	var fill := StyleBoxFlat.new()
	fill.bg_color = tint
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)
	var right_label := Label.new()
	right_label.text = right
	right_label.custom_minimum_size = Vector2(70, 0)
	row.add_child(right_label)
	return bar


static func _style_track(bar: ProgressBar) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.090196, 0.07451, 0.109804)  # INK
	track.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", track)
