extends GdUnitTestSuite
## SpeciesCatalog smoke test (Cluster 2, D3/D7). Proves the packed species DB
## (res://catalog/species/species_db.tres, generated from docs/creature_registry.csv) loads and
## that the facade's lookups/queries return the expected typed SpeciesData. Pure read-only catalog
## data — no stats, no RNG (the oracle computes stats from this at runtime, not here).
##
## Counts/ids are kept in lock-step with the JSON bundle + Postgres seed by
## tools/test_catalog_parity.mjs; this suite asserts the GDScript side actually loads them.

const EXPECTED_COUNT := 406  # 407 registry rows minus 1 with empty force_primary (ADR-006)

var _catalog: SpeciesCatalog


func before() -> void:
	_catalog = SpeciesCatalog.new()


func test_catalog_loads_expected_count() -> void:
	assert_object(_catalog).is_not_null()
	assert_int(_catalog.count()).is_equal(EXPECTED_COUNT)
	assert_int(_catalog.all().size()).is_equal(EXPECTED_COUNT)


func test_all_entries_are_typed_species_data() -> void:
	var all := _catalog.all()
	assert_int(all.size()).is_greater(0)
	var first: SpeciesData = all[0]
	assert_bool(first is SpeciesData).is_true()
	# Every entry has a non-empty id and a non-empty force_primary (NOT NULL in the table).
	for sp: SpeciesData in all:
		assert_str(sp.id).is_not_empty()
		assert_str(sp.force_primary).is_not_empty()


func test_get_by_id_returns_expected_row() -> void:
	var ruinmaw: SpeciesData = _catalog.get_by_id("AD01")
	assert_object(ruinmaw).is_not_null()
	assert_str(ruinmaw.name).is_equal("Ruinmaw")
	assert_str(ruinmaw.force_primary).is_equal("Chaos")
	assert_str(ruinmaw.force_secondary).is_equal("Thanatos")
	assert_str(ruinmaw.tier).is_equal("T2")
	assert_str(ruinmaw.rank).is_equal("wild")
	assert_str(ruinmaw.species_class).is_equal("organic")
	assert_str(ruinmaw.evolution_line).is_equal("Ruin Wolf")


func test_get_unknown_id_returns_null() -> void:
	assert_object(_catalog.get_by_id("NOPE-does-not-exist")).is_null()


func test_tags_are_packed_string_array() -> void:
	# AD02 (Worldback) carries a single tag "apex" in the registry.
	var worldback: SpeciesData = _catalog.get_by_id("AD02")
	assert_object(worldback).is_not_null()
	assert_bool(worldback.tags is PackedStringArray).is_true()
	assert_int(worldback.tags.size()).is_equal(1)
	assert_str(worldback.tags[0]).is_equal("apex")


func test_by_force_matches_primary_or_secondary() -> void:
	var chaos := _catalog.by_force("Chaos")
	assert_int(chaos.size()).is_greater(0)
	# AD01 has force_primary Chaos -> must be present.
	var ids := _ids(chaos)
	assert_bool(ids.has("AD01")).is_true()
	# Every returned row really has Chaos as primary or secondary.
	for sp: SpeciesData in chaos:
		assert_bool(sp.force_primary == "Chaos" or sp.force_secondary == "Chaos").is_true()


func test_by_tier_filters_correctly() -> void:
	var t3 := _catalog.by_tier("T3")
	assert_int(t3.size()).is_greater(0)
	for sp: SpeciesData in t3:
		assert_str(sp.tier).is_equal("T3")
	assert_bool(_ids(t3).has("AD02")).is_true()  # Worldback is T3


func test_by_rank_filters_correctly() -> void:
	var wild := _catalog.by_rank("wild")
	assert_int(wild.size()).is_greater(0)
	for sp: SpeciesData in wild:
		assert_str(sp.rank).is_equal("wild")
	assert_bool(_ids(wild).has("AD01")).is_true()


func _ids(rows: Array[SpeciesData]) -> PackedStringArray:
	var out := PackedStringArray()
	for sp: SpeciesData in rows:
		out.append(sp.id)
	return out
