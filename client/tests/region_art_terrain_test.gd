extends GdUnitTestSuite
## E2c "Region-2 art promotion + world art gaps" — the ACT-1 WORLD resolves to REAL art, headless.
##   * every species a player can meet through act 1 (the Threshold hub, the Verdant fringe, and
##     the two act-1 gate destinations Mournmarch + Forgefell: starter party, wild pools, elite
##     pools, the act bosses — BOTH the authored kit species AND the pools' stand-in slots)
##     resolves through the promoted manifest to its OWN plate, never the halo-sprout fallback;
##   * both act-1 regions' force palettes resolve to REAL terrain (every palette texture ships,
##     build() serves the full atlas), a REAL horizon strip, and a REAL battle-backdrop key
##     (no eros/thanatos default-key fallback);
##   * both regions raise structures: the waygate + the lair land on a real generated layout with
##     at least one force-pool landmark, and every pool id resolves to a shipped cutout texture
##     (no bare region).
## Pure data + RefCounted logic — no scene tree, no canonical RNG streams.

const EncounterCatalogScript := preload("res://application/overworld/encounter_catalog.gd")
const BattleCardKitScript := preload("res://presentation/battle/battle_card_kit.gd")
const OverworldDepthScript := preload("res://presentation/overworld/overworld_depth.gd")

const TEST_SEED := 0xE2C_0A21

## Everything reachable through act 1: the hub, the starter fringe, and the two regions the
## registered_aspirant act-1 gate opens as the act's authored destinations.
const ACT1_REGIONS := ["threshold", "verdant_glut", "mournmarch", "forgefell"]

## The act-1 gate destinations this batch promoted (mournmarch = Thanatos' grey march,
## forgefell = the Iron Guild's dead foundries).
const ACT1_DESTINATIONS := ["mournmarch", "forgefell"]

const FALLBACK_PLATE := "halo_sprout.png"


func test_every_act1_reachable_species_resolves_to_promoted_art() -> void:
	var catalog := SpeciesCatalog.new()
	var ids := {}
	for member: Variant in EncounterCatalogScript.starter_party():
		ids[str((member as Dictionary)["species_id"])] = true
	for region_id: String in ACT1_REGIONS:
		for sid: Variant in EncounterCatalogScript.wild_pool_for(region_id, catalog):
			ids[str(sid)] = true
		for sid: Variant in EncounterCatalogScript.elite_pool_for(region_id, catalog):
			ids[str(sid)] = true
		var boss: Dictionary = EncounterCatalogScript.boss_for(region_id)
		if not boss.is_empty():
			ids[str(boss.get("species_id", ""))] = true
	# The pools' STAND-IN boss slots for the two destinations must ship art too — the boss path
	# a player sees if the authored kit data is ever absent must not regress to the sprout.
	for region_id: String in ACT1_DESTINATIONS:
		var stand_in := _pool_boss_species(region_id)
		assert_str(stand_in).is_not_empty()
		ids[stand_in] = true
	# Sanity: the union really is act-1 sized (hub 14 + fringe ~24 + two destination rosters).
	assert_int(ids.size()).is_greater_equal(50)
	for sid: String in ids:
		(
			assert_bool(SpeciesArt.has_art(sid))
			. override_failure_message("no promoted plate for act-1 species " + sid)
			. is_true()
		)
		var path := SpeciesArt.plate_path(sid)
		assert_bool(path.ends_with(FALLBACK_PLATE)).is_false()
		(
			assert_bool(ResourceLoader.exists(path))
			. override_failure_message("manifest names a missing plate: " + path)
			. is_true()
		)


func test_act1_destination_bosses_carry_art_for_kit_and_stand_in_species() -> void:
	for region_id: String in ACT1_DESTINATIONS:
		# The authored act boss (region_bosses.json -> boss_kits.json) is what boss_for serves.
		var authored: Dictionary = BossKitCatalog.boss_config_for_region(region_id)
		assert_bool(authored.is_empty()).is_false()
		assert_bool(SpeciesArt.has_art(str(authored.get("species_id", "")))).is_true()
		# And the E1b stand-in slot (the no-kit fallback path) resolves to its own plate as well.
		assert_bool(SpeciesArt.has_art(_pool_boss_species(region_id))).is_true()


