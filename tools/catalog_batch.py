#!/usr/bin/env python3
"""Mutants_Game batch cataloger — ingest a batch of creature art into the registry.

Usage:
    python3 catalog_batch.py <zip_or_dir> <batch_label> [--page N] [--cols 6] [--cell 240] [--no-montage]

What it does:
  1. Extracts <zip> into art/<batch_label>/  (or reads <dir> in place).
  2. Builds labeled contact-sheet montage(s) -> art/montage_<label>_pN.png
     (<=24 cells/sheet; each cell labeled <label>-NNN to match its registry id).
  3. Appends placeholder rows to creature_registry.csv (status='new'), idempotently
     (rows are keyed by art_ref, so re-running never duplicates).

Tip: for very large batches, generate sheets one at a time with --page to dodge timeouts.
"""
import os, glob, csv, math, zipfile, argparse

ROOT = os.path.dirname(os.path.abspath(__file__))
ART = os.path.join(ROOT, "art")
REG = os.path.join(ROOT, "creature_registry.csv")
COLUMNS = ["id", "name", "batch", "art_ref", "tier", "line", "stage",
           "force_primary", "force_secondary", "role", "acquisition",
           "tags", "description", "status"]
PER_SHEET = 24
IMG_EXT = (".png", ".jpg", ".jpeg", ".webp")


def extract(src, label):
    """Return a directory containing the batch images."""
    if src.lower().endswith(".zip"):
        dest = os.path.join(ART, label)
        os.makedirs(dest, exist_ok=True)
        with zipfile.ZipFile(src) as z:
            z.extractall(dest)
        return dest
    return src  # already a directory


def list_images(d):
    return sorted(f for f in glob.glob(os.path.join(d, "**", "*"), recursive=True)
                  if f.lower().endswith(IMG_EXT))


def ref_for(f):
    return os.path.relpath(f, ROOT).replace("\\", "/")


def build_montage(files, label, page, cols, cell):
    from PIL import Image, ImageDraw, ImageFont
    band, pad = 26, 6
    chunk = files[page * PER_SHEET:(page + 1) * PER_SHEET]
    if not chunk:
        return None
    rows = math.ceil(len(chunk) / cols)
    W = cols * (cell + pad) + pad
    H = rows * (cell + band + pad) + pad
    sheet = Image.new("RGB", (W, H), (245, 242, 235))
    d = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 18)
    except Exception:
        font = ImageFont.load_default()
    for i, f in enumerate(chunk):
        gi = page * PER_SHEET + i + 1
        r, c = divmod(i, cols)
        x = pad + c * (cell + pad)
        y = pad + r * (cell + band + pad)
        try:
            im = Image.open(f).convert("RGB")
            im.thumbnail((cell, cell))
        except Exception:
            im = Image.new("RGB", (cell, cell), (200, 180, 180))
        ox = x + (cell - im.width) // 2
        oy = y + band + (cell - im.height) // 2
        sheet.paste(im, (ox, oy))
        d.rectangle([x, y, x + cell, y + band], fill=(30, 28, 34))
        d.text((x + 5, y + 3), f"{label}-{gi:03d}", fill=(255, 255, 255), font=font)
    out = os.path.join(ART, f"montage_{label}_p{page + 1}.png")
    sheet.save(out)
    return out


def append_registry(files, label):
    existing = set()
    if os.path.exists(REG):
        with open(REG, newline="", encoding="utf-8") as f:
            for row in csv.DictReader(f):
                existing.add(row.get("art_ref", ""))
    new = []
    for i, f in enumerate(files):
        ref = ref_for(f)
        if ref in existing:
            continue
        row = {k: "" for k in COLUMNS}
        row.update(id=f"{label}-{i + 1:03d}", batch=label, art_ref=ref, status="new")
        new.append(row)
    write_header = not os.path.exists(REG)
    with open(REG, "a", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=COLUMNS)
        if write_header:
            w.writeheader()
        w.writerows(new)
    return len(new)


def main():
    ap = argparse.ArgumentParser(description="Ingest a creature-art batch into the registry.")
    ap.add_argument("source", help="path to a .zip or a directory of images")
    ap.add_argument("label", help="short batch label, e.g. batch3")
    ap.add_argument("--page", type=int, default=None, help="build only montage page N")
    ap.add_argument("--cols", type=int, default=6)
    ap.add_argument("--cell", type=int, default=240)
    ap.add_argument("--no-montage", action="store_true")
    a = ap.parse_args()

    d = extract(a.source, a.label)
    files = list_images(d)
    print(f"images: {len(files)} in {d}")
    added = append_registry(files, a.label)
    print(f"registry: +{added} new rows -> {os.path.basename(REG)}")
    if not a.no_montage and files:
        pages = math.ceil(len(files) / PER_SHEET)
        target = [a.page - 1] if a.page else range(pages)
        for p in target:
            out = build_montage(files, a.label, p, a.cols, a.cell)
            if out:
                print("montage:", os.path.relpath(out, ROOT))


if __name__ == "__main__":
    main()
