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

## Local modifications (4.7 compatibility)

- **Dialogic** `Modules/Variable/subsystem_variables.gd` — added `return null` to the two `_get()`
  overrides (lines ~187 and ~249). Godot 4.7's stricter compiler rejects "not all code paths return
  a value"; `_get` returning `null` (= property not handled) is the correct, upstream-safe fix. This is
  the only change to vendored code; without it Dialogic fails to compile on 4.7.

- **inkgd** `editor/import_plugins/ink_json_import_plugin.gd` — `_get_recognized_extensions()` now
  returns `["inkjson"]` instead of `["json"]`. Upstream claims the generic `.json` extension, which
  makes the importer attempt EVERY `.json` in the project (`catalog/*.json`, `tests/*.json`) and flag
  the non-ink ones as failed imports. Restricting it to a dedicated `.inkjson` extension leaves plain
  data `.json` files untouched. Compiled stories are therefore named `<name>.inkjson` (ADR-017).

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

`godot --headless --path client --import` + the GdUnit4 CLI run the project with all five addons
enabled; the sample suite (`client/tests/example_test.gd`) passes 3/3 with 0 errors. gdUnit4 self-skips
its *editor* plugin in a test environment (expected). `.uid`/`.import` files are committed so UIDs
resolve on a clean clone.
