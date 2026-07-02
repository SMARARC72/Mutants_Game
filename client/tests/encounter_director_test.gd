extends GdUnitTestSuite
## Phase 5 · Slice 1 + Wave 13 — EncounterDirector determinism DoD, headless.
##   * the per-step encounter roll is DETERMINISTIC: same (run seed, region, tile classes) ->
##     identical encounter SEQUENCE over a range of steps (encounter flags, enemy parties, battle
##     seeds, kinds, misbehavior flags all match);
##   * the roll draws from the canonical sub-stream only (a different seed yields a different
##     sequence — it is seed-sensitive, not constant);
##   * Wave 13 thin-place gating: thin cells (~0.30) fire FAR more often than the base surface
##     (~0.04) over the same deterministic walk;
##   * the misbehavior sub-roll (~1/12 of thin battle hits) draws ONE T3 from the elite pool;
##   * the kind sub-roll (~1/6) marks peculiar encounters deterministically;
##   * assembled enemy parties are non-empty on a hit and drawn from the region wild pool.
## Pure RefCounted logic — no scene, no global RNG.

const EncounterDirectorScript := preload("res://application/overworld/encounter_director.gd")
const EncounterCatalogScript := preload("res://application/overworld/encounter_catalog.gd")

const TEST_SEED := 0x5EED_BEEF
const REGION := "verdant_glut"
## Wave 13 retuned the base ENCOUNTER_CHANCE 0.09 -> 0.04: the deterministic walk is lengthened so
## the fixed canonical stream still yields hits > 0 (expected ~16 at 0.04 over 400 steps).
const STEPS := 400
const THIN := EncounterDirectorScript.TILE_CLASS_THIN


## A deterministic mixed-class walk: every 3rd step crosses a thin place, the rest are base tiles
## (a stand-in for the overworld handing roll_step the stepped cell's class).
func _class_at(step: int) -> String:
	return THIN if step % 3 == 0 else ""


func _sequence(seed: int, tile_class: String = "") -> Array:
	var director: EncounterDirector = EncounterDirectorScript.for_region(seed, REGION)
	var out: Array = []
	for i in STEPS:
		out.append(director.roll_step(i, tile_class))
	return out


func _mixed_sequence(seed: int) -> Array:
	var director: EncounterDirector = EncounterDirectorScript.for_region(seed, REGION)
	var out: Array = []
	for i in STEPS:
		out.append(director.roll_step(i, _class_at(i)))
	return out


func test_encounter_sequence_is_deterministic() -> void:
	var a := _sequence(TEST_SEED)
	var b := _sequence(TEST_SEED)
	assert_int(a.size()).is_equal(STEPS)
	for i in STEPS:
		var ra: Dictionary = a[i]
		var rb: Dictionary = b[i]
		assert_bool(bool(ra["encounter"])).is_equal(bool(rb["encounter"]))
		assert_int(int(ra["battle_seed"])).is_equal(int(rb["battle_seed"]))
		assert_str(str(ra["enemy_party"])).is_equal(str(rb["enemy_party"]))


func test_mixed_tile_class_walk_is_deterministic_including_kind_and_misbehavior() -> void:
	# Same seed + same per-step tile classes => the encounter/kind/misbehavior sequence replays
	# EXACTLY (the Wave 13 determinism contract: the class is folded into the purpose hash).
	var a := _mixed_sequence(TEST_SEED)
	var b := _mixed_sequence(TEST_SEED)
	for i in STEPS:
		var ra: Dictionary = a[i]
		var rb: Dictionary = b[i]
		assert_bool(bool(ra["encounter"])).is_equal(bool(rb["encounter"]))
		assert_str(str(ra["kind"])).is_equal(str(rb["kind"]))
		assert_bool(bool(ra["misbehavior"])).is_equal(bool(rb["misbehavior"]))
		assert_int(int(ra["battle_seed"])).is_equal(int(rb["battle_seed"]))
		assert_str(str(ra["enemy_party"])).is_equal(str(rb["enemy_party"]))


func test_tile_class_changes_the_canonical_stream() -> void:
	# The thin-class stream is DISJOINT from the base stream (the class salts the purpose hash):
	# over the walk the two must not produce identical battle-seed sequences on shared hits.
	var base := _sequence(TEST_SEED, "")
	var thin := _sequence(TEST_SEED, THIN)
	var diverged := false
	for i in STEPS:
		var rb: Dictionary = base[i]
		var rt: Dictionary = thin[i]
		if bool(rb["encounter"]) and bool(rt["encounter"]):
			if int(rb["battle_seed"]) != int(rt["battle_seed"]):
				diverged = true
				break
	assert_bool(diverged).is_true()


func test_different_seed_gives_different_sequence() -> void:
	# Compare the encounter-flag pattern; two distinct seeds must not produce identical sequences.
	var a := _sequence(TEST_SEED)
	var b := _sequence(TEST_SEED + 1)
	var pattern_a := ""
	var pattern_b := ""
	for i in STEPS:
		pattern_a += "1" if bool((a[i] as Dictionary)["encounter"]) else "0"
		pattern_b += "1" if bool((b[i] as Dictionary)["encounter"]) else "0"
	assert_str(pattern_a).is_not_equal(pattern_b)


func test_at_least_one_encounter_fires_over_a_run() -> void:
	# With the base ENCOUNTER_CHANCE ~0.04 over 400 steps, the canonical stream must trigger at
	# least once (a smoke that the roll is actually wired, not always-false).
	var seq := _sequence(TEST_SEED)
	var hits := 0
	for r: Dictionary in seq:
		if bool(r["encounter"]):
			hits += 1
	assert_int(hits).is_greater(0)


