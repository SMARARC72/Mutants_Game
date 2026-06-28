class_name LabEngine
extends RefCounted
## LAB engine (v0.1) — typed port of oracle/lab_engine.py (TDD §1, §6).
## Whole-creature Creator operations: fuse (+ blend helper). Operations resolve to
## stat-spine numbers plus a COST LEDGER (creature ENTROPY + player CORRUPTION).
## Methods: precise (Cosmos: deterministic, costly) | wild (Chaos: cheaper, variance).
## DOMAIN layer: pure, no Node/SceneTree/wall-clock/stdlib-RNG. Randomness is the injected
## CanonicalRNG; numeric tables come from Constants.BALANCE so they stay single-sourced.
##
## OPPOSED / NEXT come from Constants.BALANCE["forces"]["opposed"] / ["lab"]["next_tier"].
## blend() sorts poles by -weight with a STABLE tiebreak that preserves POLES order, so ties
## resolve identically to Python's stable sorted() (TDD §6.4). fuse() calls StatEngine.stat_block
## with no genome (the rng is consumed only by randint(12,24)), then derives the cost ledger.

# POLES order is load-bearing for blend's stable tiebreak.
const POLES: Array = ["Gaia", "Ouranos", "Cosmos", "Chaos", "Eros", "Thanatos"]


## blend(parts) -> {"prim": String, "sec": String}.
## parts is an Array of [primary, secondary] pairs (secondary may be "" / falsy).
## Mirrors the oracle: prim += 0.6, sec += 0.4; order = stable sort by -weight (POLES order on
## ties); prim = order[0]; sec = order[1] if its weight > 0 else "".
static func blend(parts: Array) -> Dictionary:
	var w: Dictionary = {}
	for p in POLES:
		w[p] = 0.0
	var pw: float = float(Constants.BALANCE["lab"]["blend_primary_weight"])
	var sw: float = float(Constants.BALANCE["lab"]["blend_secondary_weight"])
	for pair in parts:
		var prim: Variant = pair[0]
		var sec: Variant = pair[1] if (pair as Array).size() > 1 else null
		w[prim] += pw
		if _truthy(sec):
			w[sec] += sw
	# Stable sort of POLES by descending weight; ties keep original POLES order (Python's
	# sorted() is stable). Build index-tagged entries so the comparator is total + first-wins.
	var tagged: Array = []
	for i in POLES.size():
		var p: String = POLES[i]
		tagged.append({"p": p, "w": float(w[p]), "i": i})
	tagged.sort_custom(_blend_cmp)
	var order: Array = []
	for e in tagged:
		order.append(e["p"])
	var prim_out: String = order[0]
	var sec_out: String = order[1] if float(w[order[1]]) > 0.0 else ""
	return {"prim": prim_out, "sec": sec_out}


## fuse(a, b, method, rng) -> result Dictionary.
## a and b are Arrays [name, primary, secondary, tier]. Reproduces the oracle exactly:
##   prim, sec = blend([(pA, sA), (pB, sB)])
##   tier = NEXT[tA] if (tA == "T3" and tB == "T3") else max(tA, tB)   (Python str max)
##   taboo = OPPOSED.get(pA) == pB
##   stats, hp, bst = StatEngine.stat_block(prim, sec, "wild", tier, "organic")  (no genome)
##   entropy = rng.randint(12, 24) + (28 if taboo else 0); wild: max(6, entropy - 9)
##   corruption = 18 if taboo else 0
static func fuse(a: Array, b: Array, method: Variant, rng: CanonicalRNG) -> Dictionary:
	var nA: Variant = a[0]
	var pA: Variant = a[1]
	var sA: Variant = a[2]
	var tA: Variant = a[3]
	var nB: Variant = b[0]
	var pB: Variant = b[1]
	var sB: Variant = b[2]
	var tB: Variant = b[3]

	var blended := blend([[pA, sA], [pB, sB]])
	var prim: String = blended["prim"]
	var sec: String = blended["sec"]

	var next_tier: Dictionary = Constants.BALANCE["lab"]["next_tier"]
	var tier: String
	if tA == "T3" and tB == "T3":
		tier = str(next_tier[str(tA)])
	else:
		# Python max(tA, tB) over tier strings: lexicographic, first-wins on ties.
		tier = str(tA) if str(tA) >= str(tB) else str(tB)

	var opposed: Dictionary = Constants.BALANCE["forces"]["opposed"]
	# OPPOSED.get(pA) == pB : absent key -> null, which never equals a pole string.
	var taboo: bool = opposed.has(pA) and opposed[pA] == pB

	var sb := StatEngine.stat_block(prim, sec, "wild", tier, "organic")
	var stats: Dictionary = sb["stats"]
	var hp: int = int(sb["hp"])
	var bst: int = int(sb["bst"])

	var lab: Dictionary = Constants.BALANCE["lab"]
	var entropy: int = (
		rng.randint(int(lab["fuse_entropy_lo"]), int(lab["fuse_entropy_hi"]))
		+ (int(lab["taboo_entropy_bonus"]) if taboo else 0)
	)
	if method == "wild":
		entropy = max(
			int(lab["wild_method_entropy_floor"]),
			entropy - int(lab["wild_method_entropy_reduction"])
		)
	var corruption: int = int(lab["taboo_corruption"]) if taboo else 0

	return {
		"name": str(nA) + " x " + str(nB),
		"prim": prim,
		"sec": sec,
		"tier": tier,
		"stats": stats,
		"hp": hp,
		"bst": bst,
		"taboo": taboo,
		"entropy": entropy,
		"corruption": corruption,
		"method": method,
	}


# --- helpers -----------------------------------------------------------------


static func _blend_cmp(a: Dictionary, b: Dictionary) -> bool:
	# Returns true if `a` should sort before `b`. Descending weight; ties keep POLES order
	# (smaller original index first). This makes sort_custom behave like a stable sort by -w.
	if float(a["w"]) != float(b["w"]):
		return float(a["w"]) > float(b["w"])
	return int(a["i"]) < int(b["i"])


static func _truthy(v: Variant) -> bool:
	# Mirror Python truthiness for the only types used here: None / "" are falsy.
	if v == null:
		return false
	if v is String:
		return (v as String) != ""
	return bool(v)
