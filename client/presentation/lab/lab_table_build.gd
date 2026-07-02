extends RefCounted
## LabTableBuild (Wave 15 extraction) — the Living Creation Table's STATIC UI constructors and
## list renderers, lifted from lab_screen.gd for the 1000-line module cap (the battle_card_kit /
## battle_beats pattern). PRESENTATION ONLY and deliberately dumb: builders assemble themed nodes
## and CONNECT signals to screen callables BY NAME (duck-typed — no import cycle back into the
## screen); renderers paint pickers/chips from data the screen already resolved. Nothing here
## reads a run, rolls a number, or touches the oracle.

const LabBenchViewScript := preload("res://presentation/lab/lab_bench_view.gd")
const LabRitualScript := preload("res://presentation/lab/lab_ritual.gd")
const LabLineageScript := preload("res://presentation/lab/lab_lineage.gd")

## Preview alternates flicker rate at the wild end (~8Hz — plan Wave 15).
const CONFIG_CYCLE_SECONDS := 0.125


## The table shell: ink backdrop, margin, root column, title, the STAGED TABLE (LabBenchView),
## and the mid row — scrolling bench stack (rite/subject/donor/reagents) beside the read-only
## Forbidden Ladder rail. Returns every node ref the screen keeps.
static func build_shell(screen: Control) -> Dictionary:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.05, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	screen.add_child(margin)

	var box := VBoxContainer.new()
	box.name = "RootBox"
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var title := Label.new()
	title.name = "LabTitle"
	title.text = "The Splicing Bench"
	title.theme_type_variation = "TitleLabel"
	box.add_child(title)

	# THE STAGED TABLE: subject/donor LivingPlates flanking the bubbling vessel, conduits pulsing
	# on a LEGAL preview. Identity/mood only — every number still walks the oracle road.
	var bench_view: Control = LabBenchViewScript.new()
	bench_view.name = "BenchStage"
	box.add_child(bench_view)

	# Bench pickers (scroll) beside the read-only Forbidden Ladder rail.
	var mid := HBoxContainer.new()
	mid.name = "MidRow"
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 16)
	box.add_child(mid)

	# The bench stack scrolls if it overflows so the verdict panel and the Divine/Splice/Back
	# verbs below stay on-screen at any size.
	var bench_scroll := ScrollContainer.new()
	bench_scroll.name = "BenchScroll"
	bench_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bench_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bench_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mid.add_child(bench_scroll)
	var bench_box := VBoxContainer.new()
	bench_box.add_theme_constant_override("separation", 10)
	bench_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bench_scroll.add_child(bench_box)

	var op_title := Label.new()
	op_title.text = "Rite"
	op_title.theme_type_variation = "MutedLabel"
	bench_box.add_child(op_title)
	var op_row := HBoxContainer.new()
	op_row.name = "OpRow"
	op_row.add_theme_constant_override("separation", 8)
	bench_box.add_child(op_row)

	var a_title := Label.new()
	a_title.text = "Subject"
	a_title.theme_type_variation = "MutedLabel"
	bench_box.add_child(a_title)
	var a_picker := VBoxContainer.new()
	a_picker.name = "CreatureAPicker"
	bench_box.add_child(a_picker)

	# Creature B section (fuse only — the screen toggles visibility per op).
	var b_section := VBoxContainer.new()
	b_section.name = "CreatureBSection"
	bench_box.add_child(b_section)
	var b_title := Label.new()
	b_title.text = "Donor"
	b_title.theme_type_variation = "MutedLabel"
	b_section.add_child(b_title)
	var b_picker := VBoxContainer.new()
	b_picker.name = "CreatureBPicker"
	b_section.add_child(b_picker)

	var ing_title := Label.new()
	ing_title.text = "Reagents"
	ing_title.theme_type_variation = "MutedLabel"
	bench_box.add_child(ing_title)
	var ingredient_picker := VBoxContainer.new()
	ingredient_picker.name = "IngredientPicker"
	bench_box.add_child(ingredient_picker)

	# The Forbidden Ladder (read-only flavor: the three gated rites vs the run's corruption).
	var ladder_rail := VBoxContainer.new()
	ladder_rail.name = "ForbiddenLadder"
	ladder_rail.custom_minimum_size = Vector2(216, 0)
	ladder_rail.size_flags_horizontal = Control.SIZE_SHRINK_END
	ladder_rail.add_theme_constant_override("separation", 8)
	mid.add_child(ladder_rail)

	return {
		"root_box": box,
		"bench_view": bench_view,
		"op_row": op_row,
		"a_picker": a_picker,
		"b_section": b_section,
		"b_picker": b_picker,
		"ingredient_picker": ingredient_picker,
		"ladder_rail": ladder_rail,
	}


