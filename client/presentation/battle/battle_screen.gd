extends Control
## BattleScreen (Phase 5 · Slice 2) — the INTERACTIVE battle's PRESENTATION. CODE-BUILT (a thin .tscn
## just loads this script) so it is unit-testable headless. The player's side is PLAYER-DRIVEN: on a
## player actor's turn the screen offers Attack (pick a target), Capture (wild only) and Flee (wild
## only); the enemy side is brain-driven. Every strike resolves through the EXISTING oracle path
## (BattleController.InteractiveSession → BattleEngine.attack) preserving the turn structure +
## RES/SEL sub-stream split. The Slice 1 AUTO path (BattleSession.run / simulate parity) is untouched
## and still used for boss/auto battles.
##
## It renders, from minimal code-built Control nodes styled via ThemeService:
##   * party + enemy ROWS (HP bar + name/force per combatant),
##   * a turn / whose-turn INDICATOR,
##   * the ACTION MENU (Attack → target picker / Capture / Flee),
##   * a scrolling TRANSCRIPT log (the controller's char-for-char strings),
##   * a VICTORY / DEFEAT / FLED / CAUGHT banner.
##
## FLOW: reads the pending battle (enemy_party + battle_seed [+ is_wild]) GameController stashed before
## the swap, builds an interactive session against the run's party, drives it turn-by-turn from player
## input, then applies the result back to the run (xp on a win; a caught creature joins the party),
## persists, and waits for a Confirm to return to the overworld. DETERMINISTIC: same (seed, teams,
## player-choice sequence) => byte-identical transcript + result (canonical RNG; capture rolls on a
## disjoint capture sub-stream).

const BattleSessionScript := preload("res://application/battle/battle_session.gd")
const CaptureServiceScript := preload("res://application/battle/capture_service.gd")
const InputActions := preload("res://infrastructure/input/input_actions.gd")
const OVERWORLD_SCENE := "res://presentation/overworld/overworld_screen.tscn"

const _STEP_AWAIT := "await_player"
const _STEP_RESOLVED := "resolved"
const _STEP_ENDED := "ended"

var _game: Node = null
var _transition: Node = null
var _input: Node = null
var _result: Dictionary = {}
var _battle: BattleSession.InteractiveBattle = null
var _session: BattleSession = null  # the BattleSession (for result_for)
var _is_wild: bool = true
var _last_step: Dictionary = {}
var _continue_button: Button = null
var _action_menu: VBoxContainer = null
var _target_picker: VBoxContainer = null
var _turn_label: Label = null
var _transcript_label: RichTextLabel = null
var _scroll: ScrollContainer = null
var _party_rows: VBoxContainer = null
var _enemy_rows: VBoxContainer = null
var _banner: Label = null
var _root_box: VBoxContainer = null
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


## Begin the interactive battle GameController stashed in run.flags.pending_battle. Builds the UI and
## pumps the session to the first decision point (a player turn, or the end). Public so a test can
## drive it headlessly after configuring a GameController + pending battle. Returns the last step dict.
func run_pending_battle() -> Dictionary:
	if _game == null:
		return {}
	var run: RunContext = _game.call("run")
	if run == null:
		return {}
	# Re-entrancy guard: a battle builds ONCE per pending_battle. A stray second call finds no pending
	# flag and returns the cached result/step rather than rebuilding a degenerate empty battle.
	if not run.flags.has("pending_battle"):
		return _last_step
	var pending: Dictionary = run.flags.get("pending_battle", {})
	var enemy_party: Array = pending.get("enemy_party", [])
	var battle_seed := int(pending.get("battle_seed", 0))
	_is_wild = bool(pending.get("is_wild", true))  # overworld encounters are wild by default
	var catalog: SpeciesCatalog = _game.call("catalog")
	_session = BattleSessionScript.new(catalog)
	_battle = _session.begin_interactive(run.party, enemy_party, battle_seed)
	# Clear the pending flag now so a re-entrant call is a no-op even mid-battle.
	run.flags.erase("pending_battle")
	_build_ui()
	if _battle == null:
		# Unassemblable team — finish immediately with an invalid-style result.
		_result = {"valid": false, "winner": "enemy", "player_won": false, "transcript": []}
		_show_banner_text("DEFEAT")
		return _last_step
	_pump()
	return _last_step


# === interactive driving ====================================================================== #


