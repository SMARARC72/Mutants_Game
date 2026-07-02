extends GdUnitTestSuite
## Wave 13 "Atmosphere, Thin Places & The Follower" — headless DoD suite.
##   * the AtmosphereLayer builds headless with EXACTLY two fullscreen passes (tension 9), rides
##     below the HUD, and set_mood(corruption) visibly re-grades the world CanvasModulate;
##   * the HUD corruption pip stages at 25/50/75 and records each first threshold crossing on the
##     run (the authored VoiceBook threshold lines resolve);
##   * the veil shimmer marks exactly the thin-place cells the encounter surface uses (the same
##     pure mapping — shimmering tiles and the gated rolls never disagree);
##   * Beehave ambient critters spawn headless-safe under the y-sorted world root, each with a
##     real BeehaveTree brain (C15 — the addon is genuinely exercised);
##   * the PECULIAR seam: a kind:"peculiar" roll deterministically routes to peculiar_encounter —
##     signal + peculiar_hook fire, and NOTHING battle-shaped happens (no pending_battle stash,
##     no grace, no encounter_started, never the battle scene).

const GameControllerScript := preload("res://application/game/game_controller.gd")
const FakeDalScript := preload("res://infrastructure/dal/fake_dal.gd")
const OverworldScreenScript := preload("res://presentation/overworld/overworld_screen.gd")
const EncounterDirectorScript := preload("res://application/overworld/encounter_director.gd")
const OverworldTileSetScript := preload("res://presentation/overworld/overworld_tileset.gd")
const OverworldAmbienceScript := preload("res://presentation/overworld/overworld_ambience.gd")
const CorruptionPipScript := preload("res://presentation/overworld/corruption_pip.gd")

const TEST_SEED := 0x0A73_0513  # "ATMOS W13"
const REGION := "verdant_glut"


func after_test() -> void:
	OverworldScreenScript.peculiar_hook = Callable()  # never leak the seam across tests


func _make_game() -> Node:
	var gc: Node = GameControllerScript.new()
	add_child(gc)
	gc.call("configure", FakeDalScript.make())
	return gc


func _make_overworld(game: Node) -> Node2D:
	var ow: Node2D = OverworldScreenScript.new()
	ow.call("set_game", game)
	ow.call("set_auto_hand_off", false)
	add_child(ow)
	ow.call("build_from_game")
	return ow


## A cardinal direction from `cell` into a walkable, in-bounds neighbour, or ZERO if hemmed in.
func _walkable_dir(layout: Layout, cell: Vector2i) -> Vector2i:
	for dir: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
		var n := cell + dir
		if (
			layout.in_bounds(n.x, n.y)
			and OverworldTileSetScript.is_walkable(layout.get_cell(n.x, n.y))
		):
			return dir
	return Vector2i.ZERO


func test_atmosphere_layer_builds_headless_with_exactly_two_passes_below_the_hud() -> void:
	var gc := _make_game()
	gc.call("new_run", TEST_SEED)
	var ow := _make_overworld(gc)
	var atmo: CanvasLayer = ow.call("atmosphere_layer")
	assert_object(atmo).is_not_null()
	# Exactly TWO fullscreen passes (tension 9): the grade+vignette rect and the fog rect.
	assert_int(int(atmo.call("pass_count"))).is_equal(2)
	assert_object(atmo.get_node("GradePass")).is_not_null()
	assert_object(atmo.get_node("FogPass")).is_not_null()
	# Above the world canvas, BELOW the HUD — atmosphere never grades readable text.
	var hud := ow.find_child("HUD", true, false) as CanvasLayer
	assert_object(hud).is_not_null()
	assert_int(atmo.layer).is_less(hud.layer)
	# A rebuild never stacks passes (idempotent layer — the two-pass cap holds for the session).
	ow.call("build_from_game")
	assert_int(int(ow.call("atmosphere_layer").call("pass_count"))).is_equal(2)
	ow.queue_free()
	gc.queue_free()


