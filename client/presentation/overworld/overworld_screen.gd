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
## Emitted when the player speaks to an NPC (the Dialogic timeline id). Lets a test/observer react.
signal dialogue_started(timeline_id: String)

const EncounterDirectorScript := preload("res://application/overworld/encounter_director.gd")
const OverworldTileSetScript := preload("res://presentation/overworld/overworld_tileset.gd")
const OverworldLoopStateScript := preload("res://presentation/overworld/overworld_loop_state.gd")
const OverworldTokensScript := preload("res://presentation/overworld/overworld_tokens.gd")
const ControlsChipScript := preload("res://presentation/overworld/controls_chip.gd")
const InputActions := preload("res://infrastructure/input/input_actions.gd")
const BATTLE_SCENE := "res://presentation/battle/battle_screen.tscn"
const CAMP_SCENE := "res://presentation/camp/camp_menu.tscn"

const STEP_COOLDOWN := 0.14  # seconds between grid steps while a direction is held
const CAMERA_ZOOM := 2.35  # frames ~13 tiles across the 1920px baseline — no raw void at the edges
const DASH_TILES := 3  # max tiles the sigil-dash crosses in one ritual hop (design §3.5)
const DASH_COOLDOWN := 0.55  # seconds before the ley-line can be ridden again

## NPC + quest CONTENT data lives in OverworldContent (separated so adding content never bloats this
## screen logic). NPCs play authored Dialogic timelines on INTERACT; quests advance via their step_key.
## Token/vignette texture builders live in OverworldTokens; colors come from GrimoirePalette.

var _game: Node = null
var _transition: Node = null
var _input: Node = null

var _layout: Layout = null
var _director: EncounterDirector = null
var _tile_layer: TileMapLayer = null
var _force_climate: String = "Eros"  # active region's force palette (set in build_from_game)
var _player: Node2D = null
var _player_cell: Vector2i = Vector2i.ZERO
## The canonical spawn cell (centre of the largest open field). NPC placement anchors here — not on
## the (possibly battle-restored) player cell — so the cast never drifts around the map post-battle.
var _home_cell: Vector2i = Vector2i.ZERO
var _lead: Sprite2D = null  # lead-creature cameo that trails the player
var _lead_target: Vector2 = Vector2.ZERO
var _last_dir: Vector2i = Vector2i.DOWN
var _step_timer: float = 0.0
var _dash_timer: float = 0.0
var _busy: bool = false  # true while a battle hand-off / transition is mid-flight
## When false, an encounter still emits encounter_started + autosaves but skips the scene swap
## (lets a headless test drive the encounter flow without changing the SceneTree).
var _auto_hand_off: bool = true
## Slice 3b: when true (default) the OPEN_MENU/PAUSE action opens the camp menu overlay. Behind a
## flag so the Slice-1 try_move tests (which never pump _process) are completely unaffected, and a
## test can disable it. The camp overlay is added as a CanvasLayer child (no scene swap).
var _camp_enabled: bool = true
var _camp_overlay: CanvasLayer = null
var _camp_menu: Node = null
## Overworld NPCs: each entry {cell: Vector2i, name, timeline, node}. Talk on INTERACT when adjacent.
var _npcs: Array = []
var _dialogue: DialogicFacade = null
var _in_dialogue: bool = false
var _quests: QuestService = null  # drives the intro quest from NPC talks (own narrative run-state)
var _objective_label: Label = null  # HUD quest-tracker: the active quest's current objective
var _controls_chip: Node = null  # the live-verbs HUD chip (W1/C13), collapsible via TOGGLE_CONTROLS


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
## the overworld stays live beneath it). Idempotent: a second call while open returns the SAME live
## camp menu (no duplicate). Returns the camp menu node (or null if the scene is missing). Public so
## input + a test both drive it.
func open_camp() -> Node:
	if _camp_overlay != null and is_instance_valid(_camp_overlay):
		return _camp_menu
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
	_camp_menu = menu
	# Resume tears the overlay down + restores the overworld input context.
	if menu.has_signal("resumed"):
		menu.connect("resumed", _on_camp_resumed)
	return menu


func _on_camp_resumed() -> void:
	if _camp_overlay != null and is_instance_valid(_camp_overlay):
		_camp_overlay.queue_free()
	_camp_overlay = null
	_camp_menu = null
	if _input != null and _input.has_method("switch_context"):
		_input.call("switch_context", InputActions.CTX_OVERWORLD)


