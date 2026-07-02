extends Control
## DossierScreen (Wave 17) — the creature SOUL-PAGE: one light parchment page per creature, pushed
## as a UiRouter overlay from the party roster and the post-capture card. PRESENTATION layer,
## CODE-BUILT (the thin .tscn just loads this script) so it is headless-testable: a test injects a
## GameController, calls show_creature(), and asserts the rendered identity WITHOUT rendering.
##
## The page (W17 contract):
##   * a LARGE LivingPlate portrait (breathing, hybrid corruption-tinted via PortraitUtil) with the
##     creature's one-of-one sigil, beside the name header (Cinzel via TitleLabel);
##   * the six pole stats as force-coloured icon+bar+NUMBER rows (StatRows — bars augment numbers);
##   * the skill kit with verb icons (the same KitFactory mapping battle actually uses);
##   * bond + entropy meters (entropy filled via GrimoirePalette.corruption_color) and the run's
##     corruption price, each with its authored VoiceBook tooltip;
##   * a LINEAGE strip reading lineage.parents (spliced hybrids name their parents; caught wilds
##     name their provenance) — permadeath gets a face.
## Every number comes from the ORACLE via CreatureSheet (effective_stats / ceiling_block / hp_of);
## this screen computes nothing. Back pops the router (Esc pops exactly one level).

const InputActions := preload("res://infrastructure/input/input_actions.gd")
const CreatureSheetScript := preload("res://application/game/creature_sheet.gd")
const KitFactoryScript := preload("res://application/battle/kit_factory.gd")
const StatRowsScript := preload("res://presentation/ui/stat_rows.gd")
const VERB_ICON_DIR := "res://assets/icons/verbs/"
const METER_MAX := 100.0  # entropy/corruption meters read 0..100 (the run-corruption scale)

var _game: Node = null
var _input: Node = null

var _title: Label = null
var _portrait: LivingPlate = null
var _stat_box: VBoxContainer = null
var _skill_box: VBoxContainer = null
var _lineage_label: Label = null
var _creature: Dictionary = {}


func _ready() -> void:
	if _game == null:
		_game = get_node_or_null("/root/GameController")
	_input = get_node_or_null("/root/InputService")
	var theme_service := get_node_or_null("/root/ThemeService")
	if theme_service != null and theme_service.has_method("apply_to"):
		theme_service.call("apply_to", self)
	if _input != null and _input.has_method("switch_context"):
		_input.call("switch_context", InputActions.CTX_MENU)


## Inject the GameController (tests / non-autoload contexts). Call BEFORE show_creature().
func set_game(game: Node) -> void:
	_game = game


## Open the soul-page for run.party[index]. Returns true when the page built.
func show_creature(index: int) -> bool:
	var party := _party()
	if index < 0 or index >= party.size() or not (party[index] is Dictionary):
		return false
	return show_creature_dict(party[index] as Dictionary)


## Open the soul-page for an explicit creature_instance dict (the capture-card path hands the
## just-caught entry straight in). Public + headless-testable.
func show_creature_dict(creature: Dictionary) -> bool:
	if creature.is_empty():
		return false
	_creature = creature
	_build_page()
	return true


## Close the page: pop the router level that holds it, or free ourselves standalone. A buried page
## (another overlay above) swallows the verb — Esc pops exactly one level (W17).
func close() -> void:
	var router := get_node_or_null("/root/UiRouter")
	if router != null and bool(router.call("pop_from", self)):
		return
	queue_free()


func _process(_delta: float) -> void:
	if _input == null or not _input.has_method("just_pressed"):
		return
	if bool(_input.call("just_pressed", InputActions.CANCEL)):
		close()


# === accessors (tests) ======================================================================== #


func title_text() -> String:
	return _title.text if _title != null else ""


func stat_row_count() -> int:
	return _stat_box.get_child_count() if _stat_box != null else 0


func skill_row_count() -> int:
	return _skill_box.get_child_count() if _skill_box != null else 0


func lineage_text() -> String:
	return _lineage_label.text if _lineage_label != null else ""


# === the page (code-built, parchment) ========================================================= #


func _build_page() -> void:
	for child in get_children():
		child.queue_free()
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# A dim scrim behind the page — the world beneath stays visible but hushed (modal overlay).
	var scrim := ColorRect.new()
	scrim.name = "Scrim"
	scrim.color = Color(0.05, 0.04, 0.07, 0.78)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var page := PanelContainer.new()
	page.name = "DossierPage"
	page.theme_type_variation = "ParchmentPanel"
	page.custom_minimum_size = Vector2(680, 0)
	center.add_child(page)

	var box := VBoxContainer.new()
	box.name = "DossierBox"
	box.add_theme_constant_override("separation", 10)
	page.add_child(box)

	var catalog := _catalog()
	var ident := CreatureSheetScript.identity_of(_creature, catalog)
	_build_header(box, catalog, ident)
	_build_stats(box, catalog)
	_build_skills(box, ident)
	_build_meters(box)
	_build_lineage(box, catalog)

	var back := Button.new()
	back.name = "BackButton"
	back.text = "Close the page"
	back.pressed.connect(close)
	box.add_child(back)
	if back.is_inside_tree():
		back.grab_focus()


