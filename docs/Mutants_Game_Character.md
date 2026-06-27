# MUTANTS_GAME — The Player: Character Ladder (v0.1)

**Status:** designed via roundtable + built & validated · **Last updated:** 2026-06-25
**Reference implementation:** `character_engine.py` · **Principle:** *you are your own ultimate creature — built from your choices, not a stat sheet.*

---

## Model

- **Narrative-driven** (NOT a stat-creature): ranks, powers, and story-state — light on raw stats.
- **The god-ladder:** Mortal → Adept → Demigod → Titan → God → Primordial. Climbed by **deeds/notoriety** (gods & legendaries killed, taboos committed, factions crossed) **+ corruption/transformation** (self-splicing, dark acts).
- **Two morality axes** (each split in 3 → a 3×3 grid): **Order ⇄ Chaos** and **Purity ⇄ Corruption**.
- **Notoriety:** the world reacts at **thresholds** (not constant) — a faction turns hostile → a rival god-maker sends hunters → the Pantheon itself marks you.
- **In combat:** you fight **through your creatures**, with a few **corruption-granted personal force-powers** (big buttons) for key moments.

## The 9-God Grid — your emergent self

|  | **Pure** | **Tainted** | **Corrupt** |
|---|---|---|---|
| **Order** | The Lawgiver (Law/Heaven) | The Architect | The Iron Throne (Machine) |
| **Balanced** | The Warden | The Broker | The Plaguelord |
| **Chaos** | The Free Wild (Liberty) | The Reveler | The Devourer (Abyss) |

Where your two axes land decides which god you *can* become. Your whole playthrough writes it.

## Endgame — branching

- **ASCEND** → become your grid-god → **seeds the next run's Succession boss** (and your friends' worlds).
- **STAY MORTAL** → **The God-Maker** — command a pantheon of gods you built, never ascend. Human to the end.

Routed by your axis position + deeds + the final choice.

---

## Validation (`character_engine.py`)

Three scripted playthroughs, three emergent outcomes from one engine:

```
The Saint-King   Order/Pure     rank God, deeds 7  -> ASCENDS as The Lawgiver  -> Succession boss
The Abyss        Chaos/Corrupt  rank God, corr 5   -> ASCENDS as The Devourer  -> Succession boss
The Puppet-Master Balanced      rank God, deeds 7  -> refuses -> THE GOD-MAKER (mortal)
```

Notoriety scaled with deeds (all three drew the Pantheon's mark); ranks climbed correctly; the ascend-vs-mortal fork resolved by play. Same system, opposite gods.

## Open / next

The deeds/notoriety **event table** (content) · per-rank **powers** + the personal force-power list · the **faction roster** (who reacts and how) · mapping each grid-god to its **Succession boss** form.
