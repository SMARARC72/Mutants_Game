# PHASE REPORT — Integration Cluster 2: Content Pipeline

**Branch:** `cluster-2-content` · **Engine:** Godot 4.7-stable · **Spec:** `docs/Claude_Code_Cluster2_Content.md` (D1–D6), `docs/adr/0006-catalog-single-source.md`.

This cluster adds the **import-time content pipeline** that turns the creature registry CSV into
typed, queryable client data, single-sourced with the Postgres seed (ADR-006). The importer/catalog
**computes nothing** — no stats, no RNG; it is plain static data. Runtime stats are produced by the
oracle (`client/domain/stat_engine.gd`) from this data. **Nothing was added to `client/domain/`** —
the determinism boundary and its CI grep gate are untouched. The catalog facade lives in
`client/infrastructure/catalog/`.

---

## What was added — and where

### Vendored addon (D1)
| Addon | Pinned | License | Source |
|---|---|---|---|
| **CSV Data Importer** | tag `2.1` @ `cb6e945033f25459661af40633b31ed9cca65eca` (`plugin.cfg` reports `2.0`) | MIT (© 2021 Haoyu Qiu) | github.com/timothyqiu/godot-csv-data-importer |

- Vendored to `client/addons/csv-data-importer/` (`plugin.cfg`, `plugin.gd`, `import_plugin.gd`,
  `csv_data.gd`, their `.uid` companions, `LICENSE`). The upstream `examples/`, demo `project.godot`,
  and icons were **not** vendored (editor-import addon only).
- Enabled in `client/project.godot` `[editor_plugins]`; provenance + the local mod recorded in
  `client/addons/THIRD_PARTY.md` (appended; existing rows untouched).
- **Local mod (important):** upstream claims plain `.csv`/`.tsv` at priority `2.0`, which **outranks
  and hijacks Godot's built-in Translation importer**. The project ships a translation CSV
  (`addons/maaacks_game_template/base/translations/menus_translations.csv`, `importer="csv_translation"`)
  that must stay a translation. So `import_plugin.gd` now recognizes a dedicated `.csvdata`
  extension and drops priority to `1.0` (mirrors the existing inkgd `.inkjson` precedent). Plain
  `.csv` files are left untouched.

### Catalog facade + Resources (D2/D3) — `client/infrastructure/catalog/`
| File | Role |
|---|---|
| `species_data.gd` (`class_name SpeciesData`) | one registry row as a typed `Resource`; mirrors the `species` table contract |
| `species_db.gd` (`class_name SpeciesDB`) | packed `@export var species: Array[SpeciesData]` |
| `species_catalog.gd` (`class_name SpeciesCatalog`) | the **only** read surface: `get_by_id(id)`, `all()`, `count()`, `by_force(f)`, `by_tier(t)`, `by_rank(r)` |

- `SpeciesData` fields = `id, name, batch, art_ref, species_class, rank, tier, force_primary,
  force_secondary, role, evolution_line, stage, signature_skill, tags:PackedStringArray, description,
  status`. No derived/stat fields. Note `class` is a GDScript keyword → the export var is
  `species_class` (maps to the `species.class` column); `tags` is a `PackedStringArray`.
- The lookup method is `get_by_id(id)`, NOT `get(id)`. Overriding the native `Object.get(property)`
  does not work — Godot never dispatches `catalog.get("AD01")` to a user override; it calls the
  built-in property getter (returns null). So the facade uses a distinct name the engine never
  shadows.

### Imported Resources (D2) — `client/catalog/species/species_db.tres`
- A single **packed `SpeciesDB`** text Resource with **406** typed `SpeciesData` sub-resources, one
  per seeded registry row (`load_steps=409`).
- Produced at build time from `docs/creature_registry.csv` by `tools/gen_species_db.mjs` (see D4).
  A committed text `.tres` is native, deterministic, diffable, and loads headlessly with no Godot
  reimport — the right artifact for CI given Godot isn't run by the lint/oracle jobs. The vendored
  csv-data-importer is the in-editor authoring path; this generator is the build-time path.

### Single-source pipeline (D4, ADR-006)
- `tools/gen_catalog.mjs` already derives `client/catalog/species.json` from
  `docs/creature_registry.csv` (`line→evolution_line`, `signature_skill` defaulted to null since the
  CSV lacks it, `acquisition` dropped). It now **also packs** `species_db.tres` by importing
  `tools/gen_species_db.mjs` at the end — so ONE source (the CSV) feeds **three** consumers: the
  JSON bundle, the Postgres seed (`supabase/seed.sql` via the unchanged `tools/gen_seed.mjs`), and
  the client Godot Resource.
- `tools/gen_species_db.mjs` reads `client/catalog/species.json` (not the CSV directly), guaranteeing
  the `.tres` is byte-for-byte consistent with the JSON/seed id-set.

