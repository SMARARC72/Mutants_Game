# CLAUDE CODE — Mutants_Game · Integration Cluster 4: Mechanics (Execution Prompt)

> Run inside the repo. **This is the determinism-critical cluster** — it adds AI, procedural generation, the Lab Legality Engine, and the inventory/ability substrates. Every one of these could leak gameplay logic out of the oracle; **they must not.** Build to the DoD, then **stop and report**.

## ⚠️ Prerequisite (hard gate)
This cluster **depends on the ported GDScript engines existing** (`lab_engine`, `battle_engine`, `skill_engine`, `status_engine`, the canonical RNG) — i.e. **Phase 1 + Phase 2 of the TDD runway are complete and parity-green.** Do **not** start Cluster 4 before then. (Clusters 1–3 + 5 do not need the engines; this one does.)

## 0. Authority & the prime directive
- Normative: `Mutants_Game_TechnicalDesign.md` (§3, §6, §11) · `Mutants_Game_Integrations.md` (§A1, §A2, §B1, §B4; **ADR-014/015/016**) · `Mutants_Game_SpliceRules.md` (the Lab Legality Engine spec).
- **The oracle owns outcomes.** Stats, damage, splice results, capture/breed math = the ported engines in `client/domain/`. Everything in this cluster **wraps around** them: AI *selects*, generation *constrains*, inventory *stores*. **Nothing in this cluster computes a gameplay number, and nothing goes in `client/domain/`.** The CI grep gate must stay green.

## 1. Scope & components (all 🟢 MIT)
LimboAI · godot-constraint-solving · expressobits/inventory-system · OctoD godot-gameplay-systems · SimpleDungeons. Vendor pinned (`client/addons/` or `infrastructure/` for libs); record in `THIRD_PARTY.md`.

## 2. Deliverables

### D1 — LimboAI → the `CombatBrain` (ADR-016)
- Facade `application/ai/combat_brain.gd`: **`choose_action(battle_state, rng) -> Action`** (our interface). The battle controller calls it, **passes the injected canonical RNG sub-stream**, gets a chosen action, and **resolves it via the oracle** (`battle_engine`/`skill_engine`). The brain never resolves.
- **The rule (non-negotiable):** any randomness in AI selection draws from the **canonical RNG via the Blackboard** (a `BBNode`→`RngService`), **never LimboAI helpers or global `randf`/`randi`**.
- **Succession invasion boss:** an HSM (`LimboState`) of phases — *Opening → Pressure → Desperation → Apotheosis* — each a Behavior Tree selecting moves from the imported **`god_snapshot`** kit; phase transitions Blackboard-gated (HP%, turns, squad losses, entropy clock).
- **Creature/role brains:** lightweight BTs (aggressor/support/controller) on the same Blackboard. **Overworld NPC brains** may be free-running (not simulation).
- **Determinism test:** same `(seed, teams)` → identical boss decisions → identical battle transcript across runs **and OS targets** (ties into the replay test, TDD §6).

### D2 — godot-constraint-solving → `WorldGenerator` (ADR-014)
- Facade `infrastructure/worldgen/world_generator.gd`: **`generate(region_id, seed) -> Layout`**. WFC2D over `TileMapLayer`, **seeded by `canonical_rng(run.seed, region_id)`**, **backtracking ON** + attempt limit + **fallback to an authored layout** on failure (no soft-lock). Runs on a `WorkerThreadPool` task.
- **Generated once, output persisted to `world_state`**; never regenerated on load. **Better Terrain** autotiles the output.

### D3 — godot-constraint-solving → the **Lab Legality Engine** (ADR-015, implements `SpliceRules.md`)
- Implement `res://catalog/splice_rules.json` (schema + loader) and the CSP mapping from `Mutants_Game_SpliceRules.md`.
- Facade `infrastructure/lab/legality_solver.gd` + `application/lab/lab_bench.gd`:
  - `LabBench.preview(a, b, ingredients, method, player_state)` → CSP → **`LEGAL` / `ILLEGAL(reason)` / `TABOO(unlock_cost)`** + candidate `splice_config`(s).
  - On commit: `canonical_rng(run.seed, op_id)` picks a config → **`lab_engine.fuse(config, rng)`** computes the numbers → **persist the `splice_config` in `creature_instances.lineage`**.
