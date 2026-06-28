# Mutants_Game — Integration Design (adopted open-source)

**Status:** design — to implement on the Visual Elevation / mechanics tracks · **Date:** 2026-06-27 · APIs + licenses web-verified. License key per `Mutants_Game_Resources.md`.
**Companion:** `Mutants_Game_TechnicalDesign.md` (normative; this doc extends it), `Mutants_Game_OpenSource_Expansion.md` (the catalog these were chosen from).

> **Prime directive.** The **Python-ported engines are the oracle** and `client/domain/` is pure + deterministic. Every component here wraps *around* that core — it provides shell (storage, UI, AI selection, authoring, dev-tooling, generation), **never the outcome math**. If an addon wants to compute a stat, a damage number, a splice result, or a capture chance, that call routes to the oracle instead. This is the line that keeps determinism + parity (TDD §6) intact.

---

## 0. Cross-cutting integration principles

| # | Principle |
|---|---|
| **P1 — Oracle owns outcomes** | Stats, damage, splice results, capture/breed odds, leveling, morality = the ported engines (`stat/level/lab/battle/skill/status/loot/character`). Addons never duplicate this math. |
| **P2 — Never in `domain/`** | Addons live in `infrastructure/` (plumbing/generation), `application/` (orchestration/AI), or `presentation/` (UI). The CI grep gate (TDD §3.1) already fails any addon import inside `domain/`. |
| **P3 — Adapter/facade per addon** | Wrap each third-party API behind a thin **our-interface** (`WorldGenerator`, `CombatBrain`, `LabBench`, `QuestService`, `PortraitView`, `InputMap`, `Toast`). Addon types never cross a layer boundary; swapping an addon = reimplement one facade. |
| **P4 — Determinism** | Anything affecting gameplay outcomes or replayability is **seeded from `run.seed` via a canonical-RNG sub-stream** (ADR-001) **and its output persisted** to the save — so it reproduces without re-running cross-platform. **AI *selects*, the engine *resolves*; selection randomness uses the canonical RNG.** |
| **P5 — Persistence** | Addon-owned run state serializes into the **versioned-JSON save** (ADR-012), data-only. **No `Resource`/`.tres`/`.res` saves** (code-exec risk + ADR conflict) — map addon Resources to our DTOs. |
| **P6 — License** | All adopted = **MIT/CC0** except **Live2D** (free-tier, revenue-gated) and game-icons (CC-BY). Vendor pinned under `client/addons/`, record in `client/addons/THIRD_PARTY.md`, retain LICENSE, credit CC-BY in `CREDITS.md`. |

**Layer placement at a glance:**

| Layer | Components |
|---|---|
| `infrastructure/` | godot-constraint-solving (worldgen + Lab legality), SimpleDungeons, godot-csv-data-importer (import-time), sentry-godot, Supabase addon |
| `application/` | LimboAI (combat brains), QuestService, LabBench, narrative orchestration |
| `presentation/` | Maaack's, G.U.I.D.E, ThemeGen, NotificationEngine, EasyTransition, Dialogic, inkgd (render), Live2D portraits, LimboConsole (dev only) |
| dev/CI (no runtime) | gdtoolkit, GdUnit4 |

---

# Part A — Deep designs

## A1. Constraint-solving → the Lab Legality Engine **+** world generation (`godot-constraint-solving`, 🟢 MIT)

One addon, two distinct uses. It ships a **generic CSP solver with backtracking** (guaranteed-valid or clean failure) with **WFC built on top**, multithreaded, TileMapLayer/GridMap support.

### A1.1 The Lab Legality & Recombination Engine (the novel use)
**Problem it solves:** today splice legality is implicit. We want **rule-driven, guaranteed-valid recombination** — "this force × that organ × this method is legal; that one is taboo-gated; pick a valid trait resolution when several exist."

