#!/usr/bin/env python3
"""Mutants_Game - STAT SPINE (v0.2.1). HYBRID 6 pole-stats + Luck/Focus; WIDE +/-35% genome;
BRUTAL scaling. Balance pass: HP is Vitality-driven (Bulk = mitigation only)."""
from canonical_math import rnd, rnd_dp

POLES = ["Gaia", "Ouranos", "Cosmos", "Chaos", "Eros", "Thanatos"]
STAT_OF = {"Gaia": "Bulk", "Ouranos": "Celerity", "Cosmos": "Ward",
           "Chaos": "Spike", "Eros": "Vitality", "Thanatos": "Bane"}
POLE_STATS = ["Bulk", "Celerity", "Ward", "Spike", "Vitality", "Bane"]
UNIVERSALS = ["Luck", "Focus"]
ALL_STATS = POLE_STATS + UNIVERSALS
BST = {("wild", "T1"): 200, ("wild", "T2"): 360, ("wild", "T3"): 640,
       ("legendary", "x"): 1050, ("god", "x"): 1550, ("primordial", "x"): 2400}
HPBASE = {"T1": 120, "T2": 240, "T3": 420, "legendary": 650, "god": 1300, "primordial": 2200}
UNIV_BASE = {"T1": (10, 20), "T2": (14, 30), "T3": (18, 45),
             "legendary": (24, 60), "god": (32, 85), "primordial": (42, 120)}
PHI = 0.50
GENOME_LO, GENOME_HI = 0.65, 1.35


def force_dist(primary, secondary):
    f = {p: 0.0 for p in POLES}
    if primary and secondary:
        f[primary] += 0.60
        f[secondary] += 0.40
    elif primary:
        f[primary] = 1.0
    return f


def rank_tier_key(rank, tier):
    return rank if rank in ("legendary", "god", "primordial") else (tier or "T1")


def bst(rank, tier):
    if rank == "wild":
        return BST[("wild", tier or "T1")]
    return BST.get((rank, "x"), 200)


def class_mod(stats, cls):
    if cls != "construct":
        return stats
    m = dict(stats)
    m["Bulk"] = rnd(m["Bulk"] * 1.25)
    m["Ward"] = rnd(m["Ward"] * 1.20)
    m["Vitality"] = rnd(m["Vitality"] * 0.40)
    return m


def stat_block(primary, secondary, rank, tier, cls="organic", genome=None):
    f = force_dist(primary, secondary)
    budget = bst(rank, tier)
    floor = budget * PHI / 6.0
    bonus = budget * (1.0 - PHI)
    g = genome or {s: 1.0 for s in ALL_STATS}
    stats = {}
    for p in POLES:
        s = STAT_OF[p]
        stats[s] = rnd((floor + bonus * f[p]) * g.get(s, 1.0))
    key = rank_tier_key(rank, tier)
    luck_b, focus_b = UNIV_BASE[key]
    stats["Luck"] = rnd(luck_b * g.get("Luck", 1.0))
    stats["Focus"] = rnd(focus_b * g.get("Focus", 1.0))
    stats = class_mod(stats, cls)
    hp = rnd(HPBASE[key] + 3 * stats["Vitality"])   # balance: HP from Vitality; Bulk = mitigation only
    bst_total = sum(stats[s] for s in POLE_STATS)
    return stats, hp, bst_total


def roll_genome(rng):
    r = rng
    return {s: rnd_dp(r.uniform(GENOME_LO, GENOME_HI), 3) for s in ALL_STATS}


def main():
    samples = [
        ("Ruinmaw T2", "Chaos", "Thanatos", "wild", "T2", "organic"),
        ("Worldback T3", "Gaia", "Eros", "wild", "T3", "organic"),
        ("Gloamcat T2", "Thanatos", "Ouranos", "wild", "T2", "organic"),
        ("Hades GOD", "Thanatos", "Gaia", "god", "x", "organic"),
    ]
    for name, p, s, rank, tier, cls in samples:
        st, hp, tot = stat_block(p, s, rank, tier, cls)
        nums = "  ".join(k + " " + str(st[k]) for k in POLE_STATS)
        print(name.ljust(14) + nums + "   HP " + str(hp) + "  BST " + str(tot))


if __name__ == "__main__":
    main()