func test_corruption_regrades_the_world_tint_through_set_mood() -> void:
	var gc := _make_game()
	gc.call("new_run", TEST_SEED)
	var ow := _make_overworld(gc)
	var atmo: CanvasLayer = ow.call("atmosphere_layer")
	var tint := ow.get_node("ClimateTint") as CanvasModulate
	assert_object(tint).is_not_null()
	atmo.call("set_mood", 0.2, 0.0, 0.0, "Eros")
	var clean := tint.color
	atmo.call("set_mood", 0.2, 0.0, 80.0, "Eros")  # headless applies instantly (no tween)
	var rotted := tint.color
	assert_bool(clean != rotted).is_true()  # corruption-0 vs corruption-80: two different worlds
	# The mood is recorded (clamped) for observers.
	assert_float(float((atmo.call("mood") as Dictionary)["corruption"])).is_equal(80.0)
	# Readability floor: no channel of the world modulate ever drops below the guard.
	for channel: float in [rotted.r, rotted.g, rotted.b]:
		assert_float(channel).is_greater_equal(0.4)
	ow.queue_free()
	gc.queue_free()


func test_corruption_pip_stages_and_threshold_crossings_latch_on_the_run() -> void:
	assert_int(CorruptionPipScript.stage_for(0)).is_equal(0)
	assert_int(CorruptionPipScript.stage_for(24)).is_equal(0)
	assert_int(CorruptionPipScript.stage_for(25)).is_equal(1)
	assert_int(CorruptionPipScript.stage_for(50)).is_equal(2)
	assert_int(CorruptionPipScript.stage_for(75)).is_equal(3)
	assert_int(CorruptionPipScript.stage_for(100)).is_equal(3)
	# Every threshold resolves an authored VoiceBook line (corruption.first/.gate/.terminal).
	for stage in [1, 2, 3]:
		assert_str(CorruptionPipScript.threshold_line(stage)).is_not_empty()
	# refresh(): crossing a threshold latches the stage on the run so it toasts exactly once.
	var gc := _make_game()
	var run: RunContext = gc.call("new_run", TEST_SEED)
	var ow := _make_overworld(gc)
	var pip: Control = ow.call("corruption_pip")
	assert_object(pip).is_not_null()
	run.corruption = 30
	assert_int(int(pip.call("refresh", run))).is_equal(1)
	assert_int(int(run.flags.get(CorruptionPipScript.SEEN_FLAG, 0))).is_equal(1)
	run.corruption = 55
	assert_int(int(pip.call("refresh", run))).is_equal(2)
	assert_int(int(run.flags.get(CorruptionPipScript.SEEN_FLAG, 0))).is_equal(2)
	pip.call("refresh", run)  # same stage again: the latch holds (no re-cross)
	assert_int(int(run.flags.get(CorruptionPipScript.SEEN_FLAG, 0))).is_equal(2)
	ow.queue_free()
	gc.queue_free()


func test_veil_shimmer_marks_exactly_the_thin_place_cells() -> void:
	var gc := _make_game()
	gc.call("new_run", TEST_SEED)
	var ow := _make_overworld(gc)
	var layout: Layout = ow.call("layout")
	var shimmer: Node2D = ow.call("veil_shimmer")
	assert_object(shimmer).is_not_null()
	var expected := 0
	for y in layout.height:
		for x in layout.width:
			if str(ow.call("tile_class_at", Vector2i(x, y))) != "":
				expected += 1
				# The encounter class only ever rides the ritual-accent FEATURE cells.
				var tile_id := layout.get_cell(x, y)
				assert_int(tile_id).is_equal(OverworldTileSetScript.FEATURE_TILE)
	assert_int(shimmer.get_child_count()).is_equal(expected)
	assert_int(expected).is_greater(0)  # the region actually has a dare to step onto
	ow.queue_free()
	gc.queue_free()


