# MUTANTS_GAME — Status Effects (v0.1)

**Status:** designed + built & validated · **Last updated:** 2026-06-27
**Reference implementation:** `status_engine.py` · **Principle:** *every force afflicts in its own way; one meter tracks how far you've pushed.*

---

## The statuses

| Force | Status | Effect | Type |
|---|---|---|---|
| **Thanatos** | **Wither** | HP drain over time + defense down | DOT (stacks) |
| **Eros** | **Bloom-rot** | parasitic growth DOT that **spreads** to allies | DOT (stacks) |
| **Gaia** | **Petrify** | Celerity crashes → skip turns | Control (refresh) |
| **Ouranos** | **Shock** | lose AP / lose your action | Control (refresh) |
| **Cosmos** | **Seal** | can't use skills above basics | Control (refresh) |
| **Chaos** | **Madness** | act randomly / may hit an ally | Control (refresh) |
| **— universal —** | **Corruption** | **the meta-meter** (see below) | meta |

## Mechanics

- **Hybrid stacking:** DOTs (Wither, Bloom-rot) **stack intensity** — more applications, more damage. Control statuses (Petrify/Shock/Seal/Madness) **refresh duration** — one instance, re-applied to extend.
- **Bounded severity:** statuses *shape* fights but don't auto-kill on their own. The real spiral is Corruption → burnout.
- **Delivery:** Hex skills and force attacks apply the matching status.
- **Cleansing:** Eros **Mend** / Cosmos **dispel** clear battle statuses. **Corruption persists.**

## Corruption — the keystone

**One unified meter per creature**, fed by *every* "you pushed too far" source in the game:
- **Overclock-entropy** (leveling) · **Lab work** (mutate/fuse/sacrifice/self-splice) · **dark afflictions** (battle).

At **100 → burnout/feral**: the creature acts randomly and takes a −20% stat penalty (bounded — *not* instant death, but a real liability). This is the same meter across leveling, the Lab, and combat — the through-line cost of playing god.

---

## Validation (`status_engine.py`)

```
Wither      -> stacks 24 / 48 / 72 per tick                 (hybrid stack)
Bloom-rot   -> applied to Worldback, ticks, SPREADS to Palehart
Petrify     -> skip turn [2 left] -> [1 left] -> fades        (control refresh)
Corruption  -> +35 overclock, +35 Lab, +35 affliction = 105 -> BURNS OUT -> FERAL
Cleanse     -> Mend clears Wither + Bloom-rot; Corruption 105 persists
```

All four locked decisions confirmed in code: force-signature set, hybrid stacking, unified Corruption, bounded severity.

## Open / next

Per-status numbers tuning · how Madness/Shock resolve inside the AP economy · **status resistances** (a force resists its own / is vulnerable to its opposite) · the feral-behavior detail.
