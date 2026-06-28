class_name LootEngine
extends RefCounted
## Mutants_Game - LOOT & GEAR engine (v0.1): player gear that boosts CHANCES & capabilities
## for capture / tame / breed / lab / combat. Typed port of oracle/loot_engine.py (the LAW).
## DOMAIN layer: pure (no Node/SceneTree/stdlib-RNG/wall-clock). Randomness is injected via
## CanonicalRNG. Data tables/constants are single-sourced from Constants.BALANCE["loot"].


static func _loot() -> Dictionary:
	return Constants.BALANCE["loot"]


static func clamp_val(v: float, a: float, b: float) -> float:
	# Python clamp(v,a,b) == max(a, min(b, v)) — order matters for NaN-free numeric inputs only.
	return maxf(a, minf(b, v))


static func bonus(gear_list: Array, field: String) -> float:
	# sum(GEAR[g].get(field, 0) for g in gear_list) — missing field defaults to 0; preserve order.
	var gear: Dictionary = _loot()["gear"]
	var total := 0.0
	for g in gear_list:
		var entry: Dictionary = gear[g]
		total += float(entry.get(field, 0))
	return total


static func capture_chance(
	method: String,
	tier: String,
	hp_frac: float,
	bond: float,
	gear_list: Array,
	morality_fit: float = 1.0
) -> float:
	var loot: Dictionary = _loot()
	var base: float = float(loot["capture_base"][method])
	var hp_mult := clamp_val(
		float(loot["capture_hp_mult_const"]) - hp_frac,
		float(loot["capture_hp_mult_lo"]),
		float(loot["capture_hp_mult_hi"])
	)  # near-death easier
	var bond_mult := (
		1.0 + (bond * float(loot["capture_bond_factor"]) if method == "befriend" else 0.0)
	)
	var gear_mult := 1.0 + bonus(gear_list, "capture")
	return clamp_val(
		base * float(loot["tier_factor"][tier]) * hp_mult * bond_mult * gear_mult * morality_fit,
		float(loot["capture_clamp_lo"]),
		float(loot["capture_clamp_hi"])
	)


static func breed_roll(gear_list: Array, rng: CanonicalRNG) -> Dictionary:
	var loot: Dictionary = _loot()
	var rare_chance := clamp_val(
		float(loot["breed_rare_base"]) + bonus(gear_list, "breed_rare"),
		float(loot["breed_rare_clamp_lo"]),
		float(loot["breed_rare_clamp_hi"])
	)
	var rare: bool = rng.random() < rare_chance
	var iv_ceiling := CanonicalMath.rnd_dp(
		(
			float(loot["breed_iv_ceiling_base"])
			+ (float(loot["breed_iv_ceiling_rare_bonus"]) if rare else 0.0)
		),
		int(loot["breed_iv_ceiling_round_dp"])
	)  # rare/gear lifts the genome ceiling
	return {"rare": rare, "chance": rare_chance, "iv_ceiling": iv_ceiling}
