extends GdUnitTestSuite
## Phase 5 · Slice 3b — GearCatalog facade DoD: it reads client/catalog/gear.json (the SAME static
## catalog the supabase `gear` seed is generated from) as read-only rows.
##   * loads every committed gear row;
##   * get_by_id returns the id/name/slot/rarity/effects shape (or {} for an unknown id);
##   * returned rows are defensive copies (mutating one never corrupts the catalog).

const GearCatalogScript := preload("res://infrastructure/catalog/gear_catalog.gd")


func test_loads_committed_gear() -> void:
	var gc: GearCatalog = GearCatalogScript.new()
	assert_int(gc.count()).is_greater(0)
	# A known catalog id resolves with its shape.
	var charm := gc.get_by_id("luckbone_charm")
	assert_bool(charm.is_empty()).is_false()
	assert_str(str(charm["name"])).is_equal("Luckbone Charm")
	assert_str(str(charm["slot"])).is_equal("Charm")
	assert_bool((charm["effects"] as Dictionary).has("capture")).is_true()


func test_unknown_id_returns_empty() -> void:
	var gc: GearCatalog = GearCatalogScript.new()
	assert_bool(gc.get_by_id("not_real").is_empty()).is_true()
	assert_bool(gc.has("not_real")).is_false()


func test_rows_are_defensive_copies() -> void:
	var gc: GearCatalog = GearCatalogScript.new()
	var a := gc.get_by_id("luckbone_charm")
	(a["effects"] as Dictionary)["capture"] = 999.0
	var b := gc.get_by_id("luckbone_charm")
	# The mutation on the first copy did NOT bleed into the catalog.
	assert_float(float((b["effects"] as Dictionary)["capture"])).is_not_equal(999.0)
