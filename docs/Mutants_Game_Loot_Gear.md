# MUTANTS_GAME — Loot & Gear (v0.1)

**Status:** built & validated · **Last updated:** 2026-06-27
**Reference implementation:** `loot_engine.py` · **Principle:** *gear doesn't make your beasts stronger — it makes YOU better at making beasts.*

---

## Player gear — 5 slots (one item each)

**Relic · Tool · Vestment · Charm · Glyph.** Gear upgrades *your toolkit*, not creature stats — it's the player's progression curve.

## What gear boosts (chances & capabilities)

- **Capture** chance · **Tame** speed / bond gain · **Breed** rare-gene odds + genome (IV) ceiling · **Lab** operation success & quality · **Combat** (player force-powers, auras) · **Force-attune** synergy.

## Rarity & attunement

Common → Fine → Rare → Mythic → **Relic-tier** (divine). **Force-attuned** gear synergizes with matching-force creatures and regions; **set bonuses** reward matched faction/force loadouts.

## Loot sources

Bosses · rivals · competition prizes · ruins & exploration · the **black market** · crafting (Iron Guild / your Lab) · faction-standing rewards.

## Validated chance model (`loot_engine.py`)

A full kitted loadout = **+50% capture, +20% breed-rare, +65% lab, +20% tame.** Effects:

```
capture (befriend)        no gear   geared
  T2, full HP               22%  ->  33%
  T2, 20% HP                47%  ->  70%
  T3 apex, 20% HP           31%  ->  47%
  Legendary, 15% HP         15%  ->  22%
  GOD, 10% HP                5%  ->   7%

breeding rare-gene roll:  10%  ->  30%  (and a rare roll lifts the genome ceiling x1.2 -> x1.3)
```

Gear is **impactful but never trivializing** — near-death + low tier + full kit = reliable catches; legendaries and gods stay hard even fully geared. The toolkit is a real progression axis without breaking the chase.

## Ties
Capture/breed loop detail → §Acquisition & Husbandry. Sources → §Bosses & §Economy. Lab boosts → §The Lab. Player force-powers/auras → Character ladder.
