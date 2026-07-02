extends GdUnitTestSuite
## Batch E1c — BOSS KITS PARITY: the authored pantheon data (boss_kits.json /
## region_bosses.json, GENERATED from docs/content/pantheon_kits.md) obeys its contract:
##   * all 25 kits land (6 Primordials + 9 grid-gods + 10 Olympians/Titans);
##   * every kit skill EXISTS in the live SkillEngine library (no new skills — domain untouched);
##   * every species proxy RESOLVES in the SpeciesCatalog, or the boss is warn-listed;
##   * roles are valid CombatBrain role-brain names;
##   * the VERBATIM intro/defeat lines + the 4 HSM phase flavors are present;
##   * region_bosses maps regions onto real kits, threshold (the hub) stays boss-free;
##   * the EncounterCatalog seam: verdant keeps its slice boss, other regions read the pantheon
##     config, and the boss-trigger flags are REGION-SCOPED outside verdant.
## Pure data/logic — headless.

const EncounterCatalogScript := preload("res://application/overworld/encounter_catalog.gd")

const KITS_PATH := "res://catalog/boss_kits.json"
const REGIONS_PATH := "res://catalog/region_bosses.json"
const VALID_ROLES := ["aggressor", "support", "controller", "unpredictable", "neutral"]
const PHASES := ["opening", "pressure", "desperation", "apotheosis"]
## The act-boss regions the data must cover (region_layouts.json minus the verdant slice's
## own wired boss + the boss-free hub).
const ACT_REGIONS := [
	"mournmarch", "forgefell", "storm_vault", "sunder", "titanfall", "tideless", "astral_tier"
]

var _catalog: SpeciesCatalog


func before() -> void:
	_catalog = SpeciesCatalog.new()


func _kits_doc() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(KITS_PATH))
	assert_bool(parsed is Dictionary).is_true()
	return parsed as Dictionary


func test_all_25_kits_land() -> void:
	var bosses: Array = _kits_doc().get("bosses", [])
	assert_int(bosses.size()).is_equal(25)
	assert_int(BossKitCatalog.count()).is_equal(25)
	var ranks := {"primordial": 0, "god": 0}
	for boss: Dictionary in bosses:
		var rank := str(boss.get("rank", ""))
		ranks[rank] = int(ranks.get(rank, 0)) + 1
	assert_int(int(ranks["primordial"])).is_equal(6)  # the pure-pole ceiling
	assert_int(int(ranks["god"])).is_equal(19)  # 9 grid-gods + 10 Olympians/Titans


func test_every_kit_skill_exists_in_the_live_library() -> void:
	var library: Dictionary = Constants.BALANCE["skill"]["library"]
	for boss: Dictionary in _kits_doc().get("bosses", []) as Array:
		var kit: Array = boss.get("kit", [])
		(
			assert_bool(kit.is_empty())
			. override_failure_message("boss %s has an empty kit" % str(boss.get("boss_id")))
			. is_false()
		)
		for skill in kit:
			(
				assert_bool(library.has(str(skill)))
				. override_failure_message(
					"boss %s names a non-library skill %s" % [str(boss.get("boss_id")), str(skill)]
				)
				. is_true()
			)
		# The mapped signature is part of the kit (when the boss carries one).
		var signature := str(boss.get("signature_skill", ""))
		if signature != "":
			assert_bool(kit.has(signature)).is_true()


func test_species_proxies_resolve_or_are_warn_listed() -> void:
	var doc := _kits_doc()
	var warn: Array = doc.get("unresolved", [])
	for boss: Dictionary in doc.get("bosses", []) as Array:
		var boss_id := str(boss.get("boss_id", ""))
		var species_id := str(boss.get("species_id", ""))
		if species_id == "":
			# The warn-list is the contract for an unresolvable authored name.
			(
				assert_bool(warn.has(boss_id))
				. override_failure_message("boss %s is unresolved but not warn-listed" % boss_id)
				. is_true()
			)
			continue
		var species: SpeciesData = _catalog.get_by_id(species_id)
		(
			assert_object(species)
			. override_failure_message(
				"boss %s proxy %s missing from the registry" % [boss_id, species_id]
			)
			. is_not_null()
		)
		# Proxies are drawn from the boss-grade ranks only.
		assert_bool(species.rank == "god" or species.rank == "legendary").is_true()


