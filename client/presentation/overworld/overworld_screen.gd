extends Node2D
## OverworldScreen (Phase 5 · Slice 1) — the playable overworld. PRESENTATION layer, CODE-BUILT in
## _ready() (a thin .tscn just loads this script) so it is unit-testable headless: a test instantiates
## it, calls try_move(), and asserts the encounter/step logic without rendering.
##
## It wires the EXISTING infra through GameController:
##   * renders the active region's Layout (WorldGenerator.get_or_generate from run.seed, persisted +
##     reused via world_state) onto a TileMapLayer (OverworldTileSet flat-colour swatches),
##   * places a player actor on the first walkable tile and moves it on a GRID via InputService
##     overworld actions (discrete tile steps), with wall collision against the Layout,
##   * follows the player with a PhantomCamera2D (guarded so it still builds without the addon),
##   * rolls a canonical per-step WILD ENCOUNTER (EncounterDirector) each successful move and, on a
##     hit, hands the assembled enemy party + battle seed off to the battle screen (Transition swap).
##
## DETERMINISM: the encounter sequence is a pure function of (run.seed, region, step index), drawn
## from a canonical sub-stream — never global randf/randi.

## Emitted when a move triggers a wild encounter (enemy_party + battle_seed). The screen also
## auto-hands-off to the battle scene; the signal lets a test/observer react without the scene swap.
signal encounter_started(enemy_party: Array, battle_seed: int)

const EncounterDirectorScript := preload("res://application/overworld/encounter_director.gd")
const OverworldTileSetScript := preload("res://presentation/overworld/overworld_tileset.gd")
const InputActions := preload("res://infrastructure/input/input_actions.gd")
const BATTLE_SCENE := "res://presentation/battle/battle_screen.tscn"
const CAMP_SCENE := "res://presentation/camp/camp_menu.tscn"

const STEP_COOLDOWN := 0.14  # seconds between grid steps while a direction is held

var _game: Node = null
var _transition: Node = null
var _input: Node = null

var _layout: Layout = null
var _director: EncounterDirector = null
var _tile_layer: TileMapLayer = null
var _player: Node2D = null
var _player_cell: Vector2i = Vector2i.ZERO
var _step_timer: float = 0.0
var _busy: bool = false  # true while a battle hand-off / transition is mid-flight
## When false, an encounter still emits encounter_started + autosaves but skips the scene swap
## (lets a headless test drive the encounter flow without changing the SceneTree).
var _auto_hand_off: bool = true
## Slice 3b: when true (default) the OPEN_MENU/PAUSE action opens the camp menu overlay. Behind a
## flag so the Slice-1 try_move tests (which never pump _process) are completely unaffected, and a
## test can disable it. The camp overlay is added as a CanvasLayer child (no scene swap).
var _camp_enabled: bool = true
var _camp_overlay: Node = null


func _ready() -> void:
	# An injected _game (set_game before add_child) MUST win; only fall back to the autoload when
	# nothing was injected, so the test harness is never clobbered.
	if _game == null:
		_game = get_node_or_null("/root/GameController")
	_transition = get_node_or_null("/root/Transition")
	_input = get_node_or_null("/root/InputService")
	if _input != null and _input.has_method("switch_context"):
		_input.call("switch_context", InputActions.CTX_OVERWORLD)
	if _game != null and _game.has_method("has_run") and _game.call("has_run"):
		build_from_game()


## Inject the GameController (tests / non-autoload contexts). Call BEFORE build_from_game().
func set_game(game: Node) -> void:
	_game = game


## Disable the automatic scene swap on encounter (tests). The encounter still emits + autosaves.
func set_auto_hand_off(enabled: bool) -> void:
	_auto_hand_off = enabled


## Enable/disable the camp-menu trigger (Slice 3b). Default enabled; a test can turn it off.
func set_camp_enabled(enabled: bool) -> void:
	_camp_enabled = enabled


