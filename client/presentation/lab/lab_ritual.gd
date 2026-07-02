extends Control
## LabRitual (Wave 15) — the HOLD-TO-SEAL brass progress ring the commit verb wears. The seal is
## PLAYER-DRIVEN ceremony and therefore exempt from fast-forward (plan tension 10): holding
## CONFIRM/click for HOLD_TIME fills a draw_arc ring; releasing early SNUFFS it (the arc dies to
## a cooling ember stub) and nothing commits.
##
## PRESENTATION ONLY, deliberately dumb: a tiny (progress, holding) state machine + a _draw().
## The screen connects `sealed` to the real commit. HEADLESS/instant mode never runs _process —
## tests drive tick() directly with explicit deltas, so the machine's truth (fill rate, snuff,
## completion) is asserted without a frame loop (the battle_beats instant pattern).

signal sealed
signal snuffed

## Seconds of held CONFIRM/click a seal demands. Player-driven — NOT scaled by Swift Rites.
const HOLD_TIME := 0.9
const RING_WIDTH := 3.0

var _holding := false
var _progress := 0.0  # 0..1 fill
var _ember := 0.0  # snuff after-glow, decays (juice only)
var _juice := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


## Animated mode on/off. Off (headless/reduce_motion) the ring never self-ticks — the state
## machine still works via tick().
func set_juice(on: bool) -> void:
	_juice = on
	if not on:
		set_process(false)


## Start the hold (button_down / CONFIRM press). Resets any prior fill.
func begin_hold() -> void:
	if _holding:
		return
	_holding = true
	_progress = 0.0
	_ember = 0.0
	if _juice:
		set_process(true)
	queue_redraw()


## Release before the ring closes => SNUFF: progress dies, `snuffed` fires, no seal. A release
## after completion is a no-op (the seal already fired).
func release_hold() -> void:
	if not _holding:
		return
	_holding = false
	_progress = 0.0
	if _juice:
		_ember = 1.0  # the cooling stub _process fades out
	else:
		set_process(false)
	snuffed.emit()
	queue_redraw()


## Advance the hold by `delta` seconds. Public so instant/headless tests drive the machine
## directly. Emits `sealed` exactly once when the ring closes.
func tick(delta: float) -> void:
	if not _holding:
		return
	_progress = minf(1.0, _progress + delta / HOLD_TIME)
	queue_redraw()
	if _progress >= 1.0:
		_holding = false
		sealed.emit()


## True while the hold is filling.
func is_holding() -> bool:
	return _holding


## Current fill, 0..1 (0 after a snuff; sticks at 1 for the frame the seal fires).
func progress() -> float:
	return _progress


func _process(delta: float) -> void:
	if _holding:
		tick(delta)
	if _ember > 0.0:
		_ember = maxf(0.0, _ember - delta * 2.5)
		queue_redraw()
	if not _holding and _ember <= 0.0:
		set_process(false)


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - RING_WIDTH
	if radius <= 2.0:
		return
	if _holding or _progress > 0.0:
		# Faint full track under the filling brass arc, crown-first (12 o'clock).
		draw_arc(center, radius, 0.0, TAU, 40, Color(GrimoirePalette.BRASS, 0.28), RING_WIDTH)
		if _progress > 0.0:
			var sweep := TAU * _progress
			var points := maxi(8, int(40.0 * _progress))
			draw_arc(
				center,
				radius,
				-PI / 2.0,
				-PI / 2.0 + sweep,
				points,
				GrimoirePalette.BRASS_BRIGHT,
				RING_WIDTH
			)
	elif _ember > 0.0:
		# The snuff: a dying ember stub where the arc began.
		draw_arc(
			center,
			radius,
			-PI / 2.0,
			-PI / 2.0 + TAU * 0.12,
			8,
			Color(GrimoirePalette.WARNING, 0.6 * _ember),
			RING_WIDTH
		)
