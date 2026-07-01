"""Wave 6.5 terrain pipeline — turns the raw painterly plates in <main repo>/assets/tiles/topdown
into game-ready overworld assets under client/assets/tiles/.

Reads tools/tile_remap.json (the by-eye source audit; filenames of the raw plates are UNRELIABLE)
and, per role:
  * ground / ground-variant / path / wall / ritual  -> crop any baked frame (or, for diorama
    PLATES, auto-detect the plate rectangle), square-crop, offset-wrap + cross-fade to make the
    texture seamless (skipped for centered-motif tiles), resize to 512, save RGB PNG under
    client/assets/tiles/topdown/<name>.png.
  * prop-diorama -> knock out the smooth gradient background (border-connected flood over a
    border-ring-median colour threshold, so interior glows survive), 1px feather, tight-crop,
    save RGBA PNG under client/assets/tiles/props/<name>.png.

Dependency-light on purpose: PIL + numpy only. Deterministic: same inputs -> same outputs.

Usage:  python tools/make_tiles.py [--src DIR] [--repo DIR] [--qa PATH]
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image

TOOLS_DIR = Path(__file__).resolve().parent
REPO_DIR = TOOLS_DIR.parent
# Source art lives in the MAIN repo (top-level /assets is gitignored -> absent in worktrees).
DEFAULT_SRC = Path("c:/Users/arahi/Documents/Claude/Projects/Mutants_Game/assets/tiles/topdown")

OUT_SIZE = 512

# Tiles whose plate is a diorama rectangle floating on a soft gradient sheet (auto-detect bounds).
PLATE_TILES = {"TILE-042", "TILE-043", "TILE-045", "TILE-049"}
# Centered-motif tiles: offset-wrapping would cut the motif in half — keep them as-is.
NO_SEAMLESS = {"TILE-045", "TILE-053", "TILE-060"}
# Fraction cropped off each edge of a FULL-BLEED plate to drop its thin baked frame,
# plus per-edge overrides (top, right, bottom, left) where a sliver of a neighbouring
# plate leaked into the render.
FRAME_CROP = 0.05
EDGE_OVERRIDES = {
    "TILE-059": (0.085, 0.05, 0.05, 0.05),
    "TILE-060": (0.075, 0.05, 0.05, 0.05),
}


# --------------------------------------------------------------------------- image helpers


def _box_blur(arr: np.ndarray, radius: int) -> np.ndarray:
    """Separable box blur (float array, any trailing shape) via cumulative sums."""
    out = arr.astype(np.float64)
    for axis in (0, 1):
        n = out.shape[axis]
        idx_lo = np.clip(np.arange(n) - radius, 0, n)
        idx_hi = np.clip(np.arange(n) + radius + 1, 0, n)
        csum = np.cumsum(out, axis=axis)
        csum = np.concatenate([np.zeros_like(np.take(csum, [0], axis=axis)), csum], axis=axis)
        out = np.take(csum, idx_hi, axis=axis) - np.take(csum, idx_lo, axis=axis)
        out /= (idx_hi - idx_lo).reshape([-1 if a == axis else 1 for a in (0, 1)])
    return out


def _detail_bbox(rgb: np.ndarray, thr: float = 7.0, cell: int = 8) -> tuple[int, int, int, int]:
    """Bounding box (x0, y0, x1, y1) of the best connected high-detail region.

    Detail = |gray - blur(gray)| pooled to a coarse grid; connected components on the grid keep
    stray fragments of NEIGHBOURING plates (common slivers at the sheet's top/bottom edge) out of
    the box. Components are scored size x centrality (fragments hug an edge, the subject sits
    near the centre), then components whose boxes overlap the winner are merged back in (a prop's
    glow/base can split off its body).
    """
    gray = rgb.mean(axis=2)
    detail = np.abs(gray - _box_blur(gray, 6))
    h, w = detail.shape
    gh, gw = h // cell, w // cell
    pooled = detail[: gh * cell, : gw * cell].reshape(gh, cell, gw, cell).mean(axis=(1, 3))
    mask = pooled > thr
    comps: list[dict] = []
    labels = np.zeros(mask.shape, dtype=np.int32)
    for sy in range(gh):
        for sx in range(gw):
            if not mask[sy, sx] or labels[sy, sx]:
                continue
            label = len(comps) + 1
            stack = [(sy, sx)]
            labels[sy, sx] = label
            pixels = [(sy, sx)]
            while stack:
                cy, cx = stack.pop()
                for ny, nx in ((cy - 1, cx), (cy + 1, cx), (cy, cx - 1), (cy, cx + 1)):
                    if 0 <= ny < gh and 0 <= nx < gw and mask[ny, nx] and not labels[ny, nx]:
                        labels[ny, nx] = label
                        stack.append((ny, nx))
                        pixels.append((ny, nx))
            ys = np.array([p[0] for p in pixels])
            xs = np.array([p[1] for p in pixels])
            centrality = np.hypot(
                (ys.mean() - gh / 2.0) / gh, (xs.mean() - gw / 2.0) / gw
            )  # 0 = dead centre, ~0.7 = a corner
            comps.append(
                {
                    "size": len(pixels),
                    "score": len(pixels) * (1.0 - min(0.75, 1.4 * centrality)),
                    "box": [int(ys.min()), int(xs.min()), int(ys.max()), int(xs.max())],
                }
            )
    best = max(comps, key=lambda c: c["score"])
    by0, bx0, by1, bx1 = best["box"]
    for c in comps:
        if c is best:
            continue
        oy0, ox0, oy1, ox1 = c["box"]
        if oy0 <= by1 + 1 and oy1 >= by0 - 1 and ox0 <= bx1 + 1 and ox1 >= bx0 - 1:
            by0, bx0 = min(by0, oy0), min(bx0, ox0)
            by1, bx1 = max(by1, oy1), max(bx1, ox1)
    return bx0 * cell, by0 * cell, (bx1 + 1) * cell, (by1 + 1) * cell


def _smoothstep(t: np.ndarray) -> np.ndarray:
    t = np.clip(t, 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def make_seamless(rgb: np.ndarray, band: float = 0.22) -> np.ndarray:
    """Offset-wrap seamless: roll by half, then cross-fade the ORIGINAL (continuous at the
    centre) back over the rolled copy's discontinuity cross. The result wraps cleanly because
    the rolled copy's own borders come from the original's interior."""
    h, w = rgb.shape[:2]
    rolled = np.roll(rgb.astype(np.float64), (h // 2, w // 2), axis=(0, 1))
    dy = np.abs(np.arange(h) - h / 2.0) / (h / 2.0)  # 0 on the seam row, 1 at the border
    dx = np.abs(np.arange(w) - w / 2.0) / (w / 2.0)
    wy = _smoothstep((band - dy) / band)
    wx = _smoothstep((band - dx) / band)
    m = np.maximum(wy[:, None], wx[None, :])[:, :, None]
    out = rolled * (1.0 - m) + rgb.astype(np.float64) * m
    return np.clip(out + 0.5, 0, 255).astype(np.uint8)


# --------------------------------------------------------------------------- terrain tiles


def process_terrain(src: Path, stem: str, dst: Path) -> None:
    img = Image.open(src).convert("RGB")
    rgb = np.asarray(img)
    h, w = rgb.shape[:2]
    if stem in PLATE_TILES:
        x0, y0, x1, y1 = _detail_bbox(rgb)
        inset = 6  # step inside the plate's hard edge / drop-glow
        x0, y0, x1, y1 = x0 + inset, y0 + inset, x1 - inset, y1 - inset
    else:
        top, right, bottom, left = EDGE_OVERRIDES.get(stem, (FRAME_CROP,) * 4)
        x0, y0 = int(w * left), int(h * top)
        x1, y1 = w - int(w * right), h - int(h * bottom)
    # centre square crop so the downstream 1:1 tile never stretches
    cw, ch = x1 - x0, y1 - y0
    side = min(cw, ch)
    x0 += (cw - side) // 2
    y0 += (ch - side) // 2
    tile = rgb[y0 : y0 + side, x0 : x0 + side]
    tile = np.asarray(Image.fromarray(tile).resize((OUT_SIZE, OUT_SIZE), Image.LANCZOS))
    if stem not in NO_SEAMLESS:
        tile = make_seamless(tile)
    dst.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(tile).save(dst)
    print(f"  terrain {src.name} -> {dst.relative_to(REPO_DIR)}  ({side}px crop)")


# --------------------------------------------------------------------------- prop knockout


def _flood_from_border(mask: np.ndarray) -> np.ndarray:
    """All mask-True pixels connected (4-neigh) to the image border, via iterative dilation."""
    bg = np.zeros_like(mask)
    bg[0, :], bg[-1, :], bg[:, 0], bg[:, -1] = mask[0, :], mask[-1, :], mask[:, 0], mask[:, -1]
    while True:
        grown = bg.copy()
        grown[1:, :] |= bg[:-1, :]
        grown[:-1, :] |= bg[1:, :]
        grown[:, 1:] |= bg[:, :-1]
        grown[:, :-1] |= bg[:, 1:]
        grown &= mask
        if np.array_equal(grown, bg):
            return bg
        bg = grown


def process_prop(src: Path, dst: Path) -> None:
    img = Image.open(src).convert("RGB")
    rgb = np.asarray(img)
    x0, y0, x1, y1 = _detail_bbox(rgb, thr=5.0)
    pad = 10
    x0, y0 = max(0, x0 - pad), max(0, y0 - pad)
    x1, y1 = min(rgb.shape[1], x1 + pad), min(rgb.shape[0], y1 + pad)
    crop = rgb[y0:y1, x0:x1].astype(np.float64)
    ring = np.concatenate(
        [crop[:2].reshape(-1, 3), crop[-2:].reshape(-1, 3), crop[:, :2].reshape(-1, 3), crop[:, -2:].reshape(-1, 3)]
    )
    med = np.median(ring, axis=0)
    spread = float(np.median(np.abs(ring - med))) * 6.0
    thr = max(30.0, min(70.0, spread))
    dist = np.sqrt(((crop - med) ** 2).sum(axis=2))
    # A pixel is background-candidate if it matches the border-ring colour OR is featureless
    # (the sheet gradient drifts away from the ring median, but stays smooth; subject interiors
    # and painterly fringes are detailed, so the flood cannot cross them into interior glows).
    gray = crop.mean(axis=2)
    featureless = np.abs(gray - _box_blur(gray, 6)) < 2.0
    bg = _flood_from_border((dist < thr) | featureless)
    alpha = np.where(bg, 0.0, 1.0)
    alpha = np.clip(_box_blur(alpha, 1), 0.0, 1.0)  # 1px feather
    keep = alpha > 0.02
    ys, xs = np.nonzero(keep)
    if ys.size == 0:
        print(f"  !! prop {src.name}: knockout emptied the image, SKIPPED")
        return
    by0, by1, bx0, bx1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    rgba = np.dstack([crop, alpha * 255.0])[by0:by1, bx0:bx1]
    dst.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(np.clip(rgba + 0.5, 0, 255).astype(np.uint8), "RGBA").save(dst)
    print(f"  prop    {src.name} -> {dst.relative_to(REPO_DIR)}  ({bx1 - bx0}x{by1 - by0}, thr={thr:.0f})")


# --------------------------------------------------------------------------- QA sheet


def write_qa_sheet(qa_path: Path, terrain_out: list[Path], prop_out: list[Path]) -> None:
    """Terrain tiled 2x2 (so wrap seams show) + props on checkerboard (so halos show)."""
    cell, label_h, cols = 256, 26, 5
    entries = [("t", p) for p in terrain_out] + [("p", p) for p in prop_out]
    rows = (len(entries) + cols - 1) // cols
    from PIL import ImageDraw

    sheet = Image.new("RGB", (cols * cell, rows * (cell + label_h)), (24, 20, 30))
    draw = ImageDraw.Draw(sheet)
    checker = Image.new("RGB", (cell, cell), (90, 90, 100))
    dc = ImageDraw.Draw(checker)
    for cy in range(0, cell, 16):
        for cx in range(0, cell, 16):
            if (cx // 16 + cy // 16) % 2 == 0:
                dc.rectangle([cx, cy, cx + 15, cy + 15], fill=(150, 150, 160))
    for i, (kind, p) in enumerate(entries):
        x, y = (i % cols) * cell, (i // cols) * (cell + label_h)
        if kind == "t":
            small = Image.open(p).resize((cell // 2, cell // 2), Image.LANCZOS)
            for oy in (0, cell // 2):
                for ox in (0, cell // 2):
                    sheet.paste(small, (x + ox, y + oy))
        else:
            block = checker.copy()
            prop = Image.open(p).convert("RGBA")
            prop.thumbnail((cell - 16, cell - 16), Image.LANCZOS)
            block.paste(prop, ((cell - prop.width) // 2, (cell - prop.height) // 2), prop)
            sheet.paste(block, (x, y))
        draw.text((x + 4, y + cell + 4), ("2x2 " if kind == "t" else "") + p.name, fill=(230, 220, 190))
    qa_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(qa_path)
    print(f"QA sheet -> {qa_path}")


# --------------------------------------------------------------------------- main


def main() -> None:
    global REPO_DIR
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--src", type=Path, default=DEFAULT_SRC)
    ap.add_argument("--repo", type=Path, default=REPO_DIR)
    ap.add_argument("--qa", type=Path, default=None)
    args = ap.parse_args()
    REPO_DIR = args.repo
    out_root = args.repo / "client" / "assets" / "tiles"
    remap = json.loads((TOOLS_DIR / "tile_remap.json").read_text(encoding="utf-8"))
    terrain_out: list[Path] = []
    prop_out: list[Path] = []
    for fname, entry in remap.items():
        if fname.startswith("_") or entry.get("output") is None:
            continue
        src = args.src / fname
        if not src.exists():
            print(f"  !! missing source {src}, SKIPPED")
            continue
        dst = out_root / entry["output"]
        stem = fname.split("_")[0]
        if entry["role"] == "prop-diorama":
            process_prop(src, dst)
            prop_out.append(dst)
        else:
            process_terrain(src, stem, dst)
            terrain_out.append(dst)
    if args.qa is not None:
        write_qa_sheet(args.qa, terrain_out, prop_out)


if __name__ == "__main__":
    main()
