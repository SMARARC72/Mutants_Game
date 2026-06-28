class_name CanonicalRNG
extends RefCounted
## Canonical RNG — PCG32 (PCG-XSH-RR 64/32), ADR-001. Bit-identical to
## oracle/canonical_rng.py (verified by tests/rng_vectors.json). GDScript int is int64 and
## wraps on overflow (two's complement) like the masked Python side; right-shifts must be
## LOGICAL (Godot >> is arithmetic on negatives), so unsigned shifts go through _lsr().
## DOMAIN layer: pure, no Node/stdlib-RNG/wall-clock (CI domain-purity gate). Engines inject this.

const MASK32 := 0xFFFFFFFF
const PCG_MULT := 6364136223846793005
# inc = ((0xDA3E39CB94B95BDB << 1) | 1), precomputed because GDScript forbids shifting
# negative operands (the unsigned stream constant is a negative int64).
const INC := -5441347156697761865  # 0xB47C73972972B7B7
const SM_ADD := -7046029254386353131  # 0x9E3779B97F4A7C15
const SM_M1 := -4658895280553007687  # 0xBF58476D1CE4E5B9
const SM_M2 := -7723592293110705685  # 0x94D049BB133111EB

var state: int = 0
var inc: int = 0
var _seed: int = 0


static func _lsr(v: int, k: int) -> int:
	# Logical (unsigned) shift right of a 64-bit value. GDScript >> on a negative int is
	# forbidden, so clear the sign bit first (-> positive), shift that, then restore the
	# original bit-63 at its shifted position (63-k).
	if k <= 0:
		return v
	var res := (v & 0x7FFFFFFFFFFFFFFF) >> k
	if v < 0:
		res = res | (1 << (63 - k))
	return res


func _init(seed: int) -> void:
	_seed = seed
	inc = INC
	state = 0
	_step()
	state = state + _seed
	_step()


func _step() -> int:
	var old := state
	state = old * PCG_MULT + inc
	var xorshifted := _lsr(_lsr(old, 18) ^ old, 27) & MASK32
	var rot := _lsr(old, 59)
	return _rotr32(xorshifted, rot)


static func _rotr32(value: int, rot: int) -> int:
	value = value & MASK32
	rot = rot & 31
	return ((value >> rot) | (value << ((-rot) & 31))) & MASK32


func next_u32() -> int:
	return _step()


func next_float() -> float:
	return float(_step()) / 4294967296.0


func random() -> float:
	return next_float()


func uniform(a: float, b: float) -> float:
	return a + (b - a) * next_float()


func randint(a: int, b: int) -> int:
	# inclusive [a,b]; Lemire multiply-high (bias-reduced, rejection-free). Ranges are small.
	var r := b - a + 1
	return a + ((next_u32() * r) >> 32)


func choice(seq: Array) -> Variant:
	return seq[randint(0, seq.size() - 1)]


func substream(purpose: int) -> CanonicalRNG:
	return CanonicalRNG.new(_splitmix64(_seed ^ purpose))


static func _splitmix64(x: int) -> int:
	var z := x + SM_ADD
	z = (z ^ _lsr(z, 30)) * SM_M1
	z = (z ^ _lsr(z, 27)) * SM_M2
	return z ^ _lsr(z, 31)
