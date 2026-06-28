extends GdUnitTestSuite
## Inventory adapter (Cluster 4 D4): add / stack / consume the parts/kits/consumables/vials inventory.
## Asserts stacking merges matching items, consuming removes exactly the requested amount, batch
## ingredient consumption for a splice removes exactly the consumed ids (and is atomic on a miss).

const InventoryAdapterScript := preload("res://infrastructure/inventory/inventory_adapter.gd")
const InventoryItemScript := preload("res://infrastructure/inventory/inventory_item.gd")


func test_add_merges_into_a_single_stack() -> void:
	var inv := InventoryAdapterScript.new()
	assert_int(inv.add("organ", "ruin_heart", 2)).is_equal(2)
	assert_int(inv.add("organ", "ruin_heart", 3)).is_equal(5)  # merged, not a new stack
	assert_int(inv.stack_count()).is_equal(1)
	assert_int(inv.count("organ", "ruin_heart")).is_equal(5)


func test_distinct_meta_does_not_merge() -> void:
	var inv := InventoryAdapterScript.new()
	inv.add("organ", "claw", 1, {"rank": "god"})
	inv.add("organ", "claw", 1, {"rank": "wild"})
	assert_int(inv.stack_count()).is_equal(2)  # different provenance => separate stacks
	# meta-agnostic count sums both; meta-specific count isolates one variant.
	assert_int(inv.count("organ", "claw")).is_equal(2)
	assert_int(inv.count("organ", "claw", {"rank": "god"})).is_equal(1)


func test_consume_removes_exact_amount_and_drops_empty_stack() -> void:
	var inv := InventoryAdapterScript.new()
	inv.add("plating", "scale", 5)
	assert_int(inv.consume("plating", "scale", 2)).is_equal(2)
	assert_int(inv.count("plating", "scale")).is_equal(3)
	assert_int(inv.consume("plating", "scale", 3)).is_equal(3)
	assert_int(inv.count("plating", "scale")).is_equal(0)
	assert_int(inv.stack_count()).is_equal(0)  # the emptied stack is removed entirely


func test_consume_insufficient_is_a_noop() -> void:
	var inv := InventoryAdapterScript.new()
	inv.add("core", "reactor", 1)
	assert_int(inv.consume("core", "reactor", 2)).is_equal(0)  # not enough -> remove nothing
	assert_int(inv.count("core", "reactor")).is_equal(1)


func test_consume_ingredients_batch_removes_exactly_consumed() -> void:
	var inv := InventoryAdapterScript.new()
	inv.add("organ", "claw", 2)
	inv.add("gene", "venom", 1)
	inv.add("plating", "scale", 1)
	# A splice consumed two claws + one venom (the solver's config["consumed"]).
	var res := inv.consume_ingredients(["claw", "claw", "venom"])
	assert_bool(res["ok"]).is_true()
	assert_int(inv.count("organ", "claw")).is_equal(0)
	assert_int(inv.count("gene", "venom")).is_equal(0)
	assert_int(inv.count("plating", "scale")).is_equal(1)  # untouched


func test_consume_ingredients_is_atomic_on_miss() -> void:
	var inv := InventoryAdapterScript.new()
	inv.add("organ", "claw", 1)  # only ONE claw, but the batch wants two
	var res := inv.consume_ingredients(["claw", "claw"])
	assert_bool(res["ok"]).is_false()
	assert_bool((res["missing"] as Array).has("claw")).is_true()
	assert_int(inv.count("organ", "claw")).is_equal(1)  # nothing removed on a partial miss


func test_non_ingredient_items_are_not_consumed_as_ingredients() -> void:
	var inv := InventoryAdapterScript.new()
	inv.add("consumable", "claw", 3)  # a consumable that happens to share the key "claw"
	# consume_ingredients matches ingredient-CATEGORY stacks only, so the consumable is invisible to it.
	var res := inv.consume_ingredients(["claw"])
	assert_bool(res["ok"]).is_false()
	assert_int(inv.count("consumable", "claw")).is_equal(3)


func test_ingredient_classification() -> void:
	assert_bool(InventoryItemScript.new("organ", "x", 1).is_ingredient()).is_true()
	assert_bool(InventoryItemScript.new("gene", "x", 1).is_ingredient()).is_true()
	assert_bool(InventoryItemScript.new("plating", "x", 1).is_ingredient()).is_true()
	assert_bool(InventoryItemScript.new("skill_vial", "x", 1).is_ingredient()).is_false()
	assert_bool(InventoryItemScript.new("consumable", "x", 1).is_ingredient()).is_false()
	assert_bool(InventoryItemScript.new("key", "x", 1).is_ingredient()).is_false()
