# MUTANTS_GAME — Master Index

**The complete map of the design.** Every doc and every runnable engine. · Updated 2026-06-27

> A funny-grim, mature-occult creature-collection RPG: catch, breed, splice, and ascend force-born beasts in a world of dead Greek gods, climbing from gutter-rat to throne. Tamer × Creator; you make and kill gods; every champion you forge becomes the next run's boss (the Succession).

---

## Design docs

| Doc | Covers |
|---|---|
| **Mutants_Game_Design_Bible.md** | the master design — pillars, forces, taxonomy, signature, decision log (§§0–15) |
| **Mutants_Game_Bestiary.md** | the 407-creature catalog (batches, force-reads, tiers) |
| **Mutants_Game_StatSpine.md** | the 6 pole-stats + 2 universals; the stat math |
| **Mutants_Game_Lab.md** | the Creator engine — mutate/fuse/build/mod/sacrifice + parts |
| **Mutants_Game_Battle.md** | turn-based combat, vector-clash damage, entropy clock, resonance |
| **Mutants_Game_Skills.md** | force-pool skill trees, 8 verbs, combos, ranks |
| **Mutants_Game_Status.md** | 6 force-signature statuses + the unified Corruption meter |
| **Mutants_Game_Character.md** | the player's god-ladder, the 9-god grid, endings |
| **Mutants_Game_World.md** | cosmology, 8 force-regions + hub, the pantheon mapping |
| **Mutants_Game_Factions.md** | 9 clans on the morality grid |
| **Mutants_Game_Story.md** | 4 acts, branching, the three ending families |
| **Mutants_Game_Bosses_Rivals.md** | boss tiers, the nemesis-rival system, competitions |
| **Mutants_Game_Loot_Gear.md** | player gear that boosts capture/breed/tame/lab/combat chances |
| **Mutants_Game_Acquisition_Husbandry.md** | befriend/trap/summon + the breeding chase |
| **Mutants_Game_Overworld.md** | tile-based exploration, force-climates, warped zones |
| **Mutants_Game_Economy.md** | Drachma/Essence/Ichor + the soul economy |
| **Mutants_Game_NPCs_Reactivity.md** | NPCs + the choice-driven reactive world |
| **Mutants_Game_GameLoop.md** | the through-line: how every system interlocks |
| **Mutants_Game_DataModel.md** | Supabase architecture + the OpenAI/Succession integration |
| **Mutants_Game_VerticalSlice.md** | proof one creature flows through all engines |
| **Mutants_Game_Balance.md** | the tuning checklist |
| **Mutants_Game_ImageGen_Prompts.md** | the OpenAI art prompt pack |
| **Creature_Codex_Session_Prompt.md** | handoff prompt for the parallel codex session |

## Engineering & production

| Doc | Covers |
|---|---|
| **Mutants_Game_TechStack.md** | the locked 4-component stack (Godot 4.7 · Supabase · Vercel · GitHub) + rationale |
| **Mutants_Game_MVP_Slice.md** | the first vertical-slice scope (Threshold hub + Verdant fringe) |
| **Claude_Design_Handoff_Brief.md** | the UX/UI + prototype handoff for the Claude design session |
| **Mutants_Game_TechnicalDesign.md** | **the enterprise TDD** — architecture, the determinism/parity oracle, data + RLS, the Vercel services layer, save/sync, testing, CI/CD, the phased runway, risks (red-teamed, v1.1) |

## Reference engines (runnable Python, all validated)

| File | Proves |
|---|---|
| `stat_engine.py` | force-vector + genome + tier → a stat block (your forces *are* your stats) |
| `level_engine.py` | pure-awakening leveling: resonance, overclock, entropy, regression |
| `lab_engine.py` | whole-creature ops → stat-spine output + cost ledger |
| `battle_engine.py` | turn-based fights with all the wild layers (balanced) |
| `skill_engine.py` | force-pool skills, verbs, ranks, combos, supports |
| `status_engine.py` | 6 statuses + unified Corruption → burnout |
| `loot_engine.py` | gear-modified capture/breed chances |
| `character_engine.py` | the god-ladder: 3 runs → 3 different gods |
| `wire_line.py` | **all eight engines on one creature** |
| `catalog_batch.py` | the art-ingest pipeline (407 creatures) |
| `schema.sql` | the full Postgres/Supabase schema (13 tables) |

## Status

**Every major and extended system: designed, built, and validated.** Content (the 407-creature codex) runs in a parallel session. Balance is a documented checklist for a playtest sprint. The design is **one machine** — forces are the shared language, corruption the shared cost, essence the shared fuel.
