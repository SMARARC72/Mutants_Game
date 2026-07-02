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

## Emitted when a move triggers a wild BATTLE encounter (enemy_party + battle_seed). The screen
## also auto-hands-off to the battle scene; the signal lets a test/observer react without the swap.
signal encounter_started(enemy_party: Array, battle_seed: int)
## Emitted when the player speaks to an NPC (the Dialogic timeline id). Lets a test/observer react.
signal dialogue_started(timeline_id: String)
## W13: a PECULIAR encounter fired (kind:"peculiar", ~1 in 6 of triggered rolls) — a non-battle
## beat. NEVER stashes a pending battle / swaps to the battle scene; W16b wires the content.
signal peculiar_encountered(roll: Dictionary)

const EncounterDirectorScript := preload("res://application/overworld/encounter_director.gd")
const RegionTravelScript := preload("res://application/overworld/region_travel.gd")
const OverworldTileSetScript := preload("res://presentation/overworld/overworld_tileset.gd")
const OverworldLoopStateScript := preload("res://presentation/overworld/overworld_loop_state.gd")
const OverworldTokensScript := preload("res://presentation/overworld/overworld_tokens.gd")
const OverworldMotionScript := preload("res://presentation/overworld/overworld_motion.gd")
const OverworldSpawnScript := preload("res://presentation/overworld/overworld_spawn.gd")
const OverworldDepthScript := preload("res://presentation/overworld/overworld_depth.gd")
const OverworldOverlaysScript := preload("res://presentation/overworld/overworld_overlays.gd")
const ControlsChipScript := preload("res://presentation/overworld/controls_chip.gd")
const InputActions := preload("res://infrastructure/input/input_actions.gd")
const BATTLE_SCENE := "res://presentation/battle/battle_screen.tscn"
## Wave 6 spike diet: const-preload the camp scene (a load() on first ESC read as a hitch).
const CampMenuScene: PackedScene = preload("res://presentation/camp/camp_menu.tscn")
const AtmosphereLayerScene: PackedScene = preload(
	"res://presentation/ui/atmosphere/atmosphere_layer.tscn"
)

const CAMERA_ZOOM := 2.35  # frames ~13 tiles across the 1920px baseline — no raw void at the edges
const DASH_TILES := 3  # max tiles the sigil-dash crosses in one ritual hop (design §3.5)
const DASH_COOLDOWN := 0.55  # seconds before the ley-line can be ridden again

## W16b seam: when set (a Callable taking (screen, roll)), every peculiar encounter calls it with
## the roll dict — the content wave registers its handler here without editing this screen.
## Static so a registration survives scene swaps. Peculiars stay quiet until it is wired.
static var peculiar_hook := Callable()

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
## Wave 12: the single Y-SORTED world root. Props + player + NPC tokens + the lead cameo all live
## under it at z 0 with feet-level y-origins, so a tall prop occludes an actor walking behind it
## and is occluded by one standing in front — draw order comes from Y, never hand-set z layers.
var _world: Node2D = null
var _props: Node2D = null  # prop holder inside _world (rebuilt with the layout; actors persist)
var _player: Node2D = null
var _player_cell: Vector2i = Vector2i.ZERO
## The canonical spawn cell (centre of the largest open field). NPC placement anchors here — not on
## the (possibly battle-restored) player cell — so the cast never drifts around the map post-battle.
var _home_cell: Vector2i = Vector2i.ZERO
var _lead: Sprite2D = null  # lead-creature cameo that trails the player
var _lead_target: Vector2 = Vector2.ZERO
var _last_dir: Vector2i = Vector2i.DOWN
## Wave 6: visual motion + input pacing (step glide / buffering / turn-in-place / thunk / dash
## whoosh) lives in OverworldMotion; grid logic here stays synchronous. The camera rig object
## (PhantomCamera2D or fallback Camera2D) takes the walk-direction look-ahead.
var _motion: OverworldMotion = OverworldMotionScript.new()
var _cam_rig: Object = null
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
## Wave 13: the mood layer (grade+vignette+fog), the HUD corruption pip, the veil-shimmer holder,
## the follower/NPC small-life kit, and the Beehave ambient critters.
var _atmosphere: AtmosphereLayer = null
var _pip: CorruptionPip = null
var _shimmer: Node2D = null
var _ambience := OverworldAmbience.new()
var _critters := OverworldCritters.new()
## W-DRESS: the landmark-structures kit (deterministic plan + footprint blocked-set + holder).
var _structures := OverworldStructures.new()
## E1b: the live Threshold travel overlay (or null) — pushed on waygate INTERACT, popped on
## travel/close. While it is open the overworld takes no input (the camp rule).
var _threshold_screen: Node = null


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


