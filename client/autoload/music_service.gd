extends Node
## MusicService autoload (WAVE-SND) — crossfading beds on the "Music" bus.
##
## APPLICATION/autoload layer. Two AudioStreamPlayers crossfade between looping ambience
## beds; a scene-aware auto-bed (cheap current_scene poll on SceneTree.tree_changed) maps
## main menu -> menu_bed, overworld -> ambience_marsh, battle -> battle_drone, so the game
## has ambience with ZERO screen edits. Screens (or later waves) may still call
## `play_bed()` directly for beats the scene map can't know about. Headless-safe:
## `play_bed()` tracks the current bed name for tests without touching the audio device.

## Bus/headless/volume helpers live on SfxService (single audio authority for bus setup).
const Sfx := preload("res://autoload/sfx_service.gd")

const BED_PATHS := {
	"menu_bed": "res://assets/audio/ambience/menu_bed_loop.mp3",
	"ambience_marsh": "res://assets/audio/ambience/ambience_marsh_loop.mp3",
	"battle_drone": "res://assets/audio/ambience/battle_drone_loop.mp3",
}
const DEFAULT_FADE := 1.5
const FADE_OUT_DB := -60.0

## Wave 10 (the W14 adaptive-audio hook): the battle bed's INTENSITY layer — a second, detuned
## copy of the battle drone whose gain swells with the entropy crescendo (cheap thickening; no
## extra asset). The cap keeps it a bed layer, never a lead.
const INTENSITY_MAX_DB := -8.0
const INTENSITY_PITCH := 1.06

var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _current_bed := ""
var _fade_tween: Tween
var _last_scene: Node = null
var _intensity := 0.0
var _intensity_player: AudioStreamPlayer = null
var _scene_tree: SceneTree = null
var _exiting := false


func _ready() -> void:
	Sfx.ensure_buses()
	if Sfx.is_headless():
		return
	for _i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = "Music"
		add_child(player)
		_players.append(player)
	# Scene-aware auto-bed: tree_changed fires often, but the handler is two compares
	# unless the current scene actually changed.
	_scene_tree = get_tree()
	if _scene_tree != null and not _scene_tree.tree_changed.is_connected(_on_tree_changed):
		_scene_tree.tree_changed.connect(_on_tree_changed)


func _exit_tree() -> void:
	# SceneTree can emit tree_changed while this autoload itself is being detached. Disconnect
	# before child teardown so the callback never calls get_tree() after leaving the tree.
	_exiting = true
	if _scene_tree != null and _scene_tree.tree_changed.is_connected(_on_tree_changed):
		_scene_tree.tree_changed.disconnect(_on_tree_changed)
	_scene_tree = null


## The bed the service currently considers active (tracked even headless, for tests).
func current_bed() -> String:
	return _current_bed


## Normalized battle intensity (0..1) — the battle screen feeds the entropy crescendo here
## each round. A curved gain ramp (x^1.5, perceptual) swells the detuned second drone layer
## under the active battle bed; 0 silences it; a non-battle bed shelves it entirely.
## Headless: the value is tracked for tests, no device is touched.
func set_intensity(t: float) -> void:
	_intensity = clampf(t, 0.0, 1.0)
	if Sfx.is_headless() or _players.is_empty():
		return
	if _current_bed != "battle_drone" or _intensity <= 0.0:
		if _intensity_player != null and _intensity_player.playing:
			_intensity_player.stop()
		return
	_ensure_intensity_layer()
	if _intensity_player.stream == null:
		return
	if not _intensity_player.playing:
		_intensity_player.play()
	_intensity_player.volume_db = lerpf(FADE_OUT_DB, INTENSITY_MAX_DB, pow(_intensity, 1.5))


## The last normalized intensity fed in (tracked headless — the test surface).
func intensity() -> float:
	return _intensity


## Crossfade to a named bed. Re-requesting the current bed is a no-op (never restarts).
func play_bed(bed_id: String, fade := DEFAULT_FADE) -> void:
	if bed_id == _current_bed:
		return
	_current_bed = bed_id
	# Leaving the battle bed shelves the intensity layer (the swell belongs to combat only).
	if bed_id != "battle_drone" and _intensity_player != null and _intensity_player.playing:
		_intensity_player.stop()
	if Sfx.is_headless() or _players.is_empty():
		return
	var stream := _load_bed(bed_id)
	if stream == null:
		return
	var fading_out := _players[_active]
	_active = (_active + 1) % _players.size()
	var fading_in := _players[_active]
	fading_in.stream = stream
	fading_in.volume_db = FADE_OUT_DB
	fading_in.play()
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.set_parallel(true)
	_fade_tween.tween_property(fading_in, "volume_db", 0.0, fade)
	if fading_out.playing:
		_fade_tween.tween_property(fading_out, "volume_db", FADE_OUT_DB, fade)
		_fade_tween.chain().tween_callback(fading_out.stop)


## Map a scene path (or node name) onto a bed id; "" means "leave the music alone".
static func bed_for_scene_path(path: String) -> String:
	var p := path.to_lower()
	if p.contains("battle"):
		return "battle_drone"
	if p.contains("overworld") or p.contains("camp"):
		return "ambience_marsh"
	if p.contains("main_menu") or p.contains("options"):
		return "menu_bed"
	return ""


## Build the detuned intensity layer lazily (windowed play only, first swell).
func _ensure_intensity_layer() -> void:
	if _intensity_player != null:
		return
	_intensity_player = AudioStreamPlayer.new()
	_intensity_player.bus = "Music"
	_intensity_player.pitch_scale = INTENSITY_PITCH
	_intensity_player.volume_db = FADE_OUT_DB
	add_child(_intensity_player)
	_intensity_player.stream = _load_bed("battle_drone")


func _load_bed(bed_id: String) -> AudioStream:
	var path: String = BED_PATHS.get(bed_id, "")
	if path == "" or not ResourceLoader.exists(path):
		push_warning("MusicService: unknown or missing bed '%s'" % bed_id)
		return null
	var stream: AudioStream = load(path)
	if stream is AudioStreamWAV:
		_make_looping(stream as AudioStreamWAV)
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	return stream


## Force forward-looping on imported WAV beds (the generated loops are crossfade-seamless;
## the import default is LOOP_DISABLED).
static func _make_looping(wav: AudioStreamWAV) -> void:
	if wav.loop_mode != AudioStreamWAV.LOOP_DISABLED:
		return
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = _frame_count(wav)


## Total frames, format-agnostic (works for PCM and QOA-compressed imports alike).
static func _frame_count(wav: AudioStreamWAV) -> int:
	return int(round(wav.get_length() * wav.mix_rate))


func _on_tree_changed() -> void:
	if _exiting or not is_inside_tree():
		return
	var tree := _scene_tree
	if tree == null:
		return
	var scene := tree.current_scene
	if scene == null or scene == _last_scene:
		return
	_last_scene = scene
	var source := scene.scene_file_path
	if source == "":
		source = String(scene.name)
	var bed := bed_for_scene_path(source)
	if bed != "":
		play_bed(bed)
