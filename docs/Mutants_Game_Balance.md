# MUTANTS_GAME — Balance & Tuning Checklist (v0.1)

**Status:** first pass applied; living checklist · **Last updated:** 2026-06-27
**Principle:** *every balance problem we've found is a number, not a redesign. The mechanics are sound.*

---

## Applied this pass

- **HP → Vitality-driven** (`HPBASE + 3·Vit`; Bulk is mitigation only); raised HPBASE — killed the 2,000-HP unkillable tank (stat spine v0.2.1).
- **Ratio damage** (`K·off²/(off+def)`, K=1.5) replacing subtractive — no more zero-damage supports.
- **Single-hit cap = 55% max HP** — global **anti-one-shot** safeguard (battle_engine). Verified: fights still resolve (~8 turns), but nothing dies on turn 1.
- **Steeper entropy** (+12%/turn) — fights escalate and end.

## Open tuning (needs a playtest sweep)

- **Gambits** (Overload): cap power **and** add a real downside (self-entropy/recoil), so they're a gamble, not a delete button.
- **Ward/shield spam:** cap total shield (~≤50% max HP) + a per-turn or AP cost so it can't be stacked every turn.
- **Status values:** per-status DOT/control magnitudes; add **resistances** (a force resists its own status, is weak to its opposite).
- **Capture rates:** validate the per-tier curve + method/gear/morality weights for *feel* (baseline in `loot_engine`).
- **Leveling:** awakening surge ranges, overclock entropy cost, burnout threshold.
- **Lab gates:** operation costs vs. power — instability caps, force-incompatibility penalties, diminishing returns (stop turn-1 god-beasts).
- **Brutal scaling:** confirm god ≈7.75× is "hard, not impossible" once leveling is layered.
- **Genome ±35%:** confirm the variance reads as exciting, not frustrating.

## Where the dials live

`stat_engine` (BST, PHI, genome range, HP coeffs) · `battle_engine` (K, hit-cap, entropy slope, force-mult) · `skill_engine` (skill powers, shield caps) · `loot_engine` (capture/breed chances) · `status_engine` (base values) · `character_engine` (rank curve, axis deltas).

## Method
A dedicated playtest sprint sweeps these numbers against target feel (fight length ~5–8 turns, gods need strategy/ascension, supports matter, no one-shots, capture odds satisfying). Every dial is exposed in the reference engines — nothing here requires touching the mechanics.
