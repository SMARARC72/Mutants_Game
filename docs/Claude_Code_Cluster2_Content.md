# CLAUDE CODE — Mutants_Game · Integration Cluster 2: Content Pipeline (Execution Prompt)

> Run inside the repo, **after Cluster 1**. Adds the **data pipeline** that turns the 1,000+ creature registry into typed, queryable game data — import-time only, **single-sourced** with the Postgres seed. Build to the DoD, then **stop and report**. Nothing here touches `client/domain/` or the oracle.

## 0. Authority
- Normative: `Mutants_Game_TechnicalDesign.md` (esp. **ADR-006** — catalog single-sourced) + `Mutants_Game_Integrations.md` §B3. Deviations → ADR.
- **Prime directive:** the importer produces **plain data**; it computes **nothing**. Stats come from the oracle (`stat_engine`) at runtime, given this data as input.

## 1. Scope — godot-csv-data-importer (🟢 MIT, *verify exact 4.7 build*)

Vendor pinned under `client/addons/`; record in `client/addons/THIRD_PARTY.md`.

## 2. Deliverables

### D1 — Species Resource schema
Define a `SpeciesData` Resource (`infrastructure/catalog/species_data.gd`) whose fields mirror the `species` table contract **exactly** (schema.sql): `id, name, batch, class, rank, tier, force_primary, force_secondary, role, evolution_line, stage, signature_skill, tags[], description, status`. No derived/stat fields — pure catalog.

### D2 — Import the registry CSV → Resources
- Configure godot-csv-data-importer to turn the **creature registry CSV** (the single source) into typed `SpeciesData` Resources under `res://catalog/species/` (or one packed `SpeciesDB`).
- This is **import-time** (dev/build), not runtime generation.

### D3 — `SpeciesCatalog` facade
- `infrastructure/catalog/species_catalog.gd`: `get(id)`, `all()`, `by_force(f)`, `by_tier(t)`, `by_rank(r)`. The rest of the game reads species **only through this facade** — never the addon or raw Resources.

### D4 — Single-source alignment (ADR-006) + CI lint
- The **same registry CSV** feeds (a) this importer → client bundle and (b) the existing `gen_seed` → Postgres. **One source, two consumers.**
- **CI schema-lint:** assert the CSV columns match the `SpeciesData`/`species`-table contract; assert the **client catalog count + id set ≡ the Postgres seed** (no divergence). Fail CI on mismatch.

## 3. Guardrails
- Catalog is **read-only static data**; the importer computes nothing (no stats, no RNG). Stats are produced at runtime by `stat_engine` from this data + a creature's genome.
- **Nothing in `client/domain/`** — `SpeciesCatalog` is `infrastructure/`; the domain receives plain data passed in.
- Single source of truth = the registry CSV; never hand-edit generated Resources.
- Pinned version recorded; CI green.

## 4. Definition of Done
1. `SpeciesData` schema matches the `species` table contract; no derived fields.
2. Importer produces a Resource per CSV row; counts match.
3. `SpeciesCatalog` lookups/queries work (smoke test).
4. CI schema-lint green; **client catalog ≡ Postgres seed** (ids + count) proven by a test.
5. Nothing added to `client/domain/`; project opens headless clean; CI green.
6. `PHASE_Cluster2_REPORT.md` written. **STOP** — do not start Cluster 3.

## 5. Next
**Cluster 3:** Dialogic + inkgd + Quest (narrative). For now: build Cluster 2 to the DoD and report.
