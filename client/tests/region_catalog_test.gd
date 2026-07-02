extends GdUnitTestSuite
## E1b "Eleven Regions" — region-catalog PARITY, headless.
##   * the world catalog (region_layouts.json via RegionCatalog) carries ALL ELEVEN regions from
##     docs/content/regions.md with titles, forces, tier bands, and travel gates (verdant +
##     threshold always open);
##   * EncounterCatalog serves a NON-EMPTY weighted wild pool for every region through the same
##     API (slice_verdant.json for verdant, region_pools.json for the rest), weights aligned 1:1,
##     with NO id dropped against the 406-species catalog (every authored id resolves);
##   * every region carries a BOSS slot (rank legendary/god, a known role brain) + a UNIQUE
##     per-region boss-trigger flag pair; the verdant slice keeps its historical flags;
##   * tier bands are sane (every wild row's tier sits inside the region's declared band);
##   * pools are DETERMINISTIC (same seed => same encounter draws, twice);
##   * the per-region identity plumbing RESOLVES for all eleven force values (tile palette,
##     structure pool, prop pool, VoiceBook entry sting).

const EncounterCatalogScript := preload("res://application/overworld/encounter_catalog.gd")
const EncounterDirectorScript := preload("res://application/overworld/encounter_director.gd")
const RegionCatalogScript := preload("res://application/overworld/region_catalog.gd")
const OverworldTileSetScript := preload("res://presentation/overworld/overworld_tileset.gd")
const OverworldStructuresScript := preload("res://presentation/overworld/overworld_structures.gd")

const TEST_SEED := 0xE1B_0011

## The canonical eleven (docs/content/regions.md §§1-11, in world-catalog order).
const ALL_REGIONS := [
	"threshold",
	"verdant_glut",
	"mournmarch",
	"forgefell",
	"titanfall",
	"storm_vault",
	"tideless",
	"sunder",
	"astral_tier",
	"maw_beneath",
	"hollow_atelier",
]

## Regions that never seal (design: the hub + the MVP starter fringe).
const ALWAYS_OPEN := ["threshold", "verdant_glut"]

## The role brains BattleSession/CombatBrain actually assign.
const KNOWN_BRAINS := ["controller", "aggressor", "support", "neutral"]


func test_world_catalog_carries_all_eleven_regions() -> void:
	var ids: Array = RegionCatalogScript.region_ids()
	assert_int(ids.size()).is_equal(ALL_REGIONS.size())
	for region_id: String in ALL_REGIONS:
		assert_bool(RegionCatalogScript.has_region(region_id)).is_true()
		assert_str(RegionCatalogScript.title(region_id)).is_not_empty()
		assert_str(RegionCatalogScript.force(region_id)).is_not_empty()
		assert_bool(RegionCatalogScript.tier_band(region_id).is_empty()).is_false()
		assert_str(RegionCatalogScript.blurb_key(region_id)).is_not_empty()


func test_travel_gates_verdant_and_threshold_always_open_rest_flagged() -> void:
	for region_id: String in ALL_REGIONS:
		if region_id in ALWAYS_OPEN:
			assert_bool(RegionCatalogScript.always_open(region_id)).is_true()
		else:
			# Every later region seals behind a named story flag + carries locked-row copy.
			assert_str(RegionCatalogScript.gate_flag(region_id)).is_not_empty()
			assert_str(RegionCatalogScript.gate_hint(region_id)).is_not_empty()


func test_every_region_serves_a_nonempty_aligned_wild_pool() -> void:
	var catalog := SpeciesCatalog.new()
	for region_id: String in ALL_REGIONS:
		var pool: Array = EncounterCatalogScript.wild_pool_for(region_id, catalog)
		var weights: Array = EncounterCatalogScript.wild_weights_for(region_id, catalog)
		assert_int(pool.size()).is_greater(0)
		assert_int(weights.size()).is_equal(pool.size())
		for w: Variant in weights:
			assert_int(int(w)).is_greater(0)
		# NO authored id was dropped against the species DB: the filtered pool matches the raw
		# data row count (a typo'd id in the data files would silently shrink it).
		var raw := _raw_wild_rows(region_id)
		if not raw.is_empty():
			assert_int(pool.size()).is_equal(raw.size())


func test_elite_pools_present_everywhere_but_the_safe_hub() -> void:
	var catalog := SpeciesCatalog.new()
	for region_id: String in ALL_REGIONS:
		var elites: Array = EncounterCatalogScript.elite_pool_for(region_id, catalog)
		var weights: Array = EncounterCatalogScript.elite_weights_for(region_id, catalog)
		assert_int(weights.size()).is_equal(elites.size())
		if region_id == "threshold":
			# The hub is canonically gentle — nothing above T1, so the veil never coughs here.
			assert_int(elites.size()).is_equal(0)
		else:
			assert_int(elites.size()).is_greater(0)


