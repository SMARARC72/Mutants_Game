# CLAUDE CODE — Mutants_Game · Integration Cluster 3: Narrative & Quests (Execution Prompt)

> Run inside the repo, **after Cluster 2**. Adds the **narrative + quest layer** (ADR-017): Dialogic for scenes, Ink for branching lore, a quest tracker for state — all wired so **narrative never computes gameplay outcomes**. Build to the DoD, then **stop and report**. Nothing here touches `client/domain/`.

## 0. Authority
- Normative: `Mutants_Game_TechnicalDesign.md` + `Mutants_Game_Integrations.md` §B2 (**ADR-017**). Design voice: the funny-grim, occult, rare-4th-wall tone (`Claude_Design_Handoff_Brief.md` §3.5). Deviations → ADR.

## 1. Scope — the narrative split
- **Dialogic 2** (🟢 MIT) — *already vendored in Phase 0.5*; confirm it loads. = authored **conversations, encounters, the absurdist + 4th-wall beats, VN scenes** (timelines).
- **inkgd** (🟢 MIT) — vendor. = **sprawling, variable-driven branching lore/quest narrative**. Compiled `.ink.json` as `InkResource` → `InkPlayer`.
- **quest-system** (🟢 MIT, Resource-driven, *verify build*) — vendor. = the **objective/state tracker**.

Vendor pinned under `client/addons/`; record in `THIRD_PARTY.md`.

## 2. Deliverables

### D1 — `QuestService` facade
`application/narrative/quest_service.gd`: `start(id)`, `advance(id, step)`, `complete(id)`, `is_active/!done(id)`, `state()`. It reads/writes **run state** (corruption, unlocks, captures, region access) to **trigger and gate** — it never computes stats. Quest state **persists to the versioned-JSON save** (data-only, ADR-012 — no `.tres` saves).

### D2 — Ink ↔ game bridge (the only coupling)
- Load a compiled `.ink.json` via `InkPlayer.create_story()` → `continue_story()`.
- **`bind_external_function`** exposes read-only game queries to stories: `has_creature(id)`, `corruption()`, `faction_standing(f)`, `owns(id)`, `region_unlocked(id)`.
- **Variable observers** (signal-based) push Ink decisions → `QuestService` + world state.
- Persist Ink story state (the `InkPlayer` state JSON) into the versioned-JSON save alongside quest state.

### D3 — Dialogic ↔ Ink presentation split
- Dialogic **renders** VN scenes/portraits; Ink **decides** branching content + drives state. Where a line needs VN presentation, Ink hands the text to a Dialogic timeline. Document the rule in a short `docs/narrative_pipeline.md` (which system authors what).

### D4 — Sample vertical (proof)
One end-to-end slice: an **Ink lore branch** (with an external-function query) → a **Dialogic encounter** (funny-grim, a rare 4th-wall beat) → a **quest** that **gates something real** (e.g., unlocks a Lab op or marks a capture target) by writing run state via `QuestService`. Save → reload → state intact.

## 3. Guardrails
- **Narrative never computes gameplay outcomes** (no stats, no damage, no splice math). It **gates/triggers** by reading/writing run state through `QuestService`.
- The **Ink↔game bridge is the only coupling** — via external functions + observers; no addon reaches into `domain/`.
- **Nothing in `client/domain/`**; all of this is `application/` + `presentation/`.
- **Save = versioned JSON** (ADR-012) — serialize quest + Ink state as data; never a Resource save.
- Pinned versions recorded; CI green; funny-grim microcopy throughout.

## 4. Definition of Done
1. Dialogic loads; inkgd + quest-system vendored + smoke-tested.
2. `QuestService` facade works; quest + Ink state **persist + reload** from the JSON save.
3. Ink `bind_external_function` queries + variable observers wired to `QuestService`/world state.
4. The sample vertical runs end-to-end (Ink branch → Dialogic scene → quest gate writes run state).
5. `docs/narrative_pipeline.md` documents the Dialogic/Ink/Quest split.
6. Nothing in `client/domain/`; project opens headless clean; CI green.
7. `PHASE_Cluster3_REPORT.md` written. **STOP** — do not start Cluster 4.

## 5. Next
**Cluster 4 (mechanics):** LimboAI + constraint-solving (incl. the Lab Legality Engine) + inventory adapters + SimpleDungeons — **requires the ported GDScript engines (post-Phase-2)**. For now: build Cluster 3 to the DoD and report.
