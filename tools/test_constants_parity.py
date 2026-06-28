#!/usr/bin/env python3
"""Phase 0 - constants parity test (TDD 6.5, D4).

Asserts that EVERY value in tools/balance_constants.json equals the constant the Python
reference engines actually use TODAY. Three kinds of check, ALL of which compare against the
JSON value (so editing the JSON without changing an engine turns the test RED):
  * eq()  - module-level constants/dicts/lists compared by value, or engine BEHAVIOR (calling
            a function) compared to the JSON value;
  * num() - for literals living inside function bodies: parse the function with `ast`, collect
            its numeric literals, and assert the JSON value is among them (formatting-agnostic,
            scoped to the right function). Catches JSON-side AND engine-side drift.
  * frag()- for a design value that exists in the engine only as display text: assert a
            JSON-DERIVED fragment is present.
This proves the transcription is faithful. It does NOT rewire the engines to import the JSON
(that is Phase 1). Run: python -B tools/test_constants_parity.py
"""
import ast
import inspect
import json
import os
import sys
import textwrap

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ORACLE = os.path.join(ROOT, "oracle")
sys.path.insert(0, ORACLE)

import stat_engine as se
import level_engine as le
import lab_engine as la
import battle_engine as be
import skill_engine as sk
import status_engine as st
import loot_engine as lo
import character_engine as ce

with open(os.path.join(ROOT, "tools", "balance_constants.json"), encoding="utf-8") as fh:
    J = json.load(fh)

fails = []
passes = 0


def eq(label, actual, expected):
    global passes
    if actual == expected:
        passes += 1
    else:
        fails.append("EQ  %-50s engine=%r != json=%r" % (label, actual, expected))


def _func_numbers(obj):
    tree = ast.parse(textwrap.dedent(inspect.getsource(obj)))
    nums = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Constant) and isinstance(node.value, (int, float)) and not isinstance(node.value, bool):
            nums.add(float(node.value))
        if (isinstance(node, ast.UnaryOp) and isinstance(node.op, ast.USub)
                and isinstance(node.operand, ast.Constant) and isinstance(node.operand.value, (int, float))):
            nums.add(-float(node.operand.value))
    return nums


def num(label, obj, expected):
    """Assert the JSON value `expected` is a numeric literal inside engine function `obj`."""
    global passes
    if float(expected) in _func_numbers(obj):
        passes += 1
    else:
        fails.append("NUM %-50s %s() has no literal %r" % (label, obj.__name__, expected))


def frag(label, obj, fragment):
    """Assert a JSON-derived text `fragment` is present in engine function `obj` source."""
    global passes
    if fragment in inspect.getsource(obj):
        passes += 1
    else:
        fails.append("FRG %-50s %s() source missing %r" % (label, obj.__name__, fragment))


# ---- forces (structural) --------------------------------------------------
F = J["forces"]
eq("forces.poles", se.POLES, F["poles"])
eq("forces.stat_of", se.STAT_OF, F["stat_of"])
eq("forces.pole_stats", se.POLE_STATS, F["pole_stats"])
eq("forces.universals", se.UNIVERSALS, F["universals"])
eq("forces.opposed(lab)", la.OPPOSED, F["opposed"])
eq("forces.opposed(battle)", be.OPP, F["opposed"])
eq("forces.opposed(skill)", sk.OPP, F["opposed"])

# ---- stat_engine ----------------------------------------------------------
S = J["stat"]
eq("stat.phi", se.PHI, S["phi"])
eq("stat.genome_lo", se.GENOME_LO, S["genome_lo"])
eq("stat.genome_hi", se.GENOME_HI, S["genome_hi"])
eq("stat.bst.wild_T1", se.BST[("wild", "T1")], S["bst"]["wild_T1"])
eq("stat.bst.wild_T2", se.BST[("wild", "T2")], S["bst"]["wild_T2"])
eq("stat.bst.wild_T3", se.BST[("wild", "T3")], S["bst"]["wild_T3"])
eq("stat.bst.legendary", se.BST[("legendary", "x")], S["bst"]["legendary"])
eq("stat.bst.god", se.BST[("god", "x")], S["bst"]["god"])
eq("stat.bst.primordial", se.BST[("primordial", "x")], S["bst"]["primordial"])
eq("stat.hpbase", se.HPBASE, S["hpbase"])
eq("stat.univ_base", {k: list(v) for k, v in se.UNIV_BASE.items()}, S["univ_base"])
fd = se.force_dist("Gaia", "Ouranos")
eq("stat.force_dist.primary_with_secondary", fd["Gaia"], S["force_dist"]["primary_with_secondary"])
eq("stat.force_dist.secondary", fd["Ouranos"], S["force_dist"]["secondary"])
eq("stat.force_dist.primary_pure", se.force_dist("Gaia", None)["Gaia"], S["force_dist"]["primary_pure"])
cm = se.class_mod({s: 100 for s in se.ALL_STATS}, "construct")
eq("stat.class_mod.Bulk", cm["Bulk"] / 100.0, S["class_mod_construct"]["Bulk"])
eq("stat.class_mod.Ward", cm["Ward"] / 100.0, S["class_mod_construct"]["Ward"])
eq("stat.class_mod.Vitality", cm["Vitality"] / 100.0, S["class_mod_construct"]["Vitality"])
num("stat.hp_per_vitality", se.stat_block, S["hp_per_vitality"])
num("stat.genome_round_dp", se.roll_genome, S["genome_round_dp"])