- **The boundary:** the CSP decides legality + ingredient/trait/flag resolution + choice; **`lab_engine` computes every stat.** No duplication of the force blend or any number.
- **Tests:** the 4 worked examples from `SpliceRules.md` pass; the **ruleset soundness property test** (solver output always satisfies all constraints; illegal inputs never yield a creature); **parity** (`lab_engine(config)` identical Python↔GDScript for the same persisted config+seed).

### D4 — Inventory + ability substrates (parity-safe adapters, ADR-015)
- **expressobits/inventory-system** → the **parts/kits/consumables/vials inventory** (items-as-Resources, grid UI, stacks) + its **crafting GRAPH as the Lab recipe-authoring/representation layer**. `LabBench` consumes inventory items → calls `lab_engine`; **the addon never computes the spliced creature.**
- **OctoD gameplay-systems** → optionally its **buff/debuff & ability *container* nodes** as a presentation/scheduling shell for statuses/skills — **numbers from `status_engine`/`skill_engine`.** Adopt selectively behind adapters.
- **Persistence:** map their Resources → our **versioned-JSON DTOs** (ADR-012); never serialize their `.tres`.
- **Test (the contamination guard):** assert a splice's result **equals `lab_engine` on the same config** (the addon contributed storage/recipe only, not math).

### D5 — SimpleDungeons → set-pieces (ADR-014)
- Prefab-room procedural assembly for authored occult set-pieces (boss lairs, ritual sites), behind the **same `WorldGenerator` facade**; **seeded + persisted**. Composes with WFC (WFC = organic fill, SimpleDungeons = authored rooms).

### D6 — Wire the LimboConsole parity probes
- Now that the engines exist, **fully wire** the `parity_battle` / `parity_splice` commands stubbed in Cluster 1 — run the GDScript engine, dump a result hash, diff against the Python golden vectors (TDD §11.2).

## 3. Guardrails (non-negotiable — this cluster is where they matter most)
- **ADR-015 — addons never own outcome math.** `LabBench` routes splice execution to `lab_engine`; inventory only stores; OctoD only presents; the CSP only gates/resolves config. A test proves outcomes == the oracle.
- **ADR-016 — AI selects, the engine resolves.** Selection RNG = canonical sub-stream via Blackboard; never LimboAI/global RNG.
- **ADR-014 — generation seeded + persisted, not re-simulated.** Authored fallback on solver failure.
- **Nothing in `client/domain/`.** CSP, worldgen, AI, inventory all live in `infrastructure/`/`application/`. The domain stays the pure, parity-tested oracle.
- **Every gameplay-affecting addition has a parity and/or replay test.** Seeded reproducibility holds across OS targets.
- Pinned versions recorded; CI green; ADRs 014–016 written into `docs/adr/`.

## 4. Definition of Done
1. **CombatBrain** drives a **deterministic** boss battle: same seed → identical transcript (replay test green, all OS runners); selection RNG is canonical-only (grep proves no `randf`/`randi`/LimboAI-RNG in the AI path).
2. **WorldGenerator** produces a seeded, **persisted**, valid region; reload yields the same layout; the authored fallback triggers on a forced solver failure.
3. **Lab Legality Engine**: `splice_rules.json` drives `LEGAL`/`ILLEGAL(reason)`/`TABOO(cost)` correctly; the 4 worked examples pass; commit routes to `lab_engine`; config persisted in `lineage`; **ruleset soundness + parity tests green**.
4. **Adapters**: inventory stores parts/kits; OctoD presents statuses; a test proves **a splice result == `lab_engine` on the same config** (no addon math).
5. **SimpleDungeons** set-piece generates seeded + persisted under `WorldGenerator`.
6. **LimboConsole** `parity_battle`/`parity_splice` wired and **green against the golden vectors**.
7. **Nothing added to `client/domain/`**; CI grep gate + all parity/replay tests green; ADRs 014–016 written.
8. `PHASE_Cluster4_REPORT.md` written. **STOP** — do not start Cluster 5.

## 5. Next
**Cluster 5:** Live2D premium portraits. For now: build Cluster 4 to the DoD and report. Treat the Lab Legality Engine (D3) as the centerpiece — it's the signature system; get its rules + parity exactly right.