## Pump the session forward, resolving brain steps inline (updating HP + log), until it AWAITs a
## player action or ENDs. Idempotent w.r.t. an ended battle.
func _pump() -> void:
	if _battle == null:
		return
	var step := _battle.advance()
	while str(step.get("kind", "")) == _STEP_RESOLVED:
		_refresh_combatants()
		_refresh_transcript()
		step = _battle.advance()
	_last_step = step
	_apply_step(step)


func _apply_step(step: Dictionary) -> void:
	var kind := str(step.get("kind", ""))
	_refresh_combatants()
	_refresh_transcript()
	if kind == _STEP_AWAIT:
		_refresh_turn_label(step)
		_show_action_menu()
	elif kind == _STEP_ENDED:
		_finish_battle(step)


## Player ATTACK the enemy at `target_index` (in the enemy team's order). Resolves the strike, then
## pumps the enemy's responses. Public so the UI buttons + tests drive it.
func player_attack(target_index: int) -> Dictionary:
	if _battle == null or _battle.is_ended():
		return _last_step
	var foes := _battle.enemy_team()
	var target: BattleEngine.Mon = null
	if target_index >= 0 and target_index < foes.size():
		target = foes[target_index] as BattleEngine.Mon
	_hide_menus()
	_battle.attack(target)
	_pump()
	return _last_step


## Player CAPTURE the current wild target (default: first alive enemy, or `target_index` if given).
## Computes the oracle chance + canonical roll; success ends the battle as a catch (the creature joins
## the party on result apply), failure consumes the turn (enemy then acts). Wild battles only.
func player_capture(target_index: int = -1) -> Dictionary:
	if _battle == null or _battle.is_ended() or not _is_wild:
		return _last_step
	var foes := _battle.enemy_team()
	var target := _resolve_capture_target(foes, target_index)
	if target == null:
		return _last_step
	_hide_menus()
	var gear := _gear_ids()
	var outcome := _battle.attempt_capture(target, gear)
	if str(outcome.get("kind", "")) == _STEP_ENDED:
		_last_step = outcome
		_apply_step(outcome)
	else:
		_last_step = outcome
		_pump()
	return _last_step


## Player FLEE (wild only) — ends the battle, returns to the overworld with the run intact (no xp).
func player_flee() -> Dictionary:
	if _battle == null or _battle.is_ended() or not _is_wild:
		return _last_step
	_hide_menus()
	var step := _battle.flee()
	_last_step = step
	_apply_step(step)
	return _last_step


## Finalise: build the Slice-shaped result from the finished session, apply it to the run (xp + any
## caught creature), clear pending, persist, and show the outcome banner + Continue affordance.
func _finish_battle(step: Dictionary) -> void:
	if _session == null or _battle == null:
		return
	var reason := str(step.get("reason", ""))
	_result = _session.result_for(_battle.session(), _battle.caught())
	if _game != null and _game.has_method("apply_battle_result"):
		_game.call("apply_battle_result", _result)
	if _game != null and _game.has_method("save_run"):
		_game.call("save_run")
	_toast_outcome(reason)
	_show_banner_text(_banner_text_for(reason))
	_hide_menus()
	_show_continue()


# === accessors ================================================================================ #


## The battle result (winner / survivors / xp / transcript / caught). Empty until the battle ends.
func result() -> Dictionary:
	return _result


## The most recent session step (await_player / resolved / ended). For headless test assertions.
func last_step() -> Dictionary:
	return _last_step


## The live interactive battle wrapper (for tests that want to read teams / capture math directly).
func battle() -> BattleSession.InteractiveBattle:
	return _battle


## Return to the overworld (the loop closes). Public so input + the Continue button both call it.
func return_to_overworld() -> void:
	if _transition != null and _transition.has_method("change_scene_ritual"):
		await _transition.call("change_scene_ritual", OVERWORLD_SCENE)
	elif is_inside_tree():
		get_tree().change_scene_to_file(OVERWORLD_SCENE)


func _input_event_confirm() -> void:
	return_to_overworld()


func _process(_delta: float) -> void:
	if _input == null:
		return
	# After the battle ends, Confirm returns to the overworld (matches Slice 1).
	if _battle != null and _battle.is_ended() and _input.has_method("just_pressed"):
		if bool(_input.call("just_pressed", InputActions.CONFIRM)):
			set_process(false)
			return_to_overworld()


# === helpers ================================================================================== #


