# ADR-015 — Addons never own outcome math; the Lab Legality Engine gates, the oracle computes

**Status:** Accepted (Integrations §A1.1 / ADR-015; implements `Mutants_Game_SpliceRules.md`) ·
**Phase:** Integration Cluster 4 (Mechanics) · **Deliverable:** D3 (Lab Legality Engine)

## Context
Integration Cluster 4 adds AI, procedural generation, the Lab Legality Engine, and inventory/ability
substrates — each of which could leak a gameplay number out of the parity-tested oracle
(`client/domain/`). The Lab is the signature system. Its question — *"what can you splice, and how
does the non-numeric configuration resolve?"* — is naturally expressed as a constraint-satisfaction
problem over a designer-authored ruleset. But splice **outcomes** (the force blend 0.6/0.4, tier
escalation, `stat_block`, the entropy/corruption cost ledger, mechanical taboo via the opposed pair)
are already computed, ported, and golden-vector-parity-tested in `client/domain/lab_engine.gd` (with
the Python twin `oracle/lab_engine.py`). If the Legality Engine recomputed any of that, we would have
two sources of truth and the parity gate would no longer mean what it says.

## Decision
There is a **hard line** with two systems that must not duplicate each other:

- **`lab_engine` (the oracle, `client/domain/`)** owns **all numbers + the mechanical blend**: force
  blend, tier escalation, `stat_block`, the entropy/corruption ledger, opposed-pair taboo detection.
- **The Lab Legality Engine** (`infrastructure/lab/` behind `LabBench` in `application/lab/`) owns the
  **rules layer**: is the op permitted? which ingredient-driven trait/gene/organ slots are legal and
  non-conflicting? is a taboo op unlocked? which valid config when several exist?

The Legality Engine **never recomputes the force blend or any stat.** It produces a validated
`splice_config`; `LabEngine.fuse` computes the creature from the **original inputs**. Concretely:

1. `res://catalog/splice_rules.json` is the versioned, designer-editable ruleset (`SpliceRules.md` §4).
   Designers add an organ / gate / taboo by editing JSON — **no GDScript changes.**
2. `LabBench.preview(a, b, ingredients, method, player_state)` maps the op onto a CSP
   (`LegalitySolver` + `CspSolver`) per `SpliceRules.md` §3 — variables `force_intent` / `tier_target`
   / `class_target` / `trait_slots[]` / `flags`; five constraints (force-compat, ingredient-legality,
   tier-ceiling, class-rules, gate-satisfaction). Backtracking yields **`LEGAL` / `ILLEGAL(reason)` /
   `TABOO(unlock_cost)`** plus candidate `splice_config`(s) — a complete valid config or a clean
   failure, never a half-formed creature.
3. `LabBench.commit(...)` picks one config with `canonical_rng(run.seed, op_id)` when several are
   legal, then calls **`LabEngine.fuse(a, b, method, rng)`** for every number. The chosen config is
   persisted in `creature_instances.lineage` so the op reproduces exactly by re-applying `lab_engine`
   to the stored config (`SpliceRules.md` §6) — **the CSP need not re-run for server re-validation.**

`godot-constraint-solving` was evaluated and **not** vendored for D3: its public surface is a
Wave-Function-Collapse tile solver, not a generic finite-domain CSP with arbitrary predicates over
named variables. The spec explicitly allows a self-contained GDScript CSP when the lib can't be
vendored cleanly ("the CSP semantics matter more than the specific lib"), so we ship a ~70-line
backtracking core (`infrastructure/lab/csp_solver.gd`). See `client/addons/THIRD_PARTY.md`.

## Consequences
- A **contamination-guard test** asserts a committed splice's result **equals `LabEngine.fuse`** on
  the same inputs + seed — proving the CSP contributed config only, not math (Cluster 4 DoD item 4).
- A **ruleset soundness property test** asserts the solver's output always satisfies every constraint,
  and that illegal inputs never yield a creature (`SpliceRules.md` §7).
- A **coverage lint** (`tools/test_splice_rules_coverage.py`, wired into CI's `oracle` job) fails on a
  malformed ruleset: undefined forces/ops/ingredients/thresholds/unlocks, asymmetric opposed pairs.
- Nothing is added to `client/domain/`; the CI domain-purity grep gate stays green. The Lab becomes a
  **content surface** (edit JSON) instead of a maintenance liability (edit GDScript `if/else`).
- The boundary generalizes the cluster rule: **addons never own outcome math** — inventory only
  stores, OctoD only presents, the CSP only gates/resolves; the oracle computes.
