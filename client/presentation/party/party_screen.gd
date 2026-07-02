extends Control
## PartyScreen (Phase 5 · Slice 3b) — the player's CREATURE-MANAGEMENT surface: the party / grimoire
## screen. PRESENTATION layer, CODE-BUILT in _ready() (a thin .tscn just loads this script) so it is
## unit-testable HEADLESS: a test injects a GameController, calls select_creature / set_active /
## awaken_resonance / overclock / equip_gear, and asserts the run mutated correctly WITHOUT rendering.
##
## It wires the EXISTING infra through GameController + the Slice-3b services:
##   * lists the run's PARTY (creature_instances) with name / forces / tier / HP / key stats — the
##     numbers come from the ORACLE (CreatureSheet.effective_stats = LevelEngine.current_stats over
##     StatEngine.stat_block), never hand-math;
##   * SELECTS a creature for a detail panel; SETS the ACTIVE/lead creature (persisted via
##     GameController.set_active_creature + save_run);
##   * LEVELING: a resonance awaken (LevelingService -> LevelEngine.awaken, spends essence) and the
##     OVERCLOCK gamble (LevelingService -> canonical entropy roll + LevelEngine.awaken, banks
##     entropy + run corruption), each showing a COST LEDGER;
##   * GEAR: equip/unequip ONE gear slot (GearService -> GearCatalog effects), showing the stat delta.
## Every mutation persists through GameController.save_run(). Talks only to the facades + services.

const InputActions := preload("res://infrastructure/input/input_actions.gd")
const CreatureSheetScript := preload("res://application/game/creature_sheet.gd")
const LevelingServiceScript := preload("res://application/game/leveling_service.gd")
const GearServiceScript := preload("res://application/game/gear_service.gd")
const StatRowsScript := preload("res://presentation/ui/stat_rows.gd")
const CAMP_SCENE := "res://presentation/camp/camp_menu.tscn"
const DOSSIER_SCENE := "res://presentation/dossier/dossier_screen.tscn"

var _game: Node = null
var _transition: Node = null
var _input: Node = null
var _toast: Node = null
var _selected_index: int = 0

# Code-built UI handles (kept so refreshes target the right nodes; all guarded for headless).
var _roster: VBoxContainer = null
var _selected_row_button: Button = null  # the live selected roster row (focus target, W1)
var _detail_box: VBoxContainer = null
var _detail_title: Label = null
var _detail_stats: Label = null
var _stat_rows_box: VBoxContainer = null  # W17: the icon+bar+number pole-stat rows (StatRows)
var _detail_desc: Label = null
var _detail_portrait: LivingPlate = null
var _detail_forces: HBoxContainer = null
var _ledger_label: Label = null
var _gear_box: VBoxContainer = null
## When false, _ready does NOT auto-build from the autoload (a headless test injects + drives).
var _auto_build: bool = true


func _ready() -> void:
	# An injected _game (set_game before add_child) MUST win; only fall back to the autoload when
	# nothing was injected (mirrors overworld/battle screens).
	if _game == null:
		_game = get_node_or_null("/root/GameController")
	_transition = get_node_or_null("/root/Transition")
	_input = get_node_or_null("/root/InputService")
	_toast = get_node_or_null("/root/Toast")
	var theme_service := get_node_or_null("/root/ThemeService")
	if theme_service != null and theme_service.has_method("apply_to"):
		theme_service.call("apply_to", self)
	if _input != null and _input.has_method("switch_context"):
		_input.call("switch_context", InputActions.CTX_MENU)
	if _auto_build and _game != null and _game.has_method("has_run") and _game.call("has_run"):
		build_from_game()


## Inject the GameController (tests / non-autoload contexts). Call BEFORE build_from_game().
func set_game(game: Node) -> void:
	_game = game


## Disable the auto-build on _ready (tests call build_from_game() explicitly after injecting).
func set_auto_build(enabled: bool) -> void:
	_auto_build = enabled


