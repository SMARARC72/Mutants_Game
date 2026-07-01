#!/usr/bin/env python3
"""Deterministic CC0 audio synthesis for Mutants_Game (WAVE-SND "Sound Exists").

Generates every UI/SFX/ambience asset under client/assets/audio/ from a fixed seed:
44.1 kHz, 16-bit mono WAV, peaks normalized to -12 dBFS headroom. Re-running the
script reproduces byte-identical files. numpy + stdlib `wave` only — no new deps.

All output is generated in-repo and dedicated to the public domain (CC0) — see
client/assets/audio/PROVENANCE.md.

Usage:  PYTHONUTF8=1 python tools/gen_audio.py
"""

import wave
from pathlib import Path

import numpy as np

SR = 44100
PEAK = 0.25  # ~ -12 dBFS
SEED = 0x4D5554  # "MUT"
ROOT = Path(__file__).resolve().parents[1] / "client" / "assets" / "audio"


# ── plumbing ────────────────────────────────────────────────────────────────


def write_wav(rel: str, samples: np.ndarray) -> None:
    path = ROOT / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    x = np.asarray(samples, dtype=np.float64)
    peak = float(np.max(np.abs(x)))
    if peak > 0.0:
        x = x * (PEAK / peak)
    data = (np.clip(x, -1.0, 1.0) * 32767.0).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(f"  {rel:44s} {len(x) / SR:6.2f}s")


def t(dur: float) -> np.ndarray:
    return np.arange(int(SR * dur)) / SR


def env_exp(n: int, tau: float) -> np.ndarray:
    return np.exp(-np.arange(n) / (SR * tau))


def fft_band(x: np.ndarray, lo: float, hi: float) -> np.ndarray:
    """Soft 4th-order band-pass via FFT masking (lo/hi in Hz; 0 disables an edge)."""
    spec = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1.0 / SR)
    mask = np.ones_like(freqs)
    if lo > 0.0:
        mask *= 1.0 / (1.0 + (lo / np.maximum(freqs, 1e-9)) ** 4)
    if hi > 0.0:
        mask *= 1.0 / (1.0 + (freqs / hi) ** 4)
    return np.fft.irfft(spec * mask, n=len(x))


def crossfade_loop(x: np.ndarray, fade_s: float = 1.0) -> np.ndarray:
    """Seamless loop: blend the tail into the head, trim the tail."""
    f = int(SR * fade_s)
    out = x[: len(x) - f].copy()
    r = np.linspace(0.0, 1.0, f)
    out[:f] = x[len(x) - f:] * (1.0 - r) + x[:f] * r
    return out


def mix_at(out: np.ndarray, x: np.ndarray, at_s: float) -> None:
    """Add x into out starting at at_s seconds, clipping to out's length."""
    off = int(SR * at_s)
    n = min(len(x), len(out) - off)
    if n > 0:
        out[off: off + n] += x[:n]


def saw_partials(freq: float, tt: np.ndarray, n_partials: int = 8) -> np.ndarray:
    x = np.zeros_like(tt)
    for k in range(1, n_partials + 1):
        x += np.sin(2.0 * np.pi * freq * k * tt) / k
    return x


def fm_bell(freq: float, dur: float, index: float = 2.2, ratio: float = 1.4,
            tau: float = 0.6) -> np.ndarray:
    tt = t(dur)
    mod = np.sin(2.0 * np.pi * freq * ratio * tt) * index * np.exp(-tt / (tau * 0.7))
    return np.sin(2.0 * np.pi * freq * tt + mod) * np.exp(-tt / tau)


def tone(freq: float, dur: float, tau: float = 0.25, attack: float = 0.012) -> np.ndarray:
    """Brass-ish tone: three warm partials, soft attack, exponential release."""
    tt = t(dur)
    x = (np.sin(2.0 * np.pi * freq * tt)
         + 0.4 * np.sin(2.0 * np.pi * freq * 2.0 * tt)
         + 0.22 * np.sin(2.0 * np.pi * freq * 3.0 * tt))
    env = env_exp(len(tt), tau)
    a = int(SR * attack)
    env[:a] *= np.linspace(0.0, 1.0, a)
    return x * env


# ── one-shots ───────────────────────────────────────────────────────────────


def ui_click(rng: np.random.Generator) -> np.ndarray:
    n = int(SR * 0.05)
    x = np.zeros(n)
    burst = int(SR * 0.002)
    x[:burst] = rng.uniform(-1.0, 1.0, burst)
    return fft_band(x, 1200.0, 6500.0) * env_exp(n, 0.008)


def ui_confirm() -> np.ndarray:
    out = np.zeros(int(SR * 0.85))
    mix_at(out, tone(392.0, 0.5, tau=0.12), 0.0)
    mix_at(out, tone(523.25, 0.7, tau=0.2) * 0.9, 0.11)
    return fft_band(out, 120.0, 4200.0)


def footstep(rng: np.random.Generator, pitch: float) -> np.ndarray:
    dur = 0.11
    n = int(SR * dur)
    x = fft_band(rng.uniform(-1.0, 1.0, n), 60.0, 560.0 * pitch) * env_exp(n, 0.02)
    thump = np.sin(2.0 * np.pi * (85.0 * pitch) * t(dur)) * env_exp(n, 0.03)
    return x + 0.9 * thump


def hit_crunch(rng: np.random.Generator) -> np.ndarray:
    dur = 0.22
    n = int(SR * dur)
    noise = fft_band(rng.uniform(-1.0, 1.0, n), 180.0, 3200.0) * env_exp(n, 0.03)
    tt = t(dur)
    thump = np.sin(2.0 * np.pi * (70.0 - 25.0 * tt / dur) * tt) * env_exp(n, 0.06)
    return noise + 1.2 * thump


