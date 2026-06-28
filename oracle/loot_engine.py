#!/usr/bin/env python3
"""Mutants_Game - LOOT & GEAR engine (v0.1): player gear that boosts CHANCES & capabilities
for capture / tame / breed / lab / combat. 5 slots, rarity tiers, force-attune, loot sources.
Proves gear meaningfully shifts the capture & breeding odds.
"""
from canonical_rng import RNG
from canonical_math import rnd, rnd_dp

SLOTS = ["Relic", "Tool", "Vestment", "Charm", "Glyph"]
RARITY = ["Common", "Fine", "Rare", "Mythic", "Relic-tier"]

# name -> slot, rarity, effects (capture/tame/breed_rare/lab additive %, combat power, force tint)
GEAR = {
    "Beastcaller's Horn": dict(slot="Tool",     rarity="Rare",      capture=0.25, tame=0.20),
    "Geneweaver Gloves":  dict(slot="Tool",     rarity="Mythic",    breed_rare=0.20, lab=0.25),
    "Sigil of Mercy":     dict(slot="Charm",    rarity="Fine",      capture=0.10, force="Eros"),
    "Tyrant's Mantle":    dict(slot="Vestment", rarity="Mythic",    capture=0.15, combat="Dominion aura", force="Cosmos"),
    "Luckbone Charm":     dict(slot="Charm",    rarity="Rare",      breed_rare=0.10, capture=0.08),
    "Hephaestus Relic":   dict(slot="Relic",    rarity="Relic-tier",lab=0.40, combat="Forge-hand", force="Gaia"),
}
TIER_FACTOR = {"T1": 1.0, "T2": 0.72, "T3": 0.48, "legendary": 0.22, "god": 0.07}


def clamp(v, a, b):
    return max(a, min(b, v))


def bonus(gear_list, field):
    return sum(GEAR[g].get(field, 0) for g in gear_list)


def capture_chance(method, tier, hp_frac, bond, gear_list, morality_fit=1.0):
    base = {"befriend": 0.35, "trap": 0.45}[method]
    hp_mult = clamp(1.7 - hp_frac, 0.5, 1.6)                 # near-death easier
    bond_mult = 1 + (bond * 0.004 if method == "befriend" else 0)
    gear_mult = 1 + bonus(gear_list, "capture")
    return clamp(base * TIER_FACTOR[tier] * hp_mult * bond_mult * gear_mult * morality_fit, 0.02, 0.95)


def breed_roll(gear_list, rng):
    rare_chance = clamp(0.10 + bonus(gear_list, "breed_rare"), 0, 0.6)
    rare = rng.random() < rare_chance
    iv_ceiling = rnd_dp(1.20 + (0.10 if rare else 0.0), 2)    # rare/gear lifts the genome ceiling
    return rare, rare_chance, iv_ceiling


def pct(x):
    return str(rnd(x * 100)) + "%"


if __name__ == "__main__":
    print("=== GEAR LOADOUT (5 slots) ===")
    loadout = ["Beastcaller's Horn", "Geneweaver Gloves", "Sigil of Mercy", "Tyrant's Mantle", "Hephaestus Relic"]
    for g in loadout:
        d = GEAR[g]
        print("  " + d["slot"].ljust(9) + g.ljust(20) + "[" + d["rarity"] + "]")
    print("  -> capture +" + pct(bonus(loadout, "capture")) + " | breed-rare +" + pct(bonus(loadout, "breed_rare")) +
          " | lab +" + pct(bonus(loadout, "lab")) + " | tame +" + pct(bonus(loadout, "tame")))
    print()
    print("=== CAPTURE CHANCE (befriend) ===")
    print("  " + "case".ljust(40) + "no gear   geared")
    cases = [
        ("T2, full HP", "T2", 1.0), ("T2, 20% HP", "T2", 0.2),
        ("T3 apex, 20% HP", "T3", 0.2), ("Legendary, 15% HP", "legendary", 0.15),
        ("GOD, 10% HP", "god", 0.1),
    ]
    for label, tier, hp in cases:
        ng = capture_chance("befriend", tier, hp, bond=60, gear_list=[])
        gd = capture_chance("befriend", tier, hp, bond=60, gear_list=loadout)
        print("  " + label.ljust(40) + pct(ng).ljust(10) + pct(gd))
    print()
    print("=== BREEDING: rare-gene roll (gear lifts odds + genome ceiling) ===")
    for seed in (1, 2, 3, 4):
        r0, c0, iv0 = breed_roll([], RNG(seed))
        r1, c1, iv1 = breed_roll(loadout, RNG(seed))
        print("  seed " + str(seed) + ": no-gear rare=" + str(r0) + " (" + pct(c0) + ", iv x" + str(iv0) + ")   " +
              "geared rare=" + str(r1) + " (" + pct(c1) + ", iv x" + str(iv1) + ")")