## The method continuum row: Precise <-> Wild HSlider + a readout. The slider is presentation;
## the recipe snaps to binary at the midpoint (engine stays binary — Geneticist veto). Authored
## method voice rides the end-labels' tooltips.
static func build_method_row(screen: Control, box: VBoxContainer) -> Dictionary:
	var row := HBoxContainer.new()
	row.name = "MethodRow"
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var precise_label := Label.new()
	precise_label.text = "Precise"
	precise_label.theme_type_variation = "MutedLabel"
	precise_label.tooltip_text = VoiceBook.pick("lab.method.precise")
	row.add_child(precise_label)
	var slider := HSlider.new()
	slider.name = "MethodSlider"
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(Callable(screen, "set_method_value"))
	row.add_child(slider)
	var wild_label := Label.new()
	wild_label.text = "Wild"
	wild_label.theme_type_variation = "MutedLabel"
	wild_label.tooltip_text = VoiceBook.pick("lab.method.wild")
	row.add_child(wild_label)
	var readout := Label.new()
	readout.name = "MethodReadout"
	readout.custom_minimum_size = Vector2(84, 0)
	row.add_child(readout)
	return {"slider": slider, "readout": readout}


## Verdict + result panels — the oracle's ruling reads as an open grimoire page (ParchmentPanel),
## so both rich-text readouts flip to ink (TEXT_ON_PARCHMENT). Hosts the Wave 9 newborn showcase
## (LivingPlate + one-of-one sigil) and the Wave 15 Again?/Done row (hidden until a commit).
static func build_verdict_panel(screen: Control, box: VBoxContainer) -> Dictionary:
	var panel := PanelContainer.new()
	panel.name = "VerdictPanel"
	panel.theme_type_variation = "ParchmentPanel"
	box.add_child(panel)
	var verdict_box := VBoxContainer.new()
	panel.add_child(verdict_box)
	var verdict_label := RichTextLabel.new()
	verdict_label.name = "VerdictLabel"
	verdict_label.bbcode_enabled = true
	verdict_label.fit_content = true
	verdict_label.scroll_active = false
	verdict_label.custom_minimum_size = Vector2(0, 96)
	verdict_label.add_theme_color_override("default_color", GrimoirePalette.TEXT_ON_PARCHMENT)
	verdict_box.add_child(verdict_label)
	var newborn_row := HBoxContainer.new()
	newborn_row.name = "NewbornRow"
	newborn_row.add_theme_constant_override("separation", 10)
	newborn_row.visible = false
	verdict_box.add_child(newborn_row)
	var newborn_plate := LivingPlate.new()
	newborn_plate.name = "NewbornPlate"
	newborn_plate.set_plate_size(Vector2(96, 96))
	newborn_row.add_child(newborn_plate)
	var newborn_sigil := SigilGen.make_mark("", "", "", 28)
	newborn_sigil.name = "NewbornSigil"
	newborn_sigil.size_flags_vertical = Control.SIZE_SHRINK_END
	newborn_row.add_child(newborn_sigil)
	var result_label := RichTextLabel.new()
	result_label.name = "ResultLabel"
	result_label.bbcode_enabled = true
	result_label.fit_content = true
	result_label.scroll_active = false
	result_label.add_theme_color_override("default_color", GrimoirePalette.TEXT_ON_PARCHMENT)
	verdict_box.add_child(result_label)
	# The AGAIN LOOP: revealed after a sealed splice — the newborn is already pre-armed as Subject.
	var again_row := HBoxContainer.new()
	again_row.name = "AgainRow"
	again_row.add_theme_constant_override("separation", 10)
	again_row.visible = false
	verdict_box.add_child(again_row)
	var again_button := Button.new()
	again_button.name = "AgainButton"
	again_button.text = "Again?"
	again_button.pressed.connect(Callable(screen, "_on_again_pressed"))
	again_row.add_child(again_button)
	var done_button := Button.new()
	done_button.name = "DoneButton"
	done_button.text = "Done"
	done_button.pressed.connect(Callable(screen, "return_to_overworld"))
	again_row.add_child(done_button)
	var gallows_label := Label.new()
	gallows_label.name = "GallowsLabel"
	gallows_label.theme_type_variation = "MutedLabel"
	gallows_label.add_theme_color_override("font_color", GrimoirePalette.TEXT_ON_PARCHMENT)
	gallows_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gallows_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again_row.add_child(gallows_label)
	return {
		"panel": panel,
		"verdict_label": verdict_label,
		"newborn_row": newborn_row,
		"newborn_plate": newborn_plate,
		"newborn_sigil": newborn_sigil,
		"result_label": result_label,
		"again_row": again_row,
		"gallows_label": gallows_label,
	}


