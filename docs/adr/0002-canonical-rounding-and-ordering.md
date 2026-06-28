# ADR-002 — Half-to-even rounding, integer-first math, total ordering

**Status:** Accepted (TDD §6.4) · **Phase:** decided P0, implemented P1

## Context
Python `round()` is half-to-even; GDScript `round()` is half-away-from-zero. Python `sorted`
is stable, `min`/`max`/`choice` are first-wins, dict iteration is insertion-order — GDScript
guarantees none of these. Unreconciled, the port diverges on ties.

## Decision
Implement `math.rnd()` (half-to-even) in both languages and use it everywhere the engines use
`round()`. Integer-first math, explicit operation order. Every sort uses a **total** comparator
with an explicit tiebreaker; every `min`/`max`/argmin is explicit first-wins; RNG/output-feeding
dict iteration goes through a fixed `*_ORDER` list. Golden vectors include deliberate tie cases.

## Consequences
- Parity asserts exact integer equality (floats at documented precision).
- Phase 0 records the constants single-source (`balance_constants.json`) that the rounded math
  will consume; the rounding/ordering code lands in Phase 1.
