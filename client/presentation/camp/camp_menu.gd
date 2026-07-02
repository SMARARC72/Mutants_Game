extends Control
## CampMenu (Phase 5 · Slice 3b) — the camp / pause menu opened from the overworld. PRESENTATION
## layer, CODE-BUILT in _ready() (a thin .tscn just loads this script) so it is unit-testable
## headless: a test instantiates it, asserts the buttons exist, drives open()/resume()/Lab, and
## checks the target scene path WITHOUT rendering.
##
## Buttons (design §4 — the grimoire "camp" page):
##   * Party   — open the party / grimoire screen (creature management + leveling + gear),
##   * Lab     — scene-change to res://presentation/lab/lab_screen.tscn (a SIBLING track owns that
##               screen). GUARDED: if the scene is absent at runtime, the button still exists but
##               toasts "the Lab is not yet raised" instead of erroring (the slice never soft-locks).
##   * Resume  — close the menu (back to the overworld) via the `resumed` signal + queue_free.
##
## It only ever talks to the FACADES (ThemeService / Transition / InputService / Toast), never an
## addon directly — mirroring the other Slice 5 screens. Injection-guarded so headless tests drive it.

## Emitted when the player picks Resume (the overworld can react without a scene swap). A test/
## observer listens to assert the close happened.
signal resumed

const InputActions := preload("res://infrastructure/input/input_actions.gd")
const GameControllerScript := preload("res://application/game/game_controller.gd")
const PARTY_SCENE := "res://presentation/party/party_screen.tscn"
const LAB_SCENE := "res://presentation/lab/lab_screen.tscn"
const CHARACTER_SCENE := "res://presentation/character/character_sheet.tscn"
const JOURNAL_SCENE := "res://presentation/journal/journal_screen.tscn"
const OVERWORLD_SCENE := "res://presentation/overworld/overworld_screen.tscn"
const TITLE_SCENE := "res://presentation/screens/main_menu.tscn"

## The camp currency strip (W18): each run wallet with its authored icon, in ledger order.
const CURRENCY_ICONS := {
	"drachma": "res://assets/icons/currencies/drachma.svg",
	"essence": "res://assets/icons/currencies/essence.svg",
	"ichor": "res://assets/icons/currencies/ichor.svg",
}

var _game: Node = null
var _transition: Node = null
var _input: Node = null
var _toast: Node = null
## When false, navigation buttons (Party/Lab) emit their intent + return the path but skip the actual
## scene swap (lets a headless test assert the target without changing the SceneTree).
var _auto_navigate: bool = true
## currency id -> value Label (updated in place after a Rest debits the wallet).
var _currency_labels: Dictionary = {}


func _ready() -> void:
	var theme_service := get_node_or_null("/root/ThemeService")
	if theme_service != null and theme_service.has_method("apply_to"):
		theme_service.call("apply_to", self)
	if _game == null:
		_game = get_node_or_null("/root/GameController")
	_transition = get_node_or_null("/root/Transition")
	_input = get_node_or_null("/root/InputService")
	_toast = get_node_or_null("/root/Toast")
	# A camp/pause menu is a Menu input context (D4).
	if _input != null and _input.has_method("switch_context"):
		_input.call("switch_context", InputActions.CTX_MENU)
	_build()


## Inject the GameController (tests / non-autoload contexts). Call BEFORE add_child.
func set_game(game: Node) -> void:
	_game = game


## Disable the automatic scene swap on Party/Lab (tests). The buttons still emit + return the path.
func set_auto_navigate(enabled: bool) -> void:
	_auto_navigate = enabled


func _build() -> void:
	for child in get_children():
		child.queue_free()
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# A scrim so the overworld dims behind the camp page (mouse-blocking — it is a modal pause).
	var scrim := ColorRect.new()
	scrim.name = "Scrim"
	scrim.color = Color(0.05, 0.04, 0.07, 0.72)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.name = "CampPanel"
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.name = "CampBox"
	box.add_theme_constant_override("separation", 14)
	box.custom_minimum_size = Vector2(320, 0)
	panel.add_child(box)

	var title := Label.new()
	title.text = "Camp"
	title.theme_type_variation = "TitleLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Tend your coven before the next descent."
	subtitle.theme_type_variation = "MutedLabel"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)

	_add_lead_portrait(box)
	_add_currency_strip(box)
	var party_button := _add_button(box, "PartyButton", "Party & Grimoire", open_party)
	_add_button(box, "SelfButton", "The Self", open_self)
	_add_button(box, "JournalButton", "The Ledger", open_journal)
	_add_button(box, "LabButton", "Lab", open_lab)
	# W18 camp truth: Rest heals the wounds the fights left (for a small essence fee) and
	# Save & Quit hands the run back to the title THROUGH the witnessed save path.
	_add_button(
		box, "RestButton", "Rest (%d essence)" % GameControllerScript.REST_ESSENCE_FEE, rest
	)
	_add_button(box, "SaveQuitButton", "Save & Quit to Title", save_and_quit)
	_add_button(box, "ResumeButton", "Resume", resume)
	# W1 focus pass: the first camp verb owns focus (arrow keys walk the column natively).
	if party_button.is_inside_tree():
		party_button.grab_focus()


