class_name SkillEngine
extends RefCounted
## SKILL engine (v0.1) — force-pool skills, 8 verbs, ranks, combos.
## Pure port of oracle/skill_engine.py (the LAW). Reproduces the oracle's total
## ordering, integer math, and EXACT log strings. DOMAIN layer: pure, no Node/SceneTree,
## no stdlib RNG/wall-clock; randomness comes only from an injected CanonicalRNG.
##
## Mon stat blocks come from the canonical StatEngine.stat_block(prim, sec, rank, tier)
## (cls="organic", genome=null — deterministic, no RNG), matching the oracle's
## se.stat_block(prim, sec, rank, tier). SKILLS library + numeric constants are
## single-sourced from Constants.BALANCE.

# --- Force opposition (Constants.BALANCE["forces"]["opposed"]) ---
const OPP := {
	"Cosmos": "Chaos",
	"Chaos": "Cosmos",
	"Eros": "Thanatos",
	"Thanatos": "Eros",
	"Gaia": "Ouranos",
	"Ouranos": "Gaia",
}


static func _skills() -> Dictionary:
	return Constants.BALANCE["skill"]["library"]


static func force_mult(a: String, d: String) -> float:
	if OPP.get(a) == d:
		return 1.5
	if a == d:
		return 0.7
	return 1.0


# ---------------------------------------------------------------------------
# Mon
# ---------------------------------------------------------------------------
class Mon:
	extends RefCounted
	var name: String
	var prim: String
	var sec: String
	var stats: Dictionary
	var maxhp: int
	var hp: int
	var alive: bool
	var kit: Array
	var ranks: Dictionary
	var shield: int
	var buff: float
	var defdown: float

	func _init(
		p_name: String,
		p_prim: String,
		p_sec: String,
		p_rank: String,
		p_tier: String,
		p_kit: Array,
		p_ranks: Dictionary = {}
	) -> void:
		# Mirror oracle Mon.__init__: st, hp, bst = se.stat_block(prim, sec, rank, tier)
		# (cls="organic", genome=None). StatEngine returns {"stats","hp","bst"}.
		var sb := StatEngine.stat_block(p_prim, p_sec, p_rank, p_tier)
		name = p_name
		prim = p_prim
		sec = p_sec
		stats = sb["stats"]
		maxhp = int(sb["hp"])
		hp = int(sb["hp"])
		alive = true
		kit = p_kit
		ranks = p_ranks
		shield = 0
		buff = 0.0
		defdown = 0.0

	func offense() -> Array:
		# (off_stat_value, def_stat_name) — Spike>=Bane -> (Spike,"Bulk") else (Bane,"Ward")
		if int(stats["Spike"]) >= int(stats["Bane"]):
			return [int(stats["Spike"]), "Bulk"]
		return [int(stats["Bane"]), "Ward"]

	func has(verb: String) -> String:
		var lib := SkillEngine._skills()
		for s in kit:
			if String(lib[s]["verb"]) == verb:
				return s
		return ""


static func rank_mult(mon: Mon, skill: String) -> float:
	var r := 1
	if mon.ranks.has(skill):
		r = int(mon.ranks[skill])
	return 1.0 + float(r - 1) * 0.25


# ---------------------------------------------------------------------------
# damage
# ---------------------------------------------------------------------------
static func damage(
	user: Mon, skill: String, tgt: Mon, ent: float, combo: float, log: Array
) -> void:
	var lib := _skills()
	var sk: Dictionary = lib[skill]
	var off_pair := user.offense()
	var defstat: String = off_pair[1]
	var off := float(off_pair[0])
	var power := 1.0
	if sk.has("power"):
		power = float(sk["power"])
	off = off * power * rank_mult(user, skill) * (1.0 + user.buff)
	var mit := float(tgt.stats[defstat]) * (1.0 - tgt.defdown)
	var fm := force_mult(user.prim, tgt.prim)
	var dmg := CanonicalMath.rnd(1.5 * off * off / (off + mit) * fm * ent * combo)
	var absorbed: int = min(tgt.shield, dmg)
	tgt.shield -= absorbed
	dmg -= absorbed
	tgt.hp -= dmg
	var tag := ""
	if fm > 1.0:
		tag = "  [" + user.prim + ">" + tgt.prim + "]"
	var cm := ""
	if combo > 1.0:
		cm = "  +COMBO"
	var sh := ""
	if absorbed != 0:
		sh = "  (" + str(absorbed) + " absorbed)"
	log.append(
		(
			"   "
			+ user.name.rpad(9)
			+ skill.rpad(13)
			+ "-> "
			+ tgt.name.rpad(9)
			+ str(dmg)
			+ " dmg"
			+ tag
			+ cm
			+ sh
			+ "   ("
			+ tgt.name
			+ " "
			+ str(max(0, tgt.hp))
			+ "/"
			+ str(tgt.maxhp)
			+ ")"
		)
	)
	if sk.has("lifesteal") and float(sk["lifesteal"]) != 0.0 and dmg > 0:
		var heal := CanonicalMath.rnd(float(dmg) * float(sk["lifesteal"]))
		user.hp = min(user.maxhp, user.hp + heal)
		log.append("      " + user.name + " drains " + str(heal) + " HP (now " + str(user.hp) + ")")
	if sk.has("defdown") and float(sk["defdown"]) != 0.0:
		tgt.defdown = max(tgt.defdown, float(sk["defdown"]))
		log.append(
			"      " + tgt.name + " WITHERED (-" + str(int(float(sk["defdown"]) * 100.0)) + "% def)"
		)
	if tgt.hp <= 0 and tgt.alive:
		tgt.alive = false
		log.append("   ** " + tgt.name + " DIES -> parts + Graveyard **")


