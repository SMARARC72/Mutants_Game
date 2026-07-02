extends GdUnitTestSuite
## Batch E2a — "THE PLAYABLE ARC": Acts 0 through 5 walked END TO END, headless. This suite is
## the arc's TRUTH (tools/INGEST_NOTES.md, E2 section): a scripted run from new_run through the
## Act-5 finale flag, driving the REAL wiring the player drives —
##   * Act-0's hand-wired spine via speak_to + Dialogic choice resolution (headless canon);
##   * main-quest givers via their reconciled cast NPCs (NpcCastCatalog.QUEST_STEP_CARRY +
##     the hand-wired NPC_DEFS carries), talked to IN their regions;
##   * region travel through the Threshold overlay, gate flags earned by the chain
##     (astral_tier <- act1_q3_done, sunder <- act2_q1_done — the E2a gate corrections);
##   * deed-resolved quests (QuestCatalog.VICTORY_FLAGS) through the overworld's catalog sync.
## COMBAT SHORTCUTS (documented): the walk force-sets ONLY the four real boss-victory flags a
## fight would set — titanfall/sunder/maw_beneath/hollow_atelier `_boss_victory` — exactly what
## GameController._mark_slice_cleared writes on a played boss win. Everything else is earned.
## Asserts: every act gate opens IN ORDER, every main quest reaches done, travel unlocks
## follow, authored scenes play where they shipped, and the finale flag (act5_q4_done) lands.

const GameControllerScript := preload("res://application/game/game_controller.gd")
const FakeDalScript := preload("res://infrastructure/dal/fake_dal.gd")
const OverworldScreenScript := preload("res://presentation/overworld/overworld_screen.gd")
const RegionTravelScript := preload("res://application/overworld/region_travel.gd")
const RegionCatalogScript := preload("res://application/overworld/region_catalog.gd")

const TEST_SEED := 0x0E2A_0AC7

## Main-quest ids in doc order (acts 1-5; act 0 walks the hand-wired spine ids).
const MAIN_CHAIN := [
	"act1_greener_pastures_hungrier_ones",
	"act1_the_foremans_problem",
	"act1_the_guardian_at_the_node",
	"act1_the_reliquary_of_winners",
	"act2_the_sworn_rite",
	"act2_the_line_you_cant_uncross",
	"act2_the_one_who_climbed_beside_you",
	"act2_first_light",
	"act3_first_blood_on_the_thrones",
	"act3_a_gods_bargain",
	"act3_the_throne_turned",
	"act3_holes_in_the_sky",
	"act4_the_pure_poles",
	"act4_the_last_reckoning_of_the_clans",
	"act4_what_you_built",
	"act4_the_empty_seat",
	"act5_petrification",
	"act5_the_first_invader",
	"act5_the_walls_choice",
	"act5_a_graveyard_of_winners",
]


func _make_game() -> Node:
	var gc: Node = GameControllerScript.new()
	add_child(gc)
	gc.call("configure", FakeDalScript.make())
	return gc


func _make_overworld(game: Node) -> Node2D:
	var ow: Node2D = OverworldScreenScript.new()
	ow.call("set_game", game)
	ow.call("set_auto_hand_off", false)
	ow.call("set_camp_enabled", false)
	add_child(ow)
	ow.call("build_from_game")
	return ow


## Speak to the spawned NPC named `npc_name` (exact catalog/hand-wired name). Fails loud when
## the cast did not spawn the giver — that IS an arc break.
func _speak(ow: Node2D, npc_name: String) -> String:
	var npcs: Array = ow.get("_npcs")
	for i in npcs.size():
		if str((npcs[i] as Dictionary).get("name", "")) == npc_name:
			return str(ow.call("speak_to", i))
	(
		assert_bool(false)
		. override_failure_message("giver NPC never spawned in the region: " + npc_name)
		. is_true()
	)
	return ""


## Ride the Threshold circle to `region_id` through the real overlay (gates enforced).
func _travel(ow: Node2D, region_id: String) -> void:
	var screen: Node = ow.call("open_threshold")
	(
		assert_bool(bool(screen.call("travel", region_id)))
		. override_failure_message("travel refused (gate sealed?): " + region_id)
		. is_true()
	)


