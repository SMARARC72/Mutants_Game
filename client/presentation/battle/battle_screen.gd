extends Control
## BattleScreen (Phase 5 · Slice 1) — the battle round-trip's PRESENTATION. CODE-BUILT (a thin .tscn
## just loads this script) so it is unit-testable headless. Per the slice scope it AUTO-RUNS the
## BattleController via BattleSession (full interactive battle UI is a later slice) and renders:
##   * the transcript log (the BattleController's char-for-char strings),
##   * per-team survivor lines (a minimal HP/standing read-out),
##   * a win/lose RESULT banner,
## all from minimal, code-built Control nodes styled via ThemeService.
##
## FLOW: reads the pending battle (enemy_party + battle_seed) GameController stashed before the swap,
## runs the session against the run's party, applies the result back to the run (xp), then waits for
## a Confirm to return to the overworld (the loop closes). DETERMINISTIC: same seed + teams =>
## identical transcript + banner (the BattleSession's canonical RNG guarantee).

const BattleSessionScript := preload("res://application/battle/battle_session.gd")
const InputActions := preload("res://infrastructure/input/input_actions.gd")
const OVERWORLD_SCENE := "res://presentation/overworld/overworld_screen.tscn"

var _game: Node = null
var _transition: Node = null
var _input: Node = null
var _result: Dictionary = {}
var _continue_button: Button = null
## When false, _ready does NOT auto-run the pending battle (a headless test drives
## run_pending_battle() once explicitly). Default true so production auto-runs on scene entry.
var _auto_run: bool = true


func _ready() -> void:
	# An injected _game (set_game before add_child) MUST win; only fall back to the autoload when
	# nothing was injected, so the test harness is never clobbered (mirrors overworld_screen).
	if _game == null:
		_game = get_node_or_null("/root/GameController")
	_transition = get_node_or_null("/root/Transition")
	_input = get_node_or_null("/root/InputService")
	var theme_service := get_node_or_null("/root/ThemeService")
	if theme_service != null and theme_service.has_method("apply_to"):
		theme_service.call("apply_to", self)
	if _input != null and _input.has_method("switch_context"):
		_input.call("switch_context", InputActions.CTX_BATTLE)
	if _auto_run and _game != null and _game.has_method("has_run") and _game.call("has_run"):
		run_pending_battle()


## Inject the GameController (tests / non-autoload contexts). Call BEFORE add_child/run_pending.
func set_game(game: Node) -> void:
	_game = game


## Disable the automatic battle run on _ready (tests drive run_pending_battle() once explicitly).
func set_auto_run(enabled: bool) -> void:
	_auto_run = enabled


## Run the battle GameController stashed in run.flags.pending_battle, render it, apply the result.
## Public so a test can drive it headlessly after configuring a GameController + pending battle.
## Returns the result dict (also stored on the screen).
func run_pending_battle() -> Dictionary:
	if _game == null:
		return {}
	var run: RunContext = _game.call("run")
	if run == null:
		return {}
	# Re-entrancy guard: a battle runs ONCE per pending_battle. A stray second call (e.g. _ready
	# auto-run + an explicit drive) finds no pending flag and returns the cached result rather than
	# running a degenerate empty-enemy battle that would re-apply / zero xp and corrupt state.
	if not run.flags.has("pending_battle"):
		return _result
	var pending: Dictionary = run.flags.get("pending_battle", {})
	var enemy_party: Array = pending.get("enemy_party", [])
	var battle_seed := int(pending.get("battle_seed", 0))
	var catalog: SpeciesCatalog = _game.call("catalog")
	var session: BattleSession = BattleSessionScript.new(catalog)
	_result = session.run(run.party, enemy_party, battle_seed)
	if _game.has_method("apply_battle_result"):
		_game.call("apply_battle_result", _result)
	# Clear the pending battle + persist the post-battle run (autosave on encounter-end).
	run.flags.erase("pending_battle")
	if _game.has_method("save_run"):
		_game.call("save_run")
	_build_ui()
	return _result


## The battle result (winner / survivors / xp / transcript). Empty until run_pending_battle().
func result() -> Dictionary:
	return _result


## Return to the overworld (the loop closes). Public so input + the Continue button both call it.
func return_to_overworld() -> void:
	if _transition != null and _transition.has_method("change_scene_ritual"):
		await _transition.call("change_scene_ritual", OVERWORLD_SCENE)
	elif is_inside_tree():
		get_tree().change_scene_to_file(OVERWORLD_SCENE)


func _input_event_confirm() -> void:
	return_to_overworld()


func _process(_delta: float) -> void:
	if _input != null and _input.has_method("just_pressed"):
		if bool(_input.call("just_pressed", InputActions.CONFIRM)):
			set_process(false)
			return_to_overworld()


# === UI (minimal, code-built, themed) ========================================================= #


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
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	var won := bool(_result.get("player_won", false))
	var banner := Label.new()
	banner.name = "ResultBanner"
	banner.text = "VICTORY" if won else "DEFEAT"
	banner.theme_type_variation = "TitleLabel"
	banner.add_theme_color_override(
		"font_color", Color(0.55, 0.85, 0.45) if won else Color(0.85, 0.35, 0.35)
	)
	box.add_child(banner)

	var summary := Label.new()
	summary.name = "Summary"
	summary.text = _summary_text()
	summary.theme_type_variation = "MutedLabel"
	box.add_child(summary)

	var log_panel := PanelContainer.new()
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(log_panel)
	var scroll := ScrollContainer.new()
	log_panel.add_child(scroll)
	var log_label := RichTextLabel.new()
	log_label.name = "TranscriptLog"
	log_label.fit_content = true
	log_label.scroll_active = false
	log_label.custom_minimum_size = Vector2(0, 320)
	log_label.text = _transcript_text()
	scroll.add_child(log_label)

	_continue_button = Button.new()
	_continue_button.name = "ContinueButton"
	_continue_button.text = "Return to the Verdant"
	_continue_button.pressed.connect(_input_event_confirm)
	box.add_child(_continue_button)


func _summary_text() -> String:
	var turns := int(_result.get("turns", 0))
	var xp := int(_result.get("xp", 0))
	var survivors: Array = _result.get("player_survivors", [])
	var standing := ", ".join(PackedStringArray(survivors)) if not survivors.is_empty() else "—"
	return "Turns: %d    XP: +%d    Standing: %s" % [turns, xp, standing]


func _transcript_text() -> String:
	var lines: Array = _result.get("transcript", [])
	return "\n".join(PackedStringArray(lines.map(func(s: Variant) -> String: return str(s))))
