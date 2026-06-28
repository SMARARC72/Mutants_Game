# ADR-014 — runs.corruption is floor-only (not capped at 130)

**Status:** Accepted (Phase 0 deviation) · **Supersedes:** the literal "corruption ≤ 130" in TDD §5.3 / Phase-0 kickoff D2, for the `runs.corruption` column only.

## Context
TDD §5.3 and the Phase-0 kickoff D2 both say to add a `corruption ≤ 130` CHECK. Implementing
it literally on `runs.corruption` is wrong, because **130 caps a different meter**:

- The `≤130` cap lives in `status_engine.add_corruption` (`c.corruption = min(130, …)`, feral at
  100). That is the **per-combatant, battle-LIVE** corruption meter, which TDD §4.2 explicitly
  says is **NOT persisted** ("battle-live only, like current_hp … not persisted per-instance").
- `runs.corruption` (labeled "player corruption track" in `0001_init.sql`) is a **different,
  cumulative, run-long** meter, fed **unclamped** by the engines: `lab_engine.fuse` charges +18
  player corruption per taboo fuse and +35 per self-splice; `character_engine` increments it with
  no clamp (only the morality axes `oc`/`pc` are clamped). A normal run of ~8 taboo fuses
  (8×18 = 144) or a few self-splices exceeds 130.

So a literal `corruption ≤ 130` CHECK would **reject legitimate save/sync writes** in Phase 3.
The TDD's instruction (line 235, "corruption ≤ 130 mirrors the engine") conflates the two meters.

## Decision
On `runs.corruption`, enforce **floor-only**: `check (corruption >= 0)`. Do **not** add an upper
bound, because the player track has no published ceiling and the 130 ceiling belongs to a meter
that is never persisted to any column. `balance_constants.json` still carries
`status.corruption_cap = 130` — it is the faithful per-combatant battle constant (parity-checked
against `status_engine`), simply not applied as a DB constraint.

## Consequences
- `0002_hardening.sql` uses `runs_corruption_nonneg check (corruption >= 0)`.
- No persisted column carries the 130 cap (correct per the two-meter design).
- Surfaced by the Phase-0 adversarial review; flagged in `PHASE0_REPORT.md`. If a player-track
  ceiling is later designed, add it via a new migration with the correct value.
