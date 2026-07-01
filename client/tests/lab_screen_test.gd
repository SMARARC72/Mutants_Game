extends GdUnitTestSuite
## Phase 5 · Slice 3a — the LAB UI DoD, driven HEADLESSLY.
##   * a known-LEGAL fuse previews LEGAL with the expected forces/tier (config), and committing it
##     yields the oracle's entropy/corruption cost;
##   * a known-ILLEGAL combo previews ILLEGAL with a non-empty reason;
##   * an opposed combo previews TABOO with an unlock/corruption cost;
##   * COMMIT of a LEGAL op adds exactly ONE creature_instance to the party whose cached stats EQUAL
##     LabEngine on the SAME config+seed (the contamination guard) and debits the consumed ingredient;
##   * an ILLEGAL/unaffordable commit adds nothing and consumes nothing;
##   * the screen builds its themed UI (op row, pickers, verdict panel, action buttons) headless.
## Drives a CODE-INSTANTIATED GameController (injected FakeDal) + LabScreen with auto-build OFF.

const GameControllerScript := preload("res://application/game/game_controller.gd")
const FakeDalScript := preload("res://infrastructure/dal/fake_dal.gd")
const LabScreenScript := preload("res://presentation/lab/lab_screen.gd")
const LegalitySolverScript := preload("res://infrastructure/lab/legality_solver.gd")
const LabBenchScript := preload("res://application/lab/lab_bench.gd")

const TEST_SEED := 0x1AB5EED

# Known fixtures (forces/tiers verified against docs/creature_registry.csv):
#   SB07 Leaf-hare    Eros/Gaia  T1   AD10 Thornmane  Eros/Gaia T2  -> compatible fuse (LEGAL)
#   AD04 Palehart     Cosmos/Eros T2  AD01 Ruinmaw    Chaos/Thanatos T2 -> opposed (Cosmos<->Chaos) TABOO
#   AD06              Gaia/Chaos T2   (mutate host)
const PARTY_LEGAL := [{"species_id": "SB07"}, {"species_id": "AD10"}]
const PARTY_OPPOSED := [{"species_id": "AD04"}, {"species_id": "AD01"}]
const PARTY_MUTATE := [{"species_id": "AD06"}]

# --- harness ---------------------------------------------------------------------------------- #


func _make_game(party: Array) -> Node:
	var gc: Node = GameControllerScript.new()
	add_child(gc)
	gc.call("configure", FakeDalScript.make())
	var run: RunContext = gc.call("new_run", TEST_SEED)
	run.party = party.duplicate(true)
	return gc


func _make_screen(gc: Node) -> Control:
	var screen: Control = LabScreenScript.new()
	screen.call("set_game", gc)
	screen.call("set_auto_build", false)
	add_child(screen)
	screen.call("build")
	return screen


# --- preview: LEGAL / ILLEGAL / TABOO --------------------------------------------------------- #


func test_legal_fuse_previews_legal_with_expected_forces_and_tier() -> void:
	var gc := _make_game(PARTY_LEGAL)
	var screen := _make_screen(gc)
	screen.call("select_op", "fuse")
	screen.call("set_creature_a", 0)
	screen.call("set_creature_b", 1)
	var v: Dictionary = screen.call("preview")
	assert_int(int(v["verdict"])).is_equal(LegalitySolverScript.Verdict.LEGAL)
	assert_int((v["configs"] as Array).size()).is_greater(0)
	var cfg: Dictionary = v["configs"][0]
	# Eros/Gaia x Eros/Gaia: the resolved force_intent is one of the input poles (the CSP enumerates
	# the force universe in declared order, so it is Gaia OR Eros — assert membership, not a literal),
	# and the tier ceiling is max(T1, T2) = T2. A same-pole fuse is not taboo.
	assert_bool(["Eros", "Gaia"].has(str(cfg["force_intent"][0]))).is_true()
	assert_str(str(cfg["tier_target"])).is_equal("T2")
	assert_bool(bool(cfg["flags"]["taboo"])).is_false()
	screen.queue_free()
	gc.queue_free()