func _resolve_capture_target(foes: Array, target_index: int) -> BattleEngine.Mon:
	if target_index >= 0 and target_index < foes.size():
		var chosen := foes[target_index] as BattleEngine.Mon
		if chosen != null and chosen.alive:
			return chosen
	for f in foes:
		var m := f as BattleEngine.Mon
		if m.alive:
			return m
	return null


func _gear_ids() -> Array:
	if _game == null:
		return []
	var run: RunContext = _game.call("run")
	if run == null:
		return []
	return CaptureServiceScript.gear_ids(run.gear)


func _toast_outcome(reason: String) -> void:
	var toast := get_node_or_null("/root/Toast")
	if toast == null:
		return
	if reason == "caught" and toast.has_method("event"):
		toast.call("event", "creature_caught")
	elif toast.has_method("show"):
		toast.call("show", {"title": _banner_text_for(reason), "body": "", "sound": "chime"})


func _banner_text_for(reason: String) -> String:
	match reason:
		"caught":
			return "CAUGHT"
		"fled":
			return "FLED"
		_:
			return "VICTORY" if bool(_result.get("player_won", false)) else "DEFEAT"


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
	box.name = "RootBox"
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	_root_box = box

	_banner = Label.new()
	_banner.name = "ResultBanner"
	_banner.theme_type_variation = "TitleLabel"
	box.add_child(_banner)

	_turn_label = Label.new()
	_turn_label.name = "TurnIndicator"
	_turn_label.theme_type_variation = "MutedLabel"
	box.add_child(_turn_label)

	var teams := HBoxContainer.new()
	teams.add_theme_constant_override("separation", 24)
	box.add_child(teams)

	var party_box := VBoxContainer.new()
	party_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	teams.add_child(party_box)
	var party_title := Label.new()
	party_title.text = "Your Coven"
	party_title.theme_type_variation = "MutedLabel"
	party_box.add_child(party_title)
	_party_rows = VBoxContainer.new()
	_party_rows.name = "PartyRows"
	party_box.add_child(_party_rows)

	var enemy_box := VBoxContainer.new()
	enemy_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	teams.add_child(enemy_box)
	var enemy_title := Label.new()
	enemy_title.text = "The Wild" if _is_wild else "Adversary"
	enemy_title.theme_type_variation = "MutedLabel"
	enemy_box.add_child(enemy_title)
	_enemy_rows = VBoxContainer.new()
	_enemy_rows.name = "EnemyRows"
	enemy_box.add_child(_enemy_rows)

	_action_menu = VBoxContainer.new()
	_action_menu.name = "ActionMenu"
	box.add_child(_action_menu)

	_target_picker = VBoxContainer.new()
	_target_picker.name = "TargetPicker"
	box.add_child(_target_picker)

	var log_panel := PanelContainer.new()
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(log_panel)
	_scroll = ScrollContainer.new()
	log_panel.add_child(_scroll)
	_transcript_label = RichTextLabel.new()
	_transcript_label.name = "TranscriptLog"
	_transcript_label.fit_content = true
	_transcript_label.scroll_active = false
	_transcript_label.custom_minimum_size = Vector2(0, 220)
	_scroll.add_child(_transcript_label)

	_refresh_combatants()
	_refresh_transcript()


## Build the combatant rows (HP bar + name/force) for both teams from the live Mons.
func _refresh_combatants() -> void:
	if _battle == null:
		return
	_rebuild_rows(_party_rows, _battle.player_team(), false)
	_rebuild_rows(_enemy_rows, _battle.enemy_team(), true)


func _rebuild_rows(container: VBoxContainer, team: Array, _is_enemy: bool) -> void:
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()
	for m in team:
		var mon := m as BattleEngine.Mon
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 1)
		var name_label := Label.new()
		var force := mon.prim if mon.sec == "" else "%s/%s" % [mon.prim, mon.sec]
		var down := "" if mon.alive else "  (down)"
		name_label.text = "%s — %s%s" % [mon.name, force, down]
		if not mon.alive:
			name_label.add_theme_color_override("font_color", Color(0.55, 0.5, 0.55))
		row.add_child(name_label)
		var bar := ProgressBar.new()
		bar.min_value = 0
		bar.max_value = mon.maxhp
		bar.value = maxi(0, mon.hp)
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 14)
		_style_hp_bar(bar)
		row.add_child(bar)
		var hp_label := Label.new()
		hp_label.text = "%d / %d" % [maxi(0, mon.hp), mon.maxhp]
		hp_label.theme_type_variation = "MutedLabel"
		row.add_child(hp_label)
		container.add_child(row)


