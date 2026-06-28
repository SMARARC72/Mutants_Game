# ADR-017 — Narrative split: Dialogic renders, Ink decides, Quest tracks state

**Status:** Accepted (Integration Cluster 3) · **Normative:** `Mutants_Game_Integrations.md` §B2.
**Phase:** impl Cluster 3 (post-Cluster-2). **Depends on:** ADR-012 (versioned-JSON save), ADR-013
(vendored-addon + asset policy).

## Context
The game needs three distinct narrative capabilities that one tool does poorly alone:
authored visual-novel scenes/portraits + the absurdist 4th-wall beats; sprawling,
variable-driven branching lore where node-graphs get unwieldy; and an objective/state
tracker. Crucially, **narrative must never compute gameplay outcomes** — stats, damage,
splice/capture math are the ported oracle's job (`client/domain/`), and any narrative shortcut
into that math would break determinism + parity (TDD §6).

## Decision
Adopt a three-way split, each tool doing only what it is best at, coupled at exactly one seam:

- **Dialogic 2 RENDERS.** VN scenes, portraits, the funny-grim conversations + rare 4th-wall
  beats. Presentation layer. Reached through `presentation/narrative/dialogic_facade.gd`.
- **Ink (inkgd) DECIDES.** Branching lore/quest narrative + the run-state-aware decisions. A
  compiled `.inkjson` story is loaded via `InkPlayer`. Application layer, behind
  `infrastructure/narrative/ink_facade.gd`.
- **Quest (Questify) TRACKS STATE.** The objective/state tracker, Resource-driven, behind
  `infrastructure/narrative/quest_tracker_facade.gd`, surfaced to the game by the
  `QuestService` facade (`application/narrative/quest_service.gd`).

**The bridge is the only coupling** (`application/narrative/ink_bridge.gd`):
- Ink `bind_external_function` exposes **read-only** game queries to stories:
  `has_creature(id)`, `owns(id)`, `corruption()`, `faction_standing(f)`, `region_unlocked(id)`.
- Ink **variable observers** (signal-based) push story decisions out to `QuestService` + world
  state (the `quest_<id>_start/_advance/_complete` convention).
- Ink decides *what*; Dialogic decides *how it looks* (Ink names a timeline, the facade renders it).

**Gating, never math.** Quests gate Lab unlocks, capture targets, region access and Succession
triggers **only** by reading/writing run state through `QuestService` — they never touch
`client/domain/`. `QuestService` flips narrative-relevant flags (auditable, in one place); the
deterministic engines still resolve every number.

**Persistence (ADR-012).** Quest state **and** the Ink story state (`InkPlayer.get_state()` JSON
string) serialize into the versioned-JSON save as data only — never a Godot `Resource`/`.tres`.

## Consequences
- Swapping any one tool = reimplementing one facade; addon types never cross a layer boundary.
- The sample vertical (`application/narrative/narrative_vertical.gd`) proves the seam end-to-end:
  Ink lore branch (with an external query) → Dialogic encounter → quest gates run state → save →
  reload → state intact. Covered by `tests/quest_service_persistence_test.gd` +
  `tests/narrative_vertical_test.gd`.
- inkgd 0.6.0 (godot4 branch) required two minimal compat patches (recorded in
  `client/addons/THIRD_PARTY.md`): restrict the JSON importer to a dedicated `.inkjson`
  extension so it stops claiming every `.json`, and guard a stale `__InkRuntime` autoload removal.
- The pipeline rule (who authors what) is documented in `docs/narrative_pipeline.md`.
