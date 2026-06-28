extends GdUnitTestSuite
## Phase 5 · Slice 1 — Battle screen DoD, driven HEADLESSLY.
##   * the battle screen reads the pending battle GameController stashed (the overworld -> battle
##     hand-off), runs it via BattleSession/BattleController, and returns a result;
##   * the result is applied back to the run (xp awarded on a win), and the pending battle is
##     cleared (the loop closes back toward the overworld);
##   * the screen builds its minimal themed UI (result banner + transcript log) headlessly.
## Drives a CODE-INSTANTIATED GameController + battle screen with an injected FakeDal.

const GameControllerScript := preload("res://application/game/game_controller.gd")
const FakeDalScript := preload("res://infrastructure/dal/fake_dal.gd")
const BattleScreenScript := preload("res://presentation/battle/battle_screen.gd")

const TEST_SEED := 0xBA771E5
const BATTLE_SEED := 0x5117E1


func _make_game_with_pending_battle() -> Node:
	var gc: Node = GameControllerScript.new()
	add_child(gc)
	gc.call("configure", FakeDalScript.make())
	var run: RunContext = gc.call("new_run", TEST_SEED)
	run.flags["pending_battle"] = {
		"enemy_party": [{"species_id": "SB33"}, {"species_id": "SB14"}],
		"battle_seed": BATTLE_SEED,
	}
	return gc


## A battle screen wired to `gc` with auto-run DISABLED, so _ready does NOT fire the battle and the
## test drives run_pending_battle() exactly once (xp applied exactly once). Injection wins because
## set_game runs before add_child (the _ready autoload grab only fills a null _game).
func _make_screen(gc: Node) -> Control:
	var screen: Control = BattleScreenScript.new()
	screen.call("set_game", gc)
	screen.call("set_auto_run", false)
	add_child(screen)
	return screen


func test_battle_screen_runs_pending_battle_and_returns_result() -> void:
	var gc := _make_game_with_pending_battle()
	var screen := _make_screen(gc)
	var result: Dictionary = screen.call("run_pending_battle")
	assert_bool(bool(result["valid"])).is_true()
	assert_str(str(result["winner"])).is_not_empty()
	assert_int((result["transcript"] as Array).size()).is_greater(0)
	# The pending battle is consumed (loop boundary cleared).
	var run: RunContext = gc.call("run")
	assert_bool(run.flags.has("pending_battle")).is_false()
	# Outcome flag recorded for the overworld to read on return.
	assert_bool(run.flags.has("last_battle_won")).is_true()
	screen.queue_free()
	gc.queue_free()


func test_battle_screen_builds_result_banner_and_log() -> void:
	var gc := _make_game_with_pending_battle()
	var screen := _make_screen(gc)
	screen.call("run_pending_battle")
	# The code-built UI exists: a result banner + a transcript log node.
	var banner := screen.find_child("ResultBanner", true, false)
	var log := screen.find_child("TranscriptLog", true, false)
	assert_object(banner).is_not_null()
	assert_object(log).is_not_null()
	assert_str(str((banner as Label).text)).is_not_empty()
	screen.queue_free()
	gc.queue_free()


func test_win_awards_xp_to_run() -> void:
	var gc := _make_game_with_pending_battle()
	var screen := _make_screen(gc)
	var run: RunContext = gc.call("run")
	# Captured BEFORE the single explicit run (auto-run is off, so _ready did not consume xp).
	var essence_before := run.essence
	var result: Dictionary = screen.call("run_pending_battle")
	# apply_battle_result folds xp into essence (Slice 1 growth stand-in) — applied EXACTLY once.
	if bool(result["player_won"]):
		assert_int(run.essence).is_equal(essence_before + int(result["xp"]))
	else:
		assert_int(run.essence).is_equal(essence_before)
	# A stray second call is a no-op (re-entrancy guard): essence + result unchanged.
	var essence_after := run.essence
	var second: Dictionary = screen.call("run_pending_battle")
	assert_int(run.essence).is_equal(essence_after)
	assert_str(str(second["winner"])).is_equal(str(result["winner"]))
	screen.queue_free()
	gc.queue_free()
