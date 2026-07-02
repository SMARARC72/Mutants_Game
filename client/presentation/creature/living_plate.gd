class_name LivingPlate
extends Control
## LivingPlate (Wave 9) — the ONE living creature stamp every screen composes: a centered
## Sprite2D showing an RGBA cutout that BREATHES (sine y-scale 1.00 -> 1.025, ~2.6s) and SWAYS
## (creature_sway.gdshader, 1-2px top-weighted shear) over a soft elliptical drop shadow, with a
## per-instance phase hashed from set_identity() so two roster members never move in lockstep.
##
## PRESENTATION layer, LIGHT by contract — this instantiates 6+ times per battle:
##   * one ShaderMaterial per instance over ONE shared Shader; a shared shadow gradient texture;
##   * HEADLESS / reduce_motion => fully static: _process is disabled and the sway amplitude is
##     zeroed, so the 369-case suite never runs per-frame work (the battle_beats pattern);
##   * material hooks (set_hit_flash / set_dissolve / set_outline) expose the flash/dissolve/
##     outline uniforms so the Wave 10 impact stack can drive a live plate without material swaps;
##   * the tint contract matches the old TextureRect stamps: set_tint() lands on the sprite's
##     self_modulate, composing with any damage-flash tween on the ROOT's modulate
##     (BattleCardKit.flash_portrait).
## All randomness here is a LOCAL string hash — never the canonical PCG32 streams.

const SWAY_SHADER := preload("res://presentation/creature/creature_sway.gdshader")

const BREATH_PERIOD := 2.6  # seconds per breath
const BREATH_AMOUNT := 0.025  # y-scale swell: 1.00 -> 1.025
const SWAY_AMPLITUDE := 1.6  # px at the crown (feet planted)
const SHADOW_ALPHA := 0.5
const SHADOW_WIDTH_FRAC := 0.62  # ellipse width as a fraction of the fitted plate width
const SHADOW_HEIGHT_FRAC := 0.16

## Shared radial gradient for every plate's drop shadow (built once, GPU-cheap, no set_pixel).
static var _shadow_gradient: GradientTexture2D = null

var _sprite: Sprite2D = null
var _shadow: Sprite2D = null
var _material: ShaderMaterial = null
var _phase := 0.0  # per-instance breath/sway offset (radians)
var _animate := false  # false headless / reduce_motion => zero per-frame work
var _time := 0.0
var _base_scale := 1.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = SWAY_SHADER
	_shadow = Sprite2D.new()
	_shadow.name = "Shadow"
	_shadow.texture = _shared_shadow_texture()
	_shadow.modulate = Color(0.0, 0.0, 0.0, SHADOW_ALPHA)
	add_child(_shadow)
	_sprite = Sprite2D.new()
	_sprite.name = "Plate"
	_sprite.centered = false
	_sprite.material = _material
	add_child(_sprite)
	resized.connect(_layout)


func _ready() -> void:
	refresh_motion()
	_layout()


## Re-evaluate headless/reduce_motion (checked on entry; screens rebuild on every visit, so a
## live settings change lands on the next build — the OverworldMotion contract).
func refresh_motion() -> void:
	_animate = DisplayServer.get_name() != "headless" and not _reduce_motion()
	set_process(_animate)
	_material.set_shader_parameter("sway_amplitude", SWAY_AMPLITUDE if _animate else 0.0)
	if not _animate and _sprite != null:
		_sprite.scale = Vector2(_base_scale, _base_scale)


## The plate's slot size (both minimum and immediate size, for non-container parents).
func set_plate_size(slot: Vector2) -> void:
	custom_minimum_size = slot
	size = slot
	_layout()


## Show `tex` (an RGBA cutout — SpeciesArt.plate / PortraitUtil.creature_plate), fitted to the
## slot with the feet on the slot's bottom edge.
func set_texture(tex: Texture2D) -> void:
	_sprite.texture = tex
	_layout()


## The current plate texture (test/read access, mirroring TextureRect.texture).
func texture() -> Texture2D:
	return _sprite.texture if _sprite != null else null


## Hash a LOCAL per-instance phase from the creature's identity so same-species neighbours
## breathe/sway out of step, but the SAME creature moves identically on every screen.
func set_identity(species_id: String, instance_tag: String) -> void:
	var h := absi((species_id + "|" + instance_tag).hash())
	_phase = TAU * float(h % 1024) / 1024.0
	_material.set_shader_parameter("sway_phase", _phase)


