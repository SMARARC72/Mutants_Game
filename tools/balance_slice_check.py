#!/usr/bin/env python3
"""Phase 5 - Slice 4 BALANCE harness (MVP success criteria, docs/Mutants_Game_MVP_Slice.md).

Runs the oracle (oracle/battle_engine.simulate) over the Verdant slice's REPRESENTATIVE matchups
(the starter party vs each wild tier + the legendary boss) across many seeds, reports the
turn-count distribution, and ASSERTS the MVP balance targets:

  * NO one-shots  -- no combatant dies on turn 1 from a single hit;
  * typical fights land in the ~5-8 turn band (per-matchup MEAN turn count in [5, 8]).

The roster + the matchups come from client/catalog/slice_verdant.json (the curated slice data),
read BY ID against client/catalog/species.json. The battle math is the SAME oracle the client ports;
balance is tuned via tools/balance_constants.json + the oracle literals (the constants pipeline),
NOT here -- this file only measures + gates. Deterministic: same constants => same distribution.

CI: runnable in the oracle job (exit 1 on a missed target). Run: python -B tools/balance_slice_check.py
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "oracle"))

import canonical_rng as cr  # noqa: E402
import battle_engine as be  # noqa: E402

SEEDS = 300                 # seeds per matchup (a stable distribution sample)
BAND_LO, BAND_HI = 5, 8     # the MVP "~5-8 turns" target band (mean turn count)

with open(os.path.join(ROOT, "client", "catalog", "species.json"), encoding="utf-8") as fh:
    SPECIES = {r["id"]: r for r in json.load(fh)["species"]}
with open(os.path.join(ROOT, "client", "catalog", "slice_verdant.json"), encoding="utf-8") as fh:
    SLICE = json.load(fh)


def mon(species_id):
    """Build a battle_engine.Mon from a catalog id (legendary boss has tier=None -> default T3)."""
    r = SPECIES[species_id]
    tier = r.get("tier") or "T3"
    return be.Mon(r["name"], r["force_primary"], r.get("force_secondary"),
                  r["rank"], tier, r.get("class", "organic"))


def _turn_of(result_line):
    m = re.search(r"wins on turn (\d+)", result_line)
    return int(m.group(1)) if m else 0


def _had_one_shot(log):
    """A one-shot = a DIES line before '== TURN 2' (a combatant downed on turn 1)."""
    for line in log:
        if line.startswith("== TURN 2"):
            return False
        if "DIES" in line:
            return True
    return False


def run_matchup(label, player_ids, enemy_ids):
    turns, one_shots, player_wins = [], 0, 0
    for seed in range(SEEDS):
        team_a = [mon(i) for i in player_ids]
        team_b = [mon(i) for i in enemy_ids]
        log = be.simulate(team_a, team_b, cr.RNG(seed))
        turns.append(_turn_of(log[-1]))
        if _had_one_shot(log):
            one_shots += 1
        if "TEAM A" in log[-1]:
            player_wins += 1
    mean = sum(turns) / len(turns)
    return {
        "label": label, "mean": round(mean, 2), "min": min(turns), "max": max(turns),
        "one_shots": one_shots, "player_wins": player_wins, "n": SEEDS,
    }


def main():
    starter = [m["species_id"] for m in SLICE["starter_party"]]
    # Representative enemy teams: a T1 wild pair, a T2 wild pair, a T3 elite, and the boss solo.
    wild = SLICE["wild_pool"]
    elite = SLICE["elite_pool"]
    t1 = [m["species_id"] for m in wild if m.get("tier") == "T1"][:2]
    t2 = [m["species_id"] for m in wild if m.get("tier") == "T2"][:2]
    t3 = [elite[0]["species_id"]]
    boss = [SLICE["boss"]["species_id"]]

    matchups = [
        ("starter vs T1 wild", starter, t1),
        ("starter vs T2 wild", starter, t2),
        ("starter vs T3 elite", starter, t3),
        ("starter vs LEGENDARY boss", starter, boss),
    ]

    print("=" * 78)
    print("Slice 4 balance check  (oracle battle_engine.simulate, %d seeds/matchup)" % SEEDS)
    print("targets: NO one-shots; mean turn count in [%d, %d]" % (BAND_LO, BAND_HI))
    print("=" * 78)
    header = "%-30s %6s %5s %5s %9s %10s"
    print(header % ("matchup", "mean", "min", "max", "1-shots", "playerwin"))
    print("-" * 78)

    fails = []
    for label, p, e in matchups:
        r = run_matchup(label, p, e)
        print("%-30s %6.2f %5d %5d %9d %9d/%d"
              % (r["label"], r["mean"], r["min"], r["max"],
                 r["one_shots"], r["player_wins"], r["n"]))
        if r["one_shots"] > 0:
            fails.append("%s: %d one-shot(s) (target 0)" % (label, r["one_shots"]))
        if not (BAND_LO <= r["mean"] <= BAND_HI):
            fails.append("%s: mean %.2f turns outside [%d, %d]"
                         % (label, r["mean"], BAND_LO, BAND_HI))

    print("-" * 78)
    if fails:
        print("BALANCE: FAIL (%d)" % len(fails))
        for f in fails:
            print("  - " + f)
        sys.exit(1)
    print("BALANCE: PASS - no one-shots; all matchups in the %d-%d turn band." % (BAND_LO, BAND_HI))


if __name__ == "__main__":
    main()
