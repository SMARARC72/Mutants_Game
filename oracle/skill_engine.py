#!/usr/bin/env python3
"""Mutants_Game - SKILL engine (v0.1): force-pool skills, 8 verbs, ranks, combos.

Each force owns a skill pool; creatures draw primary (full) + secondary (partial).
Verbs: Strike Drain Ward Mend Hex Rouse Summon Gambit. Cost AP (+Focus).
Skills rank up (resource invest). Team combos discovered by same-force pairing.
Proves supports have a real job (Mend/Ward/Rouse/Hex), not chip damage.
"""
from canonical_rng import RNG
from canonical_math import rnd, rnd_dp
import stat_engine as se

OPP = {"Cosmos": "Chaos", "Chaos": "Cosmos", "Eros": "Thanatos",
       "Thanatos": "Eros", "Gaia": "Ouranos", "Ouranos": "Gaia"}


def force_mult(a, d):
    if OPP.get(a) == d:
        return 1.5
    if a == d:
        return 0.7
    return 1.0


# Skill library: name -> force, verb, ap, power/effect
SKILLS = {
    "Riot Fang":    dict(force="Chaos",    verb="Strike", ap=1, power=1.0),
    "Overload":     dict(force="Chaos",    verb="Gambit", ap=2, power=1.25, entropy=15),
    "Aegis":        dict(force="Cosmos",   verb="Ward",   ap=1, shield=0.30),
    "Bind":         dict(force="Cosmos",   verb="Hex",    ap=1, slow=0.30),
    "Bloom":        dict(force="Eros",     verb="Mend",   ap=1, heal=0.70),
    "Verdant Gift": dict(force="Eros",     verb="Rouse",  ap=1, buff=0.30),
    "Soul Leech":   dict(force="Thanatos", verb="Drain",  ap=1, power=0.9, lifesteal=0.5),
    "Wither":       dict(force="Thanatos", verb="Hex",    ap=1, defdown=0.30),
    "Boulder Smash":dict(force="Gaia",     verb="Strike", ap=2, power=1.3),
    "Bulwark":      dict(force="Gaia",     verb="Ward",   ap=1, shield=0.40),
    "Gale Slash":   dict(force="Ouranos",  verb="Strike", ap=1, power=0.85),
    "Tailwind":     dict(force="Ouranos",  verb="Rouse",  ap=1, buff=0.20),
}


class Mon:
    def __init__(self, name, prim, sec, rank, tier, kit, ranks=None):
        st, hp, bst = se.stat_block(prim, sec, rank, tier)
        self.name = name; self.prim = prim; self.sec = sec; self.stats = st
        self.maxhp = hp; self.hp = hp; self.alive = True
        self.kit = kit; self.ranks = ranks or {}
        self.shield = 0; self.buff = 0.0; self.defdown = 0.0

    def offense(self):
        return (self.stats["Spike"], "Bulk") if self.stats["Spike"] >= self.stats["Bane"] else (self.stats["Bane"], "Ward")

    def has(self, verb):
        for s in self.kit:
            if SKILLS[s]["verb"] == verb:
                return s
        return None


def rank_mult(mon, skill):
    return 1.0 + (mon.ranks.get(skill, 1) - 1) * 0.25


def damage(user, skill, tgt, ent, combo, log):
    sk = SKILLS[skill]
    off, defstat = user.offense()
    off = off * sk.get("power", 1.0) * rank_mult(user, skill) * (1 + user.buff)
    mit = tgt.stats[defstat] * (1 - tgt.defdown)
    fm = force_mult(user.prim, tgt.prim)
    dmg = rnd(1.5 * off * off / (off + mit) * fm * ent * combo)
    absorbed = min(tgt.shield, dmg); tgt.shield -= absorbed; dmg -= absorbed
    tgt.hp -= dmg
    tag = "  [" + user.prim + ">" + tgt.prim + "]" if fm > 1 else ""
    cm = "  +COMBO" if combo > 1 else ""
    sh = "  (" + str(absorbed) + " absorbed)" if absorbed else ""
    log.append("   " + user.name.ljust(9) + skill.ljust(13) + "-> " + tgt.name.ljust(9) + str(dmg) + " dmg" + tag + cm + sh + "   (" + tgt.name + " " + str(max(0, tgt.hp)) + "/" + str(tgt.maxhp) + ")")
    if sk.get("lifesteal") and dmg > 0:
        heal = rnd(dmg * sk["lifesteal"]); user.hp = min(user.maxhp, user.hp + heal)
        log.append("      " + user.name + " drains " + str(heal) + " HP (now " + str(user.hp) + ")")
    if sk.get("defdown"):
        tgt.defdown = max(tgt.defdown, sk["defdown"]); log.append("      " + tgt.name + " WITHERED (-" + str(int(sk["defdown"] * 100)) + "% def)")
    if tgt.hp <= 0 and tgt.alive:
        tgt.alive = False; log.append("   ** " + tgt.name + " DIES -> parts + Graveyard **")


