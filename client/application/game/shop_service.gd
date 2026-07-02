class_name ShopService
extends RefCounted
## ShopService (Wave 17 · C16) — the minimal Trader: a fixed 3-item stock sold for DRACHMA.
## APPLICATION/game layer: the stock + prices are the single source of truth here (data-only
## constants — the shop UI reads them, never re-derives a number); the purchase debits
## run.drachma and credits the run's InventoryAdapter. No RNG, no domain math.
##
## STOCK (docs/Mutants_Game_Economy.md — "Drachma: mortal coin — ordinary shops, consumables,
## common gear"): one common-tier gear piece (a real client/catalog/gear.json id, so the party
## equip gate recognises it), one Lab reagent (a real splice_rules gene key), and a camp-heal
## voucher (a consumable the W18 camp Rest will honour). Prices follow the merchant's own copy
## ("...Forty drachma!" — voice.json shop.blessed) scaled down the rarity ladder.

## The Trader's shelf. Each row: id (stable stock key), item_type/item_key (InventoryAdapter
## coordinates), price (drachma), name+blurb (display copy; gear names still resolve through the
## GearCatalog at read time so the catalog stays the naming authority).
const STOCK: Array = [
	{
		"id": "stock_gear",
		"item_type": "gear",
		"item_key": "sigil_of_mercy",
		"price": 40,
		"name": "",  # resolved from the GearCatalog
		"blurb": "Sanctified, consecrated, faintly humming. Forty drachma.",
	},
	{
		"id": "stock_reagent",
		"item_type": "gene",
		"item_key": "verdant",
		"price": 15,
		"name": "Verdant Gene-Vial",
		"blurb": "Bottled growth. The Lab drinks these.",
	},
	{
		"id": "stock_voucher",
		"item_type": "consumable",
		"item_key": "camp_heal_voucher",
		"price": 25,
		"name": "Camp-Heal Voucher",
		"blurb": "One night of honest rest, promised on paper.",
	},
]


## The display-ready shelf: STOCK with gear names resolved through the catalog. Deep copies.
static func stock(gear_catalog: GearCatalog) -> Array:
	var out: Array = []
	for entry_v in STOCK:
		var entry := (entry_v as Dictionary).duplicate(true)
		if str(entry["item_type"]) == "gear" and gear_catalog != null:
			entry["name"] = gear_catalog.name_of(str(entry["item_key"]))
		out.append(entry)
	return out


## The stock row for `stock_id`, or {}.
static func entry_of(stock_id: String, gear_catalog: GearCatalog) -> Dictionary:
	for entry: Dictionary in stock(gear_catalog):
		if str(entry.get("id", "")) == stock_id:
			return entry
	return {}


## BUY one unit of `stock_id`: debit run.drachma, credit the inventory. Atomic — an unaffordable
## or unknown purchase changes nothing. Returns the ledger:
##   { "ok": bool, "reason": String, "price": int, "short": int, "drachma_after": int,
##     "item_type": String, "item_key": String, "name": String }
static func buy(
	run: RunContext, inventory: InventoryAdapter, stock_id: String, gear_catalog: GearCatalog
) -> Dictionary:
	if run == null or inventory == null:
		return _fail("no_run", 0, 0)
	var entry := entry_of(stock_id, gear_catalog)
	if entry.is_empty():
		return _fail("unknown_stock", 0, run.drachma)
	var price := int(entry["price"])
	if run.drachma < price:
		var ledger := _fail("insufficient_drachma", price, run.drachma)
		ledger["short"] = price - run.drachma
		ledger["name"] = str(entry.get("name", ""))
		return ledger
	run.drachma -= price
	inventory.add(str(entry["item_type"]), str(entry["item_key"]), 1)
	return {
		"ok": true,
		"reason": "bought",
		"price": price,
		"short": 0,
		"drachma_after": run.drachma,
		"item_type": str(entry["item_type"]),
		"item_key": str(entry["item_key"]),
		"name": str(entry.get("name", "")),
	}


static func _fail(reason: String, price: int, drachma: int) -> Dictionary:
	return {
		"ok": false,
		"reason": reason,
		"price": price,
		"short": 0,
		"drachma_after": drachma,
		"item_type": "",
		"item_key": "",
		"name": "",
	}
