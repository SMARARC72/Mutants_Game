# infrastructure/worldgen — WorldGenerator (Cluster 4, D2 + D5, ADR-019)

The region-generation subsystem. One facade, two composed generators, seeded by the canonical RNG
and persisted to the save — never re-simulated on load. **Infrastructure layer: lays out tiles,
computes no gameplay number** (the domain oracle stays the single source of numbers; CI purity gate).

## Files

| File | Role |
|---|---|
| `world_generator.gd` | **Facade.** `generate(region_id, seed) -> Layout`. Seeds `canonical_rng(seed, region_id)`, runs WFC, stitches set-piece rooms, falls back to an authored layout on solver failure. `generate_threaded` runs the solve on a `WorkerThreadPool` task (result is thread-order-independent). `get_or_generate` / `load_layout` / `store` are the generate-once + persist-to-`world_state` path. |
| `wfc_solver.gd` | Deterministic **Wave-Function-Collapse 2D** (the `godot-constraint-solving` `WFC2DGenerator` job, self-contained): observe (min-entropy) / propagate (arc consistency) / chronological backtracking + an attempt limit. All randomness from the injected `CanonicalRNG`. |
| `dungeon_assembler.gd` | **SimpleDungeons** role: stamps authored set-piece rooms (boss lairs, ritual sites) onto the WFC fill. Seeded placement, no overlaps. |
| `region_rules.gd` | Loader for `res://catalog/region_layouts.json` (tile palette, WFC adjacency, set-piece specs, sizes; `defaults` merged with per-region overrides). |
| `layout.gd` | The plain-data result type: row-major tile grid + room footprints + metadata; versioned-JSON serialization (ADR-012). |

## Determinism contract (ADR-019/001)

Generation is a pure function of `(region_id, seed)`. Every random draw — WFC tile collapse AND
room placement — comes from `WorldGenerator.region_rng(seed, region_id)` (a `CanonicalRNG.substream`
of a FNV-1a hash of `region_id`, the same scheme `LabBench` uses). No `randf`/`randi`/`randomize`,
wall-clock, or thread-scheduling input. Same inputs → bit-identical `Layout` on any machine / OS /
load. The persisted grid is canonical; the solver is a client-side authoring aid (cf. the Lab's
persisted `splice_config`, ADR-015), so a server can re-derive or simply trust the stored layout.

## Persistence

`Layout.to_dict()` → `RunContext.world_state.region_layouts[region_id]` (a versioned-JSON dict, never
a `.tres`). On load, `WorldGenerator.load_layout` rehydrates with `Layout.from_dict` and the solver
is NEVER re-run (the generate-once invariant). Numeric reads are `int()`-wrapped (JSON decodes bare
numbers as FLOAT in GDScript).

## Authored fallback (no soft-lock)

If the WFC solver returns a contradiction (over-constrained ruleset) or exhausts its attempt budget,
the facade returns a hand-authored, guaranteed-traversable fallback (a walled room) with set-piece
rooms still stitched. Unknown regions and a missing catalog also fall back cleanly.

## Better Terrain seam

The WFC output is plain tile ids. A "Better Terrain"-style autotiler is a **render-time cosmetic**
pass over the persisted grid (it adds no traversability-changing tile), so it is intentionally not
part of generation/persistence — `presentation/` reads `Layout.tiles` and applies its terrain set.

## Tests

`client/tests/worldgen_test.gd` (GdUnit4) asserts: reproducibility (same inputs → identical tiles),
persist-not-re-simulate (reload from `world_state` without the solver), authored fallback on a forced
solver failure, cross-run determinism, threaded == synchronous, and set-piece stitch + persist.
