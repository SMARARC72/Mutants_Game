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
| **Beehave** | tag `v2.9.2` (`addons/beehave`) | MIT | https://github.com/bitbrain/beehave | **Wired (W13)** — the overworld's ambient critters (`presentation/overworld/overworld_critters.gd`) each run a real `BeehaveTree` (`SequenceComposite[Idle -> Wander]`), so the addon is genuinely exercised; battle AI remains the self-contained `application/ai` kernel (see below). The two runtime autoloads (`BeehaveGlobalMetrics`/`BeehaveGlobalDebugger`) are re-registered in `project.godot` because `BeehaveTree._ready` hard-requires them; the EDITOR plugin stays disabled (no debugger tab needed — W2 hygiene, red-team C15). Determinism note below still binds: critters roll a LOCAL rng only. **Local patch:** `debug/debugger_messages.gd` `can_send_message()` additionally requires `EngineDebugger.is_active()` (upstream v2.9.2 spams "Can't send message. No active debugger" on every headless/CLI run). |
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

## Cluster 4 — WorldGenerator (D2 WFC) + set-pieces (D5): NOT vendored (self-contained), ADR-019

**`godot-constraint-solving` (🟢 MIT, WFC2D) and SimpleDungeons (🟢 MIT) were evaluated and
deliberately NOT vendored for `WorldGenerator`.** Unlike the D3 CSP (whose self-contained choice was
about API *shape*), the D2/D5 choice is about **determinism**: ADR-019 requires generation to be
seeded by the **canonical PCG32 sub-stream** `canonical_rng(run.seed, region_id)` so a region is
bit-identical across OS targets and reloads (parity/replay, ADR-001).

| Library | Why not vendored as-is |
|---|---|
| `godot-constraint-solving` `WFC2DGenerator` (rel. 1.7, Oct 2024) | Correct *purpose* (WFC2D over `TileMapLayer`, backtracking, multithreaded) but its collapse draws from Godot's `RandomNumberGenerator`, which is **not bit-identical to our canonical PCG32** across platforms. Satisfying ADR-019's seeding would require forking its RNG core; it is also a `Node`-based generator (scene-tree coupled), whereas our facade is a pure `RefCounted` producing plain-data. Godot is not installable in this build env to verify a clean 4.7 vendor. |
| SimpleDungeons | Runtime scene/Node graph (rooms-as-PackedScenes, a generator Node) with its own RNG — same canonical-seeding mismatch, same can't-verify-4.7 constraint. |

We therefore ship small, self-contained, **parity-irrelevant** generation cores driven by the
canonical RNG, behind one facade (ADR-019 / Integrations §A1.2/§B4):

| Component | File | Role |
|---|---|---|
| `WorldGenerator` | `infrastructure/worldgen/world_generator.gd` | facade `generate(region_id, seed) -> Layout`; canonical sub-stream, WorkerThreadPool path, authored fallback, persist-to-`world_state`/reuse-on-load |
| `WfcSolver` | `infrastructure/worldgen/wfc_solver.gd` | deterministic Wave-Function-Collapse 2D (observe/propagate + chronological backtracking + attempt limit); the `WFC2DGenerator` job |
| `DungeonAssembler` | `infrastructure/worldgen/dungeon_assembler.gd` | SimpleDungeons role — prefab set-piece room stitching (footprint + tile stamp), seeded |
| `RegionRules` | `infrastructure/worldgen/region_rules.gd` | loader for `res://catalog/region_layouts.json` (tile palette, WFC adjacency, set-piece specs per region) |
| `Layout` | `infrastructure/worldgen/layout.gd` | plain-data tile grid + rooms + metadata; versioned-JSON serialization (ADR-012) |

These compute **no outcome math** (Cluster 4 §3): they lay out tiles; the domain oracle stays the
single source of gameplay numbers. **Better Terrain** autotiling is a render-time cosmetic seam over
the persisted grid (documented in `world_generator.gd`), not vendored — it adds no traversability-
changing tile, so the persisted `Layout` remains canonical. If a future need arises to vendor the
upstream WFC addon for its editor tooling, the facade is the only file that would change.
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
## Cluster 4 — Inventory + ability/status adapters (D4): expressobits + OctoD (self-contained)

**expressobits/inventory-system (🟢 MIT) and OctoD godot-gameplay-systems (🟢 MIT) were evaluated
and NOT vendored as runtime addons for D4.** The brief permits a self-contained fallback when a lib
"doesn't fit cleanly on 4.7 … the adapter contract matters more than the lib." Both decisions follow
the same precedent as the D3 CSP solver above, for two reasons specific to D4:

1. **ADR-015 (the prime directive): addons never own outcome math.** Both libraries ship their OWN
   gameplay math — expressobits computes a crafted OUTPUT item from a recipe; OctoD computes
   attribute/buff/ability VALUES. In Mutants_Game the oracle (`client/domain/lab_engine.gd`,
   `status_engine.gd`, `skill_engine.gd`) is the SOLE source of every number. Adopting either
   library's math would create a second source of truth and break parity (TDD §6). We therefore adopt
   each only for its STRUCTURE/STORAGE/CONTAINER role behind a thin adapter, computing nothing.
