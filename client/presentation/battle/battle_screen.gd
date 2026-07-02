extends Control
## BattleScreen (Phase 5 · Slice 2) — the INTERACTIVE battle's PRESENTATION. CODE-BUILT (a thin .tscn
## just loads this script) so it is unit-testable headless. The player's side is PLAYER-DRIVEN: on a
## player actor's turn the screen offers Attack (pick a target), Capture (wild only) and Flee (wild
## only); the enemy side is brain-driven. Every strike resolves through the EXISTING oracle path
## (BattleController.InteractiveSession → BattleEngine.attack) preserving the turn structure +
## RES/SEL sub-stream split. The Slice 1 AUTO path (BattleSession.run / simulate parity) is untouched
## and still used for boss/auto battles.
##
## It renders, from minimal code-built Control nodes styled via ThemeService:
##   * party + enemy ROWS (HP bar + name/force per combatant),
##   * a turn / whose-turn INDICATOR,
##   * the ACTION MENU (Attack → target picker / Capture / Flee) + the Swift Rites pacing toggle,
##   * a collapsible TRANSCRIPT drawer ("The Record" — Wave 8 demoted it; beats narrate now),
##   * a VICTORY / DEFEAT / FLED / CAUGHT banner.
##
## WAVE 8 "BATTLE TIME AXIS": enemy rounds no longer resolve in one frame. Each RESOLVED action is
## captured as a BEAT (per-action transcript delta + post-action HP snapshot) and played back as a
## coroutine (~0.45s/beat: actor highlight → HP glide → damage float → settle; held CONFIRM
## fast-forwards; Swift Rites persists x1/x2/instant). HEADLESS/instant mode drains the same queue
## synchronously with NO awaits, so every suite driving player_use_skill/last_step stays green.
##
## FLOW: reads the pending battle (enemy_party + battle_seed [+ is_wild]) GameController stashed before
## the swap, builds an interactive session against the run's party, drives it turn-by-turn from player
## input, then applies the result back to the run (xp on a win; a caught creature joins the party),
## persists, and waits for a Confirm to return to the overworld. DETERMINISTIC: same (seed, teams,
## player-choice sequence) => byte-identical transcript + result (canonical RNG; capture rolls on a
## disjoint capture sub-stream).

const BattleSessionScript := preload("res://application/battle/battle_session.gd")
const CaptureServiceScript := preload("res://application/battle/capture_service.gd")
const SkillBattleControllerScript := preload("res://application/battle/skill_battle_controller.gd")
const BattleBeatsScript := preload("res://presentation/battle/battle_beats.gd")
const BattleCardKitScript := preload("res://presentation/battle/battle_card_kit.gd")
const InputActions := preload("res://infrastructure/input/input_actions.gd")
const OVERWORLD_SCENE := "res://presentation/overworld/overworld_screen.tscn"

const _STEP_AWAIT := "await_player"
const _STEP_RESOLVED := "resolved"
const _STEP_ENDED := "ended"

## Wave 8: the Swift Rites battle-pacing cycle (persisted via Settings, battle section).
const SWIFT_RITES_ORDER: Array = ["x1", "x2", "instant"]

## Wave 3 honesty: the distinct turn-cap-with-enemies-alive banner (the interim authored line the
## W16 VoiceBook ingest replaces) + its toast body, VERBATIM from docs/content/voice_library.md
## §5.5 "A creature that refuses to fight".
const STALEMATE_BANNER := "THE WILD SLINKS AWAY — STALEMATE"
const STALEMATE_VOICE_LINE := "No battle today. It's tired, you're tired, the gods are dead — what's the point, really?"

var _game: Node = null
var _transition: Node = null
var _input: Node = null
var _result: Dictionary = {}
var _battle: BattleSession.SkillInteractiveBattle = null
var _session: BattleSession = null  # the BattleSession (for skill_result_for)
var _is_wild: bool = true
var _is_boss: bool = false  # Wave 3: pending.is_boss — a played boss win must clear the slice
var _last_step: Dictionary = {}
var _continue_button: Button = null
var _action_menu: VBoxContainer = null
var _target_picker: VBoxContainer = null
## The actor awaiting a skill choice (set on an await_player step) + the damage skill awaiting a target
## (set when the player picks a foe-targeting skill, consumed by the target picker). null when idle.
var _pending_actor: AbilityContainer = null
var _pending_skill: String = ""
var _turn_label: Label = null
var _transcript_label: RichTextLabel = null
var _scroll: ScrollContainer = null
var _party_rows: VBoxContainer = null
var _enemy_rows: VBoxContainer = null
var _banner: Label = null
var _root_box: VBoxContainer = null
var _fx_layer: Control = null  # full-rect overlay for floating damage numbers (above the cards)
## Build-once combatant cards (portrait + force icons + HP bar), then updated in place each refresh so
## HP tweens / damage floats / hit-flashes can live on persistent nodes. Each entry is a dict of refs.
var _party_cards: Array = []
var _enemy_cards: Array = []
var _player_species: Array = []  # species ids of the run party, by index (for portraits)
## When false, _ready does NOT auto-run the pending battle (a headless test drives
## run_pending_battle() once explicitly). Default true so production auto-runs on scene entry.
var _auto_run: bool = true
## === Wave 8 "Battle Time Axis" state ===
## Instant/drain mode: beats apply synchronously with NO awaits — the make-or-break headless
## contract (every suite drives player_use_skill/last_step synchronously). Defaults true when
## headless; in windowed play it follows the persisted Swift Rites setting ("instant").
var _instant_beats: bool = DisplayServer.get_name() == "headless"
var _beats_playing := false  # input latch while the beat coroutine narrates a round
var _log_watermark := 0  # transcript lines already claimed by a captured beat
var _shown_log := 0  # transcript lines already appended to the RichTextLabel
var _beats_processed := 0  # total beats routed (test bookkeeping)
var _last_beat_batch: Array = []  # the most recent pump's beat queue (test bookkeeping)
var _swift_local := ""  # Swift Rites fallback storage when no Settings autoload exists
var _region_force := ""  # pending_battle "force" (the overworld's region climate, e.g. "Eros")
var _swift_button: Button = null
var _record_button: Button = null
var _log_panel: PanelContainer = null


