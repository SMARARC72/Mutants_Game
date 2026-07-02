class_name ThresholdScreen
extends Control
## ThresholdScreen (E1b "Eleven Regions") — the RITUAL-CIRCLE fast-travel overlay (design §3.5:
## the Threshold network). PRESENTATION layer, CODE-BUILT in _ready() so it is unit-testable
## headless: a test instantiates it with an injected GameController, reads the region rows'
## LOCK STATE, drives travel(), and asserts the run moved — without rendering.
##
## Pushed by the overworld through the UiRouter (the W17 overlay pattern — the overworld stays
## live beneath; back = pop, never a scene swap) when the tamer interacts beside the region's
## WAYGATE structure (OverworldStructures.ROLE_WAYGATE — the portal by the spawn field).
##
## One row per region in the world catalog (RegionCatalog — all eleven), each in one of three
## states: HERE (the active region, disabled), OPEN (travel on press), or SEALED (disabled, with
## the region's authored gate hint — story flags from the quest act gates open it; verdant +
## threshold never seal). Traveling delegates to GameController.travel_to_region and emits
## `traveled`; the overworld owns the rebuild + the save.

## A travel was accepted: the run's active region is already switched when this fires.
signal traveled(region_id: String)
## The overlay closed without traveling (cancel / close pressed).
signal closed

const InputActions := preload("res://infrastructure/input/input_actions.gd")
const RegionCatalogScript := preload("res://application/overworld/region_catalog.gd")
const RegionTravelScript := preload("res://application/overworld/region_travel.gd")

var _game: Node = null
var _input: Node = null
var _toast: Node = null
## region id -> its row Button (rebuilt by _build; read by tests via row_for/regions).
var _rows: Dictionary = {}


func _ready() -> void:
	var theme_service := get_node_or_null("/root/ThemeService")
	if theme_service != null and theme_service.has_method("apply_to"):
		theme_service.call("apply_to", self)
	if _game == null:
		_game = get_node_or_null("/root/GameController")
	_input = get_node_or_null("/root/InputService")
	_toast = get_node_or_null("/root/Toast")
	# The travel circle is a menu surface (D4): arrows walk the region column, not the tamer.
	if _input != null and _input.has_method("switch_context"):
		_input.call("switch_context", InputActions.CTX_MENU)
	_build()


## Inject the GameController (tests / non-autoload contexts). Call BEFORE add_child.
func set_game(game: Node) -> void:
	_game = game


func _build() -> void:
	for child in get_children():
		child.queue_free()
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# A scrim so the overworld dims behind the circle (modal, mouse-blocking — the camp pattern).
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
	panel.name = "ThresholdPanel"
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.name = "ThresholdBox"
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size = Vector2(420, 0)
	panel.add_child(box)

	var title := Label.new()
	title.text = "The Threshold Network"
	title.theme_type_variation = "TitleLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.name = "TransitLine"
	subtitle.text = VoiceBook.pick("travel.transit")
	subtitle.theme_type_variation = "MutedLabel"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.custom_minimum_size = Vector2(420, 0)
	subtitle.visible = subtitle.text != ""
	box.add_child(subtitle)

	_rows = {}
	var first_open: Button = null
	for region_id: String in RegionCatalogScript.region_ids():
		var row := _build_row(str(region_id))
		box.add_child(row)
		_rows[str(region_id)] = row
		if first_open == null and not row.disabled:
			first_open = row
	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "Step back"
	close_button.pressed.connect(close)
	box.add_child(close_button)
	if first_open != null and first_open.is_inside_tree():
		first_open.grab_focus()


## One region row: "<title> · T1-T2" plus its state suffix. HERE + SEALED rows are disabled;
## sealed rows carry the authored gate hint as their second line.
func _build_row(region_id: String) -> Button:
	var row := Button.new()
	row.name = "Region_%s" % region_id
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var band: Array = RegionCatalogScript.tier_band(region_id)
	var label := RegionCatalogScript.title(region_id)
	if not band.is_empty():
		label += "  ·  %s" % "-".join(PackedStringArray(band))
	var here := _game != null and str(_game.call("active_region")) == region_id
	var open := _unlocked(region_id)
	if here:
		row.text = "%s   — you are here" % label
		row.disabled = true
	elif open:
		row.text = label
		row.pressed.connect(travel.bind(region_id))
	else:
		var hint := RegionCatalogScript.gate_hint(region_id)
		row.text = "%s   — sealed" % label
		if hint != "":
			row.tooltip_text = hint
		row.disabled = true
	return row


## The lock read for a region (RegionTravel owns the rule; no run = everything sealed).
func _unlocked(region_id: String) -> bool:
	return RegionTravelScript.unlocked(_run(), region_id)


## The live RunContext through the injected game, or null (everything sealed, travel refused).
func _run() -> RunContext:
	if _game == null or not _game.has_method("run"):
		return null
	return _game.call("run")


## The overlay's region states, for tests + the HUD: [{id, title, here, unlocked}] in catalog order.
func regions() -> Array:
	var out: Array = []
	var active := str(_game.call("active_region")) if _game != null else ""
	for region_id: String in RegionCatalogScript.region_ids():
		(
			out
			. append(
				{
					"id": str(region_id),
					"title": RegionCatalogScript.title(str(region_id)),
					"here": str(region_id) == active,
					"unlocked": _unlocked(str(region_id)),
				}
			)
		)
	return out


## The row Button for a region id, or null (tests assert disabled/lock states through it).
func row_for(region_id: String) -> Button:
	var row: Variant = _rows.get(region_id, null)
	return row if row is Button else null


## Ride the circle: travel to `region_id` through RegionTravel (over the game's live run). On
## acceptance the run's active region is switched, the transit line toasts, `traveled` fires
## (the overworld rebuilds + saves), and the overlay closes itself. A refused hop (locked /
## already there / no run) toasts the refusal and stays open. Returns the acceptance.
func travel(region_id: String) -> bool:
	if not RegionTravelScript.travel(_run(), region_id):
		_notify("The circle refuses. This door is not yours yet.")
		return false
	var line := VoiceBook.pick("travel.transit")
	if line != "":
		_notify(line)
	traveled.emit(region_id)
	_close_overlay()
	return true


## Close without traveling: pop our router level (or free standalone) and tell the overworld.
func close() -> void:
	closed.emit()
	_close_overlay()


func _close_overlay() -> void:
	var router := get_node_or_null("/root/UiRouter")
	if router != null and bool(router.call("pop_from", self)):
		return
	if _input != null and _input.has_method("switch_context"):
		_input.call("switch_context", InputActions.CTX_OVERWORLD)
	# Standalone fallback (no router): free the local overlay CanvasLayer with us, not just the
	# screen — a bare layer left behind would shadow the next push's name.
	var layer := get_parent()
	if layer is CanvasLayer:
		layer.queue_free()
	else:
		queue_free()


func _process(_delta: float) -> void:
	if _input == null or not _input.has_method("just_pressed"):
		return
	if bool(_input.call("just_pressed", InputActions.CANCEL)):
		# Esc pops exactly one level (W17): a buried circle swallows the edge.
		var router := get_node_or_null("/root/UiRouter")
		if (
			router != null
			and bool(router.call("owns", self))
			and not bool(router.call("is_top", self))
		):
			return
		close()


func _notify(message: String) -> void:
	if _toast != null and _toast.has_method("show"):
		_toast.call("show", {"title": message, "body": "", "sound": "hum"})
