class_name OverworldHud
extends RefCounted
## The overworld HUD builder (extracted from overworld_screen in Wave 13 for the lint line cap —
## the OverworldDepth/OverworldMotion pattern): the region title panel + authored entry-sting,
## the quest-objective tracker label, the controls chip (W1/C13), and the W13 corruption sigil
## pip in the chip's corner. Pure builders; the screen keeps the returned nodes and all logic.

const ControlsChipScript := preload("res://presentation/overworld/controls_chip.gd")


## Build the HUD CanvasLayer onto `screen`. Returns {layer, objective, chip, pip} so the screen
## wires its own state. `input` feeds the chip's live key names.
static func build(screen: Node2D, input: Node, region_id: String) -> Dictionary:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	layer.layer = 2
	var panel := PanelContainer.new()
	panel.position = Vector2(18, 14)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	# Wave 3: the HUD names the region the systems actually RUN (data-driven from the region id
	# via OverworldContent, falling back to the raw id).
	var title := Label.new()
	title.name = "RegionTitle"
	title.text = OverworldContent.region_title(region_id)
	title.theme_type_variation = "TitleLabel"
	var sub := Label.new()
	# W16a: the authored region entry-sting (VoiceBook region.<id>.enter, verbatim library copy)
	# — a full sentence, so it wraps inside a fixed column instead of stretching the panel.
	sub.text = OverworldContent.region_climate(region_id)
	sub.visible = sub.text != ""
	sub.theme_type_variation = "MutedLabel"
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(430, 0)
	box.add_child(title)
	box.add_child(sub)
	# Quest tracker: the active quest's current objective, always visible (hidden when none).
	var objective := Label.new()
	objective.name = "ObjectiveTracker"
	box.add_child(objective)
	panel.add_child(box)
	layer.add_child(panel)
	# Controls chip (W1/C13): the live verbs, always on, bottom-left, collapsible with H.
	var chip: Control = ControlsChipScript.new(input)
	layer.add_child(chip)
	# W13: the corruption sigil pip lives in the chip's corner — the run's rot, visible in the
	# field, thickening/cracking at 25/50/75 with authored threshold toasts.
	var pip := CorruptionPip.new()
	pip.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	pip.offset_left = 16
	pip.offset_right = 16 + CorruptionPip.PIP_SIZE
	pip.offset_bottom = -44
	pip.offset_top = -44 - CorruptionPip.PIP_SIZE
	layer.add_child(pip)
	screen.add_child(layer)
	var theme_svc := screen.get_node_or_null("/root/ThemeService")
	if theme_svc != null and theme_svc.has_method("apply_to"):
		theme_svc.call("apply_to", panel)
	return {"layer": layer, "objective": objective, "chip": chip, "pip": pip}


## "✦ <Quest>: <current step description>" for the first active quest def, or "" when none is.
## Reads the same QuestService + authored defs the Ledger does (HUD and journal never disagree).
static func active_objective(quests: QuestService) -> String:
	if quests == null:
		return ""
	for q: Dictionary in OverworldContent.quest_defs():
		var qid := str(q.get("id", ""))
		if not quests.is_active(qid):
			continue
		var cursor := int((quests.state().get(qid, {}) as Dictionary).get("step_cursor", 0))
		var steps: Array = q.get("steps", [])
		if cursor >= 0 and cursor < steps.size():
			return (
				"✦ "
				+ str(q.get("name", ""))
				+ ": "
				+ str((steps[cursor] as Dictionary).get("description", ""))
			)
	return ""
