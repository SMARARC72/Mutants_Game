class_name BattleSession
extends RefCounted
## BattleSession (Phase 5 · Slice 1) — the headless battle ROUND-TRIP the overworld hands off to.
## APPLICATION/battle layer. Given (player team, enemy team, battle_seed) it:
##   1. builds BattleEngine.Mon teams from creature dicts via MonFactory (catalog-driven),
##   2. runs the BattleController (AI SELECTS via CombatBrain, oracle RESOLVES via BattleEngine),
##   3. returns a pure-data RESULT dict (winner / survivors / xp / transcript) for the overworld.
##
## DETERMINISM (the slice DoD): all battle randomness draws from CanonicalRNG.new(battle_seed) —
## the controller derives its disjoint RES/SEL sub-streams from it (ADR-016). Same battle_seed +
## same teams => byte-identical transcript and result. Slice 1 uses the neutral CombatBrain for
## BOTH sides (player auto-resolves this slice; full player input is a later slice), which is
## byte-identical to BattleEngine.simulate while still routing every strike through the
## brain->oracle path. The enemy is driven by the CombatBrain facade, as the slice requires.
##
## NO scene / Node here — this is unit-testable headless. The presentation battle screen just runs
## a session and renders its result.

const BattleControllerScript := preload("res://application/battle/battle_controller.gd")
const CombatBrainScript := preload("res://application/ai/combat_brain.gd")
const MonFactoryScript := preload("res://application/battle/mon_factory.gd")
const SkillMonFactoryScript := preload("res://application/battle/skill_mon_factory.gd")
const SkillBattleControllerScript := preload("res://application/battle/skill_battle_controller.gd")
const CaptureServiceScript := preload("res://application/battle/capture_service.gd")

## XP awarded to the winning side per defeated enemy (Slice 1 placeholder economy; the real
## level/xp curve is a later slice). Data only — no growth math here.
const XP_PER_DEFEAT := 12

var _catalog: SpeciesCatalog


func _init(catalog: SpeciesCatalog = null) -> void:
	_catalog = catalog if catalog != null else SpeciesCatalog.new()


## Run a battle. `player_party` / `enemy_party` are Array[Dictionary] (creature dicts:
## {species_id, nickname?}). `battle_seed` seeds the canonical battle RNG. Returns a result dict:
##   {
##     "winner": "player"|"enemy",
##     "player_won": bool,
##     "turns": int,
##     "player_survivors": Array[String],   # nicknames/names still standing
##     "enemy_survivors": Array[String],
##     "player_defeated": int,              # enemy mons the player downed
##     "enemy_defeated": int,
##     "xp": int,                           # xp to the player (0 on loss)
##     "transcript": Array[String],         # the BattleController log (renderable + diffable)
##     "valid": bool                        # false if a team could not be assembled
##   }
func run(player_party: Array, enemy_party: Array, battle_seed: int) -> Dictionary:
	var team_a := MonFactoryScript.team_from_creatures(player_party, _catalog)
	var team_b := MonFactoryScript.team_from_creatures(enemy_party, _catalog)
	if team_a.is_empty() or team_b.is_empty():
		return _invalid_result()

	var run_rng := CanonicalRNG.new(battle_seed)
	var brain: CombatBrain = CombatBrainScript.new()
	var controller: BattleController = BattleControllerScript.new(brain, run_rng)
	var transcript: Array = controller.run(team_a, team_b)

	var player_won := _any_alive(team_a)
	var player_survivors := _alive_names(team_a)
	var enemy_survivors := _alive_names(team_b)
	var enemy_defeated := _dead_count(team_b)
	var player_defeated := _dead_count(team_a)
	var xp := XP_PER_DEFEAT * enemy_defeated if player_won else 0
	return {
		"winner": "player" if player_won else "enemy",
		"player_won": player_won,
		"turns": _turns_from_transcript(transcript),
		"player_survivors": player_survivors,
		"enemy_survivors": enemy_survivors,
		"player_defeated": player_defeated,
		"enemy_defeated": enemy_defeated,
		"xp": xp,
		"transcript": transcript,
		"valid": true,
	}


