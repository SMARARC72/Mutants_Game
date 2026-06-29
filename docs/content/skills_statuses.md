# MUTANTS_GAME — Named Skill & Status Content Library

**Author:** combat-content sub-agent · **Status:** content draft v0.1 · **Date:** 2026-06-28
**Source-of-truth read:** `Content_Generation_Brief.md`, `_CANON_RATIFICATIONS.md`, `Mutants_Game_Skills.md`, `Mutants_Game_Status.md`, `Mutants_Game_Battle.md`, `Mutants_Game_StatSpine.md`. Cross-checked against `content/pantheon_kits.md` so the named library and the boss kits share one vocabulary.

---

## 0. How to read these entries (the contract)

Every skill below is **expressible by the live engines** — real verbs, real forces, real resources, **no invented stats**. Conventions, lifted straight from the docs:

- **6 forces = 6 pole-stats:** **Gaia** (Bulk) · **Ouranos** (Celerity) · **Cosmos** (Ward) · **Chaos** (Spike) · **Eros** (Vitality) · **Thanatos** (Bane). Universals: **Luck**, **Focus**. **Opposed pairs:** Cosmos⇄Chaos · Eros⇄Thanatos · Gaia⇄Ouranos. (Opposed fusion = taboo *abomination*.)
- **8 verbs** (every creature gets a role): **Strike · Drain · Ward · Mend · Hex · Rouse · Summon · Gambit.** Pole affinities: Eros→Mend, Thanatos→Drain, Cosmos→Ward, Chaos→Gambit, Gaia→guard/Strike, Ouranos→fast Strike. A force can reach *any* verb — affinity just means it's cheaper/stronger on its home verb.
- **Cost shape = `AP · Focus`.** AP is the **shared squad pool** per turn (basics cheap, ultimates costly); **Focus** (the stat) is the per-creature gate on how many big moves before exhaustion. Notation below: **`2 AP · 8 Foc`**. Indicative bands: *basic* 1 AP / 0–5 Foc · *core* 2 AP / 8–14 Foc · *heavy* 3 AP / 18–28 Foc · *ultimate/signature* 4 AP / 30–45 Foc · *Gambit* costs less AP but carries a **downside** (recoil / self-entropy / miss-chance — the Skills.md balance note).
- **Damage** resolves on the locked formula `dmg = 1.5 · offense² / (offense + defense) × force_mult × entropy × chain × crit`. **Offense** = higher of Spike/Bane · **Defense** = higher of Bulk/Ward · **force_mult** opposed ×1.5 / same ×0.7 / else ×1.0 · entropy ramps +12%/turn · crit from Luck.
- **Ranks:** each skill ranks up for resources at **~×1.25 power per rank** — investment, not just use. Entries give the rank-1 shape; rank is a multiplier on top.
- **Statuses** are applied by **Hex** verbs and force attacks: each force afflicts in its own signature way (§Status). DOTs (Wither, Bloom-rot) **stack**; controls (Petrify/Shock/Seal/Madness) **refresh duration**. **Corruption** is the universal meta-meter and is *never* applied by a normal Hex — it accrues from "you pushed too far" sources.
- **Acquisition** (all skills): innate via awakenings · Lab organ-transplant · breeding inheritance · taught via skill-vials. **Signature** moves are one-per-base-species, unlocked at high bond. **Combos** are discovered by pairing the named forces in a squad (§Combos).

**Counts target:** ~8–10 named skills per force (≈48–60), a signature roster, the combo resonance table, and a full status library. Final tallies and canon gaps are in §Summary.

---

## 1. GAIA — the Old Weight *(stat: Bulk · guard/Strike pole · opposes Ouranos)*

> Gaia is patience with mass behind it. Its kit is slow, immovable, and lands like a verdict — guard that punishes you for waiting *and* for not waiting. The damage is honest Bulk-channel; the control is the ground deciding you've stood there long enough. Signature status: **Petrify** (Celerity crashes → skip turns).