## Header: the LARGE LivingPlate (sigil-stamped, hybrid-tinted) beside name / forces / vitals.
func _build_header(box: VBoxContainer, catalog: SpeciesCatalog, ident: Dictionary) -> void:
	var header := HBoxContainer.new()
	header.name = "DossierHeader"
	header.add_theme_constant_override("separation", 16)
	box.add_child(header)

	_portrait = LivingPlate.new()
	_portrait.name = "DossierPortrait"
	_portrait.set_plate_size(Vector2(196, 196))
	_portrait.set_texture(PortraitUtil.creature_plate(_creature))
	_portrait.set_tint(PortraitUtil.creature_tint(_creature))
	_portrait.set_identity(
		str(_creature.get("species_id", "")), PortraitUtil.instance_tag_of(_creature)
	)
	header.add_child(PortraitUtil.framed(_portrait, _creature, str(ident.get("prim", ""))))

	var head_col := VBoxContainer.new()
	head_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head_col.add_theme_constant_override("separation", 5)
	header.add_child(head_col)

	_title = Label.new()
	_title.name = "DossierTitle"
	_title.text = _display_name(catalog)
	_title.theme_type_variation = "TitleLabel"
	_ink(_title)
	head_col.add_child(_title)

	var forces := HBoxContainer.new()
	forces.name = "DossierForces"
	forces.add_theme_constant_override("separation", 6)
	head_col.add_child(forces)
	for f: String in [str(ident.get("prim", "")), str(ident.get("sec", ""))]:
		var tr := PortraitUtil.force_icon_node(f, 22)
		if tr != null:
			forces.add_child(tr)

	var vitals := Label.new()
	vitals.name = "DossierVitals"
	var expr := int(round(CreatureSheetScript.expression_of(_creature) * 100.0))
	vitals.text = (
		"Tier %s   ·   HP %d   ·   Expression %d%%   ·   Awakenings %d"
		% [
			str(ident.get("tier", "?")),
			CreatureSheetScript.hp_of(_creature, catalog),
			expr,
			CreatureSheetScript.awakenings_of(_creature),
		]
	)
	vitals.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ink(vitals)
	head_col.add_child(vitals)


## The six pole stats — StatRows (icon + bar + number; effective vs oracle ceiling).
func _build_stats(box: VBoxContainer, catalog: SpeciesCatalog) -> void:
	box.add_child(_section_label("The Six Poles"))
	_stat_box = VBoxContainer.new()
	_stat_box.name = "StatBox"
	_stat_box.add_theme_constant_override("separation", 3)
	box.add_child(_stat_box)
	var effective := CreatureSheetScript.effective_stats(_creature, catalog)
	var block := CreatureSheetScript.ceiling_block(_creature, catalog)
	var ceiling_raw: Variant = block.get("stats", {})
	var ceiling: Dictionary = ceiling_raw if ceiling_raw is Dictionary else {}
	StatRowsScript.render(_stat_box, effective, ceiling, true)


## The skill kit with VERB icons — the exact KitFactory mapping battle runs on.
func _build_skills(box: VBoxContainer, ident: Dictionary) -> void:
	box.add_child(_section_label("Known Rites"))
	_skill_box = VBoxContainer.new()
	_skill_box.name = "SkillBox"
	_skill_box.add_theme_constant_override("separation", 2)
	box.add_child(_skill_box)
	var lib: Dictionary = Constants.BALANCE["skill"]["library"]
	var kit := KitFactoryScript.kit_for(str(ident.get("prim", "")), str(ident.get("sec", "")))
	for i in kit.size():
		var skill := str(kit[i])
		var sk: Dictionary = lib.get(skill, {})
		var verb := str(sk.get("verb", ""))
		var force := str(sk.get("force", ""))
		var row := HBoxContainer.new()
		row.name = "SkillRow%d" % i
		row.add_theme_constant_override("separation", 8)
		row.tooltip_text = "%s — a %s rite of %s." % [skill, verb, force]
		var icon := _verb_icon(verb, force)
		if icon != null:
			row.add_child(icon)
		var name_label := Label.new()
		name_label.text = skill
		name_label.custom_minimum_size = Vector2(160, 0)
		_ink(name_label)
		row.add_child(name_label)
		var verb_label := Label.new()
		verb_label.text = verb
		verb_label.theme_type_variation = "MutedLabel"
		_ink(verb_label)
		row.add_child(verb_label)
		_skill_box.add_child(row)


