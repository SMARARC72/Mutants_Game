extends Node
## SfxService autoload (WAVE-SND) — the game's one-shot sound authority.
##
## APPLICATION/autoload layer. Owns the "Music"/"SFX" AudioServer buses (created in code, no
## .tres bus layout), a small pool of AudioStreamPlayers on the SFX bus, and the global
## BaseButton click hook (SceneTree.node_added), so every themed button clicks with ZERO
## per-screen edits. Volume settings (Settings `audio` section, ADR-012 JSON) are applied to
## the buses on startup and live on every change. Headless-safe: `play()` records
## `last_played` for tests but never touches the audio device. Pitch jitter uses a LOCAL
## RandomNumberGenerator — never the canonical PCG32 streams (determinism inviolable).

const AUDIO_DIR := "res://assets/audio/"
const POOL_SIZE := 8
## linear_to_db(0) is -inf; anything at/below this floor is treated as muted instead.
const MUTE_FLOOR := 0.0001
const CLICK_META := "_sfx_click_wired"
const FOOTSTEP_VARIANTS := 4

const STREAM_PATHS := {
	"ui_click": AUDIO_DIR + "ui/ui_click.wav",
	"ui_confirm": AUDIO_DIR + "ui/ui_confirm.wav",
	"footstep_1": AUDIO_DIR + "sfx/footstep_1.wav",
	"footstep_2": AUDIO_DIR + "sfx/footstep_2.wav",
	"footstep_3": AUDIO_DIR + "sfx/footstep_3.wav",
	"footstep_4": AUDIO_DIR + "sfx/footstep_4.wav",
	"hit_crunch": AUDIO_DIR + "sfx/hit_crunch.wav",
	"death_knell": AUDIO_DIR + "sfx/death_knell.wav",
	"capture_sting": AUDIO_DIR + "sfx/capture_sting.wav",
	"boss_swell": AUDIO_DIR + "sfx/boss_swell.wav",
	"veil_whisper": AUDIO_DIR + "sfx/veil_whisper.wav",
}

## Last sound id requested through play() — recorded even headless, so tests (and beat-queue
## suites later) can assert the audio hook fired without a device.
var last_played := ""

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_cursor := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	ensure_buses()
	apply_volumes()
	var settings := get_node_or_null("/root/Settings")
	if settings != null and settings.has_signal("changed"):
		settings.connect("changed", _on_setting_changed)
	if is_headless():
		return
	_load_streams()
	for _i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_pool.append(player)
	# Every BaseButton that ever enters the tree gets a click — zero per-screen edits.
	get_tree().node_added.connect(_on_node_added)


## True when running without a display (CI / GdUnit headless runs): all playback no-ops.
static func is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


## Idempotently create the "Music" and "SFX" buses routed to Master (code, not a .tres layout).
static func ensure_buses() -> void:
	for bus_name: String in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")


## Map a 0..1 settings value onto a bus: linear -> dB, hard mute at zero.
static func apply_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_mute(idx, linear <= MUTE_FLOOR)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, MUTE_FLOOR)))


## Read the persisted Settings audio section and apply it to the live buses.
## Safe with no Settings autoload (falls back to the documented defaults).
func apply_volumes() -> void:
	var master := 1.0
	var music := 0.8
	var sfx := 0.9
	var muted := false
	var settings := get_node_or_null("/root/Settings")
	if settings != null:
		master = float(settings.call("get_value", "audio", "master_volume", master))
		music = float(settings.call("get_value", "audio", "music_volume", music))
		sfx = float(settings.call("get_value", "audio", "sfx_volume", sfx))
		muted = bool(settings.call("get_value", "audio", "muted", false))
	apply_bus_volume("Master", 0.0 if muted else master)
	apply_bus_volume("Music", music)
	apply_bus_volume("SFX", sfx)


## Play a one-shot by id ("ui_click", "hit_crunch", ...). `pitch_jitter` is a +/- fraction
## applied to pitch_scale via the LOCAL rng. Headless: records last_played and returns.
func play(sound_id: String, pitch_jitter := 0.0) -> void:
	last_played = sound_id
	if is_headless():
		return
	var stream: AudioStream = _streams.get(sound_id)
	if stream == null:
		push_warning("SfxService.play: unknown sound '%s'" % sound_id)
		return
	var player := _next_player()
	if player == null:
		return
	player.stream = stream
	player.pitch_scale = 1.0
	if pitch_jitter > 0.0:
		player.pitch_scale = 1.0 + _rng.randf_range(-pitch_jitter, pitch_jitter)
	player.play()


## Convenience for the overworld step tween (W6 hook): random footstep variant + jitter.
func play_footstep() -> void:
	play("footstep_%d" % _rng.randi_range(1, FOOTSTEP_VARIANTS), 0.08)


func _load_streams() -> void:
	for sound_id: String in STREAM_PATHS:
		var path: String = STREAM_PATHS[sound_id]
		if ResourceLoader.exists(path):
			_streams[sound_id] = load(path)
		else:
			push_warning("SfxService: missing audio asset %s" % path)


## Round-robin pool pick, preferring an idle player so long tails aren't cut mid-ring.
func _next_player() -> AudioStreamPlayer:
	if _pool.is_empty():
		return null
	for offset in _pool.size():
		var candidate := _pool[(_pool_cursor + offset) % _pool.size()]
		if not candidate.playing:
			_pool_cursor = (_pool_cursor + offset + 1) % _pool.size()
			return candidate
	_pool_cursor = (_pool_cursor + 1) % _pool.size()
	return _pool[_pool_cursor]


func _on_setting_changed(key: String, _value: Variant) -> void:
	if key.begins_with("audio/") or key == "all":
		apply_volumes()


## SceneTree-wide click hook: any BaseButton entering the tree gets exactly one pressed->click
## connection (meta flag dedupes across service instances and re-parenting).
func _on_node_added(node: Node) -> void:
	if not (node is BaseButton):
		return
	if node.has_meta(CLICK_META):
		return
	node.set_meta(CLICK_META, true)
	(node as BaseButton).pressed.connect(_on_any_button_pressed)


func _on_any_button_pressed() -> void:
	play("ui_click", 0.04)
