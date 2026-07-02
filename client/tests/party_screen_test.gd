extends GdUnitTestSuite
## Phase 5 · Slice 3b — Party/grimoire + leveling + 1 gear slot DoD, driven HEADLESSLY.
##   * the party screen lists the injected run's party + selects a member + sets the ACTIVE/lead
##     creature (persisted to the run);
##   * a RESONANCE awaken applies the LevelEngine (oracle) result onto the creature_instance (asserted
##     VIA THE ENGINE, not a reimplementation) and costs essence;
##   * the OVERCLOCK gamble is CANONICAL (same seed => same outcome) and banks entropy + run corruption;
##   * equipping a gear item changes the creature's effective gear effects per the gear effects +
##     persists; unequip reverts.
## Drives a CODE-INSTANTIATED GameController + party screen with an injected FakeDal.

const GameControllerScript := preload("res://application/game/game_controller.gd")
const FakeDalScript := preload("res://infrastructure/dal/fake_dal.gd")
const PartyScreenScript := preload("res://presentation/party/party_screen.gd")
const CreatureSheetScript := preload("res://application/game/creature_sheet.gd")
const LevelingServiceScript := preload("res://application/game/leveling_service.gd")
const GearServiceScript := preload("res://application/game/gear_service.gd")
const GearCatalogScript := preload("res://infrastructure/catalog/gear_catalog.gd")

const TEST_SEED := 0x5A1D_3B01
## A gear id from client/catalog/gear.json with NUMERIC effects (so equipping shifts the totals).
const GEAR_ID := "luckbone_charm"


func _make_game() -> Node:
	var gc: Node = GameControllerScript.new()
	add_child(gc)
	gc.call("configure", FakeDalScript.make())
	gc.call("new_run", TEST_SEED)
	return gc


func _make_screen(gc: Node) -> Control:
	var screen: Control = PartyScreenScript.new()
	screen.call("set_game", gc)
	screen.call("set_auto_build", false)
	add_child(screen)
	screen.call("build_from_game")
	return screen


# === party listing + active/lead ============================================================== #


func test_party_screen_lists_the_party() -> void:
	var gc := _make_game()
	var run: RunContext = gc.call("run")
	var screen := _make_screen(gc)
	# One roster row per party member (the starter party has 3).
	for i in run.party.size():
		assert_object(screen.find_child("PartyRow%d" % i, true, false)).is_not_null()
	# The detail panel renders engine-derived stats for the selected member.
	assert_object(screen.find_child("DetailStats", true, false)).is_not_null()
	screen.queue_free()
	gc.queue_free()


func test_select_and_set_active_persists() -> void:
	var gc := _make_game()
	var run: RunContext = gc.call("run")
	var screen := _make_screen(gc)
	# Select the second member and set it as lead.
	screen.call("select_creature", 1)
	assert_int(int(screen.call("selected_index"))).is_equal(1)
	var ok: bool = screen.call("set_active")
	assert_bool(ok).is_true()
	# Persisted on the run (GameController reads it back).
	assert_int(int(gc.call("active_creature_index"))).is_equal(1)
	assert_int(int(run.flags.get("active_creature", -1))).is_equal(1)
	screen.queue_free()
	gc.queue_free()


# === leveling: resonance awaken (oracle) ====================================================== #


func test_resonance_awaken_applies_engine_result_and_costs_essence() -> void:
	var gc := _make_game()
	var run: RunContext = gc.call("run")
	# Fund the awaken (battle xp folds into essence; the awaken spends it).
	run.essence = 100
	var screen := _make_screen(gc)
	screen.call("select_creature", 0)
	var creature: Dictionary = screen.call("selected_creature")
	var expr_before := float(creature.get("expression", LevelingServiceScript.DEFAULT_EXPRESSION))

	var ledger: Dictionary = screen.call("awaken_resonance")
	assert_bool(bool(ledger["ok"])).is_true()
	# Essence was debited by the service's resonance cost.
	assert_int(run.essence).is_equal(100 - LevelingServiceScript.RESONANCE_ESSENCE_COST)
	# The creature's expression rose (awaken surge is +0.10..0.22, capped at 1.0).
	var expr_after := float(run.party[0]["expression"])
	assert_float(expr_after).is_greater(expr_before)
	assert_int(int(run.party[0]["awakenings"])).is_equal(1)
	screen.queue_free()
	gc.queue_free()


