extends RefCounted
## BattleBeats (Wave 8 — "Battle Time Axis") — the battle screen's BEAT capture + playback helper.
##
## PRESENTATION layer, data-only + tween choreography. The controller resolves whole enemy rounds
## instantly (one RESOLVED step per action); this module snapshots each action into a BEAT — the
## per-action transcript delta plus the post-action HP of every combatant — and plays the collected
## queue back one readable moment at a time (~0.45s each at x1): acting-card highlight -> HP bar
## tween (0.35s TRANS_CUBIC) -> floating damage number -> settle. Held CONFIRM compresses each beat
## to ~0.12s (never-wait-twice, plan tension 10).
##
## All entry points are STATIC and duck-typed against the battle screen (append_transcript_to /
## card_refs_for / side_cards / restyle_bar / fx_damage / play_stinger / confirm_held), so this
## file never preloads battle_screen.gd (no import cycle). HEADLESS SAFETY: the screen only calls
## play() in animated mode — instant/drain mode applies beats synchronously without touching this
## coroutine, so every synchronous test path stays await-free.

const BattleCardKitScript := preload("res://presentation/battle/battle_card_kit.gd")

const HP_TWEEN_TIME := 0.35  # the HP bar glide (replaces the direct value assign)
const SETTLE_TIME := 0.15  # the post-impact breath before the next actor moves
const FAST_TOTAL := 0.12  # whole-beat budget while CONFIRM is held (fast-forward)


## Snapshot one resolved action into a data-only beat. `log_from` is the caller's transcript
## watermark (lines already claimed by earlier beats); the beat claims [log_from, log_to). The HP
## arrays carry the POST-action truth for every combatant, so playback can tween each bar from its
## displayed value to this snapshot without re-reading live state that later actions already moved.
static func capture(battle, actor: Variant, log_from: int) -> Dictionary:
	var lines: Array = battle.transcript()
	return {
		"actor": actor,
		"log_from": log_from,
		"log_to": lines.size(),
		"party_hp": _hp_snapshot(battle.player_team()),
		"enemy_hp": _hp_snapshot(battle.enemy_team()),
	}


## Apply one beat with NO awaits — the INSTANT/drain route (headless / Swift Rites "instant"):
## transcript delta + per-action HP snap + damage floats + stingers, equivalent to the old
## synchronous per-step refresh. The screen's drain loop calls this once per beat, in order.
static func apply_instant(screen: Control, beat: Dictionary) -> void:
	screen.call("append_transcript_to", int(beat.get("log_to", 0)))
	for side in 2:
		var is_enemy := side == 1
		var cards: Array = screen.call("side_cards", is_enemy)
		var snap_v: Variant = beat.get("enemy_hp" if is_enemy else "party_hp", [])
		var snap: Array = snap_v if snap_v is Array else []
		for i in mini(cards.size(), snap.size()):
			var c: Dictionary = cards[i]
			var target := int(snap[i])
			var last := int(c.get("last_hp", target))
			if target == last:
				continue
			var bar := c["bar"] as ProgressBar
			bar.value = maxi(0, target)
			BattleCardKitScript.style_hp_bar(bar)
			(c["hp"] as Label).text = "%d / %d" % [maxi(0, target), int(bar.max_value)]
			if target < last:
				BattleCardKitScript.flash_portrait(c["portrait"] as TextureRect)
				screen.call("fx_damage", c["card"], last - target)
				screen.call("play_stinger", "hit_crunch", 0.15)
				if target <= 0:
					screen.call("play_stinger", "death_knell", 0.0)
			c["last_hp"] = target


## Play a collected beat queue in order (coroutine). `time_scale` scales the base durations
## (Swift Rites x1 -> 1.0, x2 -> 0.5); a held CONFIRM compresses further, re-checked per beat.
## Guards every step against the screen leaving the tree mid-playback.
static func play(screen: Control, beats: Array, time_scale: float) -> void:
	for beat_v in beats:
		if not is_instance_valid(screen) or not screen.is_inside_tree():
			return
		await _play_one(screen, beat_v as Dictionary, time_scale)


