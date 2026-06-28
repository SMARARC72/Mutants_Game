#!/usr/bin/env python3
"""Assert the Python canonical RNG reproduces client/tests/rng_vectors.json exactly.

Pins the Python side to the committed reference (the GDScript side asserts the same file).
Run: python -B tools/test_rng_parity.py
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "oracle"))
import canonical_rng as cr
import canonical_math as cm

with open(os.path.join(ROOT, "client", "tests", "rng_vectors.json"), encoding="utf-8") as fh:
    V = json.load(fh)

fails = []
n = 0


def eq(label, a, b):
    global n
    n += 1
    if a != b:
        fails.append("%s: got %r != expected %r" % (label, a, b))


def approx(label, a, b):
    global n
    n += 1
    if abs(a - b) > 1e-12:
        fails.append("%s: got %r != expected %r" % (label, a, b))


for s, vals in V["u32"].items():
    r = cr.RNG(int(s))
    eq("u32[%s]" % s, [r.next_u32() for _ in vals], vals)

for s, vals in V["next_float"].items():
    r = cr.RNG(int(s))
    for i, exp in enumerate(vals):
        approx("float[%s][%d]" % (s, i), r.next_float(), exp)

for c in V["randint"]:
    r = cr.RNG(c["seed"])
    eq("randint(%d..%d)" % (c["a"], c["b"]), [r.randint(c["a"], c["b"]) for _ in c["vals"]], c["vals"])

for c in V["uniform"]:
    r = cr.RNG(c["seed"])
    for i, exp in enumerate(c["vals"]):
        approx("uniform[%d]" % i, r.uniform(c["a"], c["b"]), exp)

for c in V["substream"]:
    eq("substream(%d,%d)" % (c["seed"], c["purpose"]), cr.RNG(c["seed"]).substream(c["purpose"]).next_u32(), c["first_u32"])

for c in V["rnd"]:
    eq("rnd(%r)" % c["x"], cm.rnd(c["x"]), c["r"])

print("RNG parity (python vs vectors): %d checks, %d failed" % (n, len(fails)))
if fails:
    for f in fails:
        print("  " + f)
    sys.exit(1)
print("OK - python canonical RNG matches rng_vectors.json")
