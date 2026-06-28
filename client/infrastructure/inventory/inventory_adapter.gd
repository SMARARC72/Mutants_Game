class_name InventoryAdapter
extends RefCounted
## InventoryAdapter — the thin FACADE over the parts/kits/consumables/vials inventory (Cluster 4 D4,
## ADR-015 P3). INFRASTRUCTURE layer. The rest of the game (LabBench, the Lab UI, the economy) talks
## ONLY to this facade, never to the expressobits inventory-system addon directly — so the addon stays
## swappable behind one file (ADR-015: "addon types never cross a layer boundary").
##
## What it owns: a list of stacks (InventoryItem) with add / stack-merge / consume / query, plus
## data-only persistence (to_dict / load_from -> RunContext.inventory). What it does NOT own: any
## gameplay number. Consuming ingredients for a splice REMOVES exactly the consumed items; the
## spliced creature is computed by client/domain/lab_engine.gd via LabBench — never here (the
## contamination guard, ADR-015 / Cluster4 DoD item 4).
##
## ADDON BOUNDARY: when expressobits/inventory-system is wired in, its Inventory node holds the
## ItemStacks and this facade's methods delegate to it (add -> Inventory.add, etc.), mapping its
## ItemDefinition/ItemStack Resources onto InventoryItem on the way out. The contract below is what
## callers depend on; the backing store is an implementation detail. See THIRD_PARTY.md (D4).

const InventoryItemScript := preload("res://infrastructure/inventory/inventory_item.gd")

# stack_id -> InventoryItem. A Dictionary keeps stacking O(1) and preserves a stable iteration order
# (Godot Dictionaries are insertion-ordered) so serialization is deterministic across saves.
var _stacks: Dictionary = {}


## Add `qty` of an item, merging into an existing matching stack (same type/key/meta). Returns the
## resulting total quantity of that stack. A non-positive qty is a no-op (returns the current count).
func add(item_type: String, item_key: String, qty: int = 1, meta: Dictionary = {}) -> int:
	if qty <= 0:
		return count(item_type, item_key, meta)
	var probe: InventoryItem = InventoryItemScript.new(item_type, item_key, qty, meta)
	var sid: String = probe.stack_id()
	if _stacks.has(sid):
		var existing: InventoryItem = _stacks[sid]
		existing.qty += qty
		return existing.qty
	_stacks[sid] = probe
	return probe.qty


## Add a whole InventoryItem (or its dict form). Convenience for harvest/loot pipelines.
func add_item(item: InventoryItem) -> int:
	return add(item.item_type, item.item_key, item.qty, item.meta)


## How many of (type, key[, meta]) are held. When `meta` is empty, sums ACROSS all meta-variants of
## that key (e.g. total claws regardless of source); with a specific meta, counts that variant only.
func count(item_type: String, item_key: String, meta: Dictionary = {}) -> int:
	if meta.is_empty():
		var total := 0
		for sid in _stacks:
			var it: InventoryItem = _stacks[sid]
			if it.item_type == item_type and it.item_key == item_key:
				total += it.qty
		return total
	var probe: InventoryItem = InventoryItemScript.new(item_type, item_key, 0, meta)
	var it2: InventoryItem = _stacks.get(probe.stack_id(), null)
	return it2.qty if it2 != null else 0


## True iff at least `qty` of the item are available (meta semantics as in count()).
func has_item(item_type: String, item_key: String, qty: int = 1, meta: Dictionary = {}) -> bool:
	return count(item_type, item_key, meta) >= qty


## Remove `qty` of an item. Returns the number ACTUALLY removed (0 if absent / insufficient when
## not partial). When `meta` is empty, removes across meta-variants oldest-stack-first. Removing the
## last of a stack drops the stack entirely. This is the primitive the splice consume path uses.
func consume(item_type: String, item_key: String, qty: int = 1, meta: Dictionary = {}) -> int:
	if qty <= 0:
		return 0
	if not has_item(item_type, item_key, qty, meta):
		return 0
	var remaining := qty
	if not meta.is_empty():
		var probe: InventoryItem = InventoryItemScript.new(item_type, item_key, 0, meta)
		remaining -= _drain_stack(probe.stack_id(), remaining)
		return qty - remaining
	# meta-agnostic: drain matching stacks in insertion order until satisfied.
	for sid in _stacks.keys():
		if remaining <= 0:
			break
		var it: InventoryItem = _stacks[sid]
		if it.item_type == item_type and it.item_key == item_key:
			remaining -= _drain_stack(sid, remaining)
	return qty - remaining


