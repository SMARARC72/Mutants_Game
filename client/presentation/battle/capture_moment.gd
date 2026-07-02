extends RefCounted
## CaptureMoment (Wave 11 — "Capture Becomes a Moment") — the battle screen's STAGED CAPTURE
## helper: the brass sigil-circle that closes around the enemy's staged LivingPlate, holds 1-3
## tension pulses scaled by how close the canonical roll ran to the shown chance (near-misses
## pulse longest), then resolves — success dissolves the plate INTO the sigil (the LivingPlate
## dissolve hook via JuiceDirector), a break-free SHATTERS the ring (Line2D fragments) and kicks
## the enemy's lunge + hit_crunch. Also home to the capture RESULT CARD hand-off and the ONE-SHOT
## first-capture teach (Old Maddox's "mercy and math" Dialogic beat, latched via run.flags).
##
## PRESENTATION layer, all STATIC and duck-typed against the battle screen (the battle_beats /
## battle_impact pattern: stage / fx_layer / play_stinger / confirm_held / capture_chance — never
## a battle_screen preload, no import cycle). HEADLESS/INSTANT contract: the screen only awaits
## play() in animated mode; instant mode records the SAME phase list via phases_for() with no
## nodes and no awaits, so every synchronous capture suite stays green unmodified. All numbers
## here are the CaptureService's — this file computes no chance and draws no roll.

const BattleCardKitScript := preload("res://presentation/battle/battle_card_kit.gd")
const CaptureCardScript := preload("res://presentation/battle/capture_card.gd")
const VoiceBookScript := preload("res://presentation/narrative/voice_book.gd")

## The recorded state-machine phases (instant + animated attempts record the SAME list).
const PHASE_CLOSE := "close"
const PHASE_PULSE := "pulse"
const PHASE_DISSOLVE := "dissolve"  # success — the plate burns into the sigil
const PHASE_SHATTER := "shatter"  # break-free — the ring fragments, the wild kicks

## Tension pulses by |roll - chance|: a near-miss margin reads as the longest hold (3 pulses),
## a comfortable margin as a single beat. The thresholds are presentation pacing only.
const NEAR_MISS_MARGIN := 0.12
const CLOSE_CALL_MARGIN := 0.35

## Animated phase budgets (seconds); held CONFIRM / reduce_motion compress every phase to FAST.
const CLOSE_TIME := 0.4
const PULSE_TIME := 0.3
const RESOLVE_TIME := 0.45
const FAST_PHASE := 0.1

## First-capture teach (W11): Old Maddox's Act-0 "mercy and math" timeline replays ONCE at the
## first weakened wild (below TEACH_HP_FRAC, nothing caught yet this run), latched in run.flags.
const TEACH_FLAG := "capture_teach_seen"
const TEACH_TIMELINE := "maddox_mercy"
const TEACH_HP_FRAC := 0.4
const TEACH_VOICE_KEY := "tutorial.catch"

## The capture result card's authored line key (befriend is the CaptureService default method).
const CARD_VOICE_KEY := "capture.befriend.success"

## Keeps the teach facade referenced while its timeline renders (RefCounted would drop mid-line).
static var _teach_dialogue: DialogicFacade = null


## The recorded phase list for a resolved capture attempt ({success, chance, roll} — the
## CaptureService outcome dict): close -> N tension pulses -> dissolve | shatter. Instant mode
## records exactly this; animated playback performs it beat for beat.
static func phases_for(cap: Dictionary) -> Array:
	var phases: Array = [PHASE_CLOSE]
	for i in pulse_count(float(cap.get("chance", 0.0)), float(cap.get("roll", 1.0))):
		phases.append(PHASE_PULSE)
	phases.append(PHASE_DISSOLVE if bool(cap.get("success", false)) else PHASE_SHATTER)
	return phases


## Tension pulses for a resolved roll: the closer the roll ran to the chance line (either side),
## the longer the sigil holds its breath — 3 for a near-miss, 2 for a close call, else 1.
static func pulse_count(chance: float, roll: float) -> int:
	var margin := absf(roll - chance)
	if margin < NEAR_MISS_MARGIN:
		return 3
	if margin < CLOSE_CALL_MARGIN:
		return 2
	return 1


