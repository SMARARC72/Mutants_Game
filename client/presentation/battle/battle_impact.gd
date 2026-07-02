extends RefCounted
## BattleImpact (Wave 10) — the battle screen's OUTCOME + IMPACT glue, extracted so
## battle_screen.gd stays under the 1000-line cap while the stage/impact stack lands.
##
## PRESENTATION layer, all STATIC and screen-agnostic (the battle_card_kit pattern): result
## plumbing (banner text, outcome toast, live-HP payload, capture-target resolution) that reads
## engine-owned state and computes NO combat number. The Wave 10 impact stack (JuiceDirector
## routing, force-matchup badges, entropy crescendo) grows here in the follow-up commits.

const BattleCardKitScript := preload("res://presentation/battle/battle_card_kit.gd")
const CaptureServiceScript := preload("res://application/battle/capture_service.gd")
const SkillBattleControllerScript := preload("res://application/battle/skill_battle_controller.gd")
const VoiceBookScript := preload("res://presentation/narrative/voice_book.gd")

## Impact-stack thresholds (Wave 10 commit 2): an engine 1.5x matchup or a kill earns the
## heavy read (hitstop + clash flash); everything else keeps the light one (flash/pop/shake).
const BIG_HIT_MULT := 1.5
const HITSTOP_BIG_MS := 60
const HITSTOP_KILL_MS := 90

## Wave 3 honesty: the distinct turn-cap-with-enemies-alive banner. The BODY lines are VoiceBook-
## keyed now (Wave 10 commit 3 — battle.victory / battle.defeat / battle.boss.victory /
## battle.stalemate); this verbatim §5.5 line stays only as the missing-catalog fallback.
const STALEMATE_BANNER := "THE WILD SLINKS AWAY — STALEMATE"
const STALEMATE_VOICE_LINE := "No battle today. It's tired, you're tired, the gods are dead — what's the point, really?"


## The outcome banner for a finished battle. Wave 3 honesty: the turn cap expiring with enemies
## still standing is NOT a victory — the distinct stalemate banner replaces the old lying VICTORY.
static func banner_text_for(result: Dictionary, reason: String) -> String:
	if bool(result.get("stalemate", false)):
		return STALEMATE_BANNER
	match reason:
		"caught":
			return "CAUGHT"
		"fled":
			return "FLED"
		_:
			return "VICTORY" if bool(result.get("player_won", false)) else "DEFEAT"


## Fire the end-of-battle toast: the catch carries its one-of-one sigil (Wave 9); everything
## else carries the banner headline + an AUTHORED VoiceBook body (Wave 10 commit 3 — the
## hand-written outcome strings are gone; the salt walks the variants deterministically per
## battle via the transcript length).
static func toast_outcome(
	toast: Node, reason: String, result: Dictionary, battle, game: Node
) -> void:
	if toast == null:
		return
	if reason == "caught" and toast.has_method("event_with"):
		# Wave 9: the catch toast bears the creature's one-of-one sigil (its mark stamps in the
		# icon slot — the same geometry party/lab render for this creature forever after).
		var sigil := BattleCardKitScript.caught_sigil_payload(battle, game)
		toast.call("event_with", "creature_caught", {"sigil": sigil})
	elif reason == "caught" and toast.has_method("event"):
		toast.call("event", "creature_caught")
	elif bool(result.get("stalemate", false)) and toast.has_method("show"):
		# The authored stalemate line (§5.5 via battle.stalemate) + the reduced-reward note.
		(
			toast
			. call(
				"show",
				{
					"title": STALEMATE_BANNER,
					"body": outcome_voice_line(result, reason) + "\n(Spoils halved.)",
					"sound": "chime",
				}
			)
		)
	elif toast.has_method("show"):
		(
			toast
			. call(
				"show",
				{
					"title": banner_text_for(result, reason),
					"body": outcome_voice_line(result, reason),
					"sound": "chime",
				}
			)
		)


## E1c: the boss-splash sub-line — the boss's AUTHORED intro line when the pantheon data
## carries one (VERBATIM from boss_kits.json), else the seed-deterministic VoiceBook
## pre-fight beat (the verdant slice boss ships with "" and keeps that presentation).
static func boss_prefight_line(intro_line: String, battle_seed: int) -> String:
	if intro_line != "":
		return intro_line
	return VoiceBookScript.pick("battle.boss.prefight", battle_seed)


## E1c: a FELLED pantheon boss gets its authored EPITAPH — the VERBATIM defeat line from
## boss_kits.json (the lair hand-off's pending.defeat_line) — toasted over the victory beat.
## Data-driven and additive: an empty line (wild fights, the verdant slice boss) or an
## unfinished boss (no boss_win) toasts nothing new.
static func toast_boss_epitaph(
	toast: Node, defeat_line: String, result: Dictionary, battle
) -> void:
	if defeat_line == "" or not bool(result.get("boss_win", false)):
		return
	if toast == null or not toast.has_method("show"):
		return
	var title := "The god is felled."
	if battle != null and not (battle.enemy_team() as Array).is_empty():
		var boss := battle.enemy_team()[0] as AbilityContainer
		title = "%s is felled." % boss.combatant_name()
	toast.call("show", {"title": title, "body": defeat_line, "sound": "hum"})