## Wave 6 test flag: force INSTANT visual placement (no tweens) even where the tree could
## animate. Headless runs are instant automatically; this pins it for timing-sensitive tests.
func set_instant_moves(enabled: bool) -> void:
	_motion.instant_moves = enabled


## Open the camp/pause menu as an OVERLAY over the LIVE overworld (W17 router pattern; the
## OverworldOverlays kit owns construction + push). Idempotent: a second call while open returns
## the SAME live camp menu. Returns the camp menu node (or null if the scene is missing). Public
## so input + a test both drive it.
func open_camp() -> Node:
	if _camp_overlay != null and is_instance_valid(_camp_overlay):
		return _camp_menu
	var opened := OverworldOverlaysScript.open_camp(self, CampMenuScene, _on_camp_resumed)
	_camp_overlay = opened.get("overlay") as CanvasLayer
	_camp_menu = opened.get("menu") as Node
	return _camp_menu


func _on_camp_resumed() -> void:
	OverworldOverlaysScript.resume_camp(self, _camp_overlay, _camp_menu, _input)
	_camp_overlay = null
	_camp_menu = null


## Leaving the tree (battle hand-off / teardown) closes any open camp overlay with us — the router
## self-heals its stack when the layer dies, so no orphan page can float over the next scene.
func _exit_tree() -> void:
	if _camp_overlay != null and is_instance_valid(_camp_overlay):
		_camp_overlay.queue_free()
	_camp_overlay = null
	_camp_menu = null


## The live camp overlay CanvasLayer, or null when closed (for tests).
func camp_overlay() -> Node:
	return _camp_overlay


## E1b — open the Threshold-network travel overlay (the ritual circle's page) over the LIVE
## overworld (the OverworldOverlays kit owns construction + push, the camp's W17 pattern).
## Idempotent: a second call returns the SAME live screen. Public so the waygate INTERACT and a
## test both drive it.
func open_threshold() -> Node:
	if _threshold_screen != null and is_instance_valid(_threshold_screen):
		return _threshold_screen
	_threshold_screen = OverworldOverlaysScript.open_threshold(
		self, _game, _on_threshold_traveled, _on_threshold_closed
	)
	return _threshold_screen


## A travel was ACCEPTED: the kit drops the stale position stash, rebuilds the overworld in
## place through the existing build path (per-region layouts rehydrate), and saves the hop.
func _on_threshold_traveled(_region_id_traveled: String) -> void:
	_threshold_screen = null
	OverworldOverlaysScript.after_travel(self, _game)


func _on_threshold_closed() -> void:
	_threshold_screen = null


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
	_ensure_world_root()
	_setup_horizon()
	_render_layout()
	_build_structures()
	_spawn_player()
	_spawn_lead_creature()
	_spawn_npcs()
	_critters.build(_world, _layout, _director.wild_pool(), _home_cell)
	_setup_camera()
	_setup_atmosphere()
	_setup_hud()
	# W13: mood after the HUD exists (the pip refresh rides it); the lead joy-hops once when this
	# build is the return from a catching battle.
	_refresh_mood()
	_ambience.maybe_joy_hop(_lead, run, int(_game.call("current_step")))
	_maybe_play_intro()


