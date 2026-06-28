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


# --- mutate (genes): in-force LEGAL; cross-force TABOO->LEGAL when gated; class-incompatible ILLEGAL ---
func test_mutate_in_force_gene_is_legal() -> void:
	var host := ["Bulwark", "Gaia", "", "T2"]
	var clean := {"corruption": 0, "unlocks": [], "has_parts": []}
	# ironblood is a Gaia gene on a Gaia host -> in-force, not taboo.
	var v := _bench().preview(host, null, ["ironblood"], "precise", clean, "mutate")
	assert_int(int(v["verdict"])).is_equal(LegalitySolverScript.Verdict.LEGAL)
	assert_bool(bool(v["configs"][0]["flags"]["taboo"])).is_false()
	assert_bool((v["configs"][0]["genes"] as Array).has("ironblood")).is_true()


func test_mutate_cross_force_gene_is_taboo_then_legal() -> void:
	var host := ["Bulwark", "Gaia", "", "T2"]
	# quickstep (Ouranos) on a Gaia host -> cross-force -> taboo-lite, gated by T_abom/abomination_rites.
	var v := _bench().preview(
		host,
		null,
		["quickstep"],
		"precise",
		{"corruption": 0, "unlocks": [], "has_parts": []},
		"mutate"
	)
	assert_int(int(v["verdict"])).is_equal(LegalitySolverScript.Verdict.TABOO)
	assert_bool(bool(v["configs"][0]["flags"]["taboo"])).is_true()

	var gated := {"corruption": 40, "unlocks": [], "has_parts": []}
	var v2 := _bench().preview(host, null, ["quickstep"], "precise", gated, "mutate")
	assert_int(int(v2["verdict"])).is_equal(LegalitySolverScript.Verdict.LEGAL)


func test_mutate_class_incompatible_gene_is_illegal() -> void:
	var host := ["Bulwark", "Gaia", "", "T2"]
	var gated := {"corruption": 90, "unlocks": ["abomination_rites"], "has_parts": []}
	# servo_weave is construct-only; an organic host with no bridge cannot weave it -> ILLEGAL.
	var v := _bench().preview(host, null, ["servo_weave"], "precise", gated, "mutate")
	assert_int(int(v["verdict"])).is_equal(LegalitySolverScript.Verdict.ILLEGAL)
	assert_int((v["configs"] as Array).size()).is_equal(0)
	assert_str(str(v["reason"])).contains("gene")


func test_mutate_conflicting_genes_is_illegal() -> void:
	# venom <-> verdant conflict; a host where BOTH are otherwise placeable still cannot take both.
	var host := ["Chimera", "Thanatos", "Eros", "T2"]
	var gated := {"corruption": 90, "unlocks": ["abomination_rites"], "has_parts": []}
	var v := _bench().preview(host, null, ["venom", "verdant"], "precise", gated, "mutate")
	assert_int(int(v["verdict"])).is_equal(LegalitySolverScript.Verdict.ILLEGAL)


# --- self_splice: LEGAL only with auto_chirurgy + corruption >= T_self, else TABOO ---
func test_self_splice_requires_unlock_and_corruption() -> void:
	var player_host := ["Player", "Eros", "", "T2"]
	# Missing unlock / below T_self -> TABOO.
	var v := _bench().preview(
		player_host,
		null,
		["heart"],
		"precise",
		{"corruption": 50, "unlocks": [], "has_parts": []},
		"self_splice"
	)
	assert_int(int(v["verdict"])).is_equal(LegalitySolverScript.Verdict.TABOO)
	assert_bool(bool(v["configs"][0]["flags"]["chimera"])).is_true()

	# Has auto_chirurgy AND corruption >= T_self(85) -> LEGAL.
	var ready := {"corruption": 90, "unlocks": ["auto_chirurgy"], "has_parts": []}
	var v2 := _bench().preview(player_host, null, ["heart"], "precise", ready, "self_splice")
	assert_int(int(v2["verdict"])).is_equal(LegalitySolverScript.Verdict.LEGAL)

	# Unlock but corruption below threshold -> still TABOO.
	var low := {"corruption": 80, "unlocks": ["auto_chirurgy"], "has_parts": []}
	var v3 := _bench().preview(player_host, null, ["heart"], "precise", low, "self_splice")
	assert_int(int(v3["verdict"])).is_equal(LegalitySolverScript.Verdict.TABOO)