## Run the Verdant LEGENDARY-BOSS fight (Slice 4) — the region climax. Identical round-trip to run(),
## except the enemy team is driven by a strong ROLE brain (CombatBrain.assign_role(mon, brain_role),
## default "controller") instead of the neutral parity brain — the boss plays to win, exploiting force
## matchups. Deterministic for a fixed (battle_seed, teams, brain_role). The result carries
## `boss_win` (true iff the player downed the boss) so the caller can set the slice-cleared flag.
## `brain_role` is one of RoleBrains' roles ("controller"/"aggressor"/...); the full Succession HSM is
## reserved for god-tier and is NOT used here. Returns the same result shape as run() + `boss_win`.
func run_boss(
	player_party: Array, boss_party: Array, battle_seed: int, brain_role: String = "controller"
) -> Dictionary:
	var team_a := MonFactoryScript.team_from_creatures(player_party, _catalog)
	var team_b := MonFactoryScript.team_from_creatures(boss_party, _catalog)
	if team_a.is_empty() or team_b.is_empty():
		var inv := _invalid_result()
		inv["boss_win"] = false
		return inv

	var run_rng := CanonicalRNG.new(battle_seed)
	var brain: CombatBrain = CombatBrainScript.new()
	# Assign the strong role brain to every boss-side combatant (a Verdant Legendary is a single
	# creature, but the loop keeps it correct if the boss arrives with adds).
	for mon in team_b:
		brain.assign_role(mon as BattleEngine.Mon, brain_role)
	var controller: BattleController = BattleControllerScript.new(brain, run_rng)
	var transcript: Array = controller.run(team_a, team_b)

	var player_won := _any_alive(team_a)
	var enemy_defeated := _dead_count(team_b)
	var xp := XP_PER_DEFEAT * enemy_defeated if player_won else 0
	# boss_win: the boss team is fully downed (the player cleared the climax).
	var boss_win := player_won and not _any_alive(team_b)
	return {
		"winner": "player" if player_won else "enemy",
		"player_won": player_won,
		"boss_win": boss_win,
		"turns": _turns_from_transcript(transcript),
		"player_survivors": _alive_names(team_a),
		"enemy_survivors": _alive_names(team_b),
		"player_defeated": _dead_count(team_a),
		"enemy_defeated": enemy_defeated,
		"xp": xp,
		"transcript": transcript,
		"valid": true,
	}


## Begin an INTERACTIVE battle (Slice 2). Builds the player + enemy teams (with the enemy Mon→creature
## source map for capture), the BattleController interactive session, and a CaptureService bound to
## the SAME battle_seed (a DISJOINT canonical capture sub-stream). The player drives side "A". Returns
## an InteractiveBattle wrapper the UI/test drives turn-by-turn, or null if a team is unassemblable.
func begin_interactive(
	player_party: Array, enemy_party: Array, battle_seed: int
) -> InteractiveBattle:
	var team_a := MonFactoryScript.team_from_creatures(player_party, _catalog)
	var enemy_built: Dictionary = MonFactoryScript.team_with_source(enemy_party, _catalog)
	var team_b: Array = enemy_built["team"]
	if team_a.is_empty() or team_b.is_empty():
		return null
	var run_rng := CanonicalRNG.new(battle_seed)
	var brain: CombatBrain = CombatBrainScript.new()
	var controller: BattleController = BattleControllerScript.new(brain, run_rng)
	var session: BattleController.InteractiveSession = controller.interactive(team_a, team_b, "A")
	var capture := CaptureServiceScript.new(battle_seed)
	return InteractiveBattle.new(session, capture, _catalog, enemy_built["source"], team_a, team_b)


## Build the Slice-1-shaped result dict from a FINISHED interactive session (so the overworld + the
## save path treat an interactive battle exactly like an auto one). `caught` adds a "caught" winner
## tag + the captured creature_instance for the caller to fold into the party.
func result_for(
	session: BattleController.InteractiveSession, caught: Dictionary = {}
) -> Dictionary:
	var team_a := session.player_team()
	var team_b := session.enemy_team()
	var reason := session.end_reason()
	var player_won := session.player_won()
	var enemy_defeated := _dead_count(team_b)
	var xp := XP_PER_DEFEAT * enemy_defeated if player_won else 0
	var winner := "player" if player_won else "enemy"
	if reason == BattleController.InteractiveSession.END_CAUGHT:
		winner = "player"
		player_won = true
	elif reason == BattleController.InteractiveSession.END_FLED:
		winner = "fled"
		xp = 0
	return {
		"winner": winner,
		"player_won": player_won,
		"reason": reason,
		"turns": _turns_from_transcript(session.transcript()),
		"player_survivors": _alive_names(team_a),
		"enemy_survivors": _alive_names(team_b),
		"player_defeated": _dead_count(team_a),
		"enemy_defeated": enemy_defeated,
		"xp": xp,
		"caught": caught.duplicate(true),
		"transcript": session.transcript(),
		"valid": true,
	}


