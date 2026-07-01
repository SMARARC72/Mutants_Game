class_name OverworldTokens
extends RefCounted
## Procedural overworld TOKEN + ATMOSPHERE textures — the tamer's brass medallion, the trailing
## lead-creature cameo disc, the parchment NPC pieces and the screen-space vignette. Extracted
## verbatim from overworld_screen.gd (Wave 3, file-cap discipline — the OverworldCameraRig
## pattern). Pure static Image builders, no Node, headless-safe. Colors come from GrimoirePalette
## (the screen's old local INK/BRASS consts were byte-identical duplicates of the palette).

## The parchment face of an NPC token (moved verbatim from overworld_screen.gd — pre-palette hue).
const _NPC_PARCHMENT := Color(0.886, 0.831, 0.733)


## A brass medallion token for the tamer: dark INK disc, BRASS_BRIGHT rim + a central sigil dot, so
## the avatar reads as an occult game-piece on the painted map (not a flat square).
static func player_token(diameter: int) -> ImageTexture:
	var img := Image.create(diameter, diameter, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := (diameter - 1) * 0.5
	var r_out := c
	var rim := maxf(2.5, diameter * 0.11)
	var r_in := c - rim
	var r_dot := r_in * 0.42
	for y in diameter:
		for x in diameter:
			var d := Vector2(x - c, y - c).length()
			if d > r_out:
				continue
			if d > r_in:
				img.set_pixel(x, y, GrimoirePalette.BRASS_BRIGHT)
			elif d <= r_dot:
				img.set_pixel(x, y, GrimoirePalette.BRASS_BRIGHT)
			elif d <= r_dot + 1.6:
				img.set_pixel(x, y, GrimoirePalette.BRASS)
			else:
				img.set_pixel(x, y, GrimoirePalette.INK)
	return ImageTexture.create_from_image(img)


## Build a circular cameo token from a full-body creature plate: centre-crop a square framing the
## creature, downscale, then mask to a disc with a brass ring (the cream plate bg reads as parchment).
static func cameo_token(src: Image, diameter: int) -> ImageTexture:
	src.convert(Image.FORMAT_RGBA8)
	var w := src.get_width()
	var h := src.get_height()
	var side := mini(w, h)
	var ox := clampi(int((w - side) * 0.5), 0, maxi(0, w - side))
	var oy := clampi(int((h - side) * 0.42), 0, maxi(0, h - side))
	var sq := src.get_region(Rect2i(ox, oy, side, side))
	sq.resize(diameter, diameter, Image.INTERPOLATE_LANCZOS)
	var c := (diameter - 1) * 0.5
	var r_out := c
	var ring := maxf(2.0, diameter * 0.07)
	var r_in := c - ring
	for y in diameter:
		for x in diameter:
			var d := Vector2(x - c, y - c).length()
			if d > r_out:
				sq.set_pixel(x, y, Color(0, 0, 0, 0))
			elif d > r_in:
				sq.set_pixel(x, y, GrimoirePalette.BRASS)
	return ImageTexture.create_from_image(sq)


## A parchment NPC token with a coloured ring + dark sigil dot — distinct from the brass tamer
## medallion and the creature cameos, so "someone to talk to" reads at a glance.
static func npc_token(diameter: int, ring: Color) -> ImageTexture:
	var img := Image.create(diameter, diameter, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := (diameter - 1) * 0.5
	var rim := maxf(2.5, diameter * 0.12)
	var r_in := c - rim
	var r_dot := r_in * 0.34
	for y in diameter:
		for x in diameter:
			var d := Vector2(x - c, y - c).length()
			if d > c:
				continue
			if d > r_in:
				img.set_pixel(x, y, ring)
			elif d <= r_dot:
				img.set_pixel(x, y, GrimoirePalette.INK)
			else:
				img.set_pixel(x, y, _NPC_PARCHMENT)
	return ImageTexture.create_from_image(img)


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
