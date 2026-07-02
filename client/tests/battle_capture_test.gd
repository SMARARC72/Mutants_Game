extends GdUnitTestSuite
## Phase 5 · Slice 2 — CAPTURE flow DoD, headless.
##   * capture SUCCESS adds exactly ONE correctly-shaped creature_instance to the party + ends the
##     battle as a catch;
##   * capture FAILURE consumes the player's turn (the enemy then acts) + adds NOTHING;
##   * GEAR modifies the capture chance (asserted via LootEngine, not a re-implementation);
##   * the capture ROLL is canonical (same battle_seed => same roll/outcome);
##   * the caught creature is shaped to the RunContext.party / creature_instances contract.
## The capture seeds are CHOSEN deterministically: the first canonical capture-substream draw for
## battle_seed 1 is ~0.0539 (< the full-HP T1 befriend chance 0.245 => SUCCESS); for battle_seed 2 it
## is ~0.9618 (> 0.245 => FAILURE). (Verified by porting PCG32 + capture_chance offline.)

const GameControllerScript := preload("res://application/game/game_controller.gd")
const FakeDalScript := preload("res://infrastructure/dal/fake_dal.gd")
const BattleScreenScript := preload("res://presentation/battle/battle_screen.gd")
const CaptureMomentScript := preload("res://presentation/battle/capture_moment.gd")
const CaptureServiceScript := preload("res://application/battle/capture_service.gd")
const MonFactoryScript := preload("res://application/battle/mon_factory.gd")
const EncounterCatalogScript := preload("res://application/overworld/encounter_catalog.gd")

const TEST_SEED := 0xBA771E5
const CAPTURE_SUCCESS_SEED := 1  # first capture roll ~0.0539 < 0.245
const CAPTURE_FAIL_SEED := 2  # first capture roll ~0.9618 > 0.245

var _catalog: SpeciesCatalog


func before() -> void:
	_catalog = SpeciesCatalog.new()


func _make_game(battle_seed: int) -> Node:
	var gc: Node = GameControllerScript.new()
	add_child(gc)
	gc.call("configure", FakeDalScript.make())
	var run: RunContext = gc.call("new_run", TEST_SEED)
	# A single wild T1 target (full HP) so the capture chance is the known 0.245.
	run.flags["pending_battle"] = {
		"enemy_party": [{"species_id": "SB33"}],
		"battle_seed": battle_seed,
		"is_wild": true,
	}
	return gc


func _make_screen(gc: Node) -> Control:
	var screen: Control = BattleScreenScript.new()
	screen.call("set_game", gc)
	screen.call("set_auto_run", false)
	add_child(screen)
	return screen


# --- CaptureService unit: chance, gear, roll, instance shape ----------------------------------- #


func _full_hp_target() -> BattleEngine.Mon:
	return MonFactoryScript.from_creature({"species_id": "SB33"}, _catalog)


func test_capture_chance_is_gear_modified_via_loot_engine() -> void:
	var target := _full_hp_target()
	var species: SpeciesData = _catalog.get_by_id("SB33")
	var bare := CaptureServiceScript.chance_for(target, species, [])
	var geared := CaptureServiceScript.chance_for(target, species, ["Beastcaller's Horn"])
	# Gear raises the chance (Beastcaller's Horn capture +0.25). The exact numbers are the oracle's.
	assert_float(geared).is_greater(bare)
	# Cross-check against LootEngine directly (single source of truth, NOT re-implemented here).
	var expected_bare := LootEngine.capture_chance("befriend", species.tier, 1.0, 0.0, [])
	assert_float(bare).is_equal_approx(expected_bare, 1e-9)
	var expected_geared := LootEngine.capture_chance(
		"befriend", species.tier, 1.0, 0.0, ["Beastcaller's Horn"]
	)
	assert_float(geared).is_equal_approx(expected_geared, 1e-9)


func test_capture_roll_is_canonical() -> void:
	var target_a := _full_hp_target()
	var target_b := _full_hp_target()
	var species: SpeciesData = _catalog.get_by_id("SB33")
	var a := CaptureServiceScript.new(CAPTURE_SUCCESS_SEED).attempt(target_a, species, [])
	var b := CaptureServiceScript.new(CAPTURE_SUCCESS_SEED).attempt(target_b, species, [])
	# Same seed => identical roll + outcome (canonical capture sub-stream).
	assert_float(float(a["roll"])).is_equal_approx(float(b["roll"]), 1e-12)
	assert_bool(bool(a["success"])).is_equal(bool(b["success"]))
	assert_bool(bool(a["success"])).is_true()  # the chosen seed succeeds.


func test_caught_creature_instance_is_well_shaped() -> void:
	var target := _full_hp_target()
	var species: SpeciesData = _catalog.get_by_id("SB33")
	var inst := CaptureServiceScript.to_creature_instance(target, species)
	# Mirrors the creature_instances columns + RunContext.party shape (data only).
	assert_str(str(inst["species_id"])).is_equal("SB33")
	assert_bool(inst.has("genome")).is_true()
	assert_bool(inst.has("expression")).is_true()
	assert_bool(inst.has("lineage")).is_true()
	assert_bool(bool(inst["is_dead"])).is_false()
	assert_bool(bool((inst["lineage"] as Dictionary).get("captured", false))).is_true()
	# It rebuilds into a valid Mon (the party-add round-trips back into battle).
	var rebuilt := MonFactoryScript.from_creature(inst, _catalog)
	assert_object(rebuilt).is_not_null()