## The live camp overlay CanvasLayer, or null when closed (for tests).
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
	_force_climate = OverworldTileSetScript.force_for_region(region)
	_render_layout()
	_spawn_player()
	_spawn_lead_creature()
	_spawn_npcs()
	_setup_camera()
	_setup_atmosphere()
	_setup_hud()
	_maybe_play_intro()


## Play the authored cold-open ("The Knack" — Maddox's thesis) ONCE per run, the first time the
## overworld builds. Flag-gated in run.flags + persisted, so it never replays on reload. No-op headless
## without a DialogicFacade target; the `dialogue_started` signal still fires so a test can assert it.
func _maybe_play_intro() -> void:
	if _game == null or not _game.has_method("run"):
		return
	var run: RunContext = _game.call("run")
	if run == null or bool(run.flags.get("intro_played", false)):
		return
	run.flags["intro_played"] = true
	if _game.has_method("save_run"):
		_game.call("save_run")
	if _dialogue == null:
		_dialogue = DialogicFacade.new()
	if not _dialogue.scene_finished.is_connected(_on_dialogue_finished):
		_dialogue.scene_finished.connect(_on_dialogue_finished)
	_in_dialogue = true
	dialogue_started.emit("intro_knack")
	_dialogue.play_timeline("intro_knack")


# === movement + encounters ==================================================================== #


## Attempt a single GRID step in `dir` (one of the 4 cardinals as Vector2i). Returns the encounter
## roll result for the step (see EncounterDirector.roll_step), or an empty/no-op dict if the move
## was blocked by a wall / out of bounds / no layout. On a real move it advances the run step
## counter (so the encounter index persists across save/load) and rolls the canonical encounter.
## `roll_encounter=false` moves + advances the counter WITHOUT the wild roll (the sigil-dash rolls
## ONCE at its landing step, not per crossed tile — Wave 3). A step inside the post-battle grace
## window (world_state) also skips the wild roll ("graced": true in the result); the boss climax is
## never graced. HEADLESS-TESTABLE: pure logic, no input/frame dependency.
func try_move(dir: Vector2i, roll_encounter: bool = true) -> Dictionary:
	if _busy or _layout == null or _director == null or _game == null:
		return {"encounter": false, "moved": false}
	var target := _player_cell + dir
	if not _layout.in_bounds(target.x, target.y):
		return {"encounter": false, "moved": false}
	if not OverworldTileSetScript.is_walkable(_layout.get_cell(target.x, target.y)):
		return {"encounter": false, "moved": false}
	var prev_px := _player.position if _player != null else Vector2.ZERO
	_player_cell = target
	_last_dir = dir
	_position_player()
	# The lead cameo trails into the tile the tamer just left (smoothed in _process).
	if _lead != null:
		_lead_target = prev_px
	var step_index := int(_game.call("advance_step"))
	# Slice 4: the LEGENDARY-BOSS climax takes precedence at/after the threshold step (once explored
	# enough + not yet cleared). Deterministic — a pure function of (seed, region, step, cleared flag).
	var boss_roll := _maybe_boss(step_index)
	if not boss_roll.is_empty():
		boss_roll["moved"] = true
		_on_boss_encounter(boss_roll)
		return boss_roll
	# Wave 3: every moved step consumes one grace tick; a graced (or roll-suppressed) step never
	# rolls, and later steps still roll their OWN step-indexed streams — determinism holds.
	var graced := OverworldLoopStateScript.consume_grace(_run_ctx())
	if graced or not roll_encounter:
		return {
			"encounter": false,
			"enemy_party": [],
			"battle_seed": 0,
			"step": step_index,
			"moved": true,
			"graced": graced,
		}
	var roll := _director.roll_step(step_index)
	roll["moved"] = true
	roll["graced"] = false
	if bool(roll.get("encounter", false)):
		_on_encounter(roll)
	return roll


## Build the deterministic boss encounter for `step_index` IF the climax should fire now, else {}.
## Reads the cleared flag from the run so a cleared slice never re-triggers the boss, and the Wave-3
## ONE-SHOT lair flag so a lost/fled boss fight never re-ambushes on every later step (the flag is
## set the moment the lair fires + persisted by the pre-battle autosave).
func _maybe_boss(step_index: int) -> Dictionary:
	if _director == null or _game == null:
		return {}
	var cleared := false
	if _game.has_method("slice_cleared"):
		cleared = bool(_game.call("slice_cleared"))
	var run := _run_ctx()
	var fired := OverworldLoopStateScript.boss_fired(run, _region_id())
	if not _director.should_trigger_boss(step_index, cleared, fired):
		return {}
	OverworldLoopStateScript.mark_boss_fired(run, _region_id())
	return _director.boss_step(step_index)


