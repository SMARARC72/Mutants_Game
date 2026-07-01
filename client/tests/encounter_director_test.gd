extends GdUnitTestSuite
## Phase 5 · Slice 1 — EncounterDirector determinism DoD, headless.
##   * the per-step encounter roll is DETERMINISTIC: same (run seed, region) -> identical encounter
##     SEQUENCE over a range of steps (encounter flags, enemy parties, battle seeds all match);
##   * the roll draws from the canonical sub-stream only (a different seed yields a different
##     sequence — it is seed-sensitive, not constant);
##   * assembled enemy parties are non-empty on a hit and drawn from the region wild pool.
## Pure RefCounted logic — no scene, no global RNG.

const EncounterDirectorScript := preload("res://application/overworld/encounter_director.gd")
const EncounterCatalogScript := preload("res://application/overworld/encounter_catalog.gd")

const TEST_SEED := 0x5EED_BEEF
const REGION := "verdant_glut"
## Wave 3 retuned ENCOUNTER_CHANCE 0.22 -> 0.09: the deterministic walk is lengthened so the
## fixed canonical stream still yields hits > 0 (expected ~14 at 0.09 over 160 steps).
const STEPS := 160


func _sequence(seed: int) -> Array:
	var director: EncounterDirector = EncounterDirectorScript.for_region(seed, REGION)
	var out: Array = []
	for i in STEPS:
		out.append(director.roll_step(i))
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
	# With ENCOUNTER_CHANCE ~0.09 over 160 steps, the canonical stream must trigger at least once
	# (a smoke that the roll is actually wired, not always-false).
	var seq := _sequence(TEST_SEED)
	var hits := 0
	for r: Dictionary in seq:
		if bool(r["encounter"]):
			hits += 1
	assert_int(hits).is_greater(0)


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
