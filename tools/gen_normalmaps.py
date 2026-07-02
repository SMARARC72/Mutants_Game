"""Wave 12 "Overworld Depth" — tangent-space normal maps for the shipped topdown terrain tiles.

Height field = blurred luminance of the diffuse tile (the painterly plates carry their relief in
value), gradients via a 3x3 Sobel with WRAP edges (the tiles are seamless, so the normal maps
wrap seamlessly too), packed OpenGL-style (+X right, +Y up, Z out) — the convention Godot's 2D
lighting expects. Output: client/assets/tiles/topdown/normal/<name>_n.png, same size as the
source. OverworldTileSet composes these into a normal atlas wrapped in a CanvasTexture so the
player's PointLight2D shades the ground.

Dependency-light on purpose: PIL + numpy only. Deterministic: same inputs -> same outputs.

Usage:  python tools/gen_normalmaps.py [--repo DIR] [--strength S]
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

TOOLS_DIR = Path(__file__).resolve().parent
REPO_DIR = TOOLS_DIR.parent

DEFAULT_STRENGTH = 2.4
PRE_BLUR = 2  # soften painterly brush noise before deriving relief


def _sobel_wrap(height: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """3x3 Sobel gradients with wrap-around edges (seamless in == seamless out)."""

    def sh(dy: int, dx: int) -> np.ndarray:
        return np.roll(height, (dy, dx), axis=(0, 1))

    gx = (
        (sh(-1, -1) + 2.0 * sh(0, -1) + sh(1, -1))
        - (sh(-1, 1) + 2.0 * sh(0, 1) + sh(1, 1))
    ) / 8.0
    gy = (
        (sh(-1, -1) + 2.0 * sh(-1, 0) + sh(-1, 1))
        - (sh(1, -1) + 2.0 * sh(1, 0) + sh(1, 1))
    ) / 8.0
    return -gx, gy  # slope DOWN the gradient; +Y up in GL convention (image y runs down)


def make_normal(src: Path, dst: Path, strength: float) -> None:
    img = Image.open(src).convert("L").filter(ImageFilter.GaussianBlur(PRE_BLUR))
    height = np.asarray(img).astype(np.float64) / 255.0
    gx, gy = _sobel_wrap(height)
    nx = gx * strength
    ny = gy * strength
    nz = np.ones_like(nx)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    packed = np.dstack([nx, ny, nz]) / length[:, :, None] * 127.5 + 127.5
    dst.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(np.clip(packed + 0.5, 0, 255).astype(np.uint8)).save(dst)
    print(f"  normal {src.name} -> {dst.relative_to(REPO_DIR)}")


def main() -> None:
    global REPO_DIR
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--repo", type=Path, default=REPO_DIR)
    ap.add_argument("--strength", type=float, default=DEFAULT_STRENGTH)
    args = ap.parse_args()
    REPO_DIR = args.repo
    topdown = args.repo / "client" / "assets" / "tiles" / "topdown"
    for src in sorted(topdown.glob("*.png")):
        make_normal(src, topdown / "normal" / f"{src.stem}_n.png", args.strength)


if __name__ == "__main__":
    main()
