#!/usr/bin/env python3
"""Promote the painterly icon set from the main-repo /assets library into the game (Wave 4).

Source: <src>/  (gitignored art library; 256px painterly icons authored on near-black card)
Dest:   client/assets/icons/painterly/<category>/<original-stem>.png  (128px RGBA, keyed out)

Pipeline per icon (mirror of the creature-plate white-knockout, inverted for black):
  1. KNOCKOUT — flood from the border ring over near-black pixels (threshold derived from
     the border-ring median colour) so only background connected to the edge is removed —
     dark paint INSIDE the artwork survives. Skipped when the border ring is already
     transparent (the library icons ship pre-keyed; this keeps the run idempotent).
  2. FEATHER — a 1px soften on the knockout edge so the cut doesn't alias.
  3. DOWNSCALE — 256 -> 128 LANCZOS on premultiplied alpha (no black fringing).

Deterministic, dependency-light (PIL + numpy). Re-running produces identical bytes.

Run:  python -B tools/promote_icons.py
      python -B tools/promote_icons.py --src <art-library>/icons --sheet <qa>/icons_sheet.png
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_SRC = "C:/Users/arahi/Documents/Claude/Projects/Mutants_Game/assets/icons"
DEST = os.path.join(ROOT, "client", "assets", "icons", "painterly")
BODY_FONT = os.path.join(ROOT, "client", "assets", "fonts", "Alegreya.ttf")

OUT_SIZE = 128
NEAR_BLACK_LUMA = 60  # a border median darker than this counts as a "near-black card"
KNOCK_TOL = 46  # euclidean RGB distance from the border median that still reads as card
INK = (23, 19, 28, 255)  # GrimoirePalette.INK — QA sheet backdrop
PARCHMENT = (232, 221, 196, 255)  # GrimoirePalette.PARCHMENT — QA labels + alt cells

# Hand-audited QA fixes (Wave 4 contact-sheet review): crop-spillover debris from
# neighbouring icons on the source card, erased as (x0, y0, x1, y1) boxes in the
# 256px source space. Keyed by "<category>/<stem>". Everything else ships untouched.
QA_ERASE = {
    # a stray purple smear below the emblem (fragment of another icon's crop)
    "forces/ICON-001_gaia-force": [(92, 228, 150, 250)],
    # a golden ring-sliver left of the seed trunk (fragment of another icon's crop)
    "lab_verbs/ICON-032_evolve": [(52, 118, 78, 198)],
}


def _border_ring(arr):
    """The 1px border ring of an (H, W, 4) array as an (N, 4) pixel list."""
    return np.concatenate([arr[0, :], arr[-1, :], arr[:, 0], arr[:, -1]])


def _flood_from_border(card_mask):
    """Boolean flood fill: the subset of card_mask 4-connected to the image border."""
    seed = np.zeros_like(card_mask)
    seed[0, :] = card_mask[0, :]
    seed[-1, :] = card_mask[-1, :]
    seed[:, 0] = card_mask[:, 0]
    seed[:, -1] = card_mask[:, -1]
    while True:
        grown = seed.copy()
        grown[1:, :] |= seed[:-1, :]
        grown[:-1, :] |= seed[1:, :]
        grown[:, 1:] |= seed[:, :-1]
        grown[:, :-1] |= seed[:, 1:]
        grown &= card_mask
        if np.array_equal(grown, seed):
            return seed
        seed = grown


def knockout_black(img):
    """Key out a border-connected near-black card. Returns (RGBA image, was_keyed)."""
    arr = np.asarray(img.convert("RGBA")).astype(np.float64)
    ring = _border_ring(arr)
    ring_alpha = np.median(ring[:, 3])
    if ring_alpha < 128:
        return img.convert("RGBA"), False  # already keyed by the library — nothing to do
    bg = np.median(ring[:, :3], axis=0)
    if bg.mean() > NEAR_BLACK_LUMA:
        return img.convert("RGBA"), False  # not a near-black card; leave it alone
    dist = np.sqrt(((arr[..., :3] - bg) ** 2).sum(axis=2))
    card = (dist <= KNOCK_TOL) & (arr[..., 3] > 0)
    bg_mask = _flood_from_border(card)
    keep = 1.0 - bg_mask.astype(np.float64)
    # 1px feather: average each keep value with its 4-neighbourhood so the cut edge softens.
    padded = np.pad(keep, 1, mode="edge")
    blurred = (
        padded[1:-1, 1:-1]
        + padded[:-2, 1:-1]
        + padded[2:, 1:-1]
        + padded[1:-1, :-2]
        + padded[1:-1, 2:]
    ) / 5.0
    feathered = np.minimum(keep, blurred)  # only soften OUTWARD (never re-grow background)
    arr[..., 3] = arr[..., 3] * feathered
    return Image.fromarray(arr.round().astype(np.uint8), "RGBA"), True


def downscale(img, size):
    """LANCZOS resize on premultiplied alpha, then un-premultiply (kills dark halos)."""
    arr = np.asarray(img.convert("RGBA")).astype(np.float64)
    alpha = arr[..., 3:4] / 255.0
    pre = np.concatenate([arr[..., :3] * alpha, arr[..., 3:4]], axis=2)
    small = np.asarray(
        Image.fromarray(pre.round().astype(np.uint8), "RGBA").resize((size, size), Image.LANCZOS)
    ).astype(np.float64)
    out_alpha = small[..., 3:4]
    safe = np.maximum(out_alpha, 1.0)
    rgb = np.clip(small[..., :3] * 255.0 / safe, 0, 255)
    out = np.concatenate([rgb, out_alpha], axis=2)
    return Image.fromarray(out.round().astype(np.uint8), "RGBA")


def promote_all(src):
    """Process every <src>/<category>/*.png. Returns [(category, stem, dest_path, keyed)]."""
    rows = []
    for category in sorted(os.listdir(src)):
        cat_dir = os.path.join(src, category)
        if not os.path.isdir(cat_dir):
            continue
        for fname in sorted(os.listdir(cat_dir)):
            if not fname.lower().endswith(".png"):
                continue
            stem = os.path.splitext(fname)[0]
            keyed_img, keyed = knockout_black(Image.open(os.path.join(cat_dir, fname)))
            for x0, y0, x1, y1 in QA_ERASE.get("%s/%s" % (category, stem), []):
                arr = np.asarray(keyed_img).copy()
                arr[y0:y1, x0:x1, 3] = 0
                keyed_img = Image.fromarray(arr, "RGBA")
            out = downscale(keyed_img, OUT_SIZE)
            out_dir = os.path.join(DEST, category)
            os.makedirs(out_dir, exist_ok=True)
            dest = os.path.join(out_dir, stem + ".png")
            out.save(dest, optimize=True)
            rows.append((category, stem, dest, keyed))
    return rows


def contact_sheet(rows, sheet_path, cols=6):
    """Labeled QA grid: every promoted icon on alternating ink/parchment cells."""
    cell_w, cell_h, pad = OUT_SIZE + 24, OUT_SIZE + 46, 12
    grid_rows = (len(rows) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cell_w + pad * 2, grid_rows * cell_h + pad * 2), INK)
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype(BODY_FONT, 13)
    except OSError:
        font = ImageFont.load_default()
    for i, (category, stem, dest, _keyed) in enumerate(rows):
        cx = pad + (i % cols) * cell_w
        cy = pad + (i // cols) * cell_h
        on_parchment = (i % cols + i // cols) % 2 == 1
        cell_bg = PARCHMENT if on_parchment else INK
        draw.rectangle([cx, cy, cx + cell_w - 4, cy + OUT_SIZE + 8], fill=cell_bg)
        icon = Image.open(dest).convert("RGBA")
        sheet.alpha_composite(icon, (cx + (cell_w - OUT_SIZE) // 2, cy + 4))
        label = "%s/%s" % (category, stem.replace("ICON-", ""))
        text_col = PARCHMENT
        draw.text((cx + 4, cy + OUT_SIZE + 14), label, fill=text_col, font=font)
    os.makedirs(os.path.dirname(sheet_path), exist_ok=True)
    sheet.save(sheet_path)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--src", default=DEFAULT_SRC, help="painterly icon library root")
    ap.add_argument("--sheet", default="", help="write a labeled QA contact sheet PNG here")
    args = ap.parse_args()
    if not os.path.isdir(args.src):
        print("source library not found:", args.src)
        return 1
    rows = promote_all(args.src)
    keyed_count = sum(1 for r in rows if r[3])
    print("promoted %d icons -> %s (%d knocked out here, %d pre-keyed)" % (
        len(rows), os.path.relpath(DEST, ROOT), keyed_count, len(rows) - keyed_count))
    if args.sheet:
        contact_sheet(rows, args.sheet)
        print("QA sheet:", args.sheet)
    return 0 if rows else 1


if __name__ == "__main__":
    sys.exit(main())
