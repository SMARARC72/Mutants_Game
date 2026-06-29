# Mutants_Game — Content Index & Canon Reconciliation

**The content feast — first pass.** Produced by a coordinated parallel sub-agent build against `Content_Generation_Brief.md`. This index lists every file, resolves the cross-agent canon flags with explicit **decisions**, and maps each file to the system that ingests it. **Date:** 2026-06-27.

---

## 1. What was produced

| File | Content | Volume |
|---|---|---|
| `creatures_wild_1.md` | wild creatures (batch3/4) — name + description | **89** |
| `creatures_wild_2.md` | wild creatures (S2 + batch5) | **131** |
| `creatures_legendary_construct.md` | legendary/god/primordial/construct creatures | **156** |
| `voice_library.md` | the funny-grim UI/NPC/notification/bark library | **314 lines** |
| `factions_npcs.md` | 9 faction leaders + 27 quest-givers + standing dialogue + 18 gated quests + NPC roster | **64 NPCs** |
| `story_quests.md` | the story — **6 acts**, branching quests that gate mechanics | **24 quests** |
| `pantheon_kits.md` | Succession boss kits + HSM phases (6 Primordials + 9 grid-gods + 10 Olympians) | **25 bosses** |
| `economy_items_rivals.md` | gear/consumables/parts + shop stocks + named nemeses | **80 items · 10 shops · 12 rivals** |
| `regions.md` | world regions — deep lore/inhabitants/set-pieces/biome rules | **11 regions** |
| `splice_rules.json` | the Lab Legality Engine ruleset (operations, trait-slots, ingredient library, CSP contract) | **~40 ingredients, 5 ops** |
| `splice_rules_notes.md` | 8 worked LEGAL/ILLEGAL/TABOO examples | — |

**Headline:** ~**376 creatures** named+described (registry naming gap effectively closed), a 64-NPC living cast, a 6-act story with 24 mechanic-gating quests, 25 boss fights, 11 regions, an 80-item economy, 12 rivals, a 314-line voice, and the Lab's legality ruleset authored.

## 2. Canon reconciliation — decisions (resolving the cross-agent flags)

These were flagged by the agents; resolved here so the parallel content is coherent. **Canonical source wins; the other is aligned at ingest.**