# --- SKILL interactive (Phase 10) ------------------------------------------------------------- #


## Begin an INTERACTIVE SKILL battle (the richer combat system: force-pool skills, 8 verbs, combos,
## shields/buffs). The SKILL counterpart to begin_interactive(): builds AbilityContainer teams (with the
## enemy container→creature source map for capture) via SkillMonFactory, the SkillBattleController
## interactive session (player on side "A"), and a CaptureService on the SAME battle_seed (a disjoint
## canonical capture sub-stream). Returns a SkillInteractiveBattle wrapper, or null if a team is
## unassemblable. Determinism is the SkillBattleController's (see its parity test).
func begin_skill_interactive(
	player_party: Array, enemy_party: Array, battle_seed: int
) -> SkillInteractiveBattle:
	# The player team keeps its container→creature-dict source map too (Wave 3): the battle screen
	# uses it to write live end-of-battle HP back to the exact run.party entries (skip-proof).
	var player_built: Dictionary = SkillMonFactoryScript.team_with_source(player_party, _catalog)
	var team_a: Array = player_built["team"]
	var enemy_built: Dictionary = SkillMonFactoryScript.team_with_source(enemy_party, _catalog)
	var team_b: Array = enemy_built["team"]
	if team_a.is_empty() or team_b.is_empty():
		return null
	var run_rng := CanonicalRNG.new(battle_seed)
	var controller = SkillBattleControllerScript.new(run_rng)
	# Real play runs WITH the status layer (DOTs / controls); the parity test drives the pure loop.
	var session = controller.interactive(team_a, team_b, "A", true)
	var capture := CaptureServiceScript.new(battle_seed)
	return SkillInteractiveBattle.new(
		session, capture, _catalog, enemy_built["source"], team_a, team_b, player_built["source"]
	)


## Build the Slice-1-shaped result dict from a FINISHED skill session (so the overworld + save path
## treat a skill battle like any other). `caught` adds the captured creature_instance. Uses the session's
## own turn() (the skill RESULT line format differs from the BattleEngine one, so we don't parse it).
## Wave 3 honesty: an END_DEFEAT with BOTH sides still standing is the TURN CAP expiring — a
## STALEMATE, not a victory. It is flagged (`stalemate`) and pays HALF spoils, so neither the banner
## nor the reward lies about an enemy that simply outlasted the clock.
func skill_result_for(session, caught: Dictionary = {}) -> Dictionary:
	var team_a: Array = session.player_team()
	var team_b: Array = session.enemy_team()
	var reason := str(session.end_reason())
	var player_won := bool(session.player_won())
	var enemy_defeated := _dead_count_ac(team_b)
	var xp := XP_PER_DEFEAT * enemy_defeated if player_won else 0
	var winner := "player" if player_won else "enemy"
	var stalemate := (
		reason == SkillBattleControllerScript.InteractiveSession.END_DEFEAT
		and player_won
		and _any_alive_ac(team_b)
	)
	if stalemate:
		xp = int(xp / 2.0)  # reduced reward: the wild slinks away with half the spoils
	if reason == SkillBattleControllerScript.InteractiveSession.END_CAUGHT:
		winner = "player"
		player_won = true
	elif reason == SkillBattleControllerScript.InteractiveSession.END_FLED:
		winner = "fled"
		xp = 0
	return {
		"winner": winner,
		"player_won": player_won,
		"reason": reason,
		"stalemate": stalemate,
		"turns": int(session.turn()),
		"player_survivors": _alive_names_ac(team_a),
		"enemy_survivors": _alive_names_ac(team_b),
		"player_defeated": _dead_count_ac(team_a),
		"enemy_defeated": enemy_defeated,
		"xp": xp,
		"caught": caught.duplicate(true),
		"transcript": session.transcript(),
		"valid": true,
	}


# --- helpers ---------------------------------------------------------------------------------- #


static func _any_alive_ac(team: Array) -> bool:
	for ac in team:
		if (ac as AbilityContainer).is_alive():
			return true
	return false


static func _alive_names_ac(team: Array) -> Array:
	var out: Array = []
	for ac in team:
		var c := ac as AbilityContainer
		if c.is_alive():
			out.append(c.combatant_name())
	return out


static func _dead_count_ac(team: Array) -> int:
	var n := 0
	for ac in team:
		if not (ac as AbilityContainer).is_alive():
			n += 1
	return n


