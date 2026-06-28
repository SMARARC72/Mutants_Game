# CLAUDE CODE — Mutants_Game · Integration Cluster 1: Dev/Ops + UX Shell (Execution Prompt)

> Run inside the `Mutants_Game` repo. This is the **first, lowest-risk integration cluster** from `docs/Mutants_Game_Integrations.md` Part C. It adds **presentation- and dev-layer** components only — **nothing here touches `client/domain/`, the oracle, or determinism.** Build to the Definition of Done, then **stop and report**.

---

## 0. Orientation & authority
- **Normative:** `docs/Mutants_Game_TechnicalDesign.md` (TDD). **Integration contract:** `docs/Mutants_Game_Integrations.md` (P1–P6 + §A3, §B5, §B6). Honor both. Deviations → an ADR in `docs/adr/`.
- **Prime directive:** the Python-ported engines are the oracle; everything here wraps *around* the game. **Do not add anything to `client/domain/`** — the CI grep gate must stay green.
- **Each component is reached only through a thin facade** we own (named below). Addon types never cross a layer boundary.

## 1. Scope — eight components, two sub-clusters

**Dev/Ops:** gdtoolkit · sentry-godot · LimboConsole.
**UX shell:** G.U.I.D.E · Maaack's Game Template · ThemeGen · NotificationEngine · EasyTransition.

All 🟢 MIT. Vendor pinned under `client/addons/` (or wire as a dev tool where noted); record each in `client/addons/THIRD_PARTY.md` (name, version/commit, source URL, license); retain LICENSE files. No CC-BY here, so no new `CREDITS.md` entries.

## 2. Deliverables

### D1 — gdtoolkit (lint + format) → pre-commit + CI
- Add `gdtoolkit` (`pip install gdtoolkit==4.*`) to the dev toolchain. Wire **`gdformat`** + **`gdlint`** into a **pre-commit hook** and the **CI lint job** (TDD §15 already calls for this; make it real). Runs without the Godot binary.
- Add a `gdlintrc`/format config; format the existing `client/` GDScript once (under VCS).
- **Acceptance:** CI fails on a lint error / unformatted file; `gdformat --check client/` is green.

