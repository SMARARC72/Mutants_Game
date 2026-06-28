class_name StatEngine
extends RefCounted
## STAT SPINE (v0.2.1) — typed port of oracle/stat_engine.py (TDD §1, §6).
## HYBRID 6 pole-stats + Luck/Focus; WIDE +/-35% genome; BRUTAL scaling.
## HP is Vitality-driven (Bulk = mitigation only).
## DOMAIN layer: pure, no Node/SceneTree/wall-clock/stdlib-RNG. Randomness is the injected
## CanonicalRNG; every Python round()/round(x,n) maps to CanonicalMath.rnd / rnd_dp.
## Numeric tables come from Constants.BALANCE so they stay single-sourced with the oracle.

const POLES: Array = ["Gaia", "Ouranos", "Cosmos", "Chaos", "Eros", "Thanatos"]
const STAT_OF: Dictionary = {
	"Gaia": "Bulk",
	"Ouranos": "Celerity",
	"Cosmos": "Ward",
	"Chaos": "Spike",
	"Eros": "Vitality",
	"Thanatos": "Bane",
}
const POLE_STATS: Array = ["Bulk", "Celerity", "Ward", "Spike", "Vitality", "Bane"]
const UNIVERSALS: Array = ["Luck", "Focus"]
# ALL_STATS = POLE_STATS + UNIVERSALS  (genome roll order — load-bearing for RNG parity)
const ALL_STATS: Array = ["Bulk", "Celerity", "Ward", "Spike", "Vitality", "Bane", "Luck", "Focus"]

const PHI: float = 0.50
const GENOME_LO: float = 0.65
const GENOME_HI: float = 1.35


static func force_dist(primary: Variant, secondary: Variant) -> Dictionary:
	var f: Dictionary = {}
	for p in POLES:
		f[p] = 0.0
	# Python truthiness: None and "" are falsy; a non-empty pole name is truthy.
	var has_primary := _truthy(primary)
	var has_secondary := _truthy(secondary)
	if has_primary and has_secondary:
		f[primary] += 0.60
		f[secondary] += 0.40
	elif has_primary:
		f[primary] = 1.0
	return f


static func rank_tier_key(rank: Variant, tier: Variant) -> String:
	if rank == "legendary" or rank == "god" or rank == "primordial":
		return str(rank)
	# Python: (tier or "T1")  — falsy tier (None/"") defaults to "T1".
	return str(tier) if _truthy(tier) else "T1"


static func bst(rank: Variant, tier: Variant) -> int:
	var tbl: Dictionary = Constants.BALANCE["stat"]["bst"]
	if rank == "wild":
		var t := str(tier) if _truthy(tier) else "T1"
		return int(tbl["wild_" + t])
	# BST.get((rank, "x"), 200) — only legendary/god/primordial are keyed; default 200.
	if tbl.has(str(rank)):
		return int(tbl[str(rank)])
	return 200


static func class_mod(stats: Dictionary, cls: Variant) -> Dictionary:
	if cls != "construct":
		return stats
	var cm: Dictionary = Constants.BALANCE["stat"]["class_mod_construct"]
	var m := stats.duplicate(true)
	m["Bulk"] = CanonicalMath.rnd(float(m["Bulk"]) * float(cm["Bulk"]))
	m["Ward"] = CanonicalMath.rnd(float(m["Ward"]) * float(cm["Ward"]))
	m["Vitality"] = CanonicalMath.rnd(float(m["Vitality"]) * float(cm["Vitality"]))
	return m


## Returns {"stats": Dictionary, "hp": int, "bst": int} reproducing the oracle tuple.
static func stat_block(
	primary: Variant,
	secondary: Variant,
	rank: Variant,
	tier: Variant,
	cls: Variant = "organic",
	genome: Variant = null
) -> Dictionary:
	var f := force_dist(primary, secondary)
	var budget := bst(rank, tier)
	var floor_v := float(budget) * PHI / 6.0
	var bonus := float(budget) * (1.0 - PHI)
	# g = genome or {s: 1.0 ...}  — a null/empty genome falls back to all 1.0.
	var g: Dictionary
	if genome is Dictionary and not (genome as Dictionary).is_empty():
		g = genome
	else:
		g = {}
		for s in ALL_STATS:
			g[s] = 1.0
	var stats: Dictionary = {}
	for p in POLES:
		var s: String = STAT_OF[p]
		stats[s] = CanonicalMath.rnd((floor_v + bonus * float(f[p])) * _gget(g, s))
	var key := rank_tier_key(rank, tier)
	var univ: Array = Constants.BALANCE["stat"]["univ_base"][key]
	var luck_b := float(univ[0])
	var focus_b := float(univ[1])
	stats["Luck"] = CanonicalMath.rnd(luck_b * _gget(g, "Luck"))
	stats["Focus"] = CanonicalMath.rnd(focus_b * _gget(g, "Focus"))
	stats = class_mod(stats, cls)
	var hpbase: int = int(Constants.BALANCE["stat"]["hpbase"][key])
	var hp_per_vit: int = int(Constants.BALANCE["stat"]["hp_per_vitality"])
	var hp := CanonicalMath.rnd(float(hpbase) + float(hp_per_vit) * float(stats["Vitality"]))
	var bst_total := 0
	for s in POLE_STATS:
		bst_total += int(stats[s])
	return {"stats": stats, "hp": hp, "bst": bst_total}


static func roll_genome(rng: CanonicalRNG) -> Dictionary:
	var dp: int = int(Constants.BALANCE["stat"]["genome_round_dp"])
	var out: Dictionary = {}
	for s in ALL_STATS:
		out[s] = CanonicalMath.rnd_dp(rng.uniform(GENOME_LO, GENOME_HI), dp)
	return out


# --- helpers -----------------------------------------------------------------


static func _gget(g: Dictionary, key: String) -> float:
	# Python g.get(s, 1.0): default to 1.0 when absent.
	return float(g[key]) if g.has(key) else 1.0


static func _truthy(v: Variant) -> bool:
	# Mirror Python truthiness for the only types used here: None / "" are falsy.
	if v == null:
		return false
	if v is String:
		return (v as String) != ""
	return bool(v)