static func _invalid_result() -> Dictionary:
	return {
		"winner": "enemy",
		"player_won": false,
		"turns": 0,
		"player_survivors": [],
		"enemy_survivors": [],
		"player_defeated": 0,
		"enemy_defeated": 0,
		"xp": 0,
		"transcript": [],
		"valid": false,
	}


static func _any_alive(team: Array) -> bool:
	for m in team:
		if (m as BattleEngine.Mon).alive:
			return true
	return false


static func _alive_names(team: Array) -> Array:
	var out: Array = []
	for m in team:
		var mon := m as BattleEngine.Mon
		if mon.alive:
			out.append(mon.name)
	return out


static func _dead_count(team: Array) -> int:
	var n := 0
	for m in team:
		if not (m as BattleEngine.Mon).alive:
			n += 1
	return n


## Parse the final turn number out of the controller transcript's RESULT line (the cheap, format-
## stable way to surface turn count without re-deriving the loop). Returns 0 if not found.
static func _turns_from_transcript(transcript: Array) -> int:
	for i in range(transcript.size() - 1, -1, -1):
		var line := str(transcript[i])
		if line.begins_with("RESULT:"):
			var marker := " wins on turn "
			var at := line.find(marker)
			if at != -1:
				var rest := line.substr(at + marker.length())
				var num := ""
				for ch in rest:
					if ch >= "0" and ch <= "9":
						num += ch
					else:
						break
				if num != "":
					return int(num)
	return 0


## InteractiveBattle — the wrapper the UI/test drives for a step-wise battle. Owns the controller's
## InteractiveSession + the CaptureService + the enemy Mon→creature source map (so a captured wild Mon
## resolves to its SpeciesData / creature dict). It is the SINGLE object the battle screen talks to:
## advance the pump, apply player verbs, run a capture attempt (oracle chance + canonical roll), and
## read teams/transcript/result. NO Node — headless-testable.
class InteractiveBattle:
	extends RefCounted

	var _session: BattleController.InteractiveSession
	var _capture: CaptureService
	var _catalog: SpeciesCatalog
	var _enemy_source: Dictionary  # Mon -> creature dict (its species_id)
	var _team_a: Array
	var _team_b: Array
	var _caught: Dictionary = {}  # the creature_instance shaped on a successful capture, else {}
	var _last_capture: Dictionary = {}

	func _init(
		session: BattleController.InteractiveSession,
		capture: CaptureService,
		catalog: SpeciesCatalog,
		enemy_source: Dictionary,
		team_a: Array,
		team_b: Array
	) -> void:
		_session = session
		_capture = capture
		_catalog = catalog
		_enemy_source = enemy_source
		_team_a = team_a
		_team_b = team_b

	# --- pump + player verbs (thin passthroughs to the session) ----------------------------------- #

	func advance() -> Dictionary:
		return _session.advance()

	func attack(target: BattleEngine.Mon) -> Dictionary:
		return _session.attack(target)

	func flee() -> Dictionary:
		return _session.flee()

	## Attempt to CAPTURE `target` (a wild enemy Mon). Computes the gear-/HP-modified chance via the
	## oracle, rolls on the canonical capture sub-stream, and — on success — shapes the creature_instance
	## (cached here for the caller to fold into the party). Then drives the session's capture verb
	## (SUCCESS → caught/end; FAILURE → the player's turn is spent, the enemy acts). `gear` is the run's
	## equipped gear id list (CaptureService.gear_ids(run.gear)). Returns the next session step dict;
	## the capture math itself is available via `last_capture()`.
	func attempt_capture(target: BattleEngine.Mon, gear: Array = []) -> Dictionary:
		var species := _species_for(target)
		var outcome := _capture.attempt(target, species, gear)
		_last_capture = outcome
		if bool(outcome["success"]):
			_caught = outcome["creature_instance"]
		return _session.capture(bool(outcome["success"]))

	# --- reads ------------------------------------------------------------------------------------ #

	func session() -> BattleController.InteractiveSession:
		return _session

	func player_team() -> Array:
		return _team_a

	func enemy_team() -> Array:
		return _team_b

	func transcript() -> Array:
		return _session.transcript()

	func is_ended() -> bool:
		return _session.is_ended()

	## The creature_instance captured this battle (shaped), or {} if nothing was caught.
	func caught() -> Dictionary:
		return _caught

	## The last capture attempt's math: {success, chance, roll, creature_instance}. {} before any try.
	func last_capture() -> Dictionary:
		return _last_capture

	## The SpeciesData backing an enemy Mon (via the source map), or null if unknown.
	func species_for(target: BattleEngine.Mon) -> SpeciesData:
		return _species_for(target)

	# --- internals -------------------------------------------------------------------------------- #

	func _species_for(target: BattleEngine.Mon) -> SpeciesData:
		var creature: Variant = _enemy_source.get(target, null)
		if creature == null or not (creature is Dictionary):
			return null
		return _catalog.get_by_id(str((creature as Dictionary).get("species_id", "")))