### D2 — sentry-godot → crash + error reporting (self-hosted, opt-in, no PII)
- Vendor sentry-godot (Godot 4.5+; we're 4.7). Configure a **self-hostable** DSN via env (never hard-coded). **Opt-in only**; **no PII** — attach `run.seed`, the save header, and the build version (D-cluster never sends email/account).
- Behind a `CrashReporter` facade (`infrastructure/ops/`): `init(consent:bool)`, `add_breadcrumb()`, `capture(error)`.
- **Acceptance:** a forced test error appears in the dashboard with seed+build attached; with consent off, nothing is sent.

### D3 — LimboConsole → dev-only console (ADR-018)
- Vendor LimboConsole. Gate it behind a **`DEV_TOOLS` feature flag** — **compiled out / disabled in release builds**; backtick toggle in dev.
- Register the **state-poke** commands now: `set_seed`, `set_corruption`, `set_morality`, `give_creature`, `grant_gear`, `unlock_region`.
- **Stub** the **parity-probe** commands (`parity_battle`, `parity_splice`) with a clear `# TODO: wire when the ported engines land (Phase 1–2)` — they call the GDScript engines + dump a result hash to diff against the Python golden vectors (TDD §11.2). Wire fully when those engines exist; do not block this cluster on them.
- **Acceptance:** console toggles in a dev build, state-poke commands work, parity stubs are present + documented; the console is absent/disabled in a release export.

### D4 — G.U.I.D.E → input with contexts
- Vendor G.U.I.D.E. Define **input contexts**: `Menu`, `Overworld`, `Battle`, `Lab` — each a mapping set; runtime rebinding; KB+mouse+gamepad.
- Behind an `InputMap` facade (`infrastructure/input/`): the app/presentation layers request **actions** (`action_pressed("confirm")`), **never raw keys**. Context switches on screen transitions.
- **Acceptance:** all four contexts exist; rebinding persists (via the settings, D5); a gamepad drives menus + a test battle action.

### D5 — Maaack's Game Template → menus & settings backbone
- Install Maaack's Game Template as the **main/pause/options menus + loading screens + persistent settings + credits** shell. Wire its **settings** (audio/video/keybinds) to our `Settings` autoload and to G.U.I.D.E rebinding (D4).
- Keep its menus **themed by ThemeGen** (D6), not its default theme.
- **Acceptance:** main→options→back, pause menu, and a loading transition all work; settings persist across restart (data-only JSON, ADR-012 — not a Resource save).

### D6 — ThemeGen → the grimoire `Theme`
- Use ThemeGen to author the **grimoire UI `Theme` in code** from the Claude design system (`/design`): semantic colors = the **6-force palette + parchment/ink**, StyleBoxes, light/dark, fonts (the OFL blackletter/serif). One `Theme` resource consumed by **all** Control nodes.
- Keep it **colorblind-safe** (color **+** icon/shape — pair with the game-icons set when present).
- **Acceptance:** a sample screen (menu + a panel + buttons) renders in the grimoire theme; swapping a semantic color updates everywhere.

### D7 — NotificationEngine → toasts
- Vendor NotificationEngine behind a `Toast` facade (`presentation/`): `Toast.show({title, body, icon, sound})`, stacking, survives scene changes.
- Seed the funny-grim microcopy for the core events: creature caught, part harvested, awakening, quest update, rival approaches, corruption rising.
- **Acceptance:** a toast fires from a test trigger, themed (D6), with a sound; stacks correctly.

### D8 — EasyTransition → ritual scene transitions
- Vendor EasyTransition behind a `Transition` facade. Implement the **overworld↔battle ritual transition** + a **threaded-load cover** (`await`) so loads feel "ritual but fast" (design §4), replacing flat loading screens.
- **Acceptance:** a scripted overworld→battle→overworld round-trip uses the transition with no visible pop/hitch.

### D9 — Repo hygiene + wiring
- Enable all addons in `project.godot`. Update `client/addons/THIRD_PARTY.md`. Confirm `.gitignore`/`.gitattributes` keep addon-internal assets tracked (per the existing setup) and `client/reports/` (GdUnit4) ignored.
- **Acceptance:** project opens headless in Godot 4.7 with **zero addon errors** (`godot --headless --quit` clean).

## 3. Guardrails (non-negotiable)
- **Nothing in `client/domain/`.** All eight are `infrastructure/`, `application/`, `presentation/`, or dev-only. CI grep gate stays green.
- **Facades only:** `InputMap`, `CrashReporter`, `Toast`, `Transition`, plus the menu/theme integration — addon types don't leak across layers.
- **Determinism untouched:** none of these feed gameplay outcomes. (LimboConsole's parity probes, when wired, *read* the engines; they never become a source of truth.)
- **Privacy:** sentry is opt-in, self-hostable, no PII. Save stays **versioned JSON** (ADR-012) — no Resource/.tres saves via Maaack's or anything else.
- **Pinned versions** recorded; secrets (Sentry DSN) via env, never committed; secret-scan stays green.
- **Scope:** this cluster only. No engine port, no gameplay/mechanics addons (LimboAI, constraint-solving, inventory — later clusters), no creature content.

## 4. Definition of Done (all true)
1. gdtoolkit pre-commit + CI lint/format gate live and green; `client/` formatted.
2. sentry-godot reports a test error (seed+build attached); silent when consent off.
3. LimboConsole works in dev, gated out of release; state-pokes functional; parity probes stubbed + documented.
4. G.U.I.D.E: four input contexts + rebinding + gamepad; app uses actions not keys.
5. Maaack's menus/settings/loading work; settings persist as JSON; themed by ThemeGen.
6. ThemeGen grimoire `Theme` drives a sample screen; one source of semantic colors.
7. NotificationEngine toasts fire, themed, with sound; EasyTransition handles overworld↔battle.
8. Project opens headless with zero addon errors; THIRD_PARTY.md updated; CI green.
9. **Nothing added to `client/domain/`.**
10. `PHASE_Cluster1_REPORT.md` written (what was added, where, how to verify locally, any deviations w/ ADR links). **STOP** — do not start Cluster 2.

## 5. What comes next (context only)
**Cluster 2 (content):** godot-csv-data-importer. **Cluster 3 (narrative):** Dialogic + inkgd + Quest. **Cluster 4 (mechanics):** LimboAI (`CombatBrain`), godot-constraint-solving (`WorldGenerator` + the `LabBench` legality engine per `docs/Mutants_Game_SpliceRules.md`), expressobits inventory + OctoD (parity-safe adapters), SimpleDungeons. **Cluster 5:** Live2D portraits. Each gets its own prompt. For now: build Cluster 1 to the DoD and report.
