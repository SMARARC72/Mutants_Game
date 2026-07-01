#!/usr/bin/env python3
"""Slice battle-backdrop contact sheets (TILE-061..072) into semantic panels.

Source sheets live in the MAIN repo art dump (gitignored there):
    <src>/TILE-061_gaia-mountain-ledge.png .. TILE-072_tundra-waste.png  (1024x576 each)

Sheet anatomy (verified by band analysis, see detect_bands / --analyze):
  * TILE-061/063/064/066 - full-width panels stacked vertically, separated by
    dark caption-banner strips (brass text on near-black, e.g. "GAIA - MOUNTAIN
    LEDGE").  Consecutive sheets are sliding windows over the same virtual
    column, so panels cut at a sheet edge continue on a later sheet.
  * TILE-062/065 - 2x2 grid windows over a 2-column variant layout (black
    vertical gutter at x~506-522) with the same banner strips.
  * TILE-067..072 - a horizontal filmstrip of full-height biome panels
    separated by black gutters; each ~600px-wide scene may be split across two
    neighbouring sheets.
  Split fragments were verified pixel-continuous (butt-joint seam MSE is in
  the same range as internal adjacent-row MSE, best overlap = 0), so STITCHES
  below rejoin them losslessly.  No resampling anywhere - native panel res.

Outputs (relative to repo root):
  client/assets/backdrops/<semantic_name>.png          - sliced panels
  client/assets/backdrops/<name>_battle.png            - dimmed variants of the
        six force panels (brightness x0.62, saturation x0.85) for HUD contrast
  client/assets/backdrops/manifest.json                - {force_or_biome: [files]}
        (list order: primary, primary battle variant, then _b variants)

Usage:
  python tools/slice_backdrops.py [--src DIR] [--out DIR] [--qa PATH] [--analyze]
"""

from __future__ import annotations

import argparse
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFont

DEFAULT_SRC = (
    "c:/Users/arahi/Documents/Claude/Projects/Mutants_Game/assets/tiles/backdrop"
)
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_OUT = os.path.join(REPO_ROOT, "client", "assets", "backdrops")

SHEETS = {
    61: "TILE-061_gaia-mountain-ledge.png",
    62: "TILE-062_ouranos-sky-temple.png",
    63: "TILE-063_cosmos-ordered-sanctum.png",
    64: "TILE-064_chaos-volcanic-rift.png",
    65: "TILE-065_eros-blooming-grove.png",
    66: "TILE-066_thanatos-moonlit-graveyard.png",
    67: "TILE-067_desert-ruin.png",
    68: "TILE-068_glacier-cavern.png",
    69: "TILE-069_abyssal-trench.png",
    70: "TILE-070_jungle-clearing.png",
    71: "TILE-071_swamp-mire.png",
    72: "TILE-072_tundra-waste.png",
}

# Whole panels: name -> (sheet, (x0, y0, x1, y1)).  Boxes exclude banners and
# gutters (derived from dark-band detection, then visually QA'd).
PANELS = {
    "gaia_mountain_ledge": (61, (0, 35, 1024, 357)),
    "ouranos_sky_temple": (63, (0, 35, 1024, 381)),
    "eros_blooming_grove": (64, (0, 233, 1024, 576)),
    "thanatos_graveyard": (66, (0, 233, 1024, 576)),
    "gaia_mountain_ledge_b": (62, (0, 34, 506, 380)),
    "ouranos_sky_temple_b": (62, (521, 34, 1024, 380)),
    "eros_blooming_grove_b": (65, (0, 243, 506, 576)),
    "thanatos_graveyard_b": (65, (522, 243, 1024, 576)),
    "desert_ruin": (67, (0, 0, 601, 576)),
    "abyssal_trench": (68, (214, 0, 809, 576)),
    "swamp_mire": (69, (421, 0, 1024, 576)),
    "tundra_waste": (70, (0, 0, 601, 576)),
    "void_rift": (71, (213, 0, 810, 576)),
    "aurora_altar": (72, (421, 0, 1024, 576)),
}