**Design — and the parity boundary (read carefully):**
- The **generic CSP** decides **(a) legality** and **(b) which legal configuration** results (forces, organ slots, trait flags, tier) when multiple are valid.
- The **stat/genome OUTCOME is still computed by the ported `lab_engine`** (oracle). The CSP constrains the *input/trait space*; `lab_engine` computes the *numbers*. **The CSP is a legality filter, not outcome math** — so parity is untouched.
- **Variables** = the result's trait/organ/force slots. **Domains** = allowed values. **Constraints** = the splice rules (force compatibility, organ legality, taboo gates, tier ceilings) authored as **data** (`res://catalog/splice_rules.tres` / a JSON ruleset), not code — designers add rules without touching GDScript.
- **Determinism:** the solver is seeded by `canonical_rng(run.seed, op_id)`; when it must choose among valid configs it uses that stream. The **chosen configuration is persisted** (`creature_instances.lineage` + a `splice_config` blob). `lab_engine` then runs on that config → the result is fully reproducible.
- **Server re-validation (Succession):** persist the chosen config so the server re-runs **`lab_engine`** on it — the CSP need not re-run. (The CSP is a client-side legality/authoring aid, not part of the oracle.)
- **UX payoff:** a botched/illegal splice returns a clean "no legal recombination" the Lab UI can surface (dread microcopy), instead of producing garbage.

**Facade:** `LabBench.preview(a, b, ingredients, method)` → CSP legality + candidate configs → on commit, `canonical_rng` picks → `lab_engine.fuse(config, rng)` → persist. The addon lives behind `infrastructure/lab/legality_solver.gd`.

### A1.2 Overworld / dungeon generation (WFC)
- **WFC2D** over `TileMapLayer` generates region layouts **once per run**, seeded by `canonical_rng(run.seed, region_id)`; the **output (tile layout / room graph) is persisted to `world_state`** and never regenerated on load (**ADR-014**).
- **Backtracking ON** (guaranteed-valid) with an **attempt limit + fallback to a hand-authored layout** if it fails (no soft-lock).
- Runs on a **`WorkerThreadPool`** task (addon supports multithreading) → no frame hitch.
- Composes with **SimpleDungeons** (B4): WFC fills organic biome/connective tissue; SimpleDungeons stitches authored set-piece rooms. Both behind one `WorldGenerator` facade in `infrastructure/worldgen/`.
- **Better Terrain** (lighting/depth doc) autotiles the WFC output so it reads hand-laid.

## A2. LimboAI → the Succession boss AI + creature/NPC brains (🟢 MIT)

LimboAI gives **Behavior Trees + Hierarchical State Machines** with a visual editor, **Blackboard** data exchange (`BBInt/BBBool/BBNode…`), custom tasks via `_tick` (extend `BTAction/BTCondition/…`), and HSM states via `LimboState` (`_enter/_exit/_update`). Placement: `application/ai/`.

### The determinism rule (ADR-016) — non-negotiable
In battle, **any randomness in AI action selection draws from the injected canonical RNG sub-stream** (handed in via the Blackboard, e.g. a `BBNode` pointing at the `RngService`), **never LimboAI's own helpers or global `randf`/`randi`**. The AI **selects** an action; the **oracle (`battle_engine`/`skill_engine`) resolves** it. This keeps full-battle replay + server re-validation valid (TDD §6).

### The Succession invasion boss (the showcase)
- An **HSM (`LimboState`)** defines **phases** — e.g. *Opening → Pressure → Desperation → Apotheosis* — each phase a **Behavior Tree** selecting moves from the boss's snapshot kit.
- **Phase transitions** are Blackboard-gated: own HP%, turn count, squad losses, the entropy clock.
- The boss is driven by the imported **`god_snapshot`** (forces, kit, signature moves, grid-god identity) → loaded into the Blackboard. So *your ascended champion* fights with *authored, readable, designer-tunable* phase logic — debuggable in LimboAI's visual debugger. This turns the Succession from a stat-swap into a feature.

### Creature + NPC brains
- **Battle creatures:** lightweight BTs per role (aggressor / support / controller) reading the same Blackboard; same canonical-RNG rule.
- **Overworld NPCs:** free-running BTs/HSM (not simulation — no determinism constraint): schedules, reactions to your corruption/notoriety (design §3.5).

**Facade:** `CombatBrain.choose_action(battle_state, rng) -> Action` (our interface), implemented by LimboAI. The battle controller calls it, passes the canonical RNG, gets a chosen action, resolves via the oracle. Swapping back to Beehave = reimplement `CombatBrain`.

## A3. LimboConsole → dev console + the **oracle-parity probe** (🟢 MIT)

