extends Control
## EntropyDial (Wave 10 commit 3 — "Entropy Crescendo") — the radial entropy readout beside the
## turn label: a draw_arc ring that fills clockwise and heats PARCHMENT -> EMBER as the
## battlefield's entropy climbs toward the engine's turn-cap ceiling.
##
## PRESENTATION-only. set_entropy() receives the SESSION's live entropy multiplier (the oracle
## loop's own number — Wave 3 deleted all duplicated local math); normalized() maps it onto 0..1
## against the Constants-derived maximum (turn_cap / entropy_step_per_turn) — a display mapping,
## never a combat computation. Colour comes from GrimoirePalette (no hexes); a static _draw
## keeps it headless-free (no per-frame work, redraw only on change).

const RING_WIDTH := 3.0
const DIAL_SIZE := 22.0
const ARC_POINTS := 40

var _t := 0.0  # normalized fill 0..1
var _ent := 1.0  # the raw session multiplier (tooltip/debug read)


func _init() -> void:
	custom_minimum_size = Vector2(DIAL_SIZE, DIAL_SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Feed the session's live entropy multiplier (1.0 on turn 1). Returns the normalized fill —
## the screen fans the same value out to the grade warmth / JuiceDirector heat / music swell.
func set_entropy(entropy: float) -> float:
	_ent = entropy
	_t = normalized(entropy)
	queue_redraw()
	return _t


## Map an entropy multiplier onto 0..1 against the ENGINE's own ceiling: 1.0 at turn 1 up to
## 1 + (turn_cap - 1) * entropy_step_per_turn at the cap (both single-sourced from Constants).
static func normalized(entropy: float) -> float:
	var sb: Dictionary = Constants.BALANCE["skill"]
	var max_ent := 1.0 + (float(int(sb["turn_cap"])) - 1.0) * float(sb["entropy_step_per_turn"])
	if max_ent <= 1.0:
		return 0.0
	return clampf((entropy - 1.0) / (max_ent - 1.0), 0.0, 1.0)


## The current normalized fill (test surface: the dial value follows the session).
func value() -> float:
	return _t


## The raw session multiplier last fed in.
func entropy() -> float:
	return _ent


func _draw() -> void:
	var c := size * 0.5
	if c == Vector2.ZERO:
		c = custom_minimum_size * 0.5
	var radius := minf(c.x, c.y) - RING_WIDTH
	if radius <= 0.0:
		return
	# The cold track ring, then the heated fill arc from 12 o'clock, clockwise.
	draw_arc(
		c,
		radius,
		-PI / 2.0,
		-PI / 2.0 + TAU,
		ARC_POINTS,
		GrimoirePalette.INK_HOVER,
		RING_WIDTH,
		true
	)
	if _t <= 0.0:
		return
	var col := GrimoirePalette.PARCHMENT.lerp(GrimoirePalette.EMBER, _t)
	var points := maxi(8, int(ARC_POINTS * _t))
	draw_arc(c, radius, -PI / 2.0, -PI / 2.0 + TAU * _t, points, col, RING_WIDTH, true)