## The active RunContext, or null (single accessor for the many world_state read/write sites).
func _run_ctx() -> RunContext:
	if _game == null or not _game.has_method("run"):
		return null
	return _game.call("run")


## The active region id, or "" without a game.
func _region_id() -> String:
	return str(_game.call("active_region")) if _game != null else ""


func _on_encounter(roll: Dictionary) -> void:
	# Wild fight: Capture/Flee available (Slice 2).
	_stash_and_hand_off(roll, {"is_wild": true})


## Hand off the LEGENDARY-BOSS climax (Slice 4) through the SAME pending_battle path as a wild fight,
## tagged is_boss with the boss role brain so the battle screen runs it via BattleSession.run_boss.
func _on_boss_encounter(roll: Dictionary) -> void:
	# The boss is not capturable / fleeable like a wild mon.
	_stash_and_hand_off(
		roll,
		{"is_wild": false, "is_boss": true, "boss_brain": str(roll.get("boss_brain", "controller"))}
	)


## Stash the battle hand-off on the run (`extra` carries the wild/boss tags), arm the Wave 3
## pre-battle position/grace stash, autosave, and swap to the battle scene. The pending dict also
## carries the region + force climate (Wave 8 backdrop-lite: the arena is picked by force).
func _stash_and_hand_off(roll: Dictionary, extra: Dictionary) -> void:
	var enemy_party: Array = roll.get("enemy_party", [])
	var battle_seed := int(roll.get("battle_seed", 0))
	encounter_started.emit(enemy_party, battle_seed)
	var run := _run_ctx()
	if run != null:
		var pending := {
			"enemy_party": enemy_party,
			"battle_seed": battle_seed,
			"region": _region_id(),
			"force": _force_climate,
		}
		pending.merge(extra, true)
		run.flags["pending_battle"] = pending
		# Wave 3: the pre-battle autosave carries the exact cell + facing (the post-battle
		# overworld restores them) and arms the post-battle encounter grace window.
		OverworldLoopStateScript.stash_prebattle(
			run, _player_cell, _last_dir, EncounterDirectorScript.POST_BATTLE_GRACE_STEPS
		)
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


## Sigil-dash (design §3.5): a ritual hop of up to DASH_TILES grid steps along `dir`, stopping early
## at a wall / region edge / the boss climax. Wave 3: the dash rolls the wild encounter ONCE, at the
## LANDING step (not per crossed tile — a dash is one ritual move, not three treadmill steps); the
## landing roll uses that step's own canonical stream, so dashing to step N meets exactly what
## walking to step N would have met. Returns the number of tiles crossed. Public + HEADLESS-testable.
func sigil_dash(dir: Vector2i) -> int:
	if dir == Vector2i.ZERO:
		return 0
	var crossed := 0
	var last_step := -1
	var landing_graced := false
	var stopped := false  # boss climax / hand-off mid-dash forfeits the landing roll
	for _i in DASH_TILES:
		var res := try_move(dir, false)
		if not bool(res.get("moved", false)):
			break
		crossed += 1
		last_step = int(res.get("step", -1))
		landing_graced = bool(res.get("graced", false))
		if _busy or bool(res.get("boss", false)):
			stopped = true
			break
	if crossed > 0:
		_last_dir = dir
		_emit_dash_trail()
	if crossed > 0 and not stopped and not landing_graced and last_step >= 0:
		var roll := _director.roll_step(last_step)
		if bool(roll.get("encounter", false)):
			_on_encounter(roll)
	return crossed


## A brief brass spark-burst trailing the tamer on a dash (ley-line residue). No-op headless.
func _emit_dash_trail() -> void:
	if _player == null or not is_inside_tree():
		return
	var spark := CPUParticles2D.new()
	spark.one_shot = true
	spark.emitting = true
	spark.amount = 18
	spark.lifetime = 0.5
	spark.explosiveness = 0.9
	spark.direction = Vector2(-_last_dir.x, -_last_dir.y)
	spark.spread = 38.0
	spark.initial_velocity_min = 40.0
	spark.initial_velocity_max = 130.0
	spark.scale_amount_min = 1.0
	spark.scale_amount_max = 2.6
	spark.color = GrimoirePalette.BRASS_BRIGHT
	_player.add_child(spark)
	get_tree().create_timer(0.9).timeout.connect(spark.queue_free)


# === input -> discrete grid steps ============================================================= #