## Colour the HP bar green -> amber -> red by health fraction (an instant read-out) over a dark INK
## track, with rounded corners to match the grimoire theme (replaces the engine default pink fill).
static func _style_hp_bar(bar: ProgressBar) -> void:
	var frac := 0.0
	if bar.max_value > 0:
		frac = clampf(bar.value / bar.max_value, 0.0, 1.0)
	var fill_color := Color(0.498039, 0.682353, 0.352941)  # SUCCESS green #7fae5a
	if frac < 0.3:
		fill_color = Color(0.760784, 0.25098, 0.184314)  # DANGER red #c2402f
	elif frac < 0.6:
		fill_color = Color(0.839216, 0.635294, 0.247059)  # WARNING amber #d6a23f
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(3)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.090196, 0.07451, 0.109804)  # INK track
	track.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", track)


func _refresh_transcript() -> void:
	if _transcript_label == null or _battle == null:
		return
	var lines: Array = _battle.transcript()
	_transcript_label.text = "\n".join(
		PackedStringArray(lines.map(func(s: Variant) -> String: return str(s)))
	)


func _refresh_turn_label(step: Dictionary) -> void:
	if _turn_label == null:
		return
	var turn := int(step.get("turn", 0))
	var actor := step.get("actor") as BattleEngine.Mon
	var who := actor.name if actor != null else "—"
	_turn_label.text = "Turn %d   ·   %s acts" % [turn, who]


## Show the player action menu: Attack (opens the target picker), Capture + Flee (wild only).
func _show_action_menu() -> void:
	_hide_target_picker()
	if _action_menu == null:
		return
	for child in _action_menu.get_children():
		child.queue_free()
	_action_menu.visible = true
	var attack_btn := Button.new()
	attack_btn.name = "AttackButton"
	attack_btn.text = "Attack"
	attack_btn.pressed.connect(_show_target_picker)
	_action_menu.add_child(attack_btn)
	if _is_wild:
		var capture_btn := Button.new()
		capture_btn.name = "CaptureButton"
		capture_btn.text = "Capture"
		capture_btn.pressed.connect(func() -> void: player_capture())
		_action_menu.add_child(capture_btn)
		var flee_btn := Button.new()
		flee_btn.name = "FleeButton"
		flee_btn.text = "Flee"
		flee_btn.pressed.connect(func() -> void: player_flee())
		_action_menu.add_child(flee_btn)


## Show one button per alive enemy (the Attack target picker).
func _show_target_picker() -> void:
	if _target_picker == null or _battle == null:
		return
	for child in _target_picker.get_children():
		child.queue_free()
	_target_picker.visible = true
	var foes := _battle.enemy_team()
	for i in foes.size():
		var mon := foes[i] as BattleEngine.Mon
		if not mon.alive:
			continue
		var btn := Button.new()
		btn.name = "Target%d" % i
		btn.text = "→ %s  (%d/%d)" % [mon.name, maxi(0, mon.hp), mon.maxhp]
		var idx := i
		btn.pressed.connect(func() -> void: player_attack(idx))
		_target_picker.add_child(btn)


func _hide_menus() -> void:
	if _action_menu != null:
		for child in _action_menu.get_children():
			child.queue_free()
		_action_menu.visible = false
	_hide_target_picker()


func _hide_target_picker() -> void:
	if _target_picker == null:
		return
	for child in _target_picker.get_children():
		child.queue_free()
	_target_picker.visible = false


func _show_banner_text(text: String) -> void:
	if _banner == null:
		return
	_banner.text = text
	var win := text == "VICTORY" or text == "CAUGHT"
	_banner.add_theme_color_override(
		"font_color", Color(0.55, 0.85, 0.45) if win else Color(0.85, 0.55, 0.35)
	)


func _show_continue() -> void:
	if _continue_button != null and is_instance_valid(_continue_button):
		return
	_continue_button = Button.new()
	_continue_button.name = "ContinueButton"
	_continue_button.text = "Return to the Verdant"
	_continue_button.pressed.connect(_input_event_confirm)
	if _root_box != null and is_instance_valid(_root_box):
		_root_box.add_child(_continue_button)
	else:
		add_child(_continue_button)
