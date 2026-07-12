#!/usr/bin/env python3
"""Wave 2 - asset contract gate (Realization plan W2; precedes the W7 art keystone).

Enforces, over every TRACKED file under client/assets/** (stdlib-only, no Godot, <1s):
  1. SIZE/DIM CAPS - any .png under client/assets/{creatures,tiles,backdrops} must be
     <= 1024 px on its longest side and <= 3 MB. Dimensions are read straight from the
     PNG IHDR chunk; when the working tree holds only an LFS pointer (CI checkout without
     `lfs: true`) the dimension check is skipped for that file, but the byte-size cap is
     still enforced from the pointer's `size` field.
  2. LFS COVERAGE - every binary asset type (png/jpg/jpeg/webp/wav/ogg/mp3/mp4) must
     resolve to `filter: lfs` via `git check-attr`, AND its INDEX blob must actually be
     an LFS pointer (catches files added before `git lfs install`, which silently land
     as full binaries even though the attribute matches).
  3. IMPORT METADATA - every tracked .png under client/assets/** must have its sibling
     `<file>.png.import` tracked too (a missing .import means CI's --import run mints
     fresh UIDs and every consumer scene rewires nondeterministically).

Run: PYTHONUTF8=1 python -B tools/check_asset_contract.py
Exits non-zero listing every violation; prints a one-line summary when clean.
"""

import csv
import json
import os
import struct
import subprocess
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSET_ROOT = "client/assets"
CAPPED_DIRS = (
    "client/assets/creatures",
    "client/assets/tiles",
    "client/assets/backdrops",
)
MAX_DIM_PX = 1024
MAX_BYTES = 3 * 1024 * 1024
LFS_EXTS = {".png", ".jpg", ".jpeg", ".webp", ".wav", ".ogg", ".mp3", ".mp4"}
LFS_POINTER_PREFIX = b"version https://git-lfs.github.com/spec/v1"
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
CREATURE_REGISTRY = "docs/creature_registry.csv"
CREATURE_MANIFEST = "client/assets/creatures/manifest.json"


def git(*args: str, data: bytes = b"") -> bytes:
    """Run a git command at the repo root and return raw stdout (raises on failure)."""
    proc = subprocess.run(
        ["git", *args], cwd=REPO_ROOT, input=data, capture_output=True, check=True
    )
    return proc.stdout


def tracked_asset_files() -> list[str]:
    out = git("ls-files", "-z", "--", ASSET_ROOT)
    return [p for p in out.decode("utf-8").split("\0") if p]


def lfs_filter_map(paths: list[str]) -> dict[str, str]:
    """path -> value of the `filter` attribute (e.g. 'lfs' / 'unspecified')."""
    payload = "\0".join(paths).encode("utf-8") + b"\0"
    out = git("check-attr", "--stdin", "-z", "filter", data=payload)
    fields = out.decode("utf-8").split("\0")
    attrs: dict[str, str] = {}
    # -z output is flat triplets: <path> <attr> <value> ...
    for i in range(0, len(fields) - 2, 3):
        attrs[fields[i]] = fields[i + 2]
    return attrs


def index_blob_head(path: str, nbytes: int = 256) -> bytes:
    """First bytes of the INDEX (staged) blob for path — what CI/collaborators receive."""
    return git("cat-file", "blob", f":{path}")[:nbytes]


def pointer_size(head: bytes) -> int | None:
    """Byte size recorded in an LFS pointer blob, or None if absent."""
    for line in head.decode("utf-8", errors="replace").splitlines():
        if line.startswith("size "):
            return int(line.split()[1])
    return None


def png_dimensions(abs_path: str) -> tuple[int, int] | None:
    """(width, height) from the IHDR chunk, or None when the file is an LFS pointer."""
    with open(abs_path, "rb") as fh:
        head = fh.read(33)
    if not head.startswith(PNG_SIGNATURE):
        return None  # LFS pointer (or corrupt) — the pointer/index checks cover it
    width, height = struct.unpack(">II", head[16:24])
    return width, height


