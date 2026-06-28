# PHASE REPORT — Integration Cluster 1: Dev/Ops + UX Shell

**Branch:** `cluster-1-devops-ux` · **Engine:** Godot 4.7-stable · **Spec:** `docs/Claude_Code_Cluster1_DevOps_UX.md` (D1–D10), `docs/Mutants_Game_Integrations.md` §A3/§B5/§B6.

This cluster adds **presentation- and dev-layer** components only. **Nothing was added to
`client/domain/`** — the oracle/determinism boundary is untouched and the CI grep gate stays green.

---

## What was added — and where

### Facades (the only files that touch each addon)
| Facade | File | Wraps (addon / role) | DoD |
|---|---|---|---|
| `InputService` (autoload) | `client/infrastructure/input/input_service.gd` | **G.U.I.D.E** | D4 |
| `InputActions` | `client/infrastructure/input/input_actions.gd` | action/context vocabulary (no addon types) | D4 |
| `CrashReporter` | `client/infrastructure/ops/crash_reporter.gd` | **sentry-godot** | D2 |
| `Toast` (autoload) | `client/presentation/ui/toast/toast.gd` | NotificationEngine role | D7 |
| `ToastMicrocopy` | `client/presentation/ui/toast/toast_microcopy.gd` | funny-grim copy for the 6 core events | D7 |
| `Transition` (autoload) | `client/presentation/ui/transition/transition.gd` | EasyTransition role | D8 |
| `GrimoirePalette` / `GrimoireTheme` | `client/presentation/ui/theme/grimoire_palette.gd`, `grimoire_theme.gd` | ThemeGen role (Theme in code) | D6 |
| `ThemeService` (autoload) | `client/autoload/theme_service.gd` | owns the one Theme | D6 |
| `Settings` (autoload) | `client/autoload/settings.gd` | versioned-JSON settings (ADR-012) | D5 |
| `DevConsole` (autoload) | `client/presentation/devtools/dev_console.gd` | **LimboConsole** (DEV_TOOLS-gated) | D3 |
| `DevState` | `client/presentation/devtools/dev_state.gd` | dev-only poke target | D3 |

### Screens (proof the shell wires together)
- `client/presentation/screens/main_menu.{gd,tscn}` — themed main menu; Play/Options run the **ritual + threaded-load** transition (D5/D8). **Main scene** of the project.
- `client/presentation/screens/options_menu.{gd,tscn}` — themed options wired to `Settings` (JSON) + G.U.I.D.E rebinding via `InputService` (D5/D4).
- `client/presentation/screens/sample_grimoire_screen.{gd,tscn}` — the sample screen (menu + panel + buttons) in the grimoire theme; fires a themed toast with sound; runs a transition (D6/D7/D8 acceptance).

### Vendored addons (pinned; `client/addons/THIRD_PARTY.md` updated, LICENSE files retained)
| Addon | Pinned | License | Source |
|---|---|---|---|
| G.U.I.D.E | `v0.13.0` | MIT | github.com/godotneers/G.U.I.D.E |
| LimboConsole | `v0.8.0` | MIT | github.com/limbonaut/limbo_console |
| Maaack's Game Template | `v1.4.6` | MIT | github.com/Maaack/Godot-Game-Template |
| sentry-godot (GDScript layer only) | `2.0.0` | MIT | github.com/getsentry/sentry-godot |

### Dev/Ops + ADRs + tests
- **D1 gdtoolkit:** `.pre-commit-config.yaml` (gdtoolkit `4.3.4` gdformat+gdlint) + a portable `tools/hooks/pre-commit`. CI lint job already globs `client/**/*.gd` (minus addons + generated constants); `gdformat --check` is green on all 41 hand-written files.
- **ADR-018** `docs/adr/0018-limboconsole-dev-only.md` (+ indexed in `docs/adr/README.md`).
- Tests: `client/tests/cluster1_ux_shell_test.gd` (10) + `client/tests/cluster1_devtools_input_test.gd` (4).

---

## How each Definition-of-Done item is met