## Open the camp/pause menu as an OVERLAY (a CanvasLayer above the overworld, NOT a scene swap, so
## the overworld stays live beneath it). Idempotent: a second call while open is a no-op. Returns the
## opened camp menu node (or the existing one). Public so input + a test both drive it.
func open_camp() -> Node:
	if _camp_overlay != null and is_instance_valid(_camp_overlay):
		return _camp_overlay
	if not ResourceLoader.exists(CAMP_SCENE):
		push_warning("OverworldScreen.open_camp: missing camp scene '%s'" % CAMP_SCENE)
		return null
	var packed: PackedScene = load(CAMP_SCENE)
	if packed == null:
		return null
	var layer := CanvasLayer.new()
	layer.name = "CampOverlay"
	layer.layer = 50  # above gameplay, below Transition (100) + Toast (128)
	var menu := packed.instantiate()
	layer.add_child(menu)
	add_child(layer)
	_camp_overlay = layer
	# Resume tears the overlay down + restores the overworld input context.
	if menu.has_signal("resumed"):
		menu.connect("resumed", _on_camp_resumed)
	return menu


func _on_camp_resumed() -> void:
	if _camp_overlay != null and is_instance_valid(_camp_overlay):
		_camp_overlay.queue_free()
	_camp_overlay = null
	if _input != null and _input.has_method("switch_context"):
		_input.call("switch_context", InputActions.CTX_OVERWORLD)


## The live camp overlay node, or null when closed (for tests).
func camp_overlay() -> Node:
	return _camp_overlay


## Build the overworld from the active GameController run. Public so a test can drive it after
## injecting a configured GameController. Idempotent-ish: safe to call once after _ready.
func build_from_game() -> void:
	if _game == null:
		return
	var run: RunContext = _game.call("run")
	if run == null:
		return
	var region := str(_game.call("active_region"))
	var world_gen: WorldGenerator = _game.call("world_generator")
	var catalog: SpeciesCatalog = _game.call("catalog")
	# Generate-once + reuse: first visit solves + persists into world_state; later loads rehydrate.
	_layout = world_gen.get_or_generate(region, run.seed, run.world_state)
	_director = EncounterDirectorScript.for_region(run.seed, region, catalog)
	_render_layout()
	_spawn_player()
	_setup_camera()


# === movement + encounters ==================================================================== #


## Attempt a single GRID step in `dir` (one of the 4 cardinals as Vector2i). Returns the encounter
## roll result for the step (see EncounterDirector.roll_step), or an empty/no-op dict if the move
## was blocked by a wall / out of bounds / no layout. On a real move it advances the run step
## counter (so the encounter index persists across save/load) and rolls the canonical encounter.
## HEADLESS-TESTABLE: pure logic, no input/frame dependency.
func try_move(dir: Vector2i) -> Dictionary:
	if _busy or _layout == null or _director == null or _game == null:
		return {"encounter": false, "moved": false}
	var target := _player_cell + dir
	if not _layout.in_bounds(target.x, target.y):
		return {"encounter": false, "moved": false}
	if not OverworldTileSetScript.is_walkable(_layout.get_cell(target.x, target.y)):
		return {"encounter": false, "moved": false}
	_player_cell = target
	_position_player()
	var step_index := int(_game.call("advance_step"))
	var roll := _director.roll_step(step_index)
	roll["moved"] = true
	if bool(roll.get("encounter", false)):
		_on_encounter(roll)
	return roll


func _on_encounter(roll: Dictionary) -> void:
	var enemy_party: Array = roll.get("enemy_party", [])
	var battle_seed := int(roll.get("battle_seed", 0))
	encounter_started.emit(enemy_party, battle_seed)
	# Stash the battle params on the run so the battle screen (a fresh scene) can read them.
	if _game != null:
		var run: RunContext = _game.call("run")
		if run != null:
			run.flags["pending_battle"] = {
				"enemy_party": enemy_party,
				"battle_seed": battle_seed,
				"is_wild": true,  # overworld encounters are wild (Capture/Flee available, Slice 2)
			}
	# Save on encounter-end boundary (autosave the run before the fight resolves the loop).
	if _game != null and _game.has_method("save_run"):
		_game.call("save_run")
	if _auto_hand_off:
		_hand_off_to_battle()


## Swap to the battle scene (the battle screen reads the pending battle stashed on run.flags). Uses
## the ritual Transition when available, else a direct scene change.
func _hand_off_to_battle() -> void:
	_busy = true
	if _transition != null and _transition.has_method("change_scene_ritual"):
		await _transition.call("change_scene_ritual", BATTLE_SCENE)
	elif is_inside_tree():
		get_tree().change_scene_to_file(BATTLE_SCENE)


