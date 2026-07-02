extends GdUnitTestSuite
## Wave 18 "Death With Weight" — the application-layer DEATH RULE (ADR-0020), headless.
##   * a LOST battle buries every 0-HP party creature EXCEPT the lead (the Last Light survives
##     at 1 HP, scarred): the dead leave run.party for run.flags["graveyard"] with a well-shaped
##     memorial and credit 1-2 wild-rank parts through the InventoryAdapter;
##   * a battle that was NOT lost never kills — 0-HP members are scarred survivors at 1 HP
##     (the MERCY rule); a flee is an escape, not a defeat;
##   * a dead creature is excluded from the next battle's team build;
##   * results without party_hp (auto/boss round-trips) kill nobody.
## HP / is_dead stay OUT of client/domain/ — everything here drives GameController + factories.

const GameControllerScript := preload("res://application/game/game_controller.gd")
const FakeDalScript := preload("res://infrastructure/dal/fake_dal.gd")
const MortalityServiceScript := preload("res://application/game/mortality_service.gd")
const SkillMonFactoryScript := preload("res://application/battle/skill_mon_factory.gd")
const MonFactoryScript := preload("res://application/battle/mon_factory.gd")

const TEST_SEED := 0xD1E5


func _make_controller() -> Node:
	var gc: Node = GameControllerScript.new()
	add_child(gc)
	gc.call("configure", FakeDalScript.make())
	return gc


## A LOST-battle result whose party_hp zeroes every party index (the wipe shape).
func _lost_result(party_size: int) -> Dictionary:
	var hp_payload: Array = []
	for i in party_size:
		hp_payload.append({"index": i, "hp": 0, "max_hp": 20})
	return {
		"player_won": false,
		"winner": "enemy",
		"reason": "defeat",
		"turns": 6,
		"enemy_survivors": ["Grave-Boar"],
		"xp": 0,
		"party_hp": hp_payload,
	}


func test_lost_battle_buries_the_dead_and_spares_the_last_light() -> void:
	var gc := _make_controller()
	var run: RunContext = gc.call("new_run", TEST_SEED)
	var party_size := run.party.size()
	assert_int(party_size).is_greater_equal(2)
	var lead: Dictionary = run.party[0]
	gc.call("apply_battle_result", _lost_result(party_size))

	# The Last Light: the lead survives at 1 HP, scarred; everyone else zeroed is GONE.
	assert_int(run.party.size()).is_equal(1)
	assert_bool(is_same(run.party[0], lead)).is_true()
	assert_int(int(lead["hp"])).is_equal(1)
	assert_bool(bool(lead["scarred"])).is_true()
	assert_bool(lead.has("is_dead") and bool(lead["is_dead"])).is_false()

	# The graveyard holds one memorial per death, in party order.
	var graveyard: Array = MortalityServiceScript.graveyard_of(gc.call("run"))
	assert_int(graveyard.size()).is_equal(party_size - 1)
	var mortality: Dictionary = gc.call("last_mortality")
	assert_int((mortality["deaths"] as Array).size()).is_equal(party_size - 1)
	gc.queue_free()


func test_memorial_shape_and_parts_credit() -> void:
	var gc := _make_controller()
	var run: RunContext = gc.call("new_run", TEST_SEED)
	gc.call("apply_battle_result", _lost_result(run.party.size()))
	var graveyard: Array = MortalityServiceScript.graveyard_of(gc.call("run"))
	assert_int(graveyard.size()).is_greater(0)
	var inventory: InventoryAdapter = gc.call("inventory")
	for memorial_v in graveyard:
		var memorial: Dictionary = memorial_v
		# The memorial dict shape the Journal renders: name/species/sigil/cause/turn/parts.
		assert_str(str(memorial.get("name", ""))).is_not_empty()
		assert_bool(memorial.has("species_id")).is_true()
		assert_bool(memorial.has("sigil")).is_true()
		assert_str(str(memorial.get("cause", ""))).contains("Grave-Boar")
		assert_bool(str(memorial.get("cause", "")).to_lower().contains("faint")).is_false()
		assert_int(int(memorial.get("turn", 0))).is_equal(6)
		# 1-2 parts credited, each present in the live inventory drawer as an ingredient.
		var parts: Array = memorial.get("parts", [])
		assert_int(parts.size()).is_between(1, 2)
		for part in parts:
			var found := false
			for item in inventory.ingredient_items():
				if (item as InventoryItem).item_key == str(part):
					found = true
			assert_bool(found).is_true()
		# The buried creature record is marked dead (the Journal silhouettes it).
		var creature: Dictionary = memorial.get("creature", {})
		assert_bool(bool(creature.get("is_dead", false))).is_true()
	gc.queue_free()


