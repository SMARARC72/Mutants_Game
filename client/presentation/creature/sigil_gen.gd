class_name SigilGen
extends RefCounted
## SigilGen (Wave 9) — deterministic one-of-one creature sigils: FNV(species_id + "|" +
## instance_tag) seeds a LOCAL RandomNumberGenerator that lays 8-16 polar strokes/arcs/nodes in
## BRASS/BRASS_BRIGHT plus exactly ONE force-accent stroke (GrimoirePalette.force_color).
##
## PRESENTATION layer. GEOMETRY-FIRST (red-team correction C6): strokes_for() returns pure data
## (the seeded polar element arrays) so determinism is testable headless, where SubViewports
## render nothing and pixel hashes are vacuous. Rendering is a separate concern — SigilMark is a
## tiny _draw() Control for corners/rows, bake_texture() rasterises via SubViewport for stamping
## (windowed only; headless returns a blank of the right size). The RNG here is LOCAL and
## presentation-only — NEVER the canonical PCG32 streams. All colours via GrimoirePalette.

## Element budget: 8..15 seeded elements + the single force-accent stroke = 9..16 total.
const STROKES_MIN := 8
const STROKES_MAX := 16

## Ink keys carried in the GEOMETRY (resolved to palette colours only at draw time).
const INK_BRASS := "brass"
const INK_BRIGHT := "brass_bright"
const INK_ACCENT := "accent"


## The 32-bit FNV-1a seed for a creature identity (species + per-instance tag).
static func seed_for(species_id: String, instance_tag: String) -> int:
	return fnv1a_32(species_id + "|" + instance_tag)


## FNV-1a over the UTF-8 bytes, masked to 32 bits (stable across sessions/platforms).
static func fnv1a_32(text: String) -> int:
	var h := 0x811C9DC5
	for b in text.to_utf8_buffer():
		h = ((h ^ int(b)) * 0x01000193) & 0xFFFFFFFF
	return h


## The DETERMINISTIC stroke geometry for one creature: an Array of element dicts in polar space
## (angles in radians, radii/sizes as fractions of the seal radius). Same (species_id,
## instance_tag) => byte-identical array; the force accent is always the LAST element.
##   stroke: {kind, ink, a1, r1, a2, r2, width}
##   arc:    {kind, ink, radius, a_start, sweep, width}
##   node:   {kind, ink, angle, radius, size, filled}
static func strokes_for(species_id: String, instance_tag: String) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_for(species_id, instance_tag)
	var count := rng.randi_range(STROKES_MIN, STROKES_MAX - 1)
	var out: Array = []
	for _i in count:
		var kind_roll := rng.randi_range(0, 5)
		var ink := INK_BRIGHT if rng.randf() < 0.3 else INK_BRASS
		if kind_roll <= 2:  # strokes carry the linework weight
			(
				out
				. append(
					{
						"kind": "stroke",
						"ink": ink,
						"a1": rng.randf_range(0.0, TAU),
						"r1": rng.randf_range(0.15, 0.9),
						"a2": rng.randf_range(0.0, TAU),
						"r2": rng.randf_range(0.15, 0.9),
						"width": rng.randf_range(1.0, 1.8),
					}
				)
			)
		elif kind_roll <= 4:
			(
				out
				. append(
					{
						"kind": "arc",
						"ink": ink,
						"radius": rng.randf_range(0.25, 0.85),
						"a_start": rng.randf_range(0.0, TAU),
						"sweep": rng.randf_range(0.5, 4.4),
						"width": rng.randf_range(1.0, 1.6),
					}
				)
			)
		else:
			(
				out
				. append(
					{
						"kind": "node",
						"ink": ink,
						"angle": rng.randf_range(0.0, TAU),
						"radius": rng.randf_range(0.2, 0.85),
						"size": rng.randf_range(0.05, 0.12),
						"filled": rng.randf() < 0.6,
					}
				)
			)
	# Exactly ONE force-accent stroke: a long chord crossing the seal (the creature's allegiance).
	var accent_a := rng.randf_range(0.0, TAU)
	(
		out
		. append(
			{
				"kind": "stroke",
				"ink": INK_ACCENT,
				"a1": accent_a,
				"r1": rng.randf_range(0.7, 0.95),
				"a2": accent_a + PI + rng.randf_range(-0.6, 0.6),
				"r2": rng.randf_range(0.7, 0.95),
				"width": 2.0,
			}
		)
	)
	return out


