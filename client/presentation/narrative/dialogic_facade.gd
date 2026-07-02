class_name DialogicFacade
extends RefCounted
## Thin facade over the vendored **Dialogic 2** addon (ADR-017). This is the ONLY
## place that touches the `Dialogic` autoload directly. In our narrative split,
## Dialogic *RENDERS* — VN scenes, portraits, the absurdist / 4th-wall beats — while
## Ink *DECIDES* the branch and QuestService owns the state. So this facade is
## presentation-only: it plays a timeline that Ink chose, and tells the caller when
## the scene finishes. It never reads or writes run state.
##
## W16a — CHOICES: Dialogic 2 parses `- choice` lines natively and renders them through
## the style's choice layer; the facade never intercepts that UI. A branch reports back
## through the timeline's own `[signal arg="choice:<tag>"]` event (Dialogic.signal_event),
## which this facade re-emits as `choice_made(scene_id, branch_tag)` — so QuestService
## wiring (the overworld screen) can advance/branch a quest step off an authored choice.
##
## Headless note: Dialogic warns that on-screen playback is UI-driven and does not run
## headless. `play_timeline()` therefore guards on a display server being present, so
## the same call is a no-op (but still emits `scene_finished`) under `--headless`,
## keeping the sample vertical scriptable in CI. A choice timeline passes its canon
## `headless_branch` the same way: the branch resolves instantly (choice_made fires
## before scene_finished), so quests stay completable in tests/CI.

signal scene_finished(timeline_id: String)
signal choice_made(scene_id: String, branch_tag: String)

## Timeline signal-event convention for choice branches: `[signal arg="choice:<tag>"]`.
const CHOICE_PREFIX := "choice:"

var _active_timeline: String = ""
var _connected: bool = false


## Renders an Ink-chosen line/scene via a Dialogic timeline (by id from the project's
## `[dialogic] dtl_directory`, or a res:// path / DialogicTimeline). Returns true if
## playback actually started on screen; false (with `scene_finished` still emitted) when
## running headless so callers can drive the flow either way. `headless_branch` names the
## choice branch that resolves instantly when there is no UI to ask (the canon branch).
func play_timeline(timeline: Variant, headless_branch: String = "") -> bool:
	_active_timeline = str(timeline)
	if not _has_display():
		# Headless / no UI: nothing to render. Resolve immediately so the vertical
		# slice (Ink -> Dialogic -> Quest) still completes in tests/CI.
		if headless_branch != "":
			resolve_choice(headless_branch)
		scene_finished.emit(_active_timeline)
		return false
	_ensure_connected()
	Dialogic.start(timeline)
	return true


## Resolve a choice branch for the active scene. Called by the Dialogic signal-event
## pass-through, by the headless default path, and directly by tests.
func resolve_choice(branch_tag: String) -> void:
	if branch_tag != "":
		choice_made.emit(_active_timeline, branch_tag)


## True if the Dialogic autoload is available (smoke check for the bridge).
func is_available() -> bool:
	return Engine.has_singleton("Dialogic") or _autoload_present()


func active_timeline() -> String:
	return _active_timeline


func _ensure_connected() -> void:
	if _connected:
		return
	if not _autoload_present():
		return
	if not Dialogic.timeline_ended.is_connected(_on_timeline_ended):
		Dialogic.timeline_ended.connect(_on_timeline_ended)
	# Choice pass-through: authored branches announce themselves with a Signal event
	# ("choice:<tag>"); everything else on signal_event is ignored here.
	if not Dialogic.signal_event.is_connected(_on_dialogic_signal):
		Dialogic.signal_event.connect(_on_dialogic_signal)
	_connected = true


func _on_timeline_ended() -> void:
	scene_finished.emit(_active_timeline)


func _on_dialogic_signal(argument: Variant) -> void:
	if argument is String and str(argument).begins_with(CHOICE_PREFIX):
		resolve_choice(str(argument).trim_prefix(CHOICE_PREFIX))


func _autoload_present() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	return tree != null and tree.root.has_node("Dialogic")


func _has_display() -> bool:
	return DisplayServer.get_name() != "headless"
