#!/usr/bin/env python3
"""Procedural grimoire UI kit (Wave 4) — deterministic PIL/numpy, no source art needed.

Outputs (both routed through GrimoirePalette hexes — no new colours):
  client/assets/ui/parchment_tile.png   256px SEAMLESS aged-parchment texture: PARCHMENT
                                        base + low-contrast fibre noise and mottling.
                                        (FFT low-pass noise is periodic, hence tileable.)
  client/assets/ui/parchment_frame.png  96px 9-patch-able panel frame: parchment fill,
                                        3px BRASS double-rule border + corner notches.
                                        Consumed by GrimoireTheme's "ParchmentPanel"
                                        StyleBoxTexture (24px texture/content margins).

  client/assets/ui/boot_splash.png      1152x648 boot splash (Wave 6): brass eight-point
                                        sigil star centered on INK #17131c — shown by the
                                        engine the instant the window exists, so the ~5s
                                        boot never reads as a hang. project.godot points
                                        application/boot_splash at it (bg_color = INK).

Deterministic (fixed seed) — re-running yields identical bytes. Run:
  python -B tools/gen_ui_kit.py
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "client", "assets", "ui")
SEED = 0x9210AE  # grimoire constant — change = re-author the paper

# GrimoirePalette (client/presentation/ui/theme/grimoire_palette.gd)
PARCHMENT = (0xE8, 0xDD, 0xC4)
PARCHMENT_DIM = (0xD4, 0xC7, 0xA8)
BRASS = (0xB9, 0x93, 0x3F)
BRASS_BRIGHT = (0xE0, 0xB9, 0x5A)
INK = (0x17, 0x13, 0x1C)

TILE_SIZE = 256
FRAME_SIZE = 96
FRAME_MARGIN = 24  # must match GrimoireTheme's ParchmentPanel texture margin
SPLASH_W, SPLASH_H = 1152, 648  # the project's design half-res 16:9 (crisp at any window)


def _periodic_noise(rng, size, sigma_y, sigma_x):
    """Zero-mean smooth noise, PERIODIC in both axes (FFT gaussian low-pass), unit-ish range."""
    white = rng.standard_normal((size, size))
    fy = np.fft.fftfreq(size)[:, None]
    fx = np.fft.fftfreq(size)[None, :]
    lowpass = np.exp(-0.5 * ((fy * size / max(sigma_y, 1e-6)) ** 2 + (fx * size / max(sigma_x, 1e-6)) ** 2))
    smooth = np.real(np.fft.ifft2(np.fft.fft2(white) * lowpass))
    peak = np.abs(smooth).max()
    return smooth / peak if peak > 0 else smooth


def parchment_field(size, rng):
    """(size, size, 3) uint8 aged-parchment: PARCHMENT base, mottling toward PARCHMENT_DIM,
    fine fibre streaks. Low contrast by construction (blend weights are small)."""
    mottle = _periodic_noise(rng, size, size / 6.0, size / 6.0)  # broad damp-stain blotches
    grain = _periodic_noise(rng, size, size / 48.0, size / 48.0)  # paper grain
    fibre_h = _periodic_noise(rng, size, size / 90.0, size / 5.0)  # horizontal chain-lines
    fibre_v = _periodic_noise(rng, size, size / 5.0, size / 90.0)  # vertical laid-lines
    base = np.array(PARCHMENT, dtype=np.float64)
    dim = np.array(PARCHMENT_DIM, dtype=np.float64)
    # Mottling leans toward the pressed/dim parchment; keep it subtle (<= ~30% blend).
    t = np.clip(0.16 + 0.14 * mottle, 0.0, 0.34)[..., None]
    rgb = base * (1.0 - t) + dim * t
    # Fibres + grain ride as small luminance offsets (low contrast: +-4 levels max).
    lum = 2.2 * grain + 1.6 * fibre_h + 1.2 * fibre_v
    rgb = np.clip(rgb + lum[..., None], 0, 255)
    return rgb.round().astype(np.uint8)


def gen_tile(path):
    rng = np.random.default_rng(SEED)
    Image.fromarray(parchment_field(TILE_SIZE, rng), "RGB").save(path, optimize=True)


def gen_frame(path):
    """96px 9-patch frame: parchment paper, a 3px BRASS outer rule + 1px inner rule
    (the double rule), and notched brass corner squares. Border art stays inside the
    24px margin band so StyleBoxTexture edge-stretching never distorts it."""
    rng = np.random.default_rng(SEED + 1)
    img = Image.fromarray(parchment_field(FRAME_SIZE, rng), "RGB").convert("RGBA")
    draw = ImageDraw.Draw(img)
    last = FRAME_SIZE - 1
    # Outer rule: 3px brass, inset 2 (rows/cols 2..4).
    for i in range(2, 5):
        draw.rectangle([i, i, last - i, last - i], outline=BRASS)
    # Inner rule: 1px brass, inset 9 — the second rule of the double border.
    draw.rectangle([9, 9, last - 9, last - 9], outline=BRASS)
    # A whisper of ink shadow just inside the inner rule (settles the page). Pre-blended
    # opaque (PIL draws raw RGBA — an alpha'd outline would punch a hole in the panel).
    shadow = tuple(round(p * 0.85 + i * 0.15) for p, i in zip(PARCHMENT, INK))
    draw.rectangle([10, 10, last - 10, last - 10], outline=shadow)
    # Corner notches: a brass square straddling the rules with an ink pip, in each corner
    # region (inside the 24px 9-patch corner so it never stretches).
    for cx, cy in ((6, 6), (last - 6, 6), (6, last - 6), (last - 6, last - 6)):
        draw.rectangle([cx - 4, cy - 4, cx + 4, cy + 4], fill=BRASS)
        draw.rectangle([cx - 4, cy - 4, cx + 4, cy + 4], outline=BRASS_BRIGHT)
        draw.rectangle([cx - 1, cy - 1, cx + 1, cy + 1], fill=INK)
    img.save(path, optimize=True)


def gen_boot_splash(path):
    """1152x648 boot splash: the brass eight-point sigil star (the same crest the player
    token / main menu carry — long cardinal rays, short diagonals, ring + bright hub)
    centered on flat INK. Pure geometry, no rng — identical bytes every run."""
    img = Image.new("RGB", (SPLASH_W, SPLASH_H), INK)
    draw = ImageDraw.Draw(img)
    cx, cy = SPLASH_W / 2.0, SPLASH_H / 2.0
    r_long, r_short = 190.0, 118.0
    for i in range(8):
        ang = math.pi / 4.0 * i
        reach = r_long if i % 2 == 0 else r_short
        half = 11.0 if i % 2 == 0 else 7.5  # ray half-width at the hub
        tip = (cx + math.cos(ang) * reach, cy + math.sin(ang) * reach)
        left = (cx + math.cos(ang + math.pi / 2) * half, cy + math.sin(ang + math.pi / 2) * half)
        right = (cx + math.cos(ang - math.pi / 2) * half, cy + math.sin(ang - math.pi / 2) * half)
        draw.polygon([tip, left, right], fill=BRASS)
    # Sigil ring around the star + a bright hub — the medallion read.
    ring_r = r_long + 28.0
    draw.ellipse([cx - ring_r, cy - ring_r, cx + ring_r, cy + ring_r], outline=BRASS, width=3)
    draw.ellipse([cx - ring_r + 8, cy - ring_r + 8, cx + ring_r - 8, cy + ring_r - 8],
                 outline=BRASS, width=1)
    draw.ellipse([cx - 15, cy - 15, cx + 15, cy + 15], fill=BRASS_BRIGHT)
    img.save(path, optimize=True)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    tile = os.path.join(OUT_DIR, "parchment_tile.png")
    frame = os.path.join(OUT_DIR, "parchment_frame.png")
    splash = os.path.join(OUT_DIR, "boot_splash.png")
    gen_tile(tile)
    gen_frame(frame)
    gen_boot_splash(splash)
    for p in (tile, frame, splash):
        print("wrote", os.path.relpath(p, ROOT))
    return 0


if __name__ == "__main__":
    sys.exit(main())
