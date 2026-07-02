extends Node
## JuiceDirector autoload ("Juice", Wave 10 — "Battle Stage & Impact") — THE single juice
## authority (plan resolution 13: per-screen ad-hoc juice is vetoed; screens route every hit
## flash, shake, hitstop, collision flash and damage pop through this node).
##
## PRESENTATION-support autoload, three binding contracts:
##   * HEADLESS-SAFE: without a display every call RECORDS itself (the `calls` ring — suites
##     assert the hook fired) and performs no tween/node work, so the synchronous drain path
##     never waits on anything;
##   * reduce_motion-GATED: motion juice (shake / hitstop / lunge / collision flash) no-ops
##     under accessibility.reduce_motion; informational juice (hit flash, dissolve, damage
##     numbers) still lands — the readout survives, the churn goes;
##   * LOCAL RNG ONLY (shake jitter / pop drift) — never the canonical PCG32 streams; all
##     colours arrive from callers or GrimoirePalette (no new hexes).
## `heat` is the battle's normalized entropy (0..1, Wave 10 entropy crescendo): it scales
## shake amplitude and damage-number size so turn 8 physically hits harder than turn 1.

const MAX_RECORDED := 128
const HIT_FLASH_TIME := 0.12
const DISSOLVE_TIME := 0.8
const LUNGE_DISTANCE := 46.0
const LUNGE_TIME := 0.25
const SHAKE_TIME := 0.26
const SHAKE_BASE_PX := 6.0
const SHAKE_STEPS := 5
const HITSTOP_TIME_SCALE := 0.05
const FLASH_TIME := 0.22
const FLASH_ALPHA := 0.16
const POP_TIME := 0.8
const POP_RISE := 58.0
## Death-drift budget: one-shot bursts of 40 with sub-second lifetimes, capped concurrently,
## keep worst-case alive GPU particles well under the Physicist's 500 ceiling.
const PARTICLES_PER_BURST := 40
const MAX_BURSTS := 8

## Normalized battle entropy (0..1) — the crescendo dial feeds this each round (commit 3).
var heat := 0.0
## Bookkeeping ring: every call lands here (headless included) as {"fn": ..., "detail": ...}.
var calls: Array = []

var _hitstop_depth := 0
var _live_bursts := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


## True when effects may build nodes/tweens (a real display exists).
func visual() -> bool:
	return DisplayServer.get_name() != "headless"


## True when MOTION effects may run (display present AND reduce_motion off).
func motion() -> bool:
	return visual() and not _reduce_motion()


## The entropy crescendo hook: 0 = turn-1 calm, 1 = turn-cap inferno.
func set_heat(t: float) -> void:
	heat = clampf(t, 0.0, 1.0)


# === the impact verbs ========================================================================== #


## Flash the struck plate white-hot: hit_flash 1 -> 0 over 0.12s (the LivingPlate shader hook).
func hit(target_plate: Node) -> void:
	_record("hit", target_plate)
	if target_plate == null or not target_plate.has_method("set_hit_flash"):
		return
	target_plate.call("set_hit_flash", 1.0)
	if not visual():
		target_plate.call("set_hit_flash", 0.0)
		return
	var tw := target_plate.create_tween()
	tw.tween_method(
		func(v: float) -> void:
			if is_instance_valid(target_plate):
				target_plate.call("set_hit_flash", v),
		1.0,
		0.0,
		HIT_FLASH_TIME
	)


## Burn a dying plate away: dissolve 0 -> 1 (~0.8s, the LivingPlate shader hook) + a one-shot
## drifting-parts GPUParticles2D burst (budgeted). Headless: the uniform snaps to 1 instantly.
func dissolve_out(plate: Node) -> void:
	_record("dissolve", plate)
	if plate == null or not plate.has_method("set_dissolve"):
		return
	if not visual():
		plate.call("set_dissolve", 1.0)
		return
	var tw := plate.create_tween()
	tw.tween_method(
		func(v: float) -> void:
			if is_instance_valid(plate):
				plate.call("set_dissolve", v),
		0.0,
		1.0,
		DISSOLVE_TIME
	)
	_drift_burst(plate)


