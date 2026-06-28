class_name SpliceRules
extends RefCounted
## SpliceRules — loader + schema validator for res://catalog/splice_rules.json (SpliceRules.md §4).
## INFRASTRUCTURE layer (NOT domain): pure rules DATA. Holds NO outcome math — the force blend,
## stat_block, and entropy/corruption ledger all belong to client/domain/lab_engine.gd (ADR-015).
## This class only parses the ruleset and proves it is structurally sound + cross-referentially
## consistent (the same checks tools/test_splice_rules_coverage.py runs in CI, SpliceRules.md §7).
##
## Usage:
##   var rules := SpliceRules.load_default()      # -> SpliceRules or null on failure
##   if rules == null: push_error(SpliceRules.last_error)
##   rules.force_is_opposed("Cosmos", "Chaos")    # true

const DEFAULT_PATH := "res://catalog/splice_rules.json"
const REQUIRED_FORCES: Array = ["Gaia", "Ouranos", "Cosmos", "Chaos", "Eros", "Thanatos"]
const REQUIRED_OPS: Array = ["fuse", "mutate", "graft", "self_splice", "reanimate"]
const REQUIRED_THRESHOLDS: Array = ["T_abom", "T_god", "T_self"]
const REQUIRED_UNLOCKS: Array = ["abomination_rites", "auto_chirurgy", "necromancy"]

# Static record of the last load error (so callers that got null can report it).
static var last_error: String = ""

var data: Dictionary = {}
var error: String = ""


## Load + validate the default ruleset. Returns a SpliceRules on success, null on failure
## (with SpliceRules.last_error set). Never throws / never returns a half-validated object.
static func load_default() -> SpliceRules:
	return load_from(DEFAULT_PATH)


static func load_from(path: String) -> SpliceRules:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		last_error = "splice_rules: cannot open " + path
		return null
	var text := f.get_as_text()
	f.close()
	return load_text(text)


## Parse + validate from a raw JSON string (used by tests with inline fixtures).
static func load_text(text: String) -> SpliceRules:
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		last_error = "splice_rules: root is not a JSON object"
		return null
	var inst := SpliceRules.new()
	inst.data = parsed
	if not inst._validate():
		last_error = inst.error
		return null
	last_error = ""
	return inst


# --- schema validation (mirrors tools/test_splice_rules_coverage.py, SpliceRules.md §7) -------


func _validate() -> bool:
	if not _validate_top_level():
		return false
	if not _validate_opposed():
		return false
	if not _validate_operations():
		return false
	if not _validate_ingredient_compat():
		return false
	return true


func _validate_top_level() -> bool:
	if int(data.get("schema_version", -1)) != 1:
		error = "splice_rules: schema_version must be 1"
		return false
	for key in ["forces", "opposed", "thresholds", "unlocks", "operations", "trait_slots"]:
		if not data.has(key):
			error = "splice_rules: missing top-level key '" + key + "'"
			return false
	var forces: Array = data["forces"]
	for fc in REQUIRED_FORCES:
		if not forces.has(fc):
			error = "splice_rules: forces missing '" + str(fc) + "'"
			return false
	var thresholds: Dictionary = data["thresholds"]
	for t in REQUIRED_THRESHOLDS:
		if not thresholds.has(t):
			error = "splice_rules: thresholds missing '" + str(t) + "'"
			return false
	var unlocks: Array = data["unlocks"]
	for u in REQUIRED_UNLOCKS:
		if not unlocks.has(u):
			error = "splice_rules: unlocks missing '" + str(u) + "'"
			return false
	return true


func _validate_opposed() -> bool:
	# Opposed pairs must be symmetric and reference defined forces (SpliceRules §7).
	var forces: Array = data["forces"]
	var pair_set := {}
	for pair in data["opposed"]:
		if not (pair is Array) or (pair as Array).size() != 2:
			error = "splice_rules: opposed entry is not a 2-element pair"
			return false
		var a: String = str(pair[0])
		var b: String = str(pair[1])
		if not forces.has(a) or not forces.has(b):
			error = "splice_rules: opposed pair references undefined force (" + a + "," + b + ")"
			return false
		pair_set[a + "|" + b] = true
	# Symmetry: for every [a,b] the reverse [b,a] is implied by force_is_opposed; assert no dupes.
	for pair in data["opposed"]:
		var a: String = str(pair[0])
		var b: String = str(pair[1])
		if pair_set.has(b + "|" + a):
			error = "splice_rules: opposed pair listed in both directions (" + a + "," + b + ")"
			return false
	return true


func _validate_operations() -> bool:
	var ops: Dictionary = data["operations"]
	for op in REQUIRED_OPS:
		if not ops.has(op):
			error = "splice_rules: operations missing '" + str(op) + "'"
			return false
		var spec: Variant = ops[op]
		if not (spec is Dictionary):
			error = "splice_rules: operation '" + str(op) + "' is not an object"
			return false
		if not (spec as Dictionary).has("inputs"):
			error = "splice_rules: operation '" + str(op) + "' missing 'inputs'"
			return false
	return true


func _validate_ingredient_compat() -> bool:
	# Every ingredient force ref must be a defined force; every slot ref must exist in trait_slots.
	var forces: Array = data["forces"]
	var trait_slots: Dictionary = data.get("trait_slots", {})
	var compat: Dictionary = data.get("ingredient_compat", {})
	for ing in compat:
		var spec: Dictionary = compat[ing]
		for fc in spec.get("forces", []):
			if not forces.has(fc):
				error = (
					"splice_rules: ingredient '"
					+ str(ing)
					+ "' references undefined force '"
					+ str(fc)
					+ "'"
				)
				return false
		var slot: Variant = spec.get("slot", null)
		if slot != null and not trait_slots.has(slot):
			error = (
				"splice_rules: ingredient '"
				+ str(ing)
				+ "' references undefined slot '"
				+ str(slot)
				+ "'"
			)
			return false
	return true


# --- accessors (rules-layer queries; NO outcome math) ----------------------------------------


func threshold(name: String) -> int:
	return int(data["thresholds"][name])


func unlocks() -> Array:
	return data["unlocks"]


func operation(op: String) -> Dictionary:
	return data["operations"].get(op, {})


func force_is_opposed(a: String, b: String) -> bool:
	for pair in data["opposed"]:
		if (str(pair[0]) == a and str(pair[1]) == b) or (str(pair[0]) == b and str(pair[1]) == a):
			return true
	return false


func ingredient_spec(ing: String) -> Dictionary:
	return data.get("ingredient_compat", {}).get(ing, {})


func gene_spec(gene: String) -> Dictionary:
	return data.get("gene_compat", {}).get(gene, {})


func trait_slot(slot: String) -> Dictionary:
	return data.get("trait_slots", {}).get(slot, {})


func bridge_parts() -> Array:
	return data.get("bridges", {}).get("parts", [])


## True if an ingredient is a tier-raising part (consuming it lifts the tier ceiling, §3 rule 3).
func ingredient_raises_tier(ing: String) -> bool:
	return bool(ingredient_spec(ing).get("raises_tier", false))
