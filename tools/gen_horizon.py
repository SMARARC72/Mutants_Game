"""Wave 12 "Overworld Depth" — distant-horizon strips for the overworld parallax layer.

For each core force, picks the region's primary painterly backdrop from
client/assets/backdrops/manifest.json (the first non-battle entry), heavily blurs + darkens it
into a wide strip, and bakes an INK fade into the top and bottom edges so the strip melts into
the occult-ink void wherever it ends. Output: client/assets/backdrops/horizon/<force>.png at
1024x320 (the asset-contract CI caps backdrops at 1024px on the longest side; the overworld
scales the strip up in-scene — it is a heavy blur, so upscaling is free).

Dependency-light on purpose: PIL + numpy only. Deterministic: same inputs -> same outputs.

Usage:  python tools/gen_horizon.py [--repo DIR]
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

TOOLS_DIR = Path(__file__).resolve().parent
REPO_DIR = TOOLS_DIR.parent

OUT_W, OUT_H = 1024, 320
BLUR_RADIUS = 16
DARKEN = 0.52
# GrimoirePalette.INK ("17131c") — the void the strip fades into at its top/bottom edges.
INK = np.array([23.0, 19.0, 28.0])
# The six core forces (compound climates resolve to their head token in the overworld).
FORCES = ["eros", "gaia", "ouranos", "cosmos", "chaos", "thanatos"]


def _smoothstep(t: np.ndarray) -> np.ndarray:
    t = np.clip(t, 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def make_horizon(src: Path, dst: Path) -> None:
    img = Image.open(src).convert("RGB")
    # Wide strip: squash-resize (backdrops are already wide 1024x329 paintings), then blur
    # heavily — this is a DISTANT read, all detail is intentional mush.
    img = img.resize((OUT_W, OUT_H), Image.LANCZOS)
    img = img.filter(ImageFilter.GaussianBlur(BLUR_RADIUS))
    rgb = np.asarray(img).astype(np.float64) * DARKEN
    # Vertical ink fade: full painting through the middle band, melting into INK at the top
    # edge (the deep void) and the bottom edge (the seam against the tile field).
    ys = np.arange(OUT_H, dtype=np.float64) / (OUT_H - 1)
    top_w = _smoothstep(ys / 0.30)  # 0 at the very top -> 1 by 30% down
    bot_w = _smoothstep((1.0 - ys) / 0.42)  # 1 above the fold -> 0 at the bottom edge
    weight = (top_w * bot_w)[:, None, None]
    out = INK[None, None, :] * (1.0 - weight) + rgb * weight
    dst.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(np.clip(out + 0.5, 0, 255).astype(np.uint8)).save(dst)
    print(f"  horizon {src.name} -> {dst.relative_to(REPO_DIR)}")


def main() -> None:
    global REPO_DIR
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--repo", type=Path, default=REPO_DIR)
    args = ap.parse_args()
    REPO_DIR = args.repo
    backdrops = args.repo / "client" / "assets" / "backdrops"
    manifest = json.loads((backdrops / "manifest.json").read_text(encoding="utf-8"))
    for force in FORCES:
        entries = [e for e in manifest.get(force, []) if "_battle" not in e]
        if not entries:
            print(f"  !! no backdrop manifest entry for force '{force}', SKIPPED")
            continue
        src = backdrops / entries[0]
        if not src.exists():
            print(f"  !! missing source {src}, SKIPPED")
            continue
        make_horizon(src, backdrops / "horizon" / f"{force}.png")


if __name__ == "__main__":
    main()