## Kinetic screen-shake, damage-scaled by `intensity` (0..~1.5) and heated by the entropy dial.
## Jitters `target`'s position (a Control or Node2D; defaults to the current scene) and restores.
func shake(intensity: float, target: CanvasItem = null) -> void:
	_record("shake", intensity)
	if not motion():
		return
	var node: CanvasItem = target
	if node == null:
		node = get_tree().current_scene as CanvasItem
	if node == null or node.has_meta("_juice_shaking"):
		return
	node.set_meta("_juice_shaking", true)
	var amp := SHAKE_BASE_PX * clampf(intensity, 0.0, 1.5) * (0.7 + 0.6 * heat)
	var start: Vector2 = node.get("position")
	var tw := node.create_tween()
	for i in SHAKE_STEPS:
		var falloff := 1.0 - float(i) / float(SHAKE_STEPS)
		var jitter := Vector2(_rng.randf_range(-amp, amp), _rng.randf_range(-amp, amp)) * falloff
		tw.tween_property(node, "position", start + jitter, SHAKE_TIME / float(SHAKE_STEPS + 1))
	tw.tween_property(node, "position", start, SHAKE_TIME / float(SHAKE_STEPS + 1))
	tw.tween_callback(
		func() -> void:
			if is_instance_valid(node):
				node.remove_meta("_juice_shaking")
	)


## Freeze the frame for `ms` milliseconds (kills / 1.5x overwhelms): Engine.time_scale dips to
## 5% and an IGNORE-timescale timer restores it. Re-entrant (nested stops extend, never stack).
func hitstop(ms: int) -> void:
	_record("hitstop", ms)
	if not motion():
		return
	_hitstop_depth += 1
	if _hitstop_depth == 1:
		Engine.time_scale = HITSTOP_TIME_SCALE
	# process_always + ignore_time_scale: the timer runs at wall-clock speed through the freeze.
	await get_tree().create_timer(float(ms) / 1000.0, true, false, true).timeout
	_hitstop_depth = maxi(0, _hitstop_depth - 1)
	if _hitstop_depth == 0:
		Engine.time_scale = 1.0


## Two-colour additive force-clash flash (attacker force left, defender force right) — always
## PAIRED with the matchup badge glyphs, never the sole cue (HAWKING). Brief and screen-wide.
func collision_flash(force_a: String, force_b: String) -> void:
	_record("collision_flash", [force_a, force_b])
	if not motion():
		return
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for side in 2:
		var rect := ColorRect.new()
		var col := GrimoirePalette.force_color(force_a if side == 0 else force_b)
		col.a = FLASH_ALPHA
		rect.color = col
		rect.material = mat
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.anchor_left = 0.0 if side == 0 else 0.5
		rect.anchor_right = 0.5 if side == 0 else 1.0
		layer.add_child(rect)
	var tw := layer.create_tween()
	tw.tween_method(
		func(a: float) -> void:
			for rect in layer.get_children():
				(rect as CanvasItem).modulate = Color(1, 1, 1, a),
		1.0,
		0.0,
		FLASH_TIME
	)
	tw.tween_callback(layer.queue_free)


## Lunge a stage plate toward its victim and recoil home (TRANS_CUBIC, ~0.25s total). `dir` is
## the un-normalized toward-the-target vector; one lunge per plate at a time.
func lunge(plate: Control, dir: Vector2) -> void:
	_record("lunge", dir)
	if not motion() or plate == null or dir == Vector2.ZERO:
		return
	if plate.has_meta("_juice_lunging"):
		return
	plate.set_meta("_juice_lunging", true)
	var start := plate.position
	var tw := plate.create_tween()
	(
		tw
		. tween_property(
			plate, "position", start + dir.normalized() * LUNGE_DISTANCE, LUNGE_TIME * 0.4
		)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)
	(
		tw
		. tween_property(plate, "position", start, LUNGE_TIME * 0.6)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_IN_OUT)
	)
	tw.tween_callback(
		func() -> void:
			if is_instance_valid(plate):
				plate.remove_meta("_juice_lunging")
	)


