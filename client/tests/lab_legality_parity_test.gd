extends GdUnitTestSuite
## Contamination guard / parity (ADR-015, Cluster 4 D3 DoD item 4): a committed splice's result
## EQUALS LabEngine.fuse on the same inputs + the same canonical seed. This proves the CSP/LabBench
## contributed CONFIG ONLY — not a single number. If LabBench recomputed any stat, blend, tier, or
## the entropy/corruption ledger, this would diverge from the pure oracle.

const SpliceRulesScript := preload("res://infrastructure/lab/splice_rules.gd")
const LabBenchScript := preload("res://application/lab/lab_bench.gd")

var _rules: SpliceRules


func before() -> void:
	_rules = SpliceRulesScript.load_default()
	assert_object(_rules).is_not_null()


# A committed LEGAL fuse equals LabEngine.fuse(a, b, method, numeric_rng(seed, op_id)) field-for-field.
func test_committed_fuse_equals_oracle() -> void:
	var a := ["Ruinmaw", "Thanatos", "Chaos", "T2"]
	var b := ["Gloamcat", "Thanatos", "Ouranos", "T2"]
	var player := {"corruption": 0, "unlocks": [], "has_parts": []}
	var seed := 4242
	var op_id := "parity_fuse_1"

	var res := LabBenchScript.new(_rules).commit(a, b, [], "precise", player, seed, op_id, "fuse")
	assert_int(int(res["verdict"])).is_equal(0)  # LEGAL
	var creature: Dictionary = res["creature"]

	# Rebuild the EXACT rng the bench passed to the oracle, then call the oracle directly.
	var rng := LabBenchScript.numeric_rng(seed, op_id)
	var expected := LabEngine.fuse(a, b, "precise", rng)

	_assert_creatures_equal(creature, expected)

	# The CSP's contribution (the persisted config) is present and is pure config, no numbers.
	var cfg: Dictionary = res["splice_config"]
	assert_bool(cfg.has("force_intent")).is_true()
	assert_bool(cfg.has("trait_slots")).is_true()
	assert_bool(cfg.has("flags")).is_true()
	assert_str(str(cfg["rng_seed_tag"])).is_equal(op_id)
	# No stat/hp/bst/entropy/corruption keys leak into the config (those are the oracle's alone).
	for forbidden in ["stats", "hp", "bst", "entropy", "corruption"]:
		assert_bool(cfg.has(forbidden)).is_false()


# Committing the SAME (seed, op_id) twice yields the IDENTICAL creature (reproducibility, §6).
func test_commit_is_reproducible() -> void:
	var a := ["Palehart", "Cosmos", "Eros", "T2"]
	var b := ["Wyrm", "Cosmos", "Gaia", "T3"]
	var player := {"corruption": 0, "unlocks": [], "has_parts": []}
	var bench := LabBenchScript.new(_rules)

	var r1 := bench.commit(a, b, [], "wild", player, 1234, "rep", "fuse")
	var r2 := bench.commit(a, b, [], "wild", player, 1234, "rep", "fuse")
	assert_int(int(r1["verdict"])).is_equal(0)
	_assert_creatures_equal(r1["creature"], r2["creature"])
	# Different op_id => a different (still-canonical) sub-stream => may differ; same op_id => identical.
	assert_str(str(r1["splice_config"]["rng_seed_tag"])).is_equal("rep")


# An opposed (taboo) fuse, once the gate is met, ALSO matches the oracle bit-for-bit — including the
# oracle's own taboo ledger (entropy/corruption). The CSP only flipped flags.taboo; numbers are oracle.
func test_committed_taboo_fuse_equals_oracle() -> void:
	var a := ["Palehart", "Cosmos", "Eros", "T2"]
	var b := ["Emberwyrm", "Chaos", "Ouranos", "T3"]
	var player := {"corruption": 80, "unlocks": ["abomination_rites"], "has_parts": []}
	var seed := 909
	var op_id := "parity_taboo"

	var res := LabBenchScript.new(_rules).commit(a, b, [], "wild", player, seed, op_id, "fuse")
	assert_int(int(res["verdict"])).is_equal(0)  # LEGAL (gate met)
	var creature: Dictionary = res["creature"]
	assert_bool(bool(creature["taboo"])).is_true()  # the ORACLE detected the opposed pair

	var expected := LabEngine.fuse(a, b, "wild", LabBenchScript.numeric_rng(seed, op_id))
	_assert_creatures_equal(creature, expected)
	# The oracle charged the taboo ledger (entropy bonus + corruption) — proof the numbers are its own.
	assert_int(int(creature["corruption"])).is_equal(18)


