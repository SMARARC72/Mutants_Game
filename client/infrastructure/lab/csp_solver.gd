class_name CspSolver
extends RefCounted
## CspSolver — a small, self-contained finite-domain constraint-satisfaction solver with
## chronological backtracking (ADR-015). INFRASTRUCTURE layer: pure structure, NO outcome math.
##
## Why self-contained and not vendored godot-constraint-solving: that addon's public surface is a
## Wave-Function-Collapse tile solver (2D grid collapse), not a generic finite-domain CSP with
## arbitrary constraint predicates over named variables — which is exactly what SpliceRules §3
## requires (variables force_intent / tier_target / class_target / trait_slots[] / flags, with the
## five custom rule-constraints). The CSP *semantics* are what matter (SpliceRules.md §3 / Cluster4
## D3 explicitly permits a self-contained GDScript CSP if the lib can't be vendored cleanly), so we
## implement just the backtracking core here and drive it from legality_solver.gd. Determinism: the
## variable + domain *order* is the order they are added, so enumeration is reproducible; choice
## among multiple legal assignments is made by the caller via the canonical RNG, not here.
##
## A variable has a name + an ordered Array domain. A constraint is a Callable(assignment) -> bool
## that is checked once ALL of its scope variables are assigned (so partial assignments are pruned
## as early as their last variable binds). solve() returns the FIRST consistent assignment (a
## Dictionary name->value) or {} if none exists; solve_all() returns every consistent assignment in
## a stable order. Backtracking guarantees a complete valid assignment or a clean empty result —
## never a half-formed one.

var _var_names: Array = []
var _domains: Dictionary = {}  # name -> Array of candidate values
# Each constraint: { "scope": Array[String], "fn": Callable }.
var _constraints: Array = []


func add_variable(name: String, domain: Array) -> void:
	_var_names.append(name)
	_domains[name] = domain.duplicate()


## Register a constraint over `scope` variables. `fn` is Callable(Dictionary assignment) -> bool;
## it is only invoked once every variable in `scope` is bound, and must return true if the (partial)
## assignment is still consistent.
func add_constraint(scope: Array, fn: Callable) -> void:
	_constraints.append({"scope": scope.duplicate(), "fn": fn})


## First consistent full assignment, or {} if none. Order = domain insertion order (deterministic).
func solve() -> Dictionary:
	var out := _backtrack({}, 0, false)
	return out[0] if out.size() > 0 else {}


## Every consistent full assignment, in a stable (deterministic) order.
func solve_all() -> Array:
	return _backtrack({}, 0, true)


func has_solution() -> bool:
	return not solve().is_empty()


# --- backtracking core -----------------------------------------------------------------------


func _backtrack(assignment: Dictionary, index: int, collect_all: bool) -> Array:
	if index >= _var_names.size():
		# Complete assignment that survived every incremental check.
		return [assignment.duplicate()]
	var name: String = _var_names[index]
	var results: Array = []
	for value in _domains[name]:
		var trial := assignment.duplicate()
		trial[name] = value
		if not _consistent(trial, name):
			continue
		var sub := _backtrack(trial, index + 1, collect_all)
		if sub.size() > 0:
			if not collect_all:
				return sub
			results.append_array(sub)
	return results


## Check every constraint whose scope is now fully bound and which INCLUDES the just-assigned var
## (so each constraint fires exactly once — when its last variable binds — pruning early).
func _consistent(assignment: Dictionary, just_assigned: String) -> bool:
	for c in _constraints:
		var scope: Array = c["scope"]
		if not scope.has(just_assigned):
			continue
		var all_bound := true
		for v in scope:
			if not assignment.has(v):
				all_bound = false
				break
		if not all_bound:
			continue
		var fn: Callable = c["fn"]
		if not bool(fn.call(assignment)):
			return false
	return true
