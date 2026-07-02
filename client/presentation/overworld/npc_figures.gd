class_name NpcFigures
extends RefCounted
## NpcFigures (W-DRESS) — the overworld's CHARACTERS: procedural painterly-adjacent FIGURE
## sprites replacing the flat wax-seal medallions on the map (the seals live on in dialogue
## as each soul's mark). Style-coherent with the sigil/brass language:
##   * a hooded robe silhouette in the NPC's identity colour (2-3 tone shading over grimoire
##     ink, per-pixel value dither so it reads painted, INK-outlined),
##   * a brass clasp + the NPC's one-of-one RUNE on the chest (the SAME OverworldTokens stroke
##     vocabulary its wax seal carries — the second, colourblind-safe identity cue),
##   * pose variants (staff / scroll / lantern / pack) + build variants (height / width),
##     all FNV-1a hashed from the name — deterministic, one figure per soul;
##   * a soft ground shadow so the figure stands ON the map (feet-level y-sort contract).
## Plus the Weathered Signpost prop and the cheap idle-sway tween (skipped headless /
## under reduce_motion). LOCAL hashes only — never the canonical RNG streams.

const INK := Color(0.06, 0.05, 0.08)
const FACE_VOID := Color(0.045, 0.035, 0.06)
const BRASS := Color(0.725, 0.576, 0.247)
const BRASS_BRIGHT := Color(0.878431, 0.72549, 0.352941)
const PARCHMENT := Color(0.909804, 0.866667, 0.768627)
const WOOD := Color(0.32, 0.24, 0.17)

const POSE_STAFF := 0
const POSE_SCROLL := 1
const POSE_LANTERN := 2
const POSE_PACK := 3

## Built figures cached by (name, height) — the set_pixel builders run once per soul.
static var _cache: Dictionary = {}


## The one-of-one figure texture for an NPC (deterministic per name; cached).
static func figure(figure_name: String, ring: Color, height: int) -> ImageTexture:
	var key := "fig|%s|%d" % [figure_name, height]
	var hit: Variant = _cache.get(key)
	if hit is ImageTexture:
		return hit
	var img := _draw_figure(figure_name, ring, height)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## The pose id (POSE_*) a name hashes to — public so tests can assert the variant spread.
static func pose_for(figure_name: String) -> int:
	return (SigilGen.fnv1a_32("pose|" + figure_name) >> 3) % 4