## Bond + entropy (corruption-coloured) + the run's corruption price, with authored tooltips.
func _build_meters(box: VBoxContainer) -> void:
	box.add_child(_section_label("The Ledger of Costs"))
	var bond := clampf(float(_creature.get("bond", 0.0)), 0.0, 1.0)
	box.add_child(
		_meter_row(
			"BondMeter", "Bond", bond * METER_MAX, GrimoirePalette.VERDANT, "ui.tooltip.bond"
		)
	)
	var entropy := clampf(float(CreatureSheetScript.entropy_of(_creature)), 0.0, METER_MAX)
	box.add_child(
		_meter_row(
			"EntropyMeter",
			"Entropy",
			entropy,
			GrimoirePalette.corruption_color(entropy / METER_MAX),
			"ui.tooltip.entropy"
		)
	)
	var run := _run()
	var corruption := clampf(float(run.corruption if run != null else 0), 0.0, METER_MAX)
	box.add_child(
		_meter_row(
			"CorruptionMeter",
			"Corruption",
			corruption,
			GrimoirePalette.corruption_color(corruption / METER_MAX),
			"ui.tooltip.corruption"
		)
	)


## One meter row: name + coloured bar + NUMBER (bars augment numbers here too) + authored tooltip.
func _meter_row(
	row_name: String, label_text: String, value: float, color: Color, voice_key: String
) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = row_name
	row.add_theme_constant_override("separation", 8)
	var tip := VoiceBook.pick(voice_key)
	if tip != "":
		row.tooltip_text = tip
	var name_label := Label.new()
	name_label.text = label_text
	name_label.custom_minimum_size = Vector2(88, 0)
	_ink(name_label)
	row.add_child(name_label)
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = METER_MAX
	bar.value = value
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(90, 12)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := StyleBoxFlat.new()
	fill.bg_color = GrimoirePalette.on_parchment(color)
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)
	var track := StyleBoxFlat.new()
	track.bg_color = GrimoirePalette.PARCHMENT_DIM
	track.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", track)
	row.add_child(bar)
	var num := Label.new()
	num.text = str(int(round(value)))
	num.custom_minimum_size = Vector2(40, 0)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ink(num)
	row.add_child(num)
	return row


## The lineage strip: spliced hybrids NAME their parents (lineage.parents, recorded at lab
## commit); caught wilds name their provenance; founders read as the starting coven.
func _build_lineage(box: VBoxContainer, catalog: SpeciesCatalog) -> void:
	_lineage_label = Label.new()
	_lineage_label.name = "LineageStrip"
	_lineage_label.text = _lineage_line(catalog)
	_lineage_label.theme_type_variation = "MutedLabel"
	_lineage_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ink(_lineage_label)
	box.add_child(_lineage_label)


func _lineage_line(catalog: SpeciesCatalog) -> String:
	var raw: Variant = _creature.get("lineage", {})
	var lineage: Dictionary = raw if raw is Dictionary else {}
	if bool(lineage.get("spliced", false)):
		var names := PackedStringArray()
		for parent: Variant in lineage.get("parents", []) as Array:
			if parent is Dictionary:
				names.append(_parent_name(parent as Dictionary, catalog))
		var line := "Spliced of %s" % " × ".join(names) if not names.is_empty() else "Spliced"
		if bool(lineage.get("taboo", false)):
			line += "   ·   a TABOO rite — the price is still compounding"
		return line
	if bool(lineage.get("captured", false)):
		var species: SpeciesData = catalog.get_by_id(str(lineage.get("from_species", "")))
		var wild := species.name if species != null else "the wild"
		return "Caught wild — a %s that chose (or lost) its way into your coven." % wild
	return "Of the founding coven — it was here before you learned the knack."


func _parent_name(parent: Dictionary, catalog: SpeciesCatalog) -> String:
	var nick := str(parent.get("nickname", ""))
	if nick != "":
		return nick
	var species: SpeciesData = catalog.get_by_id(str(parent.get("species_id", "")))
	if species != null:
		return species.name
	return "an unnamed splice"


# === helpers ================================================================================== #


func _display_name(catalog: SpeciesCatalog) -> String:
	var nick := str(_creature.get("nickname", ""))
	if nick != "":
		return nick
	var species: SpeciesData = catalog.get_by_id(str(_creature.get("species_id", "")))
	if species != null:
		return species.name
	return "A Spliced Chimera"


func _verb_icon(verb: String, force: String) -> TextureRect:
	var path := VERB_ICON_DIR + verb.to_lower() + ".svg"
	if verb == "" or not ResourceLoader.exists(path):
		return null
	var tr := TextureRect.new()
	tr.texture = load(path)
	tr.custom_minimum_size = Vector2(18, 18)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tr.modulate = GrimoirePalette.on_parchment(GrimoirePalette.force_color(force))
	tr.tooltip_text = verb
	return tr


func _section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = "MutedLabel"
	_ink(label)
	return label


func _ink(label: Label) -> void:
	label.add_theme_color_override("font_color", GrimoirePalette.TEXT_ON_PARCHMENT)


func _run() -> RunContext:
	if _game == null or not _game.has_method("run"):
		return null
	return _game.call("run")


func _party() -> Array:
	var run := _run()
	return run.party if run != null else []


func _catalog() -> SpeciesCatalog:
	if _game != null and _game.has_method("catalog"):
		return _game.call("catalog")
	return SpeciesCatalog.new()