## The authored cold-open ("The Knack"), once per run — OverworldChoices owns the beat.
func _maybe_play_intro() -> void:
	OverworldChoices.maybe_play_intro(self, _game)


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
		_motion.thunk(dir, _cell_center(_player_cell))
		_ambience.on_blocked(_lead)  # W13: the follower shivers at the wall with you
		return {"encounter": false, "moved": false}
	# W-DRESS: a structure footprint blocks like a wall — screen-local occupancy, Layout untouched.
	if (
		not OverworldTileSetScript.is_walkable(_layout.get_cell(target.x, target.y))
		or _structures.blocks(target)
	):
		_motion.thunk(dir, _cell_center(_player_cell))
		_ambience.on_blocked(_lead)
		return {"encounter": false, "moved": false}
	var prev_px := _cell_center(_player_cell)
	_player_cell = target
	_set_facing(dir)
	# Wave 6: the LOGIC above is done instantly; only the token's VISUAL position glides.
	_motion.step_to(_cell_center(_player_cell))
	# The lead cameo trails into the tile the tamer just left (smoothed in _process).
	if _lead != null:
		_lead_target = prev_px
	# W13 small life: whisper/alert-hop/NPC flips + critter recycling; re-mood on veil transitions.
	if _ambience.on_step(_layout, _lead, _npcs, _player_cell):
		_refresh_mood()
	_critters.recycle_far(_player_cell)
	var step_index := int(_game.call("advance_step"))
	_ambient_step_tick(step_index)
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
	# W13 thin-place gating: the stepped cell's class picks the encounter surface (~0.30 on the
	# shimmering ritual cells, ~0.04 elsewhere) and salts the canonical stream.
	var roll := _director.roll_step(step_index, tile_class_at(_player_cell))
	roll["moved"] = true
	roll["graced"] = false
	if bool(roll.get("encounter", false)):
		_dispatch_roll(roll)
	return roll


## Build the deterministic boss encounter for `step_index` IF the climax should fire now, else {}.
## Reads the cleared flag from the run so a cleared slice never re-triggers the boss, and the Wave-3
## ONE-SHOT lair flag so a lost/fled boss fight never re-ambushes on every later step (the flag is
## set the moment the lair fires + persisted by the pre-battle autosave). E1b: the threshold check
## reads the steps explored IN this region (region_steps ledger) — a well-walked run arriving
## through the Threshold network starts the new region's climax count at zero — while the boss
## SEED stays on the global step index (its canonical stream is untouched).
func _maybe_boss(step_index: int) -> Dictionary:
	if _director == null or _game == null:
		return {}
	var cleared := false
	if _game.has_method("slice_cleared"):
		cleared = bool(_game.call("slice_cleared"))
	var run := _run_ctx()
	var fired := OverworldLoopStateScript.boss_fired(run, _region_id())
	var explored := RegionTravelScript.explored_steps(run, _region_id())
	if not _director.should_trigger_boss(explored, cleared, fired):
		return {}
	OverworldLoopStateScript.mark_boss_fired(run, _region_id())
	return _director.boss_step(step_index)


## W16b: the per-step AMBIENT content tick — proximity barks (a hard >=25-step world_state
## cooldown between ANY two, silent during dialogue) plus the cursed trinket's deterministic
## follow-up screams. State lives on the run; the content lives in OverworldBarks/Peculiars.
func _ambient_step_tick(step_index: int) -> void:
	var run := _run_ctx()
	if run == null:
		return
	OverworldBarks.step_tick(self, run, step_index)
	OverworldPeculiars.tick_bag_scream(run, step_index, get_node_or_null("/root/Toast"))


## The active RunContext, or null (single accessor for the many world_state read/write sites).
func _run_ctx() -> RunContext:
	if _game == null or not _game.has_method("run"):
		return null
	return _game.call("run")


## The active region id, or "" without a game.
func _region_id() -> String:
	return str(_game.call("active_region")) if _game != null else ""


## Route a FIRED wild roll by kind: peculiars go to the W16b seam and never become a battle;
## battle kinds (misbehaviors included — "the veil coughs" announces the too-big draw) hand off.
func _dispatch_roll(roll: Dictionary) -> void:
	if str(roll.get("kind", "")) == EncounterDirectorScript.KIND_PECULIAR:
		peculiar_encounter(roll)
		return
	if bool(roll.get("misbehavior", false)):
		OverworldBarks.toast_misbehavior(self)
	_on_encounter(roll)


