extends GdUnitTestSuite
## Wave 5 — LAB & FACTORY TRUTH: hybrids fight + awakenings are felt.
##   * a committed spliced hybrid (species_id == "") builds a non-null BattleEngine.Mon AND a non-null
##     AbilityContainer from the oracle numbers cached at lab commit (stats_cached) — the factories
##     re-derive the block through the SAME oracle call LabEngine used, so it EQUALS the cache;
##   * the hybrid DEALS DAMAGE in an interactive skill-session step (the splice payoff is real);
##   * the party sheet (CreatureSheet) surfaces the hybrid's real force/tier/HP from the cache;
##   * the hybrid portrait helper is deterministic: dominant-parent plate + a corruption tint keyed
##     off lineage.rng_seed_tag (LOCAL hash — presentation only, never the canonical streams);
##   * AWAKENINGS FELT: expression/gene_bonus compose into battle stats via LevelEngine.current_stats
##     (the oracle's growth model) — an awakened creature enters battle visibly stronger than a fresh
##     capture, and a growth-less dict still gets the full ceiling (back-compat).

const GameControllerScript := preload("res://application/game/game_controller.gd")
const FakeDalScript := preload("res://infrastructure/dal/fake_dal.gd")
const LabScreenScript := preload("res://presentation/lab/lab_screen.gd")
const LegalitySolverScript := preload("res://infrastructure/lab/legality_solver.gd")
const MonFactoryScript := preload("res://application/battle/mon_factory.gd")
const SkillMonFactoryScript := preload("res://application/battle/skill_mon_factory.gd")
const BattleSessionScript := preload("res://application/battle/battle_session.gd")
const SkillBattleControllerScript := preload("res://application/battle/skill_battle_controller.gd")
const CreatureSheetScript := preload("res://application/game/creature_sheet.gd")

const TEST_SEED := 0x1AB5EED
const BATTLE_SEED := 0x5117E1

# SB07 Leaf-hare (Eros/Gaia T1) x AD10 Thornmane (Eros/Gaia T2) — the known-LEGAL fuse the lab suite
# uses; the hybrid's Gaia pool carries a damage verb (Boulder Smash), so it can strike.
const PARTY_LEGAL := [{"species_id": "SB07"}, {"species_id": "AD10"}]

# --- harness ------------------------------------------------------------------------------------ #


## Drive a REAL lab commit (the same harness lab_screen_test uses) and return handles:
## { "gc": Node (queue_free it), "hybrid": Dictionary (the newborn creature_instance) }.
func _commit_hybrid() -> Dictionary:
	var gc: Node = GameControllerScript.new()
	add_child(gc)
	gc.call("configure", FakeDalScript.make())
	var run: RunContext = gc.call("new_run", TEST_SEED)
	run.party = PARTY_LEGAL.duplicate(true)
	var screen: Control = LabScreenScript.new()
	screen.call("set_game", gc)
	screen.call("set_auto_build", false)
	add_child(screen)
	screen.call("build")
	screen.call("select_op", "fuse")
	screen.call("set_creature_a", 0)
	screen.call("set_creature_b", 1)
	var res: Dictionary = screen.call("commit")
	assert_int(int(res["verdict"])).is_equal(LegalitySolverScript.Verdict.LEGAL)
	screen.queue_free()
	var hybrid: Dictionary = run.party[run.party.size() - 1]
	return {"gc": gc, "hybrid": hybrid}


## The first DAMAGE skill in a combatant's kit (Strike/Drain/Gambit/Hex), else "" (pure support).
func _first_damage_skill(actor: Variant) -> String:
	if actor == null:
		return ""
	for skill: String in (actor as AbilityContainer).abilities():
		var verb := SkillBattleControllerScript.verb_of(skill)
		if not SkillBattleControllerScript.is_support_verb(verb):
			return skill
	return ""


# --- hybrids fight ------------------------------------------------------------------------------ #


func test_committed_hybrid_builds_a_mon_from_cached_stats() -> void:
	var setup := _commit_hybrid()
	var gc: Node = setup["gc"]
	var hybrid: Dictionary = setup["hybrid"]
	var catalog: SpeciesCatalog = gc.call("catalog")
	var cached: Dictionary = hybrid["stats_cached"]
	var mon: BattleEngine.Mon = MonFactoryScript.from_creature(hybrid, catalog)
	assert_object(mon).is_not_null()
	assert_int(mon.maxhp).is_greater(0)
	# The factory rebuilt the block through the SAME oracle inputs LabEngine cached — verbatim equal.
	assert_int(mon.maxhp).is_equal(int(cached["hp"]))
	assert_str(mon.prim).is_equal(str(cached["prim"]))
	assert_str(mon.sec).is_equal(str(cached["sec"]))
	var cached_stats: Dictionary = cached["stats"]
	for k in cached_stats:
		assert_int(int(mon.stats[k])).is_equal(int(cached_stats[k]))
	gc.queue_free()