## Float an arcing text pop (damage numbers): TRANS_BACK scale-punch in, a quadratic-bezier arc
## up and aside (local-RNG drift), fade out. `weight` (0..1, damage fraction) sizes the type;
## the entropy heat swells it further. Colour arrives from the caller (force-coloured).
func pop_number(layer: Control, at: Vector2, text: String, color: Color, weight := 0.5) -> void:
	_record("pop_number", text)
	if not visual() or layer == null or not layer.is_inside_tree():
		return
	var lbl := Label.new()
	lbl.text = text
	var font_px := int(lerpf(18.0, 42.0, clampf(weight, 0.0, 1.0)) * (1.0 + 0.25 * heat))
	lbl.add_theme_font_size_override("font_size", font_px)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", GrimoirePalette.INK)
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.z_index = 60
	layer.add_child(lbl)
	lbl.position = at
	lbl.scale = Vector2(0.4, 0.4)
	var apex := at + Vector2(_rng.randf_range(-20.0, 20.0) * 0.5, -POP_RISE)
	var land := at + Vector2(apex.x - at.x, -POP_RISE * 0.62)
	var tw := lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)
	tw.tween_method(
		func(t: float) -> void:
			if is_instance_valid(lbl):
				lbl.position = at.lerp(apex, t).lerp(apex.lerp(land, t), t),
		0.0,
		1.0,
		POP_TIME
	)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.3).set_delay(POP_TIME - 0.3)
	tw.chain().tween_callback(lbl.queue_free)


# === test surface ============================================================================== #


## How many recorded calls hit `fn` (suite assertions on the headless no-op ring).
func recorded(fn: String) -> int:
	var n := 0
	for c in calls:
		if str((c as Dictionary).get("fn", "")) == fn:
			n += 1
	return n


## Reset the bookkeeping ring (each test starts clean).
func clear_recorded() -> void:
	calls.clear()


# === internals ================================================================================= #


func _record(fn: String, detail: Variant = null) -> void:
	calls.append({"fn": fn, "detail": detail})
	if calls.size() > MAX_RECORDED:
		calls = calls.slice(calls.size() - MAX_RECORDED)


## One-shot drifting-parts burst over a dissolving plate (budgeted; frees itself).
func _drift_burst(plate: Node) -> void:
	if _live_bursts >= MAX_BURSTS or not (plate is Control):
		return
	_live_bursts += 1
	var parts := GPUParticles2D.new()
	parts.amount = PARTICLES_PER_BURST
	parts.one_shot = true
	parts.explosiveness = 0.85
	parts.lifetime = 0.9
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 34.0
	mat.initial_velocity_min = 12.0
	mat.initial_velocity_max = 44.0
	mat.gravity = Vector3(0, -26, 0)
	mat.scale_min = 1.4
	mat.scale_max = 3.2
	mat.color = GrimoirePalette.BRASS_BRIGHT
	parts.process_material = mat
	(plate as Control).add_child(parts)
	parts.position = (plate as Control).size * 0.5
	parts.emitting = true
	var tw := parts.create_tween()
	tw.tween_interval(parts.lifetime + 0.3)
	tw.tween_callback(
		func() -> void:
			_live_bursts = maxi(0, _live_bursts - 1)
			if is_instance_valid(parts):
				parts.queue_free()
	)


## The Settings accessibility.reduce_motion toggle (safe without the autoload).
func _reduce_motion() -> bool:
	var settings := get_node_or_null("/root/Settings")
	if settings == null:
		return false
	return bool(settings.call("get_value", "accessibility", "reduce_motion", false))