- **Placement:** `presentation/`, **dev-builds ONLY** — compiled out / hard-disabled in release behind a `DEV_TOOLS` feature flag (**ADR-018**). Backtick toggle.
- **Command set** (`register_command`):
  - **State pokes:** `give_creature <id>`, `set_corruption <n>`, `set_seed <n>`, `set_morality <oc> <pc>`, `unlock_region <id>`, `grant_gear <slot> <id>`.
  - **Sim/parity probes (the high-value bit):** `parity_battle <seed> <teamA> <teamB>` runs the GDScript `battle_engine` and dumps the transcript + a result hash; `parity_splice <a> <b> <method> <seed>` runs `lab_engine`. Diff these live against the **Python oracle's golden vectors** (TDD §11.2) to reproduce + triage parity bugs in seconds.
  - **`.lcs` scripts** for repeatable test setups (seed a known run, jump to the boss, etc.).
- It's the **manual counterpart to the automated parity gate** — the fastest path to trustworthy determinism during the playtest sprint.

---

# Part B — Integration specs

## B1. Gameplay substrates — OctoD gameplay-systems + expressobits/inventory (parity-safe, **ADR-015**)

**The risk:** both ship their *own* attributes/abilities/crafting **math** — which must NOT become a second source of truth competing with the oracle.