## W13 seam for W16b: a PECULIAR encounter is a non-battle beat. No pending_battle stash, no
## autosave, no grace, NEVER the battle scene — it emits peculiar_encountered and calls the
## static peculiar_hook (screen, roll) when the content wave has wired one.
func peculiar_encounter(roll: Dictionary) -> void:
	peculiar_encountered.emit(roll)
	if not peculiar_hook.is_valid():
		# Default content resolver (W16b). Tests overwrite/clear the seam explicitly.
		peculiar_hook = OverworldPeculiars.play
	peculiar_hook.call(self, roll)


## The EncounterDirector tile class of a cell (TILE_CLASS_THIN on the visible ritual-accent
## cells, "" elsewhere) — public for tests + siblings; the same pure mapping the shimmer uses.
func tile_class_at(cell: Vector2i) -> String:
	return OverworldAmbience.tile_class_at(_layout, cell)


func _on_encounter(roll: Dictionary) -> void:
	# Wild fight: Capture/Flee available (Slice 2).
	var extra := {"is_wild": true}
	if bool(roll.get("misbehavior", false)):
		extra["misbehavior"] = true
	_stash_and_hand_off(roll, extra)


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
	# W18 save trust: the witnessed save path first (SaveSentry surfaces the outcome).
	if _game != null and _game.has_method("request_save"):
		_game.call("request_save")
	elif _game != null and _game.has_method("save_run"):
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
	# Wave 6: suppress per-tile glides — the dash lands as ONE accelerated whoosh + ghosts.
	_motion.dash_begin()
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
		_set_facing(dir)
		OverworldAmbience.dash_trail(_player, _last_dir)
	_motion.dash_finish(_cell_center(_player_cell), crossed > 0)
	if crossed > 0 and not stopped and not landing_graced and last_step >= 0:
		# The landing roll folds the LANDING cell's class in — dashing onto a thin place meets
		# exactly what walking onto it would have met (W13).
		var roll := _director.roll_step(last_step, tile_class_at(_player_cell))
		if bool(roll.get("encounter", false)):
			_dispatch_roll(roll)
	return crossed


# === input -> discrete grid steps ============================================================= #


func _process(delta: float) -> void:
	# The lead cameo eases toward its trailing target every frame (independent of input/busy state).
	if _lead != null:
		_lead.position = _lead.position.lerp(_lead_target, clampf(delta * 9.0, 0.0, 1.0))
	if _busy or _in_dialogue or _input == null or _layout == null:
		return
	# W17/E1b: while the camp or the Threshold travel circle is open, the overworld takes NO
	# input — the arrows walk the menu focus, not the tamer under the scrim.
	if is_instance_valid(_camp_overlay) or is_instance_valid(_threshold_screen):
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
	# Wave 6: stepping is paced by tween-chaining + input buffering (turn-in-place taps only
	# pivot; a hold walks). OverworldMotion falls back to the wall-clock cooldown headless.
	_motion.tick(delta, _read_step_dir())


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


## Create the Y-SORTED world root once (Wave 12). It rides z 1 so it always draws above the
## ground TileMapLayer (z 0) regardless of child order across rebuilds; INSIDE it, draw order
## is pure Y — props and actors all sit at z 0 with feet-level origins (OverworldDepth).
func _ensure_world_root() -> void:
	if _world == null or not is_instance_valid(_world):
		_world = OverworldDepthScript.make_world_root(self)


## The painterly horizon behind the tile field (Wave 12): the force's blurred backdrop strip on
## a Parallax2D drifting at ~0.15 scroll, over an ink backing plate (see OverworldDepth).
func _setup_horizon() -> void:
	OverworldDepthScript.setup_horizon(self, _force_climate, _layout)


