class_name AtmosphereLayer
extends CanvasLayer
## AtmosphereLayer (Wave 13 "Atmosphere, Thin Places & The Follower") — the game's ONE fullscreen
## shader surface (master-plan tension 9): exactly TWO passes, a combined grimoire grade+vignette
## ColorRect and a drifting low-alpha fog ColorRect, both owned here. It renders above the world
## (layer 1) and BELOW the HUD (layer 2+) — never over readable text — and it also DRIVES the
## screen's world CanvasModulate (attach_world_tint), replacing the old raw-tint setup.
##
## Screens request moods via set_mood(dread, entropy, corruption, force_climate); they never add
## their own fullscreen shaders (Dracula veto). Corruption lerps the whole grade toward
## GrimoirePalette.corruption_color(t) — a corruption-0 vs corruption-60 run reads as two worlds.
## All strengths are clamped to readability floors (HAWKING veto); the fog drift freezes under
## reduce_motion; everything builds headless (shaders compile, nothing renders).

const GRADE_SHADER := preload("res://presentation/ui/atmosphere/grimoire_grade.gdshader")
const FOG_SHADER := preload("res://presentation/ui/atmosphere/veil_fog.gdshader")

## Per-force ambient world grades — gentle near-white MODULATES (hue data like OverworldTileSet's
## palette tints, not UI accents; semantic accents stay in GrimoirePalette). Eros keeps the exact
## Wave-12 verdant marsh grade so the shipped look is unchanged at mood zero.
const CLIMATE_GRADES := {
	"Eros": Color(0.75, 0.81, 0.74),
	"Gaia": Color(0.82, 0.78, 0.68),
	"Ouranos": Color(0.72, 0.78, 0.86),
	"Cosmos": Color(0.82, 0.8, 0.74),
	"Chaos": Color(0.8, 0.7, 0.7),
	"Thanatos": Color(0.72, 0.7, 0.78),
}
const DEFAULT_GRADE := Color(0.78, 0.79, 0.76)

## Readability ceilings (never past readable contrast) — the strongest any dial may push a pass.
const MAX_VIGNETTE := 0.55
const MAX_DESATURATE := 0.35
const MAX_FOG := 0.16
const MIN_TINT_CHANNEL := 0.4  # the world modulate never drops below this per channel
const CORRUPTION_GRADE_PULL := 0.5  # how far corruption drags the world modulate at t = 1
const TINT_EASE_TIME := 0.6  # seconds the world tint eases between moods (instant headless)

var _grade_rect: ColorRect = null
var _fog_rect: ColorRect = null
var _world_tint: CanvasModulate = null
var _tint_tween: Tween = null
var _mood := {"dread": 0.0, "entropy": 0.0, "corruption": 0.0, "force_climate": ""}


func _init() -> void:
	name = "AtmosphereLayer"
	layer = 1  # above the world canvas (0), below the HUD CanvasLayer (2+) — never over the HUD


func _ready() -> void:
	_build_passes()
	_apply()


## Point the layer at the screen's world CanvasModulate (it must live in the WORLD canvas, not in
## this CanvasLayer, so the grade dims the map but never the HUD). The layer drives its colour.
func attach_world_tint(tint: CanvasModulate) -> void:
	_world_tint = tint
	_apply()


## THE mood API (tension 9): `dread` deepens vignette + desaturation, `entropy` stirs the fog,
## `corruption` (0..100, the run meter) lerps the whole grade toward corruption_color(t),
## `force_climate` picks the region's ambient grade. Values are clamped to readability ceilings.
func set_mood(dread: float, entropy: float, corruption: float, force_climate: String) -> void:
	_mood = {
		"dread": clampf(dread, 0.0, 1.0),
		"entropy": clampf(entropy, 0.0, 1.0),
		"corruption": clampf(corruption, 0.0, 100.0),
		"force_climate": force_climate,
	}
	_apply()


## The last mood set (copy) — for tests + observers.
func mood() -> Dictionary:
	return _mood.duplicate()


## How many fullscreen passes the layer runs (tests pin this to exactly 2 — tension 9).
func pass_count() -> int:
	var count := 0
	for child in get_children():
		if child is ColorRect:
			count += 1
	return count


## Build the two pass rects once (idempotent). Order matters: grade first (reads the screen),
## fog second (blends over the graded frame).
func _build_passes() -> void:
	if _grade_rect != null and is_instance_valid(_grade_rect):
		return
	_grade_rect = _fullscreen_rect("GradePass", GRADE_SHADER)
	_fog_rect = _fullscreen_rect("FogPass", FOG_SHADER)
	var fog_mat := _fog_rect.material as ShaderMaterial
	fog_mat.set_shader_parameter("noise_tex", _make_fog_noise())
	add_child(_grade_rect)
	add_child(_fog_rect)


