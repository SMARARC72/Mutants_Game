extends Control
## JournalScreen (Phase 13) — the QUEST LOG. PRESENTATION layer, CODE-BUILT in _ready() (a thin .tscn
## just loads this script) so it is unit-testable HEADLESS: a test injects a GameController whose run
## carries a serialized quest_state, calls build_from_game(), and asserts the surfaced quests WITHOUT
## rendering.
##
## It rebuilds a QuestService from the SAME authored defs the overworld drives (OverworldContent.quest_defs)
## + the run's persisted quest_state (run.flags["quest_state"], written by the overworld's _persist_quests),
## then lists every DISCOVERED quest (active or done — undiscovered ones stay hidden so the log doesn't
## spoil) with its status and, while active, the current objective (the step at the cursor). Read-only:
## it computes nothing about quest progress; QuestService is the authority. Talks only to facades.

const InputActions := preload("res://infrastructure/input/input_actions.gd")
const CAMP_SCENE := "res://presentation/camp/camp_menu.tscn"

var _game: Node = null
var _transition: Node = null
var _input: Node = null
var _quests: QuestService = null
var _entries: Array = []  # [{id, name, status, objective}] for the discovered quests (tests read this)
## W18: the run's memorial ledger (run.flags["graveyard"]) — the Graveyard tab renders these.
var _graveyard: Array = []
## The open ledger page: "quests" (default — the errand log) or "graveyard" (the memorials).
var _tab: String = "quests"
## When false, _ready does NOT auto-build from the autoload (a headless test injects + drives).
var _auto_build: bool = true

var _list: VBoxContainer = null


func _ready() -> void:
	if _game == null:
		_game = get_node_or_null("/root/GameController")
	_transition = get_node_or_null("/root/Transition")
	_input = get_node_or_null("/root/InputService")
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


## Build the journal from the active run: rebuild the QuestService from the authored defs + persisted
## state, compute the discovered-quest entries, then build the UI. Public so a test can drive it.
func build_from_game() -> void:
	if _game == null or not _game.has_method("run"):
		return
	var run: RunContext = _game.call("run")
	if run == null:
		return
	_quests = QuestService.new()
	_quests.register(OverworldContent.quest_defs())
	var saved: Variant = run.flags.get("quest_state", null)
	if saved is Dictionary and not (saved as Dictionary).is_empty():
		_quests.deserialize(saved)
	_entries = _compute_entries()
	# W18: the memorial ledger rides the same build (the Graveyard tab renders it read-only).
	var graves: Variant = run.flags.get("graveyard", [])
	_graveyard = (graves as Array).duplicate(true) if graves is Array else []
	_build_ui()


## The discovered quests (active or done) as data: {id, name, status, objective}. status is "active" |
## "done"; objective is the current step's description while active, "" when done. Tests read this.
func _compute_entries() -> Array:
	var out: Array = []
	if _quests == null:
		return out
	for q: Dictionary in OverworldContent.quest_defs():
		var qid := str(q.get("id", ""))
		var active := _quests.is_active(qid)
		var done := _quests.is_done(qid)
		if not active and not done:
			continue  # undiscovered — keep it out of the log (no spoilers)
		(
			out
			. append(
				{
					"id": qid,
					"name": str(q.get("name", qid)),
					"status": "done" if done else "active",
					"objective": _objective_for(q) if active else "",
				}
			)
		)
	return out


## The current objective text for an active quest: the description of the step at the cursor (the next
## step to complete), or "" if the cursor is past the steps. Reads QuestService.state() for the cursor.
func _objective_for(quest: Dictionary) -> String:
	var qid := str(quest.get("id", ""))
	var cursor := int((_quests.state().get(qid, {}) as Dictionary).get("step_cursor", 0))
	var steps: Array = quest.get("steps", [])
	if cursor >= 0 and cursor < steps.size():
		return str((steps[cursor] as Dictionary).get("description", ""))
	return ""


# === accessors (for tests) ==================================================================== #


## The Bloomwarden standing line: "Bloomwardens — <Tier> (<value>)". Reads the GameController's
## authoritative run.flags standing + tier mapping; a gentle fallback when those accessors are absent.
func standing_text() -> String:
	return _standing_text()


func _standing_text() -> String:
	if _game == null:
		return "Bloomwardens — Stranger"
	var tier := "Stranger"
	var value := 0
	if _game.has_method("bloomwardens_tier"):
		tier = str(_game.call("bloomwardens_tier"))
	if _game.has_method("bloomwardens_standing"):
		value = int(_game.call("bloomwardens_standing"))
	return "Bloomwardens — %s (%d)" % [tier, value]


func entries() -> Array:
	return _entries.duplicate(true)


