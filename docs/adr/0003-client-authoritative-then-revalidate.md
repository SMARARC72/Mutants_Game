# ADR-003 — Client-authoritative sim now; deterministic server re-validation later

**Status:** Accepted (TDD §7.5, §9.5) · **Phase:** decided P0, implemented P4+

## Context
MVP is single-player; editing your own save harms no one. Competitive/Succession results that
affect others need an authority — but a third re-implementation would triple the parity surface.

## Decision
Trust the client for its own single-player run. When results affect others, re-run the **existing
Python oracle server-side** from `(seed, command_log)` and compare a result hash. Never introduce
nondeterminism that would forfeit this defense.

## Consequences
- Determinism (ADR-001/002) is a hard requirement, not a nicety.
- Phase 0 keeps the sim deterministic-ready; the validate endpoint is specified, built later.
