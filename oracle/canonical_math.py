#!/usr/bin/env python3
"""Canonical arithmetic — half-to-even rounding, ADR-002.

`rnd(x)` rounds to the nearest integer, ties to even (banker's rounding), implemented
identically here and in client/domain/math.gd. Replaces every `round()` in the engines so
Python (round = half-to-even) and GDScript (round = half-away-from-zero) cannot diverge on
ties. Integer-first math everywhere; floats are only intermediate.
"""
import math


def rnd(x: float) -> int:
    """Round half-to-even. Deterministic + identical in GDScript."""
    f = math.floor(x)
    diff = x - f
    if diff < 0.5:
        return int(f)
    if diff > 0.5:
        return int(f) + 1
    # exact .5 tie -> round to even
    fi = int(f)
    return fi if (fi % 2 == 0) else fi + 1
