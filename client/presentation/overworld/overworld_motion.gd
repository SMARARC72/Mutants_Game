class_name OverworldMotion
extends RefCounted
## OverworldMotion (Wave 6 "Motion & Camera Feel") — the overworld's VISUAL motion + input-pacing
## authority, extracted from overworld_screen to keep it under the lint line cap.
##
## CONTRACT: try_move()/grid logic in the screen stays SYNCHRONOUS — `_player_cell`, the step
## counter and the deterministic per-step encounter roll all update instantly (tests call try_move
## directly and never pump _process). ONLY the player token's visual position animates here:
##   * STEP GLIDE: each step is a short TRANS_SINE/EASE_OUT position tween; the step RATE is gated
##     by tween-chaining — a direction pressed during the final ~40% of the current glide BUFFERS
##     the next step, so held walking is a continuous glide with zero stutter;
##   * TURN-IN-PLACE: a fresh tap on a NEW direction only pivots facing; held >80ms it steps;
##   * BLOCKED THUNK: a blocked move nudges 4-5px toward the wall + the interim ui_click;
##   * DASH: one continuous accelerated whoosh + 3 fading afterimage ghosts (freed on finish).
## HEADLESS/TEST SAFETY: when the tree can't animate (headless display, node outside the tree,
## accessibility reduce_motion, or the `instant_moves` test flag) every motion applies INSTANTLY
## and the classic wall-clock cooldown becomes the step-rate gate — all existing overworld tests
## stay green unmodified. No canonical RNG anywhere here (presentation only).

const STEP_TIME := 0.115  # seconds per grid-step glide (the 0.11-0.12 grid-feel band)
const BUFFER_AT := 0.6  # a direction pressed after this fraction of the glide buffers the next step
const TURN_HOLD := 0.08  # seconds a NEW direction must be held before the pivot becomes a step
const THUNK_TIME := 0.06
const THUNK_PX := 4.5  # blocked-move nudge distance toward the wall (4-5px)
const THUNK_REST_MS := 200  # animated-path re-trigger gate: a held wall bumps, never buzzes
const DASH_TIME := 0.22  # the whole dash is ONE accelerated whoosh, not per-tile hops
const GHOST_COUNT := 3
const GHOST_FADE := 0.38  # base afterimage fade; later ghosts linger slightly longer
const STEP_COOLDOWN := 0.14  # instant-mode fallback rate gate (headless / reduce_motion)

## Test flag: force instant placement (position applies synchronously, no tweens ever).
var instant_moves := false

var _player: Node2D = null
var _step: Callable = Callable()  # (dir: Vector2i) — the screen's SYNCHRONOUS try_move
var _face: Callable = Callable()  # (dir: Vector2i) — facing-only pivot on the screen
var _facing: Callable = Callable()  # () -> Vector2i — the screen's current facing
var _step_tween: Tween = null
var _thunk_tween: Tween = null
var _buffered := Vector2i.ZERO  # the queued next step (pressed during the glide's final stretch)
var _held := Vector2i.ZERO
var _held_time := 0.0
var _pivot_hold := false  # the current hold began as a turn-in-place (a NEW direction)
var _cooldown := 0.0  # instant-mode step-rate gate
var _last_thunk_ms := -THUNK_REST_MS  # animated-path thunk re-trigger clock
var _dashing := false
var _dash_from := Vector2.ZERO


## Wire the module to the screen. Idempotent — safe to call on every build_from_game.
func setup(player: Node2D, step_cb: Callable, face_cb: Callable, facing_cb: Callable) -> void:
	_player = player
	_step = step_cb
	_face = face_cb
	_facing = facing_cb


## True when tweens can actually run AND the player wants them; its inverse is the instant
## fallback. Checked per motion, so a live reduce_motion change applies immediately.
func can_animate() -> bool:
	if instant_moves or _player == null or not _player.is_inside_tree():
		return false
	if DisplayServer.get_name() == "headless":
		return false
	return not reduce_motion()


## The Settings `accessibility.reduce_motion` toggle (safe without the autoload).
static func reduce_motion() -> bool:
	var loop := Engine.get_main_loop()
	if not (loop is SceneTree):
		return false
	var settings := (loop as SceneTree).root.get_node_or_null("Settings")
	if settings == null:
		return false
	return bool(settings.call("get_value", "accessibility", "reduce_motion", false))


## Per-frame input pacing — replaces the old STEP_COOLDOWN wall-clock gate. `held` is the
## direction currently read from input (ZERO when none). Turn-in-place on a fresh tap of a
## new direction; step on a hold; buffer during the glide's final stretch.
func tick(delta: float, held: Vector2i) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if held == Vector2i.ZERO:
		_held = Vector2i.ZERO
		_held_time = 0.0
		_pivot_hold = false
		return
	if held != _held:
		_held = held
		_held_time = 0.0
		_pivot_hold = held != Vector2i(_facing.call())
		if _pivot_hold:
			_face.call(held)  # a fresh tap on a NEW direction only sets facing
			return
		_request_step(held)
		return
	_held_time += delta
	if _pivot_hold and _held_time < TURN_HOLD:
		return  # still inside the tap window: pivoted, not yet walking
	_request_step(held)


