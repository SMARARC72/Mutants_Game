#!/usr/bin/env python3
"""Golden-vector generator (TDD §11.2). Emits tests/golden/<engine>.jsonl from the refactored
oracle. Phase 2's GDScript port runs the same (inputs, seed) through the canonical RNG and must
reproduce `expected` exactly (ints exact; floats at documented precision). Deterministic — same
oracle => same vectors (CI checks stability). Includes the §6.4 determinism tie-cases.

Run: python -B tools/gen_golden.py
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "oracle"))
import canonical_rng as cr
import stat_engine as se
import level_engine as le
import lab_engine as la
import battle_engine as be
import skill_engine as sk
import status_engine as st
import loot_engine as lo
import character_engine as ce

OUT = os.path.join(ROOT, "tests", "golden")
os.makedirs(OUT, exist_ok=True)

FORCES = se.POLES
RT = [("wild", "T1"), ("wild", "T2"), ("wild", "T3"), ("legendary", "x"), ("god", "x"), ("primordial", "x")]
CLASSES = ["organic", "construct"]


def write(engine, records):
    path = os.path.join(OUT, engine + ".jsonl")
    with open(path, "w", encoding="utf-8") as fh:
        for r in records:
            fh.write(json.dumps(r, separators=(",", ":")) + "\n")
    print("  %-16s %d vectors" % (engine, len(records)))


# ---- stat_engine ----------------------------------------------------------
def gen_stat():
    recs = []
    for pi, prim in enumerate(FORCES):
        for sec in [None] + FORCES:
            if sec == prim:
                continue
            for rank, tier in RT:
                for cls in CLASSES:
                    for seed in (pi + 1, pi + 1000):
                        genome = se.roll_genome(cr.RNG(seed))
                        stats, hp, bst = se.stat_block(prim, sec, rank, tier, cls, genome)
                        recs.append({"fn": "stat_block", "inputs": {"prim": prim, "sec": sec, "rank": rank,
                                     "tier": tier, "cls": cls, "seed": seed},
                                     "expected": {"stats": stats, "hp": hp, "bst": bst}})
    for seed in range(1000):
        recs.append({"fn": "roll_genome", "inputs": {"seed": seed},
                     "expected": se.roll_genome(cr.RNG(seed))})
    write("stat_engine", recs)


# ---- level_engine ---------------------------------------------------------
def gen_level():
    recs = []
    for seed in range(1000):
        gene_bonus, genes = {}, []
        expr, events = le.awaken(cr.RNG(seed), 0.30, gene_bonus, genes)
        recs.append({"fn": "awaken", "inputs": {"expression": 0.30, "gene_bonus": {}, "genes": [], "seed": seed},
                     "expected": {"expression": round(expr, 6), "events": events,
                                  "gene_bonus": {k: round(v, 6) for k, v in gene_bonus.items()}, "genes": genes}})
    # current_stats grid (deterministic)
    ceil = {"Bulk": 100, "Celerity": 80, "Ward": 60, "Spike": 140, "Vitality": 90, "Bane": 110, "Luck": 40, "Focus": 70}
    for expr in (0.30, 0.5, 0.75, 1.0):
        for gb in ({}, {"Spike": 0.12}, {"Bulk": 0.24, "Bane": 0.12}):
            recs.append({"fn": "current_stats", "inputs": {"ceiling": ceil, "expression": expr, "gene_bonus": gb},
                         "expected": le.current_stats(ceil, expr, gb)})
    write("level_engine", recs)


# ---- lab_engine -----------------------------------------------------------
def gen_lab():
    recs = []
    mons = [("Ruinmaw", "Chaos", "Thanatos", "T2"), ("Gloamcat", "Thanatos", "Ouranos", "T2"),
            ("Palehart", "Cosmos", "Eros", "T2"), ("Emberwyrm", "Chaos", "Ouranos", "T3"),
            ("Worldback", "Gaia", "Eros", "T3"), ("Augurwing", "Ouranos", "Eros", "T1")]
    n = 0
    for a in mons:
        for b in mons:
            for method in ("precise", "wild"):
                for seed in range(8):
                    r = la.fuse(a, b, method, cr.RNG(seed))
                    recs.append({"fn": "fuse", "inputs": {"a": a, "b": b, "method": method, "seed": seed},
                                 "expected": r})
                    n += 1
    # blend (deterministic) — incl. equal-weight tie cases (§6.4)
    for parts in ([("Chaos", "Thanatos"), ("Thanatos", "Ouranos")], [("Gaia", ""), ("Ouranos", "")],
                  [("Cosmos", "Eros"), ("Chaos", "Eros")], [("Gaia", "Eros"), ("Eros", "Gaia")]):
        p, s = la.blend(parts)
        recs.append({"fn": "blend", "inputs": {"parts": parts}, "expected": {"prim": p, "sec": s}})
    write("lab_engine", recs)


# ---- battle_engine --------------------------------------------------------
def gen_battle():
    recs = []
    for ai, att in enumerate(FORCES):
        for dfn in FORCES:
            recs.append({"fn": "force_mult", "inputs": {"att": att, "dfn": dfn},
                         "expected": be.force_mult(att, dfn)})
    teamsets = [
        ([("Ruinmaw", "Chaos", "Thanatos", "wild", "T2"), ("Gloamcat", "Thanatos", "Ouranos", "wild", "T2")],
         [("Palehart", "Cosmos", "Eros", "wild", "T2"), ("Augurwing", "Ouranos", "Eros", "wild", "T2")]),
        ([("Worldback", "Gaia", "Eros", "wild", "T3")], [("Emberwyrm", "Chaos", "Ouranos", "wild", "T3")]),
        # tie case: equal Celerity (same species both sides) -> initiative tiebreak
        ([("Twin", "Gaia", "Eros", "wild", "T2")], [("Twin", "Gaia", "Eros", "wild", "T2")]),
    ]
    for ti, (ta, tb) in enumerate(teamsets):
        for seed in range(80):
            A = [be.Mon(*m) for m in ta]
            B = [be.Mon(*m) for m in tb]
            log = be.simulate(A, B, cr.RNG(seed))
            recs.append({"fn": "simulate", "inputs": {"teamA": ta, "teamB": tb, "seed": seed},
                         "expected": {"log": log}})
    write("battle_engine", recs)


# ---- skill_engine ---------------------------------------------------------
def gen_skill():
    recs = []
    A_def = [("Worldback", "Gaia", "Eros", "wild", "T3", ["Boulder Smash", "Bulwark"], {}),
             ("Ruinmaw", "Chaos", "Thanatos", "wild", "T2", ["Riot Fang", "Soul Leech"], {"Riot Fang": 3}),
             ("Palehart", "Eros", "Cosmos", "wild", "T2", ["Bloom", "Aegis", "Verdant Gift"], {})]
    B_def = [("Emberwyrm", "Chaos", "Ouranos", "wild", "T2", ["Riot Fang", "Gale Slash"], {}),
             ("Gloamcat", "Thanatos", "Ouranos", "wild", "T2", ["Soul Leech", "Wither"], {}),
             ("Augurwing", "Ouranos", "Eros", "wild", "T2", ["Gale Slash", "Tailwind"], {})]
    for seed in range(200):
        A = [sk.Mon(m[0], m[1], m[2], m[3], m[4], m[5], m[6]) for m in A_def]
        B = [sk.Mon(m[0], m[1], m[2], m[3], m[4], m[5], m[6]) for m in B_def]
        log = sk.battle(A, B, cr.RNG(seed))
        recs.append({"fn": "battle", "inputs": {"A": A_def, "B": B_def, "seed": seed}, "expected": {"log": log}})
    write("skill_engine", recs)


# ---- status_engine (deterministic) ----------------------------------------
def gen_status():
    recs = []
    def snap(c):
        return {"hp": c.hp, "maxhp": c.maxhp, "corruption": c.corruption, "feral": c.feral,
                "status": {k: dict(v) for k, v in c.status.items()}}
    for name in ("Wither", "Bloom-rot", "Petrify", "Shock", "Seal", "Madness"):
        c = st.C("V", "Gaia", "Eros", "T3"); log = []
        st.apply(c, name, log); st.apply(c, name, log) if st.STATUSES[name].get("stack") else None
        st.tick(c, [c], log)
        recs.append({"fn": "apply_tick", "inputs": {"status": name}, "expected": {"state": snap(c), "log": log}})
    for amt in (35, 50, 100, 200):
        c = st.C("V", "Thanatos", "Gaia", "T3"); log = []
        st.add_corruption(c, amt, "test", log)
        recs.append({"fn": "add_corruption", "inputs": {"amt": amt}, "expected": {"state": snap(c), "log": log}})
    write("status_engine", recs)


# ---- loot_engine ----------------------------------------------------------
def gen_loot():
    recs = []
    loadout = ["Beastcaller's Horn", "Geneweaver Gloves", "Sigil of Mercy", "Tyrant's Mantle", "Hephaestus Relic"]
    for method in ("befriend", "trap"):
        for tier in ("T1", "T2", "T3", "legendary", "god"):
            for hp in (1.0, 0.5, 0.2, 0.05):
                for bond in (0, 30, 60):
                    for gear in ([], loadout):
                        for mf in (1.0, 0.8, 1.2):
                            v = lo.capture_chance(method, tier, hp, bond, gear, mf)
                            recs.append({"fn": "capture_chance", "inputs": {"method": method, "tier": tier,
                                         "hp_frac": hp, "bond": bond, "gear": gear, "morality_fit": mf},
                                         "expected": round(v, 6)})
    for gi, gear in enumerate(([], ["Geneweaver Gloves"], ["Luckbone Charm"], loadout)):
        for seed in range(250):
            rare, chance, iv = lo.breed_roll(gear, cr.RNG(seed))
            recs.append({"fn": "breed_roll", "inputs": {"gear": gear, "seed": seed},
                         "expected": {"rare": rare, "chance": round(chance, 6), "iv_ceiling": iv}})
    write("loot_engine", recs)


# ---- character_engine (deterministic) -------------------------------------
def gen_character():
    recs = []
    for d in range(0, 12):
        recs.append({"fn": "rank_for", "inputs": {"deeds": d}, "expected": ce.rank_for(d)})
    for v in range(-100, 101, 5):
        recs.append({"fn": "band3_oc", "inputs": {"v": v}, "expected": ce.band3(v, ["Order", "Balanced", "Chaos"])})
        recs.append({"fn": "band3_pc", "inputs": {"v": v}, "expected": ce.band3(v, ["Pure", "Tainted", "Corrupt"])})
    for k, god in ce.GODS.items():
        recs.append({"fn": "gods", "inputs": {"grid": list(k)}, "expected": god})
    write("character_engine", recs)


if __name__ == "__main__":
    print("Generating golden vectors ->", OUT)
    gen_stat()
    gen_level()
    gen_lab()
    gen_battle()
    gen_skill()
    gen_status()
    gen_loot()
    gen_character()
    print("done.")