func _process(delta: float) -> void:
	# The lead cameo eases toward its trailing target every frame (independent of input/busy state).
	if _lead != null:
		_lead.position = _lead.position.lerp(_lead_target, clampf(delta * 9.0, 0.0, 1.0))
	if _busy or _in_dialogue or _input == null or _layout == null:
		return
	# Talk to an adjacent NPC on the INTERACT action (movement is suspended while a scene plays).
	if (
		_input.has_method("just_pressed")
		and bool(_input.call("just_pressed", InputActions.INTERACT))
	):
		if try_interact() != "":
			return
	# Collapse/expand the controls chip (H) — input-truth surface; never consumes a move.
	if _controls_chip != null and _input.has_method("just_pressed"):
		if bool(_input.call("just_pressed", InputActions.TOGGLE_CONTROLS)):
			_controls_chip.call("toggle")
	# Slice 3b: open the camp/pause menu on the menu action (guarded by the flag + overlay state).
	if _camp_enabled and _camp_overlay == null and _input.has_method("just_pressed"):
		if (
			bool(_input.call("just_pressed", InputActions.OPEN_MENU))
			or bool(_input.call("just_pressed", InputActions.PAUSE))
		):
			open_camp()
			return
	# Sigil-dash (design §3.5): a ritual hop of up to DASH_TILES along the faced/held direction.
	_dash_timer = maxf(0.0, _dash_timer - delta)
	if _dash_timer <= 0.0 and _input.has_method("just_pressed"):
		if bool(_input.call("just_pressed", InputActions.SIGIL_DASH)):
			var dash_dir := _read_step_dir()
			if dash_dir == Vector2i.ZERO:
				dash_dir = _last_dir
			if dash_dir != Vector2i.ZERO:
				sigil_dash(dash_dir)
				_dash_timer = DASH_COOLDOWN
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
	_tile_layer.tile_set = OverworldTileSetScript.build(_force_climate)
	add_child(_tile_layer)
	OverworldTileSetScript.paint(_tile_layer, _layout)
	_scatter_props()


## Prop decals on feature cells: a deterministic minority of feature-classified cells (chosen by
## OverworldTileSet.prop_texture — pure function of force + cell, so the same map always dresses
## the same way) get a painterly decal sprite (boulder ledge / moss mound / crystals / bones / ward
## stone) drawn above the ground tiles. Walkability is untouched — these are set dressing.
func _scatter_props() -> void:
	if _layout == null or _tile_layer == null:
		return
	var s := OverworldTileSetScript.TILE_SIZE
	for y in _layout.height:
		for x in _layout.width:
			if _layout.get_cell(x, y) != OverworldTileSetScript.FEATURE_TILE:
				continue
			var tex: Texture2D = OverworldTileSetScript.prop_texture(_force_climate, x, y)
			if tex == null:
				continue
			var prop := Sprite2D.new()
			prop.texture = tex
			prop.z_index = 5  # above ground tiles, below the lead cameo (15) and player (20)
			var fit := (s * 0.94) / maxf(float(tex.get_width()), float(tex.get_height()))
			prop.scale = Vector2(fit, fit)
			prop.position = Vector2(x * s + s / 2.0, y * s + s / 2.0)
			_tile_layer.add_child(prop)


func _spawn_player() -> void:
	_home_cell = _spawn_cell()
	# Wave 3 position persistence: prefer the pre-battle cell + facing stashed by the autosave (when
	# present + walkable) so a post-battle/reloaded overworld puts the player exactly where the fight
	# started — never back at spawn. Falls back to the canonical spawn.
	_player_cell = OverworldLoopStateScript.restore_cell(_run_ctx(), _layout, _home_cell)
	_last_dir = OverworldLoopStateScript.restore_facing(_run_ctx(), _last_dir)
	if _player == null:
		_player = Node2D.new()
		_player.name = "Player"
		_player.z_index = 20  # above the tilemap and the trailing lead cameo
		var token := Sprite2D.new()
		token.name = "Token"
		token.texture = OverworldTokensScript.player_token(
			int(OverworldTileSetScript.TILE_SIZE * 0.92)
		)
		_player.add_child(token)
		add_child(_player)
	_position_player()


## Spawn the lead-creature cameo (the ACTUAL party lead's real bestiary plate, circular-cropped with
## a brass ring) that trails the tamer HG/SS-style. No-op if no plate resolves.
func _spawn_lead_creature() -> void:
	if _lead != null:
		return
	var tex: Texture2D = SpeciesArt.plate(_lead_species_id())
	if tex == null:
		return
	_lead = Sprite2D.new()
	_lead.name = "LeadCreature"
	_lead.z_index = 15
	_lead.texture = OverworldTokensScript.creature_cameo(
		tex, int(OverworldTileSetScript.TILE_SIZE * 1.18)
	)
	add_child(_lead)
	var s := OverworldTileSetScript.TILE_SIZE
	var here := Vector2(_player_cell.x * s + s / 2.0, _player_cell.y * s + s / 2.0)
	_lead.position = here - Vector2(_last_dir) * float(s)
	_lead_target = _lead.position