func test_legal_fuse_commit_reports_the_oracle_cost() -> void:
	# The "cost" the oracle reports (entropy/corruption ledger) materializes on COMMIT (preview has no
	# roll). A clean (non-taboo) fuse charges entropy but no corruption.
	var gc := _make_game(PARTY_LEGAL)
	var screen := _make_screen(gc)
	screen.call("select_op", "fuse")
	screen.call("set_creature_a", 0)
	screen.call("set_creature_b", 1)
	var res: Dictionary = screen.call("commit")
	assert_int(int(res["verdict"])).is_equal(LegalitySolverScript.Verdict.LEGAL)
	var creature: Dictionary = res["creature"]
	assert_int(int(creature["entropy"])).is_greater(0)  # the oracle charged an entropy cost
	assert_int(int(creature["corruption"])).is_equal(0)  # a clean fuse is not taboo
	screen.queue_free()
	gc.queue_free()


func test_illegal_mutate_previews_illegal_with_reason() -> void:
	# servo_weave is a construct-only gene; an organic Gaia/Chaos host with no bridge cannot weave it.
	var gc := _make_game(PARTY_MUTATE)
	var screen := _make_screen(gc)
	gc.call("inventory").add("gene", "servo_weave", 1)
	screen.call("build")  # rebuild so the drawer shows the new vial
	screen.call("select_op", "mutate")
	screen.call("set_creature_a", 0)
	screen.call("toggle_ingredient", "servo_weave")
	var v: Dictionary = screen.call("preview")
	assert_int(int(v["verdict"])).is_equal(LegalitySolverScript.Verdict.ILLEGAL)
	assert_str(str(v["reason"])).is_not_empty()
	screen.queue_free()
	gc.queue_free()


func test_opposed_fuse_previews_taboo_with_unlock_cost() -> void:
	# Cosmos/Eros x Chaos/Thanatos: Cosmos<->Chaos opposed -> TABOO at corruption 0 / no rite.
	var gc := _make_game(PARTY_OPPOSED)
	var screen := _make_screen(gc)
	screen.call("select_op", "fuse")
	screen.call("set_creature_a", 0)
	screen.call("set_creature_b", 1)
	var v: Dictionary = screen.call("preview")
	assert_int(int(v["verdict"])).is_equal(LegalitySolverScript.Verdict.TABOO)
	assert_str(str(v["reason"])).is_not_empty()
	# The TABOO verdict carries an unlock cost the UI can offer (corruption threshold + the rite).
	assert_int(int(v["unlock_cost"]["corruption_min"])).is_equal(40)
	assert_str(str(v["unlock_cost"]["unlock"])).is_equal("abomination_rites")
	assert_bool(bool(v["configs"][0]["flags"]["abomination"])).is_true()
	screen.queue_free()
	gc.queue_free()


# --- commit: contamination guard + inventory debit ------------------------------------------- #