func _render_layout() -> void:
	if _tile_layer != null:
		_tile_layer.queue_free()
	_tile_layer = TileMapLayer.new()
	_tile_layer.name = "RegionTiles"
	_tile_layer.z_index = 0  # ground plane: always under the y-sorted world root (z 1)
	_tile_layer.tile_set = OverworldTileSetScript.build(_force_climate)
	add_child(_tile_layer)
	OverworldTileSetScript.paint(_tile_layer, _layout)
	# W13: the veil shimmer marks every thin-place cell (added AFTER the tile layer so the ground
	# glow draws over the tiles, still under the y-sorted world at z 1).
	_shimmer = OverworldAmbience.build_shimmer(self, _shimmer, _layout)
	_scatter_props()


## Prop decals on feature cells (OverworldDepth.scatter_props): deterministic set dressing in a
## y-sorted holder with feet-level origins, so tall props occlude actors walking behind them.
func _scatter_props() -> void:
	if _layout == null:
		return
	_ensure_world_root()
	_props = OverworldDepthScript.scatter_props(_world, _props, _layout, _force_climate)


## W-DRESS: landmark STRUCTURES (temple / ruin / stall / the boss-lair altar...) on deterministic
## feature-cell clusters, y-sorted with actors; their footprints join the screen-local blocked
## set try_move consults. Placement anchors on the CANONICAL spawn — stable across battles.
func _build_structures() -> void:
	if _layout == null:
		return
	_ensure_world_root()
	_structures.build(_world, _layout, _force_climate, OverworldSpawnScript.spawn_cell(_layout))


func _spawn_player() -> void:
	_home_cell = OverworldSpawnScript.spawn_cell(_layout)
	# Wave 3 position persistence: prefer the pre-battle cell + facing stashed by the autosave (when
	# present + walkable) so a post-battle/reloaded overworld puts the player exactly where the fight
	# started — never back at spawn. Falls back to the canonical spawn.
	_player_cell = OverworldLoopStateScript.restore_cell(_run_ctx(), _layout, _home_cell)
	if _structures.blocks(_player_cell):
		_player_cell = _home_cell  # a structure claimed the stashed cell: fall back to spawn
	_last_dir = OverworldLoopStateScript.restore_facing(_run_ctx(), _last_dir)
	if _player == null:
		_player = Node2D.new()
		_player.name = "Player"
		# Wave 12: z stays 0 — the medallion lies flat on the ground, so its cell-centre origin is
		# its ground contact and the WorldYSort parent decides occlusion against props/actors.
		var token := Sprite2D.new()
		token.name = "Token"
		token.texture = OverworldTokensScript.player_token(
			int(OverworldTileSetScript.TILE_SIZE * 0.92)
		)
		_player.add_child(token)
		# One warm brass PointLight2D (Wave 12) — shades the normal-mapped ground (OverworldDepth).
		OverworldDepthScript.attach_player_glow(_player)
		_ensure_world_root()
		_world.add_child(_player)
	_motion.setup(_player, try_move, _set_facing, _get_facing)
	_position_player()


## Spawn the lead-creature cameo (glue lives in OverworldDepth — line cap). No-op without art.
func _spawn_lead_creature() -> void:
	if _lead != null:
		return
	_ensure_world_root()
	_lead = OverworldDepthScript.spawn_lead_cameo(_game, _world, _player_cell, _last_dir)
	if _lead != null:
		_lead_target = _lead.position


## Wave 13: the AtmosphereLayer owns ALL fullscreen atmosphere — ONE grade+vignette pass + ONE
## fog pass (tension 9) — and drives the world CanvasModulate; the spore-motes stay. It rides
## CanvasLayer 1: above the world, below the HUD (2), so text never grades. Idempotent.
func _setup_atmosphere() -> void:
	OverworldDepthScript.setup_motes(_player)
	if _atmosphere == null or not is_instance_valid(_atmosphere):
		_atmosphere = AtmosphereLayerScene.instantiate()
		add_child(_atmosphere)
	_atmosphere.attach_world_tint(OverworldDepthScript.ensure_world_tint(self))


## Push the run's corruption + the walk's veil-dread into the atmosphere and the HUD pip —
## called on build (which covers every post-battle rebuild), on veil transitions while walking,
## and when a quest effect raises corruption. Corruption visibly regrades the whole world.
func _refresh_mood() -> void:
	var near := OverworldAmbience.near_thin(_layout, _player_cell)
	OverworldAmbience.refresh_mood(_atmosphere, _pip, _run_ctx(), _force_climate, near)


