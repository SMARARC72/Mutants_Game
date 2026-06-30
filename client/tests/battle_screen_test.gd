extends GdUnitTestSuite
## Phase 10 · Slice 3 — INTERACTIVE SKILL Battle screen DoD, driven HEADLESSLY.
##   * the battle screen reads the pending battle GameController stashed (the overworld -> battle
##     hand-off) and builds an INTERACTIVE SKILL session (player drives side A; enemy is AI-driven);
##   * a player turn yields an await_player step; player_use_skill / capture / flee drive the battle;
##   * a scripted player-choice sequence is DETERMINISTIC (same seed+choices => identical transcript);
##   * the result is applied back to the run (xp on a win) and the pending battle is cleared;
##   * the screen builds its themed UI (banner + party/enemy rows + a per-skill action menu + transcript).
## Drives a CODE-INSTANTIATED GameController + battle screen with an injected FakeDal.

const GameControllerScript := preload("res://application/game/game_controller.gd")
const FakeDalScript := preload("res://infrastructure/dal/fake_dal.gd")
const BattleScreenScript := preload("res://presentation/battle/battle_screen.gd")
const SkillBattleControllerScript := preload("res://application/battle/skill_battle_controller.gd")

const TEST_SEED := 0xBA771E5
const BATTLE_SEED := 0x5117E1

# A weak enemy team so the player (3-strong starter party) reliably resolves the fight by acting.
const ENEMY_PARTY := [{"species_id": "SB33"}, {"species_id": "SB14"}]


func _make_game_with_pending_battle(battle_seed: int = BATTLE_SEED) -> Node:
	var gc: Node = GameControllerScript.new()
	add_child(gc)
	gc.call("configure", FakeDalScript.make())
	var run: RunContext = gc.call("new_run", TEST_SEED)
	run.flags["pending_battle"] = {
		"enemy_party": ENEMY_PARTY.duplicate(true),
		"battle_seed": battle_seed,
		"is_wild": true,
	}
	return gc


## A battle screen wired to `gc` with auto-run DISABLED so _ready does NOT build the battle; the test
## drives run_pending_battle() once explicitly. Injection wins because set_game runs before add_child.
func _make_screen(gc: Node) -> Control:
	var screen: Control = BattleScreenScript.new()
	screen.call("set_game", gc)
	screen.call("set_auto_run", false)
	add_child(screen)
	return screen


## The first DAMAGE skill in a combatant's kit (Strike/Drain/Gambit/Hex), else "" (pure support).
func _first_damage_skill(actor: Variant) -> String:
	if actor == null:
		return ""
	for skill: String in (actor as AbilityContainer).abilities():
		var verb := SkillBattleControllerScript.verb_of(skill)
		if not SkillBattleControllerScript.is_support_verb(verb):
			return skill
	return ""


## Drive the interactive skill battle to its end: on each player turn use the actor's first damage skill
## on the first enemy (or its first skill if it's a pure support). Returns the final result. Bounded.
func _play_skills(screen: Control) -> Dictionary:
	var step: Dictionary = screen.call("run_pending_battle")
	var guard := 0
	while str(step.get("kind", "")) != "ended" and guard < 300:
		guard += 1
		if str(step.get("kind", "")) == "await_player":
			var actor: Variant = step.get("actor")
			var skill := _first_damage_skill(actor)
			if skill == "":
				var kit: Array = (actor as AbilityContainer).abilities() if actor != null else []
				skill = str(kit[0]) if not kit.is_empty() else ""
			if skill == "":
				break
			step = screen.call("player_use_skill", skill, 0)
		else:
			break
	return screen.call("result")


func test_battle_starts_interactive_and_awaits_the_player() -> void:
	var gc := _make_game_with_pending_battle()
	var screen := _make_screen(gc)
	var step: Dictionary = screen.call("run_pending_battle")
	# The first decision point is a player turn (side A acts) — the battle does NOT auto-resolve.
	assert_str(str(step.get("kind", ""))).is_equal("await_player")
	assert_object(step.get("actor")).is_not_null()
	# The pending battle is consumed (loop boundary cleared) the moment the session is built.
	var run: RunContext = gc.call("run")
	assert_bool(run.flags.has("pending_battle")).is_false()
	screen.queue_free()
	gc.queue_free()


