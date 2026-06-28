class_name LegalitySolver
extends RefCounted
## LegalitySolver — the Lab Legality Engine facade (ADR-015, implements SpliceRules.md §3).
## INFRASTRUCTURE layer: maps a Lab operation onto a constraint-satisfaction problem, solves it
## with backtracking (CspSolver), and returns a VERDICT (LEGAL / ILLEGAL(reason) / TABOO(cost)) plus
## candidate splice_config(s). It NEVER computes the force blend or any stat — those belong to
## client/domain/lab_engine.gd. The CSP only governs PERMISSION, ingredient/trait/flag resolution,
## tier-target legality, and the choice among legal variants (which LabBench makes via canonical RNG).
##
## SpliceRules §3 variables: force_intent, tier_target, class_target, trait_slots[], flags.
## SpliceRules §3 constraints (as data): 1 force-compat, 2 ingredient-legality, 3 tier-ceiling,
## 4 class-rules, 5 gate-satisfaction. Backtracking yields a complete valid config or a clean failure.

enum Verdict { LEGAL, ILLEGAL, TABOO }

const SLOT_SOLVER_VAR_PREFIX := "slot:"

var _rules: SpliceRules


func _init(rules: SpliceRules) -> void:
	_rules = rules


## preview(op, a, b, ingredients, method, player_state) -> Dictionary:
##   { "verdict": Verdict, "reason": String, "unlock_cost": Dictionary, "configs": Array }
## a / b are [name, primary, secondary, tier] (b may be []/null for single-creature ops).
## ingredients is an Array of ingredient-id Strings (organs/genes/cores/plating present for the op).
## player_state is { "corruption": int, "unlocks": Array[String], "has_parts": Array[String] }.
## configs is the list of structurally-valid splice_config Dictionaries (>=1 unless ILLEGAL).
func preview(
	op: String, a: Array, b: Variant, ingredients: Array, method: Variant, player_state: Dictionary
) -> Dictionary:
	var op_spec := _rules.operation(op)
	if op_spec.is_empty():
		return _illegal("unknown operation '" + op + "'")

	var ctx := _build_context(op, op_spec, a, b, ingredients, method)
	if ctx.has("reason"):
		return _illegal(ctx["reason"])

	var configs := _solve_configs(ctx)
	if configs.is_empty():
		return _illegal(ctx["fail_reason"])

	# Classify by the gate (constraint 5). The CSP already guaranteed constraints 1-4; the gate
	# decides LEGAL vs TABOO. Every returned config shares the same taboo classification for an op,
	# so evaluate the gate once against the representative config.
	return _classify(op_spec, configs, player_state)


# --- context + domains -----------------------------------------------------------------------


func _build_context(
	op: String, op_spec: Dictionary, a: Array, b: Variant, ingredients: Array, method: Variant
) -> Dictionary:
	var pA: String = str(a[1])
	var sA: String = str(a[2]) if a.size() > 2 and a[2] != null else ""
	var tA: String = str(a[3])
	var has_b: bool = b is Array and (b as Array).size() >= 4
	var pB: String = str(b[1]) if has_b else ""
	var sB: String = str(b[2]) if has_b and b[2] != null else ""
	var tB: String = str(b[3]) if has_b else tA

	# force_intent domain: the candidate primary/secondary poles carried from the inputs.
	# We do NOT recompute the blend (lab_engine owns that) — force_intent records which forces the
	# op carries, validated for compatibility. Domain = the distinct, non-empty input forces.
	var force_domain := _distinct_nonempty([pA, sA, pB, sB])
	if force_domain.is_empty():
		return {"reason": "no forces on inputs"}

	# tier_target domain: max(tA,tB) .. ceiling. Ceiling lifts by one if a tier-raising part is fed.
	var base_tier := _max_tier(tA, tB)
	var tier_domain := _tier_domain(base_tier, _has_tier_raiser(ingredients, op_spec))
	# class_target domain: organic always; construct/hybrid when a structural/bridge part is present.
	var class_domain := _class_domain(ingredients)

	return {
		"op": op,
		"op_spec": op_spec,
		"pA": pA,
		"sA": sA,
		"tA": tA,
		"pB": pB,
		"tB": tB,
		"has_b": has_b,
		"method": method,
		"ingredients": ingredients,
		"force_domain": force_domain,
		"tier_domain": tier_domain,
		"base_tier": base_tier,
		"class_domain": class_domain,
		"fail_reason": "",
	}