# === input -> discrete grid steps ============================================================= #


func _process(delta: float) -> void:
	if _busy or _input == null or _layout == null:
		return
	# Slice 3b: open the camp/pause menu on the menu action (guarded by the flag + overlay state).
	if _camp_enabled and _camp_overlay == null and _input.has_method("just_pressed"):
		if (
			bool(_input.call("just_pressed", InputActions.OPEN_MENU))
			or bool(_input.call("just_pressed", InputActions.PAUSE))
		):
			open_camp()
			return
	_step_timer = maxf(0.0, _step_timer - delta)
	if _step_timer > 0.0:
		return
	var dir := _read_step_dir()
	if dir != Vector2i.ZERO:
		try_move(dir)
		_step_timer = STEP_COOLDOWN


## Read a single cardinal step from InputService (prefers the dominant axis so diagonal holds still
## map to one grid step). Returns Vector2i.ZERO when no movement is held.
func _read_step_dir() -> Vector2i:
	if _input == null or not _input.has_method("movement_vector"):
		return Vector2i.ZERO
	var vec: Vector2 = _input.call("movement_vector")
	if vec == Vector2.ZERO:
		return Vector2i.ZERO
	if absf(vec.x) >= absf(vec.y):
		return Vector2i(signi(int(signf(vec.x))), 0)
	return Vector2i(0, signi(int(signf(vec.y))))


# === rendering / placement (guarded so the scene still BUILDS headless) ======================= #


func _render_layout() -> void:
	if _tile_layer != null:
		_tile_layer.queue_free()
	_tile_layer = TileMapLayer.new()
	_tile_layer.name = "RegionTiles"
	_tile_layer.tile_set = OverworldTileSetScript.build()
	add_child(_tile_layer)
	OverworldTileSetScript.paint(_tile_layer, _layout)


func _spawn_player() -> void:
	_player_cell = _first_walkable_cell()
	if _player == null:
		_player = Node2D.new()
		_player.name = "Player"
		var marker := ColorRect.new()
		marker.color = Color(0.92, 0.78, 0.36)  # brass actor marker (design §1)
		var s := OverworldTileSetScript.TILE_SIZE
		marker.size = Vector2(s, s)
		marker.position = Vector2(-s / 2.0, -s / 2.0)
		_player.add_child(marker)
		add_child(_player)
	_position_player()


func _position_player() -> void:
	if _player == null:
		return
	var s := OverworldTileSetScript.TILE_SIZE
	_player.position = Vector2(_player_cell.x * s + s / 2.0, _player_cell.y * s + s / 2.0)


## The first walkable cell scanning row-major; falls back to (0,0) if the layout is somehow all
## walls (the authored fallback guarantees an interior floor, so this is defensive).
func _first_walkable_cell() -> Vector2i:
	for y in _layout.height:
		for x in _layout.width:
			if OverworldTileSetScript.is_walkable(_layout.get_cell(x, y)):
				return Vector2i(x, y)
	return Vector2i.ZERO


## Attach a PhantomCamera2D following the player. Fully guarded: if the addon classes are missing
## (stripped build / headless import quirk) it falls back to a plain Camera2D so the scene still
## builds and the slice never errors.
func _setup_camera() -> void:
	if _player == null:
		return
	if ClassDB.class_exists("PhantomCameraHost") and ClassDB.class_exists("PhantomCamera2D"):
		var cam := Camera2D.new()
		cam.name = "OverworldCamera"
		add_child(cam)
		var host: Object = ClassDB.instantiate("PhantomCameraHost")
		if host is Node:
			cam.add_child(host as Node)
		var pcam: Object = ClassDB.instantiate("PhantomCamera2D")
		if pcam is Node2D:
			add_child(pcam as Node2D)
			# follow_mode 1 == GLUED in PhantomCamera2D.FollowMode (glue to the target).
			pcam.set("follow_mode", 1)
			pcam.set("follow_target", _player)
		return
	# Fallback: plain Camera2D parented to the player so it tracks naturally.
	var fallback := Camera2D.new()
	fallback.name = "OverworldCamera"
	_player.add_child(fallback)


# === accessors (for tests + sibling slices) ================================================== #


func player_cell() -> Vector2i:
	return _player_cell


func layout() -> Layout:
	return _layout
