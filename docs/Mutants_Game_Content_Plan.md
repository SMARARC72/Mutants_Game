# Mutants_Game — Content Production Plan

**Status:** strategic plan · **Date:** 2026-06-27 · grounded in a content-completeness audit of the corpus.

> **The strategic answer to "is the world/lore/characters handled?"** — **No. It's *framed*, not *written*.** The systems and their integrations are deep; the **content that flows through them is largely empty.** And every system you just wired up — Ink, Dialogic, quests, the Succession boss AI, the splice-rules engine, worldgen, the grimoire UI/notifications — is a **content-hungry data surface.** A data-driven game with empty data tables is a tech demo. **Filling those tables *is* "taking maximum advantage."**

---

## 1. Where content actually stands (audited)

| Layer | State | Detail |
|---|---|---|
| **Pantheon** (48: 42 Olympians + 6 Primordials) | 🟢 **Written** | Fully profiled (stats, signatures, funny-grim descriptions) in `Creature_Codex_Book01`. The gold standard. |
| **Player character ladder** | 🟢 **Written** | `Character.md` + `character_engine` validated (9-god grid, 3 endings proven). |
| **Creatures — Phase A (407 art-backed)** | 🟢 **Written** | Names, descriptions, roles, force-blends filled. |
| **Creatures — Phase B (~660 net-new)** | 🟡 **Data, no prose** | Force/rank/role/tier/tags filled; **~297 lack names, ~381 lack descriptions.** |
| **Legendaries** | 🟡 **Partial** | ~42 named (demons/abominations); **~71 are force-tagged stubs.** |
| **8 regions** | 🟡 **Framed** | Named + force-mapped; **no lore, history, inhabitants, set-pieces.** |
| **Story (4 acts)** | 🟡 **Framed** | Outline + 9 endings mapped; **no beats, dialogue, or quests.** |
| **9 factions** | 🟡 **Framed** | Named + ideologies + standing ladder; **no leaders, quest-givers, or dialogue.** |
| **NPC roster** | 🔴 **Empty** | A reactivity *framework* only. **Zero named NPCs, zero dialogue.** |
| **Rivals/nemeses** | 🔴 **System only** | Procedural generator; **no authored characters.** |
| **Quests** | 🔴 **Empty** | Cluster 3 is a *build spec*; **no authored quest/Ink/Dialogic content.** |
| **Economy content** | 🟡 **Framed** | Currency taxonomy; **no prices or shop inventories.** |
| **Microcopy / voice library** | 🔴 **Empty** | Tone *directive* only; **no actual UI/NPC/notification lines.** |

**The one-line read:** the **people-and-prose layer** is the gap — factions, NPCs, rivals, quests, regional lore, the newer creatures' names, and the funny-grim voice.

## 2. The reframe — content = the data your systems eat

This is the key to "maximum advantage." Every built/integrated system reads from a **content surface**. List them as data contracts, not flavor:

| Content surface | The system that eats it | Current fill |
|---|---|---|
| **Creature registry CSV** (names, descriptions, roles, tags) | `SpeciesCatalog` → `stat_engine` + the Dossier | 407/1067 |
| **`splice_rules.json`** (forces, ops, taboo gates, ingredient/trait rules) | the **Lab Legality Engine** (CSP/`LabBench`) | spec only |
| **Pantheon kits + boss HSM phases** (move-sets, phase logic per god) | **LimboAI `CombatBrain`** (Succession boss) | gods profiled; boss kits/phases unwritten |
| **Faction roster** (leaders, quest-givers/Hands, standing-tier dialogue) | `QuestService` + Dialogic + the reactivity system | empty |
| **NPC roster + dialogue** (named NPCs, barks, encounter lines) | **Dialogic** timelines | empty |
| **Quests** (objectives, branches, the gates they open) | **quest-system** + **Ink** | empty |
| **Ink lore stories** (deep branching world lore) | **inkgd** | empty |
| **Region lore + set-piece rooms + biome rulesets** | **WorldGenerator** (WFC) + **SimpleDungeons** + the overworld | named only |
| **Item/gear content** (names, descriptions, prices, shop stocks) | inventory + economy | taxonomy only |
| **Microcopy / voice library** (the funny-grim lines) | **NotificationEngine** + the grimoire UI + every NPC | empty |
| **Named rivals/nemeses** (personalities, goals, teams) | the rival system + the Succession | procedural only |

**Read this column as a to-do list.** Each empty cell is a system running on lorem ipsum until it's filled.

