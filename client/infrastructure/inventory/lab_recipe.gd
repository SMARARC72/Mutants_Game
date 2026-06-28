class_name LabRecipe
extends RefCounted
## LabRecipe — the Lab recipe REPRESENTATION layer (Cluster 4 D4, ADR-015 §B1). INFRASTRUCTURE.
## This is the data shape the expressobits inventory-system's crafting GRAPH authors: a recipe names
## an operation, the creature inputs (by party slot / instance id) and the ingredient stacks it
## CONSUMES from the InventoryAdapter, plus the method. It is PURELY a recipe descriptor — it stores
## what goes IN; it computes NOTHING about what comes out. Execution routes through LabRecipeBench ->
## LabBench -> client/domain/lab_engine.gd (the oracle owns every number, ADR-015).
##
## "Crafting graph" mapping: a crafting recipe's inputs (ingredient ItemDefinitions + counts) map to
## `ingredients` here; the recipe's "output" is NOT a precomputed item — it is the Lab op the bench
## runs. So the addon contributes recipe AUTHORING/REPRESENTATION + ingredient STORAGE only; the
## spliced creature is never the addon's "crafted output". (This is the contamination boundary.)

# The Lab operations a recipe may name (mirror splice_rules.json operations / SpliceRules §4).
const OPERATIONS: Array = ["fuse", "mutate", "graft", "self_splice", "reanimate"]

var op: String = "fuse"
## Creature inputs as [name, primary, secondary, tier] arrays — the same shape LabBench/LegalitySolver
## take. (The Lab UI resolves party instance ids to these; the recipe stores the resolved tuples.)
var creature_a: Array = []
## Second creature for fuse (else [] / a placeholder for single-creature ops).
var creature_b: Variant = []
## Ingredient item-id Strings to CONSUME from the inventory (organ/gene/core/soul/plating keys). The
## order is the author's; the solver decides placement/skip. These are what InventoryAdapter debits.
var ingredients: Array = []
## "precise" (Cosmos: deterministic, costly) | "wild" (Chaos: cheap, variance) — passed THROUGH to
## the oracle; the recipe does not interpret it (no math here).
var method: String = "precise"
## Optional human-facing recipe name (discovery: a learned repeatable formula). Non-numeric.
var label: String = ""


func _init(
	p_op: String = "fuse",
	p_a: Array = [],
	p_b: Variant = [],
	p_ingredients: Array = [],
	p_method: String = "precise",
	p_label: String = ""
) -> void:
	op = p_op
	creature_a = p_a
	creature_b = p_b
	ingredients = p_ingredients
	method = p_method
	label = p_label


## True if this recipe's op is a known Lab operation. (Structural check only — legality is the
## LegalitySolver's job, computed at preview/commit time, NOT here.)
func is_known_op() -> bool:
	return OPERATIONS.has(op)


## The ingredient ids this recipe consumes, with duplicates preserved (two claws => two entries).
## This is exactly what InventoryAdapter.consume_ingredients expects.
func required_ingredients() -> Array:
	return ingredients.duplicate()


func to_dict() -> Dictionary:
	return {
		"op": op,
		"creature_a": creature_a.duplicate(true),
		"creature_b": creature_b.duplicate(true) if creature_b is Array else creature_b,
		"ingredients": ingredients.duplicate(),
		"method": method,
		"label": label,
	}


static func from_dict(data: Dictionary) -> LabRecipe:
	var b: Variant = data.get("creature_b", [])
	return LabRecipe.new(
		str(data.get("op", "fuse")),
		(data.get("creature_a", []) as Array).duplicate(true),
		b.duplicate(true) if b is Array else b,
		(data.get("ingredients", []) as Array).duplicate(),
		str(data.get("method", "precise")),
		str(data.get("label", ""))
	)
