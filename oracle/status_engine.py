#!/usr/bin/env python3
"""Mutants_Game - STATUS engine (v0.1): 6 force-signature statuses + unified Corruption.

Hybrid stacking: DOTs (Wither, Bloom-rot) STACK intensity; control (Petrify/Shock/Seal/Madness)
REFRESH duration. Severity bounded (statuses shape fights, don't auto-kill).
CORRUPTION = one meta-meter fed by overclock-entropy + Lab work + dark afflictions ->
burnout/feral at threshold. Cleansed by Eros Mend / Cosmos dispel (Corruption persists).
"""
import stat_engine as se

STATUSES = {
    "Wither":     dict(force="Thanatos", kind="dot", base=24, stack=True),       # + def down
    "Bloom-rot":  dict(force="Eros",     kind="dot", base=18, stack=True, spread=True),
    "Petrify":    dict(force="Gaia",     kind="control", effect="skip turn",  dur=2),
    "Shock":      dict(force="Ouranos",  kind="control", effect="lose AP",    dur=2),
    "Seal":       dict(force="Cosmos",   kind="control", effect="no skills",  dur=2),
    "Madness":    dict(force="Chaos",    kind="control", effect="act randomly", dur=2),
    "Corruption": dict(kind="meta", threshold=100),
}


class C:
    def __init__(self, name, prim, sec, tier):
        st, hp, bst = se.stat_block(prim, sec, "wild", tier)
        self.name = name; self.hp = hp; self.maxhp = hp; self.stats = st
        self.status = {}; self.corruption = 0; self.feral = False


def apply(c, name, log):
    s = STATUSES[name]
    if s.get("stack"):
        d = c.status.setdefault(name, {"stacks": 0, "dur": 99}); d["stacks"] += 1
        log.append("   " + name + " -> " + c.name + "  (stack " + str(d["stacks"]) + ")")
    else:
        c.status[name] = {"stacks": 1, "dur": s["dur"]}
        log.append("   " + name + " -> " + c.name + "  (refresh, " + str(s["dur"]) + " turns)")


def add_corruption(c, amt, src, log):
    c.corruption = min(130, c.corruption + amt)
    log.append("   " + c.name + " Corruption +" + str(amt) + " (" + src + ")  ->  " + str(c.corruption) + "/100")
    if c.corruption >= 100 and not c.feral:
        c.feral = True
        log.append("   ** " + c.name + " BURNS OUT -> FERAL (acts randomly, -20% stats; bounded - not dead) **")


def tick(c, allies, log):
    for name in list(c.status.keys()):
        s = STATUSES[name]; d = c.status[name]
        if s["kind"] == "dot":
            dmg = s["base"] * d["stacks"]; c.hp = max(0, c.hp - dmg); extra = ""
            if s.get("spread"):
                other = [a for a in allies if a is not c and name not in a.status]
                if other:
                    apply(other[0], name, log); extra = "  (spreads to " + other[0].name + "!)"
            log.append("   " + name + " ticks " + c.name + " -" + str(dmg) + " HP  (" + str(c.hp) + "/" + str(c.maxhp) + ")" + extra)
        elif s["kind"] == "control":
            log.append("   " + c.name + " is " + name + "ed (" + s["effect"] + ") [" + str(d["dur"]) + " left]")
            d["dur"] -= 1
            if d["dur"] <= 0:
                del c.status[name]; log.append("   " + name + " fades on " + c.name)


def cleanse(c, log):
    removed = [k for k in c.status if STATUSES[k]["kind"] != "meta"]
    for k in removed:
        del c.status[k]
    log.append("   Mend cleanses " + c.name + ": " + (", ".join(removed) if removed else "nothing") + "   (Corruption " + str(c.corruption) + " persists)")


if __name__ == "__main__":
    log = []
    v = C("Worldback", "Gaia", "Eros", "T3"); a = C("Palehart", "Eros", "Cosmos", "T2")
    print("=== STATUS SHOWCASE ===  Worldback HP " + str(v.maxhp) + ", Palehart HP " + str(a.maxhp))
    log.append("[Wither] Thanatos DOT - STACKS each application (hybrid):")
    apply(v, "Wither", log); tick(v, [v, a], log)
    apply(v, "Wither", log); tick(v, [v, a], log)
    apply(v, "Wither", log); tick(v, [v, a], log)
    log.append("[Bloom-rot] Eros DOT - spreads to allies:")
    apply(v, "Bloom-rot", log); tick(v, [v, a], log); tick(a, [v, a], log)
    log.append("[Petrify] Gaia control - REFRESH, causes skips, then fades:")
    apply(v, "Petrify", log); tick(v, [v, a], log); tick(v, [v, a], log); tick(v, [v, a], log)
    log.append("[Corruption] ONE meter fed by 3 sources -> burnout:")
    add_corruption(v, 35, "overclock surge", log)
    add_corruption(v, 35, "Lab self-splice", log)
    add_corruption(v, 35, "Wither affliction", log)
    log.append("[Cleanse] Eros Mend clears battle statuses - Corruption stays:")
    cleanse(v, log)
    for l in log:
        print(l)
