class_name PortraitUtil
extends RefCounted
## Shared presentation helpers for creature portraits + force iconography, so the battle / party /
## camp / character screens don't each re-implement the brass frame and the force-icon lookup
## (review P3.6 — DRY: one place to change the frame colour or the icon path).

const FRAME_BG := Color(0.13, 0.11, 0.16)
const FRAME_BORDER := Color(0.725, 0.576, 0.247)  # BRASS
const FORCE_ICON_DIR := "res://assets/icons/forces/"


## Wrap a portrait TextureRect in a brass-bordered ink frame so the creature reads as a bestiary
## plate. Returns the frame (the portrait is its child).
static func framed(portrait: TextureRect) -> PanelContainer:
	var frame := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = FRAME_BG
	sb.set_corner_radius_all(4)
	sb.set_border_width_all(2)
	sb.border_color = FRAME_BORDER
	sb.set_content_margin_all(3)
	frame.add_theme_stylebox_override("panel", sb)
	frame.add_child(portrait)
	return frame


## A force's HUD icon (res://assets/icons/forces/<force>.svg), or null if the force is empty/absent.
static func force_icon(force_name: String) -> Texture2D:
	if force_name == "":
		return null
	var path := FORCE_ICON_DIR + force_name.to_lower() + ".svg"
	return load(path) if ResourceLoader.exists(path) else null


## A ready-to-add force-icon node: the SVG, sized + tinted to its force colour (colour+icon pairing,
## design §2/§5). Returns null when the force has no icon, so callers can skip it.
static func force_icon_node(force_name: String, size: int = 18) -> TextureRect:
	var icon := force_icon(force_name)
	if icon == null:
		return null
	var tr := TextureRect.new()
	tr.texture = icon
	tr.custom_minimum_size = Vector2(size, size)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tr.modulate = GrimoirePalette.force_color(force_name)
	tr.tooltip_text = force_name
	return tr
