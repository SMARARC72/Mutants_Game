class_name CorruptionPip
extends Control
## The HUD corruption sigil pip (Wave 13) — a small inked ring in the controls-chip corner that
## THICKENS and CRACKS as run corruption crosses 25/50/75, so the meter is visible in the field
## without opening a sheet. Each first crossing toasts the matching authored VoiceBook line
## (corruption.first / corruption.gate / corruption.terminal); the last-toasted stage persists in
## run.flags so a reload never re-toasts. Colour comes from GrimoirePalette.corruption_color —
## the shape (ring weight + crack count) is the second, colourblind-safe cue. Headless-safe:
## _draw simply never runs without a display.

const THRESHOLDS := [25, 50, 75]
const SEEN_FLAG := "corruption_pip_stage"  # run.flags: last TOASTED stage (persisted)
const PIP_SIZE := 26.0
## Stage -> the authored VoiceBook threshold line ("" fallback handled at the call site).
const STAGE_VOICE_KEYS := ["corruption.first", "corruption.gate", "corruption.terminal"]

var _corruption := 0
var _stage := 0


func _init() -> void:
	name = "CorruptionPip"
	custom_minimum_size = Vector2(PIP_SIZE, PIP_SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## The crack stage for a corruption value: 0 below 25, then 1/2/3 at each crossed threshold.
static func stage_for(corruption: int) -> int:
	var stage := 0
	for threshold: int in THRESHOLDS:
		if corruption >= threshold:
			stage += 1
	return stage


## Refresh from the run: redraw at the current corruption and, on a NEWLY crossed threshold,
## show the authored VoiceBook toast exactly once (stage persisted in run.flags). Returns the
## current stage (tests). Null-safe without a run.
func refresh(run_ctx: RunContext) -> int:
	_corruption = run_ctx.corruption if run_ctx != null else 0
	_stage = stage_for(_corruption)
	tooltip_text = VoiceBook.pick("ui.tooltip.corruption")
	queue_redraw()
	if run_ctx != null:
		var seen := int(run_ctx.flags.get(SEEN_FLAG, 0))
		if _stage > seen:
			run_ctx.flags[SEEN_FLAG] = _stage
			_toast_threshold(_stage)
	return _stage


## The current crack stage (tests + the HUD).
func stage() -> int:
	return _stage


## The authored line for a crossed threshold stage (1..3), falling back to the generic
## corruption toast bank when a key is missing (VoiceBook contract: callers keep a fallback).
static func threshold_line(stage_index: int) -> String:
	if stage_index < 1 or stage_index > STAGE_VOICE_KEYS.size():
		return ""
	var line := VoiceBook.pick(str(STAGE_VOICE_KEYS[stage_index - 1]))
	if line == "":
		line = VoiceBook.pick("toast.corruption", stage_index)
	return line


func _toast_threshold(stage_index: int) -> void:
	var line := threshold_line(stage_index)
	if line == "":
		return
	var loop := Engine.get_main_loop()
	if not (loop is SceneTree):
		return
	var toast := (loop as SceneTree).root.get_node_or_null("Toast")
	if toast != null and toast.has_method("show"):
		toast.call("show", {"title": "Corruption", "body": line, "sound": "hum"})


func _draw() -> void:
	var t := clampf(_corruption / 100.0, 0.0, 1.0)
	var col := GrimoirePalette.corruption_color(t).lightened(0.3)
	var centre := size * 0.5
	var radius := minf(size.x, size.y) * 0.34
	# The sigil ring thickens with each crossed threshold (25/50/75).
	draw_arc(centre, radius, 0.0, TAU, 32, col, 1.0 + _stage * 1.1, true)
	# The rot core swells with the raw meter.
	draw_circle(centre, radius * (0.18 + t * 0.4), Color(col, 0.55 + t * 0.35))
	# Cracks: one radial fracture per crossed threshold, at stable hashed angles.
	for i in _stage:
		var angle := TAU * (0.13 + 0.37 * float(i))
		var dir := Vector2(cos(angle), sin(angle))
		draw_line(
			centre + dir * radius * 0.55, centre + dir * radius * 1.35, col, 1.4 + 0.4 * i, true
		)
