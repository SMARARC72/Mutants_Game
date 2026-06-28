extends GdUnitTestSuite
## CONTAMINATION GUARD (Cluster 4 D4 headline, ADR-015 / DoD item 4): a splice DRIVEN THROUGH the
## inventory + the recipe graph -> LabRecipeBench -> LabBench produces a creature whose stats EQUAL
## LabEngine.fuse(...) on the SAME config + seed. This proves the inventory/recipe addon contributed
## STORAGE + RECIPE REPRESENTATION only, NOT a single number. Mirrors lab_legality_parity_test.gd's
## field-for-field equality. If the inventory/recipe path perturbed any stat/blend/tier/ledger value,
## this would diverge from the pure oracle.

const SpliceRulesScript := preload("res://infrastructure/lab/splice_rules.gd")
const LabBenchScript := preload("res://application/lab/lab_bench.gd")
const LabRecipeBenchScript := preload("res://application/lab/lab_recipe_bench.gd")
const LabRecipeScript := preload("res://infrastructure/inventory/lab_recipe.gd")
const InventoryAdapterScript := preload("res://infrastructure/inventory/inventory_adapter.gd")

var _rules: SpliceRules


func before() -> void:
	_rules = SpliceRulesScript.load_default()
	assert_object(_rules).is_not_null()


# A fuse committed through inventory+recipe equals LabEngine.fuse on the same numeric rng, field for
# field. The inventory held no consumable for this fuse (fuse ingredients are optional) — the point is
# that ROUTING through the recipe bench does not change the creature vs the raw oracle.
func test_recipe_splice_equals_oracle() -> void:
	var a := ["Ruinmaw", "Thanatos", "Chaos", "T2"]
	var b := ["Gloamcat", "Thanatos", "Ouranos", "T2"]
	var player := {"corruption": 0, "unlocks": [], "has_parts": []}
	var seed := 4242
	var op_id := "inv_parity_fuse_1"

	var inventory := InventoryAdapterScript.new()
	var recipe := LabRecipeScript.new("fuse", a, b, [], "precise", "Gloammaw")
	var bench := LabRecipeBenchScript.new(_rules)

	var res := bench.commit_recipe(recipe, inventory, player, seed, op_id)
	assert_int(int(res["verdict"])).is_equal(0)  # LEGAL
	var creature: Dictionary = res["creature"]

	# Rebuild the EXACT rng the underlying LabBench passed the oracle, call the oracle directly.
	var expected := LabEngine.fuse(a, b, "precise", LabBenchScript.numeric_rng(seed, op_id))
	_assert_creatures_equal(creature, expected)

	# The recipe bench's verdict matches a direct LabBench.commit on the same inputs (no extra math).
	var direct := LabBenchScript.new(_rules).commit(
		a, b, [], "precise", player, seed, op_id, "fuse"
	)
	_assert_creatures_equal(creature, direct["creature"])


# A graft DRIVEN THROUGH the inventory: the parts drawer holds a claw; the recipe consumes it; the
# committed creature equals LabEngine.fuse(host, host-mirror partner, ...) on the same numeric rng;
# and the consumed item is removed EXACTLY (the inventory's only contribution).
func test_recipe_graft_consumes_exactly_and_equals_oracle() -> void:
	var host := ["Titanhusk", "Gaia", "Chaos", "T2"]
	var player := {"corruption": 0, "unlocks": [], "has_parts": []}
	var seed := 5151
	var op_id := "inv_parity_graft"

	var inventory := InventoryAdapterScript.new()
	inventory.add("organ", "claw", 2)  # two claws on hand
	inventory.add("plating", "scale", 1)  # an unrelated part that must NOT be touched

	var recipe := LabRecipeScript.new("graft", host, null, ["claw"], "precise", "Clawgraft")
	var bench := LabRecipeBenchScript.new(_rules)
	var res := bench.commit_recipe(recipe, inventory, player, seed, op_id)
	assert_int(int(res["verdict"])).is_equal(0)  # LEGAL

	# Equals the oracle on the HOST-MIRRORING partner (the LabBench single-creature path) — proof the
	# inventory contributed config/storage only.
	var partner := ["graft_part", "Gaia", "Chaos", "T2"]
	var expected := LabEngine.fuse(
		host, partner, "precise", LabBenchScript.numeric_rng(seed, op_id)
	)
	_assert_creatures_equal(res["creature"], expected)

	# EXACT consumption: one claw removed, one claw remains, the unrelated scale untouched.
	assert_int(inventory.count("organ", "claw")).is_equal(1)
	assert_int(inventory.count("plating", "scale")).is_equal(1)
	assert_bool((res["consumed"] as Array).has("claw")).is_true()


# An ILLEGAL/unaffordable recipe consumes NOTHING (no garbage creature, no silent part loss). A graft
# requiring a claw the drawer does not hold returns a miss and leaves the inventory intact.
func test_unaffordable_recipe_consumes_nothing() -> void:
	var host := ["Titanhusk", "Gaia", "Chaos", "T2"]
	var player := {"corruption": 0, "unlocks": [], "has_parts": []}
	var inventory := InventoryAdapterScript.new()
	inventory.add("plating", "scale", 1)  # has scale, but the recipe needs a claw

	var recipe := LabRecipeScript.new("graft", host, null, ["claw"], "precise")
	var bench := LabRecipeBenchScript.new(_rules)
	var res := bench.commit_recipe(recipe, inventory, player, 1, "miss")

	assert_int(int(res["verdict"])).is_not_equal(0)  # NOT LEGAL
	assert_bool(res.has("creature")).is_false()  # no creature produced
	assert_int(inventory.count("plating", "scale")).is_equal(1)  # nothing consumed


func _assert_creatures_equal(got: Dictionary, exp: Dictionary) -> void:
	for k in ["name", "prim", "sec", "tier", "method"]:
		assert_str(str(got[k])).is_equal(str(exp[k]))
	assert_bool(bool(got["taboo"])).is_equal(bool(exp["taboo"]))
	for k in ["hp", "bst", "entropy", "corruption"]:
		assert_int(int(got[k])).is_equal(int(exp[k]))
	var gs: Dictionary = got["stats"]
	var es: Dictionary = exp["stats"]
	assert_int(gs.size()).is_equal(es.size())
	for k in es:
		assert_int(int(gs[k])).is_equal(int(es[k]))
