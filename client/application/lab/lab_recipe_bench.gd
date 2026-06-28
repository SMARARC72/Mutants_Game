class_name LabRecipeBench
extends RefCounted
## LabRecipeBench — wires the INVENTORY (parts drawer) + the recipe GRAPH to the LabBench (Cluster 4
## D4, ADR-015 §B1). APPLICATION layer: it orchestrates, it computes NOTHING. It is the single place
## where "a splice driven through inventory" happens, and it makes the contamination boundary explicit:
##
##   commit_recipe(recipe, inventory, player_state, run_seed, op_id)
##     1. LabBench.preview/commit  -> the LegalitySolver gates legality + the oracle (lab_engine)
##        computes EVERY number (force blend, stat_block, entropy/corruption ledger).
##     2. ONLY on a LEGAL commit, debit the inventory: InventoryAdapter.consume_ingredients(
##        splice_config["consumed"]) removes EXACTLY the items the solver resolved as consumed.
##     3. Return { verdict, creature, splice_config, consumed } (the creature is lab_engine's verbatim
##        result — this class never touches it).
##
## The ordering matters: the oracle runs FIRST and is the sole source of the creature; the inventory
## is debited AFTER, and only on success, so an ILLEGAL/TABOO op never eats parts and the addon never
## sits between the inputs and the numbers. Equivalently: remove this class and LabBench still produces
## the identical creature — the inventory contributed STORAGE (which parts were consumed) only.

const InventoryAdapterScript := preload("res://infrastructure/inventory/inventory_adapter.gd")
const LabBenchScript := preload("res://application/lab/lab_bench.gd")

var _bench: LabBench


func _init(rules: SpliceRules) -> void:
	_bench = LabBenchScript.new(rules)


## Preview a recipe WITHOUT consuming anything (the Lab UI's "what would happen" path). Returns the
## LegalitySolver verdict verbatim (verdict/reason/unlock_cost/configs). Reads the inventory only to
## annotate whether the parts are actually on hand (`ingredients_available`); it removes nothing.
func preview_recipe(
	recipe: LabRecipe, inventory: InventoryAdapter, player_state: Dictionary
) -> Dictionary:
	var verdict := _bench.preview(
		recipe.creature_a,
		recipe.creature_b,
		recipe.ingredients,
		recipe.method,
		player_state,
		recipe.op
	)
	# Non-numeric affordance flag for the UI: are the recipe's ingredients in the parts drawer?
	verdict["ingredients_available"] = _all_ingredients_on_hand(recipe, inventory)
	return verdict


## Commit a recipe: run the oracle via LabBench, then (only on LEGAL) debit the inventory by the
## solver-resolved consumed set. Returns:
##   LEGAL  -> { verdict, creature, splice_config, rng_seed_tag, consumed: [item_key...] }
##   else   -> the LabBench verdict verbatim (NO creature, NO inventory change).
## If the verdict is LEGAL but the inventory lacks the parts, returns a non-LEGAL-style miss
## { verdict: ILLEGAL, reason, missing } and changes nothing (you can't splice parts you don't own).
func commit_recipe(
	recipe: LabRecipe,
	inventory: InventoryAdapter,
	player_state: Dictionary,
	run_seed: int,
	op_id: String
) -> Dictionary:
	# Pre-flight the parts drawer BEFORE committing so a legal-but-unaffordable op changes nothing.
	if not _all_ingredients_on_hand(recipe, inventory):
		return {
			"verdict": LegalitySolver.Verdict.ILLEGAL,
			"reason": "the parts drawer is missing required ingredients",
			"unlock_cost": {},
			"configs": [],
			"missing": _missing_ingredients(recipe, inventory),
		}

	# THE ORACLE RUNS HERE. lab_engine (via LabBench) computes the creature from the ORIGINAL inputs;
	# nothing in this class or the inventory perturbs a number (the contamination guard).
	var result := _bench.commit(
		recipe.creature_a,
		recipe.creature_b,
		recipe.ingredients,
		recipe.method,
		player_state,
		run_seed,
		op_id,
		recipe.op
	)
	if int(result["verdict"]) != LegalitySolver.Verdict.LEGAL:
		# ILLEGAL or TABOO: surface the verdict, eat NO parts (ADR-015: no garbage + no silent loss).
		return result

	# LEGAL: debit the inventory by EXACTLY the solver-resolved consumed set (splice_config.consumed).
	# This is the only mutation this class performs, and it is storage-only — the creature is already
	# fully computed and is returned untouched.
	var config: Dictionary = result["splice_config"]
	var to_consume: Array = config.get("consumed", [])
	var debit := inventory.consume_ingredients(to_consume)
	result["consumed"] = debit.get("consumed", [])
	return result


# --- helpers (no math) ------------------------------------------------------------------------ #


func _all_ingredients_on_hand(recipe: LabRecipe, inventory: InventoryAdapter) -> bool:
	return _missing_ingredients(recipe, inventory).is_empty()


func _missing_ingredients(recipe: LabRecipe, inventory: InventoryAdapter) -> Array:
	# Which required ingredient ids (counting duplicates) are NOT fully covered by ingredient stacks.
	var need: Dictionary = {}
	for ing in recipe.required_ingredients():
		var key := str(ing)
		need[key] = int(need.get(key, 0)) + 1
	var missing: Array = []
	for key in need:
		if _ingredient_on_hand(inventory, key) < int(need[key]):
			missing.append(key)
	return missing


func _ingredient_on_hand(inventory: InventoryAdapter, item_key: String) -> int:
	# Sum the on-hand quantity of an ingredient key across its ingredient-category stacks.
	var total := 0
	for it in inventory.ingredient_items():
		if it.item_key == item_key:
			total += it.qty
	return total