## The mood layer (for tests + sibling waves).
func atmosphere_layer() -> AtmosphereLayer:
	return _atmosphere


## The grimoire HUD (region title panel, quest tracker, controls chip, W13 corruption pip) —
## built by OverworldHud (line-cap extraction); the screen keeps the stateful nodes.
func _setup_hud() -> void:
	var parts := OverworldHud.build(self, _input, _region_id())
	_objective_label = parts["objective"]
	_controls_chip = parts["chip"]
	_pip = parts["pip"]
	_refresh_objective()


## Update the HUD quest tracker to the active quest's current objective (hidden when no quest is active).
func _refresh_objective() -> void:
	_refresh_markers()
	if _objective_label == null:
		return
	var text := OverworldHud.active_objective(_quests)
	_objective_label.text = text
	_objective_label.visible = text != ""


## W-DRESS: sync the floating NPC quest markers + the boss-lair ember to the LIVE quest state —
## on build and every quest transition, never mid-dialogue (deferred to dialogue-finished so a
## playing scene never has markers popping under it).
func _refresh_markers() -> void:
	if _in_dialogue:
		return
	QuestMarkers.refresh(_npcs, _quests)
	QuestMarkers.refresh_lair(_structures.lair(), _quests)


## Snap the token to its cell centre (spawn/restore placement; steps GLIDE via OverworldMotion).
func _position_player() -> void:
	if _player == null:
		return
	_player.position = _cell_center(_player_cell)


## Pixel centre of a grid cell — the token's rest position on that tile.
func _cell_center(cell: Vector2i) -> Vector2:
	var s := OverworldTileSetScript.TILE_SIZE
	return Vector2(cell.x * s + s / 2.0, cell.y * s + s / 2.0)


## Pivot: set facing, flip the lead cameo to the faced side, lean the camera ahead. Called by a
## turn-in-place tap (via OverworldMotion) and by every real step/dash.
func _set_facing(dir: Vector2i) -> void:
	if dir == Vector2i.ZERO:
		return
	_last_dir = dir
	if _lead != null and dir.x != 0:
		_lead.flip_h = dir.x < 0
	OverworldCameraRig.set_lookahead(_cam_rig, _lookahead_dir())


func _get_facing() -> Vector2i:
	return _last_dir


## The camera look-ahead direction: the last walk direction, or ZERO under reduce_motion (the
## lean is a constant drift some players switch off).
func _lookahead_dir() -> Vector2i:
	return Vector2i.ZERO if OverworldMotionScript.reduce_motion() else _last_dir


## Attach a PhantomCamera2D following the player. Fully guarded: if the addon classes are missing
## (stripped build / headless import quirk) it falls back to a plain Camera2D so the scene still
## builds and the slice never errors. Wave 6/C8: SIMPLE follow + damping + look-ahead (rig kept).
func _setup_camera() -> void:
	_cam_rig = OverworldCameraRig.setup(self, _player, _layout_pixel_rect(), CAMERA_ZOOM)
	OverworldCameraRig.set_lookahead(_cam_rig, _lookahead_dir())


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
	OverworldDepthScript.free_cast(_npcs)  # a rebuild re-spawns the cast; no stale twins
	_npcs.clear()
	if _layout == null:
		return
	if _quests == null:
		_quests = QuestService.new()
		_quests.register(_quest_defs())  # all overworld quests (MARSH/MELON/BRAMBLE/...) in one place
		_restore_quests()
	_sync_boss_goal_quest()
	# E1b: the shipped Verdant/Act-0 cast rides the starting region; other regions travel with
	# empty casts until the regional-cast ingest wave places theirs (OverworldContent, pure data).
	var defs: Array = OverworldContent.npc_defs_for(_region_id())
	var cells := OverworldSpawnScript.npc_cells(
		_layout, _home_cell, defs.size(), _structures.blocked()
	)
	for i in mini(cells.size(), defs.size()):
		var def: Dictionary = defs[i]
		var cell: Vector2i = cells[i]
		var node := Node2D.new()
		node.name = "NPC_%s" % str(def["name"]).replace(" ", "")
		# W-DRESS: NPCs are CHARACTERS now — hooded figures / creature cutouts / the signpost
		# (NpcFigures), feet-origined at the cell centre so WorldYSort owns the draw order.
		var s := OverworldTileSetScript.TILE_SIZE
		node.position = Vector2(cell.x * s + s / 2.0, cell.y * s + s / 2.0)
		var token := NpcFigures.npc_sprite(def, s)
		node.add_child(token)
		_ensure_world_root()
		_world.add_child(node)
		if not bool(def.get("sign", false)):
			NpcFigures.attach_sway(token, str(def["name"]))
		# Carry ALL of the def's keys (name/timeline/ring + every quest step_key) so the data-driven
		# quest dispatch sees each NPC's steps — a new quest's step_key needs no change here.
		var entry: Dictionary = def.duplicate(true)
		entry["cell"] = cell
		entry["node"] = node
		_npcs.append(entry)
	_refresh_markers()


