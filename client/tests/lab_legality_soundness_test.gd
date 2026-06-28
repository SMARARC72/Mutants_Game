extends GdUnitTestSuite
## Ruleset soundness property test (SpliceRules.md §7, Cluster 4 D3 DoD item 3). For N pseudo-random
## inputs ACROSS ALL FIVE OPS the solver's output must satisfy EVERY constraint (no rule violated);
## ILLEGAL/TABOO inputs must NEVER yield a creature. Uses the canonical RNG for reproducible input
## generation (NO global randf/randi). The constraints re-checked here are the five from SpliceRules §3.

const SpliceRulesScript := preload("res://infrastructure/lab/splice_rules.gd")
const LegalitySolverScript := preload("res://infrastructure/lab/legality_solver.gd")
const LabBenchScript := preload("res://application/lab/lab_bench.gd")

const N := 200
const FORCES := ["Gaia", "Ouranos", "Cosmos", "Chaos", "Eros", "Thanatos"]
const TIERS := ["T1", "T2", "T3"]
const OPS := ["fuse", "graft", "mutate", "self_splice", "reanimate"]
const ORGANS := [
	"venom_gland", "eye", "horn", "crest", "claw", "wing", "tail", "reactor", "god_core"
]
const GENES := ["venom", "ironblood", "quickstep", "verdant", "servo_weave"]
const PARTS := ["soul", "core", "god_core"]

var _rules: SpliceRules


func before() -> void:
	_rules = SpliceRulesScript.load_default()
	assert_object(_rules).is_not_null()


# --- property: every LEGAL/TABOO config satisfies all constraints; ILLEGAL yields no creature ---
func test_soundness_over_random_inputs_all_ops() -> void:
	var bench := LabBenchScript.new(_rules)
	var rng := CanonicalRNG.new(20260628)
	for i in N:
		var op: String = OPS[rng.randint(0, OPS.size() - 1)]
		var a := _rand_creature(rng, "A")
		var b: Variant = _rand_creature(rng, "B") if op == "fuse" else null
		var ings := _rand_ingredients(rng, op)
		var method: String = "precise" if rng.randint(0, 1) == 0 else "wild"
		var player := _rand_player(rng)
		var op_id := "soundness_%d" % i

		var v := bench.preview(a, b, ings, method, player, op)
		var verdict := int(v["verdict"])

		if verdict == LegalitySolverScript.Verdict.ILLEGAL:
			assert_int((v["configs"] as Array).size()).is_equal(0)
			assert_str(str(v["reason"])).is_not_empty()
			var c := bench.commit(a, b, ings, method, player, 7, op_id, op)
			assert_bool(c.has("creature")).is_false()
			continue

		# LEGAL or TABOO: there must be >=1 config and each must satisfy every constraint.
		var configs: Array = v["configs"]
		assert_int(configs.size()).is_greater(0)
		for cfg in configs:
			_assert_config_sound(cfg, a, b)

		if verdict == LegalitySolverScript.Verdict.TABOO:
			var ct := bench.commit(a, b, ings, method, player, 7, op_id, op)
			assert_bool(ct.has("creature")).is_false()
		else:
			var cl := bench.commit(a, b, ings, method, player, 7, op_id, op)
			assert_bool(cl.has("creature")).is_true()
			_assert_config_sound(cl["splice_config"], a, b)


# Opposed-pair fuses are ALWAYS taboo-flagged (never silently legal without the gate).
func test_opposed_fuses_always_flag_taboo() -> void:
	var bench := LabBenchScript.new(_rules)
	var clean := {"corruption": 0, "unlocks": [], "has_parts": []}
	for pair in _rules.data["opposed"]:
		var a := ["A", str(pair[0]), "", "T2"]
		var b := ["B", str(pair[1]), "", "T2"]
		var v := bench.preview(a, b, [], "precise", clean, "fuse")
		# corruption 0, no unlock => opposed must be TABOO (gated), never LEGAL.
		assert_int(int(v["verdict"])).is_equal(LegalitySolverScript.Verdict.TABOO)
		assert_bool(bool(v["configs"][0]["flags"]["taboo"])).is_true()
		assert_bool(bool(v["configs"][0]["flags"]["abomination"])).is_true()


