class_name GearService
extends RefCounted
## GearService (Phase 5 · Slice 3b) — the headless EQUIP/UNEQUIP orchestration for the ONE gear slot.
## APPLICATION/game layer: it reads gear from the CATALOG facade and applies the gear's `effects`
## through the SAME summation path the oracle uses (LootEngine.bonus / CreatureSheet.gear_effect_
## totals) — it computes no new stat numbers of its own.
##
## ONE slot per creature for the MVP: a creature_instance carries `equipped_gear` (a gear id String,
## "" = empty). Equipping overwrites the slot; unequipping clears it. The gear's effects modify the
## creature's EFFECTIVE stats (the capability/chance ledger — capture/tame/breed/lab — that this
## catalog's gear boosts) via CreatureSheet.gear_effect_totals; equip()/unequip() return the BEFORE
## and AFTER totals so the UI can show the delta. Persistence is the caller's (party screen ->
## GameController.save_run); this service only mutates the creature dict in place.
##
## PURE w.r.t. the SceneTree (no Node). The gear catalog is injected (read-only facade).

const CreatureSheetScript := preload("res://application/game/creature_sheet.gd")

## The InventoryAdapter item_type gear stacks live under (drops + the Trader credit this type).
const GEAR_ITEM_TYPE := "gear"


## EQUIP `gear_id` onto `creature` (the single slot). Validates the id against the catalog; an unknown
## id is a no-op (ok=false). W17 GEAR HONESTY: when an `inventory` (the run's InventoryAdapter) is
## given, the piece must actually be OWNED — equipping consumes it from the drawer (so one owned
## charm can never sit on two creatures) and a piece displaced from the slot returns to the drawer.
## A null inventory keeps the legacy catalog-only validation (older callers/tests). Returns a ledger:
##   { "ok": bool, "reason": String, "equipped": String,
##     "totals_before": Dictionary, "totals_after": Dictionary, "delta": Dictionary }
## delta is the per-field change in the summed numeric effects (after - before).
static func equip(
	creature: Dictionary,
	gear_id: String,
	gear_catalog: GearCatalog,
	inventory: InventoryAdapter = null
) -> Dictionary:
	if creature == null or creature.is_empty():
		return _fail("no_target")
	if gear_id == "" or not gear_catalog.has(gear_id):
		return _fail("unknown_gear")
	if inventory != null and not is_owned(gear_id, inventory):
		return _fail("not_owned")
	var before := CreatureSheetScript.gear_effect_totals(creature, gear_catalog)
	var displaced := str(creature.get("equipped_gear", ""))
	# Codex #57 P2: re-equipping the worn piece is a NO-OP — consuming a duplicate copy
	# while returning nothing silently deleted gear.
	if displaced == gear_id:
		return {
			"ok": true,
			"reason": "already_equipped",
			"equipped": gear_id,
			"totals_before": before,
			"totals_after": before,
			"delta": _delta(before, before),
		}
	creature["equipped_gear"] = gear_id
	if inventory != null:
		inventory.consume(GEAR_ITEM_TYPE, gear_id, 1)
		if displaced != "" and displaced != gear_id:
			inventory.add(GEAR_ITEM_TYPE, displaced, 1)
	var after := CreatureSheetScript.gear_effect_totals(creature, gear_catalog)
	return {
		"ok": true,
		"reason": "equipped",
		"equipped": gear_id,
		"totals_before": before,
		"totals_after": after,
		"delta": _delta(before, after),
	}


## UNEQUIP the creature's single slot (clears `equipped_gear`). No-op (ok=false) if nothing equipped.
## W17: with an `inventory`, the unequipped piece returns to the drawer (ownership stays honest).
## Returns the same ledger shape as equip() with `equipped` = "".
static func unequip(
	creature: Dictionary, gear_catalog: GearCatalog, inventory: InventoryAdapter = null
) -> Dictionary:
	if creature == null or creature.is_empty():
		return _fail("no_target")
	var worn := str(creature.get("equipped_gear", ""))
	if worn == "":
		return _fail("nothing_equipped")
	var before := CreatureSheetScript.gear_effect_totals(creature, gear_catalog)
	creature["equipped_gear"] = ""
	if inventory != null:
		inventory.add(GEAR_ITEM_TYPE, worn, 1)
	var after := CreatureSheetScript.gear_effect_totals(creature, gear_catalog)
	return {
		"ok": true,
		"reason": "unequipped",
		"equipped": "",
		"totals_before": before,
		"totals_after": after,
		"delta": _delta(before, after),
	}


## True iff the drawer holds at least one of `gear_id` (the W17 equip gate + the greyed-row read).
static func is_owned(gear_id: String, inventory: InventoryAdapter) -> bool:
	return inventory != null and inventory.has_item(GEAR_ITEM_TYPE, gear_id, 1)


## The currently-equipped gear id on a creature ("" when empty).
static func equipped_id(creature: Dictionary) -> String:
	return str(creature.get("equipped_gear", ""))


# --- internals -------------------------------------------------------------------------------- #


## Per-field numeric delta (after - before). Only NUMERIC effect fields produce a delta; label-style
## effects (e.g. "combat": "Dominion aura") are reported as the after-label under their key.
static func _delta(before: Dictionary, after: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var keys: Dictionary = {}
	for k in before:
		keys[k] = true
	for k in after:
		keys[k] = true
	for field in keys:
		var b: Variant = before.get(field, 0.0)
		var a: Variant = after.get(field, 0.0)
		if (a is float or a is int) and (b is float or b is int):
			out[field] = float(a) - float(b)
		else:
			out[field] = after.get(field, "")
	return out


static func _fail(reason: String) -> Dictionary:
	return {
		"ok": false,
		"reason": reason,
		"equipped": "",
		"totals_before": {},
		"totals_after": {},
		"delta": {},
	}
