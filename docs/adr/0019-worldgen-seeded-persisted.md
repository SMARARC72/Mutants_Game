# ADR-019 — World generation is seeded (canonical RNG) + persisted, never re-simulated

**Status:** Accepted (Integrations §A1.2/§B4, Cluster 4 D2+D5) · **Phase:** implemented Cluster 4

This ADR records the **Cluster-4 "generation seeded + persisted" decision** for the WorldGenerator
(WFC region fill) and SimpleDungeons set-pieces. It is a DIFFERENT topic from ADR-014
(runs.corruption floor-only) — the umbrella "ADR-014" label in the integration docs refers to the
generation policy described here, which we record under its own number to avoid overloading 0014.

## Context

Region layouts (overworld + dungeons) are procedurally generated. Two failure modes must be
designed out:

1. **Non-reproducibility / parity drift.** If generation draws from Godot's `RandomNumberGenerator`
   or global `randf`/`randi`, the same run yields different worlds on different machines / OS targets
   / engine builds, breaking save reload and any future server re-validation (TDD §6, ADR-001).
2. **Re-simulation on load + soft-locks.** Regenerating on every load wastes work and can diverge; a
   solver that can fail (over-constrained ruleset, attempt-budget exhaustion) must never leave the
   player in an empty/blocked region.

## Decision

- **Seeded by the canonical RNG.** `WorldGenerator.generate(region_id, seed)` derives a canonical
  sub-stream `canonical_rng(run.seed, region_id)` (the `CanonicalRNG.substream` of a FNV-1a hash of
  `region_id`, the same string→purpose scheme `LabBench` uses). ALL randomness — WFC tile collapse
  AND SimpleDungeons room placement — draws from that stream. No `randf`/`randi`/`randomize`,
  wall-clock, or thread-scheduling input. The result is a pure function of `(region_id, seed)`.
- **Generated once, persisted, reused.** The output is a plain-data `Layout` (tile grid + room
  footprints + metadata) serialized to **versioned-JSON** under
  `RunContext.world_state.region_layouts[region_id]` (ADR-012; never a `.tres`). `get_or_generate`
  returns the stored layout verbatim on a later load and **never re-runs the solver** (the
  generate-once invariant, cf. ADR-007). The solver is a client-side authoring aid, not the oracle —
  only its OUTPUT is canonical, exactly like the Lab's persisted `splice_config` (ADR-015).
- **Backtracking ON + attempt limit + authored fallback.** The WFC solver uses chronological
  backtracking and a per-region attempt budget. On contradiction or budget exhaustion the facade
  returns a **hand-authored fallback layout** (a guaranteed-traversable walled room, with set-piece
  rooms still stitched) — never a crash or empty grid (no soft-lock).
- **Threaded, determinism-independent of scheduling.** `generate_threaded` runs the solve on a
  `WorkerThreadPool` task so a large region does not hitch the frame. Because randomness is the
  injected canonical sub-stream (a value object), the result is identical regardless of which worker
  thread runs it — `generate_threaded` and `generate` produce the same `Layout`.
- **WFC + SimpleDungeons compose behind one facade.** WFC paints organic biome/connective tissue;
  the `DungeonAssembler` (SimpleDungeons role) stamps authored set-piece rooms (boss lairs, ritual
  sites) on top. Both seeded + persisted, both behind `infrastructure/worldgen/world_generator.gd`.

## Boundary (purity)

Worldgen lives entirely in `infrastructure/` (never `client/domain/`). It **lays out tiles; it
computes no gameplay number** — the CI domain-purity gate stays green. A "Better Terrain"-style
autotiler, if added, runs as a render-time cosmetic pass over the persisted grid; it is not part of
generation or persistence, so the persisted `Layout` stays the single canonical source.

## Vendoring note

`godot-constraint-solving` (its `WFC2DGenerator`) and upstream `SimpleDungeons` were evaluated. Both
draw placement randomness from Godot's own RNG (not bit-identical to our canonical PCG32 across OS
targets), so neither can satisfy the seeding requirement above without forking their internals, and
Godot is not installable in the build environment to verify a clean 4.7 vendor. We therefore ship
small, self-contained, parity-irrelevant cores (`wfc_solver.gd`, `dungeon_assembler.gd`) that
implement the deterministic algorithms and keep the upstream concepts (WFC observe/propagate; prefab
rooms = footprint + tile stamp). See `client/addons/THIRD_PARTY.md` (Cluster 4 — WorldGenerator).

## Consequences

- Reproducible worlds across machines/loads; saves carry the world as data; future server
  re-validation can re-derive a region from `(region_id, seed)` or just trust the persisted grid.
- A botched/over-constrained ruleset degrades gracefully to an authored layout instead of soft-
  locking — designers can author aggressive WFC rules without risking a stuck run.
- Tests (GdUnit4, `client/tests/worldgen_test.gd`) assert reproducibility, persist-not-resimulate,
  authored fallback on forced failure, cross-run determinism, and the threaded==synchronous property.
