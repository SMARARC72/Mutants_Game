"""W-DRESS structure pipeline — turns the raw painterly ISO dioramas in
<main repo>/assets/tiles/iso into game-ready overworld STRUCTURE cutouts under
client/assets/tiles/structures/ plus a structures.json manifest the overworld consumes.

The raw plates were exported with their transparency FLATTENED TO PURE BLACK (the shipped
alpha channel just re-keys those black pixels), so the painted dioramas are SPARSE strokes
with real holes — a naive knockout (the make_tiles border-median flood alone) leaves a
moth-eaten cutout the terrain bleeds through (verified on the first QA sheet, rejected).
This pipeline therefore RECONSTRUCTS the structure body: threshold the painted strokes,
morphologically CLOSE them into a silhouette, keep the main cluster (plus its near scatter),
flood-fill interior holes from the border (the established _flood_from_border), then back the
strokes with a solid grimoire-INK wash inside that silhouette — the cutout reads as an
ink-dark structure with painted lit detail, matching the game's ink/parchment language.
Filenames were eye-verified against the rendered plates (contact-sheet audit, the same
discipline as tools/tile_remap.json) — the STRUCTURES map below is that audit.

Deterministic: same inputs -> same outputs. PIL + numpy only.

Usage:  python tools/make_structures.py [--src DIR] [--repo DIR] [--qa PATH]
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image

import make_tiles as mt

TOOLS_DIR = Path(__file__).resolve().parent
REPO_DIR = TOOLS_DIR.parent
# Source art lives in the MAIN repo (top-level /assets is gitignored -> absent in worktrees).
DEFAULT_SRC = Path("c:/Users/arahi/Documents/Claude/Projects/Mutants_Game/assets/tiles/iso")

# Eye-verified plate -> semantic structure map. height_tiles is how tall the structure stands
# in the overworld (the screen scales the cutout to height_tiles * TILE_SIZE); footprint is the
# walkable-BLOCKING cell rectangle (w, h) centred on the anchor cell. `lift` gently raises the
# midtones of the very dark plates so they read over painterly terrain (1.0 = untouched).
STRUCTURES = {
    # TILE-021 graveyard-plot REJECTED on the QA sheet: too sparse to reconstruct a readable
    # body (disconnected ash blobs) — the Thanatos palette leans on ruin/portal instead.
    "temple": {"src": "TILE-022_templeshrine.png", "height_tiles": 2.4, "footprint": [3, 2], "lift": 1.2, "solo": True},
    "forge": {"src": "TILE-023_labforge-floor.png", "height_tiles": 1.6, "footprint": [2, 2], "lift": 1.2, "solo": True},
    "ruin": {"src": "TILE-024_ancient-ruin.png", "height_tiles": 2.0, "footprint": [3, 2], "lift": 1.25},
    "altar": {"src": "TILE-026_ascension-altar-platform.png", "height_tiles": 2.5, "footprint": [2, 2], "lift": 1.0},
    "market_stall": {"src": "TILE-027_townmarket-tile.png", "height_tiles": 1.6, "footprint": [2, 1], "lift": 1.3},
    "portal": {"src": "TILE-028_summon-portal.png", "height_tiles": 2.0, "footprint": [2, 2], "lift": 1.0},
    "bridge": {"src": "TILE-029_stone-bridge.png", "height_tiles": 1.6, "footprint": [2, 1], "lift": 1.3},
    "grove": {"src": "TILE-030_forest-grove.png", "height_tiles": 2.0, "footprint": [2, 2], "lift": 1.35},
}

MAX_DIM = 1024  # the W2 asset-contract cap (tools/check_asset_contract.py)
STROKE_THR = 6  # max-channel value above which a pixel counts as painted (sheet black is 0)
CLOSE_R = 9  # closing radius: bridges the stroke gaps inside a structure body
MIN_BLOB = 260  # px: scatter blobs below this never join the cutout (floating-island guard)
SCATTER_REACH = 14  # px: how far past the main body's bbox kept scatter may sit
INK_WASH = np.array([26.0, 21.0, 32.0])  # the solid backing inside the silhouette (~GrimoirePalette.INK)


def _lift_midtones(rgb: np.ndarray, lift: float) -> np.ndarray:
    """Gentle midtone gain (gamma-style) so ink-dark dioramas read over terrain."""
    if lift <= 1.0:
        return rgb
    x = np.clip(rgb, 0.0, 255.0) / 255.0
    return np.power(x, 1.0 / lift) * 255.0


def _dilate(mask: np.ndarray, r: int) -> np.ndarray:
    return mt._box_blur(mask.astype(np.float64), r) > 1e-9


def _erode(mask: np.ndarray, r: int) -> np.ndarray:
    return mt._box_blur(mask.astype(np.float64), r) > 1.0 - 1e-9


def _components(mask: np.ndarray) -> list[np.ndarray]:
    """4-connected components of a boolean mask (row/col run-based flood; pure numpy + stack)."""
    labels = np.zeros(mask.shape, dtype=np.int32)
    comps: list[np.ndarray] = []
    h, w = mask.shape
    for sy, sx in zip(*np.nonzero(mask)):
        if labels[sy, sx]:
            continue
        label = len(comps) + 1
        stack = [(int(sy), int(sx))]
        labels[sy, sx] = label
        while stack:
            cy, cx = stack.pop()
            for ny, nx in ((cy - 1, cx), (cy + 1, cx), (cy, cx - 1), (cy, cx + 1)):
                if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not labels[ny, nx]:
                    labels[ny, nx] = label
                    stack.append((ny, nx))
        comps.append(labels == label)
    return comps


def _keep_main_cluster(body: np.ndarray, solo: bool = False) -> np.ndarray:
    """The largest closed blob plus every blob whose bbox nears it (the diorama's ground scatter);
    lone far speckles are dropped so the footprint stays honest. `solo` keeps ONLY the main blob
    (plates whose scatter reads as floating chips on the QA sheet)."""
    comps = _components(body)
    if not comps:
        return body
    comps.sort(key=lambda c: int(c.sum()), reverse=True)
    main = comps[0]
    if solo:
        return main
    ys, xs = np.nonzero(main)
    y0, y1 = ys.min() - SCATTER_REACH, ys.max() + SCATTER_REACH
    x0, x1 = xs.min() - SCATTER_REACH, xs.max() + SCATTER_REACH
    out = main.copy()
    for c in comps[1:]:
        if int(c.sum()) < MIN_BLOB:
            continue
        cys, cxs = np.nonzero(c)
        if cys.min() <= y1 and cys.max() >= y0 and cxs.min() <= x1 and cxs.max() >= x0:
            out |= c
    return out


def process_structure(src: Path, dst: Path, lift: float, solo: bool = False) -> bool:
    """One structure plate -> a solid RGBA cutout (ink-backed silhouette + painted strokes)."""
    img = Image.open(src).convert("RGB")  # the shipped alpha just re-keys the black sheet: IGNORE
    rgb = np.asarray(img).astype(np.float64)
    strokes = rgb.max(axis=2) > STROKE_THR
    if int(strokes.sum()) < 500:
        print(f"  !! structure {src.name}: too sparse to reconstruct, SKIPPED")
        return False
    # CLOSE the strokes into a body silhouette, keep the main cluster, then fill interior holes
    # (anything not reachable from the border is inside the structure).
    body = _erode(_dilate(strokes, CLOSE_R), CLOSE_R)
    body = _keep_main_cluster(body, solo)
    body = ~mt._flood_from_border(~body)
    alpha = np.clip(mt._box_blur(body.astype(np.float64), 2) * 1.5, 0.0, 1.0)  # soft 2px edge
    keep = alpha > 0.03
    ys, xs = np.nonzero(keep)
    if ys.size == 0:
        print(f"  !! structure {src.name}: silhouette emptied the image, SKIPPED")
        return False
    pad = 3
    by0, by1 = max(0, ys.min() - pad), min(rgb.shape[0], ys.max() + 1 + pad)
    bx0, bx1 = max(0, xs.min() - pad), min(rgb.shape[1], xs.max() + 1 + pad)
    # Solid ink wash behind the strokes: pure-black interior pixels lift to grimoire ink, painted
    # strokes (brighter per-channel) pass through untouched; then the per-plate midtone lift.
    backed = np.maximum(rgb, INK_WASH[None, None, :])
    lifted = _lift_midtones(backed, lift)
    rgba = np.dstack([lifted, alpha * 255.0])[by0:by1, bx0:bx1]
    out = Image.fromarray(np.clip(rgba + 0.5, 0, 255).astype(np.uint8), "RGBA")
    if max(out.size) > MAX_DIM:
        out.thumbnail((MAX_DIM, MAX_DIM), Image.LANCZOS)
    dst.parent.mkdir(parents=True, exist_ok=True)
    out.save(dst)
    print(f"  structure {src.name} -> {dst.relative_to(REPO_DIR)}  ({out.width}x{out.height})")
    return True


def write_manifest(manifest_path: Path, built: dict) -> None:
    payload = {
        "_note": (
            "GENERATED by tools/make_structures.py - do not hand-edit. Semantic structure id -> "
            "{texture (relative to this dir), height_tiles, footprint [w,h] of walkable-blocking "
            "cells}. Sources: main-repo assets/tiles/iso dioramas, eye-verified; broken source "
            "alpha discarded and re-derived (border-median flood knockout)."
        )
    }
    for name in sorted(built):
        payload[name] = built[name]
    manifest_path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    print(f"manifest -> {manifest_path.relative_to(REPO_DIR)}  ({len(built)} structures)")


def write_qa_sheet(qa_path: Path, outputs: list[Path]) -> None:
    """Structures on checkerboard (so halos/broken cuts show), 2 columns, labelled."""
    from PIL import ImageDraw

    cell, label_h, cols = 320, 26, 3
    rows = (len(outputs) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * cell, rows * (cell + label_h)), (24, 20, 30))
    draw = ImageDraw.Draw(sheet)
    checker = Image.new("RGB", (cell, cell), (96, 104, 92))
    dc = ImageDraw.Draw(checker)
    for cy in range(0, cell, 20):
        for cx in range(0, cell, 20):
            if (cx // 20 + cy // 20) % 2 == 0:
                dc.rectangle([cx, cy, cx + 19, cy + 19], fill=(140, 150, 132))
    for i, p in enumerate(outputs):
        x, y = (i % cols) * cell, (i // cols) * (cell + label_h)
        block = checker.copy()
        cut = Image.open(p).convert("RGBA")
        cut.thumbnail((cell - 12, cell - 12), Image.LANCZOS)
        block.paste(cut, ((cell - cut.width) // 2, (cell - cut.height) // 2), cut)
        sheet.paste(block, (x, y))
        draw.text((x + 4, y + cell + 4), p.name, fill=(230, 220, 190))
    qa_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(qa_path)
    print(f"QA sheet -> {qa_path}")


def main() -> None:
    global REPO_DIR
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--src", type=Path, default=DEFAULT_SRC)
    ap.add_argument("--repo", type=Path, default=REPO_DIR)
    ap.add_argument("--qa", type=Path, default=None)
    args = ap.parse_args()
    REPO_DIR = args.repo
    out_dir = args.repo / "client" / "assets" / "tiles" / "structures"
    built: dict = {}
    outputs: list[Path] = []
    for name, entry in STRUCTURES.items():
        src = args.src / str(entry["src"])
        if not src.exists():
            print(f"  !! missing source {src}, SKIPPED")
            continue
        dst = out_dir / f"{name}.png"
        if process_structure(src, dst, float(entry["lift"]), bool(entry.get("solo", False))):
            built[name] = {
                "texture": f"{name}.png",
                "height_tiles": entry["height_tiles"],
                "footprint": entry["footprint"],
            }
            outputs.append(dst)
    write_manifest(out_dir / "structures.json", built)
    if args.qa is not None:
        write_qa_sheet(args.qa, outputs)


if __name__ == "__main__":
    main()