## The species id of the run's ACTIVE lead creature (not just party[0] — the player may have set a
## non-first member as lead), or "" — used to pick the trailing cameo plate.
func _lead_species_id() -> String:
	if _game == null or not _game.has_method("run"):
		return ""
	var run: RunContext = _game.call("run")
	if run == null or not (run.party is Array) or (run.party as Array).is_empty():
		return ""
	var party: Array = run.party
	var idx := 0
	if _game.has_method("active_creature_index"):
		idx = clampi(int(_game.call("active_creature_index")), 0, party.size() - 1)
	var lead: Variant = party[idx]
	return str((lead as Dictionary).get("species_id", "")) if lead is Dictionary else ""


## A gentle force-climate colour-grade + a vignette overlay, so the region reads as an atmospheric
## place rather than a bright tile grid. Screen-space vignette sits above the world, below the HUD.
func _setup_atmosphere() -> void:
	var tint := CanvasModulate.new()
	tint.name = "ClimateTint"
	tint.color = Color(0.84, 0.9, 0.82)  # cool verdant marsh grade
	add_child(tint)
	# Faint drifting spore-motes, parented to the tamer so they always fill the framed view.
	if _player != null:
		var motes := CPUParticles2D.new()
		motes.name = "Motes"
		motes.z_index = 12
		motes.amount = 36
		motes.lifetime = 7.0
		motes.preprocess = 5.0
		motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		motes.emission_rect_extents = Vector2(820, 520)
		motes.gravity = Vector2(0, -5)
		motes.initial_velocity_min = 3.0
		motes.initial_velocity_max = 11.0
		motes.scale_amount_min = 1.0
		motes.scale_amount_max = 2.4
		motes.color = Color(0.88, 0.78, 0.42, 0.5)
		_player.add_child(motes)
	var layer := CanvasLayer.new()
	layer.name = "Atmosphere"
	layer.layer = 1
	var vig := TextureRect.new()
	vig.texture = OverworldTokensScript.vignette(256)
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(vig)
	add_child(layer)


## A small grimoire HUD panel naming the region + its force-climate (the overworld "you are here").
func _setup_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	layer.layer = 2
	var panel := PanelContainer.new()
	panel.position = Vector2(18, 14)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	# Wave 3: the HUD names the region the systems actually RUN (data-driven from the active region
	# id via OverworldContent, falling back to the raw id) — no more hard-coded "The Rust Marsh".
	var title := Label.new()
	title.name = "RegionTitle"
	title.text = OverworldContent.region_title(_region_id())
	title.theme_type_variation = "TitleLabel"
	var sub := Label.new()
	sub.text = OverworldContent.region_climate(_region_id())
	sub.visible = sub.text != ""
	sub.theme_type_variation = "MutedLabel"
	box.add_child(title)
	box.add_child(sub)
	# Quest tracker: the active quest's current objective, always visible (hidden when none). Surfaces
	# the quest the player is on without opening the Ledger; updated live on each quest advance.
	_objective_label = Label.new()
	_objective_label.name = "ObjectiveTracker"
	box.add_child(_objective_label)
	panel.add_child(box)
	layer.add_child(panel)
	# Controls chip (W1/C13): the live verbs, always on, bottom-left, collapsible with H.
	_controls_chip = ControlsChipScript.new(_input)
	layer.add_child(_controls_chip)
	add_child(layer)
	var theme_svc := get_node_or_null("/root/ThemeService")
	if theme_svc != null and theme_svc.has_method("apply_to"):
		theme_svc.call("apply_to", panel)
	_refresh_objective()


## Update the HUD quest tracker to the active quest's current objective (hidden when no quest is active).
func _refresh_objective() -> void:
	if _objective_label == null:
		return
	var text := _active_objective()
	_objective_label.text = text
	_objective_label.visible = text != ""