## Build the party screen from the active GameController run. Public so a test can drive it after
## injecting a configured GameController.
func build_from_game() -> void:
	if _game == null:
		return
	_selected_index = int(_game.call("active_creature_index"))
	_build_ui()
	_refresh_roster()
	_refresh_detail()
	# W1 focus pass: the roster owns first focus so arrows walk the coven immediately.
	_focus_selected_row()


# === player actions (headless-testable; the UI buttons call the same methods) ================== #


## SELECT the party member at `index` for the detail panel. Returns the selected index (clamped).
func select_creature(index: int) -> int:
	var party_count := _party().size()
	if party_count == 0:
		return 0
	_selected_index = clampi(index, 0, party_count - 1)
	_refresh_roster()
	_refresh_detail()
	# The rows were rebuilt (the old ones are dying) — refocus so keyboard traversal stays alive.
	_focus_selected_row()
	return _selected_index


## SET the selected creature as the ACTIVE/lead member. Persists via GameController.set_active_creature
## + save_run. Returns true on success.
func set_active() -> bool:
	if _game == null or not _game.has_method("set_active_creature"):
		return false
	var ok := bool(_game.call("set_active_creature", _selected_index))
	if ok:
		_persist()
		_notify("Lead set.")
		_refresh_roster()
	return ok


## RESONANCE AWAKEN the selected creature (spends essence). Applies the oracle result onto the
## creature_instance + persists. Returns the LevelingService ledger.
func awaken_resonance() -> Dictionary:
	var creature := _selected_creature()
	var run: RunContext = _run()
	if creature.is_empty() or run == null:
		return {"ok": false, "reason": "no_target"}
	var ledger := LevelingServiceScript.awaken_resonance(run, creature)
	if bool(ledger.get("ok", false)):
		_persist()
		_show_ledger(_format_level_ledger(ledger))
		_refresh_detail()
	else:
		_show_ledger("Cannot awaken: " + str(ledger.get("reason", "")))
	return ledger


## OVERCLOCK gamble the selected creature (banks entropy + run corruption, forces an awakening).
## Applies the oracle result + persists. Returns the LevelingService cost ledger.
func overclock() -> Dictionary:
	var creature := _selected_creature()
	var run: RunContext = _run()
	if creature.is_empty() or run == null:
		return {"ok": false, "reason": "no_target"}
	var ledger := LevelingServiceScript.overclock(run, creature)
	if bool(ledger.get("ok", false)):
		_persist()
		_show_ledger(_format_level_ledger(ledger))
		_refresh_detail()
	return ledger


## EQUIP `gear_id` onto the selected creature (the one slot). W17 GEAR HONESTY: gated on actual
## run.inventory OWNERSHIP (an unowned piece fails with "not_owned"; equipping moves the piece out
## of the drawer). Persists. Returns the GearService ledger (with the stat/effect delta for the UI).
func equip_gear(gear_id: String) -> Dictionary:
	var creature := _selected_creature()
	if creature.is_empty() or _game == null:
		return {"ok": false, "reason": "no_target"}
	var gc: GearCatalog = _game.call("gear_catalog")
	var ledger := GearServiceScript.equip(creature, gear_id, gc, _inventory())
	if bool(ledger.get("ok", false)):
		_persist()
		_show_ledger(_format_gear_ledger(ledger, gc))
		_refresh_detail()
	elif str(ledger.get("reason", "")) == "not_owned":
		_show_ledger(
			(
				"You do not own a %s. Battles drop such things; the Trader sells a few."
				% gc.name_of(gear_id)
			)
		)
	return ledger


## UNEQUIP the selected creature's gear slot (the piece returns to the run drawer). Persists.
## Returns the GearService ledger.
func unequip_gear() -> Dictionary:
	var creature := _selected_creature()
	if creature.is_empty() or _game == null:
		return {"ok": false, "reason": "no_target"}
	var gc: GearCatalog = _game.call("gear_catalog")
	var ledger := GearServiceScript.unequip(creature, gc, _inventory())
	if bool(ledger.get("ok", false)):
		_persist()
		_show_ledger(_format_gear_ledger(ledger, gc))
		_refresh_detail()
	return ledger


