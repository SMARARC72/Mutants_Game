#!/usr/bin/env python3
"""Mutants_Game - LEVELING engine (v0.1): PURE-AWAKENING growth.

No smooth levels. Combat XP fills toward a threshold; at a threshold you ROLL for
resonance (Luck-biased). Catch -> AWAKENING (stat surge, maybe a dormant gene,
maybe a branch). Stall -> OVERCLOCK to force it, banking ENTROPY (= instability).
Entropy >= 100 -> BURNOUT (harsh, recoverable). REGRESS to purge entropy + unlock a
lesser-form trick. Ceiling raisable; world scales to deeds. Stats = ceiling x expression.
"""
from canonical_rng import RNG
from canonical_math import rnd, rnd_dp
import stat_engine as se

BURNOUT = 100
GENES = {"Ironblood": "Bulk", "Venomous": "Bane", "Quickstep": "Celerity",
         "Warded Soul": "Ward", "Frenzy": "Spike", "Verdant": "Vitality"}


def current_stats(ceiling, expression, gene_bonus):
    return {k: rnd(v * (expression + gene_bonus.get(k, 0.0))) for k, v in ceiling.items()}


def awaken(rng, expression, gene_bonus, genes):
    surge = rng.uniform(0.10, 0.22)
    expression = min(1.0, expression + surge)
    events = ["surge +" + str(rnd(surge * 100)) + "%"]
    if rng.random() < 0.35:
        avail = [g for g in GENES if g not in genes] or list(GENES)
        g = rng.choice(avail)
        genes.append(g)
        gene_bonus[GENES[g]] = gene_bonus.get(GENES[g], 0.0) + 0.12
        events.append("GENE: " + g + " (+" + GENES[g] + ")")
    if rng.random() < 0.20:
        events.append("BRANCH")
    return expression, events


def simulate(name, primary, secondary, rank, tier, cls, seed, thresholds=14, reckless=False):
    rng = RNG(seed)
    ceiling, hp, bst = se.stat_block(primary, secondary, rank, tier, cls)
    expression, entropy, awakenings, attempts, burnouts = 0.30, 0, 0, 0, 0
    genes, gene_bonus = [], {}
    mode = "RECKLESS" if reckless else "measured"
    print("=== " + name + "  (" + primary + "/" + (secondary or "pure") + ", " + tier + " " + cls + ", " + mode + ")  ceiling BST " + str(bst) + " ===")
    for t in range(1, thresholds + 1):
        attempts += 1
        chance = min(0.90, 0.28 + 0.12 * attempts + ceiling["Luck"] * 0.003)
        roll = rng.random()
        natural = roll < chance
        forced = (not natural) and (reckless or entropy <= 65)
        if forced:
            entropy += rng.randint(16, 30)
        if natural or forced:
            expression, events = awaken(rng, expression, gene_bonus, genes)
            awakenings += 1
            attempts = 0
            tag = "OVERCLOCK " if forced else "resonance "
            extra = ("  [entropy " + str(entropy) + "]") if forced else ""
            print(" T" + str(t).rjust(2) + "  " + tag + "AWAKEN #" + str(awakenings) + ": " + ", ".join(events) + " -> expr " + str(rnd(expression * 100)) + "%" + extra)
        else:
            print(" T" + str(t).rjust(2) + "  resonance STALL (rolled " + str(rnd_dp(roll, 2)) + " vs " + str(rnd_dp(chance, 2)) + ")")
        if entropy >= BURNOUT:
            burnouts += 1
            print("    >>> BURNOUT (entropy " + str(entropy) + "): crippled + corrupted!")
            expression = max(0.30, expression - 0.18)
            entropy -= 45
            trick = rng.choice(["Feral Bite", "Shrunken Step", "Last Gasp"])
            print("    >>> REGRESS: entropy -45 (now " + str(entropy) + "), expr -18% -> " + str(rnd(expression * 100)) + "%, unlock lesser-form: " + trick)
    cur = current_stats(ceiling, expression, gene_bonus)
    print(" FINAL: " + str(awakenings) + " awakenings | expr " + str(rnd(expression * 100)) + "% | entropy " + str(entropy) + " | burnouts " + str(burnouts) + " | genes: " + (", ".join(genes) if genes else "none"))
    print(" stats vs ceiling:  " + "  ".join(k + " " + str(cur[k]) + "/" + str(ceiling[k]) for k in se.POLE_STATS))
    print()


if __name__ == "__main__":
    simulate("Ruinmaw", "Chaos", "Thanatos", "wild", "T2", "organic", seed=11)
    simulate("Glasscannon", "Chaos", "Thanatos", "wild", "T2", "organic", seed=5, reckless=True)