# Panels split across two sheets: name -> (axis, [(sheet, box), (sheet, box)]).
# axis "v": first fragment on top; axis "h": first fragment on the left.
STITCHES = {
    "cosmos_sanctum": ("v", [(61, (0, 430, 1024, 576)), (64, (0, 0, 1024, 183))]),
    "chaos_volcanic_rift": (
        "v",
        [(63, (0, 430, 1024, 576)), (66, (0, 0, 1024, 183))],
    ),
    "cosmos_sanctum_b": ("v", [(62, (0, 430, 506, 576)), (65, (0, 0, 506, 182))]),
    "chaos_volcanic_rift_b": (
        "v",
        [(62, (522, 430, 1024, 576)), (65, (522, 0, 1024, 182))],
    ),
    "glacier_cavern": ("h", [(67, (615, 0, 1024, 576)), (68, (0, 0, 198, 576))]),
    "jungle_clearing": ("h", [(68, (827, 0, 1024, 576)), (69, (0, 0, 399, 576))]),
    "crystal_cavern": ("h", [(70, (615, 0, 1024, 576)), (71, (0, 0, 197, 576))]),
    "temple_ruin": ("h", [(71, (827, 0, 1024, 576)), (72, (0, 0, 406, 576))]),
}

# The six occult forces -> their primary battle panel; extra keys are biomes.
FORCE_PRIMARY = {
    "gaia": "gaia_mountain_ledge",
    "ouranos": "ouranos_sky_temple",
    "cosmos": "cosmos_sanctum",
    "chaos": "chaos_volcanic_rift",
    "eros": "eros_blooming_grove",
    "thanatos": "thanatos_graveyard",
}
BIOME_PRIMARY = {
    "desert": "desert_ruin",
    "glacier": "glacier_cavern",
    "abyss": "abyssal_trench",
    "jungle": "jungle_clearing",
    "swamp": "swamp_mire",
    "tundra": "tundra_waste",
    "crystal": "crystal_cavern",
    "void": "void_rift",
    "ruin": "temple_ruin",
    "aurora": "aurora_altar",
}


def detect_bands(gray: np.ndarray) -> dict:
    """Report near-black separator bands (banners / gutters) in a sheet."""

    def runs(mask: np.ndarray, min_run: int = 5) -> list:
        out, start = [], None
        for i, flag in enumerate(mask):
            if flag and start is None:
                start = i
            elif not flag and start is not None:
                if i - start >= min_run:
                    out.append((start, i))
                start = None
        if start is not None and len(mask) - start >= min_run:
            out.append((start, len(mask)))
        return out

    row_frac = (gray < 55).mean(axis=1)
    col_frac = (gray < 40).mean(axis=0)
    return {"rows": runs(row_frac > 0.90), "cols": runs(col_frac > 0.95)}


def _trim_pass(arr: np.ndarray, threshold: int, frac: float, cap: int) -> np.ndarray:
    gray = arr.mean(axis=2)
    top = bottom = left = right = 0
    height, width = gray.shape
    while top < cap and (gray[top] < threshold).mean() > frac:
        top += 1
    while bottom < cap and (gray[height - 1 - bottom] < threshold).mean() > frac:
        bottom += 1
    while left < cap and (gray[:, left] < threshold).mean() > frac:
        left += 1
    while right < cap and (gray[:, width - 1 - right] < threshold).mean() > frac:
        right += 1
    return arr[top : height - bottom, left : width - right]


def trim_dark_edges(arr: np.ndarray) -> np.ndarray:
    """Crop residual black frame bands / banner slivers at panel edges.

    Pass 1: effectively-black bands (sheet frame, render fade) up to 48px.
    Pass 2: near-black slivers (banner edges, gutter residue) up to 10px.
    """
    arr = _trim_pass(arr, threshold=25, frac=0.95, cap=48)
    return _trim_pass(arr, threshold=34, frac=0.93, cap=10)


def battle_variant(img: Image.Image) -> Image.Image:
    """Dim + slightly desaturate a panel so HUD text stays readable over it."""
    out = ImageEnhance.Brightness(img).enhance(0.62)
    return ImageEnhance.Color(out).enhance(0.85)


