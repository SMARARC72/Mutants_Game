# Mutants_Game — Name Reconciliation (canon lock)

**Date:** 2026-06-28. Flagged independently by the scripts, world-lore, and earlier story agents. **`factions_npcs.md` is the single source of truth for faction leaders + NPCs.** The divergent names in `story_quests.md` (written when the people layer was still empty) are **re-cast as Hands / deputies / envoys serving under the canonical leaders** — no content is deleted, only re-roled. The ingest step applies this map.

## Rule
Any faction-leader name in `story_quests.md` (or elsewhere) that is **not** the `factions_npcs.md` leader becomes a **subordinate** (Hand, deputy, regional envoy, lab-tech) under that faction's canonical leader. Scenes keep their dialogue; the *role label* changes.

## Known mappings (canonical leader ← re-roled placeholder)
| Faction | Canonical leader (`factions_npcs.md`) | Placeholder → re-roled as |
|---|---|---|
| Concord | **Velleth** | Aurelian Vox, Pellos Vane → Concord deputies/jurists under Velleth |
| Bloomwardens | **Greenmother Saoirse Lateharvest** | Sylva Greenrot → a Bloomwarden Hand |
| High Table | **Indra Vael** | Thessaly Vance, Vael Construct-Nine → High-Table envoys/brokers |
| Pale Court | *(canonical name in `factions_npcs.md`)* | Severin Ash, Sister Morrow → Court Hands |
| Iron Guild | *(canonical)* | Castor Brail → Guild foreman/Hand |
| Stoneblooded | *(canonical)* | Bram Stoneblood → clan elder/Hand |
| Unbound | *(canonical)* | Vesh Quillon → Unbound cell-leader/Hand |
| Deep Choir | *(canonical)* | — |
| (lab/mentor NPCs) | Surgeon-Lab-Tech **Veil**, Old **Maddox Quillan** | Quintus Slagg, Old Marrow → use the canonical names |

*(Where a cell says "(canonical)", the ingest reads the exact leader name from `factions_npcs.md`; the placeholder beside it is re-roled under it.)*

## Two stale-source fixes (the doc pass `_CANON_RATIFICATIONS.md` already scheduled)
1. `World.md` `| Titanfall | Gaia | (a dead Titan) |` and `factions_npcs.md` §5 → **Mordathun, the Cairn-King / the Old Weight**.
2. Olympian regional epithets (Hades→Aidaneus, Zeus→Astrapios, Hephaestus→Hephaestion) are **in-world titles, not new gods** — pin one spelling at the codex pass.

**Net:** one faction-leader roster (factions_npcs.md), everyone else serves under them. No name now contradicts another in the shipping content.