## Run the deed-quest sync exactly as a post-battle overworld build runs it (sync + the
## authored-scene play for whatever advanced).
func _sync(ow: Node2D) -> Array:
	var advanced: Array = OverworldQuestsGlue.sync_catalog_quests(ow, ow.get("_quests"))
	OverworldQuestsGlue.play_scene_for(ow, advanced)
	return advanced


func _done(ow: Node2D, quest_id: String) -> bool:
	return bool(ow.call("quest_done", quest_id))


func _assert_done(ow: Node2D, quest_id: String) -> void:
	(
		assert_bool(_done(ow, quest_id))
		. override_failure_message("main quest did not reach done: " + quest_id)
		. is_true()
	)


func test_the_arc_walks_acts_0_through_5_to_the_finale() -> void:
	var gc := _make_game()
	var run: RunContext = gc.call("new_run", TEST_SEED)
	var ow := _make_overworld(gc)
	var scenes: Array = []
	ow.connect("dialogue_started", func(tid: String) -> void: scenes.append(tid))

	# === ACT 0 — the hand-wired spine (the starting region hosts the Threshold cast) ===
	_speak(ow, "Old Maddox")
	_speak(ow, "Mother Kestrel")  # first-catch CHOICE; headless canon = offer_hand
	_speak(ow, "Surgeon-Lab-Tech Veil")
	_speak(ow, "Vael Construct-Nine")  # the Mark CHOICE; headless canon = seal
	_speak(ow, "Madam Thessaly Vance")
	_assert_done(ow, "act0_registered")
	assert_bool(bool(run.flags.get("registered_aspirant", false))).is_true()
	# Act-1 travel unlocks follow the climax flag; the act-3 tier stays sealed.
	assert_bool(RegionTravelScript.unlocked(run, "forgefell")).is_true()
	assert_bool(RegionTravelScript.unlocked(run, "titanfall")).is_true()
	assert_bool(RegionTravelScript.unlocked(run, "astral_tier")).is_false()

	# === ACT 1 — the climb ===
	# Q1.1: the Greenmother beat plays its authored scene (the .dtl outranks her intro).
	var q11_scene := _speak(ow, "Matron Sevvy")
	assert_str(q11_scene).is_equal("mvp_s05_greener_pastures_hungrier_ones")
	_assert_done(ow, "act1_greener_pastures_hungrier_ones")
	# Q1.2: the Iron Guild's leader in Forgefell.
	_travel(ow, "forgefell")
	_speak(ow, "Foundress Magna Ironwright, the Hand That Improves")
	_assert_done(ow, "act1_the_foremans_problem")
	# Q1.3: the Legendary at the node is a DEED — it self-starts on arrival in Titanfall...
	_travel(ow, "titanfall")
	assert_bool(bool(ow.call("quest_active", "act1_the_guardian_at_the_node"))).is_true()
	# ...and completes on the region's boss victory (COMBAT SHORTCUT: the real flag name).
	run.flags["titanfall_boss_victory"] = true
	_sync(ow)
	_assert_done(ow, "act1_the_guardian_at_the_node")
	# The corrected astral gate follows the chain flag the moment Q1.4 becomes startable.
	assert_bool(RegionTravelScript.unlocked(run, "astral_tier")).is_true()
	# Q1.4: the Reliquary truth — act 2 opens, and its travel unlocks follow.
	_travel(ow, "astral_tier")
	_speak(ow, "Archon Velleth Sun-Notary, the Last Lawful Voice")
	_assert_done(ow, "act1_the_reliquary_of_winners")
	assert_bool(bool(run.flags.get("act2_open", false))).is_true()
	assert_bool(RegionTravelScript.unlocked(run, "storm_vault")).is_true()
	assert_bool(RegionTravelScript.unlocked(run, "tideless")).is_true()
	assert_bool(RegionTravelScript.unlocked(run, "sunder")).is_false()

	# === ACT 2 — the deepening ===
	# Q2.1: the Sworn Rite at the Pale Court's leader; the Sunder unseals behind it.
	_travel(ow, "mournmarch")
	_speak(ow, "The Pale Steward, Wessel Graf von Underhart")
	_assert_done(ow, "act2_the_sworn_rite")
	assert_bool(RegionTravelScript.unlocked(run, "sunder")).is_true()
	# Q2.2: the taboo Lab line, given where the heretic works.
	_travel(ow, "sunder")
	_speak(ow, "The Unmaker, She-Who-Is-Called Nael (and other things)")
	_assert_done(ow, "act2_the_line_you_cant_uncross")
	# Q2.3: the rival's marker is High Table business (storm_vault).
	_travel(ow, "storm_vault")
	_speak(ow, "The Chairwoman, Indra Vael of the Long Marker")
	_assert_done(ow, "act2_the_one_who_climbed_beside_you")
	# Q2.4: Vael notarizes the first Apotheosis — act 3 opens.
	_travel(ow, "verdant_glut")
	_speak(ow, "Vael Construct-Nine")
	_assert_done(ow, "act2_first_light")
	assert_bool(bool(run.flags.get("act3_open", false))).is_true()

	# === ACT 3 — the reckoning ===
	# Q3.1: the first deicide (Bakchanyr, the Sunder's throne) — a DEED (COMBAT SHORTCUT).
	run.flags["sunder_boss_victory"] = true
	_sync(ow)
	_assert_done(ow, "act3_first_blood_on_the_thrones")
	# Q3.2: the surviving forge-god's patron offer, spoken by his last construct.
	_travel(ow, "forgefell")
	_speak(ow, 'The Last Automaton, Unit Called "Patience"')
	_assert_done(ow, "act3_a_gods_bargain")
	# Q3.3 + Q3.4: Vael reports the turned godling; Thessaly convenes the final Marker.
	_travel(ow, "verdant_glut")
	_speak(ow, "Vael Construct-Nine")
	_assert_done(ow, "act3_the_throne_turned")
	_speak(ow, "Madam Thessaly Vance")
	_assert_done(ow, "act3_holes_in_the_sky")
	assert_bool(bool(run.flags.get("act4_open", false))).is_true()
	assert_bool(RegionTravelScript.unlocked(run, "maw_beneath")).is_true()

	# === ACT 4 — the throne ===
	# Q4.1: the Primordial trial in the Maw — a DEED (COMBAT SHORTCUT).
	run.flags["maw_beneath_boss_victory"] = true
	_sync(ow)
	_assert_done(ow, "act4_the_pure_poles")
	# Q4.2: the Concord crowns or blocks (Vox re-roles under Velleth).
	_travel(ow, "astral_tier")
	_speak(ow, "Archon Velleth Sun-Notary, the Last Lawful Voice")
	_assert_done(ow, "act4_the_last_reckoning_of_the_clans")
	# Q4.3: the Table brokers the convergence of every thread.
	_travel(ow, "storm_vault")
	_speak(ow, "The Chairwoman, Indra Vael of the Long Marker")
	_assert_done(ow, "act4_what_you_built")
	# Q4.4 -> Q5.1: the Choice and the petrification rite cascade in Vael's ONE talk
	# (authored-adjacent — the notarization flows straight into the snapshot).
	_travel(ow, "verdant_glut")
	_speak(ow, "Vael Construct-Nine")
	_assert_done(ow, "act4_the_empty_seat")
	assert_bool(bool(run.flags.get("act5_open", false))).is_true()
	assert_bool(RegionTravelScript.unlocked(run, "hollow_atelier")).is_true()
	_assert_done(ow, "act5_petrification")

	# === ACT 5 — the succession ===
	# Q5.2: defend the throne (COMBAT SHORTCUT); Q5.3/Q5.4 are WITNESS beats that resolve
	# in the same doc-ordered sync pass the moment their chain triggers land.
	run.flags["hollow_atelier_boss_victory"] = true
	_sync(ow)
	for quest_id: String in MAIN_CHAIN:
		_assert_done(ow, quest_id)
	# THE FINALE FLAG: Q5.4's completion — the loop made explicit, on the run itself.
	assert_bool(bool(run.flags.get("act5_q4_done", false))).is_true()

	# The authored scenes fired where the story moved (a sample across the acts).
	(
		assert_array(scenes)
		. contains(
			[
				"mvp_s05_greener_pastures_hungrier_ones",
				"acts_s01_the_sworn_rite",
				"acts_s02_the_line_you_cant_uncross",
				"acts_s03_first_light",
				"acts_s05_the_throne_turned",
				"acts_s06_holes_in_the_sky",
				"acts_s08_the_empty_seat",
				"acts_s10_the_walls_choice_the_graveyard",
			]
		)
	)
	ow.queue_free()
	gc.queue_free()