## Play the staged attempt (ANIMATED mode only — the screen's instant path never calls this):
## the brass sigil-circle closes around `target`'s staged plate, pulses per pulse_count, then
## dissolves the plate into the ring (success) or shatters + lunges (break-free). Coroutine;
## held CONFIRM (or reduce_motion) compresses every phase. Guards the screen leaving the tree.
static func play(screen: Control, target: Variant, cap: Dictionary) -> void:
	var stage: Variant = screen.call("stage")
	var fx: Control = screen.call("fx_layer")
	if stage == null or fx == null or not screen.is_inside_tree():
		return
	var plate := stage.call("plate_of", target) as Control
	var center := screen.get_viewport_rect().size * 0.5
	var plate_w := 232.0
	if plate != null:
		center = plate.global_position + plate.size * 0.5
		plate_w = plate.size.x
	var ring := SigilRing.new()
	ring.name = "CaptureSigilRing"
	fx.add_child(ring)
	ring.position = center
	ring.radius = plate_w * 1.35
	# CLOSE: the circle draws tight around the plate.
	var t_close := _phase_time(screen, CLOSE_TIME)
	var tw := ring.create_tween()
	(
		tw
		. tween_property(ring, "radius", plate_w * 0.55, t_close)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)
	await screen.get_tree().create_timer(t_close).timeout
	if not is_instance_valid(screen) or not is_instance_valid(ring):
		return
	# TENSION: 1-3 pulses — the roll's margin decides how long the binding holds its breath.
	for i in pulse_count(float(cap.get("chance", 0.0)), float(cap.get("roll", 1.0))):
		var t_pulse := _phase_time(screen, PULSE_TIME)
		ring.pulse(t_pulse)
		await screen.get_tree().create_timer(t_pulse).timeout
		if not is_instance_valid(screen) or not is_instance_valid(ring):
			return
	# RESOLVE: dissolve-into-the-sigil, or shatter + the wild's break-free kick.
	var t_resolve := _phase_time(screen, RESOLVE_TIME)
	var juice := screen.get_node_or_null("/root/Juice")
	if bool(cap.get("success", false)):
		if juice != null and plate != null:
			juice.call("dissolve_out", plate)
		ring.contract_out(t_resolve)
	else:
		ring.shatter(t_resolve)
		screen.call("play_stinger", "hit_crunch", 0.1)
		var l: Dictionary = stage.call("lunge_of", target)
		if juice != null and not l.is_empty():
			juice.call("lunge", l["plate"], l["dir"])
	await screen.get_tree().create_timer(t_resolve).timeout


## Build + mount the capture RESULT CARD over `screen` (success only): the caught creature's
## plate LARGE, its name resolving letter-by-letter, its one-of-one sigil stamping in, and the
## authored VoiceBook capture line. Returns the card (null when nothing was caught). The banner
## and rewards beneath are untouched — dismissing the card resumes the exact pre-W11 flow.
static func show_result_card(screen: Control, battle, game: Node, instant: bool) -> Control:
	if battle == null:
		return null
	var caught: Dictionary = battle.caught()
	if caught.is_empty():
		return null
	var payload: Dictionary = BattleCardKitScript.caught_sigil_payload(battle, game)
	var display_name := str(caught.get("nickname", ""))
	if display_name == "":
		display_name = str(caught.get("species_id", "The Nameless"))
	# The salt walks the authored variants deterministically per battle (battle_impact pattern).
	var salt: int = (battle.transcript() as Array).size()
	var line: String = VoiceBookScript.pick(CARD_VOICE_KEY, salt).format({"creature": display_name})
	var card: Control = CaptureCardScript.new()
	screen.add_child(card)  # mount BEFORE build so the reveal tweens have a tree
	card.call("build", caught, display_name, str(payload.get("force", "")), line, instant)
	return card


# === first-capture teach ======================================================================= #


## Fire the ONE-SHOT first-capture teach if this player turn qualifies (wild battle, weakest foe
## below ~40% HP, nothing caught yet this run, never latched): latch run.flags, replay Maddox's
## "mercy and math" Dialogic beat (headless: the facade resolves instantly) and point a toast at
## the LIVE % the Capture button is showing. Returns true only when the beat fired.
static func maybe_teach(screen: Control, game: Node, battle, is_wild: bool) -> bool:
	if screen == null or game == null or battle == null:
		return false
	var run: RunContext = game.call("run")
	if not should_teach(run, is_wild, weakest_alive_frac(battle.enemy_team())):
		return false
	latch_teach(run)
	_teach_dialogue = DialogicFacade.new()
	_teach_dialogue.play_timeline(TEACH_TIMELINE)
	var toast := screen.get_node_or_null("/root/Toast")
	if toast != null and toast.has_method("show"):
		var readout: Dictionary = screen.call("capture_readout")
		var pct := roundi(float(readout.get("chance", 0.0)) * 100.0)
		(
			toast
			. call(
				"show",
				{
					"title": "Capture — %d%%" % pct,
					"body": teach_line(),
					"sound": "chime",
				}
			)
		)
	return true


## True when the teach beat should fire: a live run, a WILD fight, the weakest standing foe
## below TEACH_HP_FRAC, the latch unset, and no captured creature in the party yet this run.
static func should_teach(run: RunContext, is_wild: bool, weakest_frac: float) -> bool:
	if run == null or not is_wild:
		return false
	if weakest_frac >= TEACH_HP_FRAC:
		return false
	if bool(run.flags.get(TEACH_FLAG, false)):
		return false
	return not has_capture(run)


## Latch the teach one-shot in run.flags. True only the FIRST time (the FourthWall ration shape).
static func latch_teach(run: RunContext) -> bool:
	if run == null or bool(run.flags.get(TEACH_FLAG, false)):
		return false
	run.flags[TEACH_FLAG] = true
	return true