func quest_count() -> int:
	return _entries.size()


## W18: the memorial ledger the Graveyard tab renders (copy; tests read this).
func graveyard_entries() -> Array:
	return _graveyard.duplicate(true)


## The open ledger page id ("quests" | "graveyard").
func current_tab() -> String:
	return _tab


## Open the Graveyard page (rebuilds the UI onto the memorials). Public — tests/tab button drive it.
func show_graveyard() -> void:
	_tab = "graveyard"
	_build_ui()


## Open the errand log page (the default).
func show_quests() -> void:
	_tab = "quests"
	_build_ui()


# === UI (code-built, themed) ================================================================== #


func _build_ui() -> void:
	for child in get_children():
		# Detach BEFORE the deferred free: a tab switch rebuilds within the frame, and a stale
		# (queue_freed but still-attached) subtree would shadow the fresh page for find_child.
		remove_child(child)
		child.queue_free()
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var scrim := ColorRect.new()
	scrim.color = Color(0.05, 0.04, 0.07, 0.92)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)

	# The journal PAGE — an open grimoire page (ParchmentPanel); every label directly on the
	# page flips to ink text (TEXT_ON_PARCHMENT) or it vanishes against the paper. The quest
	# cards keep their raised-ink panels and parchment-tone text.
	var page := PanelContainer.new()
	page.name = "JournalPage"
	page.theme_type_variation = "ParchmentPanel"
	margin.add_child(page)

	var box := VBoxContainer.new()
	box.name = "JournalBox"
	box.add_theme_constant_override("separation", 12)
	page.add_child(box)

	var title := Label.new()
	title.name = "JournalTitle"
	title.text = "The Ledger"
	title.theme_type_variation = "TitleLabel"
	title.add_theme_color_override("font_color", GrimoirePalette.TEXT_ON_PARCHMENT)
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "What the marsh is keeping count of."
	subtitle.theme_type_variation = "MutedLabel"
	subtitle.add_theme_color_override("font_color", GrimoirePalette.TEXT_ON_PARCHMENT)
	box.add_child(subtitle)

	# FACTION STANDING — the quests nudge Bloomwarden standing; surface it so the player can read the
	# ledger they're climbing. Authoritative value + tier come from the GameController (run.flags).
	var standing := Label.new()
	standing.name = "StandingLine"
	standing.text = _standing_text()
	standing.add_theme_color_override("font_color", GrimoirePalette.TEXT_ON_PARCHMENT)
	box.add_child(standing)

	# W18: the ledger grows a second page — the Graveyard (memorials). Two tab verbs; the open
	# page's verb is disabled so the current tab reads at a glance.
	var tabs := HBoxContainer.new()
	tabs.name = "LedgerTabs"
	tabs.add_theme_constant_override("separation", 8)
	box.add_child(tabs)
	var quests_tab := Button.new()
	quests_tab.name = "QuestsTab"
	quests_tab.text = "Errands"
	quests_tab.disabled = _tab == "quests"
	quests_tab.pressed.connect(show_quests)
	tabs.add_child(quests_tab)
	var graveyard_tab := Button.new()
	graveyard_tab.name = "GraveyardTab"
	graveyard_tab.text = "The Graveyard (%d)" % _graveyard.size()
	graveyard_tab.disabled = _tab == "graveyard"
	graveyard_tab.pressed.connect(show_graveyard)
	tabs.add_child(graveyard_tab)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.name = "QuestList"
	_list.add_theme_constant_override("separation", 10)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	if _tab == "graveyard":
		_build_graveyard_list()
	else:
		_build_quest_list()

	var back := Button.new()
	back.name = "BackButton"
	back.text = "Back to Camp"
	back.pressed.connect(return_to_camp)
	box.add_child(back)
	# W1 focus pass: the Ledger is read-only, so its one verb (Back) owns focus.
	if back.is_inside_tree():
		back.grab_focus()


## The errand-log page contents (the pre-W18 body, unchanged).
func _build_quest_list() -> void:
	if _entries.is_empty():
		var empty := Label.new()
		empty.name = "EmptyNote"
		# W16a: the authored empty-state (VoiceBook empty.quests) with the old line as fallback.
		empty.text = VoiceBook.pick("empty.quests")
		if empty.text == "":
			empty.text = "No errands yet. Go let the marsh have its opinions."
		empty.theme_type_variation = "MutedLabel"
		empty.add_theme_color_override("font_color", GrimoirePalette.TEXT_ON_PARCHMENT)
		_list.add_child(empty)
	else:
		for entry: Dictionary in _entries:
			_list.add_child(_make_quest_card(entry))


