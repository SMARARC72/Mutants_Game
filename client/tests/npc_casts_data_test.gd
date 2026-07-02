extends GdUnitTestSuite
## Batch E1c — REGIONAL CASTS PARITY: the authored cast data (npc_casts.json, GENERATED from
## docs/content/regional_cast.md + factions_npcs.md) obeys its contract:
##   * per-region counts match the authored docs (9 leaders + 27 Hands + the 64-NPC roster +
##     the +43 living-world cast + the wanderers = 143);
##   * ring colours are DETERMINISTIC (stable goldens) and every def is screen-shaped;
##   * timelines follow the shared scene-id convention '<npc_snake_case>_<beat>' (beat intro);
##   * factions are drawn from the nine canon ids;
##   * the OverworldContent seam: verdant keeps the hand-wired NPC_DEFS, other regions draw
##     the catalog, and an unknown region falls back (no region is ever peopleless).
## Pure data/logic — headless.

## Authored per-region counts (docs parity — regenerating the data must keep these).
const EXPECTED_COUNTS := {
	"astral_tier": 11,
	"forgefell": 14,
	"hollow_atelier": 3,
	"maw_beneath": 4,
	"mournmarch": 13,
	"storm_vault": 12,
	"the_sunder": 16,
	"the_tideless": 12,
	"threshold": 19,
	"titanfall": 13,
	"verdant_glut": 13,
	"wanderers": 13,
}
const FACTION_IDS := [
	"concord",
	"iron_guild",
	"pale_court",
	"high_table",
	"stoneblooded",
	"bloomwardens",
	"revel",
	"unbound",
	"deep_choir",
	""
]
const TIMELINE_RE := "^[a-z0-9_]+_intro$"


func test_counts_per_region_match_the_docs() -> void:
	var total := 0
	for region in EXPECTED_COUNTS:
		var defs := NpcCastCatalog.defs_for_region(str(region))
		(
			assert_int(defs.size())
			. override_failure_message("region %s cast count drifted" % str(region))
			. is_equal(int(EXPECTED_COUNTS[region]))
		)
		total += defs.size()
	assert_int(total).is_equal(143)
	assert_int(NpcCastCatalog.region_ids().size()).is_equal(EXPECTED_COUNTS.size())


func test_defs_are_screen_shaped_and_convention_named() -> void:
	var regex := RegEx.new()
	regex.compile(TIMELINE_RE)
	for region in EXPECTED_COUNTS:
		for def: Dictionary in NpcCastCatalog.defs_for_region(str(region)):
			assert_str(str(def["name"])).is_not_empty()
			assert_bool(def["ring"] is Color).is_true()
			assert_bool(bool(def["cast"])).is_true()
			assert_bool(def["barks"] is Array).is_true()
			(
				assert_bool(FACTION_IDS.has(str(def["faction"])))
				. override_failure_message(
					"%s carries unknown faction %s" % [str(def["name"]), str(def["faction"])]
				)
				. is_true()
			)
			# The shared E1a reconciliation contract: '<npc_snake_case>_<beat>'.
			(
				assert_object(regex.search(str(def["timeline"])))
				. override_failure_message(
					(
						"%s timeline %s breaks the scene-id convention"
						% [str(def["name"]), str(def["timeline"])]
					)
				)
				. is_not_null()
			)


func test_ring_colours_are_deterministic_goldens() -> void:
	# Two stable goldens: hashing is FNV-1a over the VERBATIM name — regenerating the data
	# must reproduce these bytes exactly (the byte-identical re-run contract).
	var ottle := _def_by_name("mournmarch", "Sub-Registrar Ottle Greyquill")
	assert_bool(ottle.is_empty()).is_false()
	assert_that(ottle["ring"]).is_equal(Color("#8152b2"))
	var steward := _def_by_name("mournmarch", "The Pale Steward, Wessel Graf von Underhart")
	assert_bool(steward.is_empty()).is_false()
	assert_that(steward["ring"]).is_equal(Color("#6d9cb2"))
	# And distinct names hash to distinct rings (the token-legibility point of hashing).
	assert_bool(ottle["ring"] == steward["ring"]).is_false()


func test_leaders_carry_their_standing_voice_and_hands_their_quote() -> void:
	var steward := _def_by_name("mournmarch", "The Pale Steward, Wessel Graf von Underhart")
	assert_str(str(steward["faction"])).is_equal("pale_court")
	assert_int((steward["barks"] as Array).size()).is_equal(5)  # Stranger -> Hand, VERBATIM
	var mund := _def_by_name("mournmarch", "Archivist Mund the Indexed")
	assert_bool((mund["barks"] as Array).is_empty()).is_false()


func test_overworld_content_seam_verdant_canonical_regions_from_catalog() -> void:
	# VERDANT: the hand-wired cast, untouched (the Act-0 spine + SQ quest NPCs live there).
	var verdant := OverworldContent.region_npc_defs("verdant_glut")
	assert_int(verdant.size()).is_equal(OverworldContent.NPC_DEFS.size())
	assert_str(str((verdant[0] as Dictionary)["name"])).is_equal("Old Marrow")
	# A pantheon region draws the authored catalog cast.
	var mourn := OverworldContent.region_npc_defs("mournmarch")
	assert_int(mourn.size()).is_equal(13)
	assert_bool(bool((mourn[0] as Dictionary).get("cast", false))).is_true()
	# An unknown region falls back to the hand-wired defs — never peopleless.
	var nowhere := OverworldContent.region_npc_defs("no_such_region")
	assert_int(nowhere.size()).is_equal(OverworldContent.NPC_DEFS.size())


func _def_by_name(region: String, npc_name: String) -> Dictionary:
	for def: Dictionary in NpcCastCatalog.defs_for_region(region):
		if str(def["name"]) == npc_name:
			return def
	return {}