# ---------------------------------------------------------------------------
# support
# ---------------------------------------------------------------------------
static func support(user: Mon, skill: String, allies: Array, log: Array) -> void:
	var lib := _skills()
	var sk: Dictionary = lib[skill]
	var rm := rank_mult(user, skill)
	var verb := String(sk["verb"])
	if verb == "Mend":
		var tgt := _min_by_hp_frac(allies)
		var heal := CanonicalMath.rnd(float(user.stats["Vitality"]) * float(sk["heal"]) * rm)
		tgt.hp = min(tgt.maxhp, tgt.hp + heal)
		log.append(
			(
				"   "
				+ user.name.rpad(9)
				+ skill.rpad(13)
				+ "~> heals "
				+ tgt.name
				+ " +"
				+ str(heal)
				+ " HP  ("
				+ str(tgt.hp)
				+ "/"
				+ str(tgt.maxhp)
				+ ")"
			)
		)
	elif verb == "Ward":
		var tgt := _min_by_hp_frac(allies)
		tgt.shield += CanonicalMath.rnd(float(tgt.maxhp) * float(sk["shield"]) * rm)
		log.append(
			(
				"   "
				+ user.name.rpad(9)
				+ skill.rpad(13)
				+ "~> shields "
				+ tgt.name
				+ " ("
				+ str(tgt.shield)
				+ " shield)"
			)
		)
	elif verb == "Rouse":
		var tgt := _max_by_spike_bane(allies, user)
		# Rouse buffs the strongest OTHER ally; with no eligible ally (a last-survivor / solo team) the
		# target is null — no-op instead of a null deref. Unreachable in the 3v3 goldens (they always
		# have another ally), so this guard never changes a golden vector; it hardens live attrition play.
		if tgt == null:
			return
		tgt.buff += float(sk["buff"]) * rm
		log.append(
			(
				"   "
				+ user.name.rpad(9)
				+ skill.rpad(13)
				+ "~> rouses "
				+ tgt.name
				+ " (+"
				+ str(int(tgt.buff * 100.0))
				+ "% offense)"
			)
		)


# min over alive allies by hp/maxhp, FIRST-wins on ties (Python min semantics)
static func _min_by_hp_frac(allies: Array) -> Mon:
	var best: Mon = null
	var best_key := 0.0
	for a in allies:
		if not a.alive:
			continue
		var k := float(a.hp) / float(a.maxhp)
		if best == null or k < best_key:
			best = a
			best_key = k
	return best


# max over alive allies (excluding user by identity) by Spike+Bane, FIRST-wins on ties
static func _max_by_spike_bane(allies: Array, user: Mon) -> Mon:
	var best: Mon = null
	var best_key := 0
	for a in allies:
		if not a.alive or a == user:
			continue
		var k := int(a.stats["Spike"]) + int(a.stats["Bane"])
		if best == null or k > best_key:
			best = a
			best_key = k
	return best


# min over alive foes by hp, FIRST-wins on ties
static func _min_by_hp(foes: Array) -> Mon:
	var best: Mon = null
	var best_key := 0
	for f in foes:
		if not f.alive:
			continue
		if best == null or f.hp < best_key:
			best = f
			best_key = f.hp
	return best


