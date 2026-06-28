class_name InventoryItem
extends RefCounted
## InventoryItem — the data-only DTO for one stack in the parts/kits/consumables/vials inventory
## (Cluster 4 D4, ADR-012/015). INFRASTRUCTURE layer: pure data + value sugar; holds NO gameplay
## math (the oracle, client/domain/, owns every number). It is the versioned-JSON shape persisted
## in RunContext.inventory — a plain Dictionary { item_type, item_key, qty } (+ optional meta) so it
## round-trips through SaveEnvelope WITHOUT ever serializing an addon Resource (.tres). Mapping the
## expressobits inventory-system's ItemDefinition/ItemStack Resources onto THIS DTO is the boundary
## that keeps addon types from crossing a layer (ADR-015 P3/P5).
##
## Categories mirror the Lab ingredient taxonomy (Mutants_Game_Lab.md "Ingredients" + the live
## splice_rules.json `ingredient_compat[*].type` / `gene_compat[*].type` values) plus the
## non-ingredient run items the Lab/economy reference: consumable, key. These category strings are
## the SAME tokens the LegalitySolver reads off an ingredient spec, so a consumed ingredient's
## category needs no translation.

# The canonical item categories (Mutants_Game_Lab.md ingredient types + run items). organ/core/soul/
# plating/gene align 1:1 with splice_rules.json types so an ingredient's category == its rule `type`.
const CATEGORIES: Array = [
	"organ",  # a heart/eye/gland — grants a trait or ability (splice ingredient)
	"gene",  # gene-vial — surfaces a stat/trait (splice ingredient)
	"core",  # core (reactor/heart) — power source / build fuel (splice ingredient)
	"soul",  # soul — power source for reanimation/ascension (splice ingredient)
	"plating",  # scrap & plating — bulk construct material (splice ingredient)
	"skill_vial",  # a learnable skill carrier (feeds the skill/ability shell; NOT a splice ingredient)
	"consumable",  # one-shot field/lab consumable (potions, reagents)
	"key",  # quest/region keys, unlock tokens (non-stacking semantics still allowed)
]

# These categories are valid Lab ingredients: a stack of one of these can be CONSUMED for a splice
# (its item_key is what the LegalitySolver/LabBench receive as an ingredient id). skill_vial/
# consumable/key are inventory items the Lab never recombines, so they are NOT ingredient-eligible.
const INGREDIENT_CATEGORIES: Array = ["organ", "gene", "core", "soul", "plating"]

var item_type: String = ""
var item_key: String = ""
var qty: int = 0
## Optional non-numeric provenance/metadata (e.g. {"source": "harvest", "rank": "god"}). Data only;
## the oracle never reads it for a number. Kept so harvested/black-market parts can carry their tag.
var meta: Dictionary = {}


func _init(
	p_type: String = "", p_key: String = "", p_qty: int = 0, p_meta: Dictionary = {}
) -> void:
	item_type = p_type
	item_key = p_key
	qty = p_qty
	meta = p_meta.duplicate(true)


## True if this item's category may be fed to the Lab as a splice ingredient.
func is_ingredient() -> bool:
	return INGREDIENT_CATEGORIES.has(item_type)


## A stable identity for stacking: two items stack iff same (type, key) AND identical meta. meta is
## compared by its canonical JSON so a god-organ and a wild organ of the same key never merge.
func stack_id() -> String:
	return item_type + "/" + item_key + "/" + JSON.stringify(meta, "", true)


func to_dict() -> Dictionary:
	# Mirrors the RunContext.inventory row shape { item_type, item_key, qty } (+ meta when non-empty).
	var out := {
		"item_type": item_type,
		"item_key": item_key,
		# NOTE: a bare JSON number reparses as FLOAT in GDScript; qty is written as an int here and
		# every read int()-wraps it (from_dict below), so the round-trip stays integral.
		"qty": qty,
	}
	if not meta.is_empty():
		out["meta"] = meta.duplicate(true)
	return out


static func from_dict(data: Dictionary) -> InventoryItem:
	var meta: Dictionary = {}
	if data.get("meta", null) is Dictionary:
		meta = (data["meta"] as Dictionary).duplicate(true)
	# int(...) the qty: JSON.parse_string decodes a bare `2` as 2.0 (float), so an unwrapped read
	# would carry a float quantity through stacking math (the documented GDScript JSON gotcha).
	return InventoryItem.new(
		str(data.get("item_type", "")), str(data.get("item_key", "")), int(data.get("qty", 0)), meta
	)