def build_qa_sheet(entries: list, qa_path: str) -> None:
    """entries: [(label, Image)] -> labeled contact grid for visual review."""
    thumb_w, pad, label_h, cols = 330, 10, 30, 4
    try:
        font = ImageFont.load_default(size=15)
    except TypeError:  # older Pillow
        font = ImageFont.load_default()
    thumbs = []
    for label, img in entries:
        scale = thumb_w / img.width
        thumb = img.resize((thumb_w, max(1, round(img.height * scale))))
        thumbs.append((label, thumb))
    row_heights = []
    for i in range(0, len(thumbs), cols):
        row = thumbs[i : i + cols]
        row_heights.append(max(t.height for _, t in row) + label_h)
    sheet_w = cols * (thumb_w + pad) + pad
    sheet_h = sum(row_heights) + pad * (len(row_heights) + 1)
    sheet = Image.new("RGB", (sheet_w, sheet_h), (23, 19, 28))
    draw = ImageDraw.Draw(sheet)
    y = pad
    for i in range(0, len(thumbs), cols):
        row = thumbs[i : i + cols]
        for j, (label, thumb) in enumerate(row):
            x = pad + j * (thumb_w + pad)
            draw.text((x, y), label, fill=(224, 185, 90), font=font)
            sheet.paste(thumb, (x, y + label_h - 8))
        y += row_heights[i // cols] + pad
    os.makedirs(os.path.dirname(qa_path), exist_ok=True)
    sheet.save(qa_path)
    print(f"QA sheet: {qa_path}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--src", default=DEFAULT_SRC)
    parser.add_argument("--out", default=DEFAULT_OUT)
    parser.add_argument("--qa", default=None, help="write labeled QA sheet here")
    parser.add_argument(
        "--analyze", action="store_true", help="print detected bands and exit"
    )
    args = parser.parse_args()

    sheets = {}
    for num, fname in SHEETS.items():
        path = os.path.join(args.src, fname)
        if not os.path.isfile(path):
            print(f"ERROR: missing source sheet {path}", file=sys.stderr)
            return 1
        sheets[num] = np.asarray(Image.open(path).convert("RGB"), dtype=np.uint8)

    if args.analyze:
        for num in sorted(sheets):
            bands = detect_bands(sheets[num].mean(axis=2))
            print(f"{SHEETS[num]}: rows={bands['rows']} cols={bands['cols']}")
        return 0

    os.makedirs(args.out, exist_ok=True)
    panels: dict = {}

    def crop(sheet_num: int, box: tuple) -> np.ndarray:
        x0, y0, x1, y1 = box
        return sheets[sheet_num][y0:y1, x0:x1]

    for name, (sheet_num, box) in PANELS.items():
        panels[name] = trim_dark_edges(crop(sheet_num, box))

    for name, (axis, parts) in STITCHES.items():
        frags = [crop(num, box) for num, box in parts]
        if axis == "v":
            width = min(f.shape[1] for f in frags)
            joined = np.concatenate([f[:, :width] for f in frags], axis=0)
        else:
            height = min(f.shape[0] for f in frags)
            joined = np.concatenate([f[:height] for f in frags], axis=1)
        panels[name] = trim_dark_edges(joined)

    saved: dict = {}
    for name, arr in sorted(panels.items()):
        img = Image.fromarray(arr)
        img.save(os.path.join(args.out, f"{name}.png"))
        saved[name] = img
        print(f"  {name}.png  {img.width}x{img.height}")

    for force, primary in FORCE_PRIMARY.items():
        variant = battle_variant(saved[primary])
        variant.save(os.path.join(args.out, f"{primary}_battle.png"))
        saved[f"{primary}_battle"] = variant
        print(f"  {primary}_battle.png  ({force} dim variant)")

    manifest: dict = {}
    for force, primary in FORCE_PRIMARY.items():
        files = [f"{primary}.png", f"{primary}_battle.png"]
        if f"{primary}_b" in saved:
            files.append(f"{primary}_b.png")
        manifest[force] = files
    for biome, primary in BIOME_PRIMARY.items():
        manifest[biome] = [f"{primary}.png"]
    manifest_path = os.path.join(args.out, "manifest.json")
    with open(manifest_path, "w", encoding="utf-8", newline="\n") as handle:
        json.dump(manifest, handle, indent=2)
        handle.write("\n")
    print(f"manifest: {manifest_path}")

    if args.qa:
        entries = [
            (f"{name}  {img.width}x{img.height}", img)
            for name, img in sorted(saved.items())
        ]
        build_qa_sheet(entries, args.qa)
    return 0


if __name__ == "__main__":
    sys.exit(main())