# ---- level_engine ---------------------------------------------------------
L = J["level"]
eq("level.burnout", le.BURNOUT, L["burnout"])
eq("level.genes", le.GENES, L["genes"])
num("level.expression_start", le.simulate, L["expression_start"])
num("level.gene_bonus_step", le.awaken, L["gene_bonus_step"])
num("level.awaken_surge_lo", le.awaken, L["awaken_surge_lo"])
num("level.awaken_surge_hi", le.awaken, L["awaken_surge_hi"])
num("level.gene_chance", le.awaken, L["gene_chance"])
num("level.branch_chance", le.awaken, L["branch_chance"])
num("level.resonance_chance_base", le.simulate, L["resonance_chance_base"])
num("level.resonance_chance_per_attempt", le.simulate, L["resonance_chance_per_attempt"])
num("level.resonance_chance_cap", le.simulate, L["resonance_chance_cap"])
num("level.resonance_chance_luck_factor", le.simulate, L["resonance_chance_luck_factor"])
num("level.overclock_entropy_lo", le.simulate, L["overclock_entropy_lo"])
num("level.overclock_entropy_hi", le.simulate, L["overclock_entropy_hi"])
num("level.overclock_entropy_threshold", le.simulate, L["overclock_entropy_threshold"])
num("level.burnout_expr_penalty", le.simulate, L["burnout_expr_penalty"])
num("level.burnout_entropy_relief", le.simulate, L["burnout_entropy_relief"])

# ---- lab_engine -----------------------------------------------------------
LB = J["lab"]
eq("lab.next_tier", la.NEXT, LB["next_tier"])
num("lab.blend_primary_weight", la.blend, LB["blend_primary_weight"])
num("lab.blend_secondary_weight", la.blend, LB["blend_secondary_weight"])
num("lab.fuse_entropy_lo", la.fuse, LB["fuse_entropy_lo"])
num("lab.fuse_entropy_hi", la.fuse, LB["fuse_entropy_hi"])
num("lab.taboo_entropy_bonus", la.fuse, LB["taboo_entropy_bonus"])
num("lab.wild_method_entropy_reduction", la.fuse, LB["wild_method_entropy_reduction"])
num("lab.wild_method_entropy_floor", la.fuse, LB["wild_method_entropy_floor"])
num("lab.taboo_corruption", la.fuse, LB["taboo_corruption"])

# ---- battle_engine --------------------------------------------------------
B = J["battle"]
eq("battle.force_mult_opposed", be.force_mult("Cosmos", "Chaos"), B["force_mult_opposed"])
eq("battle.force_mult_same", be.force_mult("Gaia", "Gaia"), B["force_mult_same"])
eq("battle.force_mult_neutral", be.force_mult("Gaia", "Cosmos"), B["force_mult_neutral"])
num("battle.overload_mult", be.attack, B["overload_mult"])
num("battle.overload_chance", be.simulate, B["overload_chance"])
num("battle.crit_mult", be.attack, B["crit_mult"])
num("battle.crit_luck_divisor", be.attack, B["crit_luck_divisor"])
num("battle.damage_k", be.attack, B["damage_k"])
num("battle.single_hit_cap_frac", be.attack, B["single_hit_cap_frac"])
num("battle.entropy_step_per_turn", be.simulate, B["entropy_step_per_turn"])
num("battle.chain_mult", be.simulate, B["chain_mult"])
num("battle.turn_cap", be.simulate, B["turn_cap"])

