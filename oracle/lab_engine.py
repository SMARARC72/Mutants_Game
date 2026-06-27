#!/usr/bin/env python3
"""Mutants_Game - LAB engine (v0.1): whole-creature Creator operations.

Proves every operation resolves to stat-spine numbers + a COST LEDGER.
Operations: fuse / mutate / build / mod / sacrifice (fuse + self-splice shown).
Costs: routine -> creature ENTROPY (instability); big/taboo -> PLAYER CORRUPTION.
Methods: precise (Cosmos: deterministic, costly) | wild (Chaos: cheaper, variance).
Parts = ingredients (organs/genes/cores/scrap), harvested 4 ways, cooked freeform or by recipe.
"""
import random
import stat_engine as se

OPPOSED = {"Cosmos": "Chaos", "Chaos": "Cosmos", "Eros": "Thanatos",
           "Thanatos": "Eros", "Gaia": "Ouranos", "Ouranos": "Gaia"}
NEXT = {"T1": "T2", "T2": "T3", "T3": "T3"}


def blend(parts):
    w = {p: 0.0 for p in se.POLES}
    for prim, sec in parts:
        w[prim] += 0.6
        if sec:
            w[sec] += 0.4
    order = sorted(se.POLES, key=lambda p: -w[p])
    return order[0], (order[1] if w[order[1]] > 0 else "")


def fuse(a, b, method, seed):
    rng = random.Random(seed)
    nA, pA, sA, tA = a
    nB, pB, sB, tB = b
    prim, sec = blend([(pA, sA), (pB, sB)])
    tier = NEXT[tA] if (tA == "T3" and tB == "T3") else max(tA, tB)
    taboo = OPPOSED.get(pA) == pB
    stats, hp, bst = se.stat_block(prim, sec, "wild", tier, "organic")
    entropy = rng.randint(12, 24) + (28 if taboo else 0)
    if method == "wild":
        entropy = max(6, entropy - 9)
    corruption = 18 if taboo else 0
    return dict(name=nA + " x " + nB, prim=prim, sec=sec, tier=tier,
                stats=stats, hp=hp, bst=bst, taboo=taboo,
                entropy=entropy, corruption=corruption, method=method)


def show(r):
    print("  -> " + r["name"] + "  [" + r["prim"] + "/" + (r["sec"] or "pure") + " " + r["tier"] + "]   " +
          "  ".join(k + " " + str(r["stats"][k]) for k in se.POLE_STATS))
    tag = "   ** TABOO ABOMINATION: world bounty **" if r["taboo"] else ""
    print("     HP " + str(r["hp"]) + " | BST " + str(r["bst"]) + " | method=" + r["method"] +
          " | cost: creature entropy +" + str(r["entropy"]) + ", player corruption +" + str(r["corruption"]) + tag)


if __name__ == "__main__":
    print("=== LAB SESSION ===")
    print()
    print("[FUSE] Ruinmaw (Chaos/Thanatos T2) x Gloamcat (Thanatos/Ouranos T2)  -- compatible, precise")
    show(fuse(("Ruinmaw", "Chaos", "Thanatos", "T2"), ("Gloamcat", "Thanatos", "Ouranos", "T2"), "precise", 1))
    print()
    print("[FUSE] Palehart (Cosmos/Eros T2) x Emberwyrm (Chaos/Ouranos T3)  -- OPPOSED forces, wild")
    show(fuse(("Palehart", "Cosmos", "Eros", "T2"), ("Emberwyrm", "Chaos", "Ouranos", "T3"), "wild", 2))
    print()
    print("[SELF-SPLICE] graft a Thanatos god-organ into the PLAYER (forbidden)")
    print("  -> you gain force-power: Deathtouch (Thanatos lifesteal aura)")
    print("     cost: player corruption +35  ->  locks the Pure/Mercy ending, world turns hostile, abominations obey you")
    print()
    print("(mutate / build / mod follow the same shape: whole creature + ingredients -> stat-spine output + ledger)")
