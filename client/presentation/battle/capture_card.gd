extends Control
## CaptureCard (Wave 11 — "Capture Becomes a Moment") — the capture RESULT CARD: a full-rect ink
## scrim under a centered ParchmentPanel page carrying the caught creature's LivingPlate LARGE,
## its name resolving letter-by-letter (Cinzel via TitleLabel), its one-of-one SIGIL stamping in,
## and the authored VoiceBook capture line. Dismiss on ANY input — the battle's banner/rewards
## beneath are untouched, so closing the card resumes the exact pre-W11 flow.
##
## PRESENTATION layer, code-built (the battle screen is code-built + headless-tested). STATE
## MACHINE (the test surface): "revealing" -> "complete" -> "dismissed"; advance() is the
## any-input verb (skip the reveal first, dismiss second — never-wait-twice, plan tension 10).
## INSTANT/headless + reduce_motion contract: build(instant=true) lands fully COMPLETE with no
## tweens and no per-frame work, so every synchronous capture suite stays green.

signal dismissed

const STATE_REVEALING := "revealing"
const STATE_COMPLETE := "complete"
const STATE_DISMISSED := "dismissed"

const PLATE_SIZE := Vector2(260, 260)
const SIGIL_PX := 40
const REVEAL_CHAR_TIME := 0.05  # per name letter (skippable — the >0.4s reveal rule)
const SIGIL_STAMP_TIME := 0.3
const SCRIM_ALPHA := 0.72
const LINE_MAX_WIDTH := 420.0

var _state := STATE_DISMISSED  # inert until build()
var _name_label: Label = null
var _sigil: Control = null
var _plate: LivingPlate = null
var _reveal_tween: Tween = null


func _init() -> void:
	name = "CaptureCard"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # the card owns every click while active


## Assemble + start the card for a caught `creature` (the shaped creature_instance dict).
## `display_name` is the resolved name; `force` picks the sigil accent; `voice_line` the
## authored VoiceBook body. `instant` (headless / Swift Rites instant / reduce_motion) lands
## fully revealed with NO tweens.
func build(
	creature: Dictionary, display_name: String, force: String, voice_line: String, instant: bool
) -> void:
	var scrim := ColorRect.new()
	scrim.name = "CardScrim"
	var ink := GrimoirePalette.INK
	ink.a = SCRIM_ALPHA
	scrim.color = ink
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.name = "CardPanel"
	panel.theme_type_variation = "ParchmentPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := Label.new()
	title.name = "CardTitle"
	title.theme_type_variation = "TitleLabel"
	title.text = "CAUGHT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", GrimoirePalette.TEXT_ON_PARCHMENT)
	box.add_child(title)

	# The plate LARGE — the same LivingPlate identity every other screen renders for this
	# creature forever after (breath phase + tint + one-of-one mark are all identity-hashed).
	var plate_slot := CenterContainer.new()
	box.add_child(plate_slot)
	_plate = LivingPlate.new()
	_plate.name = "CardPlate"
	_plate.set_plate_size(PLATE_SIZE)
	_plate.set_texture(PortraitUtil.creature_plate(creature))
	_plate.set_tint(PortraitUtil.creature_tint(creature))
	var tag := PortraitUtil.instance_tag_of(creature)
	_plate.set_identity(str(creature.get("species_id", "")), tag)
	plate_slot.add_child(_plate)

	# Name + sigil row: the name resolves letter-by-letter; the mark stamps in beside it.
	var name_row := HBoxContainer.new()
	name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	name_row.add_theme_constant_override("separation", 10)
	box.add_child(name_row)
	_name_label = Label.new()
	_name_label.name = "CardName"
	_name_label.theme_type_variation = "TitleLabel"
	_name_label.text = display_name
	_name_label.add_theme_color_override("font_color", GrimoirePalette.TEXT_ON_PARCHMENT)
	name_row.add_child(_name_label)
	_sigil = SigilGen.make_mark(str(creature.get("species_id", "")), tag, force, SIGIL_PX)
	_sigil.name = "CardSigil"
	_sigil.custom_minimum_size = Vector2(SIGIL_PX, SIGIL_PX)
	_sigil.pivot_offset = Vector2(SIGIL_PX, SIGIL_PX) * 0.5
	name_row.add_child(_sigil)

	if voice_line != "":
		var line := Label.new()
		line.name = "CardVoiceLine"
		line.text = voice_line
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size = Vector2(LINE_MAX_WIDTH, 0)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.add_theme_color_override(
			"font_color", GrimoirePalette.on_parchment(GrimoirePalette.BRASS)
		)
		box.add_child(line)

	var hint := Label.new()
	hint.name = "CardHint"
	hint.text = "— any key continues —"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override(
		"font_color", GrimoirePalette.on_parchment(GrimoirePalette.TEXT_MUTED)
	)
	box.add_child(hint)

	if instant or not is_inside_tree():
		_finish_reveal()
		return
	_state = STATE_REVEALING
	_name_label.visible_characters = 0
	_sigil.modulate = Color(1, 1, 1, 0)
	_sigil.scale = Vector2(2.2, 2.2)
	_reveal_tween = create_tween()
	_reveal_tween.tween_property(
		_name_label,
		"visible_characters",
		display_name.length(),
		REVEAL_CHAR_TIME * float(display_name.length())
	)
	_reveal_tween.tween_property(_sigil, "modulate:a", 1.0, SIGIL_STAMP_TIME)
	(
		_reveal_tween
		. parallel()
		. tween_property(_sigil, "scale", Vector2.ONE, SIGIL_STAMP_TIME)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	_reveal_tween.tween_callback(_finish_reveal)


# === the any-input verb + state reads ========================================================== #


## The one input verb: a press during the reveal SKIPS it (>0.4s reveals are skippable), a press
## once complete DISMISSES the card. The screen's _process + the card's own gui_input both route
## here, so keyboard/gamepad/mouse all read as "any input".
func advance() -> void:
	if _state == STATE_REVEALING:
		skip_reveal()
	elif _state == STATE_COMPLETE:
		dismiss()


## Complete the letter-by-letter reveal + sigil stamp instantly.
func skip_reveal() -> void:
	if _state != STATE_REVEALING:
		return
	if _reveal_tween != null and _reveal_tween.is_valid():
		_reveal_tween.kill()
	_finish_reveal()


## Close the card: the battle's banner/Continue flow beneath resumes untouched.
func dismiss() -> void:
	if _state == STATE_DISMISSED:
		return
	if _reveal_tween != null and _reveal_tween.is_valid():
		_reveal_tween.kill()
	_state = STATE_DISMISSED
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	dismissed.emit()


## "revealing" | "complete" | "dismissed" (the W11 test surface).
func state() -> String:
	return _state


## True while the card is up and owning input.
func is_active() -> bool:
	return _state != STATE_DISMISSED and visible


func _gui_input(event: InputEvent) -> void:
	if not is_active():
		return
	var pressed := (
		(event is InputEventMouseButton and (event as InputEventMouseButton).pressed)
		or (event is InputEventKey and (event as InputEventKey).pressed)
		or (event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed)
	)
	if pressed:
		advance()
		accept_event()


# === internals ================================================================================= #


func _finish_reveal() -> void:
	if _name_label != null:
		_name_label.visible_characters = -1
	if _sigil != null:
		_sigil.modulate = Color.WHITE
		_sigil.scale = Vector2.ONE
	_state = STATE_COMPLETE