## 3. The production strategy — slice-complete first, then scale

**Do NOT try to write the whole world at once.** Two phases:

### Phase 1 — Make the MVP slice **content-complete** (proves the coupling end-to-end)
For the **Verdant fringe + Threshold hub** MVP (`Mutants_Game_MVP_Slice.md`), author **everything** the slice touches so it ships with real flavor, not placeholders:
- **~25 creatures** fully named + described (pull from the codex; finish any stubs in the set).
- **The Bloomwardens faction**: a named leader + 2–3 quest-givers, standing-tier dialogue (Stranger→Hand).
- **~8–12 named NPCs** with dialogue + barks (the hub + the fringe).
- **3–5 quests** authored as **Ink + Dialogic** content that **gate real mechanics** (a Lab unlock, a capture target, a region gate) — this is the proof that narrative drives the systems.
- **1 named rival** with a personality + team; **1 boss** with a kit + HSM phases (feeds `CombatBrain`).
- **The region's lore** + **1–2 set-piece rooms** (feeds `WorldGenerator`/SimpleDungeons) + the slice's **biome ruleset**.
- **The slice's `splice_rules`** content (the legal recombinations available early).
- **Item/shop content** for the slice + **a starter voice library (~150–300 lines)**.

**Why:** a content-complete slice makes the MVP *feel like a game*, validates every content→system contract once, and gives a repeatable template for the rest.

### Phase 2 — Scale by content type across the full world
Then run **per-type generation passes**, each against the design bible + the proven model:
- **Creature naming pass** (the ~660 Phase-B + ~71 legendaries) — biggest and most mechanical; the codex pipeline already exists.
- **Faction & NPC pass** (all 9 factions: leaders, quest-givers, rosters, dialogue).
- **Region & set-piece pass** (all 8 regions: lore, inhabitants, dungeons, biome rulesets).
- **Story & quest pass** (the 4 acts as authored Ink/Dialogic beats + branching by the morality grid).
- **Pantheon Succession pass** (boss kits + HSM phases for the god roster).
- **Economy + item descriptions + the full voice library.**

## 4. How it gets produced (the proven model)

The 1,067-creature codex and the 48-god pantheon were **Claude-generated against the design bible via the roundtable**, reviewed for system-fit. **Use the same model for every content type** — it's proven and fast:
1. **A data template/contract per surface** (the CSV columns, the `splice_rules` schema, an NPC/quest/Dialogic/Ink template, a faction-leader sheet).
2. **A content-generation session** (a handoff prompt like `Creature_Codex_Session_Prompt.md`) that generates content **in the funny-grim voice, against the bible**, filling the templates.
3. **System-fit review (the guardrail that makes content *mechanical*, not just flavor):** faction quests must gate real unlocks; boss kits must be **valid creatures** (run through the engines); `splice_rules` must pass the soundness test; region biome rules must produce valid WFC output; item prices must respect the economy sinks/sources.
4. **Ingest** into the live data files (CSV → `SpeciesCatalog`; JSON → `splice_rules`; Ink/Dialogic/quest Resources; faction/NPC/region docs).

This runs **in parallel** with engineering (just like the codex did) — content doesn't block the build, and the build doesn't block content; they meet at the data contracts.

## 5. What to do first (sequencing)
1. **Lock the data templates** for the empty surfaces (NPC, quest, faction-leader, region, splice_rules, voice-library) — small, unblocks everything.
2. **Creature naming pass** — finish the ~660 + ~71 (mechanical, high-volume, pipeline exists). The Dossier + catalog go from 38% → 100%.
3. **Voice library (~300 lines)** — unblocks *all* UI/NPC/notification writing; sets the funny-grim register concretely.
4. **MVP-slice content-complete** (Phase 1 above) — the slice becomes a real, flavored game.
5. **Scale** the faction/NPC/region/quest/pantheon passes world-wide.

## 6. The decision / offer
The content layer is now the **critical path to maximum advantage** — the systems are built; they're hungry. Fastest high-value moves, any of which I can start now:
- **Write the content-generation handoff prompt** (a parallel session, like the codex) covering the templates + the system-fit review — so content production runs alongside the build.
- **Do the creature naming pass** (finish the ~660 + ~71) — the biggest, most mechanical fill.
- **Content-complete the MVP slice** (the Bloomwardens, NPCs, quests, boss, lore, voice) — makes the first playable feel like a game.

*The systems were the hard part and they're done. Content is now both the bottleneck and the biggest lever — and it's the part the proven codex model produces fastest.*