func _ready() -> void:
	# An injected _game (set_game before add_child) MUST win; only fall back to the autoload when
	# nothing was injected, so the test harness is never clobbered (mirrors overworld_screen).
	if _game == null:
		_game = get_node_or_null("/root/GameController")
	_transition = get_node_or_null("/root/Transition")
	_input = get_node_or_null("/root/InputService")
	var theme_service := get_node_or_null("/root/ThemeService")
	if theme_service != null and theme_service.has_method("apply_to"):
		theme_service.call("apply_to", self)
	if _input != null and _input.has_method("switch_context"):
		_input.call("switch_context", InputActions.CTX_BATTLE)
	if _auto_run and _game != null and _game.has_method("has_run") and _game.call("has_run"):
		run_pending_battle()


## Inject the GameController (tests / non-autoload contexts). Call BEFORE add_child/run_pending.
func set_game(game: Node) -> void:
	_game = game


## Disable the automatic battle run on _ready (tests drive run_pending_battle() once explicitly).
func set_auto_run(enabled: bool) -> void:
	_auto_run = enabled


## Begin the interactive battle GameController stashed in run.flags.pending_battle. Builds the UI and
## pumps the session to the first decision point (a player turn, or the end). Public so a test can
## drive it headlessly after configuring a GameController + pending battle. Returns the last step dict.
func run_pending_battle() -> Dictionary:
	if _game == null:
		return {}
	var run: RunContext = _game.call("run")
	if run == null:
		return {}
	# Re-entrancy guard: a battle builds ONCE per pending_battle. A stray second call finds no pending
	# flag and returns the cached result/step rather than rebuilding a degenerate empty battle.
	if not run.flags.has("pending_battle"):
		return _last_step
	var pending: Dictionary = run.flags.get("pending_battle", {})
	var enemy_party: Array = pending.get("enemy_party", [])
	var battle_seed := int(pending.get("battle_seed", 0))
	_is_wild = bool(pending.get("is_wild", true))  # overworld encounters are wild by default
	_is_boss = bool(pending.get("is_boss", false))  # Wave 3: the lair hand-off tags the climax
	# Wave 8 backdrop-lite: the overworld hands off the region's force climate; "" falls back by
	# battle kind (BattleCardKit.pick_backdrop). Windowed play folds in the Swift Rites speed.
	_region_force = str(pending.get("force", ""))
	if DisplayServer.get_name() != "headless":
		_instant_beats = _swift_rites() == "instant"
	var catalog: SpeciesCatalog = _game.call("catalog")
	# Capture the player party's species ids (by index) BEFORE the session builds, so each player card
	# can show the right bestiary plate (enemy plates resolve via SkillInteractiveBattle.species_for).
	_player_species = []
	for p in run.party:
		_player_species.append(
			str((p as Dictionary).get("species_id", "")) if p is Dictionary else ""
		)
	_session = BattleSessionScript.new(catalog)
	# The richer SKILL battle (force-pool skills, combos, shields/buffs) is THE interactive battle.
	_battle = _session.begin_skill_interactive(run.party, enemy_party, battle_seed)
	# Clear the pending flag now so a re-entrant call is a no-op even mid-battle.
	run.flags.erase("pending_battle")
	_build_ui()
	if _battle == null:
		# Unassemblable team — finish immediately with an invalid-style result.
		_result = {"valid": false, "winner": "enemy", "player_won": false, "transcript": []}
		_show_banner_text("DEFEAT")
		return _last_step
	if _is_boss:
		play_stinger("boss_swell")  # once, on the climax build (W-SND stinger set)
	_pump()
	return _last_step


# === interactive driving ====================================================================== #


## Pump the session forward, COLLECTING each resolved action as a BEAT (Wave 8), until it AWAITs a
## player action or ENDs. `first_beat` carries the just-resolved PLAYER action (captured by the
## verb) so it opens the round's playback. Instant mode drains synchronously (headless / Swift
## Rites "instant" — identical to the old one-frame pump); otherwise the queue plays as a
## coroutine, one readable beat per action. Idempotent w.r.t. an ended battle.
func _pump(first_beat: Dictionary = {}) -> void:
	if _battle == null:
		return
	var beats: Array = []
	if not first_beat.is_empty():
		beats.append(first_beat)
	var step := _battle.advance()
	while str(step.get("kind", "")) == _STEP_RESOLVED:
		beats.append(_capture_beat(step.get("actor")))
		step = _battle.advance()
	_last_step = step
	_play_or_drain(beats, step)