## "✦ <Quest>: <current step description>" for the first active quest, or "" if none is active. Reads
## the same QuestService + authored defs the Ledger does, so the HUD and the journal never disagree.
func _active_objective() -> String:
	if _quests == null:
		return ""
	for q: Dictionary in OverworldContent.quest_defs():
		var qid := str(q.get("id", ""))
		if not _quests.is_active(qid):
			continue
		var cursor := int((_quests.state().get(qid, {}) as Dictionary).get("step_cursor", 0))
		var steps: Array = q.get("steps", [])
		if cursor >= 0 and cursor < steps.size():
			return (
				"✦ "
				+ str(q.get("name", ""))
				+ ": "
				+ str((steps[cursor] as Dictionary).get("description", ""))
			)
	return ""


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


## The cell nearest the region CENTRE that belongs to the LARGEST reachable open area — the player
## spawns here (not the top-left corner) so every direction is usable immediately and the camera
## frames the player mid-region. Selecting from the biggest 4-connected walkable component (not just
## any walkable tile) keeps the spawn in the navigable field and OUT of a SEALED set-piece room — a
## DungeonAssembler room is stamped with a wall ring and no doorway, so a spawn inside its isolated
## interior could move around the room but never leave, soft-locking the run.
func _spawn_cell() -> Vector2i:
	var field := _largest_open_component()
	if field.is_empty():
		return _first_walkable_cell()
	var cx := _layout.width / 2
	var cy := _layout.height / 2
	var best := Vector2i(-1, -1)
	var best_d := 1 << 30
	for cell: Vector2i in field:
		var d := (cell.x - cx) * (cell.x - cx) + (cell.y - cy) * (cell.y - cy)
		if d < best_d:
			best_d = d
			best = cell
	return best if best.x >= 0 else _first_walkable_cell()


## The cells of the LARGEST 4-connected component of walkable tiles — the main reachable field. A
## flood fill seeded from every unvisited walkable cell; the biggest basin wins (sealed rooms and
## other islands are smaller, so they lose). Empty only if the layout has no walkable tile at all.
func _largest_open_component() -> Array[Vector2i]:
	var visited := {}
	var best: Array[Vector2i] = []
	for y in _layout.height:
		for x in _layout.width:
			var start := Vector2i(x, y)
			if visited.has(start) or not OverworldTileSetScript.is_walkable(_layout.get_cell(x, y)):
				continue
			var component := _flood_open(start, visited)
			if component.size() > best.size():
				best = component
	return best


## Flood fill (4-connected, matching the cardinal grid steps of try_move) of the walkable region
## containing `start`, marking every reached cell in the shared `visited` set so each cell is scanned
## once across the whole sweep. Returns the cells of that one component.
func _flood_open(start: Vector2i, visited: Dictionary) -> Array[Vector2i]:
	var component: Array[Vector2i] = []
	var queue: Array[Vector2i] = [start]
	visited[start] = true
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		component.append(cell)
		for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := cell + step
			if visited.has(n) or not _layout.in_bounds(n.x, n.y):
				continue
			if not OverworldTileSetScript.is_walkable(_layout.get_cell(n.x, n.y)):
				continue
			visited[n] = true
			queue.append(n)
	return component


## Attach a PhantomCamera2D following the player. Fully guarded: if the addon classes are missing
## (stripped build / headless import quirk) it falls back to a plain Camera2D so the scene still
## builds and the slice never errors.
func _setup_camera() -> void:
	OverworldCameraRig.setup(self, _player, _layout_pixel_rect(), CAMERA_ZOOM)


## The painted layout rect in pixels — the camera clamps to it so the view never pans
## into raw void beyond the region's edge.
func _layout_pixel_rect() -> Rect2:
	if _layout == null:
		return Rect2()
	var s := float(OverworldTileSetScript.TILE_SIZE)
	return Rect2(Vector2.ZERO, Vector2(_layout.width * s, _layout.height * s))


# === NPCs + dialogue ========================================================================== #


## Place the region's NPCs on walkable cells near the spawn, each as a parchment token ringed in its
## colour. No-op if there is no layout. Safe headless (tokens are nodes; nothing renders).
func _spawn_npcs() -> void:
	_npcs.clear()
	if _layout == null:
		return
	if _quests == null:
		_quests = QuestService.new()
		_quests.register(_quest_defs())  # all overworld quests (MARSH/MELON/BRAMBLE/...) in one place
		_restore_quests()
	_sync_boss_goal_quest()
	var cells := _npc_cells(OverworldContent.NPC_DEFS.size())
	for i in mini(cells.size(), OverworldContent.NPC_DEFS.size()):
		var def: Dictionary = OverworldContent.NPC_DEFS[i]
		var cell: Vector2i = cells[i]
		var node := Node2D.new()
		node.name = "NPC_%s" % str(def["name"]).replace(" ", "")
		node.z_index = 16
		var s := OverworldTileSetScript.TILE_SIZE
		node.position = Vector2(cell.x * s + s / 2.0, cell.y * s + s / 2.0)
		var token := Sprite2D.new()
		token.texture = OverworldTokensScript.npc_token(
			int(s * 0.84), def["ring"] as Color, str(def["name"])
		)
		node.add_child(token)
		add_child(node)
		# Carry ALL of the def's keys (name/timeline/ring + every quest step_key) so the data-driven
		# quest dispatch sees each NPC's steps — a new quest's step_key needs no change here.
		var entry: Dictionary = def.duplicate(true)
		entry["cell"] = cell
		entry["node"] = node
		_npcs.append(entry)


