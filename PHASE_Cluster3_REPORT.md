# Integration Cluster 3 — Narrative & Quests · Report

**Status:** Complete. Dialogic confirmed loading; inkgd + Questify vendored, patched for Godot 4.7,
and smoke-tested; the `QuestService` facade + Ink↔game bridge + Dialogic/Ink split built; a sample
vertical proves the whole seam end-to-end with save→reload→state-intact.
**Branch:** `cluster-3-narrative`.
**Authority:** `docs/Claude_Code_Cluster3_Narrative.md`, `Mutants_Game_Integrations.md` §B2 (ADR-017).
**Nothing was added to `client/domain/`** — the determinism boundary holds (CI grep gate stays green).

---

## The split (ADR-017): Dialogic renders · Ink decides · Quest tracks

| System | Job | Layer / facade |
|---|---|---|
| **Dialogic 2** (already vendored) | Renders VN scenes/portraits + the funny-grim, rare-4th-wall beats | `presentation/narrative/dialogic_facade.gd` |
| **inkgd** (vendored) | Decides the branch: variable-driven lore, reading run state | `infrastructure/narrative/ink_facade.gd` |
| **Questify** (vendored) | Tracks objectives/completion (Resource-driven) | `infrastructure/narrative/quest_tracker_facade.gd` → `application/narrative/quest_service.gd` |

Rule, documented in `docs/narrative_pipeline.md`: **Ink decides *what*, Dialogic decides *how it
looks*, Quest owns *the state*** — and **narrative never computes gameplay outcomes** (only
gates/triggers via `QuestService`).

## Deliverables

### D1 — `QuestService` facade — `application/narrative/quest_service.gd`
`start / advance / complete / is_active / is_done / state`. Reads + writes **run state**
(`NarrativeRunState`: corruption, unlocks, captures, owned creatures, region access, faction
standing) to **trigger** (data `trigger` predicates) and **gate** (data `on_complete` effects:
`unlock_region`, `grant_creature`, `mark_captured`, `set_flag`, `add_corruption`, `nudge_standing`).
It computes **no** stats/damage/splice math — it only flips narrative flags, in one auditable place.
Quest + run state persist to the versioned-JSON save (ADR-012), data-only.

### D2 — Ink↔game bridge (the only coupling) — `application/narrative/ink_bridge.gd`
Loads a compiled `.inkjson` via `InkPlayer.create_story()` → `continue_story()` (through
`InkFacade`). `bind_external_function` exposes the read-only queries
`has_creature / owns / corruption / faction_standing / region_unlocked`. Signal-based variable
observers push Ink decisions → `QuestService` (the `quest_<id>_start/_advance/_complete` convention).
The Ink story state (`InkPlayer.get_state()`) round-trips into the JSON save alongside quest state.

### D3 — Dialogic↔Ink presentation split — `docs/narrative_pipeline.md`
Documents who authors what + the flow diagram + how to add a new beat. Ink hands a timeline name to
the Dialogic facade where a line needs VN presentation; the facade is display-guarded so playback
no-ops headless while the flow still completes.

### D4 — Sample vertical (proof) — `application/narrative/narrative_vertical.gd`
"Rust Marsh Omen": an Ink lore branch (`presentation/narrative/stories/rust_marsh_omen.ink` →
compiled `.inkjson`) with an external `region_unlocked` / `has_creature` query → a Dialogic
encounter (`presentation/dialogue/marsh_encounter.dtl`, funny-grim, a rare 4th-wall beat where the
Bog-Wretch clocks the player character) → a quest that **gates real run state** (unlocks region
`rust_marsh`, sets `lab_op_unlocked:necropsy`, marks `bog_wretch` captured). Save → reload → state
intact, asserted by tests.

## Vendored addons (pinned)

| Addon | Pin | License | Notes |
|---|---|---|---|
| **inkgd** | branch `godot4` @ `fea9098e…` (plugin `0.6.0`) | MIT | Godot-4 port lives on a branch (no release tag); `mono/` removed. |
| **Questify** | tag `1.6.0` @ `819ea797…` | MIT | `Questify.cs` + editor-only translation-parser addon removed. |

Recorded in `client/addons/THIRD_PARTY.md`; LICENSE files retained (both MIT → no CREDITS entry
needed). Enabled in `client/project.godot` (`[editor_plugins]` + autoloads `Questify`, `__InkRuntime`,
all re-asserted to `res://` after `--import` rewrote them to `uid://`).

### Compat patches (Godot 4.7 / project fit — minimal, documented)
1. **inkgd JSON importer** → recognizes a dedicated `.inkjson` extension instead of generic `.json`,
   so it stops claiming `catalog/*.json` + `tests/*.json` and flagging them as failed imports.
2. **inkgd editor plugin** → guards the stale `__InkRuntime` autoload removal on `_exit_tree`.

## Guardrails honored
- Narrative gates/triggers only via `QuestService`; **nothing computes gameplay outcomes**.
- Addons reached **only** through facades (infra `ink_facade`/`quest_tracker_facade`, presentation
  `dialogic_facade`); no addon type crosses a layer boundary. `application/narrative/` imports **no**
  `res://addons` directly.
- **Nothing in `client/domain/`** (CI purity gate replica run: clean).
- Save = **versioned JSON** (ADR-012), data-only; no `Resource`/`.tres` save.

## Verification (all run in-worktree, Godot 4.7)
- **Headless import** (clean `.godot`, two passes): **0** SCRIPT ERROR / Parse Error / addon-load /
  import errors (only benign engine-exit RID/ObjectDB leak warnings). Catalog/test `.json` untouched.
- **gdformat + gdlint**: clean on all 10 new `.gd` files (project `gdlintrc` applies).
- **gdUnit4 full suite**: **38 test cases, 0 failures, 0 errors** — including the pre-existing parity
  suites (proving the importer patch didn't regress JSON data loading) and the new
  `tests/quest_service_persistence_test.gd` (5) + `tests/narrative_vertical_test.gd` (2).
- **secret scan** (`tools/secret_scan.sh`): clean.

## Files added
```
client/application/narrative/{run_state,quest_service,narrative_save,ink_bridge,narrative_vertical}.gd
client/infrastructure/narrative/{ink_facade,quest_tracker_facade}.gd
client/presentation/narrative/dialogic_facade.gd
client/presentation/narrative/stories/rust_marsh_omen.ink (+ compiled .inkjson)
client/presentation/dialogue/marsh_encounter.dtl
client/tests/{quest_service_persistence,narrative_vertical}_test.gd
client/addons/{inkgd,questify}/...   (vendored, pinned)
docs/narrative_pipeline.md · docs/adr/0017-narrative-split-dialogic-ink-quest.md
```

## STOP
Cluster 3 is complete to the DoD. Per the spec: **do not start Cluster 4** (mechanics — LimboAI,
constraint-solving, inventory, SimpleDungeons), which depends on the ported GDScript engines.