1. **Faction leaders/NPCs → `factions_npcs.md` is canonical.** `story_quests.md` invented divergent leader names to fill the (then-empty) people layer; **align story_quests' leader/NPC names to `factions_npcs.md` at ingest.**
2. **Titanfall's ruling god — UNRATIFIED.** `World.md`/`Factions.md` leave it "(a dead Titan)"; `regions.md` used provisional placeholders. **Action: ratify a name in a design pass** (the only open world-naming gap).
3. **Grid-god → force-vector mapping → adopt `pantheon_kits.md` as provisional canon.** `Character.md` left this "Open/next"; the boss-kit author assigned each of the 9 grid-gods a valid force-vector + Book05 seed. **Ratify in the systems session.**
4. **Currency symbols (₯/✶/◈) — provisional.** Invented for table density in `economy_items_rivals.md`; **ratify or replace with the design system's glyphs.**
5. **Gear-slot → boost mapping → adopt provisionally** (Relic→capture, Tool→lab, Vestment→combat, Charm→tame, Glyph→breed, per the economy author); confirm in the systems session vs `loot_engine`.
6. **Rival → Dead-God (DG-###) snapshot bindings — cross-check uniqueness** so no two rivals claim the same Book05 snapshot.
7. **Region overlap (canon-OK):** the **Revel** and **Bloomwardens** share the **Verdant Glut** (contested); Bloomwardens have no solo region. Intentional; no change.
8. **Creature data audit (non-blocking):** a few batch5 rows show art↔force label mismatches (e.g. batch5-007/011/012 read fire/frost but tagged Cosmos/Gaia; batch5-107 reads scorpion, tagged Gaia; batch5-023 blank montage) — **queue a render/label audit.** The codex **WL### WildLines books use a separate ID scheme** — do **not** cross-merge them with `batch5-*` registry IDs.
9. **Prices are first-pass indicative** — `Economy.md` has no numeric anchors; **balance-pass the prices once the game-loop sim runs.**
10. **Filename note:** `economy_items_rivals.md` combines what the brief templated as two files — the ingest step should split items vs rivals as needed.

## 3. Ingest map — which system eats each file

| Content | Ingests into | Via cluster |
|---|---|---|
| `creatures_*.md` | merge name/description into `creature_registry.csv` by `id` → `SpeciesCatalog` | **Cluster 2** (csv-importer) |
| `voice_library.md` | UI/`NotificationEngine` strings; Dialogic/Ink lines | **Cluster 1** + **3** |
| `factions_npcs.md` | Dialogic timelines + `QuestService` + faction/standing data | **Cluster 3** |
| `story_quests.md` | Ink stories + Dialogic scenes + quest-system Resources | **Cluster 3** |
| `pantheon_kits.md` | LimboAI `CombatBrain` boss definitions + HSM phases | **Cluster 4** |
| `economy_items_rivals.md` | item/gear Resources + shop tables + rival data | **Cluster 4** |
| `regions.md` | `WorldGenerator` biome rulesets + SimpleDungeons set-pieces + region/NPC data | **Cluster 4** |
| `splice_rules.json` + notes | `res://catalog/splice_rules.json` → the Lab Legality Engine | **Cluster 4** |

## 4. Full manifest — Waves 1–5 (24 files)
- **Creatures & catalog:** `creatures_wild_1` (89) · `creatures_wild_2` (131) · `creatures_legendary_construct` (156) — **376 named**.
- **Voice:** `voice_library` (314) + `voice_library_2` (453) — **~767 lines**.
- **People:** `factions_npcs` (9 leaders, 27 Hands, 64 NPCs) · `regional_cast` (+43 NPCs, 33 encounters) · `roster_shops_expansion` (+12 rivals, +24 characters, +12 shops, +25 items).
- **Story & quests:** `story_quests` (6 acts, 24 main quests) · `side_quests` (28) · `scripts_mvp` (8 branched scenes) · `scripts_acts2to5` (10 scenes, all endings wired).
- **World:** `regions` (11) · `world_lore_connections` (cosmology + 18 inter-region links + 18 faction entanglements + 6 branch-trees) · `husbandry_bestiary` (acquisition/breeding flavor + 15 ecology notes).
- **Systems content:** `pantheon_kits` (25 bosses) · `skills_statuses` (skill library + 6 statuses) · `economy_items_rivals` (80 items, 10 shops, 12 rivals) · `competitions` (6 types, 24+ events) · `endgame_succession` (11 endings + ceremonies) · `splice_rules.json` (+ notes).
- **Canon control:** `_CONTENT_INDEX` · `_CANON_RATIFICATIONS` · `_NAME_RECONCILIATION` · `_SUCCESSION_REGISTRY`.

## 5. Ingest map (the new files)
- `scripts_mvp` / `scripts_acts2to5` / `side_quests` → Ink/Dialogic + quest-system → **C3**.
- `competitions` → competition/standing systems + rival hooks → **C4**.
- `endgame_succession` → ending logic + the Succession publish/invasion → **C4 + Vercel (TDD §7.4)**.
- `skills_statuses` → skill/status Resources → **C4**. `voice_library_2` → UI/Notification/Dialogic → **C1/C3**.
- `regional_cast` / `roster_shops_expansion` / `world_lore_connections` → NPC/shop/lore data → **C3/C4**.

## 6. Canon resolved (decisions locked)
Faction leaders (`factions_npcs.md` canonical; story names re-roled — `_NAME_RECONCILIATION.md`) · Titanfall's god = **Mordathun** (Cairn-King/Old Weight) · grid-god force-vectors (`pantheon_kits`) · currency glyphs ₯✶◈ · gear-slot→boost map · the **DG-### scheme** (`_SUCCESSION_REGISTRY.md`). **Apply at ingest:** the name re-roles + DG remaps to the data; the price/balance pass; the batch5 render audit; update the stale "(a dead Titan)" lines in `World.md`/`factions_npcs.md`.

*Twenty-four content files. ~376 creatures · ~767 voice lines · 130+ named cast · 24 rivals · 6 acts + 28 side quests + 18 branched scenes · 11 regions · 25 bosses · 6 competition types · 11 endings · the skill/status library · the Lab ruleset. The content-hungry surfaces have been fed a feast — the pivot now is **ingest**, as Clusters 1–5 build.*