def validate_creature_manifest(tracked: set[str]) -> list[str]:
    """Enforce exact registry -> manifest -> tracked plate coverage."""
    errors: list[str] = []
    registry_path = os.path.join(REPO_ROOT, CREATURE_REGISTRY)
    manifest_path = os.path.join(REPO_ROOT, CREATURE_MANIFEST)
    if not os.path.isfile(registry_path) or not os.path.isfile(manifest_path):
        return ["CREATURE ART CONTRACT: registry or manifest is missing"]
    with open(registry_path, newline="", encoding="utf-8-sig") as fh:
        registry_ids = {
            row["id"].strip()
            for row in csv.DictReader(fh)
            if row.get("id", "").strip() and row.get("status", "").strip().lower() != "void"
        }
    with open(manifest_path, encoding="utf-8") as fh:
        raw = json.load(fh)
    manifest = {key: value for key, value in raw.items() if not key.startswith("_")}
    manifest_ids = set(manifest)
    for species_id in sorted(registry_ids - manifest_ids):
        errors.append(f"CREATURE MANIFEST MISSING ID: {species_id}")
    for species_id in sorted(manifest_ids - registry_ids):
        errors.append(f"CREATURE MANIFEST UNKNOWN ID: {species_id}")
    used_paths: dict[str, str] = {}
    for species_id, entry in sorted(manifest.items()):
        if not isinstance(entry, dict) or not entry.get("flat"):
            errors.append(f"CREATURE MANIFEST INVALID ENTRY: {species_id} requires a flat plate")
            continue
        for variant in ("flat", "cutout"):
            relative = entry.get(variant)
            if not relative:
                continue
            asset_path = f"client/assets/creatures/{relative}".replace("\\", "/")
            if asset_path not in tracked:
                errors.append(f"CREATURE PLATE NOT TRACKED: {species_id}.{variant} -> {asset_path}")
            previous = used_paths.get(asset_path)
            if previous is not None:
                errors.append(
                    f"CREATURE PLATE REUSED: {species_id}.{variant} and {previous} -> {asset_path}"
                )
            used_paths[asset_path] = f"{species_id}.{variant}"
    return errors


def main() -> int:
    files = tracked_asset_files()
    if not files:
        print(f"asset contract: nothing tracked under {ASSET_ROOT} — nothing to check")
        return 0
    tracked = set(files)
    filters = lfs_filter_map(files)
    errors: list[str] = []
    errors.extend(validate_creature_manifest(tracked))

    for path in files:
        ext = os.path.splitext(path)[1].lower()
        abs_path = os.path.join(REPO_ROOT, path)

        # --- 2a. binary asset types must be LFS-attributed -------------------------------
        if ext in LFS_EXTS and filters.get(path) != "lfs":
            errors.append(f"NOT LFS-ATTRIBUTED: {path} (add a pattern to .gitattributes)")

        # --- 2b. lfs-attributed files must really be pointers in the index ---------------
        size_in_index: int | None = None
        if filters.get(path) == "lfs":
            head = index_blob_head(path)
            if head.startswith(LFS_POINTER_PREFIX):
                size_in_index = pointer_size(head)
            else:
                errors.append(
                    f"NOT AN LFS POINTER IN THE INDEX: {path} "
                    "(full binary committed — re-add after `git lfs install`)"
                )

        # --- 3. every tracked png ships its .import --------------------------------------
        if ext == ".png" and f"{path}.import" not in tracked:
            errors.append(f"MISSING .import: {path} (commit {path}.import)")

        # --- 1. size/dim caps on the art directories --------------------------------------
        if ext == ".png" and path.startswith(CAPPED_DIRS):
            byte_size = size_in_index
            if byte_size is None and os.path.isfile(abs_path):
                byte_size = os.path.getsize(abs_path)
            if byte_size is not None and byte_size > MAX_BYTES:
                errors.append(
                    f"OVERSIZE FILE: {path} is {byte_size / 1048576:.2f} MB "
                    f"(cap {MAX_BYTES / 1048576:.0f} MB)"
                )
            if os.path.isfile(abs_path):
                dims = png_dimensions(abs_path)
                if dims is not None and max(dims) > MAX_DIM_PX:
                    errors.append(
                        f"OVERSIZE DIMENSIONS: {path} is {dims[0]}x{dims[1]} "
                        f"(cap {MAX_DIM_PX} px on the longest side)"
                    )

    if errors:
        print(f"asset contract: {len(errors)} violation(s)")
        for err in errors:
            print(f"  {err}")
        return 1
    print(f"asset contract: clean ({len(files)} tracked files under {ASSET_ROOT})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