## Open the selected creature's DOSSIER (its soul-page) as a router overlay above this screen.
## Returns the pushed page node, or null when the router/scene is unavailable.
func open_dossier() -> Node:
	var router := get_node_or_null("/root/UiRouter")
	if router == null or not router.has_method("push_scene"):
		return null
	var page: Node = router.call("push_scene", DOSSIER_SCENE)
	if page != null:
		page.call("set_game", _game)
		page.call("show_creature", _selected_index)
	return page


## Return to the camp menu (the surface this screen was opened from). W17: as a router overlay this
## POPS one level (the camp beneath was never destroyed); the scene swap survives as the no-router
## fallback only.
func return_to_camp() -> void:
	var router := get_node_or_null("/root/UiRouter")
	if router != null and bool(router.call("pop_from", self)):
		return
	set_process(false)
	if _transition != null and _transition.has_method("change_scene_ritual"):
		await _transition.call("change_scene_ritual", CAMP_SCENE)
	elif is_inside_tree():
		get_tree().change_scene_to_file(CAMP_SCENE)


# === accessors (for tests) ==================================================================== #


func selected_index() -> int:
	return _selected_index


func selected_creature() -> Dictionary:
	return _selected_creature()


# === UI (minimal, code-built, themed) ========================================================= #


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.07, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)

	var root := VBoxContainer.new()
	root.name = "RootBox"
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var title := Label.new()
	title.name = "PartyTitle"
	title.text = "Grimoire — Your Coven"
	title.theme_type_variation = "TitleLabel"
	root.add_child(title)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(columns)

	# Left: the roster (one selectable row per party member).
	var roster_panel := PanelContainer.new()
	roster_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(roster_panel)
	_roster = VBoxContainer.new()
	_roster.name = "Roster"
	_roster.add_theme_constant_override("separation", 4)
	roster_panel.add_child(_roster)

	# Right: the detail + leveling + gear panel for the selected creature — an open grimoire
	# page (ParchmentPanel), so its labels flip to ink text (TEXT_ON_PARCHMENT) below.
	var detail_panel := PanelContainer.new()
	detail_panel.theme_type_variation = "ParchmentPanel"
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(detail_panel)
	_detail_box = VBoxContainer.new()
	_detail_box.name = "DetailBox"
	_detail_box.add_theme_constant_override("separation", 8)
	detail_panel.add_child(_detail_box)
	_build_detail_panel()


