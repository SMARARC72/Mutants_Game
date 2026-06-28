#!/usr/bin/env python3
"""Emit client/tests/rng_vectors.json from the canonical Python RNG (ADR-001).

Both tools/test_rng_parity.py (Python) and client/tests/rng_parity_test.gd (GDScript) assert
against this one file, so a green GDScript run proves the GDScript RNG is bit-identical to the
Python oracle RNG. Run: python -B tools/gen_rng_vectors.py
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "oracle"))
import canonical_rng as cr
import canonical_math as cm

SEEDS = [0, 7, 11, 42, 123456789, 2654435761]

vec = {"u32": {}, "next_float": {}, "randint": [], "uniform": [], "substream": [], "rnd": []}

for s in SEEDS:
    r = cr.RNG(s)
    vec["u32"][str(s)] = [r.next_u32() for _ in range(12)]
    r = cr.RNG(s)
    vec["next_float"][str(s)] = [r.next_float() for _ in range(6)]

for s, a, b in [(7, 12, 24), (11, 16, 30), (1, 0, 1), (5, 1, 6), (99, 0, 99)]:
    r = cr.RNG(s)
    vec["randint"].append({"seed": s, "a": a, "b": b, "vals": [r.randint(a, b) for _ in range(12)]})

for s, a, b in [(7, 0.10, 0.22), (3, 0.10, 0.90), (8, 1.0, 1.5)]:
    r = cr.RNG(s)
    vec["uniform"].append({"seed": s, "a": a, "b": b, "vals": [r.uniform(a, b) for _ in range(6)]})

# substream parity proven via the sub-stream's first u32 (< 2^32, JSON-exact; avoids the
# signed/unsigned 64-bit ambiguity between Python and GDScript).
for s, p in [(42, 99), (7, 1), (123456789, 424242)]:
    vec["substream"].append({"seed": s, "purpose": p, "first_u32": cr.RNG(s).substream(p).next_u32()})

for x in [0.0, 0.5, 1.5, 2.5, 3.5, -0.5, -1.5, -2.5, 2.4, 2.6, 171.0, 170.5, 962.5, 0.49999, 0.50001]:
    vec["rnd"].append({"x": x, "r": cm.rnd(x)})

out = os.path.join(ROOT, "client", "tests", "rng_vectors.json")
with open(out, "w", encoding="utf-8") as fh:
    json.dump(vec, fh, indent=2)
print("wrote", out, "-", len(SEEDS), "seeds,", len(vec["randint"]), "randint cases,", len(vec["rnd"]), "rnd cases")
