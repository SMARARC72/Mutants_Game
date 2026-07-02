class_name PortraitUtil
extends RefCounted
## Shared presentation helpers for creature portraits + force iconography, so the battle / party /
## camp / character screens don't each re-implement the brass frame and the force-icon lookup
## (review P3.6 — DRY: one place to change the frame colour or the icon path).

const FRAME_BG := Color(0.13, 0.11, 0.16)
const FRAME_BORDER := Color(0.725, 0.576, 0.247)  # BRASS
const FORCE_ICON_DIR := "res://assets/icons/forces/"

## How far a hybrid's plate leans into its corruption tint (0 = untinted, 1 = fully corruption-hued).
## Strong enough to read as "not the parent", weak enough to keep the plate legible.
const HYBRID_TINT_STRENGTH := 0.45


## The bestiary plate for ANY creature_instance dict — species creatures resolve their own plate;
## a spliced hybrid (species_id == "") renders its DOMINANT PARENT's plate (recorded in
## lineage.portrait_species at lab commit, else the first parent with a species id). Pair with
## creature_tint() so party/lab/battle/camp all render hybrids the same way.
static func creature_plate(creature: Dictionary) -> Texture2D:
	return SpeciesArt.plate(portrait_species_of(creature))


## The species id whose plate represents this creature: its own species, else the hybrid's dominant
## parent (lineage.portrait_species — propagated through hybrid-of-hybrid lineages at commit), else
## the first parent tag carrying a species id. "" resolves to the SpeciesArt fallback plate.
static func portrait_species_of(creature: Dictionary) -> String:
	var species_id := str(creature.get("species_id", ""))
	if species_id != "":
		return species_id
	var lineage := _lineage_of(creature)
	var direct := str(lineage.get("portrait_species", ""))
	if direct != "":
		return direct
	var parents_raw: Variant = lineage.get("parents", [])
	var parents: Array = parents_raw if parents_raw is Array else []
	for parent in parents:
		if parent is Dictionary:
			var pid := str((parent as Dictionary).get("species_id", ""))
			if pid != "":
				return pid
	return ""


## The modulate for a creature's plate: WHITE (neutral) for species creatures; for a spliced hybrid a
## DETERMINISTIC corruption tint keyed off its lineage.rng_seed_tag. The key is hashed with a LOCAL
## string hash (presentation-only — never the canonical PCG32 streams), so the same hybrid renders
## the identical tint on every screen and across sessions, and two splices differ visibly.
static func creature_tint(creature: Dictionary) -> Color:
	var lineage := _lineage_of(creature)
	if not bool(lineage.get("spliced", false)):
		return Color.WHITE
	var tag := str(lineage.get("rng_seed_tag", ""))
	var t := float(absi(tag.hash()) % 997) / 996.0
	return Color.WHITE.lerp(GrimoirePalette.corruption_color(t), HYBRID_TINT_STRENGTH)


## Apply a creature's tint to a Button's ICON (roster/picker rows use icons, which have no modulate
## of their own). No-op for the neutral WHITE so themed buttons keep their default icon colors.
static func tint_button_icon(button: Button, creature: Dictionary) -> void:
	var tint := creature_tint(creature)
	if tint == Color.WHITE:
		return
	for color_name in [
		"icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"
	]:
		button.add_theme_color_override(color_name, tint)


## The per-instance identity tag for sigils/phase hashing (Wave 9): a spliced hybrid's
## lineage.rng_seed_tag (the unique op_id) wins, else the nickname, else "" (species-level mark).
## LOCAL-hash input only — never a canonical stream seed.
static func instance_tag_of(creature: Dictionary) -> String:
	var tag := str(_lineage_of(creature).get("rng_seed_tag", ""))
	if tag != "":
		return tag
	return str(creature.get("nickname", ""))


## Stamp (or re-aim) a creature's one-of-one sigil in `host`'s bottom-right corner (Wave 9).
## `host` must be a NON-container Control (a LivingPlate / TextureRect — containers would
## stretch the mark). Idempotent per host: refresh paths re-call this and the existing mark is
## re-identified in place. `force` picks the accent colour; `tag_override` replaces the derived
## instance tag (battle cards tag wild enemies by combatant name).
static func stamp_sigil(
	host: Control, creature: Dictionary, force: String = "", px: int = 18, tag_override: String = ""
) -> void:
	if host == null:
		return
	var species_id := str(creature.get("species_id", ""))
	var tag := tag_override if tag_override != "" else instance_tag_of(creature)
	var existing := host.get_node_or_null("SigilStamp")
	if existing != null:
		existing.call("set_identity", species_id, tag, force)
		return
	var mark := SigilGen.make_mark(species_id, tag, force, px)
	mark.name = "SigilStamp"
	mark.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	mark.offset_left = -float(px) - 1.0
	mark.offset_top = -float(px) - 1.0
	mark.offset_right = -1.0
	mark.offset_bottom = -1.0
	host.add_child(mark)


static func _lineage_of(creature: Dictionary) -> Dictionary:
	var raw: Variant = creature.get("lineage", {})
	return raw if raw is Dictionary else {}


## Wrap a portrait Control (a TextureRect or a LivingPlate) in a brass-bordered ink frame so the
## creature reads as a bestiary plate. Returns the frame (the portrait is its child). Pass the
## `creature` dict to also stamp its one-of-one sigil in the portrait corner (Wave 9); refresh
## paths that re-point the portrait should call stamp_sigil() again themselves.
static func framed(
	portrait: Control, creature: Dictionary = {}, force: String = ""
) -> PanelContainer:
	var frame := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = FRAME_BG
	sb.set_corner_radius_all(4)
	sb.set_border_width_all(2)
	sb.border_color = FRAME_BORDER
	sb.set_content_margin_all(3)
	frame.add_theme_stylebox_override("panel", sb)
	frame.add_child(portrait)
	if not creature.is_empty():
		stamp_sigil(portrait, creature, force)
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