func _build_detail_panel() -> void:
	# Header: a framed bestiary-plate portrait beside the name + force icons.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	_detail_box.add_child(header)
	# Wave 9 LivingPlate: the detail portrait breathes (texture/tint/identity land per refresh).
	_detail_portrait = LivingPlate.new()
	_detail_portrait.name = "DetailPortrait"
	_detail_portrait.set_plate_size(Vector2(132, 132))
	header.add_child(PortraitUtil.framed(_detail_portrait))
	var head_col := VBoxContainer.new()
	head_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head_col.add_theme_constant_override("separation", 4)
	header.add_child(head_col)
	_detail_title = Label.new()
	_detail_title.name = "DetailTitle"
	_detail_title.theme_type_variation = "TitleLabel"
	_ink_text(_detail_title)
	head_col.add_child(_detail_title)
	_detail_forces = HBoxContainer.new()
	_detail_forces.name = "DetailForces"
	_detail_forces.add_theme_constant_override("separation", 6)
	head_col.add_child(_detail_forces)

	_detail_stats = Label.new()
	_detail_stats.name = "DetailStats"
	_detail_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ink_text(_detail_stats)
	_detail_box.add_child(_detail_stats)

	# W17 scryed legibility: the six pole stats render as the SHARED icon+bar+number rows (StatRows
	# — the same kit the Dossier uses), so the detail panel answers "good at what?" at a glance.
	_stat_rows_box = VBoxContainer.new()
	_stat_rows_box.name = "StatRowsBox"
	_stat_rows_box.add_theme_constant_override("separation", 3)
	_detail_box.add_child(_stat_rows_box)

	# The creature's bestiary description (the funny-grim flavour), in ink on the page.
	_detail_desc = Label.new()
	_detail_desc.name = "DetailDescription"
	_detail_desc.theme_type_variation = "MutedLabel"
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ink_text(_detail_desc)
	_detail_box.add_child(_detail_desc)

	# Active/lead + soul-page + leveling buttons.
	var set_active_btn := _make_button("SetActiveButton", "Set as Lead", set_active)
	_detail_box.add_child(set_active_btn)
	_detail_box.add_child(_make_button("DossierButton", "Open Dossier", open_dossier))

	var level_label := Label.new()
	level_label.text = "Leveling"
	level_label.theme_type_variation = "MutedLabel"
	_ink_text(level_label)
	_detail_box.add_child(level_label)
	_detail_box.add_child(
		_make_button("AwakenButton", "Resonance Awaken (essence)", awaken_resonance)
	)
	_detail_box.add_child(_make_button("OverclockButton", "Overclock (gamble)", overclock))

	# Gear sub-panel (the one slot).
	var gear_label := Label.new()
	gear_label.text = "Gear"
	gear_label.theme_type_variation = "MutedLabel"
	_ink_text(gear_label)
	_detail_box.add_child(gear_label)
	_gear_box = VBoxContainer.new()
	_gear_box.name = "GearBox"
	_gear_box.add_theme_constant_override("separation", 4)
	_detail_box.add_child(_gear_box)

	# A shared ledger readout for the last action's cost/result.
	_ledger_label = Label.new()
	_ledger_label.name = "LedgerLabel"
	_ledger_label.theme_type_variation = "MutedLabel"
	_ledger_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ink_text(_ledger_label)
	_detail_box.add_child(_ledger_label)


## Rebuild the roster rows (one Button per party member, the active one marked).
func _refresh_roster() -> void:
	if _roster == null:
		return
	for child in _roster.get_children():
		child.queue_free()
	_selected_row_button = null
	var party := _party()
	var active_index := int(_game.call("active_creature_index")) if _game != null else 0
	for i in party.size():
		var creature: Dictionary = party[i]
		var label := _roster_line(creature, i == active_index)
		var btn := Button.new()
		btn.name = "PartyRow%d" % i
		btn.text = label
		btn.toggle_mode = true
		btn.button_pressed = i == _selected_index
		if i == _selected_index:
			_selected_row_button = btn
		# Hybrids render their dominant parent's plate with the deterministic corruption tint
		# (PortraitUtil), so the roster shows the same face lab/battle/camp do.
		var plate := PortraitUtil.creature_plate(creature)
		if plate != null:
			btn.icon = plate
			btn.expand_icon = true
			btn.add_theme_constant_override("icon_max_width", 38)
			PortraitUtil.tint_button_icon(btn, creature)
		btn.custom_minimum_size = Vector2(0, 46)
		var idx := i
		btn.pressed.connect(func() -> void: select_creature(idx))
		_stamp_roster_sigil(btn, creature)
		_roster.add_child(btn)


## The tiny 16px one-of-one sigil on a roster row's right edge (Wave 9 — the mark travels with
## the creature everywhere it is listed). Anchored manually: Buttons are not containers, so the
## mark keeps its corner slot without stealing the row's click.
func _stamp_roster_sigil(btn: Button, creature: Dictionary) -> void:
	var catalog: SpeciesCatalog = _game.call("catalog") if _game != null else null
	var ident := CreatureSheetScript.identity_of(creature, catalog) if catalog != null else {}
	var mark := SigilGen.make_mark(
		str(creature.get("species_id", "")),
		PortraitUtil.instance_tag_of(creature),
		str(ident.get("prim", "")),
		16
	)
	mark.name = "RowSigil"
	mark.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	mark.offset_left = -26.0
	mark.offset_right = -10.0
	mark.offset_top = -8.0
	mark.offset_bottom = 8.0
	btn.add_child(mark)


