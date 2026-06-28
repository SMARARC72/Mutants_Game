# ADR-018 — LimboConsole is dev-build-only (DEV_TOOLS flag); never in a release build

**Status:** Accepted (Integrations §A3, Part C) · **Phase:** Integration Cluster 1 (Dev/Ops + UX)

## Context
LimboConsole gives us an in-game dev console: state-poke commands (`set_seed`, `set_corruption`,
`set_morality`, `give_creature`, `grant_gear`, `unlock_region`) and the high-value oracle
parity-probe commands (`parity_battle`, `parity_splice`, TDD §11.2). These can set arbitrary run
state and read the deterministic engines — powerful for triaging parity bugs, but a cheat/abuse
surface and a confusing artefact if shipped to players.

## Decision
The dev console and **all** its commands are **dev-builds only** and **compiled out / hard-disabled
in a release export**. The gate is a `DEV_TOOLS` feature flag, implemented by
`presentation/devtools/dev_console.gd::is_dev_build()` as `OS.is_debug_build() or
OS.has_feature("dev_tools")`. In a release build the `DevConsole` autoload registers nothing and
the backtick toggle is inert. LimboConsole also ships an `EditorExportPlugin` that strips console
code from non-debug exports; we keep its plugin enabled so that stripping is active.

The console NEVER becomes a source of truth: the parity probes only *read* the GDScript engines
(client/domain) and dump a hash to diff against the Python golden vectors. State pokes route
through a dev-only `DevState` shim today and will call the real run-state services when they land
(Phase 1-2/3) — the command signatures stay identical.

LimboConsole types never cross a layer boundary: the only file that references them is the
`DevConsole` facade (presentation/devtools).

## Consequences
- Dev/playtest builds get a fast manual counterpart to the automated parity gate.
- Release builds are clean and tamper-resistant; no console, no pokes.
- The parity-probe commands are STUBBED with a `# TODO: wire when the ported engines land
  (Phase 1-2)` until the GDScript engines exist; wiring them does not change this ADR.