## Snapshot the action that JUST resolved into a beat (per-action transcript delta + post-action
## HP of every combatant) and advance the transcript watermark past its lines.
func _capture_beat(actor: Variant) -> Dictionary:
	var beat: Dictionary = BattleBeatsScript.capture(_battle, actor, _log_watermark)
	_log_watermark = int(beat["log_to"])
	return beat


## Route a collected beat batch: instant/headless drains synchronously (every existing suite
## drives the verbs synchronously — this path has NO awaits), otherwise the playback coroutine
## narrates the round (~0.45s/beat at x1, ~0.12s under held CONFIRM) before applying `step`.
func _play_or_drain(beats: Array, step: Dictionary) -> void:
	_beats_processed += beats.size()
	_last_beat_batch = beats
	if _instant_beats or not is_inside_tree():
		for beat_v in beats:
			BattleBeatsScript.apply_instant(self, beat_v as Dictionary)
		_apply_step(step)
		return
	_play_beats_async(beats, step)


## Fire-and-forget coroutine wrapper: latch input, play the beats, then apply the terminal step
## (action menu / banner). The caller already returned the terminal step synchronously.
func _play_beats_async(beats: Array, step: Dictionary) -> void:
	_beats_playing = true
	await BattleBeatsScript.play(self, beats, _beat_time_scale())
	_beats_playing = false
	if not is_instance_valid(self):
		return
	_apply_step(step)


func _apply_step(step: Dictionary) -> void:
	var kind := str(step.get("kind", ""))
	_refresh_combatants()
	_flush_transcript()
	if kind == _STEP_AWAIT:
		_pending_actor = step.get("actor") as AbilityContainer
		_refresh_turn_label(step)
		_show_action_menu()
	elif kind == _STEP_ENDED:
		_finish_battle(step)


## Route the step a PLAYER verb produced: a RESOLVED action becomes the round's opening beat and
## the pump collects the enemy responses; an ENDED step still plays the finishing blow as a beat.
func _route_player_step(step: Dictionary, actor: Variant) -> Dictionary:
	var kind := str(step.get("kind", ""))
	if kind == _STEP_RESOLVED:
		_pump(_capture_beat(step.get("actor", actor)))
	elif kind == _STEP_ENDED:
		var beat := _capture_beat(actor)
		_last_step = step
		_play_or_drain([beat], step)
	else:
		_last_step = step
		_play_or_drain([], step)
	return _last_step


## Player uses `skill` (from the pending actor's kit). SUPPORT skills (Mend/Ward/Rouse) resolve at once
## (the engine picks the ally); DAMAGE/Hex skills hit the foe at `target_index` (default: first alive).
## Resolves through the oracle, then pumps the enemy's responses. Public so the UI buttons + tests drive.
func player_use_skill(skill: String, target_index: int = -1) -> Dictionary:
	if _battle == null or _battle.is_ended() or skill == "" or _beats_playing:
		return _last_step
	_hide_menus()
	var actor: Variant = _pending_actor
	var verb := SkillBattleControllerScript.verb_of(skill)
	var step: Dictionary
	if SkillBattleControllerScript.is_support_verb(verb):
		step = _battle.use_skill(skill, null)
	else:
		var foes := _battle.enemy_team()
		var target: AbilityContainer = null
		if target_index >= 0 and target_index < foes.size():
			target = foes[target_index] as AbilityContainer
		step = _battle.use_skill(skill, target)
	_pending_skill = ""
	return _route_player_step(step, actor)


## Player CAPTURE the current wild target (default: first alive enemy, or `target_index` if given).
## Computes the oracle chance + canonical roll; success ends the battle as a catch (the creature joins
## the party on result apply), failure consumes the turn (enemy then acts). Wild battles only.
func player_capture(target_index: int = -1) -> Dictionary:
	if _battle == null or _battle.is_ended() or not _is_wild or _beats_playing:
		return _last_step
	var foes := _battle.enemy_team()
	var target := _resolve_capture_target(foes, target_index)
	if target == null:
		return _last_step
	_hide_menus()
	var gear := _gear_ids()
	# attempt_capture internally advances on a failure, so its outcome may ALREADY be the first
	# enemy response (RESOLVED — a beat), the next player turn (AWAIT) or the catch (ENDED).
	var outcome := _battle.attempt_capture(target, gear)
	_pending_skill = ""
	var kind := str(outcome.get("kind", ""))
	if kind == _STEP_RESOLVED:
		_pump(_capture_beat(outcome.get("actor")))
	else:
		_last_step = outcome
		_play_or_drain([], outcome)
	return _last_step