# --- reanimate: LEGAL only with necromancy + a soul/core part, else TABOO ---
func test_reanimate_requires_necromancy_and_part() -> void:
	var snapshot := ["Snapshot", "Thanatos", "", "T3"]
	# No necromancy / no part -> TABOO.
	var v := _bench().preview(
		snapshot,
		null,
		["soul"],
		"precise",
		{"corruption": 0, "unlocks": [], "has_parts": []},
		"reanimate"
	)
	assert_int(int(v["verdict"])).is_equal(LegalitySolverScript.Verdict.TABOO)
	assert_bool(bool(v["configs"][0]["flags"]["reanimated"])).is_true()

	# necromancy + a soul part -> LEGAL.
	var ready := {"corruption": 0, "unlocks": ["necromancy"], "has_parts": ["soul"]}
	var v2 := _bench().preview(snapshot, null, ["soul"], "precise", ready, "reanimate")
	assert_int(int(v2["verdict"])).is_equal(LegalitySolverScript.Verdict.LEGAL)

	# necromancy but NO part -> TABOO.
	var no_part := {"corruption": 0, "unlocks": ["necromancy"], "has_parts": []}
	var v3 := _bench().preview(snapshot, null, ["soul"], "precise", no_part, "reanimate")
	assert_int(int(v3["verdict"])).is_equal(LegalitySolverScript.Verdict.TABOO)


# --- input-count enforcement (SpliceRules §2) ---
func test_input_count_mismatch_is_illegal() -> void:
	var clean := {"corruption": 0, "unlocks": [], "has_parts": []}
	# fuse with only 1 creature -> ILLEGAL.
	var v := _bench().preview(["Lone", "Gaia", "", "T2"], null, [], "precise", clean, "fuse")
	assert_int(int(v["verdict"])).is_equal(LegalitySolverScript.Verdict.ILLEGAL)
	assert_str(str(v["reason"])).contains("requires 2 creature")

	# graft with 2 creatures -> ILLEGAL.
	var a := ["H", "Gaia", "", "T2"]
	var b := ["X", "Gaia", "", "T2"]
	var v2 := _bench().preview(a, b, ["claw"], "precise", clean, "graft")
	assert_int(int(v2["verdict"])).is_equal(LegalitySolverScript.Verdict.ILLEGAL)
	assert_str(str(v2["reason"])).contains("requires 1 creature")


# --- slot capacity teeth: head max 1, limb max 2 ---
func test_slot_capacity_constraints() -> void:
	var clean := {"corruption": 0, "unlocks": [], "has_parts": []}
	# Two head organs (venom_gland + crest both target head, max 1) on a fuse -> no config places both.
	var two_head := _bench().preview(
		["A", "Thanatos", "Eros", "T2"],
		["B", "Thanatos", "Eros", "T2"],
		["venom_gland", "crest"],
		"precise",
		clean,
		"fuse"
	)
	assert_int(int(two_head["verdict"])).is_equal(LegalitySolverScript.Verdict.LEGAL)
	for cfg in two_head["configs"]:
		var head: Array = cfg["trait_slots"].get("head", [])
		assert_int(head.size()).is_less_equal(1)

	# Two limb organs (claw + tail, limb max 2) -> at least one config places BOTH.
	var two_limb := _bench().preview(
		["A", "Gaia", "Chaos", "T2"],
		["B", "Gaia", "Chaos", "T2"],
		["claw", "tail"],
		"precise",
		clean,
		"fuse"
	)
	assert_int(int(two_limb["verdict"])).is_equal(LegalitySolverScript.Verdict.LEGAL)
	var found_both := false
	for cfg in two_limb["configs"]:
		if (cfg["trait_slots"].get("limb", []) as Array).size() == 2:
			found_both = true
	assert_bool(found_both).is_true()

	# Three limb organs on a REQUIRED-ingredient graft (limb max 2) -> cannot place all three -> ILLEGAL.
	var three_limb := _bench().preview(
		["H", "Gaia", "Chaos", "T2"], null, ["claw", "tail", "horn"], "precise", clean, "graft"
	)
	# horn targets head, claw+tail target limb -> graft.slots organ cap (1) makes 3 organs impossible.
	assert_int(int(three_limb["verdict"])).is_equal(LegalitySolverScript.Verdict.ILLEGAL)
