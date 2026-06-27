# MUTANTS_GAME — Stat Spine (v0.2)

**Status:** Tuning locked & validated on real registry creatures · **Last updated:** 2026-06-25
**Reference implementation:** `stat_engine.py` · **Principle:** *your forces are your stats.*

**Locked tuning (your three calls):**
- **Model = HYBRID:** 6 pole-stats + 2 universals.
- **Genome = WIDE ±35%** (big breeding / min-max chase).
- **Scaling = BRUTAL** (god ≈ **7.75×** a wild-T1 base, before leveling).

---

## The stats

**6 pole-stats — one per primordial force:**

| Stat | Pole | Governs |
|---|---|---|
| **Bulk** | Gaia | physical defense, mass, stagger resist |
| **Celerity** | Ouranos | speed (turn order), accuracy, energy regen |
| **Ward** | Cosmos | mystic defense, control/debuff resist, lowers own variance |
| **Spike** | Chaos | raw attack power, crit chance, damage variance |
| **Vitality** | Eros | max-HP, HP regen, healing dealt |
| **Bane** | Thanatos | drain/lifesteal, affliction & debuff potency |

**2 universals — outside the force system (texture):**

| Stat | Governs |
|---|---|
| **Luck** | crit confirmation, evasion, rare events — *and* genetic/mutation rolls (ties to the breeding endgame) |
| **Focus** | the skill-resource pool: how many big moves before exhaustion (action economy) |

---

## Derivation

1. **Force distribution** from the registry: primary **0.60**, secondary **0.40** (pure = 1.0).
2. **Budget (BST)** — BRUTAL ladder (level-1; leveling multiplies):

   | wild T1 | wild T2 | wild T3 | Legendary | God | Primordial |
   |---|---|---|---|---|---|
   | 200 | 360 | 640 | 1050 | 1550 | 2400 |

3. **Floor + bonus** (φ=0.50): `pole_stat = BST·φ/6 + BST·(1−φ)·f_pole`.
4. **Universals**: a flat base by tier/rank (Luck 10→42, Focus 20→120), outside the force budget.
5. **Genome potential — WIDE ×0.65–1.35** per stat (hidden; dominant genes high, dormant unrealized; bred & mutated for). `stat = round(value · genome_mult)`.
6. **Construct class mod:** Bulk ×1.25, Ward ×1.20, Vitality ×0.40 (no regen); combat: Bane-affliction ×0.5, Chaos-Spike overload ×1.25.
7. **Derived:** `Max HP = HP_base + 3·Vitality` *(v0.2.1 balance: Vitality-driven; Bulk = mitigation only; raised HPBASE)* · `Initiative = Celerity` · damage/crit/drain vs. defender stats × force-matchup multiplier (battle pillar).

---

## Validation (real registry creatures, via `stat_engine.py`)

```
creature             Bulk Cele Ward Spik Vita Bane    Lk  Fc      HP    BST
Ruin pup  (SB30) T1    17   17   17   77   17   57    10  20      210   202
Ruinmaw   (AD01) T2    30   30   30  138   30  102    14  30      370   360
Worldback (AD02) T3   245   53   53   53  181   53    18  45     2176   638
Gloamcat  (AD09) T2    30  102   30   30   30  138    14  30      370   360
Clockwork (b3-031)T3  226   53  294   53   21   53    18  45     1140   700  (construct)
Hades-type  GOD      439  129  129  129  129  594    32  85     2830  1549
Primordial pure Than 200  200  200  200  200 1400    42 120     2480  2400

Wide genome ±35% — same Ruinmaw, 3 rolls:  Spike 114 / 98 / 148   (the breeding chase)
```

- Same budget, opposite creatures (Ruinmaw striker vs Gloamcat drainer, both BST 360).
- Construct guts regen (Vit 21) for armor + ward.
- Pure-pole Primordial = **glass god**: 1400 Bane, brittle elsewhere — purity↔fragility in numbers.
- God 7.75× base, *before* leveling widens it further → "battling gods" needs ascension or mastery.

---

## Identity this produces

Hardcore, theorycraft-deep, and aspirational: breeding for elite genes and ascending yourself aren't optional flourishes — they're how you stay competitive with gods and Succession bosses.

## Tuning knobs (live)

φ floor (0.50) · BST ladder (brutal) · genome ±35% · construct net-budget runs slightly above tier (trades regen for armor — flagged).

## Next §13 sub-systems

Leveling curve · genetics depth (IV/EV ceilings, breeding, dormant-gene surfacing) · skills (force-pool trees + signature moves) · full damage formula.
