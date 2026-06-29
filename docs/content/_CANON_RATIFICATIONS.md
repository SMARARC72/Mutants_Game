# Mutants_Game — Canon Ratifications (resolving the open content flags)

**Date:** 2026-06-28. These lock the items `_CONTENT_INDEX.md` §2 left open, so downstream content + the build inherit decisions, not placeholders. Orchestrator decisions (roundtable, acting for the creator).

---

1. **Titanfall's dead Titan — RATIFIED: `Mordathun, the Old Weight`** (force: **Gaia**, rank: god/primordial-adjacent, dead). Adopts the regions-agent provisional and makes it canon. Epithets (all canon): **the Cairn-King** (formal title, per `Creature_Codex_Families.md`), **the Old Weight** / **the Fallen Hill** (folk names). All NPC/region references (Granny Loam, the Titan-Priest, Matriarch Ostrega) resolve to Mordathun. *(Update `World.md` + `Factions.md` "(a dead Titan)" → Mordathun at the next doc pass.)*

2. **Grid-god → force-vector mapping — RATIFIED: adopt `pantheon_kits.md` as canon.** Each of the 9 morality-grid gods now has a locked force-vector + Book05 Dead-God seed (Lawgiver, Architect, Iron Throne, Warden, Broker, Plaguelord, Free Wild, Reveler, Devourer). `Character.md`'s "Open/next" item is closed; the systems session implements these vectors as the player's ascension forms.

3. **Currency glyphs — RATIFIED:** **Drachma = ₯** · **Essence = ✶** · **Ichor = ◈**. Adopts the economy-agent shorthand as the UI convention (distinct, single-glyph, themable). The design system may restyle the glyph art, but these are the canonical symbols.

4. **Gear-slot → boost mapping — RATIFIED** (per the economy author; confirm magnitudes vs `loot_engine` in the balance pass):
   - **Relic → capture** (+ a force-aura passive) · **Tool → lab** (operation success/cost) · **Vestment → combat** (+ corruption-resist) · **Charm → tame** (+ luck) · **Glyph → breed** (+ force-attunement).

5. **Rival → Dead-God (DG-###) binding — RULE LOCKED:** each named rival's Succession form binds to a **unique** Book05 DG-### (or a newly-minted one); **no two rivals share a snapshot.** The ingest step validates uniqueness across `economy_items_rivals.md`; conflicts get reassigned to the next free DG-###.

6. **Verdant Glut — RATIFIED as a contested region** shared by the **Bloomwardens** (cultivators) and the **Revel** (rot-revelers); the Bloomwardens have no solo region by design (the Glut *is* their front). Intentional; the tension is content, not a bug.

7. **Creature data audit — SCHEDULED (non-blocking):** the flagged batch5 art↔force label mismatches (batch5-007/011/012/107) and the blank montage (batch5-023) are queued for a render/label audit at the art-pipeline stage; names/descriptions already reconcile to the registry force tags. The codex `WL###` WildLines IDs remain a **separate scheme** — never cross-merged with `batch5-*` registry IDs.

*Six decisions locked, one audit scheduled. The world has no unnamed gods and no placeholder mappings feeding the build.*
