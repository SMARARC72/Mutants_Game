#!/usr/bin/env python3
"""Fill the empty art_ref cells for batch4/batch5 rows in docs/creature_registry.csv, IN PLACE.

Red-team correction C1 (docs/Realization_Master_Plan.md): the 219 batch4/batch5 rows ALREADY
exist (authored names, status 'reviewed') with an empty art_ref column. Re-running
tools/catalog_batch.py would APPEND 219 duplicate nameless rows (it dedupes on art_ref only).
This script instead re-derives the exact file order catalog_batch.list_images() used —
sorted(glob(dir/**/*)) filtered by image extension — and zips it against the existing
batch4/batch5 registry rows in file order, writing ONLY the art_ref cell.

The rest of the CSV is preserved byte-exactly: rows are edited as raw text with a tiny
quote-aware comma scanner, never re-serialized through the csv writer.

Usage:
    python tools/fill_artref.py [--art-root <path-to-main-repo-art>] [--dry-run]
"""

from __future__ import annotations

import argparse
import csv
import glob
import io
import os
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REGISTRY = os.path.join(REPO, "docs", "creature_registry.csv")
DEFAULT_ART_ROOT = "c:/Users/arahi/Documents/Claude/Projects/Mutants_Game/art"
IMG_EXT = (".png", ".jpg", ".jpeg", ".webp")  # keep identical to catalog_batch.py
BATCHES = ("batch4", "batch5")
ART_REF_FIELD = "art_ref"


def list_images(d: str) -> list[str]:
    """Byte-for-byte the same ordering as tools/catalog_batch.py list_images()."""
    return sorted(
        f
        for f in glob.glob(os.path.join(d, "**", "*"), recursive=True)
        if f.lower().endswith(IMG_EXT)
    )


def ref_for(path: str, art_root: str) -> str:
    """Registry art_ref format used by batch3 rows: 'art/<batch>/<subpath>' fwd slashes."""
    rel = os.path.relpath(path, os.path.dirname(art_root))
    return rel.replace("\\", "/")


def csv_quote(value: str) -> str:
    """QUOTE_MINIMAL serialization of a single cell, matching the csv module."""
    out = io.StringIO()
    csv.writer(out, lineterminator="").writerow([value])
    return out.getvalue()


def insert_art_ref(raw_line: str, field_index: int, quoted_value: str) -> str:
    """Insert `quoted_value` into the EMPTY field `field_index` of a raw CSV line.

    Walks the line with a quote-state machine counting top-level commas; asserts the
    target field is empty (delimiter immediately follows delimiter / end).
    """
    depth_commas = 0
    in_quotes = False
    i = 0
    if field_index == 0:
        start = 0
    else:
        start = -1
        while i < len(raw_line):
            ch = raw_line[i]
            if in_quotes:
                if ch == '"':
                    if i + 1 < len(raw_line) and raw_line[i + 1] == '"':
                        i += 1  # escaped quote
                    else:
                        in_quotes = False
            elif ch == '"':
                in_quotes = True
            elif ch == ",":
                depth_commas += 1
                if depth_commas == field_index:
                    start = i + 1
                    break
            i += 1
        if start < 0:
            raise ValueError("line has fewer fields than expected: " + raw_line)
    if start < len(raw_line) and raw_line[start] != ",":
        raise ValueError("target art_ref field is not empty: " + raw_line)
    return raw_line[:start] + quoted_value + raw_line[start:]


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--art-root", default=DEFAULT_ART_ROOT)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    original = open(REGISTRY, "rb").read()
    text = original.decode("utf-8")
    if not text.endswith("\r\n"):
        raise SystemExit("registry expected to end with CRLF")
    lines = text[:-2].split("\r\n")  # keep it strict: every line CRLF-terminated
    header = next(csv.reader([lines[0]]))
    art_ref_idx = header.index(ART_REF_FIELD)
    id_idx = header.index("id")
    batch_idx = header.index("batch")

    # registry line numbers (0-based into `lines`) per batch, in file order
    per_batch: dict[str, list[int]] = {b: [] for b in BATCHES}
    for n, line in enumerate(lines[1:], start=1):
        row = next(csv.reader([line]))
        if row[batch_idx] in per_batch:
            per_batch[row[batch_idx]].append(n)

    edits = 0
    for label in BATCHES:
        files = list_images(os.path.join(args.art_root, label))
        rows = per_batch[label]
        if len(files) != len(rows):
            raise SystemExit(
                f"{label}: {len(files)} files vs {len(rows)} registry rows — refusing"
            )
        for seq, (line_no, path) in enumerate(zip(rows, files), start=1):
            row = next(csv.reader([lines[line_no]]))
            expect_id = f"{label}-{seq:03d}"
            if row[id_idx] != expect_id:
                raise SystemExit(
                    f"{label}: row order broke — line {line_no + 1} id {row[id_idx]}"
                    f" != {expect_id}"
                )
            if row[art_ref_idx] != "":
                raise SystemExit(f"{expect_id}: art_ref already set — refusing")
            ref = ref_for(path, args.art_root)
            lines[line_no] = insert_art_ref(lines[line_no], art_ref_idx, csv_quote(ref))
            edits += 1

    updated = ("\r\n".join(lines) + "\r\n").encode("utf-8")

    # verification: exactly `edits` cells changed, all art_ref, everything else identical
    old_rows = list(csv.reader(io.StringIO(original.decode("utf-8"))))
    new_rows = list(csv.reader(io.StringIO(updated.decode("utf-8"))))
    assert len(old_rows) == len(new_rows), "row count changed"
    changed = 0
    for old, new in zip(old_rows, new_rows):
        assert len(old) == len(new), "field count changed: " + ",".join(old)
        for col, (a, b) in enumerate(zip(old, new)):
            if a != b:
                assert col == art_ref_idx and a == "", "non-art_ref cell changed"
                changed += 1
    assert changed == edits, f"expected {edits} changed cells, found {changed}"

    if args.dry_run:
        print(f"dry-run OK: would fill {edits} art_ref cells")
        return 0
    with open(REGISTRY, "wb") as f:
        f.write(updated)
    print(f"filled {edits} art_ref cells in {os.path.relpath(REGISTRY, REPO)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