func test_commit_adds_one_instance_equal_to_oracle_on_same_config_and_seed() -> void:
	var gc := _make_game(PARTY_LEGAL)
	var run: RunContext = gc.call("run")
	var before := run.party.size()
	var screen := _make_screen(gc)
	screen.call("select_op", "fuse")
	screen.call("set_creature_a", 0)
	screen.call("set_creature_b", 1)
	var res: Dictionary = screen.call("commit")
	assert_int(int(res["verdict"])).is_equal(LegalitySolverScript.Verdict.LEGAL)

	# Exactly ONE creature added — and (Wave 5: costs bite) BOTH parents consumed: 2 leave, 1 arrives.
	assert_int(run.party.size()).is_equal(before - 1)
	var added: Dictionary = run.party[run.party.size() - 1]
	assert_bool(bool(added["lineage"]["spliced"])).is_true()
	assert_str(str(added["lineage"]["op"])).is_equal("fuse")

	# CONTAMINATION GUARD: the added instance's cached stats EQUAL LabEngine.fuse on the SAME inputs +
	# the EXACT canonical numeric stream the bench used (rebuilt from run.seed + the op's rng_seed_tag).
	var op_id := str(res["splice_config"]["rng_seed_tag"])
	var a := ["Leaf-hare", "Eros", "Gaia", "T1"]
	var b := ["Thornmane", "Eros", "Gaia", "T2"]
	var expected := LabEngine.fuse(a, b, "precise", LabBenchScript.numeric_rng(run.seed, op_id))
	var cached: Dictionary = added["stats_cached"]
	assert_str(str(cached["prim"])).is_equal(str(expected["prim"]))
	assert_str(str(cached["sec"])).is_equal(str(expected["sec"]))
	assert_str(str(cached["tier"])).is_equal(str(expected["tier"]))
	assert_int(int(cached["hp"])).is_equal(int(expected["hp"]))
	assert_int(int(cached["bst"])).is_equal(int(expected["bst"]))
	assert_int(int(added["entropy"])).is_equal(int(expected["entropy"]))
	var es: Dictionary = expected["stats"]
	var gs: Dictionary = cached["stats"]
	assert_int(gs.size()).is_equal(es.size())
	for k in es:
		assert_int(int(gs[k])).is_equal(int(es[k]))
	screen.queue_free()
	gc.queue_free()


func test_legal_mutate_commit_debits_the_consumed_gene() -> void:
	# A Gaia host + an in-force Gaia gene (ironblood) -> LEGAL mutate; committing consumes the gene.
	var gc := _make_game(PARTY_MUTATE)
	var inv: InventoryAdapter = gc.call("inventory")
	inv.add("gene", "ironblood", 2)  # two on hand
	inv.add("plating", "scale", 1)  # an unrelated part that must NOT be touched
	var run: RunContext = gc.call("run")
	var before := run.party.size()
	var screen := _make_screen(gc)
	screen.call("select_op", "mutate")
	screen.call("set_creature_a", 0)
	screen.call("toggle_ingredient", "ironblood")
	var res: Dictionary = screen.call("commit")
	assert_int(int(res["verdict"])).is_equal(LegalitySolverScript.Verdict.LEGAL)
	# Wave 5 (costs bite): the mutate HOST is consumed and the hybrid replaces it — same size.
	assert_int(run.party.size()).is_equal(before)
	var newborn: Dictionary = run.party[run.party.size() - 1]
	assert_bool(bool((newborn["lineage"] as Dictionary).get("spliced", false))).is_true()
	# EXACT debit: one ironblood removed, one remains; the unrelated scale untouched.
	assert_int(inv.count("gene", "ironblood")).is_equal(1)
	assert_int(inv.count("plating", "scale")).is_equal(1)
	assert_bool((res["consumed"] as Array).has("ironblood")).is_true()
	screen.queue_free()
	gc.queue_free()


func test_illegal_commit_adds_and_consumes_nothing() -> void:
	var gc := _make_game(PARTY_MUTATE)
	var inv: InventoryAdapter = gc.call("inventory")
	inv.add("gene", "servo_weave", 1)
	var run: RunContext = gc.call("run")
	var before := run.party.size()
	var screen := _make_screen(gc)
	screen.call("build")
	screen.call("select_op", "mutate")
	screen.call("set_creature_a", 0)
	screen.call("toggle_ingredient", "servo_weave")
	var res: Dictionary = screen.call("commit")
	assert_int(int(res["verdict"])).is_not_equal(LegalitySolverScript.Verdict.LEGAL)
	assert_bool(res.has("creature")).is_false()  # no garbage creature
	assert_int(run.party.size()).is_equal(before)  # nothing added
	assert_int(inv.count("gene", "servo_weave")).is_equal(1)  # nothing consumed
	screen.queue_free()
	gc.queue_free()