### CI schema-lint (D4/D6) — `tools/test_catalog_parity.mjs`
- Pure Node, no deps. Asserts and **fails (exit 1)** on:
  - **A.** the registry CSV columns match the SpeciesData/`species`-table contract after the
    documented reconciliation (`line→evolution_line`, `acquisition` dropped, `signature_skill`
    defaulted) — guards against silent CSV column drift.
  - **B.** the client catalog (`species.json`), the client Resource (`species_db.tres`), and the
    Postgres seed (`supabase/seed.sql`) agree **exactly** on species **count** and **id-set**.
- Wired into `.github/workflows/ci.yml` as one appended step in the existing `lint` job (minimal,
  localized). The existing `oracle` job's drift gate (`git diff … client/catalog supabase/seed.sql`)
  already covers the new `.tres` since it lives under `client/catalog/`.
- `package.json`: added `gen:species-db` and `test:catalog-parity` scripts.

### Smoke test (D7, GdUnit4) — `client/tests/species_catalog_test.gd`
- `extends GdUnitTestSuite`, house style. Asserts the catalog loads, `count()==406`, all entries are
  typed `SpeciesData` with non-empty `id`/`force_primary`, `get_by_id("AD01")` returns Ruinmaw
  (Chaos/Thanatos, T2, wild, organic, Ruin Wolf), `get_by_id(unknown)==null`, `tags` is a
  `PackedStringArray`, and `by_force`/`by_tier`/`by_rank` filter correctly. **CI-only** (requires the
  `godot-tests` job; Godot is not installed locally).

---

## The 407 vs 406 discrepancy — cause + resolution

**Cause:** `docs/creature_registry.csv` has **407 data rows** (408 lines incl. header), all with
**unique ids** (no duplicates, no blank trailing row). Exactly **one row is unseedable**:

> line 189 — `id=batch3-078`, `name` empty, `force_primary` empty (`status=void`, `tags=blank-render`)

The `species` table declares `force_primary text not null` (plus a force CHECK), so this row cannot
be inserted. `tools/gen_catalog.mjs` already skips rows with empty `force_primary` (logged in
`client/catalog/version.json`). **407 registry rows − 1 unseedable = 406.** This matches ADR-006
("1 registry row (empty force_primary) is skipped") and the pre-existing 406-row `species.json`.

**Resolution / determinism:** the single skip rule lives in one place (`gen_catalog.mjs`), the count
is recorded in `version.json`, and `test_catalog_parity.mjs` now enforces that all three consumers
carry the **same 406 ids** — so the discrepancy can never silently re-open or diverge.

---

## Local command output (run on this machine — Node 22.12.0)

```
$ node tools/gen_catalog.mjs
catalog: species=406 (skipped 1), gear=6, skills=12, factions=9
species_db.tres: 406 SpeciesData sub-resources (load_steps=409)

$ node tools/gen_seed.mjs
seed.sql: 406 species, 6 gear, 12 skills, 9 factions

$ node tools/test_catalog_parity.mjs
A. registry CSV columns vs species-table contract
  ok: CSV header matches the expected 16 columns
  ok: CSV columns reconcile 1:1 onto the species-table contract
B. client catalog == client Resource == Postgres seed (count + id-set)
  counts: json=406, tres=406 (array refs=406), seed=406
  ok: all three sources report 406 species
  ok: .tres packed array length matches its sub_resource count
  ok: json id-set == seed id-set
  ok: json id-set == tres id-set
CATALOG PARITY: PASS
```

Negative check (verified): deleting one species from `species.json` makes the parity test fail with
exit 1 and a precise id diff. Also green locally: `gdformat --check` + `gdlint` (4 hand-written
files, relaxed `gdlintrc`), `eslint tools supabase/tests`, and gdparse on the 3 vendored addon
scripts.

---

## CI-only (cannot run locally — Godot not installed)
- `godot --headless --import` (project import with the new addon + the `.tres`).
- The GdUnit4 suite incl. `species_catalog_test.gd` — runs in the `godot-tests` job.
- The Supabase `db reset`/seed + pgTAP — runs in the `database` job (the seed is regenerated +
  drift-gated by the existing `oracle` job).

## Deviations / notes
- **D2 chose a packed `SpeciesDB.tres`** (spec-permitted) over one Resource per row, and produces it
  via a **Node generator** rather than a live Godot reimport — necessary because Godot can't run in
  the lint/oracle CI jobs, and it keeps the client Resource in lock-step with the JSON/seed.
- **`SpeciesData` includes `art_ref`** (present in the `species` table + `species.json` + seed),
  even though the spec's inline field list omitted it — to mirror the actual table contract exactly.
  Still pure catalog data, no derived/stat field.
- The 5 previously-committed generated artifacts (`gear/skills/species/version.json`, `seed.sql`)
  regenerate byte-identically (no content change); only the new `species_db.tres` is added.

**STOP** — Cluster 2 only. Cluster 3 (narrative) is already in the repo history; nothing else built.
