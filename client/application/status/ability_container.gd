class_name AbilityContainer
extends RefCounted
## AbilityContainer — the ability/skill SHELL (Cluster 4 D4, ADR-015 §B1, OctoD adapter). APPLICATION
## layer: an OctoD-style "ability container" that HOLDS a combatant's skill kit + ranks and PRESENTS
## the resolved outcome of using a skill — while computing NO number. Damage, healing, shields,
## buffs, force-multipliers, combos and lifesteal are all produced by client/domain/skill_engine.gd
## (the oracle). The container owns the kit/lifecycle; the oracle owns the math.
##
## It wraps a SkillEngine.Mon (the oracle's combatant) and exposes:
##   abilities()            -> the skill ids in this container's kit (presentation: the ability bar)
##   has_verb(verb)         -> the skill id providing a verb, or "" (the engine's own lookup)
##   use_damage(skill, tgt) -> SkillEngine.damage(...) resolves it; returns the produced log lines
##   use_support(skill, ..) -> SkillEngine.support(...) resolves it
##   choose_and_act(...)    -> SkillEngine.act(...) selects + resolves (selection RNG is the injected
##                             CanonicalRNG, ADR-016 — never global randf/randi)
## Read-back getters (hp/shield/buff/...) surface the engine-owned Mon state for a UI. Swap in OctoD's
## AbilityContainer node => reimplement this file; the contract is the methods + the exposed state.
##
## Self-contained shell rationale: identical to StatusContainer — OctoD ships its own ability math +
## is Node-based; this delegating RefCounted shell fulfils the same contract without dragging addon
## math into the skill path (forbidden, ADR-015) or requiring a 4.7 vendor we can't verify here.

const SkillEngineScript := preload("res://domain/skill_engine.gd")

## The oracle combatant this container fronts. data-only state (stats/hp/kit/ranks); NEVER a Node.
var _mon: SkillEngine.Mon
var _log: Array = []


func _init(
	c_name: String,
	prim: String,
	sec: String,
	rank: String,
	tier: String,
	kit: Array,
	ranks: Dictionary = {}
) -> void:
	# stats + HP come from the ORACLE (Mon -> StatEngine.stat_block). The shell computes none of them.
	_mon = SkillEngineScript.Mon.new(c_name, prim, sec, rank, tier, kit, ranks)


## The skill ids in this container's kit (the ability bar). Presentation only.
func abilities() -> Array:
	return _mon.kit.duplicate()


## The skill id in the kit that provides `verb` (or "" if none) — the engine's own lookup, not ours.
func has_verb(verb: String) -> String:
	return _mon.has(verb)


## Resolve a DAMAGING skill against a target container. ALL numbers (off/mit/force-mult/combo/lifesteal)
## are SkillEngine.damage's; the shell only forwards and returns the produced log lines. `ent`/`combo`
## are the battle's entropy/combo multipliers (also engine inputs, not shell-computed).
func use_damage(
	skill: String, target: AbilityContainer, ent: float = 1.0, combo: float = 1.0
) -> Array:
	var before := _log.size()
	SkillEngineScript.damage(_mon, skill, target._mon, ent, combo, _log)
	return _log.slice(before)


## Resolve a SUPPORT skill (Mend/Ward/Rouse) over allies. The oracle picks the target + the amount.
func use_support(skill: String, allies: Array) -> Array:
	var before := _log.size()
	SkillEngineScript.support(_mon, skill, _mon_list(allies), _log)
	return _log.slice(before)


## SELECT + resolve an action via the oracle (ADR-016: AI selects, the engine resolves; selection
## randomness is the injected CanonicalRNG). Returns the user's force (the engine's combo key).
func choose_and_act(
	allies: Array, foes: Array, ent: float, prevforce: String, rng: CanonicalRNG
) -> String:
	return SkillEngineScript.act(
		_mon, _mon_list(allies), _mon_list(foes), ent, prevforce, rng, _log
	)


# --- presentation reads (engine-owned Mon state; no math) ------------------------------------- #


func combatant_name() -> String:
	return _mon.name


func hp() -> int:
	return _mon.hp


func max_hp() -> int:
	return _mon.maxhp


func is_alive() -> bool:
	return _mon.alive


func shield() -> int:
	return _mon.shield


func buff() -> float:
	return _mon.buff


func stat(stat_name: String) -> int:
	return int(_mon.stats.get(stat_name, 0))


func log_lines() -> Array:
	return _log.duplicate()


# --- persistence (data-only JSON; ADR-012) --------------------------------------------------- #


## Snapshot the container's live battle state (hp/shield/buff/defdown/alive) + its identity kit/ranks
## as a plain dict (NEVER a Node/Resource). Stats/maxhp are oracle-derived and re-derived on load from
## the persisted identity (prim/sec/rank/tier), so we don't store the stat table redundantly.
func to_dict() -> Dictionary:
	return {
		"name": _mon.name,
		"prim": _mon.prim,
		"sec": _mon.sec,
		"kit": _mon.kit.duplicate(),
		"ranks": _mon.ranks.duplicate(true),
		"hp": _mon.hp,
		"maxhp": _mon.maxhp,
		"shield": _mon.shield,
		"buff": _mon.buff,
		"defdown": _mon.defdown,
		"alive": _mon.alive,
	}


## Restore the LIVE battle state IN PLACE. int()/float()-wrap numerics (JSON decodes bare numbers as
## float). The identity (name/prim/sec/kit/ranks) is restored too so the container is self-consistent;
## the stat table itself stays the oracle-derived one from _init's prim/sec/rank/tier (unchanged).
func load_from(data: Dictionary) -> void:
	_mon.name = str(data.get("name", _mon.name))
	_mon.prim = str(data.get("prim", _mon.prim))
	_mon.sec = str(data.get("sec", _mon.sec))
	if data.get("kit", null) is Array:
		_mon.kit = (data["kit"] as Array).duplicate()
	if data.get("ranks", null) is Dictionary:
		_mon.ranks = (data["ranks"] as Dictionary).duplicate(true)
	_mon.hp = int(data.get("hp", _mon.hp))
	_mon.maxhp = int(data.get("maxhp", _mon.maxhp))
	_mon.shield = int(data.get("shield", 0))
	_mon.buff = float(data.get("buff", 0.0))
	_mon.defdown = float(data.get("defdown", 0.0))
	_mon.alive = bool(data.get("alive", true))


func _mon_list(containers: Array) -> Array:
	var out: Array = []
	for ac in containers:
		out.append((ac as AbilityContainer)._mon)
	return out