# --- constraint re-checker (SpliceRules §3) --------------------------------------------------


func _assert_config_sound(cfg: Dictionary, a: Array, b: Variant) -> void:
	var present := _input_forces(a, b)
	var fi: Array = cfg["force_intent"]
	var chosen := str(fi[0])

	# Constraint 1 — force_intent is present on the inputs AND no non-input force was chosen.
	assert_bool(present.has(chosen)).is_true()
	for fc in FORCES:
		if not present.has(fc):
			assert_bool(chosen == fc).is_false()  # a non-input force is NEVER chosen

	# Constraint 2 (organs) — trait_slots[slot] is a LIST; each placed organ is force/class-compatible
	# and a slot never exceeds its max.
	var trait_slots: Dictionary = cfg["trait_slots"]
	for slot in trait_slots:
		var placed: Array = trait_slots[slot]
		assert_int(placed.size()).is_less_equal(int(_rules.trait_slot(slot).get("max", 1)))
		for ing in placed:
			var spec := _rules.ingredient_spec(ing)
			assert_bool(spec.get("forces", []).has(chosen)).is_true()
			assert_bool(spec.get("class", []).has(str(cfg["class_target"]))).is_true()

	# Constraint 2 (genes) — each placed gene is class-compatible.
	for gene in cfg.get("genes", []):
		assert_bool(_rules.gene_spec(gene).get("class", []).has(str(cfg["class_target"]))).is_true()

	# Constraint 3 — tier_target within [base .. ceiling].
	var base := _max_tier(str(a[3]), _b_tier(a, b))
	assert_bool(_tier_ge(str(cfg["tier_target"]), base)).is_true()

	# Constraint 4 — class_target is one of the legal classes.
	assert_bool(["organic", "construct", "hybrid"].has(str(cfg["class_target"]))).is_true()


# --- random input generation (canonical RNG only) -------------------------------------------


func _rand_creature(rng: CanonicalRNG, tag: String) -> Array:
	var prim: String = FORCES[rng.randint(0, FORCES.size() - 1)]
	var sec: String = ""
	if rng.randint(0, 2) > 0:
		sec = FORCES[rng.randint(0, FORCES.size() - 1)]
		if sec == prim:
			sec = ""
	var tier: String = TIERS[rng.randint(0, TIERS.size() - 1)]
	return [tag, prim, sec, tier]


func _rand_ingredients(rng: CanonicalRNG, op: String) -> Array:
	var pool: Array = GENES if op == "mutate" else ORGANS
	# Required-ingredient ops always supply >=1; fuse may supply 0. Occasionally supply 2 (same-slot).
	var lo := 0 if op == "fuse" else 1
	var count := rng.randint(lo, 2)
	var out: Array = []
	for _i in count:
		out.append(pool[rng.randint(0, pool.size() - 1)])
	return out


func _rand_player(rng: CanonicalRNG) -> Dictionary:
	var unlocks: Array = []
	for u in ["abomination_rites", "auto_chirurgy", "necromancy"]:
		if rng.randint(0, 2) == 0:
			unlocks.append(u)
	var parts: Array = []
	for p in PARTS:
		if rng.randint(0, 2) == 0:
			parts.append(p)
	return {"corruption": rng.randint(0, 100), "unlocks": unlocks, "has_parts": parts}


# --- pure tier helpers ----------------------------------------------------------------------


func _input_forces(a: Array, b: Variant) -> Array:
	var out: Array = [str(a[1])]
	if str(a[2]) != "":
		out.append(str(a[2]))
	if b is Array and (b as Array).size() >= 4:
		out.append(str(b[1]))
		if str(b[2]) != "":
			out.append(str(b[2]))
	return out


func _b_tier(a: Array, b: Variant) -> String:
	return str(b[3]) if b is Array and (b as Array).size() >= 4 else str(a[3])


func _max_tier(x: String, y: String) -> String:
	return x if _tier_rank(x) >= _tier_rank(y) else y


func _tier_ge(x: String, y: String) -> bool:
	return _tier_rank(x) >= _tier_rank(y)


func _tier_rank(t: String) -> int:
	return {"T1": 1, "T2": 2, "T3": 3}.get(t, 1)