func test_playing_to_the_end_returns_a_result_and_applies_it() -> void:
	var gc := _make_game_with_pending_battle()
	var screen := _make_screen(gc)
	var run: RunContext = gc.call("run")
	var essence_before := run.essence
	var result := _play_skills(screen)
	assert_bool(bool(result["valid"])).is_true()
	assert_str(str(result["winner"])).is_not_empty()
	assert_int((result["transcript"] as Array).size()).is_greater(0)
	# Outcome flag recorded for the overworld to read on return.
	assert_bool(run.flags.has("last_battle_won")).is_true()
	# xp folds into essence on a win (economy preserved); unchanged on a loss.
	if bool(result["player_won"]):
		assert_int(run.essence).is_equal(essence_before + int(result["xp"]))
	else:
		assert_int(run.essence).is_equal(essence_before)
	screen.queue_free()
	gc.queue_free()


func test_scripted_choices_are_deterministic() -> void:
	# Same (seed, teams, player-choice sequence) => byte-identical transcript + result.
	var gc_a := _make_game_with_pending_battle()
	var screen_a := _make_screen(gc_a)
	var result_a := _play_skills(screen_a)

	var gc_b := _make_game_with_pending_battle()
	var screen_b := _make_screen(gc_b)
	var result_b := _play_skills(screen_b)

	assert_str(str(result_a["winner"])).is_equal(str(result_b["winner"]))
	assert_int(int(result_a["turns"])).is_equal(int(result_b["turns"]))
	assert_str(str(result_a["transcript"])).is_equal(str(result_b["transcript"]))
	screen_a.queue_free()
	screen_b.queue_free()
	gc_a.queue_free()
	gc_b.queue_free()


func test_screen_builds_interactive_ui() -> void:
	var gc := _make_game_with_pending_battle()
	var screen := _make_screen(gc)
	screen.call("run_pending_battle")
	# The code-built UI exists: banner, party + enemy rows, an action menu, and a transcript log.
	assert_object(screen.find_child("ResultBanner", true, false)).is_not_null()
	assert_object(screen.find_child("TranscriptLog", true, false)).is_not_null()
	assert_object(screen.find_child("PartyRows", true, false)).is_not_null()
	assert_object(screen.find_child("EnemyRows", true, false)).is_not_null()
	# On a player turn the action menu is populated with at least one SKILL affordance (the kit's bar).
	assert_object(screen.find_child("SkillButton0", true, false)).is_not_null()
	# Wild battle => Capture + Flee are offered too.
	assert_object(screen.find_child("CaptureButton", true, false)).is_not_null()
	assert_object(screen.find_child("FleeButton", true, false)).is_not_null()
	screen.queue_free()
	gc.queue_free()


func test_flee_ends_the_battle_with_no_xp() -> void:
	var gc := _make_game_with_pending_battle()
	var screen := _make_screen(gc)
	var run: RunContext = gc.call("run")
	var essence_before := run.essence
	screen.call("run_pending_battle")
	screen.call("player_flee")
	var result: Dictionary = screen.call("result")
	assert_str(str(result["winner"])).is_equal("fled")
	assert_int(int(result["xp"])).is_equal(0)
	assert_int(run.essence).is_equal(essence_before)
	screen.queue_free()
	gc.queue_free()


func test_reentrant_run_pending_battle_is_a_no_op() -> void:
	var gc := _make_game_with_pending_battle()
	var screen := _make_screen(gc)
	var first: Dictionary = screen.call("run_pending_battle")
	# A stray second call finds no pending flag and returns the cached step (no rebuild, no crash).
	var second: Dictionary = screen.call("run_pending_battle")
	assert_str(str(second.get("kind", ""))).is_equal(str(first.get("kind", "")))
	screen.queue_free()
	gc.queue_free()