## SkillInteractiveBattle — the wrapper the UI/test drives for a step-wise SKILL battle. The skill
## counterpart to InteractiveBattle: owns the SkillBattleController.InteractiveSession + the
## CaptureService + the enemy AbilityContainer→creature source map. Thin passthroughs to the session for
## the pump + player verbs (use_skill / act_neutral / flee), plus a capture attempt that resolves the
## oracle chance + canonical roll on the AbilityContainer's live hp/tier (the decoupled CaptureService
## path). NO Node — headless-testable.
class SkillInteractiveBattle:
	extends RefCounted

	var _session
	var _capture: CaptureService
	var _catalog: SpeciesCatalog
	var _enemy_source: Dictionary  # AbilityContainer -> creature dict (its species_id)
	var _player_source: Dictionary = {}  # AbilityContainer -> the ORIGINAL run.party dict (Wave 3)
	var _team_a: Array
	var _team_b: Array
	var _caught: Dictionary = {}
	var _last_capture: Dictionary = {}

	func _init(
		session,
		capture: CaptureService,
		catalog: SpeciesCatalog,
		enemy_source: Dictionary,
		team_a: Array,
		team_b: Array,
		player_source: Dictionary = {}
	) -> void:
		_session = session
		_capture = capture
		_catalog = catalog
		_enemy_source = enemy_source
		_team_a = team_a
		_team_b = team_b
		_player_source = player_source

	# --- pump + player verbs (thin passthroughs to the session) ----------------------------------- #

	func advance() -> Dictionary:
		return _session.advance()

	func use_skill(skill: String, target: AbilityContainer = null) -> Dictionary:
		return _session.use_skill(skill, target)

	func act_neutral() -> Dictionary:
		return _session.act_neutral()

	func flee() -> Dictionary:
		return _session.flee()

	## Attempt to CAPTURE a wild enemy AbilityContainer. Computes the gear-/HP-modified chance via the
	## oracle (from the container's live hp/maxhp + its species tier), rolls on the canonical capture
	## sub-stream, and on success shapes + caches the creature_instance. Then drives the session's capture
	## verb (SUCCESS → caught/end; FAILURE → the turn is spent, the enemy acts). Returns the next step.
	func attempt_capture(target: AbilityContainer, gear: Array = []) -> Dictionary:
		var species := _species_for(target)
		var tier := species.tier if species != null else "T1"
		var hp_frac := 1.0
		if target != null and target.max_hp() > 0:
			hp_frac = float(target.hp()) / float(target.max_hp())
		var name := target.combatant_name() if target != null else ""
		var outcome := _capture.attempt_from(name, tier, hp_frac, species, gear)
		_last_capture = outcome
		if bool(outcome["success"]):
			_caught = outcome["creature_instance"]
		return _session.capture(bool(outcome["success"]))

	# --- reads ------------------------------------------------------------------------------------ #

	func session():
		return _session

	func player_team() -> Array:
		return _team_a

	func enemy_team() -> Array:
		return _team_b

	func transcript() -> Array:
		return _session.transcript()

	func is_ended() -> bool:
		return _session.is_ended()

	func caught() -> Dictionary:
		return _caught

	func last_capture() -> Dictionary:
		return _last_capture

	## The player-side AbilityContainer → ORIGINAL creature-dict map (identity-keyed, Wave 3): the
	## battle screen maps live end-of-battle HP back onto the exact run.party entries through it.
	func player_source() -> Dictionary:
		return _player_source

	## The SpeciesData backing an enemy AbilityContainer (via the source map), or null if unknown.
	func species_for(target: AbilityContainer) -> SpeciesData:
		return _species_for(target)

	# --- internals -------------------------------------------------------------------------------- #

	func _species_for(target: AbilityContainer) -> SpeciesData:
		var creature: Variant = _enemy_source.get(target, null)
		if creature == null or not (creature is Dictionary):
			return null
		return _catalog.get_by_id(str((creature as Dictionary).get("species_id", "")))
