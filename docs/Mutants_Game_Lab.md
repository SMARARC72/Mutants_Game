# MUTANTS_GAME — The Lab (Creator Engine) v0.1

**Status:** designed via roundtable + validated · **Last updated:** 2026-06-25
**Reference implementation:** `lab_engine.py` · **Principle:** *you're not a trainer — you're a surgeon-god with a parts drawer.* The moat; built to full depth.

---

## Model

**Whole-creature operations** (no anatomy slots). Each operation takes whole creature(s) **+ ingredients + a method**, and produces an output **+ a cost**. Every result resolves to **stat-spine numbers + a force-tint** (validated below).

**Operations:** **Mutate** (modify in place) · **Fuse** (2+ → 1 chimera) · **Build** (parts → construct) · **Mod** (augment a living beast) · **Sacrifice** (consume → ingredients / power / levels).

---

## Ingredients (parts / kits)

| Type | Grants |
|---|---|
| **Organs** | a specific trait or ability (a heart, eye, gland) |
| **Gene-vials** | inject a specific gene → surface a stat/trait (ties to breeding) |
| **Cores & souls** | power source — fuels builds, rituals, ascension (rare, off gods/bosses) |
| **Scrap & plating** | bulk construct materials |

**Sources (all four):** sacrifice your own · harvest the defeated & wild · **god/boss organs** (rare) · **black market** (contraband, draws heat).

---

## Method, discovery & cost

- **Precision spectrum** (per operation): **Cosmos-precise** = deterministic, costly · **Chaos-wild** = cheap, high variance.
- **Discovery:** **freeform experimentation** (gamble anything) **+ discoverable repeatable recipes** (learn a stable formula, then mass-produce). The discovery endgame.
- **Cost ledger (dual, scaling):** routine work costs the **creature's entropy** (= the Instability meter, unified with leveling); **big or taboo** work writes **corruption onto YOU**.

---

## The taboo ceiling (all unlocked)

- **Cross-force abominations** — fuse opposed forces; huge power, instability spike, **the world hunts them**.
- **God-organ grafts** — divine-tier parts on a mortal beast.
- **Splice yourself** — run the operations on your own character; become a chimera-god by hand.
- **Reanimate the dead** — rebuild from your Graveyard, or from other players' **Succession god-snapshots** (necromancy of friends' gods).

## The corruption payoff (becoming inhuman)

Corruption **unlocks player powers** — lab mastery, force-powers (e.g. Deathtouch), command over abominations — but **bolts the "pure" paths shut** and turns the world hostile. Power with a permanent price. (Feeds the morality system + the player's own apotheosis route.)

---

## Validation (`lab_engine.py`)

```
[FUSE] Ruinmaw (Chaos/Thanatos) x Gloamcat (Thanatos/Ouranos)  -- compatible, precise
  -> Thanatos/Chaos T2   Spike 102  Bane 138 ...   cost: entropy +14, corruption +0
[FUSE] Palehart (Cosmos/Eros) x Emberwyrm (Chaos/Ouranos)  -- OPPOSED, wild
  -> Cosmos/Chaos T3   Ward 245  Spike 181 ...   entropy +31, corruption +18   ** TABOO: world bounty **
[SELF-SPLICE] Thanatos god-organ -> PLAYER
  -> force-power Deathtouch | corruption +35 -> locks Pure ending, world hostile, abominations obey
```

Compatible fusions are cheap; opposed-force abominations are monstrous and expensive (instability + your humanity); self-splicing trades you for power. The ledger does the balancing.

---

## Open / next

Per-operation detail (Build, Mod, Mutate formulas) · the recipe system · the player corruption track (powers ladder) · harvest/economy tuning · wiring the Lab into the battle + morality + Succession systems.