func test_every_main_quest_is_driven_by_a_talk_or_a_deed() -> void:
	# GIVER PARITY: every acts-1-5 main quest must be reachable — either a DEED quest
	# (QuestCatalog.VICTORY_FLAGS) or its step_key is carried by a spawnable NPC def
	# (the hand-wired cast or a REGION cast; "wanderers" never spawns). Act 0 dedupes
	# into the hand-wired spine.
	var carriers: Array = []
	for def: Dictionary in OverworldContent.NPC_DEFS:
		carriers.append(def)
	for region_id: Variant in NpcCastCatalog.region_ids():
		if str(region_id) == "wanderers":
			continue
		carriers.append_array(NpcCastCatalog.defs_for_region(str(region_id)))
	for e: Dictionary in QuestCatalog.entries():
		if str(e.get("kind", "")) != "main" or int(e.get("act", -1)) < 1:
			continue
		var quest_id := str(e.get("id", ""))
		if QuestCatalog.VICTORY_FLAGS.has(quest_id):
			continue
		var step_key := str((e.get("steps", [])[0] as Dictionary).get("step_key", ""))
		var carried := false
		for def: Dictionary in carriers:
			if def.has(step_key):
				carried = true
				break
		(
			assert_bool(carried)
			. override_failure_message("no spawnable NPC carries the giver step: " + quest_id)
			. is_true()
		)