# --- Wave 5: costs bite + recursion + fresh-run reagents --------------------------------------- #


func test_commit_consumes_parents_and_applies_costs() -> void:
	# A gate-met TABOO fuse (run corruption 50 >= T_abom 40) is LEGAL and carries the oracle's
	# corruption ledger: committing must land that corruption on the RUN track, drink essence, and
	# CONSUME the parents — the hybrid replaces them in the roster.
	var gc := _make_game(PARTY_OPPOSED)
	var run: RunContext = gc.call("run")
	run.corruption = 50
	run.essence = 40
	var screen := _make_screen(gc)
	screen.call("select_op", "fuse")
	screen.call("set_creature_a", 0)
	screen.call("set_creature_b", 1)
	var res: Dictionary = screen.call("commit")
	assert_int(int(res["verdict"])).is_equal(LegalitySolverScript.Verdict.LEGAL)
	var creature: Dictionary = res["creature"]
	assert_bool(bool(creature["taboo"])).is_true()
	assert_int(int(creature["corruption"])).is_greater(0)
	# The oracle's corruption ledger lands on the run track; essence is debited by the rite cost.
	assert_int(run.corruption).is_equal(50 + int(creature["corruption"]))
	assert_int(run.essence).is_equal(40 - LabScreenScript.SPLICE_ESSENCE_COST)
	# Parents consumed: the hybrid REPLACES them (2 -> 1); no parent species remains in the party.
	assert_int(run.party.size()).is_equal(1)
	var newborn: Dictionary = run.party[0]
	assert_bool(bool((newborn["lineage"] as Dictionary).get("spliced", false))).is_true()
	for entry in run.party:
		var sid := str((entry as Dictionary).get("species_id", ""))
		assert_bool(["AD04", "AD01"].has(sid)).is_false()
	screen.queue_free()
	gc.queue_free()


func test_essence_debit_floors_at_zero() -> void:
	# The rite drinks essence but never below zero — a fresh (essence-poor) run can still splice.
	var gc := _make_game(PARTY_LEGAL)
	var run: RunContext = gc.call("run")
	run.essence = 3
	var screen := _make_screen(gc)
	screen.call("select_op", "fuse")
	screen.call("set_creature_a", 0)
	screen.call("set_creature_b", 1)
	var res: Dictionary = screen.call("commit")
	assert_int(int(res["verdict"])).is_equal(LegalitySolverScript.Verdict.LEGAL)
	assert_int(run.essence).is_equal(0)
	screen.queue_free()
	gc.queue_free()


func test_committed_hybrid_is_repickable_and_respliceable() -> void:
	# RECURSION: a committed hybrid resolves to a real bench tuple (from stats_cached) and can itself
	# be fused again — stronger, stranger, one-of-one.
	var gc := _make_game([{"species_id": "SB07"}, {"species_id": "AD10"}, {"species_id": "SB05"}])
	var run: RunContext = gc.call("run")
	var screen := _make_screen(gc)
	screen.call("select_op", "fuse")
	screen.call("set_creature_a", 0)
	screen.call("set_creature_b", 1)
	var first: Dictionary = screen.call("commit")
	assert_int(int(first["verdict"])).is_equal(LegalitySolverScript.Verdict.LEGAL)
	# Party is now [SB05, hybrid]; the hybrid carries no catalog id but a full cached identity.
	assert_int(run.party.size()).is_equal(2)
	var hybrid: Dictionary = run.party[1]
	assert_str(str(hybrid.get("species_id", ""))).is_equal("")
	# Re-splice: hybrid (subject) x SB05 (donor) previews LEGAL and commits into a new one-of-one.
	screen.call("set_creature_a", 1)
	screen.call("set_creature_b", 0)
	var v: Dictionary = screen.call("preview")
	assert_int(int(v["verdict"])).is_equal(LegalitySolverScript.Verdict.LEGAL)
	var second: Dictionary = screen.call("commit")
	assert_int(int(second["verdict"])).is_equal(LegalitySolverScript.Verdict.LEGAL)
	assert_int(run.party.size()).is_equal(1)
	var deep: Dictionary = run.party[0]
	var lineage: Dictionary = deep["lineage"]
	assert_bool(bool(lineage.get("spliced", false))).is_true()
	# The plate identity survives the recursion (the dominant line still renders a real plate).
	assert_str(str(lineage.get("portrait_species", ""))).is_not_empty()
	screen.queue_free()
	gc.queue_free()