## Resolve a geometry ink key to its palette colour (`accent` = the caller's force colour).
static func ink_color(ink: String, accent: Color) -> Color:
	match ink:
		INK_BRIGHT:
			return GrimoirePalette.BRASS_BRIGHT
		INK_ACCENT:
			return accent
		_:
			return GrimoirePalette.BRASS


## A ready-to-place SigilMark Control (px square, mouse-transparent) bearing the creature's mark.
## `force` picks the accent colour ("" falls back to brass via GrimoirePalette.force_color).
static func make_mark(
	species_id: String, instance_tag: String, force: String = "", px: int = 18
) -> Control:
	var mark := SigilMark.new()
	mark.custom_minimum_size = Vector2(px, px)
	mark.size = Vector2(px, px)
	mark.set_identity(species_id, instance_tag, force)
	return mark


## Rasterise a sigil to a Texture2D via SubViewport (capture cards / dossier stamps). COROUTINE —
## await it. `parent` hosts the transient viewport (must be inside the tree). HEADLESS (C6):
## SubViewports render nothing, so this returns a blank transparent texture of the right size
## without touching the render loop; pixel truth is a windowed/devcap concern.
static func bake_texture(
	parent: Node, species_id: String, instance_tag: String, force: String = "", px: int = 96
) -> Texture2D:
	if DisplayServer.get_name() == "headless" or parent == null or not parent.is_inside_tree():
		var blank := Image.create(px, px, false, Image.FORMAT_RGBA8)
		return ImageTexture.create_from_image(blank)
	var vp := SubViewport.new()
	vp.size = Vector2i(px, px)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var mark := make_mark(species_id, instance_tag, force, px)
	vp.add_child(mark)
	parent.add_child(vp)
	await RenderingServer.frame_post_draw
	var tex := ImageTexture.create_from_image(vp.get_texture().get_image())
	vp.queue_free()
	return tex


## SigilMark — the tiny _draw() consumer of the geometry: a faded outer seal ring + the seeded
## elements, scaled to its own rect. Cheap enough for 16px roster rows; redraws only on identity
## change or resize (no per-frame work, headless-safe).
class SigilMark:
	extends Control

	var _strokes: Array = []
	var _accent: Color = GrimoirePalette.BRASS

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	## Re-aim the mark at a creature identity (regenerates geometry + redraws).
	func set_identity(species_id: String, instance_tag: String, force: String = "") -> void:
		_strokes = SigilGen.strokes_for(species_id, instance_tag)
		_accent = GrimoirePalette.force_color(force)
		queue_redraw()

	## The current geometry (test/read access).
	func strokes() -> Array:
		return _strokes

	func _draw() -> void:
		if _strokes.is_empty():
			return
		var c := size * 0.5
		var rad := minf(size.x, size.y) * 0.5
		if rad <= 0.0:
			return
		var ring := GrimoirePalette.BRASS
		ring.a = 0.55
		draw_arc(c, rad * 0.96, 0.0, TAU, 24, ring, 1.0, true)
		for s_v in _strokes:
			var s: Dictionary = s_v
			var col := SigilGen.ink_color(str(s.get("ink", "")), _accent)
			match str(s.get("kind", "")):
				"stroke":
					draw_line(
						_pt(c, rad, float(s["a1"]), float(s["r1"])),
						_pt(c, rad, float(s["a2"]), float(s["r2"])),
						col,
						float(s["width"]),
						true
					)
				"arc":
					draw_arc(
						c,
						rad * float(s["radius"]),
						float(s["a_start"]),
						float(s["a_start"]) + float(s["sweep"]),
						16,
						col,
						float(s["width"]),
						true
					)
				"node":
					var p := _pt(c, rad, float(s["angle"]), float(s["radius"]))
					if bool(s.get("filled", true)):
						draw_circle(p, rad * float(s["size"]), col)
					else:
						draw_arc(p, rad * float(s["size"]), 0.0, TAU, 12, col, 1.0, true)

	func _pt(c: Vector2, rad: float, angle: float, r: float) -> Vector2:
		return c + Vector2(cos(angle), sin(angle)) * (rad * r)
