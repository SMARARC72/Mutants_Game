# PHASE — Integration Cluster 4 · D3: The Lab Legality Engine

**Branch:** `cluster-4-lab-legality` (off `main` via worktree) · **Scope:** D3 ONLY (Lab Legality
Engine). D1 CombatBrain / D2+D5 WorldGenerator+SimpleDungeons / D4 inventory+OctoD adapters / D6
LimboConsole probes are explicitly OUT of scope (a later wave). **Status:** complete.

This implements `docs/Mutants_Game_SpliceRules.md` (the CSP data model §3, the `splice_rules.json`
schema §4, the four worked examples §5, the CI validation §7) and `docs/Claude_Code_Cluster4_Mechanics.md`
§D3 + ADR-015 + DoD item 3.

## The hard line (ADR-015) — and how it is held
Two systems, one boundary, no duplication:

- **`lab_engine` (oracle, `client/domain/lab_engine.gd`)** — owns ALL numbers + the mechanical blend
  (force blend 0.6/0.4, tier escalation, `stat_block`, the entropy/corruption cost ledger, opposed-pair
  taboo detection). **Untouched by this work** (`git status client/domain/` is empty; the CI domain-purity
  grep gate stays green).
- **The Lab Legality Engine (this work, `infrastructure/lab/` behind `LabBench` in `application/lab/`)**
  — owns the RULES layer: is the op permitted? which ingredient/trait/gene/organ slots are legal &
  non-conflicting? is a taboo op unlocked? which config when several are legal? It produces a validated
  `splice_config`; **`lab_engine.fuse` computes the creature.** No force blend, no stat is recomputed.

`LabBench.commit` proves the boundary at runtime: it picks a config with the canonical RNG, then calls
`LabEngine.fuse(a, b, method, rng)` on the **original inputs** — the config gated/resolved legality only.
The contamination-guard test asserts the committed result EQUALS `LabEngine.fuse` on the same inputs+seed.

## Deliverables — what was built

| # | Deliverable | File(s) |
|---|---|---|
| 1 | `splice_rules.json` (§4 schema: forces, opposed, thresholds, unlocks, 5 operations, trait_slots, ingredient_compat, gene_compat, bridges) | `client/catalog/splice_rules.json` |
| 2 | splice_rules loader + schema validator | `client/infrastructure/lab/splice_rules.gd` |
| 3 | CSP legality solver (self-contained backtracking core + the §3 op→CSP facade) | `client/infrastructure/lab/csp_solver.gd`, `client/infrastructure/lab/legality_solver.gd` |
| 4 | `LabBench` (preview/commit; routes commit to `lab_engine`) | `client/application/lab/lab_bench.gd` |
| 5 | GdUnit4 tests (examples, soundness, contamination/parity, CSP+loader units) | `client/tests/lab_legality_examples_test.gd`, `lab_legality_soundness_test.gd`, `lab_legality_parity_test.gd`, `lab_csp_solver_test.gd` |
| 6 | Python coverage lint + CI wiring | `tools/test_splice_rules_coverage.py`, `.github/workflows/ci.yml` (appended one step to the `oracle` job) |
| 7 | ADR-015 + README row | `docs/adr/0015-addons-never-own-outcome-math.md`, `docs/adr/README.md` |
| 8 | This report | `PHASE_Cluster4_LabLegality_REPORT.md` |

THIRD_PARTY.md updated (appended a Cluster-4 section; existing rows untouched).

## godot-constraint-solving: self-contained CSP, NOT vendored (and why)
I wrote a small self-contained backtracking CSP in GDScript (`csp_solver.gd`, ~95 lines) instead of
vendoring `godot-constraint-solving`. The spec (D3 / SpliceRules §3) explicitly permits this "if the lib
cannot be vendored cleanly … the CSP semantics matter more than the specific lib." Reasons:

1. That addon's public surface is a **Wave-Function-Collapse tile solver** (2D grid collapse over a
   `TileMapLayer`), not a **generic finite-domain CSP** with arbitrary constraint predicates over named
   variables — which is exactly what SpliceRules §3 needs (`force_intent` / `tier_target` / `class_target`
   / `trait_slots[]` / `flags` + 5 custom rule-constraints). Bending the WFC API to that shape is more
   code and more risk than the ~95-line backtracking core.
2. Godot is not installable in this environment, so a 4.7-clean vendor could not be verified locally.

`csp_solver.gd` carries NO game/outcome math; it is a pure solver. The WFC addon may still be vendored
later for `WorldGenerator` (D2), its actual purpose. Documented in `client/addons/THIRD_PARTY.md` + ADR-015.

## How `LabBench.commit` maps a splice_config → `lab_engine.fuse(a, b, …)`
1. `preview(a, b, ingredients, method, player_state, op)` → `LegalitySolver.preview` → verdict
   (`LEGAL` / `ILLEGAL(reason)` / `TABOO(unlock_cost)`) + candidate `splice_config`s. If not LEGAL,
   `commit` returns the verdict and **produces NO creature** (backtracking → clean fail, never partial).
2. On LEGAL: a dedicated canonical sub-stream `pick_rng(run_seed, op_id)` selects one config index (the
   §3 "choice among legal variants", reproducible). The chosen config gets `rng_seed_tag = op_id`.
3. `_compute` calls **`LabEngine.fuse(a, b, method, numeric_rng(run_seed, op_id))`** — the ORIGINAL
   `a`/`b` creatures, NOT config-substituted values. The oracle recomputes the blend/stats/ledger; the
   config contributed only permission + slot/flag/tier resolution. (`pick_rng` and `numeric_rng` are
   separate sub-streams off the same `(run_seed, op_id)`, so config choice never perturbs the numeric roll.)
