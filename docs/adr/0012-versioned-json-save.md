# ADR-012 — Local save = versioned JSON (data-only); no Resource deserialization

**Status:** Accepted (TDD §10, §18 Q3) · **Phase:** decided P0, implemented P3

## Context
We import friend-shared Succession data. Deserializing a Godot `Resource`/`store_var(full_objects)`
can instantiate arbitrary scripts on load — a code-execution surface.

## Decision
Local save = **versioned JSON**, data-only via `JSON.parse_string`. Header carries
`{save_version, schema_version, app_version, run_id, written_at, checksum}`. The client NEVER
deserializes a Godot `Resource` or `store_var(full_objects)` from save or shared data. Mirrors the
Postgres aggregate (language-neutral, diffable, migratable).

## Consequences
- Phase 0 records the decision; the save serializer + migration chain land P3 (ADR-005).
