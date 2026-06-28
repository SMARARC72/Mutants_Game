class_name RngService
extends RefCounted
## RngService (ADR-016) — the ONLY randomness source the CombatBrain / BTs / HSM are allowed to
## touch. Wraps an injected canonical RNG sub-stream (CanonicalRNG, ADR-001) so every AI selection
## is byte-for-byte reproducible across runs and OS targets (TDD §6 replay).
##
## APPLICATION/ai layer. The Blackboard holds a reference to ONE RngService (the "BBNode->RngService"
## pattern from Integrations §A2). Behavior-tree leaves and HSM phases draw randomness ONLY through
## this object — NEVER LimboAI/Beehave RNG helpers and NEVER the engine-global random helpers.
## A CI grep gate over application/ai/ + application/battle/ proves no global/addon RNG appears there.
##
## This object NEVER computes a gameplay number — it only helps the brain SELECT (which target, which
## offense, which move). The oracle (battle_engine/skill_engine in client/domain/) resolves outcomes.

var _rng: CanonicalRNG


## Inject the canonical sub-stream the controller derived for this battle's AI selection. The brain
## owns no seed of its own: the controller hands in canonical_rng(run.seed).substream(AI_PURPOSE).
func _init(rng: CanonicalRNG) -> void:
	assert(rng != null, "RngService requires a CanonicalRNG (ADR-016: selection RNG is canonical)")
	_rng = rng


## A uniform float in [0, 1). Mirrors CanonicalRNG.random() — the same call the oracle uses.
func random() -> float:
	return _rng.random()


## Inclusive integer in [a, b]. Used to pick an index/element from a candidate list.
func randint(a: int, b: int) -> int:
	return _rng.randint(a, b)


## Pick one element from a non-empty array, canonically. Returns null on an empty array (the brain
## must guard for that — an empty candidate set means "no legal selection", not a random crash).
func choice(seq: Array) -> Variant:
	if seq.is_empty():
		return null
	return seq[_rng.randint(0, seq.size() - 1)]


## Roll a probability gate: true with probability p (clamped to [0,1]). One random() draw, like the
## oracle's `rng.random() < chance` idiom (matches skill_engine.act / battle_engine overload roll).
func chance(p: float) -> bool:
	return _rng.random() < clampf(p, 0.0, 1.0)


## Expose the wrapped sub-stream for the (rare) case a selector needs to derive a disjoint child
## stream of its own. Still canonical — no escape hatch to global RNG.
func canonical() -> CanonicalRNG:
	return _rng
