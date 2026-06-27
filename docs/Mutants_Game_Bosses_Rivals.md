# MUTANTS_GAME — Bosses, Rivals & Competitions (v0.1)

**Status:** roundtable-locked (orchestrated) · **Last updated:** 2026-06-27
**Principle:** *the world is full of other people trying to become god. Most of them are in your way.*

---

## Boss tiers (the vertical opposition)

| Tier | Who | Role |
|---|---|---|
| **Legendaries** | the 34 legendary-rank registry creatures | region guardians, mini-bosses, dungeon ends |
| **Olympians/Gods** | the 33 god-rank creatures (the Pantheon) | **Act bosses** — killing one reshapes its region |
| **Primordials** | the 6 pure poles | superbosses / the true-ending wall |
| **Succession bosses** | player-made gods (your past runs + friends' invasions) | the unique, personal endgame opposition |
| **Secret bosses** | gated by exploration / faction / grid conditions | bragging-rights superbosses |

## Rivals — the nemesis system (Wick)

Persistent, **named NPC god-aspirants** (trainers, breeders, lab-rats, cultists). Each has a **team, a grid alignment, a faction, a personality, and a goal.**

- They **climb alongside you** (rubber-band to your rank + notoriety): the more infamous you get, the deadlier the rivals the world sends.
- Outcomes are **sticky** — beat one and it returns obsessed; spare one and it may become an ally; humiliate one and it defects to a faction and hunts you. Some recur as **Act bosses**; some you can recruit, breed with, or sacrifice.
- You meet them in the overworld **and** in competitions.

## Competitions — the "go fight other trainers/breeders" loop

| Competition | What it tests | Run by |
|---|---|---|
| **Battle Leagues** | climbing force-themed gym-ladders of trainers | each faction |
| **The Arena** (Threshold) | seasonal neutral cross-faction tournament | the High Table |
| **Breeding Shows** | a creature's genome / stats / purity / rarity | Stoneblooded, Bloomwardens |
| **Lab-Craft Contests** | fusion / mutation creativity & power | Iron Guild, the Revel |
| **Clan Wars** | faction-vs-faction territory battles | all factions |
| **Bounties** | hunt a named rival god-maker or rogue creature | the High Table |

**Rewards:** gear, exclusive creatures, faction standing, currency, **unique god-organs**, and leaderboard rank (which itself raises notoriety → tougher rivals → bigger prizes).

## Scaling
Rival/boss power scales to **character rank + notoriety** on the brutal stat curve; competitions are bracketed by creature tier so a fresh team isn't thrown at gods. Secret/superbosses ignore brackets — they're walls on purpose.

## Engine note
Competitions reuse `battle_engine.py`; a rival generator scales an NPC team's tier/forces to the player's rank and rolls a grid-aligned personality. Validation belongs with the §Game-loop sim.

## Ties
Core Act 1–2 activity loop. Rewards → §Loot & §Economy. Bosses = §World gods. Succession bosses = Character ladder + the friends-async loop.