## If the tamer stands on/next to an NPC, speak to it and return its timeline id; else "". E1b:
## standing beside the region's WAYGATE structure (the ritual circle) instead opens the Threshold
## travel overlay and returns its token. Drives the INTERACT action from _process.
func try_interact() -> String:
	for i in _npcs.size():
		var npc: Dictionary = _npcs[i]
		var cell: Vector2i = npc["cell"]
		if (cell - _player_cell).length() <= 1.5:
			return speak_to(i)
	if _structures.waygate_adjacent(_player_cell):
		open_threshold()
		return "threshold_network"
	return ""


## Play NPC `index`'s authored Dialogic timeline (a funny-grim beat) + a toast. Returns the timeline
## id (or ""). Public + headless-safe (DialogicFacade resolves immediately under --headless), so a
## test can assert the beat fires. Movement is suspended until the scene finishes.
func speak_to(index: int) -> String:
	if index < 0 or index >= _npcs.size():
		return ""
	var npc: Dictionary = _npcs[index]
	# W16b: signs READ (the fourth-wall signpost, once per run); NPCs talked dry a 5th+ time
	# swap to the authored out-of-lines bark instead of a scene replay (quest steps included —
	# the dispatch below still runs; a choice-holding NPC keeps its scene until resolved).
	if bool(npc.get("sign", false)):
		return OverworldBarks.read_signpost(self, npc, _run_ctx(), _game)
	var timeline := str(npc["timeline"])
	var choice_conf: Dictionary = npc.get("choice", {})
	if OverworldBarks.swap_out_of_lines(self, npc, _run_ctx()):
		_advance_quest_for(npc)
		return timeline
	if _dialogue == null:
		_dialogue = DialogicFacade.new()
	# Connect idempotently BEFORE play so a first-talk signal can never be missed (review P2.3).
	if not _dialogue.scene_finished.is_connected(_on_dialogue_finished):
		_dialogue.scene_finished.connect(_on_dialogue_finished)
	# W16a: authored `- choice` branches report back as choice_made(scene_id, branch_tag);
	# the branch — not the talk — advances a choice-driven quest step (Old Garran / SQ-05).
	if not _dialogue.choice_made.is_connected(_on_dialogue_choice):
		_dialogue.choice_made.connect(_on_dialogue_choice)
	_in_dialogue = true
	_advance_quest_for(npc)
	dialogue_started.emit(timeline)
	# Headless there is no choice UI, so the NPC's canon branch resolves instantly (the
	# facade emits choice_made before scene_finished) — quests stay completable in CI.
	_dialogue.play_timeline(timeline, str(choice_conf.get("headless_branch", "")))
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


## W16a: a Dialogic choice resolved (scene_id = the timeline id, branch_tag = the authored
## branch tag from `[signal arg="choice:<tag>"]`). The branch — never the mere talk —
## advances the quest step; dispatch + branch effects/toast live in OverworldChoices.
func _on_dialogue_choice(scene_id: String, branch_tag: String) -> void:
	OverworldChoices.handle(self, _npcs, scene_id, branch_tag)