# ---------------------------------------------------------------------------
# act
# ---------------------------------------------------------------------------
static func act(
	user: Mon,
	allies: Array,
	foes: Array,
	ent: float,
	prevforce: String,
	rng: CanonicalRNG,
	log: Array
) -> String:
	var low := false
	for a in allies:
		if a.alive and a.hp < float(a.maxhp) * 0.78:
			low = true
			break
	var mend := user.has("Mend")
	if mend != "" and low:
		support(user, mend, allies, log)
		return user.prim
	var ward := user.has("Ward")
	if ward != "":
		var ward_need := false
		for a in allies:
			if a.alive and a.hp < float(a.maxhp) * 0.60:
				ward_need = true
				break
		if ward_need:
			support(user, ward, allies, log)
			return user.prim
	var rouse := user.has("Rouse")
	if rouse != "" and rng.random() < 0.3:
		support(user, rouse, allies, log)
		return user.prim
	# damaging
	var dmg_skill := user.has("Drain")
	if dmg_skill == "":
		dmg_skill = user.has("Gambit")
	if dmg_skill == "":
		dmg_skill = user.has("Strike")
	if dmg_skill == "":
		return user.prim
	var tgt := _min_by_hp(foes)
	var combo := 1.0
	if prevforce == user.prim:
		combo = 1.4
	if combo > 1.0:
		log.append("   >> RESONANCE COMBO (" + user.prim + " chain) <<")
	damage(user, dmg_skill, tgt, ent, combo, log)
	return user.prim


# ---------------------------------------------------------------------------
# battle
# ---------------------------------------------------------------------------
static func battle(A: Array, B: Array, rng: CanonicalRNG) -> Array:
	# A, B: Array[Mon]. Returns Array[String] log.
	var log: Array = []
	var turn := 0
	while _any_alive(A) and _any_alive(B) and turn < 10:
		turn += 1
		var ent := CanonicalMath.rnd_dp(1.0 + float(turn - 1) * 0.12, 2)
		log.append("== TURN " + str(turn) + "   entropy x" + _fmt_num(ent) + " ==")
		var order := _turn_order(A, B)
		# prev[side]: "" stands in for Python None (a force is never "", so it never matches user.prim)
		var prev_a := ""
		var prev_b := ""
		for m in order:
			if not m.alive:
				continue
			var in_a := _contains(A, m)
			var allies: Array = A if in_a else B
			var foes: Array = B if in_a else A
			if not _any_alive(foes):
				break
			if in_a:
				prev_a = act(m, allies, foes, ent, prev_a, rng, log)
			else:
				prev_b = act(m, allies, foes, ent, prev_b, rng, log)
		log.append("")
	log.append(
		"RESULT: " + ("TEAM A" if _any_alive(A) else "TEAM B") + " wins (turn " + str(turn) + ")"
	)
	return log


static func _fmt_num(x: float) -> String:
	# Mirror Python str(float). GDScript str() of a float already matches Python for these
	# canonical 2-dp entropy values (e.g. 1.0, 1.12, 1.6, 2.08).
	return str(x)


static func _any_alive(team: Array) -> bool:
	for m in team:
		if m.alive:
			return true
	return false


static func _contains(team: Array, m: Mon) -> bool:
	for x in team:
		if x == m:
			return true
	return false


# sorted([m for m in A+B if m.alive], key=lambda m: -Celerity) — STABLE descending by Celerity.
static func _turn_order(A: Array, B: Array) -> Array:
	var combined: Array = []
	for m in A:
		if m.alive:
			combined.append(m)
	for m in B:
		if m.alive:
			combined.append(m)
	# Stable sort: decorate with original index, sort by (-Celerity, index).
	var dec: Array = []
	for i in combined.size():
		dec.append({"i": i, "m": combined[i], "cel": int(combined[i].stats["Celerity"])})
	dec.sort_custom(
		func(p, q):
			if p["cel"] != q["cel"]:
				return p["cel"] > q["cel"]
			return p["i"] < q["i"]
	)
	var out: Array = []
	for d in dec:
		out.append(d["m"])
	return out


# Build a Mon from a golden input tuple [name, prim, sec, rank, tier, kit, ranks].
static func mon_from_tuple(t: Array) -> Mon:
	var ranks: Dictionary = {}
	if t.size() > 6 and t[6] != null:
		ranks = t[6]
	return Mon.new(
		String(t[0]), String(t[1]), String(t[2]), String(t[3]), String(t[4]), t[5], ranks
	)