## Pick `count` walkable cells near the CANONICAL spawn (manhattan distance 2..6), deterministic,
## skipping the spawn cell itself — anchored on _home_cell (not the battle-restored player cell) so
## the cast stays put across battles and reloads.
func _npc_cells(count: int) -> Array:
	var found: Array = []
	for radius in range(2, 8):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if abs(dx) + abs(dy) != radius:
					continue
				var c := _home_cell + Vector2i(dx, dy)
				if c == _home_cell or found.has(c):
					continue
				if not _layout.in_bounds(c.x, c.y):
					continue
				if OverworldTileSetScript.is_walkable(_layout.get_cell(c.x, c.y)):
					found.append(c)
					if found.size() >= count:
						return found
	return found


## If the tamer stands on/next to an NPC, speak to it and return its timeline id; else "". Drives the
## INTERACT action from _process.
func try_interact() -> String:
	for i in _npcs.size():
		var npc: Dictionary = _npcs[i]
		var cell: Vector2i = npc["cell"]
		if (cell - _player_cell).length() <= 1.5:
			return speak_to(i)
	return ""


## Play NPC `index`'s authored Dialogic timeline (a funny-grim beat) + a toast. Returns the timeline
## id (or ""). Public + headless-safe (DialogicFacade resolves immediately under --headless), so a
## test can assert the beat fires. Movement is suspended until the scene finishes.
func speak_to(index: int) -> String:
	if index < 0 or index >= _npcs.size():
		return ""
	var npc: Dictionary = _npcs[index]
	var timeline := str(npc["timeline"])
	if _dialogue == null:
		_dialogue = DialogicFacade.new()
	# Connect idempotently BEFORE play so a first-talk signal can never be missed (review P2.3).
	if not _dialogue.scene_finished.is_connected(_on_dialogue_finished):
		_dialogue.scene_finished.connect(_on_dialogue_finished)
	_in_dialogue = true
	_advance_quest_for(npc)
	dialogue_started.emit(timeline)
	_dialogue.play_timeline(timeline)
	return timeline


## Drive every quest this NPC participates in: the intro quest (quest_step → MARSH_QUEST) and the
## SQ-04 side quest (melon_step → MELON_QUEST). Both quests live in this screen's QuestService (its
## own narrative run-state) for now and share the same start-on-first-talk / toast-on-advance shape.
func _advance_quest_for(npc: Dictionary) -> void:
	if _quests == null:
		return
	# Data-driven: each quest names the NPC_DEFS key (step_key) whose value is the step this NPC drives,
	# so adding a quest is pure data (a quest def + NPC entries) — no new dispatch code here.
	for q: Dictionary in _quest_defs():
		var step_key := str(q.get("step_key", ""))
		if step_key != "":
			_advance_quest_step(str(q["id"]), str(npc.get(step_key, "")))


## Start `quest_id` on the first talk that names a step, advance to that step, and toast the ledger
## on a real advance. On a real advance the step's (and, on completion, the quest's) gameplay effect
## is applied to the PERSISTED run, and quest progress is serialized + saved — so standing/corruption
## actually accrue and survive reload (review P1.1 + Codex #37). No-op when the NPC drives no step.
func _advance_quest_step(quest_id: String, step: String) -> void:
	if step == "":
		return
	# Track BOTH transitions: a fresh start() and a real advance(). An out-of-order NPC (talked to
	# before the prerequisite step) can start the quest yet have its advance() rejected — that start
	# is still durable state and MUST persist, else re-entering the screen loses it (Codex #39 P2).
	var started := false
	if not _quests.is_active(quest_id) and not _quests.is_done(quest_id):
		started = _quests.start(quest_id)
	var advanced := _quests.is_active(quest_id) and _quests.advance(quest_id, step)
	if advanced:
		_apply_effect_to_run(_quest_step_effect(quest_id, step))
		if _quests.is_done(quest_id):
			_apply_effect_to_run(_quest_def_by_id(quest_id).get("on_complete", {}) as Dictionary)
	if not (started or advanced):
		return
	_persist_quests()
	_refresh_objective()  # keep the HUD tracker in step with the quest the player just moved
	# Only a real advance is a player-facing "quest update"; a bare start with no advance is silent.
	if advanced:
		var toast := get_node_or_null("/root/Toast")
		if toast != null and toast.has_method("event"):
			toast.call("event", "quest_update")