## The creature tint (hybrid corruption hue etc.). Lands on the SPRITE's self_modulate so it
## composes with damage-flash tweens on the root's modulate — the old TextureRect contract.
func set_tint(tint: Color) -> void:
	_sprite.self_modulate = tint


# === material hooks (Wave 10 drives these; safe no-ops visually until then) =================== #


## The plate's per-instance ShaderMaterial (flash/dissolve/outline uniforms live here).
func plate_material() -> ShaderMaterial:
	return _material


## hit_flash hook: 0 = untouched, 1 = fully `flash_color`.
func set_hit_flash(amount: float) -> void:
	_material.set_shader_parameter("flash_amount", clampf(amount, 0.0, 1.0))


## dissolve hook: 0 = whole, 1 = fully burned away.
func set_dissolve(progress: float) -> void:
	_material.set_shader_parameter("dissolve", clampf(progress, 0.0, 1.0))


## outline hook: width in texels (0 = off) + palette colour (defaults to lit brass).
func set_outline(width: float, color: Color = GrimoirePalette.BRASS_BRIGHT) -> void:
	_material.set_shader_parameter("outline_width", maxf(0.0, width))
	_material.set_shader_parameter("outline_color", color)


## True when the breath/sway loop is live (false headless / reduce_motion).
func is_animated() -> bool:
	return _animate


## The hashed per-instance phase (radians) — determinism hook for tests.
func phase() -> float:
	return _phase


# === internals ================================================================================= #


func _process(delta: float) -> void:
	_time += delta
	if _sprite == null:
		return
	var swell := 0.5 * (1.0 + sin(_time * TAU / BREATH_PERIOD + _phase))
	_sprite.scale.y = _base_scale * (1.0 + BREATH_AMOUNT * swell)


## Fit the sprite into the slot (keep aspect, feet on the bottom edge, origin at bottom-centre so
## the breath scale lifts the crown while the feet stay planted) and seat the shadow under them.
func _layout() -> void:
	if _sprite == null:
		return
	var slot := size
	if slot.x <= 0.0 or slot.y <= 0.0:
		slot = custom_minimum_size
	var tex := _sprite.texture
	if tex == null or slot.x <= 0.0 or slot.y <= 0.0:
		_shadow.visible = false
		return
	var tex_size := tex.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		_shadow.visible = false
		return
	_base_scale = minf(slot.x / tex_size.x, slot.y / tex_size.y)
	_sprite.offset = Vector2(-tex_size.x * 0.5, -tex_size.y)
	_sprite.position = Vector2(slot.x * 0.5, slot.y)
	_sprite.scale = Vector2(_base_scale, _base_scale)
	var fitted_w := tex_size.x * _base_scale
	_shadow.visible = true
	_shadow.position = Vector2(slot.x * 0.5, slot.y - 2.0)
	var shadow_size := _shadow.texture.get_size()
	if shadow_size.x > 0.0 and shadow_size.y > 0.0:
		_shadow.scale = Vector2(
			fitted_w * SHADOW_WIDTH_FRAC / shadow_size.x,
			fitted_w * SHADOW_HEIGHT_FRAC / shadow_size.y
		)


## The Settings accessibility.reduce_motion toggle (safe without the autoload — the
## OverworldMotion pattern, duplicated here to keep creature/ free of overworld imports).
static func _reduce_motion() -> bool:
	var loop := Engine.get_main_loop()
	if not (loop is SceneTree):
		return false
	var settings := (loop as SceneTree).root.get_node_or_null("Settings")
	if settings == null:
		return false
	return bool(settings.call("get_value", "accessibility", "reduce_motion", false))


static func _shared_shadow_texture() -> GradientTexture2D:
	if _shadow_gradient == null:
		var grad := Gradient.new()
		grad.set_color(0, Color(0, 0, 0, 1.0))
		grad.set_color(1, Color(0, 0, 0, 0.0))
		_shadow_gradient = GradientTexture2D.new()
		_shadow_gradient.gradient = grad
		_shadow_gradient.width = 64
		_shadow_gradient.height = 64
		_shadow_gradient.fill = GradientTexture2D.FILL_RADIAL
		_shadow_gradient.fill_from = Vector2(0.5, 0.5)
		_shadow_gradient.fill_to = Vector2(1.0, 0.5)
	return _shadow_gradient