func _solve_configs(ctx: Dictionary) -> Array:
	var solver := CspSolver.new()
	solver.add_variable("force_intent", ctx["force_domain"])
	solver.add_variable("tier_target", ctx["tier_domain"])
	solver.add_variable("class_target", ctx["class_domain"])

	# One trait_slot variable per ingredient that targets a body slot. Domain depends on whether the
	# op REQUIRES its ingredients: optional-ingredient ops (fuse) may skip an ingredient ({place,skip});
	# required-ingredient ops (graft/mutate/self_splice/reanimate) MUST place every provided ingredient
	# ({place} only) — so an incompatible required ingredient yields NO solution => ILLEGAL (the §5 ex3
	# crystal_lattice-on-organic-Thanatos case). This mirrors SpliceRules §3 where a slot's domain is
	# "compatible organs in inventory" — an empty domain for a required slot means no consistent config.
	var required := _ingredients_required(ctx["op_spec"])
	var slot_vars: Array = []
	for ing in ctx["ingredients"]:
		var spec := _rules.ingredient_spec(ing)
		if spec.is_empty() or not spec.has("slot"):
			continue
		var vname: String = SLOT_SOLVER_VAR_PREFIX + ing
		var domain: Array = ["__place__"] if required else ["__place__", "__skip__"]
		solver.add_variable(vname, domain)
		slot_vars.append({"var": vname, "ing": ing, "slot": str(spec["slot"])})
	ctx["slot_vars"] = slot_vars

	_add_force_constraint(solver, ctx)
	_add_ingredient_constraints(solver, slot_vars)
	_add_tier_constraint(solver, ctx)
	_add_class_constraint(solver, ctx)

	var raw := solver.solve_all()
	if raw.is_empty():
		ctx["fail_reason"] = _diagnose_failure(ctx, slot_vars)
		return []
	var configs: Array = []
	for assignment in raw:
		configs.append(_assignment_to_config(ctx, assignment, slot_vars))
	return configs


# --- the five constraints (SpliceRules §3) ---------------------------------------------------


func _add_force_constraint(solver: CspSolver, ctx: Dictionary) -> void:
	# Constraint 1 — force compatibility. force_intent must be one of the input forces; opposed
	# input pairs are allowed but FLAG taboo (the gate, constraint 5, decides legality later).
	# Here we only reject force_intent values not actually present on the inputs.
	var present: Array = ctx["force_domain"]
	solver.add_constraint(
		["force_intent"], func(asg: Dictionary) -> bool: return present.has(asg["force_intent"])
	)


func _add_ingredient_constraints(solver: CspSolver, slot_vars: Array) -> void:
	# Constraint 2 — ingredient legality + conflicts. A placed ingredient must be compatible with
	# force_intent AND class_target; two placed ingredients may not claim the same single-max slot.
	for sv in slot_vars:
		# Bind fresh per-iteration locals (a String var-name + the ingredient's spec Dictionary) so the
		# lambda captures THESE by value at creation — never the reassigned loop variable `sv`.
		var slot_var: String = sv["var"]
		var spec := _rules.ingredient_spec(sv["ing"])
		var forces: Array = spec.get("forces", [])
		var allowed_classes: Array = spec.get("class", [])
		solver.add_constraint(
			[slot_var, "force_intent", "class_target"],
			func(asg: Dictionary) -> bool:
				if asg[slot_var] == "__skip__":
					return true
				return forces.has(asg["force_intent"]) and allowed_classes.has(asg["class_target"])
		)
	# Slot-conflict: for each slot with max 1, at most one placed ingredient targets it.
	var by_slot := {}
	for sv in slot_vars:
		var slot: String = sv["slot"]
		if not by_slot.has(slot):
			by_slot[slot] = []
		by_slot[slot].append(sv)
	for slot in by_slot:
		var slot_max: int = int(_rules.trait_slot(slot).get("max", 1))
		# Capture an immutable Array of the member var-names + the int max (fresh locals per iteration).
		var member_vars: Array = []
		for sv in by_slot[slot]:
			member_vars.append(sv["var"])
		var cap_max: int = slot_max
		solver.add_constraint(
			member_vars,
			func(asg: Dictionary) -> bool:
				var placed := 0
				for vname in member_vars:
					if asg[vname] == "__place__":
						placed += 1
				return placed <= cap_max
		)