## Wave 3 (red-team C13): the BOSS-GOAL quest is active from RUN START (no NPC gives it — started
## here on every build until it sticks) and completes through the existing quest_state flags path
## the moment the slice reads cleared (a played boss win sets the victory flag via
## GameController._mark_slice_cleared). Surfaces the run's goal in the Phase-13c HUD tracker.
func _sync_boss_goal_quest() -> void:
	if _quests == null:
		return
	var qid := str(OverworldContent.BOSS_QUEST["id"])
	if _quests.is_done(qid):
		return
	if not _quests.is_active(qid) and _quests.start(qid):
		_persist_quests()
		_refresh_objective()
	if _game != null and _game.has_method("slice_cleared") and bool(_game.call("slice_cleared")):
		_advance_quest_step(qid, "walk_the_deep_path")


## All quest definitions this screen drives (for lookup + restore) — single-sourced from the content
## data module, so adding a quest there flows through registration, dispatch, restore, and effects.
func _quest_defs() -> Array:
	return OverworldContent.quest_defs()


func _quest_def_by_id(quest_id: String) -> Dictionary:
	for d: Dictionary in _quest_defs():
		if str(d.get("id", "")) == quest_id:
			return d
	return {}


## The `on_complete` effect of a named step of a quest, or {} if not found.
func _quest_step_effect(quest_id: String, step_id: String) -> Dictionary:
	for s: Dictionary in _quest_def_by_id(quest_id).get("steps", []) as Array:
		if str(s.get("id", "")) == step_id:
			return s.get("on_complete", {}) as Dictionary
	return {}


## Apply a quest effect to the ACTUAL run (corruption / standing / flags), not just the screen-local
## QuestService run-state, so the rewards are real + saved. Data-only effect dict.
func _apply_effect_to_run(effect: Dictionary) -> void:
	if effect.is_empty() or _game == null or not _game.has_method("run"):
		return
	var run: RunContext = _game.call("run")
	if run == null:
		return
	if effect.has("set_flag"):
		run.flags[str(effect["set_flag"])] = true
	if effect.has("add_corruption"):
		run.corruption += int(effect["add_corruption"])
	if effect.has("nudge_standing"):
		var pair: Array = effect["nudge_standing"]
		if (
			pair.size() == 2
			and str(pair[0]) == "bloomwardens"
			and _game.has_method("adjust_bloomwardens_standing")
		):
			_game.call("adjust_bloomwardens_standing", int(pair[1]))


## Serialize quest progress into run.flags and persist the run, so quests survive leaving the screen.
func _persist_quests() -> void:
	if _quests == null or _game == null or not _game.has_method("run"):
		return
	var run: RunContext = _game.call("run")
	if run == null:
		return
	run.flags["quest_state"] = _quests.serialize()
	if _game.has_method("save_run"):
		_game.call("save_run")


## Restore quest progress from the run (so a re-entered overworld keeps completed/in-flight quests).
func _restore_quests() -> void:
	if _quests == null or _game == null or not _game.has_method("run"):
		return
	var run: RunContext = _game.call("run")
	if run != null and run.flags.has("quest_state"):
		_quests.deserialize(run.flags["quest_state"] as Dictionary)


func _on_dialogue_finished(_timeline_id: String) -> void:
	_in_dialogue = false


## Intro-quest state accessors (for tests + a future quest-log UI).
## The HUD quest-tracker text (the active quest's current objective, or "" when none). For tests +
## observers; computed live from QuestService so it never lags the label node.
func objective_text() -> String:
	return _active_objective()


func quest_active(quest_id: String) -> bool:
	return _quests != null and _quests.is_active(quest_id)


func quest_done(quest_id: String) -> bool:
	return _quests != null and _quests.is_done(quest_id)


# === accessors (for tests + sibling slices) ================================================== #


## The number of NPCs placed in the region (for tests).
func npc_count() -> int:
	return _npcs.size()


## The HUD controls chip node (for tests + future waves).
func controls_chip() -> Node:
	return _controls_chip


func player_cell() -> Vector2i:
	return _player_cell


func layout() -> Layout:
	return _layout