## The authored VoiceBook body for a battle outcome ("" for a fled/unkeyed end; the verbatim
## Wave 3 stalemate line remains the missing-catalog fallback). Deterministic per battle: the
## transcript length salts the variant walk.
static func outcome_voice_line(result: Dictionary, reason: String) -> String:
	var salt: int = (result.get("transcript", []) as Array).size()
	if bool(result.get("stalemate", false)):
		var line: String = VoiceBookScript.pick("battle.stalemate", salt)
		return line if line != "" else STALEMATE_VOICE_LINE
	if reason == "fled":
		return ""
	if bool(result.get("player_won", false)):
		var key := (
			"battle.boss.victory" if bool(result.get("boss_win", false)) else "battle.victory"
		)
		return VoiceBookScript.pick(key, salt)
	return VoiceBookScript.pick("battle.defeat", salt)


## The live end-of-battle HP of every player combatant, mapped back to its run.party INDEX through
## the SkillInteractiveBattle's player source map (identity-safe even if the factory skipped an
## unassemblable entry). Shape: [{ "index": int, "hp": int, "max_hp": int }, ...] — the payload
## GameController.apply_battle_result folds into run.party (Wave 3 consequence).
static func live_party_hp(battle, game: Node) -> Array:
	var out: Array = []
	if battle == null or game == null or not battle.has_method("player_source"):
		return out
	var run: RunContext = game.call("run")
	if run == null:
		return out
	var source: Dictionary = battle.player_source()
	for ac_v in battle.player_team():
		var ac := ac_v as AbilityContainer
		var creature: Variant = source.get(ac, null)
		if creature == null:
			continue
		for i in run.party.size():
			if run.party[i] is Dictionary and is_same(run.party[i], creature):
				out.append({"index": i, "hp": maxi(0, ac.hp()), "max_hp": ac.max_hp()})
				break
	return out


## Route one damaging hit's FULL impact stack (the screen's fx_damage body, Wave 10): the
## force-coloured arcing damage pop (badge glyph repeated — grayscale-safe), the struck stage
## plate's hit flash, then — ANIMATED beats only, never the instant/drain path — damage-scaled
## shake plus hitstop + two-colour clash flash on engine-1.5x hits. The matchup multiplier is
## the controller's THIN SkillEngine read; no combat number is computed here.
static func impact(
	screen: Control, card: Control, amount: int, target: Variant, attacker: Variant, instant: bool
) -> void:
	var juice := screen.get_node_or_null("/root/Juice")
	if juice == null:
		# Bare test screens (no autoload): keep the classic float so impact still reads.
		BattleCardKitScript.spawn_damage_number(screen.call("fx_layer"), card, amount)
		return
	var t_ac := target as AbilityContainer
	var a_ac := attacker as AbilityContainer
	var mult: float = SkillBattleControllerScript.matchup_mult(a_ac, t_ac)
	var frac := 0.0
	if t_ac != null and t_ac.max_hp() > 0:
		frac = clampf(float(amount) / float(t_ac.max_hp()), 0.0, 1.0)
	var color := GrimoirePalette.DANGER
	if a_ac != null:
		color = GrimoirePalette.force_color(a_ac.primary_force())
	var text := "-%d" % amount
	var badge: Dictionary = BattleCardKitScript.matchup_badge(mult)
	if not badge.is_empty():
		text += " " + str(badge["glyph"])  # the badge repeats in the float (HAWKING)
	var at := Vector2.ZERO
	if card != null:
		at = card.global_position + Vector2(card.size.x * 0.5, 8.0)
	juice.call("pop_number", screen.call("fx_layer"), at, text, color, frac)
	var stage: Variant = screen.call("stage")
	if stage != null and t_ac != null:
		var plate: Variant = stage.call("plate_of", t_ac)
		if plate != null:
			juice.call("hit", plate)
	if instant:
		return  # pacing juice never runs on the instant/drain path (headless / Swift Rites)
	juice.call("shake", 0.3 + 0.9 * frac, stage as CanvasItem)
	if mult >= BIG_HIT_MULT:
		juice.call("hitstop", HITSTOP_BIG_MS)
		if a_ac != null and t_ac != null:
			juice.call("collision_flash", a_ac.primary_force(), t_ac.primary_force())