func _add_tier_constraint(solver: CspSolver, ctx: Dictionary) -> void:
	# Constraint 3 — tier ceiling. tier_target cannot exceed base unless a tier-raising part is
	# consumed. The domain already encodes the ceiling, so this asserts the floor (>= base).
	var base_rank: int = _tier_rank(ctx["base_tier"])
	solver.add_constraint(
		["tier_target"],
		func(asg: Dictionary) -> bool: return _tier_rank(str(asg["tier_target"])) >= base_rank
	)


func _add_class_constraint(solver: CspSolver, ctx: Dictionary) -> void:
	# Constraint 4 — class rules. construct/hybrid outputs need a plating or core part; a hybrid
	# (organic host + construct-only ingredient) requires a bridging part to be present.
	var bridges: Array = _rules.bridge_parts()
	var ingredients: Array = ctx["ingredients"]
	solver.add_constraint(
		["class_target"],
		func(asg: Dictionary) -> bool:
			var cls: String = str(asg["class_target"])
			if cls == "organic":
				return true
			# construct or hybrid need a structural part (plating/core) among the ingredients.
			var has_struct := false
			var has_bridge := false
			for ing in ingredients:
				var spec := _rules.ingredient_spec(ing)
				var itype: String = str(spec.get("type", ""))
				if itype == "plating" or itype == "core" or itype == "soul":
					has_struct = true
				if bridges.has(itype) or bridges.has(ing):
					has_bridge = true
			if cls == "hybrid":
				return has_bridge
			return has_struct
	)


# --- classification (gate, constraint 5) -----------------------------------------------------


func _classify(op_spec: Dictionary, configs: Array, player_state: Dictionary) -> Dictionary:
	var taboo_spec: Dictionary = op_spec.get("taboo_when", {})
	var rep: Dictionary = configs[0]
	var is_taboo: bool = bool(rep.get("flags", {}).get("taboo", false))
	if not is_taboo:
		return {"verdict": Verdict.LEGAL, "reason": "", "unlock_cost": {}, "configs": configs}

	# Taboo op: evaluate the gate. Met -> LEGAL(taboo). Unmet -> TABOO(cost).
	var gate: Dictionary = taboo_spec.get("gate", {})
	var met := _gate_met(gate, player_state)
	if met:
		return {"verdict": Verdict.LEGAL, "reason": "", "unlock_cost": {}, "configs": configs}
	return {
		"verdict": Verdict.TABOO,
		"reason": _gate_reason(gate),
		"unlock_cost": _gate_cost(gate),
		"configs": configs,
	}


func _gate_met(gate: Dictionary, player_state: Dictionary) -> bool:
	var corruption: int = int(player_state.get("corruption", 0))
	var unlocks: Array = player_state.get("unlocks", [])
	var parts: Array = player_state.get("has_parts", [])
	var corruption_ok: bool = (
		not gate.has("corruption") or corruption >= _rules.threshold(str(gate["corruption"]))
	)
	var met := false
	if gate.has("corruption") and gate.has("or_unlock"):
		# Corruption-or-unlock gate (abomination): corruption>=T OR the unlock is owned.
		met = corruption_ok or unlocks.has(gate["or_unlock"])
	elif gate.has("requires_part"):
		# Corruption-and-part gate (god graft): need BOTH the part AND corruption>=T.
		met = corruption_ok and parts.has(gate["requires_part"])
	elif gate.has("requires_part_any") and gate.has("requires_unlock"):
		# Part-and-unlock gate (reanimate): the unlock AND at least one required part.
		met = (
			unlocks.has(gate["requires_unlock"]) and _has_any_part(parts, gate["requires_part_any"])
		)
	elif gate.has("requires_unlock"):
		# Corruption-and-unlock gate (self_splice): the unlock AND corruption>=T.
		met = corruption_ok and unlocks.has(gate["requires_unlock"])
	return met


func _has_any_part(parts: Array, needed: Array) -> bool:
	for p in needed:
		if parts.has(p):
			return true
	return false


func _gate_reason(gate: Dictionary) -> String:
	if gate.has("corruption") and gate.has("or_unlock"):
		var need: int = _rules.threshold(str(gate["corruption"]))
		return (
			"requires corruption >= " + str(need) + " or the " + str(gate["or_unlock"]) + " unlock"
		)
	if gate.has("corruption") and gate.has("requires_part"):
		var need2: int = _rules.threshold(str(gate["corruption"]))
		return "requires the " + str(gate["requires_part"]) + " and corruption >= " + str(need2)
	if gate.has("corruption") and gate.has("requires_unlock"):
		var need3: int = _rules.threshold(str(gate["corruption"]))
		return (
			"requires corruption >= "
			+ str(need3)
			+ " and the "
			+ str(gate["requires_unlock"])
			+ " unlock"
		)
	if gate.has("requires_part_any") and gate.has("requires_unlock"):
		return (
			"requires a "
			+ str(gate["requires_part_any"])
			+ " and the "
			+ str(gate["requires_unlock"])
			+ " unlock"
		)
	return "this rite is forbidden"