func test_beehave_critters_spawn_headless_under_the_world_root() -> void:
	var gc := _make_game()
	gc.call("new_run", TEST_SEED)
	var ow := _make_overworld(gc)
	var critters: Node2D = ow.call("critters_root")
	assert_object(critters).is_not_null()
	assert_object(critters.get_parent()).is_same(ow.call("world_root"))
	assert_int(critters.get_child_count()).is_greater(0)
	assert_int(critters.get_child_count()).is_less_equal(3)
	var layout: Layout = ow.call("layout")
	var s := OverworldTileSetScript.TILE_SIZE
	for critter: Node2D in critters.get_children():
		# Every critter carries a REAL BeehaveTree brain (C15: the addon is exercised).
		var brain := critter.get_node_or_null("Brain")
		assert_object(brain).is_not_null()
		assert_bool(brain is BeehaveTree).is_true()
		assert_int(brain.get_child_count()).is_equal(1)  # Sequence[Idle -> Wander]
		assert_int(brain.get_child(0).get_child_count()).is_equal(2)
		# And it stands on a walkable cell.
		var cell := Vector2i(int(critter.position.x / s), int(critter.position.y / s))
		assert_bool(OverworldTileSetScript.is_walkable(layout.get_cell(cell.x, cell.y))).is_true()
	ow.queue_free()
	gc.queue_free()


func test_peculiar_roll_routes_to_the_seam_and_never_becomes_a_battle() -> void:
	var gc := _make_game()
	var run: RunContext = gc.call("new_run", TEST_SEED)
	run.flags["verdant_boss_cleared"] = true  # keep the climax out of the walk
	var ow := _make_overworld(gc)
	var layout: Layout = ow.call("layout")
	var d := _walkable_dir(layout, ow.call("player_cell"))
	assert_bool(d != Vector2i.ZERO).is_true()
	var landing_class := str(ow.call("tile_class_at", ow.call("player_cell") + d))
	# Pre-compute the first PECULIAR step on the landing cell's canonical stream (deterministic).
	var director: EncounterDirector = EncounterDirectorScript.for_region(TEST_SEED, REGION)
	var peculiar_step := -1
	for i in range(1, 3000):
		var probe: Dictionary = director.roll_step(i, landing_class)
		if bool(probe["encounter"]) and str(probe["kind"]) == EncounterDirectorScript.KIND_PECULIAR:
			peculiar_step = i
			break
	assert_int(peculiar_step).is_greater(0)
	# And it replays: the same (seed, step, class) is peculiar again (the W16b determinism seam).
	var replay: Dictionary = director.roll_step(peculiar_step, landing_class)
	assert_str(str(replay["kind"])).is_equal(EncounterDirectorScript.KIND_PECULIAR)
	# Drive the overworld onto it.
	var seen := {"peculiar": 0, "battle": 0, "hook": 0}
	ow.connect("peculiar_encountered", func(_roll: Dictionary) -> void: seen["peculiar"] += 1)
	ow.connect("encounter_started", func(_party: Array, _seed: int) -> void: seen["battle"] += 1)
	OverworldScreenScript.peculiar_hook = func(_screen: Node2D, _roll: Dictionary) -> void:
		seen["hook"] += 1
	run.world_state["steps"] = peculiar_step - 1
	var roll: Dictionary = ow.call("try_move", d)
	assert_bool(bool(roll.get("encounter", false))).is_true()
	assert_str(str(roll.get("kind", ""))).is_equal(EncounterDirectorScript.KIND_PECULIAR)
	# The seam fired; the battle machinery did NOT: no signal, no pending stash, no grace armed.
	assert_int(int(seen["peculiar"])).is_equal(1)
	assert_int(int(seen["hook"])).is_equal(1)
	assert_int(int(seen["battle"])).is_equal(0)
	assert_bool(run.flags.has("pending_battle")).is_false()
	assert_int(int(run.world_state.get("encounter_grace", 0))).is_equal(0)
	ow.queue_free()
	gc.queue_free()