## Forfeit the pending actor's turn (the soft-lock escape for a degenerate no-action kit). Drives the
## actor through the oracle AI (which does nothing when it has no usable verb), then pumps the enemy.
func player_pass() -> Dictionary:
	if _battle == null or _battle.is_ended() or _beats_playing:
		return _last_step
	_hide_menus()
	var actor: Variant = _pending_actor
	var step: Dictionary = _battle.act_neutral()
	_pending_skill = ""
	return _route_player_step(step, actor)


## True when the pending actor has at least one LIVING ally other than itself — the only state in which
## a Rouse skill (whose engine target excludes the user) can resolve. Read off the live player team.
func _rouse_has_target() -> bool:
	if _battle == null or _pending_actor == null:
		return false
	for ally in _battle.player_team():
		if ally != _pending_actor and (ally as AbilityContainer).is_alive():
			return true
	return false


## Player FLEE (wild only) — ends the battle, returns to the overworld with the run intact (no xp).
func player_flee() -> Dictionary:
	if _battle == null or _battle.is_ended() or not _is_wild or _beats_playing:
		return _last_step
	_hide_menus()
	var step := _battle.flee()
	_last_step = step
	_apply_step(step)
	return _last_step


## Finalise: build the Slice-shaped result from the finished session, apply it to the run (xp + any
## caught creature), clear pending, persist, and show the outcome banner + Continue affordance.
func _finish_battle(step: Dictionary) -> void:
	if _session == null or _battle == null:
		return
	var reason := str(step.get("reason", ""))
	_result = _session.skill_result_for(_battle.session(), _battle.caught())
	# Wave 3 boss wiring: a PLAYED boss fight reports boss_win (player standing + boss side wiped)
	# so GameController._mark_slice_cleared fires through the same apply path as the auto battle.
	if _is_boss:
		_result["boss_win"] = (
			bool(_result.get("player_won", false))
			and (_result.get("enemy_survivors", []) as Array).is_empty()
		)
	# Wave 3 consequence: carry the live end-of-battle HP home; GameController folds it into
	# run.party so the next fight starts with the wounds this one left.
	_result["party_hp"] = _live_party_hp()
	if _game != null and _game.has_method("apply_battle_result"):
		_game.call("apply_battle_result", _result)
	if _game != null and _game.has_method("save_run"):
		_game.call("save_run")
	if reason == "caught":
		play_stinger("capture_sting")  # the catch lands with its own sting (W-SND)
	_toast_outcome(reason)
	_show_banner_text(_banner_text_for(reason))
	_hide_menus()
	_show_continue()


# === accessors ================================================================================ #


## The battle result (winner / survivors / xp / transcript / caught). Empty until the battle ends.
func result() -> Dictionary:
	return _result


## The most recent session step (await_player / resolved / ended). For headless test assertions.
func last_step() -> Dictionary:
	return _last_step


## The live interactive battle wrapper (for tests that want to read teams / capture math directly).
func battle() -> BattleSession.SkillInteractiveBattle:
	return _battle


## Total beats routed through the queue so far (Wave 8 test bookkeeping).
func beats_processed() -> int:
	return _beats_processed


## The most recent pump's beat queue (Wave 8 test bookkeeping — order + per-beat log deltas).
func last_beat_batch() -> Array:
	return _last_beat_batch


## Force instant/drain mode on or off (tests exercise both routes explicitly).
func set_instant_beats(enabled: bool) -> void:
	_instant_beats = enabled


## Return to the overworld (the loop closes). Public so input + the Continue button both call it.
func return_to_overworld() -> void:
	if _transition != null and _transition.has_method("change_scene_ritual"):
		await _transition.call("change_scene_ritual", OVERWORLD_SCENE)
	elif is_inside_tree():
		get_tree().change_scene_to_file(OVERWORLD_SCENE)


func _input_event_confirm() -> void:
	return_to_overworld()


func _process(_delta: float) -> void:
	if _input == null or _beats_playing:
		# While the beat queue narrates, CONFIRM is the fast-forward (held), never the exit.
		return
	# After the battle ends, Confirm returns to the overworld (matches Slice 1).
	if _battle != null and _battle.is_ended() and _input.has_method("just_pressed"):
		if bool(_input.call("just_pressed", InputActions.CONFIRM)):
			set_process(false)
			return_to_overworld()


# === helpers ================================================================================== #


func _resolve_capture_target(foes: Array, target_index: int) -> AbilityContainer:
	if target_index >= 0 and target_index < foes.size():
		var chosen := foes[target_index] as AbilityContainer
		if chosen != null and chosen.is_alive():
			return chosen
	for f in foes:
		var m := f as AbilityContainer
		if m.is_alive():
			return m
	return null


func _gear_ids() -> Array:
	if _game == null:
		return []
	var run: RunContext = _game.call("run")
	if run == null:
		return []
	return CaptureServiceScript.gear_ids(run.gear)


