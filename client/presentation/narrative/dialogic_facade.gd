class_name DialogicFacade
extends RefCounted
## Thin facade over the vendored **Dialogic 2** addon (ADR-017). This is the ONLY
## place that touches the `Dialogic` autoload directly. In our narrative split,
## Dialogic *RENDERS* — VN scenes, portraits, the absurdist / 4th-wall beats — while
## Ink *DECIDES* the branch and QuestService owns the state. So this facade is
## presentation-only: it plays a timeline that Ink chose, and tells the caller when
## the scene finishes. It never reads or writes run state.
##
## Headless note: Dialogic warns that on-screen playback is UI-driven and does not run
## headless. `play_timeline()` therefore guards on a display server being present, so
## the same call is a no-op (but still emits `scene_finished`) under `--headless`,
## keeping the sample vertical scriptable in CI.

signal scene_finished(timeline_id: String)

var _active_timeline: String = ""
var _connected: bool = false


## Renders an Ink-chosen line/scene via a Dialogic timeline (by id from the project's
## `[dialogic] dtl_directory`, or a res:// path / DialogicTimeline). Returns true if
## playback actually started on screen; false (with `scene_finished` still emitted) when
## running headless so callers can drive the flow either way.
func play_timeline(timeline: Variant) -> bool:
	_active_timeline = str(timeline)
	if not _has_display():
		# Headless / no UI: nothing to render. Resolve immediately so the vertical
		# slice (Ink -> Dialogic -> Quest) still completes in tests/CI.
		scene_finished.emit(_active_timeline)
		return false
	_ensure_connected()
	Dialogic.start(timeline)
	return true


## True if the Dialogic autoload is available (smoke check for the bridge).
func is_available() -> bool:
	return Engine.has_singleton("Dialogic") or _autoload_present()


func active_timeline() -> String:
	return _active_timeline


func _ensure_connected() -> void:
	if _connected:
		return
	if _autoload_present() and not Dialogic.timeline_ended.is_connected(_on_timeline_ended):
		Dialogic.timeline_ended.connect(_on_timeline_ended)
		_connected = true


func _on_timeline_ended() -> void:
	scene_finished.emit(_active_timeline)


func _autoload_present() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	return tree != null and tree.root.has_node("Dialogic")


func _has_display() -> bool:
	return DisplayServer.get_name() != "headless"
