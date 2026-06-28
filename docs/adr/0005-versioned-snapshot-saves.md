# ADR-005 — Versioned snapshot saves + retained command log; forward-only migrations

**Status:** Accepted (TDD §10) · **Phase:** decided P0, implemented P3

## Context
The run aggregate is the unit of save. Full event-sourcing is too heavy for single-player, but the
deterministic command log is valuable for audit/replay/validation.

## Decision
Cloud = normalized Postgres rows (system of record). Local = versioned JSON snapshot of `RunContext`
+ an offline command queue. Keep the deterministic command log alongside the snapshot. Forward-only
migration chain on load; never strand a save. `save_version` is the sole sync conflict key (TDD §10.3).

## Consequences
- Phase 0 adds `runs.save_version` / `schema_version` (0002) so the conflict key exists from day one.
- Save (de)serialization + migration chain implemented P3.
