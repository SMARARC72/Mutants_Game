extends GdUnitTestSuite
## The four worked examples from Mutants_Game_SpliceRules.md §5 — each must produce the spec's
## verdict (ADR-015, Cluster 4 D3, DoD item 3). Drives the real ruleset
## (res://catalog/splice_rules.json) through SpliceRules -> LegalitySolver -> LabBench. The CSP
## gates; client/domain/lab_engine.gd computes the numbers.

const SpliceRulesScript := preload("res://infrastructure/lab/splice_rules.gd")
const LegalitySolverScript := preload("res://infrastructure/lab/legality_solver.gd")
const LabBenchScript := preload("res://application/lab/lab_bench.gd")

var _rules: SpliceRules


func before() -> void:
	_rules = SpliceRulesScript.load_default()
	assert_object(_rules).is_not_null()


func _bench() -> LabBench:
	return LabBenchScript.new(_rules)


# Example 1 — compatible fuse (LEGAL): Thanatos/Chaos x Thanatos/Ouranos, precise, no taboo.
func test_example1_compatible_fuse_is_legal() -> void:
	var a := ["Ruinmaw", "Thanatos", "Chaos", "T2"]
	var b := ["Gloamcat", "Thanatos", "Ouranos", "T2"]
	var player := {"corruption": 0, "unlocks": [], "has_parts": []}
	var v := _bench().preview(a, b, [], "precise", player, "fuse")
	assert_int(int(v["verdict"])).is_equal(LegalitySolverScript.Verdict.LEGAL)
	assert_int((v["configs"] as Array).size()).is_greater(0)
	var cfg: Dictionary = v["configs"][0]
	assert_bool(bool(cfg["flags"]["taboo"])).is_false()


# Example 2 — opposed fuse (TABOO at corruption 35 < T_abom 40, then LEGAL once unlocked).
# Cosmos/Eros x Chaos/Ouranos: Cosmos<->Chaos opposed.
func test_example2_opposed_fuse_is_taboo_then_legal() -> void:
	var a := ["Palehart", "Cosmos", "Eros", "T2"]
	var b := ["Emberwyrm", "Chaos", "Ouranos", "T3"]
	var gated := {"corruption": 35, "unlocks": [], "has_parts": []}
	var v := _bench().preview(a, b, [], "wild", gated, "fuse")
	assert_int(int(v["verdict"])).is_equal(LegalitySolverScript.Verdict.TABOO)
	# The TABOO verdict still returns the candidate config(s) + an unlock cost the UI can offer.
	assert_int((v["configs"] as Array).size()).is_greater(0)
	assert_bool(bool(v["configs"][0]["flags"]["abomination"])).is_true()
	assert_int(int(v["unlock_cost"]["corruption_min"])).is_equal(40)
	assert_str(str(v["unlock_cost"]["unlock"])).is_equal("abomination_rites")

	# Once the rite is unlocked, the same op becomes LEGAL.
	var unlocked := {"corruption": 35, "unlocks": ["abomination_rites"], "has_parts": []}
	var v2 := _bench().preview(a, b, [], "wild", unlocked, "fuse")
	assert_int(int(v2["verdict"])).is_equal(LegalitySolverScript.Verdict.LEGAL)

	# Equivalently, crossing the corruption threshold also makes it LEGAL.
	var corrupt := {"corruption": 40, "unlocks": [], "has_parts": []}
	var v3 := _bench().preview(a, b, [], "wild", corrupt, "fuse")
	assert_int(int(v3["verdict"])).is_equal(LegalitySolverScript.Verdict.LEGAL)


# Example 3 — illegal graft: crystal_lattice (Cosmos/construct-only) onto an organic Thanatos
# beast with no bridging part -> ILLEGAL with a reason; NO creature.
func test_example3_crystal_lattice_on_organic_thanatos_is_illegal() -> void:
	var host := ["Gravewyrm", "Thanatos", "", "T2"]
	var player := {"corruption": 0, "unlocks": [], "has_parts": []}
	var v := _bench().preview(host, null, ["crystal_lattice"], "precise", player, "graft")
	assert_int(int(v["verdict"])).is_equal(LegalitySolverScript.Verdict.ILLEGAL)
	assert_int((v["configs"] as Array).size()).is_equal(0)
	assert_str(str(v["reason"])).contains("organic")
	assert_str(str(v["reason"])).contains("Thanatos")

	# commit must also refuse: NO creature is produced on an illegal op.
	var c := _bench().commit(host, null, ["crystal_lattice"], "precise", player, 99, "ex3", "graft")
	assert_int(int(c["verdict"])).is_equal(LegalitySolverScript.Verdict.ILLEGAL)
	assert_bool(c.has("creature")).is_false()


# Example 4 — god-organ graft (LEGAL/taboo): graft a god_core onto a T3 beast; the player HAS the
# part and corruption 72 >= T_god 70 -> LEGAL (taboo).
func test_example4_god_core_graft_meets_gate_is_legal() -> void:
	var host := ["Titanhusk", "Gaia", "", "T3"]
	var player := {"corruption": 72, "unlocks": [], "has_parts": ["god_core"]}
	var v := _bench().preview(host, null, ["god_core"], "precise", player, "graft")
	assert_int(int(v["verdict"])).is_equal(LegalitySolverScript.Verdict.LEGAL)
	assert_bool(bool(v["configs"][0]["flags"]["god_graft"])).is_true()

	# Below the threshold (or missing the part) the SAME graft is TABOO, not LEGAL.
	var low := {"corruption": 50, "unlocks": [], "has_parts": ["god_core"]}
	var v2 := _bench().preview(host, null, ["god_core"], "precise", low, "graft")
	assert_int(int(v2["verdict"])).is_equal(LegalitySolverScript.Verdict.TABOO)
	assert_str(str(v2["unlock_cost"]["part"])).is_equal("god_core")

	var no_part := {"corruption": 90, "unlocks": [], "has_parts": []}
	var v3 := _bench().preview(host, null, ["god_core"], "precise", no_part, "graft")
	assert_int(int(v3["verdict"])).is_equal(LegalitySolverScript.Verdict.TABOO)