# --- end-to-end through the screen: success adds one, failure adds none ------------------------- #


func test_capture_success_adds_one_creature_and_ends_as_caught() -> void:
	var gc := _make_game(CAPTURE_SUCCESS_SEED)
	var screen := _make_screen(gc)
	var run: RunContext = gc.call("run")
	var party_before := run.party.size()
	screen.call("run_pending_battle")  # pumps to the first player turn
	var step: Dictionary = screen.call("player_capture")
	# The capture succeeded and ended the battle as a catch.
	assert_str(str(step.get("kind", ""))).is_equal("ended")
	var result: Dictionary = screen.call("result")
	assert_str(str(result["reason"])).is_equal("caught")
	assert_bool(bool(result["player_won"])).is_true()
	# Exactly ONE creature_instance was added to the party.
	assert_int(run.party.size()).is_equal(party_before + 1)
	var added: Dictionary = run.party[run.party.size() - 1]
	assert_str(str(added["species_id"])).is_equal("SB33")
	assert_bool(bool((added["lineage"] as Dictionary).get("captured", false))).is_true()
	screen.queue_free()
	gc.queue_free()


func test_capture_failure_consumes_turn_and_adds_nothing() -> void:
	var gc := _make_game(CAPTURE_FAIL_SEED)
	var screen := _make_screen(gc)
	var run: RunContext = gc.call("run")
	var party_before := run.party.size()
	screen.call("run_pending_battle")
	var step: Dictionary = screen.call("player_capture")
	# Failure does NOT end as a catch — the player's turn was spent and the pump advanced (the enemy
	# acts, then the battle returns to a player turn or ends). Nothing was added to the party.
	assert_str(str(step.get("kind", ""))).is_not_equal("ended")
	var battle: Variant = screen.call("battle")
	var last: Dictionary = battle.call("last_capture")
	assert_bool(bool(last["success"])).is_false()
	assert_int(run.party.size()).is_equal(party_before)
	# A capture roll WAS drawn (the turn was genuinely consumed by the failed attempt).
	assert_bool(last.has("roll")).is_true()
	screen.queue_free()
	gc.queue_free()


func test_capture_success_seed_is_deterministic_end_to_end() -> void:
	# Re-running the same (seed, capture-on-first-turn) choice yields the same caught species + party.
	var gc_a := _make_game(CAPTURE_SUCCESS_SEED)
	var screen_a := _make_screen(gc_a)
	screen_a.call("run_pending_battle")
	screen_a.call("player_capture")
	var caught_a: Dictionary = (gc_a.call("run") as RunContext).party[-1]

	var gc_b := _make_game(CAPTURE_SUCCESS_SEED)
	var screen_b := _make_screen(gc_b)
	screen_b.call("run_pending_battle")
	screen_b.call("player_capture")
	var caught_b: Dictionary = (gc_b.call("run") as RunContext).party[-1]

	assert_str(str(caught_a["species_id"])).is_equal(str(caught_b["species_id"]))
	screen_a.queue_free()
	screen_b.queue_free()
	gc_a.queue_free()
	gc_b.queue_free()


# --- W11 "Capture Becomes a Moment" ------------------------------------------------------------- #


func test_live_odds_accessor_is_pure_and_matches_the_oracle() -> void:
	# Screen A reads the LIVE odds several times BEFORE capturing; screen B never reads them.
	# If chance_for drew from the canonical capture sub-stream, A's roll would drift off B's.
	var gc_a := _make_game(CAPTURE_SUCCESS_SEED)
	var screen_a := _make_screen(gc_a)
	screen_a.call("run_pending_battle")
	var chance := 0.0
	for _i in 5:
		chance = float((screen_a.call("capture_readout") as Dictionary)["chance"])
	# The shown % IS the oracle number (full-HP T1 befriend, no gear — single source of truth).
	var species: SpeciesData = _catalog.get_by_id("SB33")
	var expected := LootEngine.capture_chance("befriend", species.tier, 1.0, 0.0, [])
	assert_float(chance).is_equal_approx(expected, 1e-9)
	screen_a.call("player_capture")
	var roll_a := float((screen_a.call("battle").call("last_capture") as Dictionary)["roll"])

	var gc_b := _make_game(CAPTURE_SUCCESS_SEED)
	var screen_b := _make_screen(gc_b)
	screen_b.call("run_pending_battle")
	screen_b.call("player_capture")
	var roll_b := float((screen_b.call("battle").call("last_capture") as Dictionary)["roll"])

	# The canonical capture stream is UNCHANGED by reading odds: byte-identical roll either way.
	assert_float(roll_a).is_equal_approx(roll_b, 1e-12)
	screen_a.queue_free()
	screen_b.queue_free()
	gc_a.queue_free()
	gc_b.queue_free()