# ---- skill_engine ---------------------------------------------------------
SK = J["skill"]
eq("skill.library", sk.SKILLS, SK["library"])
eq("skill.force_mult_opposed", sk.force_mult("Cosmos", "Chaos"), SK["force_mult_opposed"])
eq("skill.force_mult_same", sk.force_mult("Gaia", "Gaia"), SK["force_mult_same"])
eq("skill.force_mult_neutral", sk.force_mult("Gaia", "Cosmos"), SK["force_mult_neutral"])
num("skill.damage_k", sk.damage, SK["damage_k"])
num("skill.rank_mult_step", sk.rank_mult, SK["rank_mult_step"])
num("skill.combo_mult", sk.act, SK["combo_mult"])
num("skill.entropy_step_per_turn(current 0.08)", sk.battle, SK["entropy_step_per_turn"])
num("skill.act_mend_hp_threshold", sk.act, SK["act_mend_hp_threshold"])
num("skill.act_ward_hp_threshold", sk.act, SK["act_ward_hp_threshold"])
num("skill.act_rouse_chance", sk.act, SK["act_rouse_chance"])
num("skill.turn_cap", sk.battle, SK["turn_cap"])
# canonical entropy step (TDD §6.5 ratified) is linked to battle's value, not skill's
eq("skill.entropy_canonical==battle", SK["entropy_step_per_turn_canonical"], B["entropy_step_per_turn"])

# ---- status_engine --------------------------------------------------------
ST = J["status"]
eq("status.statuses", st.STATUSES, ST["statuses"])
num("status.corruption_cap", st.add_corruption, ST["corruption_cap"])
num("status.feral_threshold", st.add_corruption, ST["feral_threshold"])
# feral_stat_penalty exists in the engine only as display text ("-20% stats"); derive the fragment.
frag("status.feral_stat_penalty", st.add_corruption, "-%d%% stats" % round(ST["feral_stat_penalty"] * 100))

# ---- loot_engine ----------------------------------------------------------
LO = J["loot"]
eq("loot.slots", lo.SLOTS, LO["slots"])
eq("loot.rarity", lo.RARITY, LO["rarity"])
eq("loot.tier_factor", lo.TIER_FACTOR, LO["tier_factor"])
eq("loot.gear", lo.GEAR, LO["gear"])
num("loot.capture_base.befriend", lo.capture_chance, LO["capture_base"]["befriend"])
num("loot.capture_base.trap", lo.capture_chance, LO["capture_base"]["trap"])
num("loot.capture_hp_mult_const", lo.capture_chance, LO["capture_hp_mult_const"])
num("loot.capture_hp_mult_lo", lo.capture_chance, LO["capture_hp_mult_lo"])
num("loot.capture_hp_mult_hi", lo.capture_chance, LO["capture_hp_mult_hi"])
num("loot.capture_bond_factor", lo.capture_chance, LO["capture_bond_factor"])
num("loot.capture_clamp_lo", lo.capture_chance, LO["capture_clamp_lo"])
num("loot.capture_clamp_hi", lo.capture_chance, LO["capture_clamp_hi"])
num("loot.breed_rare_base", lo.breed_roll, LO["breed_rare_base"])
num("loot.breed_rare_clamp_lo", lo.breed_roll, LO["breed_rare_clamp_lo"])
num("loot.breed_rare_clamp_hi", lo.breed_roll, LO["breed_rare_clamp_hi"])
num("loot.breed_iv_ceiling_base", lo.breed_roll, LO["breed_iv_ceiling_base"])
num("loot.breed_iv_ceiling_rare_bonus", lo.breed_roll, LO["breed_iv_ceiling_rare_bonus"])
num("loot.breed_iv_ceiling_round_dp", lo.breed_roll, LO["breed_iv_ceiling_round_dp"])

# ---- character_engine -----------------------------------------------------
C = J["character"]
eq("character.ranks", ce.RANKS, C["ranks"])
eq("character.events", ce.EVENTS, C["events"])
eq("character.gods", {("|".join(k)): v for k, v in ce.GODS.items()}, C["gods"])
eq("character.notoriety", [list(x) for x in ce.NOTO], C["notoriety_thresholds"])
for _t in C["rank_deed_thresholds"]:
    num("character.rank_deed_thresholds[%s]" % _t, ce.rank_for, _t)
num("character.axis_clamp_lo", ce.clamp, C["axis_clamp_lo"])
num("character.axis_clamp_hi", ce.clamp, C["axis_clamp_hi"])
num("character.band3_lo", ce.band3, C["band3_lo"])
num("character.band3_hi", ce.band3, C["band3_hi"])

# ---- report ---------------------------------------------------------------
print("constants parity: %d checks passed, %d failed" % (passes, len(fails)))
if fails:
    print("\nFAILURES:")
    for f in fails:
        print("  " + f)
    sys.exit(1)
print("OK - balance_constants.json is faithful to the engines (eq + ast-numeric + derived-fragment).")
