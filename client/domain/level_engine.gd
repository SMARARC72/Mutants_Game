class_name LevelEngine
extends RefCounted
## Mutants_Game - LEVELING engine (v0.1): PURE-AWAKENING growth. Typed port of
## oracle/level_engine.py (the LAW). Combat XP fills toward a threshold; at a threshold you
## ROLL for resonance (Luck-biased). Catch -> AWAKENING (stat surge, maybe a dormant gene,
## maybe a branch). Stall -> OVERCLOCK to force it, banking ENTROPY. Stats = ceiling x expression.
## DOMAIN layer: pure (no Node/SceneTree/stdlib-RNG/wall-clock). Randomness is injected via
## CanonicalRNG. Data tables/constants are single-sourced from Constants.BALANCE["level"].


static func _level() -> Dictionary:
	return Constants.BALANCE["level"]


static func _genes() -> Dictionary:
	# GENES = {"Ironblood":"Bulk", ...} — insertion-ordered; iteration order matters for choice().
	return _level()["genes"]


static func current_stats(
	ceiling: Dictionary, expression: float, gene_bonus: Dictionary
) -> Dictionary:
	# {k: rnd(v * (expression + gene_bonus.get(k, 0.0))) for k, v in ceiling.items()}
	# Iterate ceiling in insertion order; preserve key order in the result.
	var out := {}
	for k in ceiling:
		var v: float = float(ceiling[k])
		var bonus: float = float(gene_bonus.get(k, 0.0))
		out[k] = CanonicalMath.rnd(v * (expression + bonus))
	return out


static func awaken(
	rng: CanonicalRNG, expression: float, gene_bonus: Dictionary, genes: Array
) -> Dictionary:
	# Mutates gene_bonus + genes in place (Dictionaries/Arrays are by-reference, matching Python).
	# Returns {"expression": float, "events": Array[String]}; gene_bonus/genes carry the mutations.
	var lvl := _level()
	var GENES := _genes()

	var surge := rng.uniform(float(lvl["awaken_surge_lo"]), float(lvl["awaken_surge_hi"]))
	expression = minf(1.0, expression + surge)
	var events: Array = ["surge +" + str(CanonicalMath.rnd(surge * 100.0)) + "%"]

	if rng.random() < float(lvl["gene_chance"]):
		# avail = [g for g in GENES if g not in genes] or list(GENES)
		var avail: Array = []
		for g in GENES:
			if not genes.has(g):
				avail.append(g)
		if avail.is_empty():
			for g in GENES:
				avail.append(g)
		var picked: String = rng.choice(avail)
		genes.append(picked)
		var stat: String = GENES[picked]
		gene_bonus[stat] = float(gene_bonus.get(stat, 0.0)) + float(lvl["gene_bonus_step"])
		events.append("GENE: " + picked + " (+" + stat + ")")

	if rng.random() < float(lvl["branch_chance"]):
		events.append("BRANCH")

	return {"expression": expression, "events": events}
