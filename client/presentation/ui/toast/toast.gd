extends Node
## Toast facade autoload (D7) — NotificationEngine wrapped behind our `Toast.show(...)`.
##
## PRESENTATION layer. The single entry point for in-game notifications:
##   Toast.show({title, body, icon, sound})  — or  Toast.event(ToastMicrocopy.CAUGHT).
## Toasts STACK and SURVIVE scene changes (D7 acceptance) because this autoload owns a
## high-layer `CanvasLayer` that is never freed on scene transition. Each toast is rendered with
## the grimoire Theme (D6) and plays a sound (D6/D7). Funny-grim copy comes from `ToastMicrocopy`.
##
## "NotificationEngine" is wrapped here: the facade owns the queue/stack/animation so the app
## never sees an addon type. If a third-party notification addon is later dropped in, only this
## file changes — `Toast.show()` stays the contract.

const Microcopy := preload("res://presentation/ui/toast/toast_microcopy.gd")
const Palette := preload("res://presentation/ui/theme/grimoire_palette.gd")

const MAX_VISIBLE := 4
const TOAST_LIFETIME := 4.0
const FADE := 0.35
const TOAST_WIDTH := 420
const MARGIN := 24
const GAP := 10

var _layer: CanvasLayer
var _stack: VBoxContainer
var _audio: AudioStreamPlayer
var _sound_cache := {}


func _ready() -> void:
	# A CanvasLayer high above gameplay; persists across scene swaps (it lives under /root).
	_layer = CanvasLayer.new()
	_layer.layer = 128
	_layer.name = "ToastLayer"
	add_child(_layer)

	var anchor := Control.new()
	anchor.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.set_anchor_and_offset(SIDE_LEFT, 1.0, -TOAST_WIDTH - MARGIN)
	anchor.set_anchor_and_offset(SIDE_RIGHT, 1.0, -MARGIN)
	anchor.set_anchor_and_offset(SIDE_TOP, 0.0, MARGIN)
	anchor.set_anchor_and_offset(SIDE_BOTTOM, 1.0, -MARGIN)
	_layer.add_child(anchor)

	_stack = VBoxContainer.new()
	_stack.add_theme_constant_override("separation", GAP)
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack.set_anchors_preset(Control.PRESET_TOP_WIDE)
	anchor.add_child(_stack)

	_audio = AudioStreamPlayer.new()
	_audio.bus = "Master"
	add_child(_audio)


## Show a toast. `payload` keys: title, body, icon (res:// path or ""), sound (cue name).
func show(payload: Dictionary) -> void:
	var title: String = payload.get("title", "")
	var body: String = payload.get("body", "")
	var icon: String = payload.get("icon", "")
	var sound: String = payload.get("sound", "chime")
	_spawn(title, body, icon)
	_play(sound)


## Show a preset core-event toast with funny-grim copy (D7). e.g. event(ToastMicrocopy.CAUGHT).
func event(event_id: String) -> void:
	show(Microcopy.preset(event_id))


func _spawn(title: String, body: String, icon_path: String) -> void:
	# Enforce the stack cap (oldest off the top).
	while _stack.get_child_count() >= MAX_VISIBLE:
		var oldest := _stack.get_child(0)
		_stack.remove_child(oldest)
		oldest.queue_free()

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(TOAST_WIDTH, 0)
	_theme_panel(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	if icon_path != "" and ResourceLoader.exists(icon_path):
		var tex := TextureRect.new()
		tex.texture = load(icon_path)
		tex.custom_minimum_size = Vector2(40, 40)
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.modulate = Palette.BRASS_BRIGHT
		row.add_child(tex)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)

	if title != "":
		var title_label := Label.new()
		title_label.text = title
		title_label.theme_type_variation = "TitleLabel"
		title_label.add_theme_font_size_override("font_size", 20)
		title_label.add_theme_color_override("font_color", Palette.BRASS_BRIGHT)
		text.add_child(title_label)

	var body_label := Label.new()
	body_label.text = body
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.add_theme_color_override("font_color", Palette.TEXT_ON_INK)
	text.add_child(body_label)

	panel.modulate.a = 0.0
	_stack.add_child(panel)

	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, FADE)
	tween.tween_interval(TOAST_LIFETIME)
	tween.tween_property(panel, "modulate:a", 0.0, FADE)
	tween.tween_callback(func() -> void: _dismiss(panel))


func _dismiss(panel: Node) -> void:
	if is_instance_valid(panel) and panel.get_parent() == _stack:
		_stack.remove_child(panel)
		panel.queue_free()


## How many toasts are currently shown (for the stacking test).
func visible_count() -> int:
	return _stack.get_child_count() if _stack != null else 0


func _theme_panel(panel: PanelContainer) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.INK_PANEL
	sb.set_corner_radius_all(5)
	sb.set_border_width_all(2)
	sb.border_color = Palette.BRASS
	sb.set_content_margin_all(14)
	# A subtle shadow so toasts read above any background.
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 6
	panel.add_theme_stylebox_override("panel", sb)


# === sound (procedural so there is no missing-asset dependency; D7 "with a sound") ===
func _play(cue: String) -> void:
	if not _sound_cache.has(cue):
		_sound_cache[cue] = _make_tone(cue)
	_audio.stream = _sound_cache[cue]
	_audio.play()


## Build a short procedural tone per cue. Self-contained — keeps "fires with a sound" true
## without committing audio binaries. Swap for authored SFX under assets/audio/sfx/ when present.
func _make_tone(cue: String) -> AudioStreamWAV:
	var freq := 660.0
	match cue:
		"toll":
			freq = 220.0
		"hum":
			freq = 174.0
		"wet":
			freq = 330.0
		"swell":
			freq = 528.0
		"ink":
			freq = 440.0
		_:
			freq = 660.0

	var rate := 22050
	var duration := 0.18
	var sample_count := int(rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	for i in sample_count:
		var t := float(i) / rate
		var envelope := 1.0 - (float(i) / sample_count)  # quick decay
		var sample := sin(TAU * freq * t) * envelope * 0.4
		var value := int(clampf(sample, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, value)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = bytes
	return stream