## The live end-of-battle HP of every player combatant, mapped back to its run.party INDEX through
## the SkillInteractiveBattle's player source map (identity-safe even if the factory skipped an
## unassemblable entry). Shape: [{ "index": int, "hp": int, "max_hp": int }, ...] — the payload
## GameController.apply_battle_result folds into run.party (Wave 3 consequence).
func _live_party_hp() -> Array:
	var out: Array = []
	if _battle == null or _game == null or not _battle.has_method("player_source"):
		return out
	var run: RunContext = _game.call("run")
	if run == null:
		return out
	var source: Dictionary = _battle.player_source()
	for ac_v in _battle.player_team():
		var ac := ac_v as AbilityContainer
		var creature: Variant = source.get(ac, null)
		if creature == null:
			continue
		for i in run.party.size():
			if run.party[i] is Dictionary and is_same(run.party[i], creature):
				out.append({"index": i, "hp": maxi(0, ac.hp()), "max_hp": ac.max_hp()})
				break
	return out


func _toast_outcome(reason: String) -> void:
	var toast := get_node_or_null("/root/Toast")
	if toast == null:
		return
	if reason == "caught" and toast.has_method("event_with"):
		# Wave 9: the catch toast bears the creature's one-of-one sigil (its mark stamps in the
		# icon slot — the same geometry party/lab render for this creature forever after).
		var sigil := BattleCardKitScript.caught_sigil_payload(_battle, _game)
		toast.call("event_with", "creature_caught", {"sigil": sigil})
	elif reason == "caught" and toast.has_method("event"):
		toast.call("event", "creature_caught")
	elif bool(_result.get("stalemate", false)) and toast.has_method("show"):
		# The verbatim voice line (§5.5) + the reduced-reward note — the honest stalemate copy.
		(
			toast
			. call(
				"show",
				{
					"title": STALEMATE_BANNER,
					"body": STALEMATE_VOICE_LINE + "\n(Spoils halved.)",
					"sound": "chime",
				}
			)
		)
	elif toast.has_method("show"):
		toast.call("show", {"title": _banner_text_for(reason), "body": "", "sound": "chime"})


func _banner_text_for(reason: String) -> String:
	# Wave 3 honesty: the turn cap expiring with enemies still standing is NOT a victory — the
	# distinct stalemate banner replaces the old lying VICTORY over an undamaged enemy.
	if bool(_result.get("stalemate", false)):
		return STALEMATE_BANNER
	match reason:
		"caught":
			return "CAUGHT"
		"fled":
			return "FLED"
		_:
			return "VICTORY" if bool(_result.get("player_won", false)) else "DEFEAT"


# === UI (minimal, code-built, themed) ========================================================= #


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()
	_party_cards.clear()
	_enemy_cards.clear()
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.06, 0.09)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# Wave 8 backdrop-lite: the region's painterly backdrop (dim battle variant) replaces the flat
	# void — picked by the encounter's force climate, sitting UNDER the vignette so HUD text keeps
	# its contrast grade.
	var backdrop_tex: Texture2D = BattleCardKitScript.pick_backdrop(_region_force, _is_wild)
	if backdrop_tex != null:
		var backdrop := TextureRect.new()
		backdrop.name = "ArenaBackdrop"
		backdrop.texture = backdrop_tex
		backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
		backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(backdrop)
	# A radial vignette grades the arena toward its dark edges (atmosphere, not gameplay).
	var vig := TextureRect.new()
	vig.texture = BattleCardKitScript.make_vignette(256)
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vig)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)

	var box := VBoxContainer.new()
	box.name = "RootBox"
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	_root_box = box

	# The combatant area scrolls if it ever overflows, so the action verbs below are
	# ALWAYS on-screen — no viewport size may ever clip Flee/Capture off the bottom.
	var top_scroll := ScrollContainer.new()
	top_scroll.name = "CombatantScroll"
	top_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_scroll.size_flags_stretch_ratio = 3.0
	top_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(top_scroll)
	var top_box := VBoxContainer.new()
	top_box.add_theme_constant_override("separation", 8)
	top_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_scroll.add_child(top_box)

	_banner = Label.new()
	_banner.name = "ResultBanner"
	_banner.theme_type_variation = "TitleLabel"
	top_box.add_child(_banner)

	_turn_label = Label.new()
	_turn_label.name = "TurnIndicator"
	_turn_label.theme_type_variation = "MutedLabel"
	top_box.add_child(_turn_label)

	var teams := HBoxContainer.new()
	teams.add_theme_constant_override("separation", 24)
	top_box.add_child(teams)

	var party_box := VBoxContainer.new()
	party_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	teams.add_child(party_box)
	var party_title := Label.new()
	party_title.text = "Your Coven"
	party_title.theme_type_variation = "MutedLabel"
	party_box.add_child(party_title)
	_party_rows = VBoxContainer.new()
	_party_rows.name = "PartyRows"
	party_box.add_child(_party_rows)

	var enemy_box := VBoxContainer.new()
	enemy_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	teams.add_child(enemy_box)
	var enemy_title := Label.new()
	enemy_title.text = "The Wild" if _is_wild else "Adversary"
	enemy_title.theme_type_variation = "MutedLabel"
	enemy_box.add_child(enemy_title)
	_enemy_rows = VBoxContainer.new()
	_enemy_rows.name = "EnemyRows"
	enemy_box.add_child(_enemy_rows)

	_action_menu = VBoxContainer.new()
	_action_menu.name = "ActionMenu"
	box.add_child(_action_menu)

	_target_picker = VBoxContainer.new()
	_target_picker.name = "TargetPicker"
	box.add_child(_target_picker)

	# Wave 8 (HAWKING veto honored: demoted, never deleted): the transcript is a COLLAPSIBLE
	# drawer — the beat playback IS the narration now; "The Record" opens the written ledger.
	# The utility row also carries the Swift Rites pacing toggle (persisted, x1/x2/instant).
	var utility := HBoxContainer.new()
	utility.name = "UtilityRow"
	utility.add_theme_constant_override("separation", 8)
	box.add_child(utility)
	_record_button = Button.new()
	_record_button.name = "RecordToggle"
	_record_button.text = "The Record ▸"
	_record_button.pressed.connect(toggle_record)
	utility.add_child(_record_button)
	_swift_button = Button.new()
	_swift_button.name = "SwiftRitesButton"
	_swift_button.pressed.connect(func() -> void: cycle_swift_rites())
	utility.add_child(_swift_button)
	_update_swift_button()

	_log_panel = PanelContainer.new()
	_log_panel.name = "RecordDrawer"
	_log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_panel.visible = false  # collapsed by default — beats narrate; the drawer archives
	box.add_child(_log_panel)
	_scroll = ScrollContainer.new()
	_log_panel.add_child(_scroll)
	_transcript_label = RichTextLabel.new()
	_transcript_label.name = "TranscriptLog"
	_transcript_label.fit_content = true
	_transcript_label.scroll_active = false
	# Cap the transcript's reserved height to a viewport fraction — on small windows the
	# old fixed 220px starved the layout and pushed the action verbs off-screen.
	var log_min_h := minf(220.0, get_viewport_rect().size.y * 0.18)
	_transcript_label.custom_minimum_size = Vector2(0, log_min_h)
	_scroll.add_child(_transcript_label)
	_shown_log = 0
	_log_watermark = 0

	# Top-most overlay for floating damage numbers (mouse-transparent, full-rect).
	_fx_layer = Control.new()
	_fx_layer.name = "FxLayer"
	_fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx_layer)

	_refresh_combatants()