4. Returns `{ verdict: LEGAL, creature: <oracle result>, splice_config: <chosen config>, rng_seed_tag }`.
   The DAL persists `creature` + `splice_config` in `creature_instances.lineage` (SpliceRules §6); re-running
   `lab_engine` on the stored config reproduces the creature, so the CSP need not re-run on server re-validation.
   Single-creature ops (graft/mutate/self_splice/reanimate) — `lab_engine` v0.1 ships only `fuse`, so the host
   is fused against a synthetic partner derived from the resolved `force_intent`/`tier_target`; the oracle
   still does every number.

## Tests — what each asserts, and what was run locally

GDScript (GdUnit4) — **CI-validated** (Godot not installed locally; statically reviewed + lint/format-clean):
- `lab_legality_examples_test.gd` — the four §5 worked examples: (1) Thanatos/Chaos × Thanatos/Ouranos →
  **LEGAL**; (2) Cosmos/Eros × Chaos/Ouranos at corruption 35 → **TABOO** (cost = corruption≥40 OR
  abomination_rites), then **LEGAL** once unlocked OR at corruption 40; (3) crystal_lattice graft onto
  organic Thanatos → **ILLEGAL** with reason containing "organic"+"Thanatos" (and `commit` yields no
  creature); (4) god_core graft at corruption 72 with the part → **LEGAL(taboo)**; below threshold / no
  part → **TABOO**.
- `lab_legality_soundness_test.gd` — property test: 120 canonical-RNG-seeded random fuses; every
  LEGAL/TABOO config re-satisfies all five §3 constraints; ILLEGAL → 0 configs + commit yields no
  creature; TABOO commit yields no creature; LEGAL commit yields one. Plus: every opposed pair at clean
  player state is always TABOO + abomination-flagged.
- `lab_legality_parity_test.gd` — contamination guard: a committed fuse EQUALS `LabEngine.fuse` on the
  same inputs + `numeric_rng(seed, op_id)`, field-for-field (name/prim/sec/tier/method/taboo/hp/bst/
  entropy/corruption/stats); the persisted config carries NO stat/hp/bst/entropy/corruption keys;
  same (seed, op_id) commits twice → identical creature; the opposed (taboo) fuse still matches the
  oracle's own taboo ledger (corruption +18) — proving the CSP only flipped `flags.taboo`.
- `lab_csp_solver_test.gd` — CSP core (only-solution found; unsatisfiable → clean empty; `solve_all`
  enumerates all) + loader (default ruleset loads; malformed ruleset rejected → null + `last_error`;
  both-directions opposed rejected).

Python — **run locally, output verbatim:**

`python -B tools/test_splice_rules_coverage.py`:
```
splice_rules coverage lint: OK
  forces=6 ops=5 ingredients=14 genes=4 trait_slots=4
```
Verified it FAILS on malformed rulesets — 10 mutations (drop a force, bad schema_version, opposed
undefined force, opposed both directions, drop threshold, drop op, ingredient bad force, ingredient bad
slot, gate bad unlock, drop trait_slots) were each correctly flagged (exit 1 with a specific message).

Additionally, to de-risk the GDScript algorithm before CI, I ported the solver logic to Python and ran
it against all four worked examples (all produced the spec verdict, incl. the exact §5 ex3 reason
"crystal lattice rejects organic Thanatos flesh") and a 2000-input soundness sweep:
`SOUNDNESS: legal=1903 taboo=97 illegal=0 violations=0` and `OPPOSED-ALWAYS-TABOO: True`. (Scratch port,
not committed — the committed soundness check is the GdUnit4 test.)

## Lint / format / static review (local, matching the CI lint job exactly)
gdtoolkit 4.5.0 (CI pins `4.*`) is available as a Python module locally. All 8 new `.gd` files:
`gdformat --check` → "left unchanged"; `gdlint` (with the repo `gdlintrc`) → "no problems found".
GDScript lambda capture verified against the Godot docs (capture-by-value-at-creation); the two
per-iteration constraint loops bind fresh locals before each lambda so no loop variable is captured.
`.uid` files committed for clean-clone UID resolution. `client/domain/` untouched.

## CI wiring (minimal, localized)
`.github/workflows/ci.yml` — appended ONE step to the existing `oracle` job (after the golden-vector
gate): `Lab Legality ruleset coverage lint (SpliceRules §7, ADR-015)` →
`PYTHONUTF8=1 python -B tools/test_splice_rules_coverage.py`. No other job touched. The drift gate is
unaffected: `splice_rules.json` is authored, not produced by `gen_catalog.mjs` (verified — the generator
writes only species/gear/skills/version), so it never appears in the drift diff.

## Deviations / notes / blockers
- **CSP is self-contained, not the vendored addon** — by design and spec permission (see above). This is
  the only material deviation from a literal reading of D3 ("vendor godot-constraint-solving").
- **Single-creature ops use a synthetic-partner fuse** — `lab_engine` v0.1 exposes only `fuse`/`blend`;
  graft/mutate/self_splice/reanimate route through `fuse` with an oracle-blended synthetic partner. The
  rules/legality (the D3 deliverable) are fully modeled for all five ops; if `lab_engine` later adds
  dedicated graft/mutate entries, only `LabBench._compute` changes (the CSP/rules are unaffected).
- **GdUnit4 tests are CI-validated, not run locally** (Godot not installed). Mitigated by: gdformat/gdlint
  clean against the real CI config, a careful static review (preload paths exist, `LabEngine.fuse`
  signature matched, enum/const refs valid), and the Python algorithm port reproducing every verdict.
- No changes to `client/domain/`, the oracle, or existing tests.