func _roster_line(creature: Dictionary, is_active: bool) -> String:
	var catalog: SpeciesCatalog = _game.call("catalog")
	var species: SpeciesData = catalog.get_by_id(str(creature.get("species_id", "")))
	var nick := str(creature.get("nickname", ""))
	var nm := nick if nick != "" else (species.name if species != null else "?")
	var lead := "★ " if is_active else "   "
	# identity_of resolves species AND spliced hybrids (stats_cached), so a hybrid shows its real tier.
	var ident := CreatureSheetScript.identity_of(creature, catalog)
	var tier := str(ident.get("tier", "?")) if not ident.is_empty() else "?"
	return "%s%s  [%s]" % [lead, nm, tier]


## Refresh the right-hand detail panel from the selected creature (oracle stats + gear options).
func _refresh_detail() -> void:
	if _detail_title == null or _game == null:
		return
	var creature := _selected_creature()
	if creature.is_empty():
		_detail_title.text = "—"
		# W16a: an actually-empty roster gets the authored empty-state (VoiceBook
		# empty.party); a mere non-selection keeps the plain instruction.
		var empty_line := VoiceBook.pick("empty.party") if _party().is_empty() else ""
		_detail_stats.text = empty_line if empty_line != "" else "No creature selected."
		if _stat_rows_box != null:
			for child in _stat_rows_box.get_children():
				child.queue_free()
		if _detail_desc != null:
			_detail_desc.text = ""
		return
	var catalog: SpeciesCatalog = _game.call("catalog")
	var species: SpeciesData = catalog.get_by_id(str(creature.get("species_id", "")))
	var nick := str(creature.get("nickname", ""))
	_detail_title.text = nick if nick != "" else (species.name if species != null else "?")
	if _detail_portrait != null:
		# Hybrids render their dominant parent's plate + the deterministic corruption tint; the
		# identity hash keeps this creature's breath phase + sigil the same on every screen.
		_detail_portrait.set_texture(PortraitUtil.creature_plate(creature))
		_detail_portrait.set_tint(PortraitUtil.creature_tint(creature))
		_detail_portrait.set_identity(
			str(creature.get("species_id", "")), PortraitUtil.instance_tag_of(creature)
		)
		var sigil_ident := CreatureSheetScript.identity_of(creature, catalog)
		PortraitUtil.stamp_sigil(_detail_portrait, creature, str(sigil_ident.get("prim", "")), 20)
	_refresh_detail_forces(creature, catalog)
	_detail_stats.text = _format_detail(creature, catalog)
	_refresh_stat_rows(creature, catalog)
	if _detail_desc != null:
		var desc := species.description if species != null else ""
		_detail_desc.text = "“%s”" % desc if desc != "" else ""
	_refresh_gear_box(creature)


## Fill the detail force-icon row from the creature's primary/secondary forces (colour+icon pairing).
## identity_of resolves species AND spliced hybrids (stats_cached), so hybrids get real force icons.
func _refresh_detail_forces(creature: Dictionary, catalog: SpeciesCatalog) -> void:
	if _detail_forces == null:
		return
	for child in _detail_forces.get_children():
		child.queue_free()
	var ident := CreatureSheetScript.identity_of(creature, catalog)
	if ident.is_empty():
		return
	for f: String in [str(ident.get("prim", "")), str(ident.get("sec", ""))]:
		var tr := PortraitUtil.force_icon_node(f, 22)
		if tr != null:
			_detail_forces.add_child(tr)