func test_resonance_matches_a_direct_level_engine_awaken() -> void:
	# The applied result must EQUAL what LevelEngine.awaken (the oracle) produces for the SAME
	# canonical sub-stream — proving the screen applies the engine, not a reimplementation.
	var gc := _make_game()
	var run: RunContext = gc.call("run")
	run.essence = 100
	var creature: Dictionary = run.party[0]

	# Reproduce the service's stream + a fresh awaken to get the oracle's expected expression.
	var op := (
		LevelingServiceScript.RESONANCE_SALT
		^ int(
			(str(creature.get("species_id", "")) + "|" + str(creature.get("nickname", ""))).hash()
		)
		^ (int(creature.get("awakenings", 0)) << 8)
	)
	var rng := CanonicalRNG.new(run.seed).substream(op)
	var gene_bonus: Dictionary = {}
	var genes: Array = []
	var expected: Dictionary = LevelEngine.awaken(
		rng, float(creature.get("expression", 0.30)), gene_bonus, genes
	)

	var screen := _make_screen(gc)
	screen.call("select_creature", 0)
	screen.call("awaken_resonance")
	assert_float(float(run.party[0]["expression"])).is_equal_approx(
		float(expected["expression"]), 1e-9
	)
	screen.queue_free()
	gc.queue_free()


func test_resonance_blocked_when_essence_short() -> void:
	var gc := _make_game()
	var run: RunContext = gc.call("run")
	run.essence = 0
	var screen := _make_screen(gc)
	screen.call("select_creature", 0)
	var ledger: Dictionary = screen.call("awaken_resonance")
	assert_bool(bool(ledger["ok"])).is_false()
	assert_str(str(ledger["reason"])).is_equal("insufficient_essence")
	# No mutation: still the baseline, no awakening.
	assert_int(int(run.party[0].get("awakenings", 0))).is_equal(0)
	screen.queue_free()
	gc.queue_free()


# === leveling: overclock gamble (canonical) =================================================== #


func test_overclock_is_canonical_and_costs_corruption_entropy() -> void:
	# Same seed => same overclock outcome (entropy roll + awakening), and it banks entropy on the
	# creature + run corruption.
	var gc_a := _make_game()
	var run_a: RunContext = gc_a.call("run")
	var screen_a := _make_screen(gc_a)
	screen_a.call("select_creature", 0)
	var corruption_before := run_a.corruption
	var ledger_a: Dictionary = screen_a.call("overclock")

	var gc_b := _make_game()
	var screen_b := _make_screen(gc_b)
	screen_b.call("select_creature", 0)
	var ledger_b: Dictionary = screen_b.call("overclock")

	assert_bool(bool(ledger_a["ok"])).is_true()
	# Determinism: identical entropy roll + resulting expression + events for the same seed.
	assert_int(int(ledger_a["entropy_gained"])).is_equal(int(ledger_b["entropy_gained"]))
	assert_float(float(ledger_a["expression_after"])).is_equal_approx(
		float(ledger_b["expression_after"]), 1e-9
	)
	assert_str(str(ledger_a["events"])).is_equal(str(ledger_b["events"]))
	# Cost ledger: entropy is banked on the creature, corruption on the run.
	var gained := int(ledger_a["entropy_gained"])
	assert_int(gained).is_greater(0)
	assert_int(int(run_a.party[0]["entropy"])).is_equal(gained)
	assert_int(run_a.corruption).is_equal(corruption_before + gained)
	# Overclock forces an awakening (expression rose, awakening count up).
	assert_float(float(run_a.party[0]["expression"])).is_greater(
		float(ledger_a["expression_before"])
	)
	assert_int(int(run_a.party[0]["awakenings"])).is_equal(1)
	screen_a.queue_free()
	screen_b.queue_free()
	gc_a.queue_free()
	gc_b.queue_free()


# === gear: equip / unequip (catalog effects; W17 ownership-gated) ============================= #


## Fund the run drawer with one unit of GEAR_ID (W17: equipping requires actual ownership).
func _own_gear(gc: Node) -> void:
	(gc.call("inventory") as InventoryAdapter).add("gear", GEAR_ID, 1)


func test_equip_gear_changes_effective_effects_and_persists() -> void:
	var gc := _make_game()
	var run: RunContext = gc.call("run")
	_own_gear(gc)
	var screen := _make_screen(gc)
	screen.call("select_creature", 0)
	var gear_catalog: GearCatalog = gc.call("gear_catalog")

	# Before: no gear -> empty effect totals.
	var before := CreatureSheetScript.gear_effect_totals(run.party[0], gear_catalog)
	assert_bool(before.is_empty()).is_true()

	var ledger: Dictionary = screen.call("equip_gear", GEAR_ID)
	assert_bool(bool(ledger["ok"])).is_true()
	# Persisted on the creature_instance.
	assert_str(str(run.party[0]["equipped_gear"])).is_equal(GEAR_ID)

	# Effective effects now equal the gear's catalog effects (per the gear effects, not hand-math).
	var after := CreatureSheetScript.gear_effect_totals(run.party[0], gear_catalog)
	var gear_row := gear_catalog.get_by_id(GEAR_ID)
	var gear_effects: Dictionary = gear_row["effects"]
	for field in gear_effects:
		assert_float(float(after.get(field, 0.0))).is_equal_approx(float(gear_effects[field]), 1e-9)
	# The ledger delta reflects the change.
	var delta: Dictionary = ledger["delta"]
	for field in gear_effects:
		assert_float(float(delta.get(field, 0.0))).is_equal_approx(float(gear_effects[field]), 1e-9)
	screen.queue_free()
	gc.queue_free()