## The map sprite for an NPC def: creature-NPCs (a `species` hint — The Melon, Bog-Wretch,
## The Greenwatcher) walk as their ACTUAL painterly cutout at NPC scale, the signpost is a
## signpost, everyone else is their one-of-one hooded figure. Feet-level offset set here so
## the WorldYSort contract (position = ground contact) holds for every variant.
static func npc_sprite(def: Dictionary, tile_size: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = "Token"
	var species := str(def.get("species", ""))
	if species != "":
		var plate: Texture2D = SpeciesArt.plate(species)
		if plate != null:
			var box := int(tile_size * 1.15)
			sprite.texture = OverworldTokens.creature_cameo(plate, box, species)
			sprite.offset = Vector2(0, -box * 0.42)
			return sprite
	var h := int(tile_size * 1.4)
	if bool(def.get("sign", false)):
		sprite.texture = signpost(h)
	else:
		sprite.texture = figure(str(def.get("name", "")), def.get("ring", BRASS) as Color, h)
	sprite.offset = Vector2(0, -h * 0.44)
	return sprite


## The Weathered Signpost prop (a post + two parchment boards) — a readable thing, not a person.
static func signpost(height: int) -> ImageTexture:
	var key := "sign|%d" % height
	var hit: Variant = _cache.get(key)
	if hit is ImageTexture:
		return hit
	var w := int(height * 0.78)
	var img := Image.create(w, height, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := w * 0.5
	var base_y := height * 0.94
	_shadow(img, cx, base_y, w * 0.30, height * 0.045)
	var post_w := maxf(2.0, height * 0.055)
	_rect(img, cx - post_w * 0.5, height * 0.18, cx + post_w * 0.5, base_y, WOOD)
	# Two weathered boards, slightly skewed opposite ways (long past repainting).
	_board(img, cx, height * 0.26, w * 0.42, height * 0.115, 1)
	_board(img, cx, height * 0.46, w * 0.34, height * 0.10, -1)
	_outline(img)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## The cheap idle sway: a looping rotation tween pivoting at the FEET (the sprite's offset
## raises the texture above the node origin), phase/pace hashed per name so the cast never
## sways in lockstep. No-op headless / under reduce_motion — suites stay green.
static func attach_sway(token: Sprite2D, figure_name: String) -> void:
	if token == null or not token.is_inside_tree():
		return
	if DisplayServer.get_name() == "headless" or OverworldMotion.reduce_motion():
		return
	var hsh := SigilGen.fnv1a_32("sway|" + figure_name)
	var span := 0.9 + float(hsh % 5) * 0.06  # 1.14-1.9 degrees of lean
	var pace := 1.6 + float((hsh >> 8) % 7) * 0.12
	token.rotation_degrees = -span * 0.5
	var tween := token.create_tween().set_loops()
	var right := tween.tween_property(token, "rotation_degrees", span, pace)
	right.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var left := tween.tween_property(token, "rotation_degrees", -span, pace)
	left.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# === the layered figure painter ================================================================ #


static func _draw_figure(figure_name: String, ring: Color, height: int) -> Image:
	var hsh := SigilGen.fnv1a_32(figure_name)
	var height_f := 0.88 * (0.9 + float((hsh >> 4) % 16) / 75.0)  # 0.90..1.10 build height
	var width_f := 0.85 + float((hsh >> 16) % 16) / 50.0  # 0.85..1.15 build width
	var pose := pose_for(figure_name)
	var side := 1 if ((hsh >> 12) & 1) == 0 else -1
	var w := int(height * 0.72)
	var img := Image.create(w, height, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := w * 0.5
	var feet_y := height * 0.94
	var bh := height * height_f
	var top_y := feet_y - bh
	var head_y := top_y + bh * 0.16
	var head_r := bh * 0.115 * width_f
	var shoulder_y := top_y + bh * 0.32
	var shoulder_hw := bh * 0.19 * width_f
	var hem_hw := bh * 0.30 * width_f
	# Tones: the identity colour pulled into grimoire ink (2-3 tone shading + dither).
	var robe := ring.lerp(INK, 0.52)
	var robe_lit := ring.lerp(INK, 0.22)
	var robe_dark := ring.lerp(INK, 0.78)
	_shadow(img, cx, feet_y, hem_hw * 1.25, height * 0.045)
	if pose == POSE_PACK:
		_ellipse(
			img,
			cx - side * shoulder_hw * 0.9,
			shoulder_y + bh * 0.18,
			bh * 0.14,
			bh * 0.20,
			robe_dark
		)
	_robe_body(
		img,
		cx,
		head_y,
		head_r,
		shoulder_y,
		shoulder_hw,
		feet_y,
		hem_hw,
		robe,
		robe_lit,
		robe_dark,
		hsh
	)
	# Brass clasp + the chest rune (the wax seal's stroke vocabulary, brass on the dark robe).
	_ellipse(img, cx, shoulder_y + bh * 0.055, bh * 0.028, bh * 0.028, BRASS_BRIGHT)
	OverworldTokens.stamp_rune(img, cx, shoulder_y + bh * 0.21, bh * 0.085, figure_name, BRASS)
	match pose:
		POSE_STAFF:
			_staff(img, cx + side * (hem_hw + bh * 0.05), head_y - head_r * 0.6, feet_y, bh)
		POSE_SCROLL:
			_board(
				img,
				cx + side * (hem_hw + bh * 0.02),
				shoulder_y + bh * 0.24,
				bh * 0.14,
				bh * 0.075,
				side
			)
		POSE_LANTERN:
			_lantern(img, cx + side * (hem_hw + bh * 0.07), shoulder_y + bh * 0.10, bh)
		_:
			pass  # POSE_PACK painted behind the body above
	_outline(img)
	return img


## The hooded silhouette fill: hood dome + cowl, a lit/shadow tone split with a hashed dither
## so the robe reads painted, the face an ink void under the hood, a brass hem trim.
static func _robe_body(
	img: Image,
	cx: float,
	head_y: float,
	head_r: float,
	shoulder_y: float,
	shoulder_hw: float,
	feet_y: float,
	hem_hw: float,
	robe: Color,
	robe_lit: Color,
	robe_dark: Color,
	hsh: int
) -> void:
	var hood_r := head_r * 1.5
	for y in img.get_height():
		for x in img.get_width():
			var fx := float(x)
			var fy := float(y)
			var inside := false
			var in_hood := false
			var head_d := Vector2(fx - cx, fy - head_y).length()
			if head_d <= hood_r and fy <= shoulder_y:
				inside = true
				in_hood = true
			elif fy > shoulder_y and fy <= feet_y:
				var t := (fy - shoulder_y) / maxf(1.0, feet_y - shoulder_y)
				var hw := lerpf(shoulder_hw, hem_hw, t * t * (3.0 - 2.0 * t))
				inside = absf(fx - cx) <= hw
			elif fy > head_y and fy <= shoulder_y:
				# The cowl: neck taper between hood and shoulders.
				var tn := (fy - head_y) / maxf(1.0, shoulder_y - head_y)
				inside = absf(fx - cx) <= lerpf(hood_r * 0.8, shoulder_hw, tn)
			if not inside:
				continue
			var tone := robe
			if fx < cx - img.get_width() * 0.06:
				tone = robe_lit
			elif fx > cx + img.get_width() * 0.14:
				tone = robe_dark
			if fy > feet_y - (feet_y - shoulder_y) * 0.16:
				tone = tone.lerp(robe_dark, 0.5)  # hem falls into shade
			# Sleeve creases: two soft ink folds falling from the shoulders (arms under cloth).
			if fy > shoulder_y + (feet_y - shoulder_y) * 0.12 and fy < feet_y - 3.0:
				var fold := absf(absf(fx - cx) - shoulder_hw * 0.62)
				if fold < 1.2:
					tone = tone.lerp(robe_dark, 0.6)
			# Deterministic value dither (painted grain, never flat fill).
			var grain := float((x * 73 + y * 151 + hsh) % 7) / 7.0 - 0.5
			tone = tone.lightened(maxf(0.0, grain * 0.06)).darkened(maxf(0.0, -grain * 0.06))
			if in_hood and head_d <= head_r * 0.85 and fy > head_y - head_r * 0.25:
				tone = FACE_VOID  # the face under the hood is an occult void, not a face
			img.set_pixel(x, y, tone)
	# Brass hem trim: a thin lit line at the robe's base.
	for x in img.get_width():
		var hw := hem_hw
		if absf(float(x) - cx) <= hw:
			var yy := int(feet_y) - 1
			if yy >= 0 and yy < img.get_height():
				img.set_pixel(x, yy, BRASS)


static func _staff(img: Image, x: float, top: float, feet_y: float, bh: float) -> void:
	var half_w := maxf(1.0, bh * 0.018)
	_rect(img, x - half_w, top, x + half_w, feet_y, WOOD)
	_ellipse(img, x, top, bh * 0.035, bh * 0.035, BRASS_BRIGHT)


static func _lantern(img: Image, x: float, y: float, bh: float) -> void:
	_rect(img, x - bh * 0.012, y, x + bh * 0.012, y + bh * 0.06, WOOD)  # the hanger
	_rect(img, x - bh * 0.045, y + bh * 0.06, x + bh * 0.045, y + bh * 0.15, BRASS)
	_ellipse(img, x, y + bh * 0.105, bh * 0.026, bh * 0.032, Color(1.0, 0.85, 0.45))


## A parchment board (signpost plank / held scroll), skewed by `lean` (+1 / -1).
static func _board(
	img: Image, cx: float, cy: float, half_w: float, half_h: float, lean: int
) -> void:
	for y in range(int(cy - half_h), int(cy + half_h) + 1):
		var skew := float(lean) * (float(y) - cy) * 0.18
		for x in range(int(cx - half_w + skew), int(cx + half_w + skew) + 1):
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
				var edge := absf(float(y) - cy) > half_h - 1.5
				img.set_pixel(x, y, PARCHMENT.darkened(0.25) if edge else PARCHMENT.darkened(0.08))


static func _rect(img: Image, x0: float, y0: float, x1: float, y1: float, color: Color) -> void:
	for y in range(maxi(0, int(y0)), mini(img.get_height(), int(y1) + 1)):
		for x in range(maxi(0, int(x0)), mini(img.get_width(), int(x1) + 1)):
			img.set_pixel(x, y, color)


static func _ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, color: Color) -> void:
	for y in range(maxi(0, int(cy - ry - 1)), mini(img.get_height(), int(cy + ry + 2))):
		for x in range(maxi(0, int(cx - rx - 1)), mini(img.get_width(), int(cx + rx + 2))):
			var n := Vector2((x - cx) / maxf(0.001, rx), (y - cy) / maxf(0.001, ry))
			if n.length_squared() <= 1.0:
				img.set_pixel(x, y, color)


static func _shadow(img: Image, cx: float, cy: float, rx: float, ry: float) -> void:
	for y in range(maxi(0, int(cy - ry - 2)), mini(img.get_height(), int(cy + ry + 3))):
		for x in range(maxi(0, int(cx - rx - 2)), mini(img.get_width(), int(cx + rx + 3))):
			var n := (
				Vector2((x - cx) / maxf(0.001, rx), (y - cy) / maxf(0.001, ry)).length_squared()
			)
			if n < 1.0:
				img.set_pixel(x, y, Color(0.02, 0.015, 0.03, 0.36 * (1.0 - n)))


## INK-outline every filled pixel that borders a transparent one (the cutout linework pass).
static func _outline(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var solid: Array = []
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a <= 0.45:
				continue
			var edge := false
			for off: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx := x + off.x
				var ny := y + off.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h or img.get_pixel(nx, ny).a <= 0.45:
					edge = true
					break
			if edge:
				solid.append(Vector2i(x, y))
	for p: Vector2i in solid:
		img.set_pixel(p.x, p.y, INK)
