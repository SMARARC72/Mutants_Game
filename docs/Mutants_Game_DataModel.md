# MUTANTS_GAME — Data Model & Tech Architecture (v0.1)

**Status:** schema built (`schema.sql`, 13 tables) · **Last updated:** 2026-06-27
**Principle:** *forces are the shared language, corruption the shared cost, essence the shared fuel — and the schema speaks all three.*

---

## Stack

- **Database:** Supabase (Postgres). DDL: `schema.sql`.
- **Images:** OpenAI image-gen — `genome → prompt`, **generate-once / persist-forever** into `art_assets`.
- **Logic:** the reference `*_engine.py` modules become app logic / Postgres functions / Supabase edge functions — pure functions, **no rework**.
- **Client/engine:** engine-agnostic (the reference logic is plain functions); a 2D tile client (Godot/web) is the natural fit, deferred to engineering.

## Schema map (13 tables)

- **`species`** — the 407 registry (creature templates).
- **`players`, `runs`** — the player + each playthrough: rank, the two grid axes (order_chaos, purity_corrupt), notoriety, deeds, corruption, the three currencies, gear loadout, ascended god_form.
- **`creature_instances`** — owned **one-of-one** creatures: `genome` jsonb (the wide ±35% + dormant genes), expression, bond, **entropy** (the unified corruption meter), awakenings, learned skills, status_effects, lineage, `sigil_seed`, dead flag.
- **`art_assets`** — OpenAI generate-once images (instance → url/prompt/seed/model).
- **`gear`, `skills`, `inventory`** — items, the skill library, per-run parts/kits/vials/consumables.
- **`factions`, `faction_standing`, `world_state`, `rivals`** — the reactive world & nemesis system.
- **`god_snapshots`** — **the Succession:** player-made gods saved as boss templates; `shareable` exports them to friends' worlds.

## Key decisions

- **Stats are derived, not stored raw:** `stat_engine` computes from species + genome + tier; cached in `stats_cached` and recomputed on change.
- **One corruption meter:** `creature_instances.entropy` (creatures) and `runs.corruption` (player) — the unified "pushed too far" track from leveling/Lab/battle.
- **The Succession:** on ascension, snapshot the run's champion + pantheon → `god_snapshots`; the next run (or a friend's import) seeds its bosses from there — the shared, self-generating mythology.
- **OpenAI persistence:** prompt+seed+image saved per instance; authored art is the style fallback if generation is pending.

## Save / sync

Per-run rows; `world_state.region_states` jsonb holds the reactive world; `god_snapshots` persist **cross-run** (the mythology that outlives any save). Friend invasion = import a friend's `god_snapshot` as a boss in your world — async, no live netcode.

## Engines → backend (port list)
`stat_engine · level_engine · lab_engine · battle_engine · skill_engine · status_engine · loot_engine · character_engine` — all pure → app logic or Postgres/edge functions.

## Ties
Everything persists here. `force_primary/secondary`, the corruption columns, and `essence` are the threads that stitch the schema to the design.
