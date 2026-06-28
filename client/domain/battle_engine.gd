class_name BattleEngine
extends RefCounted
## BATTLE engine (v0.1) — typed port of oracle/battle_engine.py (TDD §1, §6).
## Classic turn-based core (HP, Celerity initiative, attacks, faint/death) plus wild layers:
## shared AP economy | ENTROPY escalation clock (0.12/turn) | RESONANCE (same-force chain x1.3,
## cross-force overload x1.4 @ 30%) | vector-clash damage | real permadeath -> parts/Graveyard.
##
## DOMAIN layer: pure, no Node/SceneTree/wall-clock/stdlib-RNG. Randomness is the injected
## CanonicalRNG; every Python round() maps to CanonicalMath.rnd / rnd_dp. Mon stat blocks come
## from StatEngine.stat_block (genome defaults to all-1.0, exactly like se.stat_block(..., cls)).
## Numeric dials come from Constants.BALANCE so they stay single-sourced with the oracle.
##
## LOG PARITY: every log line is reproduced char-for-char. Python s.ljust(n) == GDScript
## s.rpad(n); Python str(x).rjust(n) == GDScript str(x).lpad(n). Entropy is the only float in a
## log string; Python str(rnd_dp(...,2)) is reproduced by _py_float_str (str(1.0)=="1.0",
## str(1.6)=="1.6", str(2.08)=="2.08"), which plain GDScript str() does NOT match.

# OPP = opposed-force map (Constants.BALANCE["forces"]["opposed"]).
const OPP: Dictionary = {
	"Cosmos": "Chaos",
	"Chaos": "Cosmos",
	"Eros": "Thanatos",
	"Thanatos": "Eros",
	"Gaia": "Ouranos",
	"Ouranos": "Gaia",
}


## force_mult(att, dfn) -> float. att/dfn are force (pole) names.
static func force_mult(att: String, dfn: String) -> float:
	var b: Dictionary = Constants.BALANCE["battle"]
	if OPP.get(att, null) == dfn:
		return float(b["force_mult_opposed"])  # opposed forces clash hard (1.5)
	if att == dfn:
		return float(b["force_mult_same"])  # resists its own kind (0.7)
	return float(b["force_mult_neutral"])  # 1.0


## A combatant. Mirrors oracle Mon: name/prim/sec, stats dict, maxhp/hp, alive.
## `side` is set by simulate() so that team membership is by object identity (matches Python
## `m in teamA`, which two equal-stat mons named the same would NOT collide on).
class Mon:
	extends RefCounted
	var name: String
	var prim: String
	var sec: String
	var stats: Dictionary
	var maxhp: int
	var hp: int
	var alive: bool
	var side: String = ""

	func _init(
		p_name: String,
		p_prim: String,
		p_sec: String,
		rank: Variant,
		tier: Variant,
		cls: Variant = "organic"
	) -> void:
		var block := StatEngine.stat_block(p_prim, p_sec, rank, tier, cls)
		name = p_name
		prim = p_prim
		sec = p_sec
		stats = block["stats"]
		maxhp = int(block["hp"])
		hp = int(block["hp"])
		alive = true

	## Returns [power:int, kind:String, defstat:String]. Spike-vs-Bane offense pick (Spike wins ties).
	func offense() -> Array:
		if int(stats["Spike"]) >= int(stats["Bane"]):
			return [int(stats["Spike"]), "Spike", "Bulk"]
		return [int(stats["Bane"]), "Bane", "Ward"]


## attack(att, dfn, ent, chain, overload, rng, log) — resolves one strike, appends log line(s).
## RNG: exactly ONE rng.random() call here (the crit roll), AFTER any overload roll in simulate().
static func attack(
	att: Mon, dfn: Mon, ent: float, chain: float, overload: bool, rng: CanonicalRNG, log: Array
) -> void:
	var b: Dictionary = Constants.BALANCE["battle"]
	var off := att.offense()
	var power: int = int(off[0])
	var defstat: String = str(off[2])
	var mit: int = int(dfn.stats[defstat])
	var overload_mult: float = float(b["overload_mult"]) if overload else 1.0
	var fm := force_mult(att.prim, dfn.prim) * overload_mult
	var crit_luck := float(att.stats["Luck"]) / float(b["crit_luck_divisor"])
	var crit: float = float(b["crit_mult"]) if rng.random() < crit_luck else 1.0
	var k := float(b["damage_k"])  # global damage constant (1.5)
	var raw := k * float(power) * float(power) / float(power + mit) * fm * ent * chain * crit
	var dmg := CanonicalMath.rnd(raw)
	var cap := CanonicalMath.rnd(float(dfn.maxhp) * float(b["single_hit_cap_frac"]))  # anti-one-shot cap
	dmg = mini(dmg, cap)
	dfn.hp -= dmg
	var cue := ""
	if fm >= 1.4:
		cue = "  [" + att.prim + " overwhelms " + dfn.prim + "!]"
	elif fm < 1.0:
		cue = "  [resisted]"
	var flags := ""
	flags += " CHAIN" if chain > 1 else ""
	flags += " OVERLOAD" if overload else ""
	flags += " CRIT" if crit > 1 else ""
	var shown_hp: int = maxi(0, dfn.hp)
	log.append(
		(
			"   "
			+ att.name.rpad(10)
			+ " -> "
			+ dfn.name.rpad(10)
			+ str(dmg).lpad(4)
			+ " dmg"
			+ cue
			+ flags
			+ "   ("
			+ dfn.name
			+ " "
			+ str(shown_hp)
			+ "/"
			+ str(dfn.maxhp)
			+ ")"
		)
	)
	if dfn.hp <= 0 and dfn.alive:
		dfn.alive = false
		log.append(
			(
				"   ** "
				+ dfn.name
				+ " DIES -> harvestable parts + Graveyard (reanimatable at a cost) **"
			)
		)


