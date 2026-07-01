class_name OverworldTokens
extends RefCounted
## Overworld game-piece tokens (extracted from overworld_screen; presentation-only, deterministic).
##
## The design language: the tamer is a BRASS SIGIL-STAR medallion (the same eight-point crest the
## main menu and ritual transition carry), NPCs are wax-seal medallions — parchment field, coloured
## wax rim (the NPC's identity colour), and a per-name RUNE so each seal is one-of-one — and the
## lead creature trails as its actual painterly cutout, not a cropped coin. All builders are pure
## functions of their inputs (LOCAL hashes only — never the canonical RNG streams).

const INK := Color(0.090196, 0.07451, 0.109804)
const PARCHMENT := Color(0.909804, 0.866667, 0.768627)
const BRASS := Color(0.725, 0.576, 0.247)
const BRASS_BRIGHT := Color(0.878431, 0.72549, 0.352941)

## Wave 6 spike diet: built token/cameo textures cached by identity+size, so the set_pixel
## builders run once per (species/name, size) — never again on every battle return.
static var _texture_cache: Dictionary = {}


## The tamer: ink disc, brass rim, and an eight-point sigil star (long cardinal rays, short
## diagonal rays) — the player piece reads as the crest, not a flat ring.
static func player_token(diameter: int) -> ImageTexture:
	var key := "player|%d" % diameter
	var hit: Variant = _texture_cache.get(key)
	if hit is ImageTexture:
		return hit
	var img := Image.create(diameter, diameter, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := (diameter - 1) * 0.5
	var rim := maxf(2.5, diameter * 0.09)
	var r_in := c - rim
	var r_long := r_in * 0.82
	var r_short := r_in * 0.52
	for y in diameter:
		for x in diameter:
			var v := Vector2(x - c, y - c)
			var d := v.length()
			if d > c:
				continue
			if d > r_in:
				img.set_pixel(x, y, BRASS_BRIGHT)
				continue
			img.set_pixel(x, y, INK)
			if d <= r_in * 0.10:
				img.set_pixel(x, y, BRASS_BRIGHT)
				continue
			# Eight rays at 45-degree spacing: cardinal rays run long, diagonals short.
			var ang := fposmod(v.angle(), PI / 4.0)
			var delta := minf(ang, PI / 4.0 - ang)
			var eighth := int(roundf(fposmod(v.angle(), TAU) / (PI / 4.0))) % 8
			var reach := r_long if eighth % 2 == 0 else r_short
			var width := 0.16 * (1.0 - d / (reach + 0.001)) + 0.02
			if d <= reach and delta < width:
				img.set_pixel(x, y, BRASS_BRIGHT if d < reach * 0.85 else BRASS)
	var tex := ImageTexture.create_from_image(img)
	_texture_cache[key] = tex
	return tex


## An NPC wax-seal: parchment disc, coloured wax rim (identity colour kept — colourblind-safe
## because the RUNE, hashed from the name, is the second cue), ink rune strokes. One seal per soul.
static func npc_token(diameter: int, ring: Color, seal_name: String) -> ImageTexture:
	var key := "npc|%s|%d" % [seal_name, diameter]
	var hit: Variant = _texture_cache.get(key)
	if hit is ImageTexture:
		return hit
	var img := Image.create(diameter, diameter, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := (diameter - 1) * 0.5
	var rim := maxf(2.5, diameter * 0.13)
	var r_in := c - rim
	for y in diameter:
		for x in diameter:
			var d := Vector2(x - c, y - c).length()
			if d > c:
				continue
			if d > r_in:
				img.set_pixel(x, y, ring)
			elif d > r_in - 1.5:
				img.set_pixel(x, y, INK)
			else:
				img.set_pixel(x, y, PARCHMENT)
	_draw_rune(img, c, r_in * 0.62, seal_name)
	var out := ImageTexture.create_from_image(img)
	_texture_cache[key] = out
	return out


## The lead-creature cameo: the painterly CUTOUT itself, fitted into a square box with a soft
## elliptical ground shadow — a creature walking with you, not a coin. Pass the species id as
## `cache_key` to reuse the built texture across rebuilds (Wave 6 spike diet); "" skips caching.
static func creature_cameo(tex: Texture2D, box: int, cache_key: String = "") -> ImageTexture:
	var key := ""
	if cache_key != "":
		key = "cameo|%s|%d" % [cache_key, box]
		var hit: Variant = _texture_cache.get(key)
		if hit is ImageTexture:
			return hit
	var src := tex.get_image()
	src.convert(Image.FORMAT_RGBA8)
	var fit := float(box) / maxf(float(src.get_width()), float(src.get_height()))
	var w := maxi(1, int(src.get_width() * fit))
	var h := maxi(1, int(src.get_height() * fit))
	src.resize(w, h, Image.INTERPOLATE_LANCZOS)
	var img := Image.create(box, box, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Ground shadow: a soft ellipse under the feet, so the cutout sits ON the map.
	var sc := Vector2(box * 0.5, box * 0.92)
	var sr := Vector2(w * 0.38, box * 0.055)
	for y in range(maxi(0, int(sc.y - sr.y - 2)), mini(box, int(sc.y + sr.y + 3))):
		for x in range(maxi(0, int(sc.x - sr.x - 2)), mini(box, int(sc.x + sr.x + 3))):
			var n := Vector2((x - sc.x) / sr.x, (y - sc.y) / sr.y).length_squared()
			if n < 1.0:
				img.set_pixel(x, y, Color(0.02, 0.015, 0.03, 0.38 * (1.0 - n)))
	img.blend_rect(src, Rect2i(0, 0, w, h), Vector2i((box - w) / 2, box - h))
	var out := ImageTexture.create_from_image(img)
	if key != "":
		_texture_cache[key] = out
	return out


## A radial vignette texture (transparent centre → soft dark corners) for screen-space atmosphere.
static func vignette(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) * 0.5
	var maxd := Vector2(c, c).length()
	for y in size:
		for x in size:
			var t := clampf((Vector2(x - c, y - c).length() / maxd - 0.55) / 0.45, 0.0, 1.0)
			img.set_pixel(x, y, Color(0.02, 0.015, 0.03, t * t * 0.62))
	return ImageTexture.create_from_image(img)


## A 3-4 stroke rune hashed from the seal name (deterministic; distinct per NPC). Strokes pick
## from a small vocabulary of line segments across the seal face.
static func _draw_rune(img: Image, c: float, r: float, seal_name: String) -> void:
	var hsh := seal_name.hash()
	var points := [
		Vector2(0, -1),
		Vector2(0.87, -0.5),
		Vector2(0.87, 0.5),
		Vector2(0, 1),
		Vector2(-0.87, 0.5),
		Vector2(-0.87, -0.5),
		Vector2(0, 0),
	]
	var strokes := 3 + (hsh & 1)
	var prev := int(absi(hsh) % points.size())
	for i in strokes:
		var next := int(absi(hsh >> (4 * (i + 1))) % points.size())
		if next == prev:
			next = (next + 2 + i) % points.size()
		var a: Vector2 = Vector2(c, c) + (points[prev] as Vector2) * r
		var b: Vector2 = Vector2(c, c) + (points[next] as Vector2) * r
		_line(img, a, b, INK)
		prev = next


static func _line(img: Image, a: Vector2, b: Vector2, color: Color) -> void:
	var steps := int(maxf(absf(b.x - a.x), absf(b.y - a.y))) + 1
	for i in steps + 1:
		var p := a.lerp(b, float(i) / float(steps))
		for oy in range(-1, 1):
			for ox in range(-1, 1):
				var px := int(p.x) + ox
				var py := int(p.y) + oy
				if px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height():
					img.set_pixel(px, py, color)