func test_act1_region_forces_resolve_to_real_terrain() -> void:
	for region_id: String in ACT1_DESTINATIONS:
		# The palette key is the region's OWN declared force — never the Eros default fallback.
		var force := OverworldTileSet.force_for_region(region_id)
		assert_str(force).is_equal(RegionCatalog.force(region_id))
		assert_bool(OverworldTileSet.PALETTES.has(force)).is_true()
		# Every texture the palette names actually ships (a missing file would silently fall
		# back to a flat colour swatch — functional, but not the region's identity).
		var palette: Dictionary = OverworldTileSet.PALETTES[force]
		for tile_id: Variant in palette:
			for path: String in _palette_paths(palette, int(tile_id)):
				(
					assert_bool(ResourceLoader.exists(path))
					. override_failure_message("%s palette names missing %s" % [force, path])
					. is_true()
				)
		# build() serves the full atlas: all ground variants + feature/path/wall/ritual tiles.
		var tile_set := OverworldTileSet.build(force)
		var source := tile_set.get_source(0) as TileSetAtlasSource
		assert_object(source).is_not_null()
		for v in OverworldTileSet.GROUND_VARIANTS:
			assert_bool(source.has_tile(Vector2i(OverworldTileSet.GROUND_TILE, v))).is_true()
		for tile_id: int in [1, 2, OverworldTileSet.WALL_TILE, OverworldTileSet.RITUAL_TILE]:
			assert_bool(source.has_tile(Vector2i(tile_id, 0))).is_true()


func test_act1_region_horizons_and_battle_backdrops_resolve_non_fallback() -> void:
	var manifest: Dictionary = BattleCardKitScript.load_backdrop_manifest()
	assert_bool(manifest.is_empty()).is_false()
	for region_id: String in ACT1_DESTINATIONS:
		var force := OverworldTileSet.force_for_region(region_id)
		var head := force.get_slice("+", 0).to_lower()
		# The horizon strip behind the tile field (thanatos.png / cosmos.png) really ships.
		var horizon := OverworldDepthScript.HORIZON_DIR + head + ".png"
		(
			assert_bool(ResourceLoader.exists(horizon))
			. override_failure_message("missing horizon strip " + horizon)
			. is_true()
		)
		# The battle backdrop resolves through the region's OWN manifest key — pick_backdrop
		# would silently reroute an unknown key to the eros/thanatos defaults.
		assert_bool(manifest.has(head)).is_true()
		assert_object(BattleCardKitScript.pick_backdrop(force, true)).is_not_null()
		assert_object(BattleCardKitScript.pick_backdrop(force, false)).is_not_null()


func test_act1_regions_place_waygate_lair_and_landmarks() -> void:
	var gen := WorldGenerator.new()
	for region_id: String in ACT1_DESTINATIONS:
		var force := OverworldTileSet.force_for_region(region_id)
		# The force's landmark pool exists and every id it can place resolves to a shipped
		# cutout — including the lair altar, the Threshold-network waygate, and the home stall.
		assert_bool(OverworldStructures.POOLS.has(force)).is_true()
		var pool: Array = OverworldStructures.POOLS[force]
		assert_int(pool.size()).is_greater_equal(2)
		var wanted: Array = pool.duplicate()
		wanted.append_array(
			[
				OverworldStructures.LAIR_ID,
				OverworldStructures.WAYGATE_ID,
				OverworldStructures.HOME_ID
			]
		)
		for id: Variant in wanted:
			(
				assert_object(OverworldStructures.texture_for(str(id)))
				. override_failure_message("structure '%s' has no shipped texture" % str(id))
				. is_not_null()
			)
		# A real generated layout raises the boss lair + the ritual circle + landmark(s).
		var layout: Layout = gen.generate(region_id, TEST_SEED)
		var home := OverworldSpawn.spawn_cell(layout)
		var plan := OverworldStructures.plan_for(layout, force, home)
		var roles := {}
		for entry: Dictionary in plan:
			var role := str(entry.get("role", ""))
			roles[role] = int(roles.get(role, 0)) + 1
		assert_int(int(roles.get(OverworldStructures.ROLE_LAIR, 0))).is_equal(1)
		assert_int(int(roles.get(OverworldStructures.ROLE_WAYGATE, 0))).is_equal(1)
		assert_int(int(roles.get(OverworldStructures.ROLE_LANDMARK, 0))).is_greater_equal(1)


# --- helpers ----------------------------------------------------------------------------------- #


## The E1b region_pools.json stand-in boss species for a region ("" when absent).
func _pool_boss_species(region_id: String) -> String:
	var parsed: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://catalog/region_pools.json")
	)
	if not (parsed is Dictionary):
		return ""
	var regions: Variant = (parsed as Dictionary).get("regions", {})
	if not (regions is Dictionary):
		return ""
	var entry: Variant = (regions as Dictionary).get(region_id, {})
	if not (entry is Dictionary):
		return ""
	var boss: Variant = (entry as Dictionary).get("boss", {})
	if not (boss is Dictionary):
		return ""
	return str((boss as Dictionary).get("species_id", ""))


## Every texture path a palette entry names: ground rows are [[texture, modulate], ...]; other
## tile ids are a single [texture, modulate] pair.
func _palette_paths(palette: Dictionary, tile_id: int) -> Array:
	var out: Array = []
	if tile_id == OverworldTileSet.GROUND_TILE:
		for row: Variant in palette[tile_id] as Array:
			out.append(str((row as Array)[0]))
	else:
		out.append(str((palette[tile_id] as Array)[0]))
	return out