# === internals ================================================================================= #


## One beat: highlight the acting card, append the action's transcript delta, glide every changed
## HP bar (TRANS_CUBIC), float the damage numbers, fire the stingers, then settle.
static func _play_one(screen: Control, beat: Dictionary, time_scale: float) -> void:
	var fast := bool(screen.call("confirm_held"))
	var t_hp := FAST_TOTAL * 0.6 if fast else HP_TWEEN_TIME * time_scale
	var t_settle := FAST_TOTAL * 0.4 if fast else SETTLE_TIME * time_scale
	_highlight_actor(screen, beat)
	screen.call("append_transcript_to", int(beat.get("log_to", 0)))
	var impact := _animate_hp(screen, beat, t_hp)
	if bool(impact.get("any_damage", false)):
		screen.call("play_stinger", "hit_crunch", 0.15)
	await screen.get_tree().create_timer(t_hp).timeout
	if bool(impact.get("any_death", false)):
		screen.call("play_stinger", "death_knell", 0.0)
	if not is_instance_valid(screen) or not screen.is_inside_tree():
		return
	await screen.get_tree().create_timer(t_settle).timeout


## Pulse the acting combatant's card toward lit brass, then back — the "who acts" read.
static func _highlight_actor(screen: Control, beat: Dictionary) -> void:
	var refs: Dictionary = screen.call("card_refs_for", beat.get("actor"))
	if refs.is_empty():
		return
	var card := refs.get("card") as Control
	if card == null or not is_instance_valid(card):
		return
	var restore := card.modulate
	var glow := GrimoirePalette.BRASS_BRIGHT.lightened(0.45)
	glow.a = restore.a
	card.modulate = glow
	var tw := screen.create_tween()
	tw.tween_property(card, "modulate", restore, 0.3)


## Tween every card whose displayed HP ("last_hp") differs from the beat snapshot; spawn a damage
## float per drop and report whether anything was hit / died (for the stingers). Updates each
## card's "last_hp" so the terminal refresh never double-spawns numbers.
static func _animate_hp(screen: Control, beat: Dictionary, duration: float) -> Dictionary:
	var out := {"any_damage": false, "any_death": false}
	for side in 2:
		var is_enemy := side == 1
		var cards: Array = screen.call("side_cards", is_enemy)
		var snap_v: Variant = beat.get("enemy_hp" if is_enemy else "party_hp", [])
		var snap: Array = snap_v if snap_v is Array else []
		for i in mini(cards.size(), snap.size()):
			var c: Dictionary = cards[i]
			var target := int(snap[i])
			var last := int(c.get("last_hp", target))
			if target == last:
				continue
			_glide_card_hp(screen, c, target, duration)
			if target < last:
				out["any_damage"] = true
				screen.call("fx_damage", c.get("card"), last - target)
				if target <= 0:
					out["any_death"] = true
			c["last_hp"] = target
	return out


## Glide one card's HP bar to `target` (TRANS_CUBIC ease-out) and update its numeric label;
## re-style the bar's colour band once the glide lands.
static func _glide_card_hp(screen: Control, c: Dictionary, target: int, duration: float) -> void:
	var bar := c.get("bar") as ProgressBar
	if bar == null or not is_instance_valid(bar):
		return
	var tw := screen.create_tween()
	(
		tw
		. tween_property(bar, "value", float(maxi(0, target)), duration)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)
	tw.chain().tween_callback(
		func() -> void:
			if is_instance_valid(screen) and is_instance_valid(bar):
				screen.call("restyle_bar", bar)
	)
	var hp_label := c.get("hp") as Label
	if hp_label != null and is_instance_valid(hp_label):
		hp_label.text = "%d / %d" % [maxi(0, target), int(bar.max_value)]


static func _hp_snapshot(team: Array) -> Array:
	var out: Array = []
	for ac in team:
		out.append(maxi(0, (ac as AbilityContainer).hp()))
	return out
