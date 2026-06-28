#!/usr/bin/env python3
"""Coverage lint for client/catalog/splice_rules.json (Mutants_Game SpliceRules.md §7).

The Lab Legality Engine's ruleset is DATA (ADR-015). This lint proves the ruleset is structurally
sound and cross-referentially consistent BEFORE the GDScript CSP ever runs it -- the same checks
SpliceRules.gd performs at load time, but runnable in plain Python in CI (no Godot needed):

  * schema_version == 1; every required top-level key present.
  * the six forces are all defined.
  * every opposed pair references DEFINED forces, is a 2-tuple, and is symmetric (no pair listed in
    both directions -- force_is_opposed treats [a,b] as covering [b,a]).
  * the three thresholds (T_abom, T_god, T_self) and three unlocks are defined.
  * the five operations exist, each with an `inputs` block; every gate references a defined threshold
    and/or unlock and/or part.
  * every ingredient/gene references only DEFINED forces and classes; every ingredient `slot` exists
    in trait_slots; every trait_slot `accepts` entry is a known ingredient-or-organ token.
  * bridge parts reference known ingredient types or ids.

Exit 0 = sound. Exit 1 = at least one violation (printed). Run: python -B tools/test_splice_rules_coverage.py
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RULES_PATH = os.path.join(ROOT, "client", "catalog", "splice_rules.json")

REQUIRED_TOP = ["schema_version", "forces", "opposed", "thresholds", "unlocks",
                "operations", "trait_slots", "ingredient_compat"]
REQUIRED_FORCES = ["Gaia", "Ouranos", "Cosmos", "Chaos", "Eros", "Thanatos"]
REQUIRED_OPS = ["fuse", "mutate", "graft", "self_splice", "reanimate"]
REQUIRED_THRESHOLDS = ["T_abom", "T_god", "T_self"]
REQUIRED_UNLOCKS = ["abomination_rites", "auto_chirurgy", "necromancy"]
REQUIRED_CLASSES = ["organic", "construct", "hybrid"]


def load_rules(path):
    with open(path, "r", encoding="utf-8") as fh:
        return json.load(fh)


def check(rules):
    """Return a list of violation strings (empty = sound)."""
    errs = []

    # --- top level ---------------------------------------------------------
    for key in REQUIRED_TOP:
        if key not in rules:
            errs.append("missing top-level key: %s" % key)
    if errs:
        return errs  # nothing else is safe to inspect

    if rules.get("schema_version") != 1:
        errs.append("schema_version must be 1 (got %r)" % rules.get("schema_version"))

    forces = rules["forces"]
    force_set = set(forces)
    for fc in REQUIRED_FORCES:
        if fc not in force_set:
            errs.append("forces missing required force: %s" % fc)

    classes = set(rules.get("classes", REQUIRED_CLASSES))
    for cls in REQUIRED_CLASSES:
        if cls not in classes:
            errs.append("classes missing required class: %s" % cls)

    # --- thresholds + unlocks ---------------------------------------------
    thresholds = rules["thresholds"]
    for t in REQUIRED_THRESHOLDS:
        if t not in thresholds:
            errs.append("thresholds missing: %s" % t)
        elif not isinstance(thresholds[t], (int, float)):
            errs.append("threshold %s must be numeric" % t)
    unlocks = set(rules["unlocks"])
    for u in REQUIRED_UNLOCKS:
        if u not in unlocks:
            errs.append("unlocks missing: %s" % u)

    # --- opposed pairs: defined, 2-tuple, symmetric ------------------------
    seen_pairs = set()
    for pair in rules["opposed"]:
        if not isinstance(pair, list) or len(pair) != 2:
            errs.append("opposed entry is not a 2-element pair: %r" % (pair,))
            continue
        a, b = pair[0], pair[1]
        if a not in force_set:
            errs.append("opposed pair references undefined force: %s" % a)
        if b not in force_set:
            errs.append("opposed pair references undefined force: %s" % b)
        if (b, a) in seen_pairs:
            errs.append("opposed pair listed in both directions: [%s,%s]" % (a, b))
        seen_pairs.add((a, b))

    # --- operations + gates ------------------------------------------------
    ops = rules["operations"]
    for op in REQUIRED_OPS:
        if op not in ops:
            errs.append("operations missing: %s" % op)
            continue
        spec = ops[op]
        if not isinstance(spec, dict):
            errs.append("operation %s is not an object" % op)
            continue
        if "inputs" not in spec:
            errs.append("operation %s missing 'inputs'" % op)
        gate = spec.get("taboo_when", {}).get("gate", {})
        if "corruption" in gate and gate["corruption"] not in thresholds:
            errs.append("operation %s gate references undefined threshold: %s"
                        % (op, gate["corruption"]))
        for ukey in ("or_unlock", "requires_unlock"):
            if ukey in gate and gate[ukey] not in unlocks:
                errs.append("operation %s gate references undefined unlock: %s"
                            % (op, gate[ukey]))

    # --- ingredient_compat: forces + classes + slots ----------------------
    trait_slots = rules["trait_slots"]
    compat = rules["ingredient_compat"]
    known_ingredients = set(compat.keys())
    # Ingredient TYPES span both organ ingredients (ingredient_compat) and genes (gene_compat).
    known_types = {spec.get("type") for spec in compat.values() if spec.get("type")}
    known_types |= {spec.get("type") for spec in rules.get("gene_compat", {}).values() if spec.get("type")}
    for ing, spec in compat.items():
        for fc in spec.get("forces", []):
            if fc not in force_set:
                errs.append("ingredient %s references undefined force: %s" % (ing, fc))
        for cls in spec.get("class", []):
            if cls not in classes:
                errs.append("ingredient %s references undefined class: %s" % (ing, cls))
        slot = spec.get("slot")
        if slot is not None and slot not in trait_slots:
            errs.append("ingredient %s references undefined slot: %s" % (ing, slot))

    # --- gene_compat: forces + classes ------------------------------------
    for gene, spec in rules.get("gene_compat", {}).items():
        for fc in spec.get("forces", []):
            if fc not in force_set:
                errs.append("gene %s references undefined force: %s" % (gene, fc))
        for cls in spec.get("class", []):
            if cls not in classes:
                errs.append("gene %s references undefined class: %s" % (gene, cls))

    # --- trait_slots: enforce the documented invariants (accepts non-empty, max>=1, refs exist) ---
    for slot, sdef in trait_slots.items():
        accepts = sdef.get("accepts", [])
        if not accepts:
            errs.append("trait_slot %s has an empty/absent accepts list" % slot)
        slot_max = sdef.get("max", 1)
        if not isinstance(slot_max, int) or slot_max < 1:
            errs.append("trait_slot %s max must be an int >= 1 (got %r)" % (slot, slot_max))
        for accept in accepts:
            # Every accepts token must be a DEFINED ingredient id (catches typos in either direction).
            if accept not in known_ingredients:
                errs.append("trait_slot %s accepts undefined ingredient: %s" % (slot, accept))
        # conflicts_with entries must reference defined slots (a slot may list itself = capacity rule).
        for cw in sdef.get("conflicts_with", []):
            if cw not in trait_slots:
                errs.append("trait_slot %s conflicts_with undefined slot: %s" % (slot, cw))

    # every ingredient that names a slot must be in that slot's accepts list (cross-ref both ways)
    for ing, spec in compat.items():
        slot = spec.get("slot")
        if slot in trait_slots:
            accepts = trait_slots[slot].get("accepts", [])
            if ing not in accepts:
                errs.append("ingredient %s declares slot %s but is not in its accepts list"
                            % (ing, slot))

    # --- gene conflicts_with references defined genes -----------------------
    gene_ids = set(rules.get("gene_compat", {}).keys())
    for gene, spec in rules.get("gene_compat", {}).items():
        for cw in spec.get("conflicts_with", []):
            if cw not in gene_ids:
                errs.append("gene %s conflicts_with undefined gene: %s" % (gene, cw))

    # --- data<->engine drift: every op key the engine consumes is authored & well-formed ----------
    # The engine reads inputs, tier_rule.raise_with, slots (per-type caps), taboo_when.flags/gate. If
    # an op is missing a key the engine relies on, behavior silently degrades -> flag it here.
    for op, spec in ops.items():
        tier_rule = spec.get("tier_rule", {})
        if "raise_with" in tier_rule and not isinstance(tier_rule["raise_with"], list):
            errs.append("operation %s tier_rule.raise_with must be a list" % op)
        for raiser in tier_rule.get("raise_with", []):
            if raiser not in known_types:
                errs.append("operation %s tier_rule.raise_with references unknown type: %s" % (op, raiser))
        for type_name in spec.get("slots", {}):
            if type_name not in known_types:
                errs.append("operation %s slots references unknown ingredient type: %s" % (op, type_name))
        taboo = spec.get("taboo_when", {})
        for flag in taboo.get("flags", []):
            if flag not in ("taboo", "abomination", "god_graft", "reanimated", "chimera"):
                errs.append("operation %s taboo_when.flags has unknown flag: %s" % (op, flag))

    # --- bridges: parts reference known types or ids -----------------------
    for part in rules.get("bridges", {}).get("parts", []):
        if part not in known_types and part not in known_ingredients:
            errs.append("bridge part references unknown type/ingredient: %s" % part)

    return errs


def main():
    if not os.path.exists(RULES_PATH):
        print("FAIL: splice_rules.json not found at %s" % RULES_PATH)
        return 1
    try:
        rules = load_rules(RULES_PATH)
    except (ValueError, OSError) as exc:
        print("FAIL: could not parse splice_rules.json: %s" % exc)
        return 1

    errs = check(rules)
    if errs:
        print("splice_rules coverage lint: FAIL (%d violation(s))" % len(errs))
        for e in errs:
            print("  - %s" % e)
        return 1

    print("splice_rules coverage lint: OK")
    print("  forces=%d ops=%d ingredients=%d genes=%d trait_slots=%d" % (
        len(rules["forces"]), len(rules["operations"]), len(rules["ingredient_compat"]),
        len(rules.get("gene_compat", {})), len(rules["trait_slots"])))
    return 0


if __name__ == "__main__":
    sys.exit(main())
