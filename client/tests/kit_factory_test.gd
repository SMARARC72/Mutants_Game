extends GdUnitTestSuite
## KitFactory (Phase 10 · Slice 0) — the force->kit derivation is deterministic, library-valid, and
## orders the primary force's pool ahead of the secondary's. Pure mapping policy; no oracle math here.

const FORCES := ["Gaia", "Ouranos", "Cosmos", "Chaos", "Eros", "Thanatos"]


func test_every_force_yields_a_nonempty_kit() -> void:
	for force: String in FORCES:
		assert_int(KitFactory.kit_for(force, "").size()).is_greater(0)


func test_kit_is_deterministic() -> void:
	assert_array(KitFactory.kit_for("Chaos", "Thanatos")).is_equal(
		KitFactory.kit_for("Chaos", "Thanatos")
	)


func test_kit_references_only_library_skills() -> void:
	var lib: Dictionary = Constants.BALANCE["skill"]["library"]
	for s: String in KitFactory.kit_for("Gaia", "Eros"):
		assert_bool(lib.has(s)).is_true()


func test_primary_pool_leads_then_secondary() -> void:
	# Gaia pool first (Boulder Smash, Bulwark), then Eros (Bloom, Verdant Gift) — deduped, ordered.
	var kit := KitFactory.kit_for("Gaia", "Eros")
	assert_array(kit).contains_exactly(["Boulder Smash", "Bulwark", "Bloom", "Verdant Gift"])
	assert_int(kit.find("Boulder Smash")).is_less(kit.find("Bloom"))


func test_mono_force_kit_is_just_the_primary_pool() -> void:
	# A mono-force creature (sec == prim) gets only the primary pool, no duplication.
	assert_array(KitFactory.kit_for("Ouranos", "Ouranos")).contains_exactly(
		["Gale Slash", "Tailwind"]
	)


func test_secondary_overlap_is_deduped() -> void:
	# Even with an empty/overlapping secondary the kit carries each skill once.
	assert_array(KitFactory.kit_for("Chaos", "")).contains_exactly(["Riot Fang", "Overload"])


func test_skills_of_force_groups_by_force() -> void:
	for s: String in KitFactory.skills_of_force("Thanatos"):
		assert_str(str(Constants.BALANCE["skill"]["library"][s]["force"])).is_equal("Thanatos")