func test_won_battle_scars_the_downed_instead_of_killing() -> void:
	var gc := _make_controller()
	var run: RunContext = gc.call("new_run", TEST_SEED)
	var party_size := run.party.size()
	var downed: Dictionary = run.party[1]
	var result := {
		"player_won": true,
		"winner": "player",
		"reason": "defeat",
		"turns": 5,
		"xp": 12,
		"party_hp": [{"index": 1, "hp": 0, "max_hp": 18}],
	}
	gc.call("apply_battle_result", result)
	# MERCY rule: nobody leaves the party; the downed one is dragged out at 1 HP, scarred.
	assert_int(run.party.size()).is_equal(party_size)
	assert_int(int(downed["hp"])).is_equal(1)
	assert_bool(bool(downed["scarred"])).is_true()
	assert_int(MortalityServiceScript.graveyard_of(gc.call("run")).size()).is_equal(0)
	assert_array((gc.call("last_mortality") as Dictionary)["scarred"] as Array).contains([1])
	gc.queue_free()


func test_flee_is_an_escape_not_a_defeat() -> void:
	var gc := _make_controller()
	var run: RunContext = gc.call("new_run", TEST_SEED)
	var party_size := run.party.size()
	var result := {
		"player_won": false,
		"winner": "fled",
		"reason": "fled",
		"turns": 2,
		"xp": 0,
		"party_hp": [{"index": 0, "hp": 0, "max_hp": 20}],
	}
	gc.call("apply_battle_result", result)
	assert_int(run.party.size()).is_equal(party_size)  # nobody buried
	assert_int(MortalityServiceScript.graveyard_of(gc.call("run")).size()).is_equal(0)
	assert_int(int((run.party[0] as Dictionary)["hp"])).is_equal(1)  # scarred survivor
	gc.queue_free()


func test_results_without_party_hp_kill_nobody() -> void:
	# Auto/boss round-trips carry no party_hp fold — the death rule must not fire on them.
	var gc := _make_controller()
	var run: RunContext = gc.call("new_run", TEST_SEED)
	var party_size := run.party.size()
	gc.call("apply_battle_result", {"player_won": false, "winner": "enemy", "xp": 0})
	assert_int(run.party.size()).is_equal(party_size)
	assert_int(MortalityServiceScript.graveyard_of(gc.call("run")).size()).is_equal(0)
	gc.queue_free()


func test_dead_creatures_are_excluded_from_the_next_battle() -> void:
	var gc := _make_controller()
	var run: RunContext = gc.call("new_run", TEST_SEED)
	var catalog: SpeciesCatalog = gc.call("catalog")
	# A defensive is_dead entry (the rule REMOVES the dead; the factories still refuse one).
	var roster: Array = run.party.duplicate(true)
	(roster[1] as Dictionary)["is_dead"] = true
	var skill_built: Dictionary = SkillMonFactoryScript.team_with_source(roster, catalog)
	assert_int((skill_built["team"] as Array).size()).is_equal(roster.size() - 1)
	var mons: Array = MonFactoryScript.team_from_creatures(roster, catalog)
	assert_int(mons.size()).is_equal(roster.size() - 1)
	gc.queue_free()


func test_graveyard_persists_through_save_and_continue() -> void:
	var gc := _make_controller()
	var run: RunContext = gc.call("new_run", TEST_SEED)
	gc.call("apply_battle_result", _lost_result(run.party.size()))
	var expected := MortalityServiceScript.graveyard_of(gc.call("run")).size()
	assert_bool(bool(gc.call("save_run"))).is_true()
	var gc2 := _make_controller()
	assert_bool(bool(gc2.call("continue_run"))).is_true()
	assert_int(MortalityServiceScript.graveyard_of(gc2.call("run")).size()).is_equal(expected)
	# The memorial parts are in the RELOADED inventory too ("death funds creation" persists).
	var inv: InventoryAdapter = gc2.call("inventory")
	assert_bool(inv.ingredient_items().size() > 0).is_true()
	gc.queue_free()
	gc2.queue_free()


func test_last_light_reaims_the_active_creature_flag() -> void:
	var gc := _make_controller()
	var run: RunContext = gc.call("new_run", TEST_SEED)
	assert_int(run.party.size()).is_greater_equal(3)
	# Lead the party from the LAST slot, then wipe: the spared lead's index shifts left.
	var last := run.party.size() - 1
	assert_bool(bool(gc.call("set_active_creature", last))).is_true()
	var lead: Dictionary = run.party[last]
	gc.call("apply_battle_result", _lost_result(run.party.size()))
	assert_int(run.party.size()).is_equal(1)
	assert_bool(is_same(run.party[0], lead)).is_true()
	assert_int(int(gc.call("active_creature_index"))).is_equal(0)
	gc.queue_free()