# A committed SINGLE-CREATURE op (graft) equals LabEngine.fuse(host, host-mirroring partner, ...) on
# the same numeric rng — exercising the config-influenced _compute/_partner_from_config path (not the
# near-tautological fuse path). Proves the single-creature path also contributes config only.
func test_committed_graft_equals_host_preserving_oracle() -> void:
	var host := ["Titanhusk", "Gaia", "Chaos", "T2"]
	var player := {"corruption": 0, "unlocks": [], "has_parts": []}
	var seed := 5151
	var op_id := "parity_graft"

	var res := LabBenchScript.new(_rules).commit(
		host, null, ["claw"], "precise", player, seed, op_id, "graft"
	)
	assert_int(int(res["verdict"])).is_equal(0)  # LEGAL
	var creature: Dictionary = res["creature"]

	# The bench mirrors the host's own poles + tier into the partner (config-INDEPENDENT). Rebuild that
	# partner + the exact rng, call the oracle directly, and assert field-for-field equality.
	var partner := ["graft_part", "Gaia", "Chaos", "T2"]
	var expected := LabEngine.fuse(
		host, partner, "precise", LabBenchScript.numeric_rng(seed, op_id)
	)
	_assert_creatures_equal(creature, expected)
	# Host-preserving: the committed creature's forces are exactly the host's (blend of [Gaia,Chaos]x2).
	assert_str(str(creature["prim"])).is_equal("Gaia")
	assert_str(str(creature["sec"])).is_equal("Chaos")
	assert_str(str(creature["tier"])).is_equal("T2")


# CONFIG-INDEPENDENCE (the P1 fix's teeth): a single-creature op with MULTIPLE legal configs. Across
# many op_ids the config pick VARIES (>1 distinct config observed), yet EVERY committed creature equals
# the oracle on the HOST-MIRRORING partner with that op_id's numeric stream. If the config leaked into
# the partner (the old bug), a config that chose force_intent=secondary would flip prim/sec and the
# creature would NOT match the host-mirror oracle. (Numbers legitimately differ across op_ids because
# each has its own numeric sub-stream; what must hold is config-independence, asserted per op_id.)
func test_config_pick_never_perturbs_numbers() -> void:
	var host := ["Titanhusk", "Gaia", "Chaos", "T2"]
	var partner := ["graft_part", "Gaia", "Chaos", "T2"]  # the host-mirroring partner (config-independent)
	var player := {"corruption": 0, "unlocks": [], "has_parts": []}
	var bench := LabBenchScript.new(_rules)

	# claw is compatible with both Gaia and Chaos -> force_intent has multiple legal values -> >1 config.
	var pv := bench.preview(host, null, ["claw"], "precise", player, "graft")
	assert_int((pv["configs"] as Array).size()).is_greater(1)

	var seed := 777
	var distinct_configs := {}
	for n in 40:
		var op_id := "vary_%d" % n
		var res := bench.commit(host, null, ["claw"], "precise", player, seed, op_id, "graft")
		distinct_configs[str(res["splice_config"]["force_intent"])] = true
		# Whatever config was picked, the numbers equal the HOST-MIRROR oracle for this op_id's stream.
		var expected := LabEngine.fuse(
			host, partner, "precise", LabBenchScript.numeric_rng(seed, op_id)
		)
		_assert_creatures_equal(res["creature"], expected)
		# Forces are ALWAYS the host's, never flipped by the config pick.
		assert_str(str(res["creature"]["prim"])).is_equal("Gaia")
		assert_str(str(res["creature"]["sec"])).is_equal("Chaos")
	# The config pick genuinely varied across op_ids (otherwise the test would be vacuous).
	assert_int(distinct_configs.size()).is_greater(1)


func _assert_creatures_equal(got: Dictionary, exp: Dictionary) -> void:
	for k in ["name", "prim", "sec", "tier", "method"]:
		assert_str(str(got[k])).is_equal(str(exp[k]))
	assert_bool(bool(got["taboo"])).is_equal(bool(exp["taboo"]))
	for k in ["hp", "bst", "entropy", "corruption"]:
		assert_int(int(got[k])).is_equal(int(exp[k]))
	var gs: Dictionary = got["stats"]
	var es: Dictionary = exp["stats"]
	assert_int(gs.size()).is_equal(es.size())
	for k in es:
		assert_int(int(gs[k])).is_equal(int(es[k]))
