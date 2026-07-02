extends Control
## TraderShop (Wave 17 · C16) — the minimal camp Trader: a ParchmentPanel shelf of 2-3 items sold
## for drachma. PRESENTATION layer, CODE-BUILT (thin .tscn loads this) so it is headless-testable:
## inject a GameController, call build_from_game() + buy(), assert the debit/credit WITHOUT
## rendering. All prices/stock come from ShopService (single source — no UI math); the purchase
## debits run.drachma and credits the run's InventoryAdapter, then persists via save_run.
## Pushed as a UiRouter overlay from the camp menu; back pops exactly one level.

const InputActions := preload("res://infrastructure/input/input_actions.gd")
const ShopServiceScript := preload("res://application/game/shop_service.gd")
const DRACHMA_ICON := "res://assets/icons/currencies/drachma.svg"

var _game: Node = null
var _input: Node = null
var _auto_build: bool = true

var _drachma_label: Label = null
var _shelf: VBoxContainer = null
var _ledger_label: Label = null
var _last_ledger: Dictionary = {}


func _ready() -> void:
	if _game == null:
		_game = get_node_or_null("/root/GameController")
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


## Build the shelf from the active run. Public so a test drives it headlessly.
func build_from_game() -> void:
	if _game == null:
		return
	_build_ui()
	_refresh()


# === player actions (headless-testable; the buttons call the same method) ===================== #


## BUY one unit of `stock_id` (a ShopService STOCK id). Debits drachma, credits the inventory,
## persists, refreshes the shelf. Returns the ShopService ledger.
func buy(stock_id: String) -> Dictionary:
	var run := _run()
	if run == null:
		return {"ok": false, "reason": "no_run"}
	var gc: GearCatalog = _game.call("gear_catalog")
	var inventory: InventoryAdapter = _game.call("inventory")
	var ledger := ShopServiceScript.buy(run, inventory, stock_id, gc)
	_last_ledger = ledger
	if bool(ledger.get("ok", false)):
		if _game.has_method("save_run"):
			_game.call("save_run")
		_show_ledger(_voice_line("shop.buy", int(ledger.get("price", 0))))
	else:
		_show_ledger(_voice_line("shop.cant_afford", int(ledger.get("short", 0))))
	_refresh()
	return ledger


## Close the shop: pop the router level holding it, else free (standalone/local overlay).
func close() -> void:
	var router := get_node_or_null("/root/UiRouter")
	if router != null and bool(router.call("pop_from", self)):
		return
	queue_free()


func _process(_delta: float) -> void:
	if _input == null or not _input.has_method("just_pressed"):
		return
	if bool(_input.call("just_pressed", InputActions.CANCEL)):
		close()


# === accessors (tests) ======================================================================== #


func last_ledger() -> Dictionary:
	return _last_ledger.duplicate(true)


func drachma_text() -> String:
	return _drachma_label.text if _drachma_label != null else ""


func stock_row_count() -> int:
	return _shelf.get_child_count() if _shelf != null else 0


# === UI (code-built, parchment) =============================================================== #


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var scrim := ColorRect.new()
	scrim.name = "Scrim"
	scrim.color = Color(0.05, 0.04, 0.07, 0.78)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var page := PanelContainer.new()
	page.name = "TraderPage"
	page.theme_type_variation = "ParchmentPanel"
	page.custom_minimum_size = Vector2(560, 0)
	center.add_child(page)

	var box := VBoxContainer.new()
	box.name = "TraderBox"
	box.add_theme_constant_override("separation", 10)
	page.add_child(box)

	var title := Label.new()
	title.name = "TraderTitle"
	title.text = "The Trader"
	title.theme_type_variation = "TitleLabel"
	_ink(title)
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = VoiceBook.pick("shop.browse")
	if subtitle.text == "":
		subtitle.text = "Looking's free. Everything after looking has a number on it."
	subtitle.theme_type_variation = "MutedLabel"
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ink(subtitle)
	box.add_child(subtitle)

	# The purse: drachma icon + live count (colour+icon pairing; authored tooltip).
	var purse := HBoxContainer.new()
	purse.name = "PurseRow"
	purse.add_theme_constant_override("separation", 6)
	purse.tooltip_text = VoiceBook.pick("ui.tooltip.drachma")
	if ResourceLoader.exists(DRACHMA_ICON):
		var icon := TextureRect.new()
		icon.texture = load(DRACHMA_ICON)
		icon.custom_minimum_size = Vector2(18, 18)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate = GrimoirePalette.on_parchment(GrimoirePalette.BRASS_BRIGHT)
		purse.add_child(icon)
	_drachma_label = Label.new()
	_drachma_label.name = "DrachmaLabel"
	_ink(_drachma_label)
	purse.add_child(_drachma_label)
	box.add_child(purse)

	_shelf = VBoxContainer.new()
	_shelf.name = "Shelf"
	_shelf.add_theme_constant_override("separation", 6)
	box.add_child(_shelf)

	_ledger_label = Label.new()
	_ledger_label.name = "ShopLedger"
	_ledger_label.theme_type_variation = "MutedLabel"
	_ledger_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ink(_ledger_label)
	box.add_child(_ledger_label)

	var back := Button.new()
	back.name = "BackButton"
	back.text = "Back to camp"
	back.pressed.connect(close)
	box.add_child(back)
	if back.is_inside_tree():
		back.grab_focus()


## Rebuild the shelf rows + purse from the live run (after every purchase).
func _refresh() -> void:
	var run := _run()
	if run == null or _shelf == null:
		return
	if _drachma_label != null:
		_drachma_label.text = "%d ₯" % run.drachma
	for child in _shelf.get_children():
		child.queue_free()
	var gc: GearCatalog = _game.call("gear_catalog")
	for entry: Dictionary in ShopServiceScript.stock(gc):
		_shelf.add_child(_stock_row(entry, run.drachma))


## One shelf row: name + blurb tooltip + price + Buy (disabled when the purse is short —
## disabled-with-reason, never hidden).
func _stock_row(entry: Dictionary, drachma: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Stock_" + str(entry.get("id", ""))
	row.add_theme_constant_override("separation", 10)
	row.tooltip_text = str(entry.get("blurb", ""))
	var name_label := Label.new()
	name_label.text = str(entry.get("name", ""))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ink(name_label)
	row.add_child(name_label)
	var price := int(entry.get("price", 0))
	var price_label := Label.new()
	price_label.text = "%d ₯" % price
	_ink(price_label)
	row.add_child(price_label)
	var btn := Button.new()
	btn.name = "BuyButton_" + str(entry.get("id", ""))
	btn.text = "Buy"
	btn.disabled = drachma < price
	if btn.disabled:
		btn.tooltip_text = "Short by %d ₯." % (price - drachma)
	var sid := str(entry.get("id", ""))
	btn.pressed.connect(func() -> void: buy(sid))
	row.add_child(btn)
	return row


# === helpers ================================================================================== #


## An authored merchant line with its "{n}" drachma placeholder filled. Falls back to plain copy.
func _voice_line(key: String, n: int) -> String:
	var line := VoiceBook.pick(key)
	if line == "":
		line = "Sold." if key == "shop.buy" else "Short by {n}₯."
	return line.replace("{n}", str(n))


func _show_ledger(text: String) -> void:
	if _ledger_label != null:
		_ledger_label.text = text


func _ink(label: Label) -> void:
	label.add_theme_color_override("font_color", GrimoirePalette.TEXT_ON_PARCHMENT)


func _run() -> RunContext:
	if _game == null or not _game.has_method("run"):
		return null
	return _game.call("run")
