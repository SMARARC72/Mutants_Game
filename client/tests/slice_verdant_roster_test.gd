extends GdUnitTestSuite
## Phase 5 · Slice 4 — the curated Verdant ROSTER + weighted wild pool DoD, headless.
##   * every roster id (starter party + wild pool + elite + boss) resolves to a real species in the
##     SpeciesCatalog (no dangling ids ever reach battle);
##   * the EncounterDirector's wild ENCOUNTERS yield ONLY roster ids;
##   * the wild pool draw respects WEIGHTS deterministically (a higher-weight id appears more often)
##     AND is reproducible (same seed -> identical observed distribution);
##   * the roster is Verdant-fringe sized (~25: ~18 T1/T2 wild, ~5 T3, + 1 boss).
## Pure RefCounted logic — no scene, canonical RNG only.

const EncounterDirectorScript := preload("res://application/overworld/encounter_director.gd")
const EncounterCatalogScript := preload("res://application/overworld/encounter_catalog.gd")

const TEST_SEED := 0x5EED_BEEF
const REGION := "verdant_glut"
const STEPS := 400

var _catalog: SpeciesCatalog


func before() -> void:
	_catalog = SpeciesCatalog.new()


func test_every_roster_id_exists_in_the_catalog() -> void:
	# Starter party.
	for member: Variant in EncounterCatalogScript.starter_party():
		var sid := str((member as Dictionary)["species_id"])
		assert_object(_catalog.get_by_id(sid)).is_not_null()
	# Wild pool.
	var pool := EncounterCatalogScript.wild_pool_for(REGION, _catalog)
	assert_int(pool.size()).is_greater(0)
	for sid: Variant in pool:
		assert_object(_catalog.get_by_id(str(sid))).is_not_null()
	# Boss.
	var boss := EncounterCatalogScript.boss_for(REGION)
	assert_bool(boss.is_empty()).is_false()
	assert_object(_catalog.get_by_id(str(boss["species_id"]))).is_not_null()


func test_roster_is_verdant_slice_sized() -> void:
	# ~25 total: ~18 T1/T2 wild + ~5 T3 + 1 boss. Assert the wild pool is a sensible slice size and the
	# boss is a single Legendary creature.
	var pool := EncounterCatalogScript.wild_pool_for(REGION, _catalog)
	assert_int(pool.size()).is_between(15, 22)
	var boss := EncounterCatalogScript.boss_for(REGION)
	var boss_species: SpeciesData = _catalog.get_by_id(str(boss["species_id"]))
	assert_str(boss_species.rank).is_equal("legendary")


func test_wild_weights_align_with_pool() -> void:
	var pool := EncounterCatalogScript.wild_pool_for(REGION, _catalog)
	var weights := EncounterCatalogScript.wild_weights_for(REGION, _catalog)
	assert_int(weights.size()).is_equal(pool.size())
	for w: Variant in weights:
		assert_int(int(w)).is_greater(0)


func test_wild_encounters_yield_only_roster_ids() -> void:
	var director: EncounterDirector = EncounterDirectorScript.for_region(
		TEST_SEED, REGION, _catalog
	)
	var pool := director.wild_pool()
	assert_int(pool.size()).is_greater(0)
	var hits := 0
	for i in STEPS:
		var roll := director.roll_step(i)
		if bool(roll["encounter"]):
			hits += 1
			for member: Variant in roll["enemy_party"]:
				var sid := str((member as Dictionary).get("species_id", ""))
				assert_bool(pool.has(sid)).is_true()
	# Smoke: the wild roll actually fires over a run (not always-false).
	assert_int(hits).is_greater(0)


func test_weighted_draw_is_deterministic_and_respects_weights() -> void:
	# Tally species occurrences across a long, deterministic encounter sequence twice; the two tallies
	# must be IDENTICAL (determinism) and the highest-weight ids must out-appear the lowest-weight ids.
	var counts_a := _tally(TEST_SEED)
	var counts_b := _tally(TEST_SEED)
	assert_str(str(counts_a)).is_equal(str(counts_b))

	# Weight sensitivity: the summed appearances of the top-weight ids exceed the lowest-weight ids.
	var pool := EncounterCatalogScript.wild_pool_for(REGION, _catalog)
	var weights := EncounterCatalogScript.wild_weights_for(REGION, _catalog)
	var max_w := 0
	var min_w := 9999
	for w: Variant in weights:
		max_w = maxi(max_w, int(w))
		min_w = mini(min_w, int(w))
	assert_int(max_w).is_greater(min_w)  # the slice has a real weight spread to test
	var heavy_total := 0
	var light_total := 0
	for i in pool.size():
		var c := int(counts_a.get(str(pool[i]), 0))
		if int(weights[i]) == max_w:
			heavy_total += c
		elif int(weights[i]) == min_w:
			light_total += c
	assert_int(heavy_total).is_greater(light_total)


func test_different_seed_gives_different_distribution() -> void:
	var a := _tally(TEST_SEED)
	var b := _tally(TEST_SEED + 1)
	assert_str(str(a)).is_not_equal(str(b))


# --- helpers ---------------------------------------------------------------------------------- #


func _tally(seed: int) -> Dictionary:
	var director: EncounterDirector = EncounterDirectorScript.for_region(seed, REGION, _catalog)
	var counts: Dictionary = {}
	for i in STEPS:
		var roll := director.roll_step(i)
		if bool(roll["encounter"]):
			for member: Variant in roll["enemy_party"]:
				var sid := str((member as Dictionary).get("species_id", ""))
				counts[sid] = int(counts.get(sid, 0)) + 1
	return counts