## Refresh both teams. Cards are built ONCE then updated in place, so HP changes can flash the
## portrait without rebuilding (and node identity is stable for animations). The card build/update
## work lives in BattleCardKit (Wave 8 extraction — battle_screen stays under the line cap).
func _refresh_combatants() -> void:
	if _battle == null:
		return
	if _party_cards.is_empty():
		_build_team_cards(_party_rows, _battle.player_team(), false, _party_cards)
	if _enemy_cards.is_empty():
		_build_team_cards(_enemy_rows, _battle.enemy_team(), true, _enemy_cards)
	BattleCardKitScript.update_team_cards(_party_cards, _battle.player_team(), status_for, self)
	BattleCardKitScript.update_team_cards(_enemy_cards, _battle.enemy_team(), status_for, self)


## Build a team's portrait cards once into `container`, recording node refs in `cards`.
func _build_team_cards(container: VBoxContainer, team: Array, is_enemy: bool, cards: Array) -> void:
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()
	cards.clear()
	for i in team.size():
		var ac := team[i] as AbilityContainer
		var creature := _creature_dict_for(is_enemy, i)
		cards.append(
			BattleCardKitScript.make_card(
				container, ac, _species_id_for(is_enemy, i, ac), is_enemy, status_for(ac), creature
			)
		)


## The run-party creature_instance backing a PLAYER card (by team index), so hybrids (species_id "")
## can render their dominant-parent plate + corruption tint. {} for enemies / unresolvable indices
## (the species-id path covers those).
func _creature_dict_for(is_enemy: bool, index: int) -> Dictionary:
	if is_enemy or _game == null:
		return {}
	var run: RunContext = _game.call("run")
	if run == null or index < 0 or index >= run.party.size():
		return {}
	var entry: Variant = run.party[index]
	return entry if entry is Dictionary else {}


## The StatusContainer fronting `ac` (statuses / corruption), or null when the status layer is
## off. Public: BattleCardKit resolves chip state through it (Wave 8 extraction).
func status_for(ac: AbilityContainer) -> StatusContainer:
	if _battle == null or not _battle.has_method("session"):
		return null
	var sess: Variant = _battle.session()
	if sess == null or not sess.has_method("status_of"):
		return null
	return sess.status_of(ac)


## The species id backing a card's combatant (enemy via species_for, player via the captured party order).
func _species_id_for(is_enemy: bool, index: int, ac: AbilityContainer) -> String:
	if is_enemy:
		if _battle != null and _battle.has_method("species_for"):
			var sd: Variant = _battle.species_for(ac)
			if sd != null:
				return str(sd.id)
		return ""
	return str(_player_species[index]) if index < _player_species.size() else ""


## Flush every transcript line not yet shown (terminal steps: turn headers before an AWAIT, the
## RESULT line on an END) and advance the beat watermark past them.
func _flush_transcript() -> void:
	if _battle == null:
		return
	var total: int = _battle.transcript().size()
	append_transcript_to(total)
	_log_watermark = total