def death_knell() -> np.ndarray:
    dur = 2.8
    out = np.zeros(int(SR * dur))
    out += fm_bell(220.0, dur, tau=0.55)
    # Subtle detuned second strike.
    mix_at(out, fm_bell(223.5, dur - 0.9, tau=0.5) * 0.55, 0.9)
    return fft_band(out, 60.0, 5200.0)


def capture_sting() -> np.ndarray:
    dur = 1.3
    out = np.zeros(int(SR * dur))
    for i, (freq, at) in enumerate([(440.0, 0.0), (554.37, 0.16), (659.25, 0.34)]):
        x = fm_bell(freq, dur - at, index=1.2, ratio=2.0, tau=0.35) * (0.7 + 0.15 * i)
        mix_at(out, x, at)
    return fft_band(out, 150.0, 6000.0)


def boss_swell(rng: np.random.Generator) -> np.ndarray:
    dur = 3.0
    tt = t(dur)
    n = len(tt)
    drone = fft_band(saw_partials(55.0, tt) + 0.6 * saw_partials(82.5, tt), 30.0, 900.0)
    noise = fft_band(rng.uniform(-1.0, 1.0, n), 40.0, 300.0) * 0.5
    swell = (tt / dur) ** 2.2
    release = np.ones(n)
    r = int(SR * 0.25)
    release[-r:] = np.linspace(1.0, 0.0, r)
    return (drone + noise) * swell * release


def veil_whisper(rng: np.random.Generator) -> np.ndarray:
    dur = 1.9
    n = int(SR * dur)
    x = fft_band(rng.uniform(-1.0, 1.0, n), 900.0, 2600.0)
    tt = t(dur)
    swell = np.sin(np.pi * tt / dur) ** 1.5
    tremolo = 1.0 + 0.25 * np.sin(2.0 * np.pi * 7.3 * tt)
    return x * swell * tremolo


# ── seamless beds (generated 1s long, crossfade-trimmed to the loop length) ─


def ambience_marsh(rng: np.random.Generator) -> np.ndarray:
    dur = 21.0
    n = int(SR * dur)
    brown = np.cumsum(rng.uniform(-1.0, 1.0, n))
    brown -= np.mean(brown)
    bed = fft_band(brown, 25.0, 320.0)
    bed /= np.max(np.abs(bed))
    tt = t(dur)
    out = bed * (0.8 + 0.2 * np.sin(2.0 * np.pi * tt * 2.0 / dur))
    for _ in range(14):  # sparse soft blips / croaks
        at = rng.uniform(0.5, dur - 1.0)
        f0 = rng.uniform(140.0, 260.0)
        bl = rng.uniform(0.08, 0.3)
        bt = t(bl)
        chirp = np.sin(2.0 * np.pi * (f0 - 30.0 * bt / bl) * bt)
        am = 1.0 + 0.6 * np.sin(2.0 * np.pi * rng.uniform(18.0, 30.0) * bt)
        blip = chirp * am * np.sin(np.pi * bt / bl) ** 2 * rng.uniform(0.1, 0.25)
        mix_at(out, blip, at)
    return crossfade_loop(out, 1.0)


def battle_drone(rng: np.random.Generator) -> np.ndarray:
    dur = 17.0
    tt = t(dur)
    n = len(tt)
    drone = fft_band(
        saw_partials(55.0, tt, 10) + 0.5 * saw_partials(55.5, tt, 6), 30.0, 700.0
    )
    lfo = 0.75 + 0.25 * np.sin(2.0 * np.pi * tt * 3.0 / dur)  # slow amplitude LFO
    noise = fft_band(rng.uniform(-1.0, 1.0, n), 50.0, 220.0) * 0.35
    return crossfade_loop(drone * lfo + noise, 1.0)


def menu_bed(rng: np.random.Generator) -> np.ndarray:
    dur = 21.0
    tt = t(dur)
    freqs = [110.0, 110.35, 164.8, 165.1, 220.2]
    amps = [1.0, 0.9, 0.5, 0.45, 0.3]
    pad = np.zeros(len(tt))
    for freq, amp in zip(freqs, amps):
        pad += amp * np.sin(2.0 * np.pi * freq * tt + rng.uniform(0.0, 2.0 * np.pi))
    dark = fft_band(pad, 40.0, 380.0)
    bright = fft_band(pad, 40.0, 1400.0)
    sweep = 0.5 + 0.5 * np.sin(2.0 * np.pi * tt * 2.0 / dur)  # slow filter sweep
    return crossfade_loop(dark * (1.0 - sweep) * 0.9 + bright * sweep * 0.6, 1.2)


def main() -> None:
    rng = np.random.default_rng(SEED)
    print(f"gen_audio.py -> {ROOT}  (seed 0x{SEED:X}, {SR} Hz, peak {PEAK})")
    write_wav("ui/ui_click.wav", ui_click(rng))
    write_wav("ui/ui_confirm.wav", ui_confirm())
    for i, pitch in enumerate((0.85, 1.0, 1.12, 1.25), start=1):
        write_wav(f"sfx/footstep_{i}.wav", footstep(rng, pitch))
    write_wav("sfx/hit_crunch.wav", hit_crunch(rng))
    write_wav("sfx/death_knell.wav", death_knell())
    write_wav("sfx/capture_sting.wav", capture_sting())
    write_wav("sfx/boss_swell.wav", boss_swell(rng))
    write_wav("sfx/veil_whisper.wav", veil_whisper(rng))
    write_wav("ambience/ambience_marsh_loop.wav", ambience_marsh(rng))
    write_wav("ambience/battle_drone_loop.wav", battle_drone(rng))
    write_wav("ambience/menu_bed_loop.wav", menu_bed(rng))
    print("done.")


if __name__ == "__main__":
    main()
