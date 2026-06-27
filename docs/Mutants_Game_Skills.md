# MUTANTS_GAME — Skills & Combo Library (v0.1)

**Status:** designed via roundtable + built & validated · **Last updated:** 2026-06-25
**Reference implementation:** `skill_engine.py` · **Principle:** *your force-blend is your kit — but nothing is locked.*

---

## Architecture

- **Force-pool trees:** each of the 6 forces owns a skill pool. A creature draws **primary (full) + secondary (partial)**, unlocking depth as it **awakens** (skills & leveling are one progression). Kits are **teachable & swappable** — the pool is the default, not a cage.
- **8 combat verbs** (so every creature has a role): **Strike · Drain · Ward · Mend · Hex · Rouse · Summon · Gambit.** Pole affinities: Eros mends, Thanatos drains, Cosmos wards, Chaos gambits, Gaia guards, Ouranos strikes fast.
- **Cost:** AP (shared squad pool) **+ Focus** (the stat) — cheap basics → expensive ultimates.
- **Signature moves:** one unique identity skill per base species, unlocked at high bond.
- **Combo-moves:** named team moves **discovered by pairing** the right creatures/forces (squad-building + collection hook).

## Acquisition (all four sources)

**Innate via awakenings** (leveling) · **Lab transplant** (graft an organ → gain its skill) · **Breeding inheritance** (offspring inherit signature skills) · **Taught** (skill-vials — a craftable/tradeable skill economy).

## Mastery

**Ranks:** spend resources to rank a skill up (~×1.25 power per rank) — deliberate investment, not just use.

## Sample pool (v0.1)

| Force | Skills (verb) |
|---|---|
| **Gaia** | Boulder Smash (Strike), Bulwark (Ward) |
| **Ouranos** | Gale Slash (Strike), Tailwind (Rouse) |
| **Cosmos** | Aegis (Ward), Bind (Hex) |
| **Chaos** | Riot Fang (Strike), Overload (Gambit) |
| **Eros** | Bloom (Mend), Verdant Gift (Rouse) |
| **Thanatos** | Soul Leech (Drain), Wither (Hex) |

---

## Validation (`skill_engine.py`)

- **In a live fight:** Ward shields absorbed 260–376/hit, Drain lifesteal landed, Rouse buffs stacked (+offense), rank-3 Riot Fang hit harder, resonance-combo logic fired, deaths routed to parts/Graveyard.
- **Controlled support showcase:** Drain (131) → **Bloom heals +97** → **Aegis shields 289** → next Drain **fully absorbed (0 dmg)**. Supports demonstrably matter.

## ⚠ Balance notes (for the playtest sprint — tuning, not design)

- **Gambits one-shot.** "Overload" (power 1.25–1.8) deletes squishies before supports act. Gambits need a real *downside* (self-entropy, recoil, miss chance), not just raw power.
- **Shield-spam is oppressive.** Bulwark every turn made a tank near-immortal. Wards need a **cap, cooldown, or AP cost** so they can't be spammed.

## Open / next

Full per-pole skill lists (content) · signature-move roster · the combo-move table · status-effect payloads (what Hex does) · AP/Focus economy tuning.