func _format_detail(creature: Dictionary, catalog: SpeciesCatalog) -> String:
	var force := "?"
	var tier := "?"
	# identity_of resolves species AND spliced hybrids (stats_cached) — real force/tier for both.
	var ident := CreatureSheetScript.identity_of(creature, catalog)
	if not ident.is_empty():
		force = str(ident.get("prim", "?"))
		if str(ident.get("sec", "")) != "":
			force = "%s/%s" % [force, str(ident.get("sec", ""))]
		tier = str(ident.get("tier", "?"))
	var hp := CreatureSheetScript.hp_of(creature, catalog)
	var expr := int(round(CreatureSheetScript.expression_of(creature) * 100.0))
	var entropy := CreatureSheetScript.entropy_of(creature)
	var awak := CreatureSheetScript.awakenings_of(creature)
	var lines := PackedStringArray()
	lines.append("Force %s   Tier %s   HP %d" % [force, tier, hp])
	lines.append("Expression %d%%   Awakenings %d   Entropy %d" % [expr, awak, entropy])
	# W17: the pole-stat NUMBERS moved into the icon+bar+number rows below (_refresh_stat_rows).
	return "\n".join(lines)


## Render the six pole stats as StatRows (effective vs oracle ceiling) — scryed legibility (W17).
func _refresh_stat_rows(creature: Dictionary, catalog: SpeciesCatalog) -> void:
	if _stat_rows_box == null:
		return
	var effective := CreatureSheetScript.effective_stats(creature, catalog)
	var block := CreatureSheetScript.ceiling_block(creature, catalog)
	var ceiling_raw: Variant = block.get("stats", {})
	var ceiling: Dictionary = ceiling_raw if ceiling_raw is Dictionary else {}
	StatRowsScript.render(_stat_rows_box, effective, ceiling, true)


## Rebuild the gear sub-panel: the equipped slot + an equip button per catalog gear + Unequip.
## W17 GEAR HONESTY: the list is gated on run.inventory OWNERSHIP — an unowned piece is GREYED
## (disabled-with-reason, never hidden) with acquisition flavour, so the catalog stops reading as
## a free wardrobe.
func _refresh_gear_box(creature: Dictionary) -> void:
	if _gear_box == null or _game == null:
		return
	for child in _gear_box.get_children():
		child.queue_free()
	var gc: GearCatalog = _game.call("gear_catalog")
	var inv := _inventory()
	var equipped := GearServiceScript.equipped_id(creature)
	var slot_label := Label.new()
	slot_label.name = "EquippedLabel"
	slot_label.text = "Slot: %s" % (gc.name_of(equipped) if equipped != "" else "(empty)")
	_ink_text(slot_label)
	_gear_box.add_child(slot_label)
	for row in gc.all():
		var gid := str(row["id"])
		var owned := GearServiceScript.is_owned(gid, inv)
		var btn := Button.new()
		btn.name = "EquipButton_%s" % gid
		if owned:
			btn.text = "Equip %s" % str(row["name"])
		else:
			btn.text = "%s — not in your keeping" % str(row["name"])
			btn.disabled = true
			btn.tooltip_text = ("Unfound. The wild drops such things after a won fight; the camp Trader shelves a few.")
		var this_id := gid
		btn.pressed.connect(func() -> void: equip_gear(this_id))
		_gear_box.add_child(btn)
	var unequip := _make_button("UnequipButton", "Unequip", unequip_gear)
	unequip.disabled = equipped == ""
	_gear_box.add_child(unequip)


# === ledger formatting ======================================================================== #


