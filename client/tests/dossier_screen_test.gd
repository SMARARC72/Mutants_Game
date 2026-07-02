extends GdUnitTestSuite
## Wave 17 — the DOSSIER (creature soul-page), built HEADLESSLY for a REAL species creature and a
## SPLICED HYBRID:
##   * the page renders the name header, all six pole-stat rows (icon+bar+NUMBER), the skill kit
##     with verb rows, and the bond/entropy/corruption meters;
##   * a hybrid (species_id "", stats_cached + lineage) resolves its cached identity and NAMES its
##     parents on the lineage strip — permadeath gets a face.

const GameControllerScript := preload("res://application/game/game_controller.gd")
const FakeDalScript := preload("res://infrastructure/dal/fake_dal.gd")
const DossierScreenScript := preload("res://presentation/dossier/dossier_screen.gd")

const TEST_SEED := 0xD0551E12
const POLE_STATS: Array = ["Bulk", "Celerity", "Ward", "Spike", "Vitality", "Bane"]


func _make_game() -> Node:
	var gc: Node = GameControllerScript.new()
	add_child(gc)
	gc.call("configure", FakeDalScript.make())
	gc.call("new_run", TEST_SEED)
	return gc


func _make_dossier(gc: Node) -> Control:
	var page: Control = DossierScreenScript.new()
	page.call("set_game", gc)
	add_child(page)
	return page


## A spliced-hybrid party entry in the exact lab-commit shape (stats_cached + lineage.parents).
func _hybrid() -> Dictionary:
	return {
		"species_id": "",
		"nickname": "Gruesome Delight",
		"genome": {},
		"expression": 0.4,
		"bond": 0.3,
		"entropy": 22,
		"awakenings": 1,
		"stats_cached":
		{
			"prim": "Eros",
			"sec": "Gaia",
			"tier": "T2",
			"hp": 44,
			"bst": 210,
			"stats":
			{"Bulk": 38, "Celerity": 30, "Ward": 33, "Spike": 41, "Vitality": 36, "Bane": 32},
		},
		"skills": [],
		"status_effects": {},
		"lineage":
		{
			"spliced": true,
			"op": "fuse",
			"parents":
			[
				{"species_id": "SB07", "nickname": "Alpha", "portrait_species": "SB07"},
				{"species_id": "AD10", "nickname": "Betabloom", "portrait_species": "AD10"},
			],
			"portrait_species": "SB07",
			"splice_config": {},
			"rng_seed_tag": "op-test-77",
			"taboo": false,
		},
		"is_dead": false,
	}


func test_dossier_builds_for_a_real_party_creature() -> void:
	var gc := _make_game()
	var page := _make_dossier(gc)
	assert_bool(bool(page.call("show_creature", 0))).is_true()
	# Name header (Cinzel TitleLabel) resolved from the species row.
	assert_str(str(page.call("title_text"))).is_not_empty()
	# All six pole stats render as icon+bar+NUMBER rows.
	assert_int(int(page.call("stat_row_count"))).is_equal(6)
	for stat: String in POLE_STATS:
		var row := page.find_child("StatRow_%s" % stat, true, false)
		assert_object(row).is_not_null()
		assert_object(row.find_child("StatBar", true, false)).is_not_null()
		assert_object(row.find_child("StatNumber", true, false)).is_not_null()
	# The skill kit (KitFactory over the creature's forces) renders at least one verb row.
	assert_int(int(page.call("skill_row_count"))).is_greater(0)
	# The cost meters + the portrait + the lineage strip all landed.
	assert_object(page.find_child("BondMeter", true, false)).is_not_null()
	assert_object(page.find_child("EntropyMeter", true, false)).is_not_null()
	assert_object(page.find_child("CorruptionMeter", true, false)).is_not_null()
	assert_object(page.find_child("DossierPortrait", true, false)).is_not_null()
	assert_object(page.find_child("LineageStrip", true, false)).is_not_null()
	page.queue_free()
	gc.queue_free()


func test_dossier_builds_for_a_spliced_hybrid_and_names_parents() -> void:
	var gc := _make_game()
	var page := _make_dossier(gc)
	assert_bool(bool(page.call("show_creature_dict", _hybrid()))).is_true()
	# The hybrid's cached identity carries the page — nickname header + six non-zero stat rows.
	assert_str(str(page.call("title_text"))).is_equal("Gruesome Delight")
	assert_int(int(page.call("stat_row_count"))).is_equal(6)
	# The lineage strip NAMES both parents (lineage.parents from the lab commit).
	var lineage := str(page.call("lineage_text"))
	assert_bool(lineage.contains("Alpha")).is_true()
	assert_bool(lineage.contains("Betabloom")).is_true()
	# A hybrid's kit resolves from its cached forces (Eros/Gaia -> a real skill list).
	assert_int(int(page.call("skill_row_count"))).is_greater(0)
	page.queue_free()
	gc.queue_free()


func test_dossier_rejects_a_bad_index() -> void:
	var gc := _make_game()
	var page := _make_dossier(gc)
	assert_bool(bool(page.call("show_creature", 99))).is_false()
	page.queue_free()
	gc.queue_free()


func test_captured_lineage_reads_as_caught_wild() -> void:
	var gc := _make_game()
	var page := _make_dossier(gc)
	var caught := {
		"species_id": "SB33",
		"nickname": "Bitey",
		"expression": 0.3,
		"bond": 0.1,
		"lineage": {"captured": true, "from_species": "SB33"},
	}
	assert_bool(bool(page.call("show_creature_dict", caught))).is_true()
	assert_bool(str(page.call("lineage_text")).contains("Caught wild")).is_true()
	page.queue_free()
	gc.queue_free()
