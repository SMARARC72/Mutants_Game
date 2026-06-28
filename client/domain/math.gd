class_name CanonicalMath
extends RefCounted
## Canonical arithmetic — half-to-even rounding, ADR-002. Bit-identical to
## oracle/canonical_math.py. Replaces every round() in the ported engines (GDScript round()
## is half-away-from-zero; Python round() is half-to-even — this is the shared truth).
## DOMAIN layer: pure (CI domain-purity gate).


static func rnd(x: float) -> int:
	var f := int(floor(x))
	var diff := x - float(f)
	if diff < 0.5:
		return f
	if diff > 0.5:
		return f + 1
	# exact .5 tie -> round to even
	return f if (f % 2 == 0) else f + 1


static func rnd_dp(x: float, n: int) -> float:
	# Round to n decimal places via canonical half-to-even (replaces round(x, n)).
	var factor := pow(10, n)
	return float(rnd(x * factor)) / factor

