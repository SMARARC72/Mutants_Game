# Vendored addons — provenance & licenses (Phase 0.5, ADR-013)

All vendored at **pinned** versions (no floating `main`) so the build is reproducible. Each
retains its upstream license; all are permissive (🟢). Enabled in `client/project.godot`
(`[editor_plugins]` + `[autoload]`). The pure `client/domain/` layer must never reference any
of these (TDD §3.1 determinism boundary) — they are used from `infrastructure/`/`presentation/`.

| Addon | Version (pinned) | License | Source | Used for |
|---|---|---|---|---|
| **Supabase** | tag `v3.3.0` (`addons/supabase`) | MIT | https://github.com/supabase-community/godot-engine.supabase | Auth (anon-first, ADR-011), DB CRUD behind the DAL, Realtime, Storage |
| **Dialogic** | tag `2.0-alpha-19` (`addons/dialogic`) | MIT | https://github.com/dialogic-godot/dialogic | NPC dialogue, branching/absurdist encounters, 4th-wall beats |
| **gdUnit4** | tag `v6.1.3` (`addons/gdUnit4`) | MIT | https://github.com/MikeSchulze/gdUnit4 | **Primary** GDScript unit + parity test harness + CI runner (TDD §11) |
| **Beehave** | tag `v2.9.2` (`addons/beehave`) | MIT | https://github.com/bitbrain/beehave | Battle AI + overworld NPC behavior (behavior trees) |
| **Phantom Camera** | tag `v0.11.0.2` (`addons/phantom_camera`) | MIT | https://github.com/ramokz/phantom-camera | Overworld + battle camera (follow, framing, push-in juice) |
| **inkgd** | branch `godot4` @ commit `fea9098ee18d6cdbe9a5e25f8f0296bcdf0fd96a` (plugin.cfg `0.6.0`; `addons/inkgd`) | MIT | https://github.com/ephread/inkgd | Ink runtime — branching lore/quest narrative (ADR-017). *Pinned to the exact commit because the Godot-4 port lives on the `godot4` branch with no release tag; the `0.5.0` tag is the Godot-3 line.* `mono/` (C# variant) removed. |
| **Questify** | tag `1.6.0` @ commit `819ea79764da7861cce75d58b012600bd379fd19` (`addons/questify`) | MIT | https://github.com/TheWalruzz/godot-questify | Resource-driven quest/objective tracker (ADR-017). `Questify.cs` (C# variant) + the editor-only `quest_resource_translation_parser` POT addon removed. |
| **G.U.I.D.E** | tag `v0.13.0` (`addons/guide`) | MIT | https://github.com/godotneers/G.U.I.D.E | Unified input + contexts + runtime rebinding + gamepad — behind the `InputService` facade (D4) |
| **LimboConsole** | tag `v0.8.0` (`addons/limbo_console`) | MIT | https://github.com/limbonaut/limbo_console | Dev-only in-game console (state pokes + parity probes) — behind the `DevConsole` facade, gated by DEV_TOOLS (D3, ADR-018) |
| **Maaack's Game Template** | tag `v1.4.6` (`addons/maaacks_game_template`) | MIT | https://github.com/Maaack/Godot-Game-Template | Menu/settings/loading backbone (base components). Demo `media/` + `docs/` trimmed (unused at runtime). Editor *installer* plugin NOT enabled (our screens use its `base/` directly). (D5) |
| **sentry-godot** | tag `2.0.0` (`addons/sentry`, GDScript layer only) | MIT | https://github.com/getsentry/sentry-godot | Crash/error reporting — behind the `CrashReporter` facade (D2). Native GDExtension binaries are NOT committed (see `addons/sentry/bin/.gitignore`); the facade detects the `SentrySDK` singleton at runtime and no-ops when absent. |
| **CSV Data Importer** | tag `2.1` @ commit `cb6e945033f25459661af40633b31ed9cca65eca` (`plugin.cfg` reports `2.0`; `addons/csv-data-importer`) | MIT | https://github.com/timothyqiu/godot-csv-data-importer | In-editor import path for the creature registry → typed Resources (Cluster 2, ADR-006). The `examples/`, demo `project.godot`, and icons are NOT vendored (editor-import addon only). Behind the `SpeciesCatalog` facade; the build-time path is `tools/gen_species_db.mjs`. |

### Cluster 1 facades (the only files that touch these addons)
| Facade | File | Wraps |
|---|---|---|
| `InputService` (autoload) | `infrastructure/input/input_service.gd` | G.U.I.D.E |
| `CrashReporter` | `infrastructure/ops/crash_reporter.gd` | sentry-godot |
| `Toast` (autoload) | `presentation/ui/toast/toast.gd` | NotificationEngine role (self-contained backend; swap-in seam documented in-file) |
| `Transition` (autoload) | `presentation/ui/transition/transition.gd` | EasyTransition role (self-contained ritual + threaded-load cover) |
| `GrimoireTheme` / `ThemeService` | `presentation/ui/theme/*`, `autoload/theme_service.gd` | ThemeGen role (the grimoire `Theme` authored in code) |
| `DevConsole` (autoload) | `presentation/devtools/dev_console.gd` | LimboConsole |