func test_thin_cells_fire_far_more_often_than_the_base_surface() -> void:
	# The Wave 13 teeth: over the SAME deterministic walk, thin-place steps (~0.30) must hit at
	# least 3x as often as base steps (~0.04) — paths are safe, shimmering tiles are a dare.
	var base_hits := 0
	var thin_hits := 0
	for r: Dictionary in _sequence(TEST_SEED, ""):
		if bool(r["encounter"]):
			base_hits += 1
	for r: Dictionary in _sequence(TEST_SEED, THIN):
		if bool(r["encounter"]):
			thin_hits += 1
	assert_int(thin_hits).is_greater(base_hits * 3)
	assert_int(base_hits).is_greater(0)


func test_misbehavior_draws_one_elite_and_only_on_thin_cells() -> void:
	var director: EncounterDirector = EncounterDirectorScript.for_region(TEST_SEED, REGION)
	var elites := director.elite_pool()
	assert_int(elites.size()).is_greater(0)  # the slice's previously-dead elite_pool is live
	var misbehaved := 0
	for i in STEPS:
		var roll := director.roll_step(i, THIN)
		if not bool(roll["misbehavior"]):
			continue
		misbehaved += 1
		# A misbehavior is always a BATTLE kind and exactly ONE too-big T3 from the elite pool.
		assert_str(str(roll["kind"])).is_equal(EncounterDirectorScript.KIND_BATTLE)
		var party: Array = roll["enemy_party"]
		assert_int(party.size()).is_equal(1)
		var sid := str((party[0] as Dictionary).get("species_id", ""))
		assert_bool(elites.has(sid)).is_true()
	# ~1/12 of ~120 thin hits over 400 steps: the sub-roll must actually fire, and rarely.
	assert_int(misbehaved).is_greater(0)
	assert_int(misbehaved).is_less(40)
	# And the BASE surface never misbehaves (no thin cell, no cough).
	for i in STEPS:
		assert_bool(bool(director.roll_step(i, "")["misbehavior"])).is_false()


func test_kind_sub_stream_marks_some_encounters_peculiar_deterministically() -> void:
	var director: EncounterDirector = EncounterDirectorScript.for_region(TEST_SEED, REGION)
	var hits := 0
	var peculiars := 0
	for i in STEPS:
		var roll := director.roll_step(i, THIN)
		if not bool(roll["encounter"]):
			assert_str(str(roll["kind"])).is_equal("")  # kind only exists on a hit
			continue
		hits += 1
		var kind := str(roll["kind"])
		var is_known := (
			kind == EncounterDirectorScript.KIND_BATTLE
			or kind == EncounterDirectorScript.KIND_PECULIAR
		)
		assert_bool(is_known).is_true()
		if kind == EncounterDirectorScript.KIND_PECULIAR:
			peculiars += 1
			# A peculiar never misbehaves — it must never escalate into an elite battle.
			assert_bool(bool(roll["misbehavior"])).is_false()
	# ~1/6 of ~120 thin hits: present, minority.
	assert_int(peculiars).is_greater(0)
	assert_int(peculiars * 2).is_less(hits)


func test_enemy_party_drawn_from_region_wild_pool() -> void:
	var director: EncounterDirector = EncounterDirectorScript.for_region(TEST_SEED, REGION)
	var pool := director.wild_pool()
	assert_int(pool.size()).is_greater(0)
	for i in STEPS:
		var roll := director.roll_step(i)
		if bool(roll["encounter"]):
			var party: Array = roll["enemy_party"]
			assert_int(party.size()).is_greater(0)
			for member: Variant in party:
				var sid := str((member as Dictionary).get("species_id", ""))
				assert_bool(pool.has(sid)).is_true()


func test_wild_pool_resolves_to_real_catalog_ids() -> void:
	# Every Verdant wild-pool id (and the starter party) must exist in the species catalog.
	var catalog := SpeciesCatalog.new()
	var pool := EncounterCatalogScript.wild_pool_for(REGION, catalog)
	# The live pool is data-driven from slice_verdant.json (Slice 4); REGION_WILD_POOLS is only the
	# offline fallback, so don't cross-check sizes against it. The real teeth: non-empty + every id resolves.
	assert_int(pool.size()).is_greater(0)
	for sid: Variant in pool:
		assert_object(catalog.get_by_id(str(sid))).is_not_null()
	for member: Variant in EncounterCatalogScript.starter_party():
		var sid := str((member as Dictionary)["species_id"])
		assert_object(catalog.get_by_id(sid)).is_not_null()


func test_elite_pool_resolves_and_aligns_with_weights() -> void:
	var catalog := SpeciesCatalog.new()
	var elites := EncounterCatalogScript.elite_pool_for(REGION, catalog)
	var weights := EncounterCatalogScript.elite_weights_for(REGION, catalog)
	assert_int(elites.size()).is_greater(0)
	assert_int(weights.size()).is_equal(elites.size())
	for sid: Variant in elites:
		assert_object(catalog.get_by_id(str(sid))).is_not_null()
	for w: Variant in weights:
		assert_int(int(w)).is_greater(0)
	# Regions without an authored elite pool return [] (misbehavior simply never fires there).
	assert_int(EncounterCatalogScript.elite_pool_for("somewhere_unmapped", catalog).size()).is_equal(
		0
	)
