# MUTANTS_GAME — MVP / First Vertical Slice (v0.1)

**Status:** scoped (orchestrated) · **Last updated:** 2026-06-27
**Principle:** *the smallest thing that proves the core loop is fun. If the slice isn't fun, we tune before we scale — not after.*

---

## Goal

A **~30-minute playable** that runs the core loop end-to-end. Its only job: prove the loop is moreish and the wild systems read as *fun*, not opaque. Everything else waits.

## In scope (v1)

- **1 hub** (Threshold) + **1 starter region** (the **Verdant fringe** — Eros-tilted, gentle, forgiving).
- **~25 creatures**: a balanced force-spread — ~18 T1/T2 wild, ~5 T3, **1 Legendary boss** — pulled from the registry/codex.
- **The core loop:** tile **explore** → wild **encounter** → turn-based **battle** (stats + vector-clash + AP; *statuses deferred to v1.1*) → **catch** (befriend/trap, gear-modified chances) → **basic Lab** (mutate + fuse only) → **leveling** (resonance awakenings + the overclock gamble) → **one gear slot** of loot → the **boss**.
- **1 faction** (the Bloomwardens) — a taste of standing.
- **Save** on Supabase: `players`, `runs`, `creature_instances`, `world_state`.

## Out of scope (v2+)

Full Lab (build/mod/self-splice/taboo) · full skill trees & combos · status effects (v1.1) · the full pantheon + the Succession · the character god-ladder + ascension · competitions & the rival/nemesis depth · world-reactivity depth · the 9 endings · the other 7 regions · the 660 net-new creatures.

## Success criteria (what "fun" means, measurably)

- The **explore → fight → catch → lab → grow** loop stays moreish across ~30 min.
- **Vector-clash + awakenings + the overclock gamble** read as exciting, not confusing.
- **Catch / gear / breed chances** feel satisfying (not a slot machine, not a gimme).
- **No one-shots; fights land ~5–8 turns** (the balance targets).

## Asset needs for the slice

~25 creature arts (authored/codex art exists for the picks, or gen via the OpenAI pipeline) · the hub + one region's tiles · a minimal UI (battle, party, Lab, map).

## Build order (the engineering runway)

1. **Data + loop skeleton** — player/run/creature CRUD on Supabase (`schema.sql`).
2. **Battle** — port `battle_engine` logic (the validated core).
3. **Overworld** — tile movement + wild encounters.
4. **Catch + basic Lab + leveling** — port `loot_engine`, `lab_engine` (fuse/mutate), `level_engine`.
5. **Content** — the one region + its ~25 creatures + the boss + the Bloomwardens.
6. **Playtest → tune** — sweep the `Mutants_Game_Balance.md` dials against the success criteria.

## Why this slice

The Verdant fringe is gentle (good onboarding), Eros-tilted (shows off Mend/husbandry, the warm before the grim), and small enough to finish. It exercises **every core engine** (stats, battle, catch, lab, leveling, loot) without needing the endgame systems — a true vertical proof that becomes the seed of the full game.
