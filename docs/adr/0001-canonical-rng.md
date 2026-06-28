# ADR-001 — Canonical RNG (PCG32) replaces stdlib RNG in both languages

**Status:** Accepted (TDD §6.3, §18 Q2) · **Phase:** decided P0, implemented P1

## Context
Determinism across Python (oracle) and GDScript (client) is the make-or-break feature
(save-as-seed, replay, server re-validation). Python's Mersenne Twister and GDScript's RNG
cannot be made bit-identical cheaply.

## Decision
Implement ONE small, fully-specified PRNG — **PCG32** — identically in `domain/rng.gd` and
`oracle/canonical_rng.py`. Every engine takes an **injected** RNG (no engine constructs its
own / calls a stdlib RNG). Sub-streams via documented seed derivation (splitmix64).

## Consequences
- The oracle is refactored onto the canonical RNG so it stays the parity source of truth.
- Phase 0 forbids new wall-clock/global-RNG dependence so Phase 1 drops in cleanly (the
  `domain/` purity grep gate, TDD §3.1). No RNG code ships in Phase 0.
