class_name StatRows
extends RefCounted
## StatRows (Wave 17 — scryed legibility) — the SHARED icon+bar+number stat-row kit used by the
## Dossier and the party detail panel, so "what is this creature good at" reads at a glance and
## reads the SAME everywhere.
##
## PRESENTATION layer. Pure node building — every NUMBER comes from the caller (the oracle via
## CreatureSheet); this file computes nothing. Each of the six pole stats renders as one row:
##   [painterly stat icon]  [stat name]  [bar: effective vs ceiling]  [effective number]
## The bar AUGMENTS the number, never replaces it (W17 contract). Rows are force-coloured through
## the canonical pole-stat ↔ primordial-force correspondence below, adapted for parchment via
## GrimoirePalette.on_parchment — and every colour is PAIRED with the stat's icon + name + number,
## so the readout survives grayscale (design §2 colorblind rule).

## The canonical pole-stat -> force pairing (design §2: each pole stat expresses one primordial
## force — Bulk/Gaia stone, Celerity/Ouranos wind, Ward/Cosmos order, Spike/Chaos rupture,
## Vitality/Eros growth, Bane/Thanatos rot). Colour source; icons carry the shape half of the pair.
const STAT_FORCE := {
	"Bulk": "Gaia",
	"Celerity": "Ouranos",
	"Ward": "Cosmos",
	"Spike": "Chaos",
	"Vitality": "Eros",
	"Bane": "Thanatos",
}

## The restyled painterly stat icons (client/assets/icons/painterly/stats, W2 asset drop).
const STAT_ICONS := {
	"Bulk": "res://assets/icons/painterly/stats/ICON-011_bulk.png",
	"Celerity": "res://assets/icons/painterly/stats/ICON-012_celerity.png",
	"Ward": "res://assets/icons/painterly/stats/ICON-013_ward.png",
	"Spike": "res://assets/icons/painterly/stats/ICON-014_spike.png",
	"Vitality": "res://assets/icons/painterly/stats/ICON-015_vitality.png",
	"Bane": "res://assets/icons/painterly/stats/ICON-016_bane.png",
}

## One-line stat meanings (the tooltip half of scryed legibility).
const STAT_LINES := {
	"Bulk": "Raw mass behind every strike.",
	"Celerity": "Who moves first, and how often.",
	"Ward": "How much of a blow the hide keeps out.",
	"Spike": "The cruelty of a single clean hit.",
	"Vitality": "How much living this body holds.",
	"Bane": "The venom in everything it does.",
}

const POLE_STATS: Array = ["Bulk", "Celerity", "Ward", "Spike", "Vitality", "Bane"]


## Render the six pole-stat rows into `parent` (cleared first). `effective` and `ceiling` are the
## oracle's stat dicts (LevelEngine.current_stats / StatEngine ceiling block); the bar shows
## effective AGAINST ceiling so growth-left is visible. `on_parchment` flips text to ink and
## deepens the force colours for the light page.
static func render(
	parent: VBoxContainer, effective: Dictionary, ceiling: Dictionary, on_parchment: bool
) -> void:
	if parent == null:
		return
	for child in parent.get_children():
		child.queue_free()
	for stat: String in POLE_STATS:
		parent.add_child(
			make_row(
				stat, int(effective.get(stat, 0)), maxi(int(ceiling.get(stat, 0)), 1), on_parchment
			)
		)


## Build one icon+bar+number row for `stat`. Named "StatRow_<stat>" so tests and refresh paths can
## find it. Public so a screen can lay a single row outside the six-pack.
static func make_row(stat: String, value: int, ceiling: int, on_parchment: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "StatRow_" + stat
	row.add_theme_constant_override("separation", 8)
	row.tooltip_text = "%s — %s" % [stat, str(STAT_LINES.get(stat, ""))]

	var force := str(STAT_FORCE.get(stat, ""))
	var color := GrimoirePalette.force_color(force)
	if on_parchment:
		color = GrimoirePalette.on_parchment(color)

	var icon := _stat_icon(stat, color)
	if icon != null:
		row.add_child(icon)

	var name_label := Label.new()
	name_label.name = "StatName"
	name_label.text = stat
	name_label.custom_minimum_size = Vector2(78, 0)
	name_label.add_theme_font_size_override("font_size", 14)
	_tint_text(name_label, on_parchment)
	row.add_child(name_label)

	var bar := ProgressBar.new()
	bar.name = "StatBar"
	bar.min_value = 0
	bar.max_value = maxi(ceiling, 1)
	bar.value = clampi(value, 0, maxi(ceiling, 1))
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(90, 12)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_bar(bar, color, on_parchment)
	row.add_child(bar)

	# The NUMBER — the bar augments it, never replaces it (W17). Effective now / oracle ceiling.
	var num := Label.new()
	num.name = "StatNumber"
	num.text = "%d / %d" % [value, ceiling]
	num.custom_minimum_size = Vector2(64, 0)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_tint_text(num, on_parchment)
	row.add_child(num)
	return row


## The painterly stat icon (tinted toward its force so colour+shape pair), or null if absent.
static func _stat_icon(stat: String, color: Color) -> TextureRect:
	var path := str(STAT_ICONS.get(stat, ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	var tr := TextureRect.new()
	tr.name = "StatIcon"
	tr.texture = load(path)
	tr.custom_minimum_size = Vector2(20, 20)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tr.self_modulate = color.lerp(Color.WHITE, 0.35)
	return tr


static func _tint_text(label: Label, on_parchment: bool) -> void:
	if on_parchment:
		label.add_theme_color_override("font_color", GrimoirePalette.TEXT_ON_PARCHMENT)


static func _style_bar(bar: ProgressBar, color: Color, on_parchment: bool) -> void:
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	var track := StyleBoxFlat.new()
	track.bg_color = GrimoirePalette.PARCHMENT_DIM if on_parchment else GrimoirePalette.INK
	track.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", track)