func test_every_region_has_a_resolvable_boss_slot() -> void:
	var catalog := SpeciesCatalog.new()
	for region_id: String in ALL_REGIONS:
		var boss: Dictionary = EncounterCatalogScript.boss_for(region_id)
		if region_id == "threshold":
			# The hub holds the Standstill — no throne, no act boss, NO ambush trigger
			# (integration adjudication with the E1c seam; the arena slot waits for the
			# Competitions system).
			assert_bool(boss.is_empty()).is_true()
			continue
		assert_bool(boss.is_empty()).is_false()
		var species_id := str(boss.get("species_id", ""))
		assert_object(catalog.get_by_id(species_id)).is_not_null()
		assert_str(str(boss.get("name", ""))).is_not_empty()
		assert_bool(str(boss.get("rank", "")) in ["legendary", "god"]).is_true()
		assert_bool(str(boss.get("brain", "")) in KNOWN_BRAINS).is_true()


func test_boss_trigger_flags_are_unique_per_region() -> void:
	var cleared := {}
	var victory := {}
	for region_id: String in ALL_REGIONS:
		var trigger: Dictionary = EncounterCatalogScript.boss_trigger_for(region_id)
		assert_int(int(trigger.get("min_steps", 0))).is_greater(0)
		cleared[str(trigger.get("cleared_flag", ""))] = true
		victory[str(trigger.get("victory_flag", ""))] = true
	assert_int(cleared.size()).is_equal(ALL_REGIONS.size())
	assert_int(victory.size()).is_equal(ALL_REGIONS.size())
	# The verdant slice keeps its historical flags (save-compat with the shipped MVP loop).
	var verdant: Dictionary = EncounterCatalogScript.boss_trigger_for("verdant_glut")
	assert_str(str(verdant.get("cleared_flag", ""))).is_equal("verdant_boss_cleared")
	assert_str(str(verdant.get("victory_flag", ""))).is_equal("slice_verdant_victory")


func test_tier_bands_are_sane() -> void:
	for region_id: String in ALL_REGIONS:
		var band: Array = RegionCatalogScript.tier_band(region_id)
		for row: Dictionary in _raw_wild_rows(region_id):
			var tier := str(row.get("tier", ""))
			assert_bool(tier in band).is_true()


func test_encounter_draws_are_deterministic_per_seed() -> void:
	var catalog := SpeciesCatalog.new()
	for region_id: String in ["threshold", "mournmarch", "sunder", "hollow_atelier"]:
		var a := EncounterDirectorScript.for_region(TEST_SEED, region_id, catalog)
		var b := EncounterDirectorScript.for_region(TEST_SEED, region_id, catalog)
		assert_array(a.wild_pool()).is_equal(b.wild_pool())
		for step in 40:
			assert_that(a.roll_step(step, "thin")).is_equal(b.roll_step(step, "thin"))


func test_identity_plumbing_resolves_for_all_eleven_forces() -> void:
	for region_id: String in ALL_REGIONS:
		# The palette lookup never silently defaults: the resolved key must be the region's own
		# force or its compound head (force_for_region's documented fallback), and every key the
		# eleven regions resolve to carries a real palette + structure pool + prop pool.
		var force := RegionCatalogScript.force(region_id)
		var resolved := OverworldTileSetScript.force_for_region(region_id)
		assert_bool(resolved == force or resolved == force.get_slice("+", 0)).is_true()
		assert_bool(OverworldTileSetScript.PALETTES.has(resolved)).is_true()
		assert_bool(OverworldTileSetScript.PROPS.has(resolved)).is_true()
		assert_bool(OverworldStructuresScript.POOLS.has(resolved)).is_true()
		# The authored VoiceBook entry sting resolves for every region id (voice_library §1.12).
		assert_str(OverworldContent.region_climate(region_id)).is_not_empty()
		assert_str(OverworldContent.region_title(region_id)).is_not_equal(region_id)


# --- helpers ----------------------------------------------------------------------------------- #


## The raw authored wild_pool rows for a region (slice_verdant.json for verdant, region_pools.json
## for the rest) — [] when a region rides the const fallback (none should, in this catalog).
func _raw_wild_rows(region_id: String) -> Array:
	var path := "res://catalog/region_pools.json"
	if region_id == "verdant_glut":
		path = "res://catalog/slice_verdant.json"
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return []
	var root: Dictionary = parsed
	if region_id != "verdant_glut":
		var regions: Variant = root.get("regions", {})
		if not (regions is Dictionary):
			return []
		var entry: Variant = (regions as Dictionary).get(region_id, {})
		root = entry if entry is Dictionary else {}
	var rows: Variant = root.get("wild_pool", [])
	var out: Array = []
	if rows is Array:
		for row in rows as Array:
			if row is Dictionary:
				out.append(row)
	return out