## The run's three wallets (drachma / essence / ichor) with their authored icons — the camp is
## where you count what the descent has paid. No-op without a run (headless menu tests).
func _add_currency_strip(box: VBoxContainer) -> void:
	_currency_labels = {}
	var run: RunContext = _run_of()
	if run == null:
		return
	var strip := HBoxContainer.new()
	strip.name = "CurrencyStrip"
	strip.add_theme_constant_override("separation", 18)
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(strip)
	for currency: String in CURRENCY_ICONS:
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 5)
		strip.add_child(cell)
		var icon_path := str(CURRENCY_ICONS[currency])
		if ResourceLoader.exists(icon_path):
			var icon := TextureRect.new()
			icon.texture = load(icon_path)
			icon.custom_minimum_size = Vector2(18, 18)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.tooltip_text = currency.capitalize()
			cell.add_child(icon)
		var value := Label.new()
		value.name = "%sValue" % currency.capitalize()
		value.text = str(run.get(currency))
		value.theme_type_variation = "MutedLabel"
		cell.add_child(value)
		_currency_labels[currency] = value


## Refresh the wallet labels in place (after Rest debits essence).
func _refresh_currencies() -> void:
	var run: RunContext = _run_of()
	if run == null:
		return
	for currency: String in _currency_labels:
		var label: Label = _currency_labels[currency]
		if is_instance_valid(label):
			label.text = str(run.get(currency))


func _run_of() -> RunContext:
	if _game == null or not _game.has_method("run"):
		return null
	return _game.call("run")


## Show the lead creature's framed bestiary plate (when a run is live) — a face for "tend your coven".
## No-op headless / no-run (GameController autoload absent or party empty), so tests are unaffected.
func _add_lead_portrait(box: VBoxContainer) -> void:
	var gc := _game
	if gc == null or not gc.has_method("run"):
		return
	var run: RunContext = gc.call("run")
	if run == null or not (run.party is Array) or (run.party as Array).is_empty():
		return
	# The lead is the ACTIVE creature (the player may have set a non-first member as lead), not party[0].
	var party: Array = run.party
	var idx := 0
	if gc.has_method("active_creature_index"):
		idx = clampi(int(gc.call("active_creature_index")), 0, party.size() - 1)
	var lead: Variant = party[idx]
	if not (lead is Dictionary):
		return
	# Hybrids render their dominant parent's plate + the deterministic corruption tint (PortraitUtil),
	# so camp shows the same face party/lab/battle do. Wave 9: the lead is a LivingPlate (it
	# breathes while you tend the coven) and its one-of-one sigil rides the frame corner.
	var lead_dict := lead as Dictionary
	var plate := PortraitUtil.creature_plate(lead_dict)
	if plate == null:
		return
	var portrait := LivingPlate.new()
	portrait.name = "LeadPortrait"
	portrait.set_plate_size(Vector2(118, 118))
	portrait.set_texture(plate)
	portrait.set_tint(PortraitUtil.creature_tint(lead_dict))
	portrait.set_identity(
		str(lead_dict.get("species_id", "")), PortraitUtil.instance_tag_of(lead_dict)
	)
	var frame := PortraitUtil.framed(portrait, lead_dict, _lead_force(gc, lead_dict))
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(frame)


## The lead's primary force (its sigil accent), read through the catalog when available.
func _lead_force(gc: Node, lead: Dictionary) -> String:
	if gc == null or not gc.has_method("catalog"):
		return ""
	var catalog: SpeciesCatalog = gc.call("catalog")
	if catalog == null:
		return ""
	var species: SpeciesData = catalog.get_by_id(str(lead.get("species_id", "")))
	return species.force_primary if species != null else ""


func _add_button(
	parent: VBoxContainer, node_name: String, text: String, handler: Callable
) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	parent.add_child(button)
	button.pressed.connect(handler)
	return button