func test_committed_hybrid_builds_an_ability_container_with_a_kit() -> void:
	var setup := _commit_hybrid()
	var gc: Node = setup["gc"]
	var hybrid: Dictionary = setup["hybrid"]
	var catalog: SpeciesCatalog = gc.call("catalog")
	var cached: Dictionary = hybrid["stats_cached"]
	var ac: AbilityContainer = SkillMonFactoryScript.from_creature(hybrid, catalog)
	assert_object(ac).is_not_null()
	assert_int(ac.max_hp()).is_greater(0)
	assert_int(ac.max_hp()).is_equal(int(cached["hp"]))
	assert_str(ac.primary_force()).is_equal(str(cached["prim"]))
	# The kit derives from the cached forces via the same KitFactory policy every species uses.
	assert_bool((ac.abilities() as Array).is_empty()).is_false()
	gc.queue_free()


func test_malformed_hybrid_without_cache_still_dead_ends_safely() -> void:
	var catalog := SpeciesCatalog.new()
	var broken := {"species_id": "", "nickname": "Ghost"}
	assert_object(MonFactoryScript.from_creature(broken, catalog)).is_null()
	assert_object(SkillMonFactoryScript.from_creature(broken, catalog)).is_null()


func test_hybrid_deals_damage_in_a_skill_session_step() -> void:
	var setup := _commit_hybrid()
	var gc: Node = setup["gc"]
	var hybrid: Dictionary = setup["hybrid"]
	var session: BattleSession = BattleSessionScript.new(gc.call("catalog"))
	var battle = session.begin_skill_interactive([hybrid], [{"species_id": "SB33"}], BATTLE_SEED)
	assert_object(battle).is_not_null()
	var enemy: AbilityContainer = battle.enemy_team()[0]
	var dealt := false
	var step: Dictionary = battle.advance()
	var guard := 0
	while str(step.get("kind", "")) != "ended" and guard < 80:
		guard += 1
		if str(step.get("kind", "")) == "await_player":
			var actor: Variant = step.get("actor")
			var skill := _first_damage_skill(actor)
			assert_str(skill).is_not_empty()  # the hybrid's kit carries a damage verb
			step = battle.use_skill(skill, enemy)
			# The strike landed if the enemy's HP dropped below its ceiling (death counts: 0 < max).
			if enemy.hp() < enemy.max_hp():
				dealt = true
				break
		else:
			step = battle.advance()
	assert_bool(dealt).is_true()
	gc.queue_free()


# --- party shows truth ---------------------------------------------------------------------------- #


func test_creature_sheet_surfaces_hybrid_force_tier_hp_from_cache() -> void:
	var setup := _commit_hybrid()
	var gc: Node = setup["gc"]
	var hybrid: Dictionary = setup["hybrid"]
	var catalog: SpeciesCatalog = gc.call("catalog")
	var cached: Dictionary = hybrid["stats_cached"]
	assert_int(CreatureSheetScript.hp_of(hybrid, catalog)).is_equal(int(cached["hp"]))
	var ident: Dictionary = CreatureSheetScript.identity_of(hybrid, catalog)
	assert_str(str(ident["prim"])).is_equal(str(cached["prim"]))
	assert_str(str(ident["tier"])).is_equal(str(cached["tier"]))
	# Effective stats compose at the hybrid's expression 1.0 — the cached oracle block verbatim.
	var eff: Dictionary = CreatureSheetScript.effective_stats(hybrid, catalog)
	var cached_stats: Dictionary = cached["stats"]
	for k in cached_stats:
		assert_int(int(eff[k])).is_equal(int(cached_stats[k]))
	gc.queue_free()


func test_hybrid_portrait_is_deterministic_and_tinted() -> void:
	var setup := _commit_hybrid()
	var hybrid: Dictionary = setup["hybrid"]
	# Dominant-parent plate identity resolved + recorded at commit (SB07/AD10 line).
	assert_str(PortraitUtil.portrait_species_of(hybrid)).is_not_empty()
	# The corruption tint is deterministic from lineage.rng_seed_tag (LOCAL hash) and never neutral.
	var tint_a: Color = PortraitUtil.creature_tint(hybrid)
	var tint_b: Color = PortraitUtil.creature_tint(hybrid.duplicate(true))
	assert_bool(tint_a == tint_b).is_true()
	assert_bool(tint_a == Color.WHITE).is_false()
	# A plain species creature stays untinted.
	assert_bool(PortraitUtil.creature_tint({"species_id": "SB07"}) == Color.WHITE).is_true()
	(setup["gc"] as Node).queue_free()


# --- awakenings felt ------------------------------------------------------------------------------ #