func test_roles_lines_and_phases_are_present_and_valid() -> void:
	for boss: Dictionary in _kits_doc().get("bosses", []) as Array:
		var boss_id := str(boss.get("boss_id", ""))
		(
			assert_bool(VALID_ROLES.has(str(boss.get("role", ""))))
			. override_failure_message("boss %s carries an invalid CombatBrain role" % boss_id)
			. is_true()
		)
		assert_str(str(boss.get("intro_line", ""))).is_not_empty()
		assert_str(str(boss.get("defeat_line", ""))).is_not_empty()
		var phases: Dictionary = boss.get("phase_flavor", {})
		for phase in PHASES:
			(
				assert_bool(phases.has(phase))
				. override_failure_message("boss %s is missing phase %s" % [boss_id, phase])
				. is_true()
			)


func test_region_bosses_map_onto_real_kits() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(REGIONS_PATH))
	assert_bool(parsed is Dictionary).is_true()
	var map: Dictionary = (parsed as Dictionary).get("region_bosses", {})
	for region in map:
		var boss := BossKitCatalog.boss_by_id(str(map[region]))
		(
			assert_bool(boss.is_empty())
			. override_failure_message(
				"region %s names an unknown boss %s" % [str(region), str(map[region])]
			)
			. is_false()
		)
	for region in ACT_REGIONS:
		(
			assert_bool(map.has(region))
			. override_failure_message("region %s has no act-boss slot" % str(region))
			. is_true()
		)
	# The hub keeps no boss; the reserved not-yet-landed regions are present for the integrator.
	assert_bool(map.has("threshold")).is_false()
	assert_bool(map.has("maw_beneath")).is_true()
	assert_bool(map.has("hollow_atelier")).is_true()


func test_encounter_catalog_seam_verdant_stays_slice_and_regions_read_pantheon() -> void:
	# VERDANT: byte-identical to the shipped slice — a Legendary from slice_verdant.json,
	# no pantheon keys.
	var verdant := EncounterCatalogScript.boss_for("verdant_glut")
	assert_bool(verdant.is_empty()).is_false()
	var verdant_species: SpeciesData = _catalog.get_by_id(str(verdant.get("species_id", "")))
	assert_object(verdant_species).is_not_null()
	assert_str(verdant_species.rank).is_equal("legendary")
	assert_bool(verdant.has("boss_id")).is_false()
	# A pantheon region reads its authored act boss with the kit + VERBATIM lines.
	var mourn := EncounterCatalogScript.boss_for("mournmarch")
	assert_str(str(mourn.get("boss_id", ""))).is_equal("ol_10_aidaneus")
	assert_str(str(mourn.get("name", ""))).is_equal("Aidaneus, the Underlord")
	assert_bool((mourn.get("kit", []) as Array).is_empty()).is_false()
	assert_str(str(mourn.get("intro_line", ""))).is_not_empty()
	assert_str(str(mourn.get("defeat_line", ""))).is_not_empty()
	assert_object(_catalog.get_by_id(str(mourn.get("species_id", "")))).is_not_null()
	# The hub has no boss — its trigger can never fire.
	assert_bool(EncounterCatalogScript.boss_for("threshold").is_empty()).is_true()


func test_boss_trigger_flags_are_region_scoped_outside_verdant() -> void:
	var verdant := EncounterCatalogScript.boss_trigger_for("verdant_glut")
	assert_str(str(verdant["cleared_flag"])).is_equal("verdant_boss_cleared")
	assert_str(str(verdant["victory_flag"])).is_equal("slice_verdant_victory")
	var mourn := EncounterCatalogScript.boss_trigger_for("mournmarch")
	assert_str(str(mourn["cleared_flag"])).is_equal("mournmarch_boss_cleared")
	assert_str(str(mourn["victory_flag"])).is_equal("mournmarch_boss_victory")
	assert_int(int(mourn["min_steps"])).is_equal(30)