func test_fresh_run_mutate_is_committable_with_seeded_reagents() -> void:
	# Wave 5: new_run seeds 1 gene-vial + 2 organs (REAL splice_rules.json keys) so Mutate is
	# committable on a brand-new run — no farming required before the first rite.
	var gc: Node = GameControllerScript.new()
	add_child(gc)
	gc.call("configure", FakeDalScript.make())
	var run: RunContext = gc.call("new_run", TEST_SEED)
	var inv: InventoryAdapter = gc.call("inventory")
	assert_int(inv.count("gene", "verdant")).is_equal(1)
	assert_int(inv.count("organ", "claw")).is_equal(1)
	assert_int(inv.count("organ", "horn")).is_equal(1)
	var party_size := run.party.size()
	var screen := _make_screen(gc)
	screen.call("select_op", "mutate")
	screen.call("set_creature_a", 0)  # the starter lead (Eros/Gaia) — verdant (Eros) is in-force
	screen.call("toggle_ingredient", "verdant")
	var v: Dictionary = screen.call("preview")
	assert_int(int(v["verdict"])).is_equal(LegalitySolverScript.Verdict.LEGAL)
	assert_bool(bool(v["ingredients_available"])).is_true()
	var res: Dictionary = screen.call("commit")
	assert_int(int(res["verdict"])).is_equal(LegalitySolverScript.Verdict.LEGAL)
	# The gene-vial was consumed; the host was replaced by the hybrid (party size unchanged).
	assert_int(inv.count("gene", "verdant")).is_equal(0)
	assert_int(run.party.size()).is_equal(party_size)
	screen.queue_free()
	gc.queue_free()


# --- UI build --------------------------------------------------------------------------------- #


func test_screen_builds_themed_ui() -> void:
	var gc := _make_game(PARTY_LEGAL)
	var screen := _make_screen(gc)
	assert_object(screen.find_child("LabTitle", true, false)).is_not_null()
	assert_object(screen.find_child("OpRow", true, false)).is_not_null()
	assert_object(screen.find_child("CreatureAPicker", true, false)).is_not_null()
	assert_object(screen.find_child("CreatureBPicker", true, false)).is_not_null()
	assert_object(screen.find_child("VerdictLabel", true, false)).is_not_null()
	assert_object(screen.find_child("PreviewButton", true, false)).is_not_null()
	assert_object(screen.find_child("CommitButton", true, false)).is_not_null()
	assert_object(screen.find_child("BackButton", true, false)).is_not_null()
	# The party pickers list one button per party creature.
	assert_object(screen.find_child("PickA_0", true, false)).is_not_null()
	assert_object(screen.find_child("PickB_1", true, false)).is_not_null()
	screen.queue_free()
	gc.queue_free()


func test_selecting_mutate_hides_the_donor_section() -> void:
	var gc := _make_game(PARTY_MUTATE)
	var screen := _make_screen(gc)
	assert_str(str(screen.call("current_op"))).is_equal("fuse")
	screen.call("select_op", "mutate")
	assert_str(str(screen.call("current_op"))).is_equal("mutate")
	var b_section := screen.find_child("CreatureBSection", true, false) as Control
	assert_object(b_section).is_not_null()
	assert_bool(b_section.visible).is_false()
	screen.queue_free()
	gc.queue_free()
