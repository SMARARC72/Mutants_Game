class_name StatusEngine
extends RefCounted
## Mutants_Game — STATUS engine (v0.1) port of oracle/status_engine.py.
## 6 force-signature statuses + unified Corruption. Hybrid stacking: DOTs (Wither, Bloom-rot)
## STACK intensity; control (Petrify/Shock/Seal/Madness) REFRESH duration. CORRUPTION = one
## meta-meter -> burnout/feral at threshold; cleansed statuses leave Corruption persisting.
##
## DETERMINISTIC: no RNG. apply/add_corruption/tick/cleanse mutate a Character (`StatusEngine.C`)
## state + append to a log. Reproduces oracle ordering/strings EXACTLY for golden parity.
## DOMAIN layer: pure (no Node/SceneTree/Time/randf). Constants single-source the balance tables.


# STATUSES table — read from Constants.BALANCE["status"]["statuses"] (single source of truth).
static func _statuses() -> Dictionary:
	return Constants.BALANCE["status"]["statuses"]


## Character — mirrors oracle `class C`. hp from StatEngine.stat_block (inlined: HP is
## Vitality-driven). status/corruption/feral as in the oracle.
class C:
	extends RefCounted
	var name: String
	var hp: int
	var maxhp: int
	var status: Dictionary
	var corruption: int
	var feral: bool

	func _init(c_name: String, prim: String, sec: String, tier: String) -> void:
		name = c_name
		hp = StatusEngine._hp_for(prim, sec, "wild", tier)
		maxhp = hp
		status = {}
		corruption = 0
		feral = false


# Inlined stat_block HP computation (oracle stat_engine.stat_block with cls="organic",
# genome=None). HP = rnd(HPBASE[key] + 3 * Vitality); Vitality = rnd(floor + bonus * f[Eros]).
# Only Vitality + hp are needed for the status snapshot, so we compute exactly those, in the
# oracle's float-operation order, via Constants.
static func _hp_for(primary: String, secondary: String, rank: String, tier: String) -> int:
	var stat: Dictionary = Constants.BALANCE["stat"]
	var phi: float = stat["phi"]  # 0.5
	# force_dist for the Eros pole (Vitality source) only.
	var fd: Dictionary = stat["force_dist"]
	var f_eros := 0.0
	if primary != "" and secondary != "":
		if primary == "Eros":
			f_eros += float(fd["primary_with_secondary"])
		if secondary == "Eros":
			f_eros += float(fd["secondary"])
	elif primary != "":
		if primary == "Eros":
			f_eros = float(fd["primary_pure"])
	# bst(rank, tier): wild -> bst["wild_T<n>"]; else table fallback (golden uses wild only).
	var budget := _bst(rank, tier)
	var fl := budget * phi / 6.0
	var bonus := budget * (1.0 - phi)
	var vitality := CanonicalMath.rnd((fl + bonus * f_eros) * 1.0)
	var key := _rank_tier_key(rank, tier)
	var hpbase: int = int(Constants.BALANCE["stat"]["hpbase"][key])
	return CanonicalMath.rnd(float(hpbase) + 3.0 * float(vitality))


static func _rank_tier_key(rank: String, tier: String) -> String:
	if rank == "legendary" or rank == "god" or rank == "primordial":
		return rank
	return tier if tier != "" else "T1"


static func _bst(rank: String, tier: String) -> int:
	var bst: Dictionary = Constants.BALANCE["stat"]["bst"]
	if rank == "wild":
		var t := tier if tier != "" else "T1"
		return int(bst["wild_" + t])
	if rank == "legendary":
		return int(bst["legendary"])
	if rank == "god":
		return int(bst["god"])
	if rank == "primordial":
		return int(bst["primordial"])
	return 200


# ---- apply: stack DOTs, refresh control --------------------------------------
static func apply(c: C, name: String, log: Array) -> void:
	var s: Dictionary = _statuses()[name]
	if s.get("stack", false):
		var d: Dictionary
		if c.status.has(name):
			d = c.status[name]
		else:
			d = {"stacks": 0, "dur": 99}
			c.status[name] = d
		d["stacks"] = int(d["stacks"]) + 1
		log.append("   " + name + " -> " + c.name + "  (stack " + str(int(d["stacks"])) + ")")
	else:
		c.status[name] = {"stacks": 1, "dur": int(s["dur"])}
		log.append("   " + name + " -> " + c.name + "  (refresh, " + str(int(s["dur"])) + " turns)")


# ---- add_corruption: feed the meta-meter, burnout at threshold ----------------
static func add_corruption(c: C, amt: int, src: String, log: Array) -> void:
	c.corruption = mini(130, c.corruption + amt)
	log.append(
		(
			"   "
			+ c.name
			+ " Corruption +"
			+ str(amt)
			+ " ("
			+ src
			+ ")  ->  "
			+ str(c.corruption)
			+ "/100"
		)
	)
	if c.corruption >= 100 and not c.feral:
		c.feral = true
		log.append(
			(
				"   ** "
				+ c.name
				+ " BURNS OUT -> FERAL (acts randomly, -20% stats; bounded - not dead) **"
			)
		)


# ---- tick: DOT damage (+ spread), control countdown --------------------------
static func tick(c: C, allies: Array, log: Array) -> void:
	# Python: for name in list(c.status.keys()) — snapshot the keys before mutating.
	for name in c.status.keys().duplicate():
		var s: Dictionary = _statuses()[name]
		var d: Dictionary = c.status[name]
		if s["kind"] == "dot":
			var dmg := int(s["base"]) * int(d["stacks"])
			c.hp = maxi(0, c.hp - dmg)
			var extra := ""
			if s.get("spread", false):
				# other = [a for a in allies if a is not c and name not in a.status] — first wins.
				var other_first: C = null
				for a in allies:
					if a != c and not (a as C).status.has(name):
						other_first = a
						break
				if other_first != null:
					apply(other_first, name, log)
					extra = "  (spreads to " + other_first.name + "!)"
			log.append(
				(
					"   "
					+ name
					+ " ticks "
					+ c.name
					+ " -"
					+ str(dmg)
					+ " HP  ("
					+ str(c.hp)
					+ "/"
					+ str(c.maxhp)
					+ ")"
					+ extra
				)
			)
		elif s["kind"] == "control":
			log.append(
				(
					"   "
					+ c.name
					+ " is "
					+ name
					+ "ed ("
					+ str(s["effect"])
					+ ") ["
					+ str(int(d["dur"]))
					+ " left]"
				)
			)
			d["dur"] = int(d["dur"]) - 1
			if int(d["dur"]) <= 0:
				c.status.erase(name)
				log.append("   " + name + " fades on " + c.name)


# ---- cleanse: clear battle statuses, Corruption persists ---------------------
static func cleanse(c: C, log: Array) -> void:
	# removed = [k for k in c.status if STATUSES[k]["kind"] != "meta"] — preserve dict order.
	var removed: Array = []
	for k in c.status.keys():
		if _statuses()[k]["kind"] != "meta":
			removed.append(k)
	for k in removed:
		c.status.erase(k)
	var joined := ", ".join(PackedStringArray(removed)) if not removed.is_empty() else "nothing"
	log.append(
		(
			"   Mend cleanses "
			+ c.name
			+ ": "
			+ joined
			+ "   (Corruption "
			+ str(c.corruption)
			+ " persists)"
		)
	)
