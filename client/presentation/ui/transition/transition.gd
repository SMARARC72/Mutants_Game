extends Node
## Transition facade autoload (D8) — EasyTransition wrapped behind our `Transition.*`.
##
## PRESENTATION layer. Owns the ritual overworld<->battle transition + a threaded-load cover so
## loads feel "ritual but fast" (design §4), replacing flat loading screens (D8 acceptance). The
## app awaits these; it never sees an addon type — if a third-party transition addon is dropped
## in, only this file changes.
##
## The cover is a full-screen `CanvasLayer` (above everything, below toasts) painted in the
## grimoire ink/brass; a sigil-bloom tween sells the ritual. `change_scene_ritual()` runs a
## THREADED load under the cover (`ResourceLoader.load_threaded_*`) and only swaps when ready,
## so the player sees ceremony, never a hitch.

const Palette := preload("res://presentation/ui/theme/grimoire_palette.gd")

const COVER_IN := 0.4
const COVER_OUT := 0.45
const MIN_COVER_TIME := 0.25  # keep the ritual on-screen at least this long even if load is instant

var _layer: CanvasLayer
var _cover: ColorRect
var _sigil: Label
var _busy := false


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 100  # above gameplay, below the Toast layer (128)
	_layer.name = "TransitionLayer"
	add_child(_layer)

	_cover = ColorRect.new()
	_cover.color = Palette.INK
	_cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cover.mouse_filter = Control.MOUSE_FILTER_STOP
	_cover.modulate.a = 0.0
	_cover.visible = false
	_layer.add_child(_cover)

	# The ritual sigil-mark at the centre of the cover (brass on ink — design §1 motif).
	_sigil = Label.new()
	_sigil.text = "✵"  # an eight-pointed sigil glyph
	_sigil.add_theme_font_size_override("font_size", 96)
	_sigil.add_theme_color_override("font_color", Palette.BRASS_BRIGHT)
	_sigil.set_anchors_preset(Control.PRESET_CENTER)
	_sigil.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sigil.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cover.add_child(_sigil)


## True while a transition is mid-flight (callers can guard double-triggers).
func is_busy() -> bool:
	return _busy


## Lower the ritual cover (fade the ink in + bloom the sigil). `await` it.
func cover() -> void:
	_busy = true
	_cover.visible = true
	_cover.modulate.a = 0.0
	_sigil.scale = Vector2(0.6, 0.6)
	_sigil.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_cover, "modulate:a", 1.0, COVER_IN)
	tween.tween_property(_sigil, "modulate:a", 1.0, COVER_IN)
	tween.tween_property(_sigil, "scale", Vector2.ONE, COVER_IN).set_trans(Tween.TRANS_BACK)
	await tween.finished


## Raise the cover (fade out). `await` it.
func reveal() -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_cover, "modulate:a", 0.0, COVER_OUT)
	tween.tween_property(_sigil, "scale", Vector2(1.3, 1.3), COVER_OUT)
	await tween.finished
	_cover.visible = false
	_busy = false


## The overworld<->battle ritual transition wrapping an arbitrary action. Covers, runs `work`
## (a Callable that may `await`), keeps the ritual on-screen a beat, then reveals (D8).
func ritual(work: Callable = Callable()) -> void:
	await cover()
	var start := Time.get_ticks_msec()
	if work.is_valid():
		# In Godot 4 awaiting a non-coroutine value is a harmless no-op, so this safely covers
		# both a synchronous Callable and one that itself awaits.
		await work.call()
	# Hold the ritual at least MIN_COVER_TIME so instant work still feels ceremonial.
	var elapsed := (Time.get_ticks_msec() - start) / 1000.0
	if elapsed < MIN_COVER_TIME:
		await get_tree().create_timer(MIN_COVER_TIME - elapsed).timeout
	await reveal()


## Threaded-load cover (D8): cover, load `scene_path` off-thread, swap the current scene when
## ready, then reveal. No visible pop/hitch. Returns true on success.
func change_scene_ritual(scene_path: String) -> bool:
	if not ResourceLoader.exists(scene_path):
		push_error("Transition.change_scene_ritual: missing scene '%s'" % scene_path)
		return false
	var ok := true
	await ritual(func() -> void: ok = await _threaded_load_and_swap(scene_path))
	return ok


func _threaded_load_and_swap(scene_path: String) -> bool:
	var err := ResourceLoader.load_threaded_request(scene_path)
	if err != OK:
		return false
	# Poll the threaded load while the cover holds (the "ritual but fast" feel).
	while true:
		var progress := []
		var status := ResourceLoader.load_threaded_get_status(scene_path, progress)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			break
		if (
			status == ResourceLoader.THREAD_LOAD_FAILED
			or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE
		):
			return false
		await get_tree().process_frame
	var packed: PackedScene = ResourceLoader.load_threaded_get(scene_path)
	if packed == null:
		return false
	var tree := get_tree()
	tree.change_scene_to_packed(packed)
	return true
