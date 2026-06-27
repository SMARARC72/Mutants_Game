# MUTANTS_GAME — Battle System (v0.1)

**Status:** designed via roundtable + built & validated (with a balance flag) · **Last updated:** 2026-06-25
**Reference implementation:** `battle_engine.py` · **Principle:** *classic turn-based bones, wild layers on top, every number from the stat spine.*

---

## Model

**Kept classic (not reinvented):** HP pools · **Celerity** initiative · attacks & skills · faint/death.
**Layers on top:** shared AP economy · **entropy escalation clock** · **resonance combos** · vector-clash damage · real permadeath.

- **Action economy:** a **shared squad AP pool** each turn — basic actions cheap, big skills costly; load one beast or spread out. (Focus modulates the pool.)
- **Party:** 3–5 creatures, **real permadeath**. God fights scale to multi-phase raids.

## Damage — vector clash (the locked hybrid)

`dmg = max(1, offense − defense×0.5) × force_mult × entropy × chain × crit`

- **Offense** = Spike (physical) or Bane (mystic), whichever is higher. **Defense** = Bulk or Ward to match.
- **force_mult:** opposed forces **×1.5** (clash hard) · same force **×0.7** (resists its kind) · else ×1.0. Surfaced as a simple cue: *"Chaos overwhelms Cosmos!"*
- **crit** from Luck.

## The signature layers

- **Entropy clock (escalation engine):** entropy rises each turn (+10%/turn here), ramping everyone's damage — fights start tactical, end explosive. **Overclock** mid-fight for a surge at an entropy cost.
- **Resonance combos (3 modes):**
  - **Same-force chaining** — allies sharing a force chain sequential actions into amplified hits (×1.3).
  - **Unlockable combo skills** — specific creature pairs unlock named team moves (discoverable, collectible).
  - **Cross-force overload** — deliberately clash opposed forces for a high-risk burst that spikes entropy.

## Death feeds the machine

A fallen creature is **gone as a fighter** but becomes **harvestable Lab parts + a Graveyard epitaph**, and can be **reanimated** (changed/corrupted) at a steep cost. Permadeath that loops back into the Creator engine.

---

## Validation (`battle_engine.py`) — a real 3v3

Squad A (Ruinmaw/Gloamcat/Worldback) vs Squad B (Palehart/Augurwing/Emberwyrm). **All layers fired correctly:** vector cues ("Chaos overwhelms Cosmos!"), entropy ramped ×1.0→×1.9, crits/overloads triggered, three creatures died → parts/Graveyard, Team A won on the back of Worldback.

### ✓ Balance pass (resolved 2026-06-25)

The first sim flagged fat HP and zero-damage supports. Fixed via **tuning only** (mechanics untouched):

- **HP is now Vitality-driven:** `HPBASE(tier) + 3·Vitality` (Bulk reverted to *mitigation only* — no double-dip), with raised HPBASE. Tank:glass HP spread went from ~6:1 to ~3:1 (Worldback **2,176 → 963**).
- **Ratio damage** replaces subtractive: `dmg = K · offense² / (offense + defense) × force × entropy × chain × crit` (K = 1.5). Never collapses to zero — supports chip ~10–25 instead of 2.
- **Entropy steepened** to +12%/turn.

**Re-validated:** the same 3v3 now resolves in **7 turns** — casualties spread across the fight, the fortress tank (Worldback) durable but killable, vector cues / crits / overloads all firing. Tight and readable. (Per-creature fine-tuning is a job for a full playtest sprint once the skills layer exists.)

---

## Open / next

Balance pass (damage:HP ratio) · status effects · the combo-skill / signature-move library · player-in-combat (corruption force-powers) · god-raid multi-phase structure · AI.