# === navigation =============================================================================== #


## Open the party / grimoire screen. Returns the target scene path (so a test can assert it without
## the swap). Skips the real swap when auto-navigate is off.
func open_party() -> String:
	_navigate(PARTY_SCENE)
	return PARTY_SCENE


## Open the character sheet (the player's morality / Apotheosis trajectory). Returns the target path.
func open_self() -> String:
	_navigate(CHARACTER_SCENE)
	return CHARACTER_SCENE


## Open the quest journal (the Ledger — active/done quests). Returns the target path.
func open_journal() -> String:
	_navigate(JOURNAL_SCENE)
	return JOURNAL_SCENE


## The scene path the Lab button targets (a SIBLING track owns the screen). Always returns the path
## so a test can assert the wiring even before the sibling screen exists.
func lab_scene_path() -> String:
	return LAB_SCENE


## True if the Lab screen scene actually exists at runtime (the sibling track has landed it).
func lab_available() -> bool:
	return ResourceLoader.exists(LAB_SCENE)


## Open the Lab (sibling track's screen). GUARDED: if the scene is absent, toast a gentle notice and
## stay in camp instead of erroring. Returns the target path on success, "" when guarded off.
func open_lab() -> String:
	if not lab_available():
		_notify("The Lab is not yet raised.")
		return ""
	_navigate(LAB_SCENE)
	return LAB_SCENE


## W18 camp Rest: heal every persisted wound + clear the scars for a small essence fee (the
## GameController owns the bookkeeping), persist through the witnessed save path, and refresh
## the wallet strip. Returns the rest report ({ok, healed, fee, reason}) so tests can assert it.
func rest() -> Dictionary:
	if _game == null or not _game.has_method("rest_at_camp"):
		return {"ok": false, "healed": 0, "fee": 0, "reason": "no game"}
	var report: Dictionary = _game.call("rest_at_camp")
	if bool(report.get("ok", false)):
		_persist()
		_refresh_currencies()
		var healed := int(report.get("healed", 0))
		if healed > 0:
			_notify("The coven sleeps. %d wound(s) close." % healed)
		else:
			_notify("The coven sleeps. Nothing needed mending — this time.")
	elif str(report.get("reason", "")) == "essence":
		_notify("Not enough essence. Rest costs %d." % int(report.get("fee", 0)))
	return report


## W18 Save & Quit: persist through the witnessed save path, then hand the run back to the title
## screen. Returns the target scene path (auto-navigate off lets a test assert without the swap).
func save_and_quit() -> String:
	_persist()
	_navigate(TITLE_SCENE)
	return TITLE_SCENE


## Persist through request_save when the game offers it (SaveSentry surfaces the outcome);
## fall back to the bare save_run for older/stub game nodes.
func _persist() -> void:
	if _game == null:
		return
	if _game.has_method("request_save"):
		_game.call("request_save")
	elif _game.has_method("save_run"):
		_game.call("save_run")


## Resume play: emit `resumed` and close the menu (back to the overworld). As an OVERLAY the menu
## simply frees itself (the overworld is untouched beneath it) — but when the camp is the ROOT
## scene (returned to via a Party/Lab scene swap) freeing would leave a black screen, so it swaps
## back to the overworld instead. Interim soft-lock guard; the screen router (W17) replaces it.
func resume() -> void:
	resumed.emit()
	if _input != null and _input.has_method("switch_context"):
		_input.call("switch_context", InputActions.CTX_OVERWORLD)
	if is_inside_tree() and get_tree().current_scene == self:
		_navigate(OVERWORLD_SCENE)
		return
	queue_free()


# === input ==================================================================================== #


func _process(_delta: float) -> void:
	if _input == null or not _input.has_method("just_pressed"):
		return
	# Cancel/pause closes the camp menu (matches the overworld toggle).
	if bool(_input.call("just_pressed", InputActions.CANCEL)):
		resume()


# === internals ================================================================================ #


func _navigate(scene_path: String) -> void:
	if not _auto_navigate:
		return
	if _transition != null and _transition.has_method("change_scene_ritual"):
		await _transition.call("change_scene_ritual", scene_path)
	elif is_inside_tree():
		get_tree().change_scene_to_file(scene_path)


func _notify(message: String) -> void:
	if _toast != null and _toast.has_method("show"):
		_toast.call("show", {"title": message, "body": "", "sound": "chime"})
	else:
		push_warning("CampMenu: %s" % message)