func _fullscreen_rect(rect_name: String, shader: Shader) -> ColorRect:
	var rect := ColorRect.new()
	rect.name = rect_name
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = shader
	rect.material = mat
	return rect


## A seamless engine-built noise tile for the fog pass (fixed seed: deterministic presentation,
## LOCAL — never the canonical streams). No binary asset, headless-safe.
func _make_fog_noise() -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = 1313
	noise.noise_type = FastNoiseLite.TYPE_VALUE_CUBIC
	noise.frequency = 0.02
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.noise = noise
	return tex


## Push the current mood into the two passes + the world modulate.
func _apply() -> void:
	if _grade_rect == null or not is_instance_valid(_grade_rect):
		return
	var dread := float(_mood["dread"])
	var entropy := float(_mood["entropy"])
	var t := clampf(float(_mood["corruption"]) / 100.0, 0.0, 1.0)
	var rot := GrimoirePalette.corruption_color(t)
	# Pass 1 — grade + vignette: corruption drags the multiplied grade hue; dread desaturates and
	# tightens the vignette; the vignette itself bruises toward the rot colour.
	var grade := _grade_rect.material as ShaderMaterial
	var grade_tint := Color.WHITE.lerp(rot, t * 0.35)
	grade.set_shader_parameter("grade_tint", Vector3(grade_tint.r, grade_tint.g, grade_tint.b))
	grade.set_shader_parameter("grade_mix", 0.3 + t * 0.25)
	grade.set_shader_parameter("desaturate", minf(dread * MAX_DESATURATE, MAX_DESATURATE))
	grade.set_shader_parameter("vignette_strength", minf(0.28 + dread * 0.35, MAX_VIGNETTE))
	grade.set_shader_parameter("vignette_reach", 0.55 - dread * 0.08)
	var ink := GrimoirePalette.INK
	var vig_tint := ink.lerp(rot, t * 0.6)
	grade.set_shader_parameter("vignette_tint", Vector3(vig_tint.r, vig_tint.g, vig_tint.b))
	# Pass 2 — fog: entropy stirs the banks, corruption stains them; reduce_motion freezes drift.
	var fog := _fog_rect.material as ShaderMaterial
	var base: Color = CLIMATE_GRADES.get(
		str(_mood["force_climate"]).get_slice("+", 0), DEFAULT_GRADE
	)
	var fog_col := base.lightened(0.12).lerp(rot, t * 0.5)
	fog.set_shader_parameter("fog_color", Vector3(fog_col.r, fog_col.g, fog_col.b))
	fog.set_shader_parameter("density", minf(0.07 + entropy * 0.05 + t * 0.04, MAX_FOG))
	fog.set_shader_parameter("time_scale", 0.0 if _reduce_motion() else 0.6 + entropy * 0.8)
	_apply_world_tint(base, rot, t)


## Ease the world CanvasModulate toward the moody grade (instant headless / reduce_motion).
func _apply_world_tint(base: Color, rot: Color, t: float) -> void:
	if _world_tint == null or not is_instance_valid(_world_tint):
		return
	var target := base.lerp(rot, t * CORRUPTION_GRADE_PULL)
	target.r = maxf(target.r, MIN_TINT_CHANNEL)
	target.g = maxf(target.g, MIN_TINT_CHANNEL)
	target.b = maxf(target.b, MIN_TINT_CHANNEL)
	if _tint_tween != null and _tint_tween.is_valid():
		_tint_tween.kill()
	var animate := (
		is_inside_tree() and DisplayServer.get_name() != "headless" and not _reduce_motion()
	)
	if not animate:
		_world_tint.color = target
		return
	_tint_tween = create_tween()
	_tint_tween.tween_property(_world_tint, "color", target, TINT_EASE_TIME)


## The Settings accessibility.reduce_motion toggle (safe without the autoload — kept local,
## the LivingPlate pattern, so ui/atmosphere never imports overworld modules).
static func _reduce_motion() -> bool:
	var loop := Engine.get_main_loop()
	if not (loop is SceneTree):
		return false
	var settings := (loop as SceneTree).root.get_node_or_null("Settings")
	if settings == null:
		return false
	return bool(settings.call("get_value", "accessibility", "reduce_motion", false))
