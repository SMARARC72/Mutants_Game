#!/usr/bin/env python3
"""Mutants_Game - BATTLE engine (v0.1): classic turn-based core + wild layers.

Kept classic: HP, Celerity initiative, attacks, faint/death.
Layers: shared AP economy | ENTROPY escalation clock | RESONANCE (same-force chain,
cross-force overload) | vector-clash damage with simple cues | real permadeath -> parts/Graveyard.
Everything resolves to stat-spine numbers.
"""
from canonical_rng import RNG
from canonical_math import rnd, rnd_dp
import stat_engine as se

OPP = {"Cosmos": "Chaos", "Chaos": "Cosmos", "Eros": "Thanatos",
       "Thanatos": "Eros", "Gaia": "Ouranos", "Ouranos": "Gaia"}


def force_mult(att, dfn):
    if OPP.get(att) == dfn:
        return 1.5            # opposed forces clash hard
    if att == dfn:
        return 0.7           # resists its own kind
    return 1.0


class Mon:
    def __init__(self, name, prim, sec, rank, tier, cls="organic"):
        stats, hp, bst = se.stat_block(prim, sec, rank, tier, cls)
        self.name = name; self.prim = prim; self.sec = sec
        self.stats = stats; self.maxhp = hp; self.hp = hp; self.alive = True

    def offense(self):
        if self.stats["Spike"] >= self.stats["Bane"]:
            return self.stats["Spike"], "Spike", "Bulk"
        return self.stats["Bane"], "Bane", "Ward"


def attack(att, dfn, ent, chain, overload, rng, log):
    power, kind, defstat = att.offense()
    mit = dfn.stats[defstat]
    fm = force_mult(att.prim, dfn.prim) * (1.4 if overload else 1.0)
    crit = 1.5 if rng.random() < att.stats["Luck"] / 180.0 else 1.0
    K = 4.5  # global damage constant (balance dial) — Slice 4 balance pass (was 1.5; lifts fights into the 5-8 turn band, no one-shots)
    dmg = rnd(K * power * power / (power + mit) * fm * ent * chain * crit)
    dmg = min(dmg, rnd(dfn.maxhp * 0.55))   # anti-one-shot cap (balance pass)
    dfn.hp -= dmg
    cue = ""
    if fm >= 1.4:
        cue = "  [" + att.prim + " overwhelms " + dfn.prim + "!]"
    elif fm < 1.0:
        cue = "  [resisted]"
    flags = ("".join([" CHAIN" if chain > 1 else "", " OVERLOAD" if overload else "", " CRIT" if crit > 1 else ""]))
    log.append("   " + att.name.ljust(10) + " -> " + dfn.name.ljust(10) + str(dmg).rjust(4) + " dmg" + cue + flags +
               "   (" + dfn.name + " " + str(max(0, dfn.hp)) + "/" + str(dfn.maxhp) + ")")
    if dfn.hp <= 0 and dfn.alive:
        dfn.alive = False
        log.append("   ** " + dfn.name + " DIES -> harvestable parts + Graveyard (reanimatable at a cost) **")


def simulate(teamA, teamB, rng):
    log = []; turn = 0
    while any(m.alive for m in teamA) and any(m.alive for m in teamB) and turn < 8:
        turn += 1
        ent = rnd_dp(1.0 + (turn - 1) * 0.12, 2)
        log.append("== TURN " + str(turn) + "   entropy x" + str(ent) + " (escalating) ==")
        order = sorted([m for m in teamA + teamB if m.alive], key=lambda m: -m.stats["Celerity"])
        sideprev = {"A": None, "B": None}
        for m in order:
            if not m.alive:
                continue
            mine, foes = (teamA, teamB) if m in teamA else (teamB, teamA)
            side = "A" if m in teamA else "B"
            tgt = next((f for f in foes if f.alive), None)
            if not tgt:
                break
            chain = 1.3 if sideprev[side] == m.prim else 1.0   # same-force chaining
            overload = OPP.get(m.prim) == tgt.prim and rng.random() < 0.30  # cross-force overload play
            attack(m, tgt, ent, chain, overload, rng, log)
            sideprev[side] = m.prim
        log.append("")
    winner = "TEAM A" if any(m.alive for m in teamA) else "TEAM B"
    surv = [m.name for m in (teamA if winner == "TEAM A" else teamB) if m.alive]
    log.append("RESULT: " + winner + " wins on turn " + str(turn) + " | survivors: " + ", ".join(surv))
    return log


if __name__ == "__main__":
    A = [Mon("Ruinmaw", "Chaos", "Thanatos", "wild", "T2"),
         Mon("Gloamcat", "Thanatos", "Ouranos", "wild", "T2"),
         Mon("Worldback", "Gaia", "Eros", "wild", "T3")]
    B = [Mon("Palehart", "Cosmos", "Eros", "wild", "T2"),
         Mon("Augurwing", "Ouranos", "Eros", "wild", "T2"),
         Mon("Emberwyrm", "Chaos", "Ouranos", "wild", "T3")]
    print("SQUAD A: Ruinmaw, Gloamcat, Worldback   vs   SQUAD B: Palehart, Augurwing, Emberwyrm")
    print()
    for line in simulate(A, B, RNG(7)):
        print(line)