func _gate_cost(gate: Dictionary) -> Dictionary:
	var cost := {}
	if gate.has("corruption"):
		cost["corruption_min"] = _rules.threshold(str(gate["corruption"]))
	if gate.has("or_unlock"):
		cost["unlock"] = gate["or_unlock"]
	if gate.has("requires_unlock"):
		cost["unlock"] = gate["requires_unlock"]
	if gate.has("requires_part"):
		cost["part"] = gate["requires_part"]
	if gate.has("requires_part_any"):
		cost["part_any"] = gate["requires_part_any"]
	return cost


# --- config materialization ------------------------------------------------------------------


func _assignment_to_config(ctx: Dictionary, assignment: Dictionary, slot_vars: Array) -> Dictionary:
	var force_intent: Array = _force_intent_pair(ctx, str(assignment["force_intent"]))
	var trait_slots := {}
	var consumed: Array = []
	for sv in slot_vars:
		if assignment[sv["var"]] == "__place__":
			trait_slots[sv["slot"]] = sv["ing"]
			consumed.append(sv["ing"])
	# Non-slot ingredients (e.g. tier-raising cores already counted) still get consumed.
	for ing in ctx["ingredients"]:
		if not consumed.has(ing):
			consumed.append(ing)
	var flags := _derive_flags(ctx, assignment)
	return {
		"op": ctx["op"],
		"force_intent": force_intent,
		"tier_target": str(assignment["tier_target"]),
		"class_target": str(assignment["class_target"]),
		"trait_slots": trait_slots,
		"flags": flags,
		"consumed": consumed,
		"method": ctx["method"],
	}


func _force_intent_pair(ctx: Dictionary, primary: String) -> Array:
	# force_intent records [primary-carrier, secondary-carrier] for audit; the actual blend is
	# recomputed by lab_engine from the input creatures. Pair the chosen primary with the opposing
	# input's primary if present (so an opposed fuse records both poles).
	var pA: String = ctx["pA"]
	var pB: String = ctx["pB"]
	if ctx["has_b"]:
		if primary == pA and pB != "":
			return [pA, pB]
		if primary == pB and pA != "":
			return [pB, pA]
	var sA: String = ctx["sA"]
	if primary == pA and sA != "":
		return [pA, sA]
	return [primary, ""]


func _derive_flags(ctx: Dictionary, _assignment: Dictionary) -> Dictionary:
	# Flags are DERIVED from the op + inputs (SpliceRules §3 "flags ... derived, constrained").
	var flags := {
		"taboo": false,
		"abomination": false,
		"god_graft": false,
		"reanimated": false,
		"chimera": false,
	}
	var op: String = ctx["op"]
	var op_spec: Dictionary = ctx["op_spec"]
	var taboo_spec: Dictionary = op_spec.get("taboo_when", {})
	# fuse: opposed input primaries -> taboo + abomination.
	if op == "fuse" and ctx["has_b"] and _rules.force_is_opposed(ctx["pA"], ctx["pB"]):
		_set_flags(flags, taboo_spec.get("flags", ["taboo", "abomination"]))
	# graft: a god-rank ingredient -> taboo + god_graft.
	if op == "graft" and _has_god_rank_ingredient(ctx["ingredients"]):
		_set_flags(flags, taboo_spec.get("flags", ["taboo", "god_graft"]))
	# mutate: a cross-force gene -> taboo.
	if op == "mutate" and _has_cross_force_gene(ctx):
		_set_flags(flags, taboo_spec.get("flags", ["taboo"]))
	# self_splice / reanimate: always gated.
	if bool(op_spec.get("always_gated", false)):
		_set_flags(flags, taboo_spec.get("flags", ["taboo"]))
	return flags


# --- diagnostics + helpers -------------------------------------------------------------------


