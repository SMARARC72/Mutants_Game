# ADR-009 — Python engines are the oracle; golden-vector parity gates CI

**Status:** Accepted (TDD §11.2) · **Phase:** foundation P0, parity P1–P2

## Context
The Python engines define canonical game behavior. The GDScript port must reproduce them exactly,
or the regression oracle and server re-validation collapse.

## Decision
Engines are relocated UNCHANGED in Phase 0 (`/oracle`). Their constants are transcribed faithfully to
`tools/balance_constants.json`, proved by `tools/test_constants_parity.py` (structural + source-fragment
checks). Phase 1 builds the golden-vector generator; Phase 2 ports the engines against the vectors. Any
mismatch fails CI.

## Consequences
- Phase 0 does NOT rewire engines to import the JSON (that changes engine internals — Phase 1, under the
  golden-vector harness). The §6.5 fixes (skill RNG, entropy-step unify to 0.12, StatSpine doc) are P1.