func test_awakened_creature_enters_battle_stronger_than_fresh_capture() -> void:
	var catalog := SpeciesCatalog.new()
	var plain := {"species_id": "SB07", "nickname": "Ceiling"}
	var fresh := {"species_id": "SB07", "nickname": "Fresh", "expression": 0.30}
	var awakened := {
		"species_id": "SB07",
		"nickname": "Awake",
		"expression": 0.66,
		"gene_bonus": {"Spike": 0.12},
		"awakenings": 3,
	}
	var mon_plain: BattleEngine.Mon = MonFactoryScript.from_creature(plain, catalog)
	var mon_fresh: BattleEngine.Mon = MonFactoryScript.from_creature(fresh, catalog)
	var mon_awake: BattleEngine.Mon = MonFactoryScript.from_creature(awakened, catalog)
	assert_object(mon_plain).is_not_null()
	assert_object(mon_fresh).is_not_null()
	assert_object(mon_awake).is_not_null()

	# Back-compat: a growth-less dict gets the FULL engine ceiling (canonical battles unchanged).
	var species: SpeciesData = catalog.get_by_id("SB07")
	var cls: String = species.species_class if species.species_class != "" else "organic"
	var ceiling := StatEngine.stat_block(
		species.force_primary, species.force_secondary, species.rank, species.tier, cls
	)
	var ceiling_stats: Dictionary = ceiling["stats"]
	for k in ceiling_stats:
		assert_int(int(mon_plain.stats[k])).is_equal(int(ceiling_stats[k]))

	# The composed stats ARE the oracle's growth model (LevelEngine.current_stats) — no new math.
	var expected_fresh := LevelEngine.current_stats(ceiling_stats, 0.30, {})
	for k in expected_fresh:
		assert_int(int(mon_fresh.stats[k])).is_equal(int(expected_fresh[k]))

	# AWAKENINGS FELT: every stat >= the fresh capture's, strictly greater in total (and on the
	# gene-boosted pole in particular).
	var sum_fresh := 0
	var sum_awake := 0
	for k in expected_fresh:
		sum_fresh += int(mon_fresh.stats[k])
		sum_awake += int(mon_awake.stats[k])
		assert_int(int(mon_awake.stats[k])).is_greater_equal(int(mon_fresh.stats[k]))
	assert_int(sum_awake).is_greater(sum_fresh)
	assert_int(int(mon_awake.stats["Spike"])).is_greater(int(mon_fresh.stats["Spike"]))

	# HP stays ceiling-derived (the growth model scales pole stats, not HP).
	assert_int(mon_fresh.maxhp).is_equal(int(ceiling["hp"]))

	# The SKILL factory composes identically (both battle paths tell the same truth).
	var ac_fresh: AbilityContainer = SkillMonFactoryScript.from_creature(fresh, catalog)
	var ac_awake: AbilityContainer = SkillMonFactoryScript.from_creature(awakened, catalog)
	assert_int(ac_awake.stat("Spike")).is_greater(ac_fresh.stat("Spike"))


func test_persisted_wounds_carry_into_the_next_battle() -> void:
	# FIGHTS LEAVE MARKS (Codex #54 P2): apply_battle_result writes hp back onto the
	# creature dict; BOTH factories must rebuild the combatant AT that hp (clamped to
	# [1, max]), not at the full ceiling — else the consequence evaporates between fights.
	var gc: Node = GameControllerScript.new()
	gc.call("configure", FakeDalScript.make())
	var run: RunContext = gc.call("new_run", TEST_SEED)
	var catalog: SpeciesCatalog = gc.call("catalog")
	var wounded: Dictionary = (run.party[0] as Dictionary).duplicate(true)

	var full_mon: BattleEngine.Mon = MonFactoryScript.from_creature(wounded, catalog)
	var ceiling_hp := full_mon.maxhp
	wounded["hp"] = int(ceiling_hp * 0.4)
	wounded["max_hp"] = ceiling_hp

	var mon: BattleEngine.Mon = MonFactoryScript.from_creature(wounded, catalog)
	assert_int(mon.hp).is_equal(int(ceiling_hp * 0.4))
	assert_int(mon.maxhp).is_equal(ceiling_hp)
	var ac: AbilityContainer = SkillMonFactoryScript.from_creature(wounded, catalog)
	assert_int(ac.hp()).is_equal(int(ceiling_hp * 0.4))

	# A 0-HP survivor floors at 1 (playable until permadeath owns death — plan W18);
	# a dict WITHOUT the key keeps the full-HP rebuild (fresh captures, wild enemies).
	wounded["hp"] = 0
	assert_int((MonFactoryScript.from_creature(wounded, catalog) as BattleEngine.Mon).hp).is_equal(
		1
	)
	(
		assert_int((SkillMonFactoryScript.from_creature(wounded, catalog) as AbilityContainer).hp())
		. is_equal(1)
	)
	var fresh: Dictionary = (run.party[0] as Dictionary).duplicate(true)
	fresh.erase("hp")
	assert_int((MonFactoryScript.from_creature(fresh, catalog) as BattleEngine.Mon).hp).is_equal(
		ceiling_hp
	)
	gc.queue_free()
