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
	_add_button(box, "PartyButton", "Party & Grimoire", open_party)
	_add_button(box, "LabButton", "Lab", open_lab)
	_add_button(box, "ResumeButton", "Resume", resume)


## Show the lead creature's framed bestiary plate (when a run is live) — a face for "tend your coven".
## No-op headless / no-run (GameController autoload absent or party empty), so tests are unaffected.
func _add_lead_portrait(box: VBoxContainer) -> void:
	var gc := get_node_or_null("/root/GameController")
	if gc == null or not gc.has_method("run"):
		return
	var run: RunContext = gc.call("run")
	if run == null or not (run.party is Array) or (run.party as Array).is_empty():
		return
	var lead: Variant = (run.party as Array)[0]
	if not (lead is Dictionary):
		return
	var plate := SpeciesArt.plate(str((lead as Dictionary).get("species_id", "")))
	if plate == null:
		return
	var portrait := TextureRect.new()
	portrait.name = "LeadPortrait"
	portrait.custom_minimum_size = Vector2(118, 118)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture = plate
	var frame := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.11, 0.16)
	sb.set_corner_radius_all(4)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.725, 0.576, 0.247)  # BRASS
	sb.set_content_margin_all(3)
	frame.add_theme_stylebox_override("panel", sb)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	frame.add_child(portrait)
	box.add_child(frame)


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


## Resume play: emit `resumed` and close the menu (back to the overworld). The overlay simply frees
## itself; the overworld scene is untouched beneath it.
func resume() -> void:
	resumed.emit()
	if _input != null and _input.has_method("switch_context"):
		_input.call("switch_context", InputActions.CTX_OVERWORLD)
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
