# PHASE 0.5 — Resource Integration · Report

**Status:** ✅ Core complete — six (+ Wave-B) building blocks acquired, placed, licensed, threaded into
the plan, and verified in Godot 4.7. A few **bulk/gated asset downloads are flagged** (manual steps below).
**Branch:** `phase-0.5-resources` → PR into `phase-0-foundations` (stacked on the Phase 0 PR).
**Scope discipline:** dependencies + assets only — no game logic, no engine port, no screens.
**Nothing was added to `client/domain/`** (the determinism boundary holds; CI enforces it).

---

## What was added & where

### Vendored addons (pinned, committed) — `client/addons/`
| Addon | Version | License | Autoload(s) |
|---|---|---|---|
| Supabase | `v3.3.0` | MIT | `Supabase` |
| Dialogic | `2.0-alpha-19` | MIT | `Dialogic` |
| gdUnit4 (**primary** test framework) | `v6.1.3` | MIT | — |
| Beehave | `v2.9.2` | MIT | `BeehaveGlobalMetrics`, `BeehaveGlobalDebugger` |
| Phantom Camera | `v0.11.0.2` | MIT | `PhantomCameraManager` |

Recorded in `client/addons/THIRD_PARTY.md`; enabled in `client/project.godot` (`[editor_plugins]` +
`[autoload]`, explicit `res://` paths). **One vendored-code change:** a 2-line Godot-4.7 compat patch to
Dialogic (`subsystem_variables.gd` `_get` → `return null`); without it Dialogic won't compile on 4.7.

### Assets
- **Icons:** 28 curated **game-icons.net** SVGs (CC BY 3.0) → `client/assets/icons/{forces,verbs,statuses,currencies,gear}/`, renamed to domain terms. Every one attributed in repo-root **`CREDITS.md`**.
- **Shaders:** 3 project-authored **CC0** starters (`hit_flash`, `outline`, `dissolve`) → `client/presentation/shaders/`.
- **Asset dirs** (`ui`, `tiles`, `particles`, `audio/sfx`) created with `PROVENANCE.md` documenting the CC0/curated policy + the manual download steps for the bulk packs.

### References (cloned OUTSIDE the repo, NOT committed) — `../_reference/`
- **GDQuest Open-RPG** (MIT) → `../_reference/godot-open-rpg`
- **fenix-hub/supabase-examples** (MIT) → `../_reference/supabase-examples`
- Mapped to our modules/phases in **`docs/Open-RPG_Pattern_Map.md`** (patterns only; never into `domain/`).

### Docs
`ADR-013` (dependency + asset policy + Beehave RNG rule), `docs/Open-RPG_Pattern_Map.md`, updated
`docs/Mutants_Game_Resources.md` (integration status), this report.

### Repo hygiene
`.gitignore` no longer blanket-ignores `*.png`/`*.wav` (that wrongly excluded addons + curated assets);
it ignores the **bulk dirs** (`/art/`, `/assets/`) instead. `.gitattributes` LFS patterns route committed
binaries (addon PNGs, curated assets) to **Git LFS** (verified `git check-attr filter <png>` → `lfs`), so
no multi-MB blob lands in base history. `.uid`/`.import` files are committed (Godot 4.4+) so UIDs resolve
on a clean clone.

---

## Verification (Godot 4.7, headless)

```bash
GODOT=<Godot_v4.7-stable_console>
$GODOT --headless --path client --import                                  # all 5 addons load, 0 errors
$GODOT --headless --path client -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --add res://tests --ignoreHeadlessMode --continue
# -> 7 test cases | 0 errors | 0 failures (3 suites):
#    example_test (sanity + generated Constants load + BALANCE sections)
#    dialogic_smoke_test (Dialogic autoload present + smoke.dtl imports/loads as DialogicTimeline)
#    assets_test (3 CC0 shaders compile + 6 force icons import as Texture2D)
```
gdUnit4 self-skips its *editor* plugin in a test environment (expected). CI runs the same via the new
**`godot-tests`** job (chickensoft setup-godot 4.7.0). The lint job gained a **domain-purity gate** (TDD §3.1).

## Deferred hooks (what each resource wires into, and when)
- Supabase addon → DAL repositories + auth flow (**Phase 3**), Storage/gen (**Phase 4**).
- Open-RPG patterns → battle controller (**Phase 2**), overworld grid/movement + Phantom Camera (**Phase 5**).
- Dialogic → NPC dialogue/encounters (**Phase 5**). Beehave → battle/NPC AI (**Phase 2/5**, canonical-RNG rule).
- Icons/shaders/Kenney → UI + juice art pass (**Phase 5**). GdUnit4 → parity suites (**Phase 1–2**).

## Blockers / flagged (not auto-fetched — manual steps)
These are **bulk or gated** downloads; the structure + `PROVENANCE.md` are in place, the curated subsets are pending:
1. **Sonniss GameAudioGDC** — tens of GB behind a download form. Manual: download the current-year bundle to
   `../_asset-library/sonniss/` (local only), then copy ≤10 clips into `client/assets/audio/sfx/` (LFS).
2. **Full Kenney library** (UI/tiles/particles) — large. Manual: download packs to `../_asset-library/kenney/`,
   copy curated subsets into `client/assets/{ui,tiles,particles}/` (LFS).
3. **OpenGameArt tileset** — mixed-license. Manual: pick ONE **verified-CC0** dark-fantasy tileset →
   `client/assets/tiles/` (record license; CC-BY → `CREDITS.md`).

## STOP
Phase 0.5 core is complete and verified. **Phase 1 (determinism core) is not started.**
