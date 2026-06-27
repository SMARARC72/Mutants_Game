#!/usr/bin/env python3
"""Mutants_Game - CHARACTER LADDER (v0.1): the player's climb to godhood.

Narrative-driven (not a stat-creature). Climb the god-ladder via DEEDS + CORRUPTION.
Two morality axes (each split in 3 -> a 3x3 grid of 9 emergent gods):
  Order <-> Chaos   (oc: -100 Order .. +100 Chaos)
  Purity <-> Corruption (pc: -100 Pure .. +100 Corrupt)
World reacts at notoriety thresholds. Endgame: ASCEND (become your grid-god -> Succession)
or stay the mortal GOD-MAKER.
"""
RANKS = ["Mortal", "Adept", "Demigod", "Titan", "God", "Primordial"]

GODS = {
    ("Order", "Pure"):    "The Lawgiver  (Law / Heaven)",
    ("Order", "Tainted"): "The Architect (Order, compromised)",
    ("Order", "Corrupt"): "The Iron Throne (Dominion / Machine)",
    ("Balanced", "Pure"): "The Warden  (Steward)",
    ("Balanced", "Tainted"): "The Broker  (Gray god)",
    ("Balanced", "Corrupt"): "The Plaguelord",
    ("Chaos", "Pure"):    "The Free Wild (Liberty / Nature)",
    ("Chaos", "Tainted"): "The Reveler  (Dionysian)",
    ("Chaos", "Corrupt"): "The Devourer (the Abyss)",
}

EVENTS = {
    "uphold a law":   dict(oc=-12, note=2),
    "ally a faction": dict(oc=-8, note=-5),
    "break a taboo":  dict(oc=12, note=8),
    "incite chaos":   dict(oc=10, note=6),
    "spare / heal":   dict(pc=-9),
    "refuse power":   dict(pc=-11),
    "self-splice":    dict(pc=14, corr=1, note=10),
    "sacrifice kin":  dict(pc=10, corr=1, note=7),
    "kill a god":     dict(deeds=1, note=20),
    "kill a legend":  dict(deeds=1, note=10),
}

NOTO = [(90, "the Pantheon itself marks you for death"),
        (60, "a rival god-maker sends hunters"),
        (30, "a faction turns hostile")]


def clamp(v):
    return max(-100, min(100, v))


def band3(v, labels):
    return labels[0] if v <= -34 else (labels[2] if v >= 34 else labels[1])


def rank_for(deeds):
    thr = [0, 1, 3, 5, 7, 9]   # God at 7 deeds, Primordial at 9
    r = RANKS[0]
    for i, t in enumerate(thr):
        if deeds >= t:
            r = RANKS[i]
    return r


def play(name, sequence, ascend):
    oc = pc = deeds = corr = note = 0
    fired = set()
    print("=== " + name + " ===")
    rank = rank_for(deeds)
    for ev in sequence:
        d = EVENTS[ev]
        oc = clamp(oc + d.get("oc", 0)); pc = clamp(pc + d.get("pc", 0))
        deeds += d.get("deeds", 0); corr += d.get("corr", 0); note = max(0, note + d.get("note", 0))
        nr = rank_for(deeds)
        line = "  " + ev.ljust(15)
        if nr != rank:
            rank = nr; line += "  >> RANK UP -> " + rank
        for thr, msg in NOTO:
            if note >= thr and thr not in fired:
                fired.add(thr); line += "  ! NOTORIETY: " + msg
        print(line)
    al, pl = band3(oc, ["Order", "Balanced", "Chaos"]), band3(pc, ["Pure", "Tainted", "Corrupt"])
    god = GODS[(al, pl)]
    print("  FINAL: rank " + rank + " | axes " + al + "/" + pl + " (oc " + str(oc) + ", pc " + str(pc) + ") | deeds " + str(deeds) + " corruption " + str(corr) + " notoriety " + str(note))
    if ascend and rank in ("God", "Primordial"):
        print("  ENDING: ASCENDS as " + god + "  ->  becomes next run's Succession boss")
    else:
        print("  ENDING: stays mortal -> THE GOD-MAKER (commands a pantheon, never ascends)")
    print()


if __name__ == "__main__":
    print("=== THE 9-GOD GRID (Order/Chaos x Purity/Corruption) ===")
    for oc_l in ["Order", "Balanced", "Chaos"]:
        row = "  " + oc_l.ljust(9) + " : "
        row += " | ".join(GODS[(oc_l, p)].split("(")[0].strip() for p in ["Pure", "Tainted", "Corrupt"])
        print(row)
    print()
    play("The Saint-King", ["uphold a law", "spare / heal", "ally a faction", "refuse power",
                            "kill a legend", "kill a god", "uphold a law", "refuse power",
                            "kill a god", "spare / heal", "kill a god", "kill a god",
                            "uphold a law", "kill a god", "kill a god"], ascend=True)
    play("The Abyss", ["break a taboo", "self-splice", "kill a legend", "sacrifice kin",
                       "self-splice", "incite chaos", "kill a god", "self-splice", "break a taboo",
                       "kill a god", "kill a god", "self-splice", "kill a god", "kill a god", "kill a god"], ascend=True)
    play("The Puppet-Master", ["ally a faction", "kill a legend", "kill a god", "spare / heal",
                               "kill a god", "uphold a law", "kill a god", "kill a god",
                               "kill a god", "kill a god"], ascend=False)