**NotificationEngine / EasyTransition / ThemeGen note:** these three are realised as facades with
a self-contained backend rather than a vendored runtime addon — the spec (D6/D7/D8) emphasises the
*facade contract* (`Toast.show`, `Transition.ritual`, the grimoire `Theme` "authored in code"), and
each file documents the clean seam to drop in the upstream addon later without touching callers.

## Cluster 4 — Lab Legality Engine (D3): CSP solver NOT vendored (self-contained)

**godot-constraint-solving was evaluated and deliberately NOT vendored for the Lab Legality Engine.**
The Cluster 4 spec (D3) and `Mutants_Game_SpliceRules.md` §3 permit a self-contained GDScript CSP
"if `godot-constraint-solving` cannot be vendored cleanly for 4.7 ... the CSP semantics matter more
than the specific lib." That library's public surface is a **Wave-Function-Collapse tile solver**
(2D grid collapse over a `TileMapLayer`), not a **generic finite-domain CSP** with arbitrary
constraint predicates over named variables — which is exactly what SpliceRules §3 requires
(`force_intent` / `tier_target` / `class_target` / `trait_slots[]` / `flags` with five custom
rule-constraints). Forcing the WFC API into that shape would be more code and more risk than the
~70-line backtracking core we need, and (per the cluster constraints) Godot is not installable here
to verify a 4.7 vendor cleanly. We therefore ship a small, self-contained, parity-irrelevant
backtracking CSP solver:

| Component | File | Role |
|---|---|---|
| `CspSolver` | `infrastructure/lab/csp_solver.gd` | generic finite-domain CSP + chronological backtracking (no game/outcome math) |
| `LegalitySolver` | `infrastructure/lab/legality_solver.gd` | maps a Lab op → CSP per SpliceRules §3; verdict + candidate configs |
| `SpliceRules` | `infrastructure/lab/splice_rules.gd` | loader + schema validator for `res://catalog/splice_rules.json` |
| `LabBench` | `application/lab/lab_bench.gd` | preview/commit; routes commit to `client/domain/lab_engine.gd` (numbers) |

The CSP carries **no outcome math** (ADR-015): it gates legality + resolves ingredient/trait/flag
config + chooses among legal variants; `lab_engine` computes every number. The WFC use of
`godot-constraint-solving` for `WorldGenerator` (D2) is a separate, later deliverable and may still
vendor the addon for its actual (tile-collapse) purpose.

## Cluster 4 — CombatBrain (D1): LimboAI NOT vendored (self-contained BT/HSM)

**LimboAI was evaluated and deliberately NOT vendored for the CombatBrain.** The Cluster 4 spec (D1)
and `Mutants_Game_Integrations.md` §A2 permit a self-contained GDScript BT/HSM "if a clean 4.7 binary
can't be vendored here ... the SELECTION/determinism semantics matter more than the specific lib, same
precedent as the lab CSP." Two reasons:

1. **LimboAI ships a GDExtension (native binary).** A clean, verified Godot-4.7 build could not be
   vendored here (Godot is not installable in this environment to confirm the binary loads), and
   committing an unverifiable native blob would break the "build is reproducible / CI green on a clean
   clone" guarantee.
2. **The vendored Beehave (pure GDScript, already present) is the wrong shape for the in-loop kernel.**
   Beehave's `BeehaveTree` is a frame-ticked SceneTree `Node` (`set_physics_process` /
   `actor_node_path` / `tick_rate`) and ships **no HSM**. A per-turn, synchronous,
   replay-deterministic `choose_action()` needs a value-type tree it can run to completion in ONE
   headless call — not a node that ticks across frames. Beehave remains the right tool for
   free-running **overworld NPC** behaviour (its documented role), but not for the deterministic battle
   selection path.

We therefore ship a small, self-contained, synchronous, parity-irrelevant BT + HSM with the SAME
selection semantics (Selector/Sequence/Condition/Action; HSM phases with `_enter`/transition guards)
and the SAME Blackboard→RngService determinism rule (ADR-016):

