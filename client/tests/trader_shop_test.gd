extends GdUnitTestSuite
## Wave 17 · C16 — the minimal camp TRADER, driven HEADLESSLY.
##   * the shelf lists the ShopService STOCK (a gear piece, a reagent, a heal voucher) with prices;
##   * a purchase DEBITS run.drachma and CREDITS the run's InventoryAdapter (atomic);
##   * an empty purse fails with "insufficient_drachma" and changes nothing;
##   * a bought gear piece is genuinely OWNED — the party equip gate accepts it;
##   * the camp menu carries the Trader entry.

const GameControllerScript := preload("res://application/game/game_controller.gd")
const FakeDalScript := preload("res://infrastructure/dal/fake_dal.gd")
const TraderShopScript := preload("res://presentation/camp/trader_shop.gd")
const CampMenuScript := preload("res://presentation/camp/camp_menu.gd")
const ShopServiceScript := preload("res://application/game/shop_service.gd")
const GearServiceScript := preload("res://application/game/gear_service.gd")

const TEST_SEED := 0x7EAD_E201


func _make_game(drachma: int) -> Node:
	var gc: Node = GameControllerScript.new()
	add_child(gc)
	gc.call("configure", FakeDalScript.make())
	var run: RunContext = gc.call("new_run", TEST_SEED)
	run.drachma = drachma
	return gc


func _make_shop(gc: Node) -> Control:
	var shop: Control = TraderShopScript.new()
	shop.call("set_game", gc)
	shop.call("set_auto_build", false)
	add_child(shop)
	shop.call("build_from_game")
	return shop


func test_shelf_lists_the_stock_with_prices() -> void:
	var gc := _make_game(100)
	var shop := _make_shop(gc)
	assert_int(int(shop.call("stock_row_count"))).is_equal(ShopServiceScript.STOCK.size())
	for entry: Dictionary in ShopServiceScript.STOCK:
		assert_object(shop.find_child("Stock_%s" % str(entry["id"]), true, false)).is_not_null()
	# The purse shows the live drachma count.
	assert_bool(str(shop.call("drachma_text")).contains("100")).is_true()
	shop.queue_free()
	gc.queue_free()


func test_purchase_debits_drachma_and_credits_inventory() -> void:
	var gc := _make_game(100)
	var run: RunContext = gc.call("run")
	var shop := _make_shop(gc)
	var entry: Dictionary = ShopServiceScript.entry_of("stock_gear", gc.call("gear_catalog"))
	var price := int(entry["price"])

	var ledger: Dictionary = shop.call("buy", "stock_gear")
	assert_bool(bool(ledger["ok"])).is_true()
	assert_int(run.drachma).is_equal(100 - price)
	var inv: InventoryAdapter = gc.call("inventory")
	assert_int(inv.count("gear", str(entry["item_key"]))).is_equal(1)
	# save_run flushed the live drawer into the persisted rows (the bought piece survives reload).
	var persisted := false
	for row: Variant in run.inventory:
		if (
			row is Dictionary
			and str((row as Dictionary).get("item_key", "")) == str(entry["item_key"])
		):
			persisted = true
	assert_bool(persisted).is_true()
	shop.queue_free()
	gc.queue_free()


func test_insufficient_drachma_changes_nothing() -> void:
	var gc := _make_game(5)
	var run: RunContext = gc.call("run")
	var shop := _make_shop(gc)
	var ledger: Dictionary = shop.call("buy", "stock_gear")
	assert_bool(bool(ledger["ok"])).is_false()
	assert_str(str(ledger["reason"])).is_equal("insufficient_drachma")
	assert_int(int(ledger["short"])).is_greater(0)
	assert_int(run.drachma).is_equal(5)
	var inv: InventoryAdapter = gc.call("inventory")
	assert_int(inv.count("gear", "sigil_of_mercy")).is_equal(0)
	shop.queue_free()
	gc.queue_free()


func test_unknown_stock_is_rejected() -> void:
	var gc := _make_game(100)
	var shop := _make_shop(gc)
	var ledger: Dictionary = shop.call("buy", "stock_of_lies")
	assert_bool(bool(ledger["ok"])).is_false()
	assert_str(str(ledger["reason"])).is_equal("unknown_stock")
	shop.queue_free()
	gc.queue_free()


func test_bought_gear_passes_the_equip_ownership_gate() -> void:
	# C16 closes the W17 gear-honesty loop: Trader purchase -> owned -> equippable.
	var gc := _make_game(100)
	var run: RunContext = gc.call("run")
	var shop := _make_shop(gc)
	shop.call("buy", "stock_gear")
	var creature: Dictionary = run.party[0]
	var ledger := GearServiceScript.equip(
		creature, "sigil_of_mercy", gc.call("gear_catalog"), gc.call("inventory")
	)
	assert_bool(bool(ledger["ok"])).is_true()
	assert_str(str(creature["equipped_gear"])).is_equal("sigil_of_mercy")
	shop.queue_free()
	gc.queue_free()


func test_camp_menu_carries_the_trader_entry() -> void:
	var camp: Control = CampMenuScript.new()
	camp.call("set_auto_navigate", false)
	add_child(camp)
	assert_object(camp.find_child("TraderButton", true, false)).is_not_null()
	assert_str(str(camp.call("open_trader"))).is_equal("res://presentation/camp/trader_shop.tscn")
	camp.queue_free()
