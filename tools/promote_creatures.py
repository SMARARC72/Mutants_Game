#!/usr/bin/env python3
"""Promote registry creature art into the game: painterly RGBA cutouts + flat plates.

Per docs/Realization_Master_Plan.md Wave 7 with red-team correction C3: the alpha knockout
thresholds against a PER-IMAGE border-ring median (not a fixed seed tolerance), removes only
candidate components CONNECTED to the image border (interior whites survive structurally),
additionally drops large enclosed near-pure-white background pockets, then erodes 1px and
feathers the alpha 1px. Built for all 407 registry rows; promotion runs scoped (--slice /
--only) until the asset-contract gate has proven itself.

Source resolution per registry row:
  * art_ref 'art/...'  -> file under the main-repo art root (batch3/4/5 plates).
  * any other art_ref  -> tools/art_origins.json (full-res original, optionally a cell 'box').
  * unresolved         -> recorded in tools/creature_art_gaps.json.

Outputs (paths inside the Godot project):
  client/assets/creatures/cutout/<species_id>.png   RGBA cutout, max dim 512 (never upscaled)
  client/assets/creatures/flat/<species_id>.png     flat original (codex surfaces), max dim 512
  client/assets/creatures/manifest.json             {species_id: {"cutout": ..., "flat": ...}}

tools/creature_art_rejects.json (hand-authored after the QA contact sheet) lists species ids
whose knockout is visibly broken: their cutout entry is dropped from the manifest (flat still
ships) and the bad cutout file is not emitted.

Usage:
  python tools/promote_creatures.py --slice          # Verdant slice + starters (+curated ids)
  python tools/promote_creatures.py --only SB05,DM06
  python tools/promote_creatures.py --all
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REGISTRY = os.path.join(REPO, "docs", "creature_registry.csv")
ORIGINS = os.path.join(REPO, "tools", "art_origins.json")
GAPS = os.path.join(REPO, "tools", "creature_art_gaps.json")
REJECTS = os.path.join(REPO, "tools", "creature_art_rejects.json")
SLICE = os.path.join(REPO, "client", "catalog", "slice_verdant.json")
OUT_DIR = os.path.join(REPO, "client", "assets", "creatures")
DEFAULT_ART_ROOT = "c:/Users/arahi/Documents/Claude/Projects/Mutants_Game/art"

MAX_DIM = 512
RING = 6  # border-ring width (px) for the background statistic
POCKET_MIN_AREA = 800
MIN_COMPONENT_AREA = 60


# ---------------------------------------------------------------- components
class _DSU:
    def __init__(self) -> None:
        self.parent: list[int] = []

    def make(self) -> int:
        self.parent.append(len(self.parent))
        return len(self.parent) - 1

    def find(self, a: int) -> int:
        while self.parent[a] != a:
            self.parent[a] = self.parent[self.parent[a]]
            a = self.parent[a]
        return a

    def union(self, a: int, b: int) -> None:
        ra, rb = self.find(a), self.find(b)
        if ra != rb:
            self.parent[rb] = ra


def label_components(mask: np.ndarray) -> list[dict]:
    """4-connected component labeling via row runs (PIL+numpy only; no scipy).

    Returns [{'runs': [(row, start, end)], 'area': int, 'bbox': (x0,y0,x1,y1),
              'touches_border': bool}] for each True-component of `mask`.
    """
    h, w = mask.shape
    dsu = _DSU()
    prev_runs: list[tuple[int, int, int]] = []  # (start, end, label)
    all_runs: list[tuple[int, int, int, int]] = []  # (row, start, end, label)
    for row in range(h):
        line = mask[row]
        if not line.any():
            prev_runs = []
            continue
        padded = np.diff(np.concatenate(([False], line, [False])).astype(np.int8))
        starts = np.flatnonzero(padded == 1)
        ends = np.flatnonzero(padded == -1)
        cur_runs: list[tuple[int, int, int]] = []
        pi = 0
        for s, e in zip(starts.tolist(), ends.tolist()):
            label = -1
            while pi < len(prev_runs) and prev_runs[pi][1] <= s:
                pi += 1
            pj = pi
            while pj < len(prev_runs) and prev_runs[pj][0] < e:
                if label == -1:
                    label = dsu.find(prev_runs[pj][2])
                else:
                    dsu.union(label, prev_runs[pj][2])
                pj += 1
            if pj > pi:
                pj -= 1  # last overlapping prev run may also overlap the next cur run
            pi_next = pj
            if label == -1:
                label = dsu.make()
            cur_runs.append((s, e, label))
            all_runs.append((row, s, e, label))
            pi = pi_next
        prev_runs = cur_runs
    comps: dict[int, dict] = {}
    for row, s, e, label in all_runs:
        root = dsu.find(label)
        c = comps.get(root)
        if c is None:
            c = {
                "runs": [],
                "area": 0,
                "bbox": [w, h, 0, 0],
                "touches_border": False,
            }
            comps[root] = c
        c["runs"].append((row, s, e))
        c["area"] += e - s
        b = c["bbox"]
        b[0] = min(b[0], s)
        b[1] = min(b[1], row)
        b[2] = max(b[2], e)
        b[3] = max(b[3], row + 1)
        if row == 0 or row == h - 1 or s == 0 or e == w:
            c["touches_border"] = True
    return list(comps.values())


def comp_mask(comp: dict, shape: tuple[int, int]) -> np.ndarray:
    m = np.zeros(shape, dtype=bool)
    for row, s, e in comp["runs"]:
        m[row, s:e] = True
    return m


# ---------------------------------------------------------------- knockout
def knockout(img: Image.Image, cell_mode: bool = False) -> Image.Image:
    """Background removal per correction C3. Returns an RGBA image (uncropped)."""
    rgb = np.asarray(img.convert("RGB"), dtype=np.int16)
    h, w = rgb.shape[:2]
    ring = np.concatenate(
        [
            rgb[:RING].reshape(-1, 3),
            rgb[-RING:].reshape(-1, 3),
            rgb[:, :RING].reshape(-1, 3),
            rgb[:, -RING:].reshape(-1, 3),
        ]
    )
    med = np.median(ring, axis=0)
    dist = np.abs(rgb - med).max(axis=2)
    ring_dist = np.abs(ring - med).max(axis=1)
    # margin: adaptive to how painterly/noisy the background ring itself is
    threshold = float(np.clip(np.percentile(ring_dist, 99) + 8, 26, 60))
    candidate = dist <= threshold

    remove = np.zeros((h, w), dtype=bool)
    comps = label_components(candidate)
    for c in comps:
        if c["touches_border"]:
            for row, s, e in c["runs"]:
                remove[row, s:e] = True
        else:
            # enclosed background pockets between limbs: large + near-pure-white, or
            # large + median-indistinguishable from the border median. Compact bright
            # blobs are exempt — those are specular highlights ON the creature (the
            # white-on-white failure case), not background pockets.
            if c["area"] <= POCKET_MIN_AREA:
                continue
            m = comp_mask(c, (h, w))
            white = float((rgb.min(axis=2) >= 250)[m].mean())
            med_dist = float(np.median(dist[m]))
            x0, y0, x1, y1 = c["bbox"]
            fill = c["area"] / max(1, (x1 - x0) * (y1 - y0))
            is_pocket = white >= 0.98 or med_dist <= max(6.0, 0.25 * threshold)
            is_highlight = white >= 0.5 and c["area"] < 4000 and fill >= 0.6
            if is_pocket and not is_highlight:
                for row, s, e in c["runs"]:
                    remove[row, s:e] = True

    keep = ~remove
    if cell_mode:
        # sheet-cell hygiene: drop the number badge (small, isolated, top-left zone)
        # and slivers bleeding in from neighbouring cells (small + touching the crop edge)
        fg = label_components(keep)
        if fg:
            largest = max(c["area"] for c in fg)
            zone_x, zone_y = int(w * 0.33), int(h * 0.33)
            for c in fg:
                if c["area"] >= largest:
                    continue
                x0, y0, x1, y1 = c["bbox"]
                badge = x1 <= zone_x and y1 <= zone_y and c["area"] < 0.02 * h * w
                bleed = c["touches_border"] and c["area"] < 0.12 * largest
                noise = c["area"] < MIN_COMPONENT_AREA
                if badge or bleed or noise:
                    for row, s, e in c["runs"]:
                        keep[row, s:e] = False
    else:
        fg = label_components(keep)
        for c in fg:
            if c["area"] < MIN_COMPONENT_AREA:
                for row, s, e in c["runs"]:
                    keep[row, s:e] = False

    alpha = Image.fromarray((keep * 255).astype(np.uint8), mode="L")
    alpha = alpha.filter(ImageFilter.MinFilter(3))  # 1px erode
    alpha = alpha.filter(ImageFilter.GaussianBlur(1))  # 1px feather
    out = img.convert("RGBA")
    out.putalpha(alpha)
    return out


def crop_to_alpha(img: Image.Image, pad: int = 4) -> Image.Image:
    bbox = img.getchannel("A").getbbox()
    if bbox is None:
        return img
    x0, y0, x1, y1 = bbox
    x0, y0 = max(0, x0 - pad), max(0, y0 - pad)
    x1, y1 = min(img.width, x1 + pad), min(img.height, y1 + pad)
    return img.crop((x0, y0, x1, y1))


def downscale(img: Image.Image) -> Image.Image:
    if max(img.size) <= MAX_DIM:
        return img  # never upscale
    scale = MAX_DIM / max(img.size)
    size = (max(1, round(img.width * scale)), max(1, round(img.height * scale)))
    return img.resize(size, Image.LANCZOS)


# ---------------------------------------------------------------- scope + io
def load_registry() -> list[dict]:
    with open(REGISTRY, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def slice_ids() -> list[str]:
    with open(SLICE, encoding="utf-8") as f:
        data = json.load(f)
    ids: list[str] = []
    for entry in data.get("starter_party", []):
        ids.append(str(entry["species_id"]))
    for pool in ("wild_pool", "elite_pool"):
        for entry in data.get(pool, []):
            ids.append(str(entry["species_id"]))
    boss = data.get("boss", {})
    if boss.get("species_id"):
        ids.append(str(boss["species_id"]))
    # previously-curated manifest ids (client/assets/creatures/*.png era)
    ids.extend(["SB07", "SB05", "AD10", "SB14", "SB33"])
    seen: set[str] = set()
    ordered = []
    for i in ids:
        if i not in seen:
            seen.add(i)
            ordered.append(i)
    return ordered


def resolve_source(row: dict, origins: dict, art_root: str):
    """-> (abs_path, box|None) or (None, reason)."""
    ref = row.get("art_ref", "")
    if not ref:
        return None, "empty art_ref"
    base = os.path.dirname(art_root)
    if ref.startswith("art/"):
        path = os.path.join(base, ref)
        return (path, None) if os.path.exists(path) else (None, f"missing file {ref}")
    origin = origins.get(ref)
    if origin is None:
        return None, f"no origin mapping for art_ref '{ref}'"
    path = os.path.join(base, origin["file"])
    if not os.path.exists(path):
        return None, f"missing origin file {origin['file']}"
    return path, origin.get("box")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--art-root", default=DEFAULT_ART_ROOT)
    group = ap.add_mutually_exclusive_group(required=True)
    group.add_argument("--slice", action="store_true", help="Verdant slice + starters")
    group.add_argument("--only", help="comma-separated species ids")
    group.add_argument("--all", action="store_true", help="every registry row")
    a = ap.parse_args()

    registry = load_registry()
    by_id = {r["id"]: r for r in registry}
    if a.all:
        ids = [r["id"] for r in registry]
    elif a.only:
        ids = [s.strip() for s in a.only.split(",") if s.strip()]
    else:
        ids = slice_ids()

    with open(ORIGINS, encoding="utf-8") as f:
        origins = json.load(f)["refs"]
    rejects: list[str] = []
    if os.path.exists(REJECTS):
        with open(REJECTS, encoding="utf-8") as f:
            rejects = [str(x) for x in json.load(f).get("rejected", [])]

    cut_dir = os.path.join(OUT_DIR, "cutout")
    flat_dir = os.path.join(OUT_DIR, "flat")
    os.makedirs(cut_dir, exist_ok=True)
    os.makedirs(flat_dir, exist_ok=True)

    manifest: dict[str, dict] = {}
    gaps: dict[str, str] = {}
    for sid in ids:
        row = by_id.get(sid)
        if row is None:
            gaps[sid] = "not in registry"
            continue
        src, box = resolve_source(row, origins, a.art_root)
        if src is None:
            gaps[sid] = box  # box carries the reason string here
            print(f"  GAP {sid}: {box}")
            continue
        img = Image.open(src)
        cell_mode = isinstance(box, list)
        if cell_mode:
            img = img.crop(tuple(box))
        flat = downscale(img.convert("RGB"))
        flat_name = f"{sid}.png"
        flat.save(os.path.join(flat_dir, flat_name))
        entry = {"flat": f"flat/{flat_name}"}
        if sid in rejects:
            print(f"  {sid}: cutout REJECTED -> flat only")
        else:
            cut = downscale(crop_to_alpha(knockout(img, cell_mode=cell_mode)))
            cut_name = f"{sid}.png"
            cut.save(os.path.join(cut_dir, cut_name))
            entry["cutout"] = f"cutout/{cut_name}"
        manifest[sid] = entry
        print(f"  ok {sid}: {os.path.basename(src)}" + (" [cell]" if cell_mode else ""))

    # merge into any existing manifest so scoped runs stay additive
    manifest_path = os.path.join(OUT_DIR, "manifest.json")
    merged: dict[str, dict] = {}
    if os.path.exists(manifest_path):
        with open(manifest_path, encoding="utf-8") as f:
            merged = json.load(f)
            merged.pop("_note", None)
    merged.update(manifest)
    payload: dict = {
        "_note": (
            "GENERATED by tools/promote_creatures.py — do not hand-edit. species_id -> plate "
            "files relative to res://assets/creatures/. 'cutout' (RGBA knockout) is preferred "
            "by SpeciesArt.plate(); 'flat' is the original plate for codex/parchment surfaces. "
            "Rejected knockouts (tools/creature_art_rejects.json) ship flat-only."
        )
    }
    payload.update({k: merged[k] for k in sorted(merged)})
    with open(manifest_path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(payload, f, indent=2)
        f.write("\n")
    with open(GAPS, "w", encoding="utf-8", newline="\n") as f:
        json.dump(
            {
                "_note": "species ids whose art_ref could not be resolved to a source file; "
                "fill via tools/gen_art.py --only or by extending tools/art_origins.json.",
                "gaps": gaps,
            },
            f,
            indent=2,
        )
        f.write("\n")
    print(
        f"promoted {len(manifest)} species ({len(rejects)} reject(s) flat-only), "
        f"{len(gaps)} gap(s) -> manifest {len(merged)} entries"
    )
    return 0 if not gaps else 1


if __name__ == "__main__":
    sys.exit(main())
