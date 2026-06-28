extends GdUnitTestSuite
## Unit tests for the self-contained CSP core (infrastructure/lab/csp_solver.gd) and the SpliceRules
## loader/validator (infrastructure/lab/splice_rules.gd). The CSP backtracking must yield a complete
## valid assignment or a clean empty result — never a half-formed one (ADR-015 / SpliceRules §3).

const CspSolverScript := preload("res://infrastructure/lab/csp_solver.gd")
const SpliceRulesScript := preload("res://infrastructure/lab/splice_rules.gd")


# A classic toy CSP: x,y,z in 1..3 with x<y<z has exactly one solution (1,2,3).
func test_backtracking_finds_the_only_solution() -> void:
	var s := CspSolverScript.new()
	s.add_variable("x", [1, 2, 3])
	s.add_variable("y", [1, 2, 3])
	s.add_variable("z", [1, 2, 3])
	s.add_constraint(["x", "y"], func(a: Dictionary) -> bool: return int(a["x"]) < int(a["y"]))
	s.add_constraint(["y", "z"], func(a: Dictionary) -> bool: return int(a["y"]) < int(a["z"]))
	var sol := s.solve()
	assert_int(int(sol["x"])).is_equal(1)
	assert_int(int(sol["y"])).is_equal(2)
	assert_int(int(sol["z"])).is_equal(3)


# An over-constrained CSP has NO solution -> clean empty result (never partial).
func test_unsatisfiable_returns_empty() -> void:
	var s := CspSolverScript.new()
	s.add_variable("x", [1, 2])
	s.add_variable("y", [1, 2])
	s.add_constraint(["x", "y"], func(a: Dictionary) -> bool: return int(a["x"]) < int(a["y"]))
	s.add_constraint(["x", "y"], func(a: Dictionary) -> bool: return int(a["x"]) > int(a["y"]))
	assert_bool(s.solve().is_empty()).is_true()
	assert_bool(s.has_solution()).is_false()


# solve_all enumerates every consistent assignment in a stable (insertion) order.
func test_solve_all_enumerates_all() -> void:
	var s := CspSolverScript.new()
	s.add_variable("a", [0, 1])
	s.add_variable("b", [0, 1])
	# no constraints -> 4 combinations.
	assert_int(s.solve_all().size()).is_equal(4)


# The real ruleset loads + validates.
func test_default_ruleset_loads() -> void:
	var rules := SpliceRulesScript.load_default()
	assert_object(rules).is_not_null()
	assert_int(rules.threshold("T_abom")).is_equal(40)
	assert_int(rules.threshold("T_god")).is_equal(70)
	assert_bool(rules.force_is_opposed("Cosmos", "Chaos")).is_true()
	assert_bool(rules.force_is_opposed("Chaos", "Cosmos")).is_true()  # symmetric
	assert_bool(rules.force_is_opposed("Cosmos", "Eros")).is_false()


# A malformed ruleset is REJECTED (null), with last_error set — never a half-validated object.
func test_malformed_ruleset_is_rejected() -> void:
	# missing required force "Chaos".
	var bad := '{"schema_version":1,"forces":["Gaia","Ouranos","Cosmos","Eros","Thanatos"],'
	bad += '"opposed":[],"thresholds":{"T_abom":40,"T_god":70,"T_self":85},'
	bad += '"unlocks":["abomination_rites","auto_chirurgy","necromancy"],'
	bad += '"operations":{"fuse":{"inputs":{}},"mutate":{"inputs":{}},"graft":{"inputs":{}},'
	bad += '"self_splice":{"inputs":{}},"reanimate":{"inputs":{}}},"trait_slots":{}}'
	var rules := SpliceRulesScript.load_text(bad)
	assert_object(rules).is_null()
	assert_str(SpliceRulesScript.last_error).contains("Chaos")

	# non-object root.
	assert_object(SpliceRulesScript.load_text("[]")).is_null()


# Symmetric-opposed violation (both directions listed) is rejected.
func test_opposed_both_directions_rejected() -> void:
	var bad := '{"schema_version":1,"forces":["Gaia","Ouranos","Cosmos","Chaos","Eros","Thanatos"],'
	bad += '"opposed":[["Cosmos","Chaos"],["Chaos","Cosmos"]],'
	bad += '"thresholds":{"T_abom":40,"T_god":70,"T_self":85},'
	bad += '"unlocks":["abomination_rites","auto_chirurgy","necromancy"],'
	bad += '"operations":{"fuse":{"inputs":{}},"mutate":{"inputs":{}},"graft":{"inputs":{}},'
	bad += '"self_splice":{"inputs":{}},"reanimate":{"inputs":{}}},"trait_slots":{}}'
	var rules := SpliceRulesScript.load_text(bad)
	assert_object(rules).is_null()
	assert_str(SpliceRulesScript.last_error).contains("both directions")
