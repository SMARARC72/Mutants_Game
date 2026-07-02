extends Node
## SaveSentry autoload (Wave 18 "Session Trust") — the run's save-outcome witness. It listens to
## GameController.save_succeeded / save_failed and makes every persist VISIBLE:
##   * success -> a small quill-scratch toast ("Sealed. The record holds — for now."), rate-limited
##     so the frequent autosave boundaries never spam;
##   * failure -> a PERSISTENT themed warning banner (top of screen, above gameplay, below toasts)
##     that stays until a later save lands, plus a toast with the reason.
## It also owns the WINDOW-CLOSE AUTOSAVE: `auto_accept_quit` is disabled (windowed builds only —
## headless CI keeps the default so runners exit cleanly) and NOTIFICATION_WM_CLOSE_REQUEST saves
## the active run before quitting, so alt-F4 never eats progress.
##
## PRESENTATION-adjacent autoload: talks only to the GameController signals + the Toast facade.
## Headless-safe: everything builds without a display; autosave_and_quit(false) is test-drivable.

## How long after a success toast before the next one may show (autosaves fire on every battle /
## camp / quest boundary — the trust cue should whisper, not nag).
const SUCCESS_TOAST_COOLDOWN_MS := 8000
const WARNING_TITLE := "THE LEDGER DID NOT TAKE THE INK"

var _game: Node = null
var _toast_gate_ms := -SUCCESS_TOAST_COOLDOWN_MS
var _warning_layer: CanvasLayer = null
var _warning_reason: Label = null


func _ready() -> void:
	if _game == null:
		set_game(get_node_or_null("/root/GameController"))
	# Own the close request so the sentry gets NOTIFICATION_WM_CLOSE_REQUEST before exit. Headless
	# runs (CI / GdUnit) keep auto-accept so the test runner's quit is never intercepted.
	if DisplayServer.get_name() != "headless" and get_tree() != null:
		get_tree().auto_accept_quit = false
	_build_warning_banner()


## Inject/replace the observed GameController (tests; autoload wiring uses /root). Reconnects.
func set_game(game: Node) -> void:
	_disconnect_game()
	_game = game
	if _game == null:
		return
	if _game.has_signal("save_succeeded"):
		_game.connect("save_succeeded", _on_save_succeeded)
	if _game.has_signal("save_failed"):
		_game.connect("save_failed", _on_save_failed)


## The quit-gate autosave: persist the active run (through request_save so the outcome is still
## witnessed), then quit. `quit=false` lets a headless test drive the save without ending the
## process. Safe with no game / no run (straight to quit).
func autosave_and_quit(quit: bool = true) -> void:
	if (
		_game != null
		and _game.has_method("has_run")
		and bool(_game.call("has_run"))
		and _game.has_method("request_save")
	):
		# The Fake/local DAL path resolves synchronously; Supabase awaits before the window closes.
		await _game.call("request_save")
	if quit and is_inside_tree():
		get_tree().quit()


## True while the persistent save-failure warning is showing (tests read this).
func warning_visible() -> bool:
	return _warning_layer != null and _warning_layer.visible


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		autosave_and_quit()


# === signal handlers ========================================================================== #


func _on_save_succeeded() -> void:
	if _warning_layer != null:
		_warning_layer.visible = false
	var now := Time.get_ticks_msec()
	if now - _toast_gate_ms < SUCCESS_TOAST_COOLDOWN_MS:
		return
	_toast_gate_ms = now
	var toast := get_node_or_null("/root/Toast")
	if toast != null and toast.has_method("show"):
		var line := VoiceBook.pick_plain("ui.saveload.save_complete")
		if line == "":
			line = "Sealed. The record holds — for now."
		toast.call("show", {"title": line, "body": "", "sound": "chime"})


func _on_save_failed(reason: String) -> void:
	if _warning_layer != null:
		_warning_layer.visible = true
		if _warning_reason != null:
			_warning_reason.text = reason if reason != "" else "The ink refused the page."
	var toast := get_node_or_null("/root/Toast")
	if toast != null and toast.has_method("show"):
		(
			toast
			. call(
				"show",
				{
					"title": WARNING_TITLE,
					"body": "Your progress may not persist. %s" % reason,
					"sound": "chime",
				}
			)
		)


# === UI ======================================================================================= #


## The persistent failure banner: a slim themed strip pinned top-center, above gameplay (layer
## 100) but below the toast stack (128). Built once, hidden until a save fails.
func _build_warning_banner() -> void:
	if _warning_layer != null:
		return
	_warning_layer = CanvasLayer.new()
	_warning_layer.name = "SaveWarningLayer"
	_warning_layer.layer = 100
	_warning_layer.visible = false
	add_child(_warning_layer)

	var panel := PanelContainer.new()
	panel.name = "SaveWarningPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.05, 0.06, 0.94)
	style.border_color = GrimoirePalette.DANGER
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.position.y = 8
	_warning_layer.add_child(panel)

	var column := VBoxContainer.new()
	panel.add_child(column)
	var title := Label.new()
	title.name = "SaveWarningTitle"
	title.text = WARNING_TITLE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", GrimoirePalette.DANGER)
	column.add_child(title)
	_warning_reason = Label.new()
	_warning_reason.name = "SaveWarningReason"
	_warning_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warning_reason.theme_type_variation = "MutedLabel"
	column.add_child(_warning_reason)


func _disconnect_game() -> void:
	if _game == null:
		return
	if (
		_game.has_signal("save_succeeded")
		and _game.is_connected("save_succeeded", _on_save_succeeded)
	):
		_game.disconnect("save_succeeded", _on_save_succeeded)
	if _game.has_signal("save_failed") and _game.is_connected("save_failed", _on_save_failed):
		_game.disconnect("save_failed", _on_save_failed)