## The visual half of a successful step: footstep + glide toward the new cell centre. The
## logic half (cell / step counter / encounter roll) already happened synchronously.
func step_to(target: Vector2) -> void:
	if _dashing:
		return  # the dash animates ONCE at its landing (one whoosh, not three hops)
	_play_footstep()
	if _player == null:
		return
	_kill(_thunk_tween)
	_thunk_tween = null
	_kill(_step_tween)
	if not can_animate():
		_player.position = target
		return
	_step_tween = _player.create_tween()
	(
		_step_tween
		. tween_property(_player, "position", target, STEP_TIME)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_OUT)
	)
	_step_tween.finished.connect(_on_step_finished)


## Blocked move: a 0.06s 4-5px nudge toward the wall + the interim ui_click thunk (W-SND).
## Never touches the grid cell. Instant mode always records the click (the input-driven
## cooldown already rate-gates it); the animated path is re-trigger-gated so a HELD direction
## into a wall bumps rhythmically instead of buzzing every frame.
func thunk(dir: Vector2i, cell_center: Vector2) -> void:
	if _dashing:
		return  # the dash stopping at a wall is already one whoosh, not a bump
	if not can_animate():
		_click()
		return
	if _step_tween != null and _step_tween.is_valid() and _step_tween.is_running():
		return
	if _thunk_tween != null and _thunk_tween.is_valid() and _thunk_tween.is_running():
		return
	var now := Time.get_ticks_msec()
	if now - _last_thunk_ms < THUNK_REST_MS:
		return
	_last_thunk_ms = now
	_click()
	var out := cell_center + Vector2(dir) * THUNK_PX
	_thunk_tween = _player.create_tween()
	(
		_thunk_tween
		. tween_property(_player, "position", out, THUNK_TIME * 0.5)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_OUT)
	)
	(
		_thunk_tween
		. tween_property(_player, "position", cell_center, THUNK_TIME * 0.5)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN)
	)


## Mark a sigil-dash in flight: per-tile glides/footsteps/thunks are suppressed until
## dash_finish plays the single whoosh.
func dash_begin() -> void:
	_dashing = true
	_dash_from = _player.position if _player != null else Vector2.ZERO


## One continuous accelerated whoosh to the landing cell + fading afterimage ghosts.
## Instant fallback (headless / reduce_motion — ghosts skipped) applies the landing directly.
func dash_finish(target: Vector2, moved: bool) -> void:
	_dashing = false
	if _player == null or not moved:
		return
	_kill(_step_tween)
	if not can_animate():
		_player.position = target
		return
	_spawn_ghosts(target)
	_step_tween = _player.create_tween()
	(
		_step_tween
		. tween_property(_player, "position", target, DASH_TIME)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN)
	)
	_step_tween.finished.connect(_on_step_finished)


## Step now if the glide chain is free; else buffer it during the final ~40% of the glide.
## Instant mode keeps the classic wall-clock cooldown as the rate gate.
func _request_step(dir: Vector2i) -> void:
	if not can_animate():
		if _cooldown > 0.0:
			return
		_cooldown = STEP_COOLDOWN
		_step.call(dir)
		return
	if _step_tween != null and _step_tween.is_valid() and _step_tween.is_running():
		if _step_tween.get_total_elapsed_time() >= STEP_TIME * BUFFER_AT:
			_buffered = dir
		return
	_step.call(dir)


## Glide finished: chain the buffered step immediately (continuous held-walk, zero stutter).
func _on_step_finished() -> void:
	_step_tween = null
	if _buffered == Vector2i.ZERO:
		return
	var dir := _buffered
	_buffered = Vector2i.ZERO
	_step.call(dir)  # try_move runs synchronously and glides again


## Three token afterimages along the dash path, alpha-fading and freed on finish.
func _spawn_ghosts(target: Vector2) -> void:
	var parent := _player.get_parent()
	var token := _player.get_node_or_null("Token") as Sprite2D
	if parent == null or token == null or token.texture == null:
		return
	for i in GHOST_COUNT:
		var ghost := Sprite2D.new()
		ghost.texture = token.texture
		ghost.z_index = 19  # under the live token (20)
		ghost.position = _dash_from.lerp(target, float(i + 1) / float(GHOST_COUNT + 1))
		ghost.modulate = Color(1.0, 1.0, 1.0, 0.5 - 0.09 * i)
		parent.add_child(ghost)
		var fade := ghost.create_tween()
		fade.tween_property(ghost, "modulate:a", 0.0, GHOST_FADE + 0.07 * i)
		fade.tween_callback(ghost.queue_free)


func _play_footstep() -> void:
	var sfx := _sfx()
	if sfx != null and sfx.has_method("play_footstep"):
		sfx.call("play_footstep")


## The interim wall-thunk sound (W-SND ui_click at a 0.2 pitch jitter, headless-recorded).
func _click() -> void:
	var sfx := _sfx()
	if sfx != null and sfx.has_method("play"):
		sfx.call("play", "ui_click", 0.2)


static func _sfx() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("SfxService")
	return null


static func _kill(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