func _format_level_ledger(ledger: Dictionary) -> String:
	var events: Array = ledger.get("events", [])
	var head := "Resonance" if str(ledger.get("reason", "")) == "resonance" else "OVERCLOCK"
	var before := int(round(float(ledger.get("expression_before", 0.0)) * 100.0))
	var after := int(round(float(ledger.get("expression_after", 0.0)) * 100.0))
	var lines := PackedStringArray(["%s: expr %d%% -> %d%%" % [head, before, after]])
	if ledger.has("essence_spent"):
		lines.append(
			"essence -%d (now %d)" % [int(ledger["essence_spent"]), int(ledger["essence_after"])]
		)
	if ledger.has("entropy_gained"):
		(
			lines
			. append(
				(
					"entropy +%d (now %d), corruption +%d (now %d)"
					% [
						int(ledger["entropy_gained"]),
						int(ledger["entropy_after"]),
						int(ledger["corruption_gained"]),
						int(ledger["corruption_after"]),
					]
				)
			)
		)
		if bool(ledger.get("burnout", false)):
			lines.append("!! BURNOUT risk reached")
	if not events.is_empty():
		var event_strs := PackedStringArray(events.map(func(e: Variant) -> String: return str(e)))
		lines.append(" · ".join(event_strs))
	return "\n".join(lines)


func _format_gear_ledger(ledger: Dictionary, gear_catalog: GearCatalog) -> String:
	var head := str(ledger.get("reason", "")).capitalize()
	var equipped := str(ledger.get("equipped", ""))
	var gear_name := gear_catalog.name_of(equipped) if equipped != "" else "(nothing)"
	var delta: Dictionary = ledger.get("delta", {})
	var parts := PackedStringArray()
	for field in delta:
		var v: Variant = delta[field]
		if v is float or v is int:
			parts.append("%s %+.2f" % [field, float(v)])
		else:
			parts.append("%s: %s" % [field, str(v)])
	var detail := "  ".join(parts) if not parts.is_empty() else "no stat change"
	return "%s %s\n%s" % [head, gear_name, detail]


# === input ==================================================================================== #


func _process(_delta: float) -> void:
	if _input == null or not _input.has_method("just_pressed"):
		return
	# Esc pops exactly one level (W17): return_to_camp pops when router-owned (and a page buried
	# under another overlay swallows the edge inside pop_from); the swap fallback disables _process
	# itself before awaiting.
	if bool(_input.call("just_pressed", InputActions.CANCEL)):
		return_to_camp()


# === helpers ================================================================================== #


## Focus the selected roster row (W1 focus pass). Uses the captured node ref, NOT a name lookup —
## the freed rows linger until end of frame, so a name lookup could hit a dying duplicate.
func _focus_selected_row() -> void:
	if (
		_selected_row_button != null
		and is_instance_valid(_selected_row_button)
		and _selected_row_button.is_inside_tree()
	):
		_selected_row_button.grab_focus()


func _make_button(node_name: String, text: String, handler: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.pressed.connect(handler)
	return button


## Flip a label to ink text — the parchment-tone default (TEXT_ON_INK) is authored for dark
## surfaces and vanishes against the detail panel's ParchmentPanel page.
func _ink_text(label: Label) -> void:
	label.add_theme_color_override("font_color", GrimoirePalette.TEXT_ON_PARCHMENT)


func _run() -> RunContext:
	if _game == null or not _game.has_method("run"):
		return null
	return _game.call("run")


## The run's live InventoryAdapter (the W17 gear-ownership gate), or null when unavailable.
func _inventory() -> InventoryAdapter:
	if _game == null or not _game.has_method("inventory"):
		return null
	return _game.call("inventory")


func _party() -> Array:
	var run := _run()
	return run.party if run != null else []


func _selected_creature() -> Dictionary:
	var party := _party()
	if _selected_index < 0 or _selected_index >= party.size():
		return {}
	var entry: Variant = party[_selected_index]
	return entry if entry is Dictionary else {}


func _persist() -> void:
	if _game != null and _game.has_method("save_run"):
		_game.call("save_run")


func _show_ledger(text: String) -> void:
	if _ledger_label != null:
		_ledger_label.text = text


func _notify(message: String) -> void:
	if _toast != null and _toast.has_method("show"):
		_toast.call("show", {"title": message, "body": "", "sound": "chime"})