func test_region_gates_open_with_the_chain_that_needs_them() -> void:
	# The E2a gate corrections: a main-quest giver's region must unseal no later than the
	# flag that makes their quest startable (the chicken-and-egg seals E1b shipped).
	assert_str(RegionCatalogScript.gate_flag("astral_tier")).is_equal("act1_q3_done")
	assert_str(RegionCatalogScript.gate_flag("sunder")).is_equal("act2_q1_done")
	# The rest of the lattice holds its authored act gates.
	assert_str(RegionCatalogScript.gate_flag("mournmarch")).is_equal("registered_aspirant")
	assert_str(RegionCatalogScript.gate_flag("forgefell")).is_equal("registered_aspirant")
	assert_str(RegionCatalogScript.gate_flag("titanfall")).is_equal("registered_aspirant")
	assert_str(RegionCatalogScript.gate_flag("storm_vault")).is_equal("act2_open")
	assert_str(RegionCatalogScript.gate_flag("tideless")).is_equal("act2_open")
	assert_str(RegionCatalogScript.gate_flag("maw_beneath")).is_equal("act4_open")
	assert_str(RegionCatalogScript.gate_flag("hollow_atelier")).is_equal("act5_open")


func test_deed_quests_carry_real_victory_flags() -> void:
	# Every boss-gated quest names the EXACT flag GameController._mark_slice_cleared sets
	# for its region (EncounterCatalog.boss_trigger_for) — no invented flag can strand it.
	var expected := {
		"act1_the_guardian_at_the_node": "titanfall",
		"act3_first_blood_on_the_thrones": "sunder",
		"act4_the_pure_poles": "maw_beneath",
		"act5_the_first_invader": "hollow_atelier",
	}
	for quest_id: String in expected:
		var flag := str(QuestCatalog.VICTORY_FLAGS.get(quest_id, "<missing>"))
		var trigger: Dictionary = EncounterCatalog.boss_trigger_for(str(expected[quest_id]))
		assert_str(flag).is_equal(str(trigger.get("victory_flag", "")))