func test_capture_button_advertises_the_live_odds() -> void:
	var gc := _make_game(CAPTURE_SUCCESS_SEED)
	var screen := _make_screen(gc)
	screen.call("run_pending_battle")  # pumps to the first player turn (the menu builds)
	var btn := screen.find_child("CaptureButton", true, false) as Button
	assert_object(btn).is_not_null()
	var chance := float((screen.call("capture_readout") as Dictionary)["chance"])
	assert_str(btn.text).is_equal("Capture — %d%%" % roundi(chance * 100.0))
	screen.queue_free()
	gc.queue_free()


func test_staged_attempt_records_phases_success_dissolves() -> void:
	var gc := _make_game(CAPTURE_SUCCESS_SEED)
	var screen := _make_screen(gc)
	screen.call("run_pending_battle")
	screen.call("player_capture")
	var phases: Array = (screen.call("capture_readout") as Dictionary)["phases"]
	# close -> 1..3 tension pulses (scaled by |roll - chance|) -> dissolve-into-the-sigil.
	assert_str(str(phases[0])).is_equal("close")
	assert_str(str(phases[-1])).is_equal("dissolve")
	var pulses := phases.size() - 2
	assert_int(pulses).is_between(1, 3)
	var cap: Dictionary = screen.call("battle").call("last_capture")
	var expected := CaptureMomentScript.pulse_count(float(cap["chance"]), float(cap["roll"]))
	assert_int(pulses).is_equal(expected)
	screen.queue_free()
	gc.queue_free()


func test_staged_attempt_records_phases_failure_shatters() -> void:
	var gc := _make_game(CAPTURE_FAIL_SEED)
	var screen := _make_screen(gc)
	screen.call("run_pending_battle")
	screen.call("player_capture")
	var readout: Dictionary = screen.call("capture_readout")
	var phases: Array = readout["phases"]
	assert_str(str(phases[0])).is_equal("close")
	assert_str(str(phases[-1])).is_equal("shatter")
	# The failed attempt shows NO result card (success only).
	assert_object(readout["card"]).is_null()
	screen.queue_free()
	gc.queue_free()


func test_result_card_state_machine_in_instant_mode() -> void:
	var gc := _make_game(CAPTURE_SUCCESS_SEED)
	var screen := _make_screen(gc)
	screen.call("run_pending_battle")
	screen.call("player_capture")
	var card: Control = (screen.call("capture_readout") as Dictionary)["card"]
	assert_object(card).is_not_null()
	# Instant/headless: the card lands fully COMPLETE — no reveal to wait on, no awaits taken.
	assert_str(str(card.call("state"))).is_equal("complete")
	assert_bool(bool(card.call("is_active"))).is_true()
	# The card carries the plate + name + sigil + authored line surfaces.
	var name_label := card.find_child("CardName", true, false) as Label
	assert_object(name_label).is_not_null()
	assert_int(name_label.visible_characters).is_equal(-1)  # fully revealed
	assert_object(card.find_child("CardPlate", true, false)).is_not_null()
	assert_object(card.find_child("CardSigil", true, false)).is_not_null()
	# ANY input dismisses; the battle flow beneath (banner/rewards) already ran unchanged.
	card.call("advance")
	assert_str(str(card.call("state"))).is_equal("dismissed")
	assert_bool(bool(card.call("is_active"))).is_false()
	var result: Dictionary = screen.call("result")
	assert_str(str(result["reason"])).is_equal("caught")
	screen.queue_free()
	gc.queue_free()


func test_first_capture_teach_latches_once_via_run_flags() -> void:
	var gc: Node = GameControllerScript.new()
	add_child(gc)
	gc.call("configure", FakeDalScript.make())
	var run: RunContext = gc.call("new_run", TEST_SEED)
	# Not weakened enough / not wild: never fires.
	assert_bool(CaptureMomentScript.should_teach(run, true, 0.9)).is_false()
	assert_bool(CaptureMomentScript.should_teach(run, false, 0.3)).is_false()
	# The first weakened wild qualifies; the latch fires exactly ONCE (run.flags one-shot).
	assert_bool(CaptureMomentScript.should_teach(run, true, 0.3)).is_true()
	assert_bool(CaptureMomentScript.latch_teach(run)).is_true()
	assert_bool(bool(run.flags.get("capture_teach_seen", false))).is_true()
	assert_bool(CaptureMomentScript.latch_teach(run)).is_false()
	assert_bool(CaptureMomentScript.should_teach(run, true, 0.3)).is_false()
	# A run that already CAUGHT something never teaches (mercy already understood).
	var run_b: RunContext = gc.call("new_run", TEST_SEED + 1)
	run_b.party.append(
		CaptureServiceScript.to_creature_instance_named("Stray", _catalog.get_by_id("SB33"))
	)
	assert_bool(CaptureMomentScript.has_capture(run_b)).is_true()
	assert_bool(CaptureMomentScript.should_teach(run_b, true, 0.3)).is_false()
	gc.queue_free()
