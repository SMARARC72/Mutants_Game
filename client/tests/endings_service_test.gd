extends GdUnitTestSuite
## Batch E2b — EndingsService.resolve(), driven across crafted runs. The resolver
## must pick the highest-priority satisfied ending, band the morality axes EXACTLY
## like CharacterEngine (so the character sheet and the ending can never disagree),
## honour the refusal-door flags, and NEVER come back empty (the documented
## fallback). Also covers finale_reached, the record latch and the run ledger.


func _run_with(oc: int, pc: int, flags: Dictionary = {}) -> RunContext:
	var run := RunContext.new()
	run.order_chaos = oc
	run.purity_corrupt = pc
	run.flags = flags
	return run


func test_default_run_walks_the_brokers_path() -> void:
	# Neutral axes sit Balanced|Tainted — the gray god, same cell the sheet shows.
	assert_str(str(EndingsService.resolve(_run_with(0, 0)).get("id", ""))).is_equal("the_broker")


func test_pure_order_run_resolves_the_lawgiver() -> void:
	assert_str(str(EndingsService.resolve(_run_with(-80, -80)).get("id", ""))).is_equal(
		"the_lawgiver"
	)


func test_high_corruption_chaos_run_resolves_the_devourer() -> void:
	assert_str(str(EndingsService.resolve(_run_with(80, 80)).get("id", ""))).is_equal(
		"the_devourer"
	)


func test_band_edges_match_character_engine_band3() -> void:
	# ±34 flips the band; ±33 stays middle — the oracle's exact thresholds.
	assert_str(str(EndingsService.resolve(_run_with(-34, -34)).get("id", ""))).is_equal(
		"the_lawgiver"
	)
	assert_str(str(EndingsService.resolve(_run_with(-33, 33)).get("id", ""))).is_equal("the_broker")
	assert_str(str(EndingsService.resolve(_run_with(33, 34)).get("id", ""))).is_equal(
		"the_plaguelord"
	)


func test_faction_champion_run_keeps_its_grid_ending() -> void:
	# A Bloomwarden Hand at Balanced|Pure is the Warden — standing never distorts the
	# grid resolution (no authored ending gates on standing; see INGEST_NOTES E2b §4).
	var run := _run_with(0, -80, {"bloomwardens_standing": 60})
	assert_str(str(EndingsService.resolve(run).get("id", ""))).is_equal("the_warden")


func test_standing_min_condition_shape_is_honoured() -> void:
	# The condition key is implemented for future authored content: ["<faction>", min]
	# against the `<faction>_standing` run flag.
	var run := _run_with(0, 0, {"bloomwardens_standing": 60})
	(
		assert_bool(EndingsService.conditions_met({"standing_min": ["bloomwardens", 40]}, run))
		. is_true()
	)
	(
		assert_bool(EndingsService.conditions_met({"standing_min": ["bloomwardens", 99]}, run))
		. is_false()
	)
	assert_bool(EndingsService.conditions_met({"standing_min": ["iron_guild", 1]}, run)).is_false()


func test_refusal_doors_outrank_the_grid() -> void:
	# A god_maker flag beats ANY grid cell; the unmaking beats both.
	var god_maker := _run_with(-80, -80, {"god_maker": true})
	assert_str(str(EndingsService.resolve(god_maker).get("id", ""))).is_equal("the_god_maker")
	var both := _run_with(80, 80, {"god_maker": true, "unmaking": true})
	assert_str(str(EndingsService.resolve(both).get("id", ""))).is_equal("the_unmaking")


func test_resolve_never_returns_empty() -> void:
	# Even a null run answers with the documented fallback — the never-null contract.
	var fallback := EndingsService.resolve(null)
	assert_bool(fallback.is_empty()).is_false()
	assert_str(str(fallback.get("id", ""))).is_equal("a_graveyard_of_winners")


func test_finale_reached_reads_either_seam_flag() -> void:
	assert_bool(EndingsService.finale_reached(_run_with(0, 0))).is_false()
	assert_bool(EndingsService.finale_reached(null)).is_false()
	(
		assert_bool(EndingsService.finale_reached(_run_with(0, 0, {"succession_begins": true})))
		. is_true()
	)
	assert_bool(EndingsService.finale_reached(_run_with(0, 0, {"act5_q4_done": true}))).is_true()


func test_record_latches_exactly_once() -> void:
	var run := _run_with(0, 0)
	assert_str(EndingsService.recorded_ending(run)).is_equal("")
	assert_bool(EndingsService.record(run, "the_broker")).is_true()
	assert_str(EndingsService.recorded_ending(run)).is_equal("the_broker")
	# A second record is refused — the FIRST verdict stands (a finished ledger is final).
	assert_bool(EndingsService.record(run, "the_devourer")).is_false()
	assert_str(EndingsService.recorded_ending(run)).is_equal("the_broker")
	assert_bool(EndingsService.record(run, "")).is_false()


func test_run_ledger_reads_run_fields() -> void:
	var run := _run_with(0, 0, {"bloomwardens_standing": 23})
	run.corruption = 41
	run.party = [
		{"species_id": "a", "lineage": {"captured": true}},
		{"species_id": "b", "lineage": {"spliced": true, "parents": []}},
		{"species_id": "c"},  # founder — neither caught nor spliced
	]
	# The dead still count toward caught/spliced (they were caught before they were lost).
	run.flags["graveyard"] = [
		{"name": "Gone", "creature": {"species_id": "d", "lineage": {"captured": true}}}
	]
	var ledger := EndingsService.run_ledger(run)
	assert_int(int(ledger.get("caught", 0))).is_equal(2)
	assert_int(int(ledger.get("spliced", 0))).is_equal(1)
	assert_int(int(ledger.get("lost", 0))).is_equal(1)
	assert_int(int(ledger.get("corruption", 0))).is_equal(41)
	assert_int(int(ledger.get("standing", 0))).is_equal(23)
	# A null run still answers a zeroed ledger (the screen never crashes).
	assert_int(int(EndingsService.run_ledger(null).get("caught", -1))).is_equal(0)