## The Graveyard page (W18): one memorial per fallen coven creature — its plate as an INK
## SILHOUETTE, its one-of-one sigil, name, cause, and the parts its death funded. Read-only;
## the memorial dicts were shaped at burial (MortalityService) and never recomputed here.
func _build_graveyard_list() -> void:
	if _graveyard.is_empty():
		var empty := Label.new()
		empty.name = "EmptyNote"
		empty.text = VoiceBook.pick("empty.graveyard")
		if empty.text == "":
			empty.text = "No headstones. Either you're careful or you're new."
		empty.theme_type_variation = "MutedLabel"
		empty.add_theme_color_override("font_color", GrimoirePalette.TEXT_ON_PARCHMENT)
		_list.add_child(empty)
		return
	for i in _graveyard.size():
		var memorial_v: Variant = _graveyard[i]
		if memorial_v is Dictionary:
			_list.add_child(_make_memorial_card(memorial_v as Dictionary, i))


## One memorial: ink-silhouette plate + sigil + name / cause / parts-yielded lines.
func _make_memorial_card(memorial: Dictionary, index: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "MemorialCard_%d" % index
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	# The plate as an INK SILHOUETTE: the same bestiary cutout every screen shows this creature,
	# modulated to ink — a shape you recognize, a colour it no longer has.
	var creature_v: Variant = memorial.get("creature", {})
	var creature: Dictionary = creature_v if creature_v is Dictionary else {}
	var plate_tex := PortraitUtil.creature_plate(creature)
	if plate_tex != null:
		var plate := LivingPlate.new()
		plate.name = "MemorialPlate"
		plate.set_plate_size(Vector2(72, 72))
		plate.set_texture(plate_tex)
		plate.set_identity(str(memorial.get("species_id", "")), str(memorial.get("sigil", "")))
		plate.modulate = GrimoirePalette.INK
		row.add_child(plate)

	# Its one-of-one sigil — the mark it carried in life, now its headstone's seal.
	var mark := SigilGen.make_mark(
		str(memorial.get("species_id", "")),
		str(memorial.get("sigil", "")),
		str(memorial.get("force", "")),
		26
	)
	mark.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(mark)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	var name_label := Label.new()
	name_label.name = "MemorialName"
	name_label.text = str(memorial.get("name", "The Nameless"))
	column.add_child(name_label)
	var cause := Label.new()
	cause.name = "MemorialCause"
	cause.text = "%s — turn %d." % [str(memorial.get("cause", "")), int(memorial.get("turn", 0))]
	cause.theme_type_variation = "MutedLabel"
	column.add_child(cause)
	var parts: Array = memorial.get("parts", []) as Array
	if not parts.is_empty():
		var yielded := Label.new()
		yielded.name = "MemorialParts"
		var names: Array = []
		for p in parts:
			names.append(str(p).capitalize())
		yielded.text = "Its death funded: %s." % ", ".join(PackedStringArray(names))
		yielded.theme_type_variation = "MutedLabel"
		column.add_child(yielded)
	return card


## One quest card: name + a status badge (In Progress / Complete) + the current objective when active.
func _make_quest_card(entry: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "QuestCard_" + str(entry.get("id", ""))  # unique per quest (no auto-rename collision)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	card.add_child(col)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	var name_label := Label.new()
	name_label.text = str(entry.get("name", ""))
	header.add_child(name_label)
	var badge := Label.new()
	var done := str(entry.get("status", "")) == "done"
	badge.text = "✓ Complete" if done else "• In Progress"
	badge.add_theme_color_override(
		"font_color", GrimoirePalette.SUCCESS if done else GrimoirePalette.WARNING
	)
	header.add_child(badge)
	col.add_child(header)

	var objective := str(entry.get("objective", ""))
	if objective != "":
		var obj := Label.new()
		obj.text = "→ " + objective
		obj.theme_type_variation = "MutedLabel"
		col.add_child(obj)
	return card


## Return to the camp menu (the surface this screen is opened from). W17: as a router overlay this
## POPS one level (the camp beneath was never destroyed); the swap is the no-router fallback only.
func return_to_camp() -> void:
	var router := get_node_or_null("/root/UiRouter")
	if router != null and bool(router.call("pop_from", self)):
		return
	set_process(false)
	if _transition != null and _transition.has_method("change_scene_ritual"):
		await _transition.call("change_scene_ritual", CAMP_SCENE)
	elif is_inside_tree():
		get_tree().change_scene_to_file(CAMP_SCENE)


func _process(_delta: float) -> void:
	if _input == null or not _input.has_method("just_pressed"):
		return
	# Esc pops exactly one level (W17): a buried Ledger swallows the edge inside pop_from.
	if bool(_input.call("just_pressed", InputActions.CANCEL)):
		return_to_camp()