## THE PERMADEATH DIRGE (Wave 18 "Death With Weight"): the mournful beat when a PARTY creature
## truly dies at battle end (a LOST battle — the mercy rule spares winners' downed). The knell
## tolls once, the ONE grade pass desaturates for ~0.8s (the battle's atmosphere surface —
## tension 9 keeps the pass count at one, so the pulse rides `mourn` instead of a new shader),
## and each memorial gets an authored epitaph toast bearing the creature's one-of-one sigil.
## Never the word "fainted". Skippable/instant: headless + instant beats skip the tween entirely
## and the toasts never block input (the Continue affordance is already live).
static func death_dirge(screen: Control, grade: ColorRect, deaths: Array, instant: bool) -> void:
	if deaths.is_empty():
		return
	var sfx := screen.get_node_or_null("/root/SfxService")
	if sfx != null and sfx.has_method("play"):
		sfx.call("play", "death_knell", 0.0)
	_toast_epitaphs(screen, deaths)
	if instant or grade == null or not (grade.material is ShaderMaterial):
		return
	if not screen.is_inside_tree():
		return
	var mat := grade.material as ShaderMaterial
	var tween := screen.create_tween()
	tween.tween_method(func(v: float) -> void: mat.set_shader_parameter("mourn", v), 0.0, 0.85, 0.3)
	tween.tween_method(func(v: float) -> void: mat.set_shader_parameter("mourn", v), 0.85, 0.0, 0.5)


## One epitaph toast per memorial: the authored region line when it exists, else the permadeath
## line, with {creature} interpolated; the memorial's sigil stamps the icon slot (Wave 9 pattern).
static func _toast_epitaphs(screen: Control, deaths: Array) -> void:
	var toast := screen.get_node_or_null("/root/Toast")
	if toast == null or not toast.has_method("show"):
		return
	for death_v in deaths:
		if not (death_v is Dictionary):
			continue
		var memorial: Dictionary = death_v
		var name := str(memorial.get("name", ""))
		var body := epitaph_for(memorial)
		(
			toast
			. call(
				"show",
				{
					"title": "%s is gone." % name,
					"body": body,
					"sound": "chime",
					"sigil":
					{
						"species": str(memorial.get("species_id", "")),
						"tag": str(memorial.get("sigil", "")),
						"force": str(memorial.get("force", "")),
					},
				}
			)
		)


## The authored epitaph line for a memorial (region variant first, then the permadeath key,
## then a hand fallback), deterministic per creature (its sigil tag salts the variant walk).
static func epitaph_for(memorial: Dictionary) -> String:
	var name := str(memorial.get("name", ""))
	var salt := str(memorial.get("sigil", "")).hash() & 0x7FFFFFFF
	var line := VoiceBookScript.pick("death.region.%s" % str(memorial.get("region", "")), salt)
	if line == "":
		line = VoiceBookScript.pick("death.permadeath", salt)
	if line == "":
		line = "{creature} is gone. Not down — gone. The grimoire keeps a page where it kept a heartbeat."
	return line.format({"creature": name})


## The death beat (Wave 10): the dying combatant's staged plate dissolves (0 -> 1, ~0.8s) with
## a drifting-parts burst; animated playback adds the kill hitstop + a full-weight shake.
static func death(screen: Control, target: Variant, instant: bool) -> void:
	var juice := screen.get_node_or_null("/root/Juice")
	var stage: Variant = screen.call("stage")
	if juice == null or stage == null or target == null:
		return
	var plate: Variant = stage.call("plate_of", target)
	if plate != null:
		juice.call("dissolve_out", plate)
	if not instant:
		juice.call("hitstop", HITSTOP_KILL_MS)
		juice.call("shake", 1.0, stage as CanvasItem)


## Fan the session's entropy out to every crescendo surface (Wave 10 commit 3): the radial
## dial's fill, the grade pass's warmth, the JuiceDirector heat (shake amplitude + number
## scale) and the music bed's intensity swell. ONE normalization (EntropyDial.normalized on
## the dial), four consumers — presentation mapping only, the number is the session's.
static func crescendo(screen: Control, dial: Control, grade: ColorRect, entropy: float) -> void:
	if dial == null or not dial.has_method("set_entropy"):
		return
	var t := float(dial.call("set_entropy", entropy))
	if grade != null and grade.material is ShaderMaterial:
		(grade.material as ShaderMaterial).set_shader_parameter("warmth", t)
	var juice := screen.get_node_or_null("/root/Juice")
	if juice != null and juice.has_method("set_heat"):
		juice.call("set_heat", t)
	var music := screen.get_node_or_null("/root/MusicService")
	if music != null and music.has_method("set_intensity"):
		music.call("set_intensity", t)


## The capture target: the chosen live foe at `target_index`, else the first alive foe, else null.
static func resolve_capture_target(foes: Array, target_index: int) -> AbilityContainer:
	if target_index >= 0 and target_index < foes.size():
		var chosen := foes[target_index] as AbilityContainer
		if chosen != null and chosen.is_alive():
			return chosen
	for f in foes:
		var m := f as AbilityContainer
		if m.is_alive():
			return m
	return null


## The run's equipped capture-gear ids ([] without a game/run) — CaptureService's own derivation.
static func gear_ids(game: Node) -> Array:
	if game == null:
		return []
	var run: RunContext = game.call("run")
	if run == null:
		return []
	return CaptureServiceScript.gear_ids(run.gear)
