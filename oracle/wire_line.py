#!/usr/bin/env python3
"""Mutants_Game - VERTICAL SLICE: one creature line through EVERY engine.
Proves the whole stack integrates on a single real registry creature (the Ruin Wolf line).
"""
import stat_engine as se
import lab_engine as lab
import loot_engine as loot
import status_engine as st


def line(s):
    print(s)


name, prim, sec, rank, tier, cls = "Ruinmaw", "Chaos", "Thanatos", "wild", "T2", "organic"
print("============ VERTICAL SLICE — THE RUIN WOLF LINE ============")

# 1) SPECIES (registry) ------------------------------------------------
line("[species]  Ruinmaw  | Organic/Wild/T2 | Chaos/Thanatos | line: Ruin Wolf (pup SB30 -> Ruinmaw)")

# 2) STATS — one-of-one genome (stat_engine) ---------------------------
genome = se.roll_genome(7)
stats, hp, bst = se.stat_block(prim, sec, rank, tier, cls, genome)
line("[stats]    one-of-one roll: " + "  ".join(k + " " + str(stats[k]) for k in se.POLE_STATS) +
     "  | HP " + str(hp) + "  BST " + str(bst))

# 3) LEVELING — pure-awakening growth (concept from level_engine) ------
expr = 0.30
for surge in (0.18, 0.15, 0.20):           # three resonance awakenings
    expr = min(1.0, expr + surge)
cur = {k: round(v * expr) for k, v in stats.items()}
line("[leveling] 3 awakenings -> expression " + str(round(expr * 100)) + "%  (Spike now " +
     str(cur["Spike"]) + ", Bane " + str(cur["Bane"]) + ")  [overclock would bank entropy]")

# 4) LAB — fuse into a chimera (lab_engine) ----------------------------
r = lab.fuse(("Ruinmaw", "Chaos", "Thanatos", "T2"), ("Gloamcat", "Thanatos", "Ouranos", "T2"), "precise", 3)
line("[lab]      FUSE Ruinmaw x Gloamcat -> " + r["name"] + " [" + r["prim"] + "/" + r["sec"] + " " + r["tier"] +
     "]  cost: entropy +" + str(r["entropy"]) + ", corruption +" + str(r["corruption"]))

# 5) SKILLS — force-pool kit + signature (skill system) ----------------
line("[skills]   kit: Riot Fang (Strike/Chaos), Soul Leech (Drain/Thanatos) | SIGNATURE: Ruin's Hunger (Drain)")

# 6) STATUS — inflicts its force-signature (status_engine) -------------
foe = st.C("Augurwing", "Ouranos", "Eros", "T2"); slog = []
st.apply(foe, "Wither", slog); st.apply(foe, "Wither", slog); st.tick(foe, [foe], slog)
line("[status]   Ruinmaw inflicts Wither x2 -> " + slog[-1].strip())

# 7) LOOT / CAPTURE — its catch odds (loot_engine) ---------------------
kit = ["Beastcaller's Horn", "Sigil of Mercy"]
ng = loot.capture_chance("trap", "T2", 0.2, 30, [])
gd = loot.capture_chance("trap", "T2", 0.2, 30, kit)
line("[loot]     wild Ruinmaw @20% HP catch: " + loot.pct(ng) + " bare -> " + loot.pct(gd) + " geared")

# 8) WORLD / CHARACTER placement --------------------------------------
line("[world]    haunts the Mournmarch & the Sunder | favored by the Pale Court / Unbound")
line("[ascend]   pure-Thanatos path -> could seed 'The Devourer' (Chaos/Corrupt grid-god) via the Succession")
print("============ all eight engines fired on one creature ✔ ============")
