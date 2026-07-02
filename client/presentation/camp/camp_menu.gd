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
const PARTY_SCENE := "res://presentation/party/party_screen.tscn"
const LAB_SCENE := "res://presentation/lab/lab_screen.tscn"
const CHARACTER_SCENE := "res://presentation/character/character_sheet.tscn"
const JOURNAL_SCENE := "res://presentation/journal/journal_screen.tscn"
const TRADER_SCENE := "res://presentation/camp/trader_shop.tscn"
const OVERWORLD_SCENE := "res://presentation/overworld/overworld_screen.tscn"

var _transition: Node = null
var _input: Node = null
var _toast: Node = null
## When false, navigation buttons (Party/Lab) emit their intent + return the path but skip the actual
## scene swap (lets a headless test assert the target without changing the SceneTree).
var _auto_navigate: bool = true


func _ready() -> void:
	var theme_service := get_node_or_null("/root/ThemeService")
	if theme_service != null and theme_service.has_method("apply_to"):
		theme_service.call("apply_to", self)
	_transition = get_node_or_null("/root/Transition")
	_input = get_node_or_null("/root/InputService")
	_toast = get_node_or_null("/root/Toast")
	# A camp/pause menu is a Menu input context (D4).
	if _input != null and _input.has_method("switch_context"):
		_input.call("switch_context", InputActions.CTX_MENU)
	_build()


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
	var party_button := _add_button(box, "PartyButton", "Party & Grimoire", open_party)
	_add_button(box, "SelfButton", "The Self", open_self)
	_add_button(box, "JournalButton", "The Ledger", open_journal)
	_add_button(box, "TraderButton", "The Trader", open_trader)
	_add_button(box, "LabButton", "Lab", open_lab)
	_add_button(box, "ResumeButton", "Resume", resume)
	# W1 focus pass: the first camp verb owns focus (arrow keys walk the column natively).
	if party_button.is_inside_tree():
		party_button.grab_focus()


## Show the lead creature's framed bestiary plate (when a run is live) — a face for "tend your coven".
## No-op headless / no-run (GameController autoload absent or party empty), so tests are unaffected.
func _add_lead_portrait(box: VBoxContainer) -> void:
	var gc := get_node_or_null("/root/GameController")
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
## the swap). Skips the real push/swap when auto-navigate is off.
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


## Open the Trader (W17/C16 — the minimal drachma shop, a pushed overlay). Returns the target path.
func open_trader() -> String:
	_navigate(TRADER_SCENE)
	return TRADER_SCENE


## The scene path the Lab button targets (a SIBLING track owns the screen). Always returns the path
## so a test can assert the wiring even before the sibling screen exists.
func lab_scene_path() -> String:
	return LAB_SCENE


## True if the Lab screen scene actually exists at runtime (the sibling track has landed it).
func lab_available() -> bool:
	return ResourceLoader.exists(LAB_SCENE)


## Open the Lab (sibling track's screen). GUARDED: if the scene is absent, toast a gentle notice and
## stay in camp instead of erroring. The Lab STAYS a full-screen SCENE SWAP (Geneticist veto — never
## a router overlay), so every router overlay is unwound first (nothing may float over the Lab).
## Returns the target path on success, "" when guarded off.
func open_lab() -> String:
	if not lab_available():
		_notify("The Lab is not yet raised.")
		return ""
	if _auto_navigate:
		# Fire the swap on the TRANSITION autoload directly (never awaited through this menu — the
		# pop_all below frees it, and a coroutine must not resume on a freed screen), then unwind.
		if _transition != null and _transition.has_method("change_scene_ritual"):
			_transition.call("change_scene_ritual", LAB_SCENE)
		elif is_inside_tree():
			get_tree().change_scene_to_file(LAB_SCENE)
		var router := _router()
		if router != null and router.has_method("pop_all"):
			router.call("pop_all")
	return LAB_SCENE


## Resume play: emit `resumed` and close the menu — back to the LIVE overworld. W17: as a ROUTER
## overlay the menu pops its own level (the router restores the pre-camp input context; the
## overworld beneath was never swapped away, so a black screen is structurally unreachable). The
## legacy fallbacks (root-scene guard / bare queue_free) remain for degraded/standalone contexts.
func resume() -> void:
	var router := _router()
	# Esc pops EXACTLY one level (W17): while another overlay sits ABOVE this menu, the resume verb
	# is SWALLOWED — the page on top owns the edge, and `resumed` must not fire for a buried camp.
	if router != null and bool(router.call("owns", self)) and not bool(router.call("is_top", self)):
		return
	resumed.emit()
	if router != null and bool(router.call("pop_from", self)):
		return
	if _input != null and _input.has_method("switch_context"):
		_input.call("switch_context", InputActions.CTX_OVERWORLD)
	if is_inside_tree() and get_tree().current_scene == self:
		_swap_scene(OVERWORLD_SCENE)
		return
	queue_free()


# === input ==================================================================================== #


func _process(_delta: float) -> void:
	if _input == null or not _input.has_method("just_pressed"):
		return
	# Cancel/pause closes the camp menu (matches the overworld toggle); a buried menu swallows the
	# edge inside resume().
	if bool(_input.call("just_pressed", InputActions.CANCEL)):
		resume()


# === internals ================================================================================ #


## The screen-router autoload, or null (degraded/standalone contexts fall back to scene swaps).
func _router() -> Node:
	return get_node_or_null("/root/UiRouter")


## Navigate to a sibling MENU page. W17: pushed as a router overlay over the persistent overworld
## (back = pop); the scene-swap path survives only as the no-router fallback.
func _navigate(scene_path: String) -> void:
	if not _auto_navigate:
		return
	var router := _router()
	if router != null and router.has_method("push_scene"):
		router.call("push_scene", scene_path)
		return
	_swap_scene(scene_path)


## A REAL scene swap (the Lab + legacy fallbacks) through the ritual Transition when available.
func _swap_scene(scene_path: String) -> void:
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