1. **gdtoolkit gate live + `client/` formatted** — pre-commit config + hook added; `gdformat --check` + `gdlint` pass on all 41 hand-written `.gd` (CI mirror command).
2. **sentry-godot opt-in, no PII, seed+build attached** — `CrashReporter.init(consent, seed, save_header, build_version)`: silent unless `consent==true` **and** a `SENTRY_DSN` env var is set; PII keys (email/account/name/…) are stripped from context; seed + non-PII save header + build version attached. Tests `test_crash_reporter_silent_without_consent`, `test_crash_reporter_attaches_seed_and_strips_pii`.
3. **LimboConsole dev-only, pokes work, parity stubbed** — `DevConsole.is_dev_build()` (debug build OR `dev_tools` feature) gates registration; LimboConsole's export plugin strips it from release. All 6 state-pokes + 2 parity stubs register (runtime test confirms `has_command` for all 8). Parity probes carry `# TODO: wire when the ported engines land (Phase 1-2)`.
4. **G.U.I.D.E: four contexts + rebinding + gamepad; actions not keys** — `InputActions` defines Menu/Overworld/Battle/Lab + default KB **and** gamepad bindings; `InputService` builds the GUIDE contexts, switches them, and rebinds (persisted as JSON via `Settings`, ADR-012). Tests switch all 4 contexts + rebind→persist.
5. **Maaack menus/settings/loading; JSON settings; ThemeGen-themed** — main→options→back via the ritual transition; `Settings` round-trips as versioned JSON (test); options sliders/toggles/keybinds write to `Settings`/`InputService`; all screens use `ThemeService` (not Maaack's default theme).
6. **ThemeGen grimoire Theme drives a sample screen; one colour source** — `GrimoireTheme.build()` authors one `Theme` from `GrimoirePalette` (6-force + parchment/ink + corruption rot); `ThemeService` is the single source consumed by every Control; swapping a palette colour + `ThemeService.rebuild()` re-themes everything. Colorblind-safe (colour **+** icon/border-brightness).
7. **Toasts fire themed + with sound + stack; EasyTransition overworld↔battle** — `Toast.event(...)` fires funny-grim copy, themed, with a procedural sound; stacking capped + verified (test `test_toast_fires_and_stacks`). `Transition.ritual()` / `change_scene_ritual()` cover→threaded-load→reveal (test `test_transition_ritual_runs_and_clears_busy`).
8. **Zero addon errors headless; THIRD_PARTY.md updated; CI green** — `godot --headless --path client --import` → **0** SCRIPT/Parse errors; lint + secret-scan + domain-purity all green; 45/45 GdUnit4 cases pass.
9. **Nothing added to `client/domain/`** — confirmed (`git diff` shows no domain changes; purity grep clean).
10. **This report written.** Cluster 2 NOT started.

---

## How to verify locally

```sh
GODOT="…/Godot_v4.7-stable_win64_console.exe"

# 1) Zero-error headless import (ignore "no main scene" is N/A — main scene is set)
"$GODOT" --headless --path client --import        # expect 0 SCRIPT ERROR / Parse Error

# 2) Lint/format gate (mirrors CI)
GD=$(git ls-files 'client/**/*.gd' | grep -v '^client/addons/' | grep -v '^client/domain/constants.gd')
gdformat --check $GD && gdlint $GD                 # both green

# 3) Test suite (45/45)
"$GODOT" --headless --path client -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
  --add res://tests --ignoreHeadlessMode --continue

# 4) Run the shell (themed menu → ritual transition → sample screen → toast)
"$GODOT" --path client                             # main_menu.tscn boots

# 5) Guardrails
bash tools/secret_scan.sh                          # clean
```

Dev console: in a debug build press **backtick (`)** to toggle; try `set_seed 1234`, `give_creature gaia_brute_001`, `parity_battle 1 a b` (stub).

Sentry (optional, real reporting): drop the pinned native binaries into `client/addons/sentry/bin/`, rename `sentry.gdextension.template`→`sentry.gdextension`, `export SENTRY_DSN=<self-hosted>`, call `CrashReporter.init(true, run_seed, save_header, build)`.

---

## Deviations & notes (for the integrator)

- **NotificationEngine / EasyTransition / ThemeGen are realised as facades with a self-contained backend**, not vendored runtime addons. Rationale: the spec emphasises the *facade contract* (`Toast.show`, `Transition.ritual`, the grimoire `Theme` **authored in code**), and clean pinned Godot-4.7 builds of these specific community addons were not reliably retrievable in-worktree. Each facade file documents the exact swap-in seam; the app calls only `Toast`/`Transition`/`ThemeService`, so dropping in an upstream addon later touches one file and no callers. **If the integrator wants the named addons vendored, only the facade backends change — no DoD-visible behaviour does.**
- **sentry-godot native binaries are not committed** (`client/addons/sentry/bin/.gitignore`); a `.gdextension` pointing at missing per-platform libs would error headless. The `CrashReporter` facade detects the `SentrySDK` singleton at runtime and no-ops when absent — so the project imports clean everywhere and reporting "just works" once a dev drops the libs in. The descriptor is vendored as `sentry.gdextension.template`.
- **Maaack's editor *installer* plugin is intentionally NOT enabled** (it pops an interactive copy dialog and isn't headless-safe). We consume its `base/` components via our own themed screens; its demo `media/`+`docs/` were trimmed (unused at runtime). The runtime menu/settings/loading DoD is met by our screens wired to `Settings`+`InputService`+`Transition`.
- **Rebinding persists as JSON via `Settings`, not as a `GUIDERemappingConfig` Resource** — to honour ADR-012 (no Resource deserialization). `InputService` serialises remaps to `{action: {device, code}}` and rebuilds GUIDE inputs from that on load.
- **Autoloads re-asserted to `res://`** in `project.godot` after import (Godot rewrites them to `uid://` on `--import`, per the environment note).