## Start `quest_id` on the first talk that names a step, advance to that step, and toast the ledger
## on a real advance. On a real advance the step's (and, on completion, the quest's) gameplay effect
## is applied to the PERSISTED run, and quest progress is serialized + saved — so standing/corruption
## actually accrue and survive reload (review P1.1 + Codex #37). No-op when the NPC drives no step.
## Returns true only on a REAL advance (W16a: choice branches key their effects off this).
## `toast_on_advance` = false lets a caller substitute its own richer toast for the generic one.
func _advance_quest_step(quest_id: String, step: String, toast_on_advance := true) -> bool:
	if step == "":
		return false
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
		return false
	_persist_quests()
	_refresh_objective()  # keep the HUD tracker in step with the quest the player just moved
	# Only a real advance is a player-facing "quest update"; a bare start with no advance is silent.
	if advanced and toast_on_advance:
		var toast := get_node_or_null("/root/Toast")
		if toast != null and toast.has_method("event"):
			toast.call("event", "quest_update")
	return advanced


## Wave 3 (red-team C13): the BOSS-GOAL quest is active from RUN START (no NPC gives it — started
## here on every build until it sticks) and completes through the existing quest_state flags path
## the moment the slice reads cleared (a played boss win sets the victory flag via
## GameController._mark_slice_cleared). Surfaces the run's goal in the Phase-13c HUD tracker.
## E1b: the quest is the VERDANT slice's goal — it only syncs (starts/advances) while the run
## stands in the starting region; another region's boss clear must never complete it.
func _sync_boss_goal_quest() -> void:
	if _quests == null or _region_id() != EncounterCatalog.STARTING_REGION:
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
	return OverworldQuestsGlue.quest_def_by_id(quest_id)


func _quest_step_effect(quest_id: String, step_id: String) -> Dictionary:
	return OverworldQuestsGlue.quest_step_effect(quest_id, step_id)


func _apply_effect_to_run(effect: Dictionary) -> void:
	if OverworldQuestsGlue.apply_effect_to_run(_game, effect):
		_refresh_mood()  # W13: the grade + the HUD pip react the moment the rot moves


func _persist_quests() -> void:
	OverworldQuestsGlue.persist_quests(_game, _quests)


func _restore_quests() -> void:
	OverworldQuestsGlue.restore_quests(_game, _quests)


func _on_dialogue_finished(_timeline_id: String) -> void:
	_in_dialogue = false
	_refresh_markers()  # the deferred marker sync (never during the scene itself)


## Intro-quest state accessors (for tests + a future quest-log UI).
## The HUD quest-tracker text (the active quest's current objective, or "" when none). For tests +
## observers; computed live from QuestService so it never lags the label node.
func objective_text() -> String:
	return OverworldHud.active_objective(_quests)


func quest_active(quest_id: String) -> bool:
	return _quests != null and _quests.is_active(quest_id)


func quest_done(quest_id: String) -> bool:
	return _quests != null and _quests.is_done(quest_id)


# === accessors (for tests + sibling slices) ================================================== #


## The number of NPCs placed in the region (for tests).
func npc_count() -> int:
	return _npcs.size()


## The y-sorted world root holding props + player + NPCs + the lead cameo (for tests + waves).
func world_root() -> Node2D:
	return _world


## The HUD controls chip node (for tests + future waves).
func controls_chip() -> Node:
	return _controls_chip


## The Beehave ambient-critter holder under the world root (for tests — W13/C15).
func critters_root() -> Node2D:
	return _critters.holder()


## The HUD corruption sigil pip (for tests — W13).
func corruption_pip() -> Control:
	return _pip


## The veil-shimmer marker holder (for tests — W13).
func veil_shimmer() -> Node2D:
	return _shimmer


## The landmark-structures kit: plan / blocked-set / holder / lair (for tests — W-DRESS).
func structures() -> OverworldStructures:
	return _structures


func player_cell() -> Vector2i:
	return _player_cell


func layout() -> Layout:
	return _layout