## Append transcript lines up to index `upto` via RichTextLabel.add_text — the Wave 8 per-beat
## append that replaced the old full-text O(n²) rebuild. Raw text (add_text, not append_text) so
## engine log lines with brackets never parse as BBCode. Watermarked: each line lands exactly once.
func append_transcript_to(upto: int) -> void:
	if _transcript_label == null or _battle == null:
		return
	var lines: Array = _battle.transcript()
	var target := mini(upto, lines.size())
	while _shown_log < target:
		if _shown_log > 0:
			_transcript_label.add_text("\n")
		_transcript_label.add_text(str(lines[_shown_log]))
		_shown_log += 1


func _refresh_turn_label(step: Dictionary) -> void:
	if _turn_label == null:
		return
	var turn := int(step.get("turn", 0))
	var actor := step.get("actor") as AbilityContainer
	var who := actor.combatant_name() if actor != null else "—"
	# Entropy clock (design): the battlefield gets deadlier each turn — read from the SESSION (the
	# single source the oracle loop actually uses; Wave 3 deleted the duplicated local math).
	var entropy := 1.0
	if _battle != null:
		entropy = float(_battle.session().entropy())
	_turn_label.text = "Turn %d   ·   %s acts   ·   entropy ×%.2f" % [turn, who, entropy]


## Show the player action menu: ONE button per skill in the acting creature's kit (verb · name),
## plus Capture + Flee (wild only). A SUPPORT skill resolves at once; a DAMAGE/Hex skill opens
## the foe target picker. One skill = the actor's single action this turn (mirrors the engine's loop).
## Wave 3 (plan tension 5): the "(N AP)" suffix is DELETED — no AP pool exists in the engine, and
## the surface never advertises unbuilt mechanics. No AP chip returns until an oracle-first AP
## phase ships.
func _show_action_menu() -> void:
	_hide_target_picker()
	if _action_menu == null:
		return
	for child in _action_menu.get_children():
		child.queue_free()
	_action_menu.visible = true
	var lib: Dictionary = Constants.BALANCE["skill"]["library"]
	var kit: Array = _pending_actor.abilities() if _pending_actor != null else []
	var actionable := 0
	for i in kit.size():
		var skill := str(kit[i])
		var sk: Dictionary = lib.get(skill, {})
		var verb := str(sk.get("verb", ""))
		# A Rouse with no eligible ally (a last-survivor / solo actor) can't resolve — its engine target
		# excludes the user + the dead — so omit the button rather than offer a turn-wasting no-op.
		if verb == "Rouse" and not _rouse_has_target():
			continue
		var btn := Button.new()
		btn.name = "SkillButton%d" % i
		btn.text = "%s · %s" % [verb, skill]
		var chosen := skill
		if SkillBattleControllerScript.is_support_verb(verb):
			btn.pressed.connect(func() -> void: player_use_skill(chosen))
		else:
			btn.pressed.connect(func() -> void: _show_target_picker(chosen))
		_action_menu.add_child(btn)
		actionable += 1
	if _is_wild:
		var capture_btn := Button.new()
		capture_btn.name = "CaptureButton"
		capture_btn.text = "Capture"
		capture_btn.pressed.connect(func() -> void: player_capture())
		_action_menu.add_child(capture_btn)
		var flee_btn := Button.new()
		flee_btn.name = "FleeButton"
		flee_btn.text = "Flee"
		flee_btn.pressed.connect(func() -> void: player_flee())
		_action_menu.add_child(flee_btn)
		actionable += 2
	# Soft-lock guard: if the actor has NO usable action (degenerate empty kit in a non-wild fight),
	# offer a Pass so the interactive pump can never stall waiting on an impossible player turn.
	if actionable == 0:
		var pass_btn := Button.new()
		pass_btn.name = "PassButton"
		pass_btn.text = "Pass"
		pass_btn.pressed.connect(func() -> void: player_pass())
		_action_menu.add_child(pass_btn)
	# W1 focus pass: the first action owns focus EVERY time the menu shows, so each new turn is
	# immediately keyboard/gamepad-drivable (the rebuilt buttons wiped any prior focus).
	_focus_first_button(_action_menu)


## Show one button per alive enemy — the target picker for the damage `skill` the player chose.
func _show_target_picker(skill: String) -> void:
	if _target_picker == null or _battle == null:
		return
	for child in _target_picker.get_children():
		child.queue_free()
	_pending_skill = skill
	_target_picker.visible = true
	var foes := _battle.enemy_team()
	for i in foes.size():
		var ac := foes[i] as AbilityContainer
		if not ac.is_alive():
			continue
		var btn := Button.new()
		btn.name = "Target%d" % i
		btn.text = "→ %s  (%d/%d)" % [ac.combatant_name(), maxi(0, ac.hp()), ac.max_hp()]
		var idx := i
		var chosen := skill
		btn.pressed.connect(func() -> void: player_use_skill(chosen, idx))
		_target_picker.add_child(btn)
	# Focus follows the decision: the first target owns focus while the picker is up.
	_focus_first_button(_target_picker)


## Focus a menu's first LIVE Button (W1 focus pass). Skips buttons already queue_freed by the
## rebuild (they linger as children until end of frame). No-op before the menu enters the tree.
func _focus_first_button(menu: Container) -> void:
	if menu == null or not menu.is_inside_tree():
		return
	for child in menu.get_children():
		if child is Button and not child.is_queued_for_deletion():
			(child as Button).grab_focus()
			return