2. **Godot is not installable in this environment**, so a 4.7 vendor cannot be smoke-tested here
   (`godot --headless --import`) — the same blocker recorded for the CSP solver. Shipping a small,
   self-contained, parity-irrelevant adapter that fulfils the SAME contract is lower-risk than
   committing an unverified vendor. The adapter seam is documented in each file so the upstream addon
   can be dropped in later WITHOUT touching callers (ADR-015 P3: swap an addon = reimplement one facade).

| Component | File | Role (the contract) |
|---|---|---|
| `InventoryItem` | `infrastructure/inventory/inventory_item.gd` | data-only item DTO (categories = Lab ingredient types + run items); maps expressobits ItemDefinition/ItemStack → versioned-JSON, never `.tres` (ADR-012) |
| `InventoryAdapter` | `infrastructure/inventory/inventory_adapter.gd` | the parts/kits/consumables/vials inventory facade — add / stack / consume / query + `to_dict`/`load_from`. The ONLY file callers touch; expressobits `Inventory` would back it 1:1 |
| `LabRecipe` | `infrastructure/inventory/lab_recipe.gd` | the recipe REPRESENTATION (op + creature inputs + ingredient ids + method) the expressobits crafting GRAPH authors. Stores inputs only; computes no output |
| `LabRecipeBench` | `application/lab/lab_recipe_bench.gd` | wires inventory + recipe → `LabBench` → `lab_engine`; debits the inventory by `splice_config["consumed"]` ONLY on a LEGAL commit, AFTER the oracle ran. The creature is `lab_engine`'s verbatim |
| `StatusContainer` | `application/status/status_container.gd` | OctoD-style buff/debuff effect-container SHELL; delegates apply/tick/cleanse/corruption to `status_engine` and reads back state. Owns no number |
| `AbilityContainer` | `application/status/ability_container.gd` | OctoD-style ability-container SHELL; delegates damage/support/act to `skill_engine`. Owns no number |

**The contamination boundary (ADR-015 / DoD item 4):** `inventory_contamination_guard_test.gd` proves a
splice driven through inventory → `LabRecipeBench` → `LabBench` yields a creature EQUAL field-for-field to
`LabEngine.fuse(...)` on the same config + seed — the inventory/recipe contributed storage + recipe
representation only, NOT a single number. `status_ability_shell_test.gd` proves the OctoD shells reflect
`status_engine`/`skill_engine` values exactly. The upstream URLs (for a future runtime vendor):
expressobits https://github.com/expressobits/inventory-system · OctoD https://github.com/OctoD/godot-gameplay-systems.

## Local modifications (4.7 compatibility)

- **Dialogic** `Modules/Variable/subsystem_variables.gd` — added `return null` to the two `_get()`
  overrides (lines ~187 and ~249). Godot 4.7's stricter compiler rejects "not all code paths return
  a value"; `_get` returning `null` (= property not handled) is the correct, upstream-safe fix.
  Without it Dialogic fails to compile on 4.7.
- **Dialogic** `Modules/Text/node_name_label.gd` — added the missing `return false` fall-through to
  the `_set()` override (W16a). Same 4.7 strictness as above (the native `_set` contract infers a
  `bool` return): without it the script fails to parse, which cascades into
  `Layer_VN_Textbox/vn_textbox_layer.gd` ("Failed to compile depended scripts" — it types a var as
  `DialogicNode_NameLabel`) and would kill the grimoire dialogue style's textbox layer at runtime.
  `false` = property not handled, the documented `_set` semantic; upstream-safe.
- **Dialogic** runtime cache teardown — `DialogicGameHandler._exit_tree()` now clears the static
  event/style caches and the `SceneTree` indexer metadata. Its generated subsystem accessors now
  preload scripts for static typing without constructing hidden, unparented nodes. Upstream retained
  26 resources plus 60 objects on every clean exit; the ownership-safe accessors release them all.
- **Supabase Auth** `Auth/auth.gd` + `auth_task.gd` — anonymous sign-in now performs the real GoTrue
  `POST /auth/v1/signup` request and installs its JWT instead of fabricating a user from the public
  anon key. An unused, unparented `Timer` initializer was also removed, eliminating the last clean-
  exit ObjectDB leak.
- **Questify** `quest_manager.gd` — the autoload clears runtime quest-instance roots during tree
  teardown. Quest resources contain cyclic graph references, so retaining the manager array until
  script shutdown kept the complete six-script model graph alive in windowed runs.
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
  The editor story panel also stops its delayed recompile callback when its `SceneTree` has already
  begun teardown, preventing a null-tree coroutine error after failed or cancelled exports.

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
complete suite passes **612/612** test cases across 101 suites, including the Cluster 1 facade + runtime
integration suites (`cluster1_ux_shell_test.gd`, `cluster1_devtools_input_test.gd`). gdUnit4
self-skips its *editor* plugin in a test environment (expected). `.uid`/`.import` files are committed
so UIDs resolve on a clean clone.