**The rule — adopt for structure, storage, and UX only:**
- **expressobits/inventory-system** (🟢 MIT) → the **parts/kits/consumables/vials inventory** (items-as-Resources, grid UI, stacks) **and** its **crafting GRAPH as a recipe-authoring/representation layer** for Lab ops. The **execution** of any Lab operation calls `lab_engine` (oracle) via the `LabBench` facade (A1.1) — the addon only *holds ingredients* and *renders the recipe*. It never computes the spliced creature.
- **OctoD godot-gameplay-systems** (🟢 MIT) → reference architecture + (optionally) its **buff/debuff & ability *container* nodes** as a presentation/scheduling shell for statuses/skills. The numbers come from `status_engine`/`skill_engine`. Adopt selectively behind adapters; treat mostly as a pattern source.
- **Persistence:** inventory/run state → versioned-JSON save; map their Resources → our DTOs (don't serialize their `.tres` — ADR-012).

## B2. Narrative — inkgd + Quest complementing Dialogic (**ADR-017**)

**The split:**
- **Dialogic 2** (🟢 MIT) = authored **conversations, encounters, the absurdist + 4th-wall beats, VN scenes** (timelines, portraits).
- **Ink via inkgd** (🟢 MIT) = **sprawling, variable-driven branching lore/quest narrative** where node-graphs get unwieldy. Compiled `.json` as `InkResource` → `InkPlayer.create_story()` → `continue_story()`.
- **Quest system** (quest-system, 🟢 MIT — Resource-driven to match our data approach) = the **objective/state tracker**.

**The bridge (concrete):**
- Ink **`bind_external_function("has_creature", self, "_has_creature")`** etc. exposes game queries to stories (`corruption()`, `faction_standing(f)`, `owns(id)`).
- Ink **variable observers** (signal-based) push story decisions → our **`QuestService`** + world state.
- **Quest + Ink story state persist in the versioned-JSON save** (data-only).
- Dialogic can **render** Ink-driven lines where we want VN presentation (Ink decides *what*, Dialogic decides *how it looks*).
- Quests gate **Lab unlocks, capture targets, Succession triggers** by reading/writing run state through `QuestService` — never touching `domain/`.

## B3. Content pipeline — godot-csv-data-importer (aligns **ADR-006**)

- The creature registry CSV (1,000+) is the **single catalog source** (ADR-006). `godot-csv-data-importer` (🟢 MIT) turns it into typed **client-side species Resources** at import-time; the **same CSV** seeds Postgres via the existing `gen_seed` pipeline. **One source → two consumers** (client bundle + DB mirror) — no divergence.
- Add a **CI schema-lint** that the CSV columns match the species contract, so the importer and the Postgres seed can't drift.

## B4. World set-pieces — SimpleDungeons (🟢 MIT, *verify build*)

- Prefab-room procedural assembly for **authored occult set-piece dungeons** (boss lairs, ritual sites). Composes with WFC (A1.2): WFC = organic fill; SimpleDungeons = hand-crafted rooms stitched per run. **Seeded + persisted** (ADR-014), behind the same `WorldGenerator` facade.

## B5. UX shell — Maaack's + G.U.I.D.E + ThemeGen + NotificationEngine + EasyTransition (all 🟢 MIT, presentation)

| Component | Role | Integration |
|---|---|---|
| **Maaack's Game Template** | main/pause/options menus, loading screens, persistent settings, credits | The menu/settings backbone; wire its settings to our `Settings` autoload. |
| **G.U.I.D.E** | all input + runtime rebinding + gamepad | **Input contexts**: `Menu / Overworld / Battle / Lab`. The app layer asks for **actions**, never raw keys. Rebinding lives in the options menu. |
| **ThemeGen** | the **grimoire `Theme`** in code | Semantic colors = the **6-force palette + parchment/ink** from the Claude design system; one `Theme` consumed by all Control nodes (colorblind-safe color+icon). |
| **NotificationEngine** | toasts | "creature caught / part harvested / awakening / quest update / rival approaches / corruption rising" — funny-grim microcopy. |
| **EasyTransition** | scene transitions | The **ritual overworld↔battle transition** + threaded-load cover (`await`) — the "ritual but fast" feel (design §4), replacing flat loading screens. |

All consume the design system; none touch `domain/`.

## B6. Dev / Ops — gdtoolkit + sentry-godot (🟢 MIT)

- **gdtoolkit** (gdlint + gdformat) → **pre-commit hook + CI gate** (TDD §15 already specifies it); runs without the Godot binary; `gdformat` rewrites under VCS.
- **sentry-godot** (Godot 4.5+; we're on 4.7) → **crash + GDScript-error reporting**, **self-hosted** (privacy), **opt-in**, **no PII** — attach the **seed + save header + build version**, never email/account. Dev + playtest builds; consent-gated in release. The crash backbone for a clean playtest sprint (and it pairs with the determinism work: a crash report's seed reproduces the bug exactly).

## B7. Premium visual — Live2D via gd_cubism (🟡 free-tier, confirmed adopt)

- Confirmed: no sales, not listing → **free tier is clear**. gd_cubism (MIT plugin) + Cubism free tier.
- Use for **living-portrait god/boss reveals + creature-soul dossier close-ups only** — wrapped in a **`PortraitView`** facade that **falls back to a static image** if Live2D is absent, so it's fully modular/swappable. Re-evaluate the SDK license at the ¥10M/~$67k revenue threshold. Presentation-only.

---

# Part C — ADRs, sequencing, Definition of Done

## New ADRs (write into `docs/adr/`)
- **ADR-014** Procedural generation is **seeded (canonical RNG) + output persisted**, never re-simulated per load; failure falls back to an authored layout.
- **ADR-015** Third-party gameplay addons **never own outcome math** — the oracle does; addons provide storage/UX/containers behind adapters.
- **ADR-016** **AI selects, the deterministic engine resolves**; AI selection randomness uses the canonical RNG sub-stream (via Blackboard), never the addon's/global RNG.
- **ADR-017** Narrative split: **Dialogic = scenes, Ink = lore/branching, Quest = state**; all narrative/quest state in the versioned-JSON save; Ink↔game via external functions + variable observers.
- **ADR-018** **LimboConsole is dev-build-only** (DEV_TOOLS flag); never enabled in a release build.

## Suggested dependency order (lowest-risk first)
1. **Dev/ops:** gdtoolkit (pre-commit/CI) · LimboConsole (dev console + parity probes) · sentry-godot.
2. **UX shell:** G.U.I.D.E (+ input contexts) · Maaack's · ThemeGen (the grimoire theme) · NotificationEngine · EasyTransition.
3. **Content:** godot-csv-data-importer (the 1,000-creature pipeline).
4. **Narrative:** Dialogic + inkgd + Quest (the bridge).
5. **Mechanics:** LimboAI (CombatBrain) · godot-constraint-solving (WorldGenerator + LabBench legality) · expressobits inventory + OctoD containers (behind adapters) · SimpleDungeons.
6. **Premium:** Live2D portraits.

## Definition of Done (per adoption — the gate)
- Vendored **pinned** under `client/addons/` (or `infrastructure/` for generation libs), recorded in `client/addons/THIRD_PARTY.md`; LICENSE retained; CC-BY in `CREDITS.md`.
- Reached **only through its facade** (`WorldGenerator`/`CombatBrain`/`LabBench`/`QuestService`/`PortraitView`/`InputMap`/`Toast`); addon types don't cross layers.
- **Nothing added to `client/domain/`**; the CI grep gate passes.
- Any gameplay-affecting use is **seeded + persisted** and routes outcomes to the **oracle**; a parity/replay test covers it where applicable.
- A **smoke test** proves it loads + works headless in Godot 4.7; CI green.
- Its ADR (014–018) is written where one applies.

*Build each behind its facade in a branch, prove it, keep it only if it earns its place — the oracle and determinism are never negotiable.*