def support(user, skill, allies, log):
    sk = SKILLS[skill]; rm = rank_mult(user, skill)
    if sk["verb"] == "Mend":
        tgt = min([a for a in allies if a.alive], key=lambda a: a.hp / a.maxhp)
        heal = rnd(user.stats["Vitality"] * sk["heal"] * rm)
        tgt.hp = min(tgt.maxhp, tgt.hp + heal)
        log.append("   " + user.name.ljust(9) + skill.ljust(13) + "~> heals " + tgt.name + " +" + str(heal) + " HP  (" + str(tgt.hp) + "/" + str(tgt.maxhp) + ")")
    elif sk["verb"] == "Ward":
        tgt = min([a for a in allies if a.alive], key=lambda a: a.hp / a.maxhp)
        tgt.shield += rnd(tgt.maxhp * sk["shield"] * rm)
        log.append("   " + user.name.ljust(9) + skill.ljust(13) + "~> shields " + tgt.name + " (" + str(tgt.shield) + " shield)")
    elif sk["verb"] == "Rouse":
        tgt = max([a for a in allies if a.alive and a is not user], key=lambda a: a.stats["Spike"] + a.stats["Bane"])
        tgt.buff += sk["buff"] * rm
        log.append("   " + user.name.ljust(9) + skill.ljust(13) + "~> rouses " + tgt.name + " (+" + str(int(tgt.buff * 100)) + "% offense)")


def act(user, allies, foes, ent, prevforce, rng, log):
    low = [a for a in allies if a.alive and a.hp < a.maxhp * 0.78]
    mend = user.has("Mend")
    if mend and low:
        support(user, mend, allies, log); return user.prim
    ward = user.has("Ward")
    if ward and any(a.alive and a.hp < a.maxhp * 0.60 for a in allies):
        support(user, ward, allies, log); return user.prim
    rouse = user.has("Rouse")
    if rouse and rng.random() < 0.3:
        support(user, rouse, allies, log); return user.prim
    # damaging
    dmg_skill = user.has("Drain") or user.has("Gambit") or user.has("Strike")
    if not dmg_skill:
        return user.prim
    tgt = min([f for f in foes if f.alive], key=lambda f: f.hp)
    combo = 1.4 if prevforce == user.prim else 1.0
    if combo > 1:
        log.append("   >> RESONANCE COMBO (" + user.prim + " chain) <<")
    damage(user, dmg_skill, tgt, ent, combo, log)
    return user.prim


def battle(A, B, rng):
    log = []; turn = 0
    while any(m.alive for m in A) and any(m.alive for m in B) and turn < 10:
        turn += 1
        ent = rnd_dp(1.0 + (turn - 1) * 0.12, 2)
        log.append("== TURN " + str(turn) + "   entropy x" + str(ent) + " ==")
        order = sorted([m for m in A + B if m.alive], key=lambda m: -m.stats["Celerity"])
        prev = {"A": None, "B": None}
        for m in order:
            if not m.alive:
                continue
            allies, foes = (A, B) if m in A else (B, A)
            side = "A" if m in A else "B"
            if not any(f.alive for f in foes):
                break
            prev[side] = act(m, allies, foes, ent, prev[side], rng, log)
        log.append("")
    log.append("RESULT: " + ("TEAM A" if any(m.alive for m in A) else "TEAM B") + " wins (turn " + str(turn) + ")")
    return log


if __name__ == "__main__":
    print("=== FORCE-POOL SKILL LIBRARY (v0.1 sample) ===")
    for force in se.POLES:
        names = [n for n, s in SKILLS.items() if s["force"] == force]
        print("  " + force.ljust(9) + " : " + ", ".join(n + "(" + SKILLS[n]["verb"] + ")" for n in names))
    print()
    print("=== SKILLS BATTLE: Team A runs a dedicated healer ===")
    A = [Mon("Worldback", "Gaia", "Eros", "wild", "T3", ["Boulder Smash", "Bulwark"]),
         Mon("Ruinmaw", "Chaos", "Thanatos", "wild", "T2", ["Riot Fang", "Soul Leech"], {"Riot Fang": 3}),
         Mon("Palehart", "Eros", "Cosmos", "wild", "T2", ["Bloom", "Aegis", "Verdant Gift"])]
    B = [Mon("Emberwyrm", "Chaos", "Ouranos", "wild", "T2", ["Riot Fang", "Gale Slash"]),
         Mon("Gloamcat", "Thanatos", "Ouranos", "wild", "T2", ["Soul Leech", "Wither"]),
         Mon("Augurwing", "Ouranos", "Eros", "wild", "T2", ["Gale Slash", "Tailwind"])]
    print("(Ruinmaw's Riot Fang is RANK 3 -- mastery demo)")
    print()
    for line in battle(A, B, RNG(4)):
        print(line)