func test_unequip_reverts_gear() -> void:
	var gc := _make_game()
	var run: RunContext = gc.call("run")
	_own_gear(gc)
	var screen := _make_screen(gc)
	screen.call("select_creature", 0)
	var gear_catalog: GearCatalog = gc.call("gear_catalog")

	screen.call("equip_gear", GEAR_ID)
	assert_str(str(run.party[0]["equipped_gear"])).is_equal(GEAR_ID)
	# W17: equipping MOVED the piece out of the drawer (one owned charm, one wearer).
	var inv: InventoryAdapter = gc.call("inventory")
	assert_int(inv.count("gear", GEAR_ID)).is_equal(0)

	var ledger: Dictionary = screen.call("unequip_gear")
	assert_bool(bool(ledger["ok"])).is_true()
	assert_str(str(run.party[0]["equipped_gear"])).is_equal("")
	# Effects reverted to empty; the piece is back in the drawer.
	var after := CreatureSheetScript.gear_effect_totals(run.party[0], gear_catalog)
	assert_bool(after.is_empty()).is_true()
	assert_int(inv.count("gear", GEAR_ID)).is_equal(1)
	screen.queue_free()
	gc.queue_free()


func test_equip_unknown_gear_is_a_no_op() -> void:
	var gc := _make_game()
	var run: RunContext = gc.call("run")
	var screen := _make_screen(gc)
	screen.call("select_creature", 0)
	var ledger: Dictionary = screen.call("equip_gear", "not_a_real_gear")
	assert_bool(bool(ledger["ok"])).is_false()
	assert_str(str(run.party[0].get("equipped_gear", ""))).is_equal("")
	screen.queue_free()
	gc.queue_free()


func test_equip_unowned_gear_is_gated_and_greyed() -> void:
	# W17 gear honesty: a catalog piece the run does not OWN cannot be equipped, and its row is
	# rendered disabled (greyed with acquisition flavour), never hidden.
	var gc := _make_game()
	var run: RunContext = gc.call("run")
	var screen := _make_screen(gc)
	screen.call("select_creature", 0)
	var ledger: Dictionary = screen.call("equip_gear", GEAR_ID)  # never funded
	assert_bool(bool(ledger["ok"])).is_false()
	assert_str(str(ledger["reason"])).is_equal("not_owned")
	assert_str(str(run.party[0].get("equipped_gear", ""))).is_equal("")
	var row := screen.find_child("EquipButton_%s" % GEAR_ID, true, false) as Button
	assert_object(row).is_not_null()
	assert_bool(row.disabled).is_true()
	screen.queue_free()
	gc.queue_free()


func test_owned_gear_row_is_enabled() -> void:
	var gc := _make_game()
	_own_gear(gc)
	var screen := _make_screen(gc)
	screen.call("select_creature", 0)
	var row := screen.find_child("EquipButton_%s" % GEAR_ID, true, false) as Button
	assert_object(row).is_not_null()
	assert_bool(row.disabled).is_false()
	screen.queue_free()
	gc.queue_free()


func test_detail_panel_renders_stat_rows() -> void:
	# W17 scryed legibility: the six pole stats render as icon+bar+NUMBER rows (StatRows).
	var gc := _make_game()
	var screen := _make_screen(gc)
	screen.call("select_creature", 0)
	for stat: String in ["Bulk", "Celerity", "Ward", "Spike", "Vitality", "Bane"]:
		var row := screen.find_child("StatRow_%s" % stat, true, false)
		assert_object(row).is_not_null()
		# The bar AUGMENTS the number — both live in the row.
		assert_object(row.find_child("StatBar", true, false)).is_not_null()
		assert_object(row.find_child("StatNumber", true, false)).is_not_null()
	screen.queue_free()
	gc.queue_free()


func test_reequipping_worn_gear_never_consumes_a_duplicate() -> void:
	# Codex #57 P2: same-id equip is a no-op — it must not eat a spare copy.
	var gc := _make_game()
	var run: RunContext = gc.call("run")
	var inv: InventoryAdapter = gc.call("inventory")
	var catalog: GearCatalog = gc.call("gear_catalog")
	var gear_id := str((catalog.all()[0] as Dictionary).get("id", ""))
	inv.add(GearService.GEAR_ITEM_TYPE, gear_id, 2)
	var creature: Dictionary = run.party[0]
	var first: Dictionary = GearService.equip(creature, gear_id, catalog, inv)
	assert_bool(bool(first.get("ok", false))).is_true()
	assert_int(inv.count(GearService.GEAR_ITEM_TYPE, gear_id)).is_equal(1)
	var again: Dictionary = GearService.equip(creature, gear_id, catalog, inv)
	assert_str(str(again.get("reason", ""))).is_equal("already_equipped")
	assert_int(inv.count(GearService.GEAR_ITEM_TYPE, gear_id)).is_equal(1)  # spare intact
	gc.queue_free()