| Component | File | Role |
|---|---|---|
| `RngService` | `application/ai/rng_service.gd` | the ONLY randomness source; wraps an injected CanonicalRNG sub-stream (ADR-016) |
| `AiBlackboard` | `application/ai/blackboard.gd` | data exchange + the BBNode→RngService handle (named `AiBlackboard` to avoid colliding with Beehave's `Blackboard`) |
| `BehaviorTree` | `application/ai/behavior_tree.gd` | synchronous BT kernel (Selector/Sequence/Condition/Action/Inverter) |
| `Hsm` | `application/ai/hsm.gd` | hierarchical state machine (LimboState-equivalent: states + blackboard-gated transitions) |
| `RoleBrains` | `application/ai/role_brains.gd` | aggressor / support / controller / neutral target-selection BTs |
| `SuccessionBoss` | `application/ai/succession_boss.gd` | Opening→Pressure→Desperation→Apotheosis HSM over the `god_snapshot` kit |
| `CombatBrain` | `application/ai/combat_brain.gd` | THE FACADE: `choose_action(battle_state, rng) -> Action` |
| `BattleController` | `application/battle/battle_controller.gd` | drives the turn loop; SELECTS via CombatBrain, RESOLVES via `client/domain/battle_engine.gd` |

The brain carries **no outcome math** (ADR-016): it SELECTS the target/offense; `BattleEngine.attack`
computes every number. `BattleEngine.simulate` is untouched and remains the auto/parity oracle. If a
clean 4.7 LimboAI binary becomes available, the swap is local: reimplement `CombatBrain` (the facade);
the controller and the determinism contract are unchanged.

## Local modifications (4.7 compatibility)

- **Dialogic** `Modules/Variable/subsystem_variables.gd` — added `return null` to the two `_get()`
  overrides (lines ~187 and ~249). Godot 4.7's stricter compiler rejects "not all code paths return
  a value"; `_get` returning `null` (= property not handled) is the correct, upstream-safe fix. This is
  the only change to vendored code; without it Dialogic fails to compile on 4.7.
- **Maaack's Game Template** — removed the demo `media/` (~4.5 MB) and `docs/` directories; neither is
  referenced at runtime by the `base/` components we use. No GDScript was modified.
- **sentry-godot** — only the addon's GDScript layer + descriptor template are vendored; native
  binaries are intentionally absent (re-fetched per build). The `CrashReporter` facade tolerates this.
- **G.U.I.D.E v0.13.0 / LimboConsole v0.8.0** — vendored unmodified; both compile clean on Godot 4.7.

- **inkgd** `editor/import_plugins/ink_json_import_plugin.gd` — `_get_recognized_extensions()` now
  returns `["inkjson"]` instead of `["json"]`. Upstream claims the generic `.json` extension, which
  makes the importer attempt EVERY `.json` in the project (`catalog/*.json`, `tests/*.json`) and flag
  the non-ink ones as failed imports. Restricting it to a dedicated `.inkjson` extension leaves plain
  data `.json` files untouched. Compiled stories are therefore named `<name>.inkjson` (ADR-017).

- **CSV Data Importer** `addons/csv-data-importer/import_plugin.gd` — `_get_recognized_extensions()`
  now returns `["csvdata"]` (not the generic `["csv", "tsv"]`) and `_get_priority()` is lowered to
  `1.0`. Upstream claims plain `.csv` at priority `2.0`, which OUTRANKS and hijacks Godot's built-in
  Translation importer — but the project ships a translation CSV
  (`addons/maaacks_game_template/base/translations/menus_translations.csv`) that must stay a
  translation. Restricting this importer to a dedicated `.csvdata` extension (mirrors the inkgd
  `.inkjson` precedent above) leaves all plain `.csv` files untouched. The creature registry itself
  lives at `docs/creature_registry.csv` (OUTSIDE `res://`) and is packed into the committed
  `res://catalog/species/species_db.tres` by `tools/gen_species_db.mjs` at build time. The upstream
  `examples/`, demo `project.godot`, and icons are not vendored (editor-import addon only).

- **inkgd** `editor/ink_editor_plugin.gd` — guarded `_remove_autoloads()` with
  `if ProjectSettings.has_setting("autoload/__InkRuntime")`. The 0.6.0 line no longer auto-registers
  that autoload, so removing it on `_exit_tree` raised "nonexistent project setting" during headless
  import teardown. (We register `__InkRuntime` ourselves in `project.godot`, the inkgd-recommended
  setup, so the runtime exists without a per-`InkPlayer` "Node not found" warning.)

## Determinism note (Beehave — critical, ADR-013)

Beehave may drive overworld NPC behavior freely, but **any AI decision that affects a battle outcome
MUST draw randomness from the injected canonical RNG sub-stream (ADR-001) — never Beehave's own
randomness or global `randf`/`randi`** — or full-battle replay/parity (TDD §6) breaks. Battle AI lives
in `application/` and *selects* actions; resolution stays in the deterministic `domain/`.

## Verification

`godot --headless --path client --import` runs the project with all enabled addons and ZERO
`SCRIPT ERROR` / `Parse Error` / addon-load errors (Integration Cluster 1, D9). The GdUnit4 CLI
suite passes **45/45** test cases across 14 suites, including the Cluster 1 facade + runtime
integration suites (`cluster1_ux_shell_test.gd`, `cluster1_devtools_input_test.gd`). gdUnit4
self-skips its *editor* plugin in a test environment (expected). `.uid`/`.import` files are committed
so UIDs resolve on a clean clone.