| Name | Verb | Shape | One-liner |
|---|---|---|---|
| **Boulder Smash** | Strike | `2 AP · 9 Foc` | The oldest argument: a rock, applied firmly, to the part of you that was disagreeing. *(canon basic)* |
| **Tectonic Slam** | Strike | `3 AP · 20 Foc` | Drops a fault line under the formation; the cluster that stood together now lies down together. AoE Bulk-channel. |
| **Bulwark** | Ward | `2 AP · 10 Foc` | Roots and refuses. Absorbs the next several blows; the hill does not consent to being moved. *(canon basic — capped/cooldowned per balance note)* |
| **The Long Settling** | Hex | `2 AP · 14 Foc` | The ground closes around an ankle, politely. Applies **Petrify** — Celerity craters, turns get skipped. |
| **Sediment of Years** | Hex | `3 AP · 16 Foc` | Buries a target one stratum deeper each turn; stacks toward a hard **Petrify** while shaving its defense. |
| **Grave-Weight** | Drain | `2 AP · 13 Foc` | Off-pole: presses the life out of a thing the way a glacier presses out a valley — slow Bane leeched through sheer mass. |
| **Hold the Line** | Rouse | `2 AP · 11 Foc` | Plants the squad's feet; raises Bulk across the party and shrugs off the next stagger. The dead-god in the dirt approves. |
| **Mountainfather's Patience** | Ward | `3 AP · 22 Foc` | A standing wall that *hardens every turn it survives* — make this quick, or it won't be quick for you. |
| **Summon: Cairn-Thing** | Summon | `3 AP · 24 Foc` | Stacks loose rubble into a squat guardian that soaks hits and occasionally falls on someone. Built, not born. |
| **Mordathun's Reproach** | Gambit | `2 AP · 26 Foc` | *(downside: self-stagger next turn)* Calls down the Old Weight's full sulk — a region-shaking Bulk burst that staggers the caster too. Named for the Fallen Hill itself. |

**Signature (base-species, high bond): `Inherit the Ground`** *(Ward, Gaia · 4 AP · 38 Foc)* — the creature *becomes terrain* for two turns: near-immune behind a planet's worth of Bulk, immovable, and anything that strikes the body risks **Petrify**. The fight has to go *around* it, because it will not be going anywhere.

---

## 2. OURANOS — the Open Sky *(stat: Celerity · fast-Strike pole · opposes Gaia)*

> Ouranos is the force that already went. Its kit is initiative made into a weapon — strike first, strike again, and leave the enemy a turn behind the whole fight. Low Focus on most moves (it regens energy), high tempo, brittle if it ever has to *take* a hit. Signature status: **Shock** (lose AP / lose your action).

| Name | Verb | Shape | One-liner |
|---|---|---|---|
| **Gale Slash** | Strike | `1 AP · 4 Foc` | A cut delivered before the wind notices it left. Cheap, always early in the order. *(canon basic)* |
| **Skyfall Lance** | Strike | `3 AP · 18 Foc` | Comes down from a height nobody agreed the sky had; Celerity-scaled single-target spike that lands first. |
| **Tailwind** | Rouse | `1 AP · 5 Foc` | Hands the squad the sky's tailwind — initiative and accuracy up, because going second is for the buried. *(canon basic)* |
| **Stormstep** | Rouse | `2 AP · 10 Foc` | Quickens one ally so hard it takes its turn *now*; the wind doesn't wait for the queue. |
| **Sever the Tempo** | Hex | `2 AP · 13 Foc` | A strike to the nerve that runs the clock. Applies **Shock** — the target loses its action, having misplaced its turn. |
| **Thunderstruck** | Hex | `3 AP · 17 Foc` | A bolt that scrambles the action economy: drains AP from the enemy line and re-applies **Shock** to whoever moved last. |
| **Wind-Drinker** | Drain | `2 AP · 12 Foc` | Off-pole: skims the breath out of a thing and gives it to the caster — a thin, whistling Bane-drain at speed. |
| **Outrun the Verdict** | Strike | `2 AP · 9 Foc` | On a kill, the wind takes a second action; it has never once stayed for the eulogy. |
| **Summon: Squall-Wisp** | Summon | `3 AP · 22 Foc` | Calls a fast, fragile air-elemental that harries the backline and dies cheaply, on purpose. |
| **First, Always** | Gambit | `1 AP · 24 Foc` | *(downside: −Ward until next turn)* Steals the top of the round outright — acts before anything, twice, and stands wide open for it. |

**Signature (base-species, high bond): `Before You Finish the Thought`** *(Strike, Ouranos · 4 AP · 36 Foc)* — the creature acts at the absolute speed of the open sky: a strike landed *before the turn is read*, that **Shocks** on hit and, on a kill, immediately takes another. Going first against it is not a strategy that exists.