## Consume a BATCH of ingredient ids for a Lab op (the LabBench consume path). `ingredients` is the
## list of ingredient-id Strings the bench/solver consumed (config["consumed"]); each is matched
## against the inventory's INGREDIENT-category stacks by item_key. Returns { ok, missing, consumed }:
## ok=true only if EVERY ingredient was present and removed; on a miss NOTHING is removed (atomic) so
## a failed splice never silently eats parts. The spliced creature is still computed by lab_engine —
## this method only debits the parts drawer.
func consume_ingredients(ingredients: Array) -> Dictionary:
	# Pre-flight: verify availability for the WHOLE batch (counting duplicates) before removing any.
	var need: Dictionary = {}  # item_key -> required count
	for ing in ingredients:
		var key := str(ing)
		need[key] = int(need.get(key, 0)) + 1
	var missing: Array = []
	for key in need:
		if _ingredient_count(key) < int(need[key]):
			missing.append(key)
	if not missing.is_empty():
		return {"ok": false, "missing": missing, "consumed": []}
	# All present -> remove exactly the consumed ids (ingredient categories only).
	var consumed: Array = []
	for ing in ingredients:
		var key := str(ing)
		if _consume_ingredient_one(key):
			consumed.append(key)
	return {"ok": true, "missing": [], "consumed": consumed}


## All stacks as InventoryItem objects (read-only snapshot; callers must not mutate the live stacks).
func items() -> Array:
	var out: Array = []
	for sid in _stacks:
		out.append(_stacks[sid])
	return out


## Stacks whose category is a Lab-ingredient category (organ/gene/core/soul/plating).
func ingredient_items() -> Array:
	var out: Array = []
	for sid in _stacks:
		var it: InventoryItem = _stacks[sid]
		if it.is_ingredient():
			out.append(it)
	return out


func is_empty() -> bool:
	return _stacks.is_empty()


func stack_count() -> int:
	return _stacks.size()


# --- persistence (data-only JSON; ADR-012) --------------------------------------------------- #


## The versioned-JSON array form (the RunContext.inventory payload). Each entry is an InventoryItem
## dict; NEVER an addon Resource. Iteration order is the stable insertion order.
func to_dict() -> Array:
	var out: Array = []
	for sid in _stacks:
		var it: InventoryItem = _stacks[sid]
		out.append(it.to_dict())
	return out


## Restore IN PLACE from a RunContext.inventory array (mirrors RunContext.load_from semantics so a
## cached reference sees the restored state). Re-stacks on load: two rows with the same identity merge.
func load_from(rows: Array) -> void:
	_stacks.clear()
	for row in rows:
		if not (row is Dictionary):
			continue
		var it: InventoryItem = InventoryItemScript.from_dict(row)
		if it.item_key == "" or it.qty <= 0:
			continue
		add(it.item_type, it.item_key, it.qty, it.meta)


static func from_rows(rows: Array) -> InventoryAdapter:
	var inv := InventoryAdapter.new()
	inv.load_from(rows)
	return inv


# --- helpers ---------------------------------------------------------------------------------- #


func _drain_stack(sid: String, want: int) -> int:
	# Remove up to `want` from the stack at sid; erase the stack if it hits zero. Returns removed count.
	if not _stacks.has(sid):
		return 0
	var it: InventoryItem = _stacks[sid]
	var take: int = min(it.qty, want)
	it.qty -= take
	if it.qty <= 0:
		_stacks.erase(sid)
	return take


func _ingredient_count(item_key: String) -> int:
	# Total across ingredient-category stacks of this key (meta-agnostic).
	var total := 0
	for sid in _stacks:
		var it: InventoryItem = _stacks[sid]
		if it.is_ingredient() and it.item_key == item_key:
			total += it.qty
	return total


func _consume_ingredient_one(item_key: String) -> bool:
	# Remove one unit of an ingredient-category stack with this key (insertion order). True if removed.
	for sid in _stacks.keys():
		var it: InventoryItem = _stacks[sid]
		if it.is_ingredient() and it.item_key == item_key and it.qty > 0:
			_drain_stack(sid, 1)
			return true
	return false