func _hide_menus() -> void:
	if _action_menu != null:
		for child in _action_menu.get_children():
			child.queue_free()
		_action_menu.visible = false
	_hide_target_picker()


func _hide_target_picker() -> void:
	if _target_picker == null:
		return
	for child in _target_picker.get_children():
		child.queue_free()
	_target_picker.visible = false


func _show_banner_text(text: String) -> void:
	if _banner == null:
		return
	_banner.text = text
	var win := text == "VICTORY" or text == "CAUGHT"
	_banner.add_theme_color_override(
		"font_color", Color(0.55, 0.85, 0.45) if win else Color(0.85, 0.55, 0.35)
	)


func _show_continue() -> void:
	if _continue_button != null and is_instance_valid(_continue_button):
		return
	_continue_button = Button.new()
	_continue_button.name = "ContinueButton"
	_continue_button.text = "Return to the Verdant"
	_continue_button.pressed.connect(_input_event_confirm)
	if _root_box != null and is_instance_valid(_root_box):
		_root_box.add_child(_continue_button)
	else:
		add_child(_continue_button)


# === Wave 8 — beat-player surface (duck-typed by battle_beats.gd) + pacing + backdrop ========= #


## True while CONFIRM is held — the beat fast-forward gesture (never-wait-twice, tension 10).
func confirm_held() -> bool:
	if _input == null or not _input.has_method("is_pressed"):
		return false
	return bool(_input.call("is_pressed", InputActions.CONFIRM))


## The card node-refs dict backing `actor` (searched by identity across both teams), or {}.
func card_refs_for(actor: Variant) -> Dictionary:
	if _battle == null or actor == null:
		return {}
	var teams: Array = [_battle.player_team(), _battle.enemy_team()]
	var cardsets: Array = [_party_cards, _enemy_cards]
	for s in 2:
		var team: Array = teams[s]
		var cards: Array = cardsets[s]
		for i in team.size():
			if team[i] == actor and i < cards.size():
				return cards[i]
	return {}


## One side's card refs, index-aligned with the beat snapshots (false = party, true = enemy).
func side_cards(is_enemy: bool) -> Array:
	return _enemy_cards if is_enemy else _party_cards


## Re-style an HP bar's colour band after a glide lands (green -> amber -> red by fraction).
func restyle_bar(bar: ProgressBar) -> void:
	BattleCardKitScript.style_hp_bar(bar)


## Float a damage number off a card (the beat player's + card kit's impact feedback hook).
func fx_damage(card: Variant, amount: int) -> void:
	BattleCardKitScript.spawn_damage_number(_fx_layer, card as Control, amount)


## Fire a one-shot through the SfxService autoload (headless-safe: play() records + returns).
func play_stinger(sound_id: String, pitch_jitter: float = 0.0) -> void:
	var sfx := get_node_or_null("/root/SfxService")
	if sfx != null and sfx.has_method("play"):
		sfx.call("play", sound_id, pitch_jitter)


## Toggle the transcript drawer ("The Record"). Collapsed by default — HAWKING's veto keeps the
## written ledger reachable; the beat playback carries the moment-to-moment narration.
func toggle_record() -> void:
	if _log_panel == null:
		return
	_log_panel.visible = not _log_panel.visible
	if _record_button != null:
		_record_button.text = "The Record ▾" if _log_panel.visible else "The Record ▸"


## The persisted Swift Rites pacing setting ("x1" / "x2" / "instant") from Settings (battle
## section), with a local fallback when no autoload is present (bare test screens).
func _swift_rites() -> String:
	var settings := get_node_or_null("/root/Settings")
	if settings != null and settings.has_method("get_value"):
		return str(settings.call("get_value", "battle", "swift_rites", "x1"))
	return _swift_local if _swift_local != "" else "x1"


## Beat duration multiplier for the current Swift Rites speed (x2 halves every beat).
func _beat_time_scale() -> float:
	return 0.5 if _swift_rites() == "x2" else 1.0


## Cycle Swift Rites x1 -> x2 -> instant (persisted immediately through Settings). Public: the
## toggle button and tests drive it. Returns the new mode.
func cycle_swift_rites() -> String:
	var idx := SWIFT_RITES_ORDER.find(_swift_rites())
	var next_mode := str(SWIFT_RITES_ORDER[(idx + 1) % SWIFT_RITES_ORDER.size()])
	var settings := get_node_or_null("/root/Settings")
	if settings != null and settings.has_method("set_value"):
		settings.call("set_value", "battle", "swift_rites", next_mode)
		settings.call("save_settings")
	_swift_local = next_mode
	# Headless stays instant regardless (the make-or-break suite contract); windowed play follows.
	if DisplayServer.get_name() != "headless":
		_instant_beats = next_mode == "instant"
	_update_swift_button()
	return next_mode


func _update_swift_button() -> void:
	if _swift_button == null:
		return
	var mode := _swift_rites()
	var speed_label := "×1"
	if mode == "x2":
		speed_label = "×2"
	elif mode == "instant":
		speed_label = "Instant"
	_swift_button.text = "Swift Rites: " + speed_label
