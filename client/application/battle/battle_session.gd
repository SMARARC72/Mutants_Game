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


# --- helpers ---------------------------------------------------------------------------------- #


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
