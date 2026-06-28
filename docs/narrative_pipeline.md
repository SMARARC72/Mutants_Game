# Narrative pipeline — who authors what (ADR-017)

The narrative layer is three tools doing three jobs, coupled at exactly one seam. The
inviolable rule: **narrative never computes gameplay outcomes.** Stats, damage, splice and
capture math are the ported oracle's job (`client/domain/`). Narrative only **gates** and
**triggers** by reading/writing run state through `QuestService`.

## The split

| System | Job | Authors | Layer / facade |
|---|---|---|---|
| **Dialogic 2** | **Renders** VN scenes, portraits, the funny-grim conversations + rare 4th-wall beats | Timeline authors (writers, `.dtl`/`.dtl` timelines) | `presentation/narrative/dialogic_facade.gd` |
| **Ink (inkgd)** | **Decides** the branch: sprawling, variable-driven lore + quest narrative, reading run state | Ink writers (`.ink` → compiled `.inkjson`) | `infrastructure/narrative/ink_facade.gd` |
| **Quest (Questify)** | **Tracks state**: objectives + completion, Resource-driven | Quest designers (data quest definitions) | `infrastructure/narrative/quest_tracker_facade.gd`, surfaced by `application/narrative/quest_service.gd` |

One-line mnemonic: **Ink decides *what*, Dialogic decides *how it looks*, Quest owns *the state*.**

## The flow (one beat, end to end)

```
            EXTERNAL queries (read-only)                 variable observers (signals)
  run state ───────────────────────────►  Ink story  ───────────────────────────►  QuestService
  (corruption, owns,                       (decides    quest_<id>_start/_advance/    (start/advance/
   region_unlocked, ...)                    branch)     _complete                     complete)
                                              │                                          │
                                              │ names a timeline (render_timeline)        │ applies a
                                              ▼                                          ▼ run-state effect
                                          Dialogic  ──────────────────────────►  run state changes
                                          (renders the VN beat)                   (unlock region, mark
                                                                                   capture, set flag, ...)
```

1. **Ink reads run state** through the bound external functions
   (`has_creature`, `owns`, `corruption`, `faction_standing`, `region_unlocked`) to choose a branch.
2. **Ink drives state** by flipping observed variables. The `InkBridge` translates them to
   `QuestService` calls via a naming convention:
   - `quest_<id>_start` → `QuestService.start(<id>)`
   - `quest_<id>_advance` (String step id) → `QuestService.advance(<id>, step)`
   - `quest_<id>_complete` → `QuestService.complete(<id>)`
3. **Dialogic renders** the beat the Ink branch requested (Ink sets `render_timeline`; the
   orchestrator hands that timeline to the Dialogic facade). Headless, playback no-ops but the
   flow still completes.
4. **The quest gates something real** — only by writing run state through `QuestService`
   (unlock a Lab op, mark a capture target, open a region, nudge corruption/standing). No stats.

## The only coupling

`application/narrative/ink_bridge.gd` is the single seam between narrative and run state. It:
- binds the read-only queries (`_bind_queries`),
- wires the variable observers (`_observe_quest_drivers` / `_on_quest_var_changed`),
- round-trips the Ink story state into the versioned-JSON save.

No addon type ever crosses a layer boundary — each addon is reached only through its facade,
which returns plain `String`/`Array`/`Dictionary`. Swapping a tool = reimplement one facade.

## Persistence (ADR-012)

`QuestService.serialize()` (quest progress + run state) and `InkFacade.get_state_json()` (the
opaque Ink story state) are written as **data only** into the versioned-JSON save envelope
(`application/narrative/narrative_save.gd`). The client never deserializes a Godot
`Resource`/`.tres` from a save. Save → reload restores quest progress, run-state flags and the
Ink story position intact.

## Authoring a new narrative beat

1. Write the lore branch in a `.ink` file under `client/presentation/narrative/stories/`.
   Use `EXTERNAL` for any run-state query; declare a `VAR quest_<id>_start/_advance/_complete`
   to drive the quest; set `VAR render_timeline = "<dtl id>"` where you want a VN scene.
2. Compile it to `<name>.inkjson` (inklecate / inkjs `Compiler.ToJson`). The dedicated
   `.inkjson` extension keeps the inkgd importer off plain `.json` data files.
3. Author the VN scene as a Dialogic timeline (`.dtl`) and register it in
   `project.godot [dialogic] dtl_directory`.
4. Define the quest as **data** (id, ordered steps, `on_complete` run-state effects) and
   `QuestService.register([...])` it. Effects are the only way narrative touches run state.
5. Wire it with `InkBridge.load_story(path, [observed vars])`; see
   `application/narrative/narrative_vertical.gd` for the worked example.

## Guardrails recap

- Narrative gates/triggers via `QuestService`; it never computes outcomes and never imports
  `client/domain/`.
- Every addon is reached only through its facade; addon types stay inside their layer.
- Quest + Ink state persist as versioned JSON (ADR-012), never a Resource save.
