#!/usr/bin/env python3
"""Validate promoted creature plates and optionally render labeled QA contact sheets.

This is the visual counterpart to check_asset_contract.py. It requires real LFS bytes and Pillow,
so it runs locally or in an artifact-producing job rather than the pointer-only lint checkout.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import os
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "client/assets/creatures/manifest.json"
REGISTRY = ROOT / "docs/creature_registry.csv"
RECOVERIES = ROOT / "tools/creature_art_recoveries.json"
INK = (23, 19, 28, 255)
PARCHMENT = (232, 221, 196, 255)
BRASS = (185, 147, 63, 255)
TEXT = (244, 236, 216, 255)


def load_contract() -> tuple[dict[str, dict[str, str]], set[str], set[str]]:
    with MANIFEST.open(encoding="utf-8") as fh:
        raw = json.load(fh)
    manifest = {key: value for key, value in raw.items() if not key.startswith("_")}
    with REGISTRY.open(newline="", encoding="utf-8-sig") as fh:
        registry_ids = {
            row["id"].strip()
            for row in csv.DictReader(fh)
            if row.get("id", "").strip() and row.get("status", "").strip().lower() != "void"
        }
    recoveries: set[str] = set()
    if RECOVERIES.exists():
        with RECOVERIES.open(encoding="utf-8") as fh:
            recoveries = set(json.load(fh).get("recoveries", {}))
    return manifest, registry_ids, recoveries


def validate(manifest: dict[str, dict[str, str]], registry_ids: set[str]) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    if set(manifest) != registry_ids:
        for species_id in sorted(registry_ids - set(manifest)):
            errors.append(f"missing manifest id: {species_id}")
        for species_id in sorted(set(manifest) - registry_ids):
            errors.append(f"unknown manifest id: {species_id}")
    hashes: dict[str, str] = {}
    for species_id, variants in sorted(manifest.items()):
        for variant in ("flat", "cutout"):
            relative = variants.get(variant)
            if not relative:
                if variant == "cutout":
                    warnings.append(f"{species_id}: flat-only (cutout rejected)")
                    continue
                errors.append(f"{species_id}: missing flat variant")
                continue
            path = MANIFEST.parent / relative
            if not path.is_file():
                errors.append(f"{species_id}.{variant}: missing {path.relative_to(ROOT)}")
                continue
            try:
                with Image.open(path) as opened:
                    opened.load()
                    image = opened.convert("RGBA")
            except OSError as error:
                errors.append(f"{species_id}.{variant}: unreadable: {error}")
                continue
            if max(image.size) > 512 or min(image.size) < 1:
                errors.append(f"{species_id}.{variant}: invalid dimensions {image.size}")
            digest = hashlib.sha256(image.tobytes()).hexdigest()
            duplicate = hashes.get(digest)
            if duplicate:
                warnings.append(f"pixel duplicate: {species_id}.{variant} == {duplicate}")
            else:
                hashes[digest] = f"{species_id}.{variant}"
            if variant == "cutout":
                alpha = image.getchannel("A")
                nonzero = sum(1 for value in alpha.get_flattened_data() if value > 8)
                coverage = nonzero / (image.width * image.height)
                if coverage < 0.02 or coverage > 0.96:
                    warnings.append(f"{species_id}.cutout: suspicious alpha coverage {coverage:.1%}")
    return errors, warnings


def render_sheets(
    manifest: dict[str, dict[str, str]], recoveries: set[str], output: Path, cols: int, rows: int
) -> int:
    output.mkdir(parents=True, exist_ok=True)
    ids = sorted(manifest)
    per_page = cols * rows
    cell_w, cell_h = 260, 300
    font = ImageFont.load_default(size=16)
    small = ImageFont.load_default(size=12)
    pages = math.ceil(len(ids) / per_page)
    for page in range(pages):
        sheet = Image.new("RGBA", (cols * cell_w, rows * cell_h), INK)
        draw = ImageDraw.Draw(sheet)
        for local_index, species_id in enumerate(ids[page * per_page : (page + 1) * per_page]):
            x = (local_index % cols) * cell_w
            y = (local_index // cols) * cell_h
            draw.rectangle((x, y, x + cell_w // 2, y + cell_h), fill=INK)
            draw.rectangle((x + cell_w // 2, y, x + cell_w, y + cell_h), fill=PARCHMENT)
            relative = manifest[species_id].get("cutout") or manifest[species_id]["flat"]
            with Image.open(MANIFEST.parent / relative) as opened:
                plate = opened.convert("RGBA")
            plate.thumbnail((220, 245), Image.Resampling.LANCZOS)
            px = x + (cell_w - plate.width) // 2
            py = y + 22 + (250 - plate.height) // 2
            sheet.alpha_composite(plate, (px, py))
            label = species_id + ("  RECOVERED" if species_id in recoveries else "")
            label_color = (255, 120, 92, 255) if species_id in recoveries else TEXT
            draw.rectangle((x, y, x + cell_w, y + 22), fill=(8, 6, 10, 230))
            draw.text((x + 6, y + 3), label, font=font, fill=label_color)
            draw.text((x + 6, y + cell_h - 18), "INK", font=small, fill=BRASS)
            draw.text((x + cell_w - 72, y + cell_h - 18), "PARCHMENT", font=small, fill=(60, 45, 30, 255))
            draw.rectangle((x, y, x + cell_w - 1, y + cell_h - 1), outline=BRASS, width=1)
        sheet.save(output / f"creature_art_qa_{page + 1:02d}.png")
    return pages


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sheet-dir", type=Path, help="write labeled visual QA pages here")
    parser.add_argument("--cols", type=int, default=5)
    parser.add_argument("--rows", type=int, default=4)
    args = parser.parse_args()
    manifest, registry_ids, recoveries = load_contract()
    errors, warnings = validate(manifest, registry_ids)
    for warning in warnings:
        print(f"WARN: {warning}")
    for error in errors:
        print(f"ERROR: {error}")
    pages = 0
    if args.sheet_dir and not errors:
        pages = render_sheets(manifest, recoveries, args.sheet_dir, args.cols, args.rows)
    print(
        f"creature art QA: {len(manifest)} entries, {len(errors)} error(s), "
        f"{len(warnings)} warning(s), {pages} sheet(s)"
    )
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
