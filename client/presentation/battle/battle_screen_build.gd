extends RefCounted
## BattleScreenBuild (Wave 11 extraction) — the battle screen's one-time UI ASSEMBLY, moved out of
## battle_screen.gd verbatim so the screen stays under the 1000-line cap while the capture moment
## lands (the battle_card_kit / battle_impact extraction pattern: STATIC, screen-agnostic,
## duck-typed back onto the screen for button verbs).
##
## PRESENTATION layer. Builds the EXACT tree _build_ui always built — flat void, arena stage,
## grade pass, HUD margin (banner / turn strip / compact card columns), action menu + target
## picker, the utility row (The Record + Swift Rites), the collapsible transcript drawer and the
## FX overlay — and returns every node the screen keeps as a member in one refs Dictionary. No
## live state is read here; the screen remains the single owner of teams/cards/transcript.

const BattleCardKitScript := preload("res://presentation/battle/battle_card_kit.gd")
const BattleStageScript := preload("res://presentation/battle/battle_stage.gd")
const EntropyDialScript := preload("res://presentation/battle/entropy_dial.gd")


## Assemble the battle screen's static UI onto `screen` and return the member refs:
## { stage, grade, root_box, banner, entropy_dial, turn_label, enemy_rows, party_rows,
##   action_menu, target_picker, record_button, swift_button, log_panel, scroll,
##   transcript_label, fx_layer }. Button presses duck-call the screen's public verbs.
static func build(
	screen: Control, region_force: String, is_wild: bool, is_boss: bool, instant: bool
) -> Dictionary:
	var refs: Dictionary = {}
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.06, 0.09)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(bg)
	# Wave 10 stage: the arena layer — painterly backdrop (Wave 8 backdrop-lite pick by force
	# climate), the two staged LivingPlates, and the boss dressing — sits between the flat void
	# and the vignette, so HUD text keeps its contrast grade.
	var stage: BattleStageScript = BattleStageScript.new()
	stage.name = "BattleStage"
	stage.build(BattleCardKitScript.pick_backdrop(region_force, is_wild), is_boss, instant)
	screen.add_child(stage)
	refs["stage"] = stage
	# The ONE combined grade+vignette pass (Wave 10 commit 3, tension 9): grades the arena toward
	# its dark edges and — driven by the entropy crescendo — toward ember heat. It replaces the
	# old 65k set_pixel vignette texture and sits BELOW the HUD margin, never over readable text.
	var grade := BattleCardKitScript.make_grade_pass()
	screen.add_child(grade)
	refs["grade"] = grade

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	# Boss battles: the full-width boss bar rides the very top — start the HUD below it.
	if is_boss:
		margin.add_theme_constant_override("margin_top", 56)
	screen.add_child(margin)

	var box := VBoxContainer.new()
	box.name = "RootBox"
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	refs["root_box"] = box

	# The combatant area scrolls if it ever overflows, so the action verbs below are
	# ALWAYS on-screen — no viewport size may ever clip Flee/Capture off the bottom.
	var top_scroll := ScrollContainer.new()
	top_scroll.name = "CombatantScroll"
	top_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_scroll.size_flags_stretch_ratio = 3.0
	top_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(top_scroll)
	var top_box := VBoxContainer.new()
	top_box.add_theme_constant_override("separation", 8)
	top_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_scroll.add_child(top_box)

	var banner := Label.new()
	banner.name = "ResultBanner"
	banner.theme_type_variation = "TitleLabel"
	top_box.add_child(banner)
	refs["banner"] = banner

	# The turn strip: the radial entropy dial (parchment -> ember as the field burns) beside the
	# whose-turn label — the crescendo's at-a-glance read (Wave 10 commit 3).
	var turn_row := HBoxContainer.new()
	turn_row.add_theme_constant_override("separation", 8)
	top_box.add_child(turn_row)
	var entropy_dial: EntropyDialScript = EntropyDialScript.new()
	entropy_dial.name = "EntropyDial"
	turn_row.add_child(entropy_dial)
	refs["entropy_dial"] = entropy_dial
	var turn_label := Label.new()
	turn_label.name = "TurnIndicator"
	turn_label.theme_type_variation = "MutedLabel"
	turn_row.add_child(turn_label)
	refs["turn_label"] = turn_label

	# Wave 10 composition: COMPACT card columns hug the corners the stage plates do NOT use —
	# enemy readouts top-LEFT (its plate is top-right), party readouts bottom-RIGHT (its plate is
	# bottom-left) — so the centre stays open for the spectacle while every readout stays visible.
	var teams := HBoxContainer.new()
	teams.add_theme_constant_override("separation", 24)
	teams.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_box.add_child(teams)

	var enemy_box := VBoxContainer.new()
	enemy_box.custom_minimum_size = Vector2(320, 0)
	enemy_box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	teams.add_child(enemy_box)
	var enemy_title := Label.new()
	enemy_title.text = "The Wild" if is_wild else "Adversary"
	enemy_title.theme_type_variation = "MutedLabel"
	enemy_box.add_child(enemy_title)
	var enemy_rows := VBoxContainer.new()
	enemy_rows.name = "EnemyRows"
	enemy_box.add_child(enemy_rows)
	refs["enemy_rows"] = enemy_rows

	var stage_gap := Control.new()
	stage_gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	teams.add_child(stage_gap)

	var party_box := VBoxContainer.new()
	party_box.custom_minimum_size = Vector2(320, 0)
	party_box.size_flags_horizontal = Control.SIZE_SHRINK_END
	party_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	party_box.alignment = BoxContainer.ALIGNMENT_END
	teams.add_child(party_box)
	var party_title := Label.new()
	party_title.text = "Your Coven"
	party_title.theme_type_variation = "MutedLabel"
	party_box.add_child(party_title)
	var party_rows := VBoxContainer.new()
	party_rows.name = "PartyRows"
	party_box.add_child(party_rows)
	refs["party_rows"] = party_rows

	var action_menu := VBoxContainer.new()
	action_menu.name = "ActionMenu"
	box.add_child(action_menu)
	refs["action_menu"] = action_menu

	var target_picker := VBoxContainer.new()
	target_picker.name = "TargetPicker"
	box.add_child(target_picker)
	refs["target_picker"] = target_picker

	# Wave 8 (HAWKING veto honored: demoted, never deleted): the transcript is a COLLAPSIBLE
	# drawer — the beat playback IS the narration now; "The Record" opens the written ledger.
	# The utility row also carries the Swift Rites pacing toggle (persisted, x1/x2/instant).
	var utility := HBoxContainer.new()
	utility.name = "UtilityRow"
	utility.add_theme_constant_override("separation", 8)
	box.add_child(utility)
	var record_button := Button.new()
	record_button.name = "RecordToggle"
	record_button.text = "The Record ▸"
	record_button.pressed.connect(func() -> void: screen.call("toggle_record"))
	utility.add_child(record_button)
	refs["record_button"] = record_button
	var swift_button := Button.new()
	swift_button.name = "SwiftRitesButton"
	swift_button.pressed.connect(func() -> void: screen.call("cycle_swift_rites"))
	utility.add_child(swift_button)
	refs["swift_button"] = swift_button

	var log_panel := PanelContainer.new()
	log_panel.name = "RecordDrawer"
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_panel.visible = false  # collapsed by default — beats narrate; the drawer archives
	box.add_child(log_panel)
	refs["log_panel"] = log_panel
	var scroll := ScrollContainer.new()
	log_panel.add_child(scroll)
	refs["scroll"] = scroll
	var transcript_label := RichTextLabel.new()
	transcript_label.name = "TranscriptLog"
	transcript_label.fit_content = true
	transcript_label.scroll_active = false
	# Cap the transcript's reserved height to a viewport fraction — on small windows the
	# old fixed 220px starved the layout and pushed the action verbs off-screen.
	var log_min_h := minf(220.0, screen.get_viewport_rect().size.y * 0.18)
	transcript_label.custom_minimum_size = Vector2(0, log_min_h)
	scroll.add_child(transcript_label)
	refs["transcript_label"] = transcript_label

	# Top-most overlay for floating damage numbers (mouse-transparent, full-rect).
	var fx_layer := Control.new()
	fx_layer.name = "FxLayer"
	fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(fx_layer)
	refs["fx_layer"] = fx_layer

	return refs