## Action row: Divine (preview), the Commit verb wearing its LabRitual seal ring (button_down
## begins the hold, button_up snuffs an early release), Back — plus the wild flicker Timer
## (~8Hz), which only the screen ever starts.
static func build_actions(screen: Control, box: VBoxContainer) -> Dictionary:
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	box.add_child(actions)
	var preview_button := Button.new()
	preview_button.name = "PreviewButton"
	preview_button.text = "Divine"
	preview_button.pressed.connect(Callable(screen, "preview"))
	actions.add_child(preview_button)
	var commit_button := Button.new()
	commit_button.name = "CommitButton"
	commit_button.text = "Splice"
	commit_button.custom_minimum_size = Vector2(0, 40)
	commit_button.button_down.connect(Callable(screen, "press_commit"))
	commit_button.button_up.connect(Callable(screen, "release_seal_hold"))
	actions.add_child(commit_button)
	var ritual: Control = LabRitualScript.new()
	ritual.name = "SealRing"
	ritual.set_anchors_preset(Control.PRESET_FULL_RECT)
	ritual.connect("sealed", Callable(screen, "_on_seal_complete"))
	commit_button.add_child(ritual)
	var back_button := Button.new()
	back_button.name = "BackButton"
	back_button.text = "Leave the Bench"
	back_button.pressed.connect(Callable(screen, "return_to_overworld"))
	actions.add_child(back_button)
	var cycle_timer := Timer.new()
	cycle_timer.name = "ConfigCycleTimer"
	cycle_timer.wait_time = CONFIG_CYCLE_SECONDS
	cycle_timer.timeout.connect(Callable(screen, "cycle_alternate"))
	screen.add_child(cycle_timer)
	return {
		"preview_button": preview_button,
		"commit_button": commit_button,
		"ritual": ritual,
		"cycle_timer": cycle_timer,
	}


## Rebuild the Fuse/Mutate op row (painterly rite icons where they match). Returns the FIRST
## button — the screen's W1 focus anchor.
static func fill_op_row(
	screen: Control, op_row: HBoxContainer, ops: Array, current: String
) -> Button:
	for child in op_row.get_children():
		child.queue_free()
	var first: Button = null
	for op in ops:
		var btn := Button.new()
		btn.name = "Op_" + str(op)
		btn.toggle_mode = true
		btn.button_pressed = str(op) == current
		btn.text = str(op).capitalize()
		var icon := LabBenchViewScript.op_icon(str(op))
		if icon != null:
			btn.icon = icon
			btn.expand_icon = true
			btn.add_theme_constant_override("icon_max_width", 28)
		# Bound method Callables (no lambda captures): they die silently with the screen.
		btn.pressed.connect(Callable(screen, "select_op").bind(str(op)))
		op_row.add_child(btn)
		if first == null:
			first = btn
	return first


