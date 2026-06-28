#!/usr/bin/env python3
"""Canonical RNG — PCG32 (PCG-XSH-RR 64/32), ADR-001.

THE single PRNG for Mutants_Game, implemented bit-identically here and in
client/domain/rng.gd. Every engine takes an injected RNG instance; no engine calls a
stdlib RNG. All arithmetic is explicit 64-bit (mask) so Python (arbitrary precision) and
GDScript (int64, two's-complement wrap) produce identical streams. Verified by
tools/test_rng_parity.py against the GDScript implementation.

Frozen spec:
  multiplier  = 6364136223846793005
  output      = rotr32( ((state>>18) ^ state) >> 27 , state>>59 )   on the PRE-step state
  seeding     = pcg32_srandom(initstate=seed, initseq=DEFAULT_STREAM)
  sub-streams = RNG(splitmix64(parent_seed ^ purpose_const))
"""

MASK64 = (1 << 64) - 1
MASK32 = (1 << 32) - 1
PCG_MULT = 6364136223846793005
DEFAULT_STREAM = 0xDA3E39CB94B95BDB  # fixed default stream/sequence


def splitmix64(x: int) -> int:
    """Deterministic 64-bit mixer — used for seed expansion + sub-stream derivation."""
    x &= MASK64
    z = (x + 0x9E3779B97F4A7C15) & MASK64
    z = ((z ^ (z >> 30)) * 0xBF58476D1CE4E5B9) & MASK64
    z = ((z ^ (z >> 27)) * 0x94D049BB133111EB) & MASK64
    return (z ^ (z >> 31)) & MASK64


def _rotr32(value: int, rot: int) -> int:
    value &= MASK32
    rot &= 31
    return ((value >> rot) | (value << ((-rot) & 31))) & MASK32


class RNG:
    """PCG32 generator. Seed explicitly; derive sub-streams with .substream(purpose)."""

    __slots__ = ("state", "inc", "_seed")

    def __init__(self, seed: int):
        self._seed = seed & MASK64
        self.inc = ((DEFAULT_STREAM << 1) | 1) & MASK64
        self.state = 0
        self._step()
        self.state = (self.state + self._seed) & MASK64
        self._step()

    def _step(self) -> int:
        old = self.state
        self.state = (old * PCG_MULT + self.inc) & MASK64
        xorshifted = (((old >> 18) ^ old) >> 27) & MASK32
        rot = old >> 59
        return _rotr32(xorshifted, rot)

    # ---- public API (each engine call site documents which it uses) ----
    def next_u32(self) -> int:
        return self._step()

    def next_float(self) -> float:
        """[0,1) via the documented u32 / 2^32 construction."""
        return self._step() / 4294967296.0

    def random(self) -> float:
        return self.next_float()

    def uniform(self, a: float, b: float) -> float:
        return a + (b - a) * self.next_float()

    def randint(self, a: int, b: int) -> int:
        """Inclusive [a,b]. Lemire multiply-high (bias-reduced, rejection-free).
        Engine ranges are small, so u32*range fits well within int64 on both sides."""
        rng_range = b - a + 1
        return a + ((self.next_u32() * rng_range) >> 32)

    def choice(self, seq):
        return seq[self.randint(0, len(seq) - 1)]

    def substream(self, purpose: int) -> "RNG":
        return RNG(splitmix64(self._seed ^ (purpose & MASK64)))