func _diagnose_failure(ctx: Dictionary, slot_vars: Array) -> String:
	# Produce a specific, dread-microcopy reason for the failing constraint (SpliceRules §3/§5).
	var host_force: String = ctx["pA"]
	for sv in slot_vars:
		var ing: String = sv["ing"]
		var spec := _rules.ingredient_spec(ing)
		var ing_classes: Array = spec.get("class", [])
		var ok_force := false
		for fc in ctx["force_domain"]:
			if spec.get("forces", []).has(fc):
				ok_force = true
				break
		# Would any achievable class_target make this ingredient legal?
		var ok_class := false
		for cls in ctx["class_domain"]:
			if ing_classes.has(cls):
				ok_class = true
				break
		# A construct-only part (class excludes organic) on an organic host that cannot be force-bridged
		# is the signature §5 ex3 case (crystal_lattice on organic Thanatos): a hybrid bridge could fix
		# the CLASS, but the part's force still rejects the host -> the flesh-rejection narrative.
		if not ing_classes.has("organic") and not ok_force:
			return _humanize(ing) + " rejects organic " + host_force + " flesh"
		if not ok_force:
			return _humanize(ing) + " rejects the " + host_force + " forces of this flesh"
		if not ok_class:
			return _humanize(ing) + " cannot occupy any legal slot on this " + host_force + " host"
	return "no consistent configuration exists for this operation"


func _humanize(token: String) -> String:
	return token.replace("_", " ")


func _set_flags(flags: Dictionary, names: Array) -> void:
	for n in names:
		flags[n] = true


func _has_god_rank_ingredient(ingredients: Array) -> bool:
	for ing in ingredients:
		if str(_rules.ingredient_spec(ing).get("rank", "wild")) == "god":
			return true
	return false


func _has_cross_force_gene(ctx: Dictionary) -> bool:
	var host_forces: Array = _distinct_nonempty([ctx["pA"], ctx["sA"]])
	for ing in ctx["ingredients"]:
		var gspec := _rules.gene_spec(ing)
		if gspec.is_empty():
			continue
		var compatible := false
		for fc in gspec.get("forces", []):
			if host_forces.has(fc):
				compatible = true
				break
		if not compatible:
			return true
	return false


func _ingredients_required(op_spec: Dictionary) -> bool:
	return str(op_spec.get("inputs", {}).get("ingredients", "optional")) == "required"


func _has_tier_raiser(ingredients: Array, op_spec: Dictionary) -> bool:
	# A part raises the tier ceiling if it is flagged raises_tier OR its type is in the op's
	# tier_rule.raise_with list (SpliceRules §3 constraint 3 / §4 tier_rule).
	var raise_with: Array = op_spec.get("tier_rule", {}).get("raise_with", [])
	for ing in ingredients:
		if _rules.ingredient_raises_tier(ing):
			return true
		var itype: String = str(_rules.ingredient_spec(ing).get("type", ""))
		if raise_with.has(itype):
			return true
	return false


func _class_domain(ingredients: Array) -> Array:
	var domain: Array = ["organic"]
	var bridges: Array = _rules.bridge_parts()
	var has_struct := false
	var has_bridge := false
	for ing in ingredients:
		var spec := _rules.ingredient_spec(ing)
		var itype: String = str(spec.get("type", ""))
		if itype == "plating" or itype == "core" or itype == "soul":
			has_struct = true
		if bridges.has(itype) or bridges.has(ing):
			has_bridge = true
	if has_struct:
		domain.append("construct")
	if has_bridge:
		domain.append("hybrid")
	return domain


func _tier_domain(base_tier: String, raised: bool) -> Array:
	var order := ["T1", "T2", "T3"]
	var base_rank := _tier_rank(base_tier)
	var ceiling := base_rank
	if raised:
		ceiling = min(3, base_rank + 1)
	var domain: Array = []
	for t in order:
		var r := _tier_rank(t)
		if r >= base_rank and r <= ceiling:
			domain.append(t)
	return domain


func _illegal(reason: String) -> Dictionary:
	return {"verdict": Verdict.ILLEGAL, "reason": reason, "unlock_cost": {}, "configs": []}


# --- pure value helpers ----------------------------------------------------------------------


func _distinct_nonempty(values: Array) -> Array:
	var out: Array = []
	for v in values:
		var s: String = str(v)
		if s != "" and s != "null" and not out.has(s):
			out.append(s)
	return out


func _max_tier(tA: String, tB: String) -> String:
	return tA if _tier_rank(tA) >= _tier_rank(tB) else tB


func _tier_rank(tier: String) -> int:
	var order: Dictionary = _rules.data.get("tier_order", {"T1": 1, "T2": 2, "T3": 3})
	return int(order.get(tier, 1))
