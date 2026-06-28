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
| **G.U.I.D.E** | tag `v0.13.0` (`addons/guide`) | MIT | https://github.com/godotneers/G.U.I.D.E | Unified input + contexts + runtime rebinding + gamepad — behind the `InputService` facade (D4) |
| **LimboConsole** | tag `v0.8.0` (`addons/limbo_console`) | MIT | https://github.com/limbonaut/limbo_console | Dev-only in-game console (state pokes + parity probes) — behind the `DevConsole` facade, gated by DEV_TOOLS (D3, ADR-018) |
| **Maaack's Game Template** | tag `v1.4.6` (`addons/maaacks_game_template`) | MIT | https://github.com/Maaack/Godot-Game-Template | Menu/settings/loading backbone (base components). Demo `media/` + `docs/` trimmed (unused at runtime). Editor *installer* plugin NOT enabled (our screens use its `base/` directly). (D5) |
| **sentry-godot** | tag `2.0.0` (`addons/sentry`, GDScript layer only) | MIT | https://github.com/getsentry/sentry-godot | Crash/error reporting — behind the `CrashReporter` facade (D2). Native GDExtension binaries are NOT committed (see `addons/sentry/bin/.gitignore`); the facade detects the `SentrySDK` singleton at runtime and no-ops when absent. |

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