## simulate(teamA, teamB, rng) -> Array[String]. teamA/teamB are Array[Mon].
static func simulate(teamA: Array, teamB: Array, rng: CanonicalRNG) -> Array:
	var b: Dictionary = Constants.BALANCE["battle"]
	var turn_cap: int = int(b["turn_cap"])
	var entropy_step: float = float(b["entropy_step_per_turn"])
	var chain_mult: float = float(b["chain_mult"])
	var overload_chance: float = float(b["overload_chance"])

	# Tag side by identity, mirroring Python `m in teamA` (object identity, not value equality).
	for m in teamA:
		(m as Mon).side = "A"
	for m in teamB:
		(m as Mon).side = "B"

	var log: Array = []
	var turn := 0
	while _any_alive(teamA) and _any_alive(teamB) and turn < turn_cap:
		turn += 1
		var ent := CanonicalMath.rnd_dp(1.0 + float(turn - 1) * entropy_step, 2)
		log.append(
			"== TURN " + str(turn) + "   entropy x" + _py_float_str(ent) + " (escalating) =="
		)

		# order = sorted([alive in teamA+teamB], key=-Celerity); Python sorted is STABLE.
		var order := _initiative_order(teamA, teamB)
		var sideprev: Dictionary = {"A": null, "B": null}
		for m in order:
			var mon := m as Mon
			if not mon.alive:
				continue
			var foes: Array = teamB if mon.side == "A" else teamA
			var side: String = mon.side
			var tgt := _first_alive(foes)
			if tgt == null:
				break
			var chain: float = chain_mult if sideprev[side] == mon.prim else 1.0
			# Python short-circuit: rng.random() is only consumed when the OPP check passes.
			var overload := false
			if OPP.get(mon.prim, null) == tgt.prim and rng.random() < overload_chance:
				overload = true
			attack(mon, tgt, ent, chain, overload, rng, log)
			sideprev[side] = mon.prim
		log.append("")

	var winner: String = "TEAM A" if _any_alive(teamA) else "TEAM B"
	var win_team: Array = teamA if winner == "TEAM A" else teamB
	var surv: PackedStringArray = PackedStringArray()
	for m in win_team:
		if (m as Mon).alive:
			surv.append((m as Mon).name)
	log.append(
		"RESULT: " + winner + " wins on turn " + str(turn) + " | survivors: " + ", ".join(surv)
	)
	return log


# --- helpers -----------------------------------------------------------------


static func _any_alive(team: Array) -> bool:
	for m in team:
		if (m as Mon).alive:
			return true
	return false


static func _first_alive(team: Array) -> Mon:
	# Python: next((f for f in foes if f.alive), None) — first alive in team order.
	for m in team:
		if (m as Mon).alive:
			return m as Mon
	return null


static func _initiative_order(teamA: Array, teamB: Array) -> Array:
	# Build [alive in teamA+teamB order], then STABLE-sort by -Celerity.
	# Decorate with original index so ties keep teamA+teamB order (Python sorted stability).
	var decorated: Array = []
	var idx := 0
	for m in teamA:
		if (m as Mon).alive:
			decorated.append({"i": idx, "m": m})
		idx += 1
	for m in teamB:
		if (m as Mon).alive:
			decorated.append({"i": idx, "m": m})
		idx += 1
	decorated.sort_custom(
		func(a, b):
			var ca := int((a["m"] as Mon).stats["Celerity"])
			var cb := int((b["m"] as Mon).stats["Celerity"])
			if ca != cb:
				return ca > cb  # key = -Celerity -> higher Celerity first
			return int(a["i"]) < int(b["i"])  # stable tiebreak: original order
	)
	var out: Array = []
	for d in decorated:
		out.append(d["m"])
	return out


static func _py_float_str(v: float) -> String:
	# Reproduce Python str(float) for entropy values = rnd_dp(x, 2) (<=2 decimals).
	# str(1.0)=="1.0", str(1.6)=="1.6", str(2.08)=="2.08". GDScript str() drops the ".0".
	var s := "%.2f" % v
	# Strip trailing zeros, then guarantee at least one decimal digit.
	while s.ends_with("0"):
		s = s.substr(0, s.length() - 1)
	if s.ends_with("."):
		s += "0"
	return s