## Rebuild a Subject/Donor picker: one toggle per party creature, bearing its plate (hybrids show
## their dominant parent's plate + deterministic corruption tint via PortraitUtil — the same face
## party/battle/camp render). Picks route back through `pick_method` on the screen.
static func fill_creature_picker(
	screen: Control,
	container: VBoxContainer,
	party: Array,
	catalog: SpeciesCatalog,
	selected_index: int,
	pick_method: String,
	tag: String
) -> void:
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()
	for i in party.size():
		var entry: Variant = party[i]
		if not (entry is Dictionary):
			continue
		var tuple: Array = LabLineageScript.creature_tuple(party, i, catalog)
		var btn := Button.new()
		btn.name = "Pick%s_%d" % [tag, i]
		btn.toggle_mode = true
		btn.button_pressed = i == selected_index
		btn.text = ("• " if i == selected_index else "  ") + _tuple_label(entry, tuple)
		var plate := PortraitUtil.creature_plate(entry as Dictionary)
		if plate != null:
			btn.icon = plate
			btn.expand_icon = true
			btn.add_theme_constant_override("icon_max_width", 36)
			PortraitUtil.tint_button_icon(btn, entry as Dictionary)
		btn.custom_minimum_size = Vector2(0, 44)
		btn.pressed.connect(Callable(screen, pick_method).bind(i))
		container.add_child(btn)


## Rebuild the reagent chips: painterly force icons where one matches + ingredient_compat hover
## tooltips (verbatim splice_rules.json data via LabBenchView). Empty drawer shows the authored
## VoiceBook empty-state.
static func fill_reagent_chips(
	screen: Control,
	container: VBoxContainer,
	stacks: Array,
	rules: SpliceRules,
	chosen: Array,
	op: String
) -> void:
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()
	if stacks.is_empty():
		var empty := Label.new()
		empty.name = "NoReagents"
		var what := "gene-vials" if op == "mutate" else "organs"
		empty.text = VoiceBook.pick("empty.parts")
		if empty.text == "":
			empty.text = "(the drawer holds no %s)" % what
		empty.theme_type_variation = "MutedLabel"
		container.add_child(empty)
		return
	for stack in stacks:
		var item: InventoryItem = stack
		var btn := Button.new()
		btn.name = "Reagent_" + item.item_key
		btn.toggle_mode = true
		btn.button_pressed = chosen.has(item.item_key)
		var mark := "• " if chosen.has(item.item_key) else "  "
		btn.text = "%s%s ×%d  (%s)" % [mark, item.item_key, item.qty, item.item_type]
		var spec := rules.ingredient_spec(item.item_key)
		if spec.is_empty():
			spec = rules.gene_spec(item.item_key)
		var chip := LabBenchViewScript.reagent_icon(spec)
		if chip != null:
			btn.icon = chip
			btn.expand_icon = true
			btn.add_theme_constant_override("icon_max_width", 24)
		btn.tooltip_text = LabBenchViewScript.reagent_tooltip(item.item_key, spec)
		btn.pressed.connect(Callable(screen, "toggle_ingredient").bind(item.item_key))
		container.add_child(btn)


static func _tuple_label(entry: Dictionary, tuple: Array) -> String:
	if tuple.size() >= 4:
		var force: String = str(tuple[1])
		if str(tuple[2]) != "":
			force += "/" + str(tuple[2])
		return "%s — %s %s" % [str(tuple[0]), force, str(tuple[3])]
	# A spliced/unresolvable entry (no catalog row): show its nickname so it stays pickable info.
	return str(entry.get("nickname", "Unknown"))