## True when any party member was CAUGHT (lineage.captured) — "no captures yet this run".
static func has_capture(run: RunContext) -> bool:
	if run == null:
		return false
	for creature in run.party:
		if not (creature is Dictionary):
			continue
		var lineage_v: Variant = (creature as Dictionary).get("lineage", {})
		var lineage: Dictionary = lineage_v if lineage_v is Dictionary else {}
		if bool(lineage.get("captured", false)):
			return true
	return false


## The weakest ALIVE combatant's hp fraction on `team` (1.0 when nothing stands).
static func weakest_alive_frac(team: Array) -> float:
	var weakest := 1.0
	for ac_v in team:
		var ac := ac_v as AbilityContainer
		if ac == null or not ac.is_alive() or ac.max_hp() <= 0:
			continue
		weakest = minf(weakest, float(ac.hp()) / float(ac.max_hp()))
	return weakest


## The authored teach body: the VoiceBook's "mercy and math" tutorial line verbatim (scanned by
## its signature phrase so the exact beat survives catalog re-orders), else the keyed default.
static func teach_line() -> String:
	for line in VoiceBookScript.lines(TEACH_VOICE_KEY):
		if str(line).findn("mercy and math") != -1:
			return str(line)
	return VoiceBookScript.pick(TEACH_VOICE_KEY, 0)


# === internals ================================================================================= #


## One phase's duration: FAST under held CONFIRM (never-wait-twice) or reduce_motion.
static func _phase_time(screen: Control, base: float) -> float:
	if bool(screen.call("confirm_held")) or _reduce_motion():
		return FAST_PHASE
	return base


static func _reduce_motion() -> bool:
	var loop := Engine.get_main_loop()
	if not (loop is SceneTree):
		return false
	var settings := (loop as SceneTree).root.get_node_or_null("Settings")
	if settings == null:
		return false
	return bool(settings.call("get_value", "accessibility", "reduce_motion", false))


## SigilRing — the drawn brass capture circle (draw_arc; GrimoirePalette colours only): a full
## ring + four bright binding ticks. `radius` is tweenable (setter redraws); pulse() swells it,
## contract_out() collapses it into the catch, shatter() bursts it into Line2D fragments that
## fly outward and fade (the break-free read). Animated-mode only — never built headless.
class SigilRing:
	extends Control

	const ARC_POINTS := 48
	const RING_WIDTH := 3.0
	const TICKS := 4
	const TICK_SPAN := 0.5
	const FRAGMENTS := 10
	const FRAGMENT_HALF := 9.0
	const FRAGMENT_FLY := 46.0

	var radius := 100.0:
		set(value):
			radius = value
			queue_redraw()

	var _shattered := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if _shattered:
			return  # the fragments carry the read; the ring itself is gone
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, ARC_POINTS, GrimoirePalette.BRASS, RING_WIDTH)
		for i in TICKS:
			var a := TAU * float(i) / float(TICKS) + 0.35
			draw_arc(
				Vector2.ZERO, radius + 7.0, a, a + TICK_SPAN, 10, GrimoirePalette.BRASS_BRIGHT, 2.0
			)

	## One tension pulse: a 12% swell-and-settle with a brief lit-brass flicker.
	func pulse(duration: float) -> void:
		var from := radius
		var tw := create_tween()
		(
			tw
			. tween_property(self, "radius", from * 1.12, duration * 0.5)
			. set_trans(Tween.TRANS_SINE)
			. set_ease(Tween.EASE_OUT)
		)
		tw.tween_property(self, "radius", from, duration * 0.5).set_trans(Tween.TRANS_SINE)
		modulate = Color(1.35, 1.3, 1.1)
		create_tween().tween_property(self, "modulate", Color.WHITE, duration)

	## The catch: the ring collapses to a point and fades — the plate dissolves INTO it.
	func contract_out(duration: float) -> void:
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(self, "radius", 3.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(
			Tween.EASE_IN
		)
		tw.tween_property(self, "modulate:a", 0.0, duration * 0.5).set_delay(duration * 0.5)
		tw.chain().tween_callback(queue_free)

	## The break-free: the ring bursts into short tangent fragments that fly outward and fade.
	func shatter(duration: float) -> void:
		_shattered = true
		queue_redraw()
		for i in FRAGMENTS:
			var a := TAU * float(i) / float(FRAGMENTS)
			var dir := Vector2(cos(a), sin(a))
			var tangent := Vector2(-sin(a), cos(a))
			var frag := Line2D.new()
			frag.width = RING_WIDTH
			frag.default_color = GrimoirePalette.BRASS_BRIGHT
			frag.add_point(dir * radius - tangent * FRAGMENT_HALF)
			frag.add_point(dir * radius + tangent * FRAGMENT_HALF)
			add_child(frag)
			var tw := frag.create_tween()
			tw.set_parallel(true)
			(
				tw
				. tween_property(frag, "position", dir * FRAGMENT_FLY, duration)
				. set_trans(Tween.TRANS_CUBIC)
				. set_ease(Tween.EASE_OUT)
			)
			tw.tween_property(frag, "modulate:a", 0.0, duration)
		var out := create_tween()
		out.tween_interval(duration)
		out.tween_callback(queue_free)
