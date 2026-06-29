#!/usr/bin/env python3
"""AI creature-art generation pipeline (Phase 7). Composes an on-model image prompt for every
creature in docs/creature_registry.csv from the locked STYLE ANCHOR + FORCE VISUAL KEY
(docs/Mutants_Game_ImageGen_Prompts.md), then calls the OpenAI Images API (gpt-image-1) to
generate a bestiary plate per creature.

Design goals (mirror the in-game proxy in services/, but for offline bulk seeding):
  * Pure, unit-testable prompt builder (build_prompt) — no I/O, no network.
  * Generate-once / resumable via a manifest JSON: a creature already "done" is skipped unless
    --force, so a half-finished 407-creature run resumes for free and never double-spends.
  * --dry-run requires NO key and makes NO network call (the safe default when no key is set).
  * Dependency-light: stdlib urllib against the REST endpoint — no `openai` package needed.
  * Never crash the whole run on one API error: retry w/ backoff, record the failure, continue.

The OpenAI key is read from env OPENAI_API_KEY, falling back to a gitignored
tools/.art_secrets.env (KEY=VALUE lines). A key is NEVER hardcoded or committed.

Run:  python -B tools/gen_art.py --dry-run --limit 5
      python -B tools/gen_art.py --only AD01,AD03
      python -B tools/gen_art.py --batch adult --status confirmed
See tools/ART_PIPELINE.md for setup, usage and the curation workflow.
"""
import argparse
import csv
import datetime
import hashlib
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
import warnings

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REGISTRY = os.path.join(ROOT, "docs", "creature_registry.csv")
SECRETS_FILE = os.path.join(ROOT, "tools", ".art_secrets.env")
DEFAULT_OUT = os.path.join(ROOT, "art", "generated")

OPENAI_URL = "https://api.openai.com/v1/images/generations"
DEFAULT_MODEL = "gpt-image-1"
DEFAULT_SIZE = "1024x1024"
# Ballpark gpt-image-1 cost per 1024x1024 image (USD). For an estimate banner only; OpenAI is
# the source of truth — see tools/ART_PIPELINE.md.
PRICE_PER_IMAGE_USD = {
    "1024x1024": 0.04,
    "1024x1536": 0.06,
    "1536x1024": 0.06,
}

# ---------------------------------------------------------------------------
# STYLE ANCHOR + FORCE VISUAL KEY — copied verbatim from
# docs/Mutants_Game_ImageGen_Prompts.md (the locked visual vocabulary). This module is the
# single Python source of that vocabulary; keep it in sync with the doc if the doc changes.
# ---------------------------------------------------------------------------
STYLE_ANCHOR = (
    "Painterly digital creature concept art for an occult monster-collecting RPG, in the style "
    "of a hand-illustrated bestiary plate. A single full-body creature, 3/4 view, centered on a "
    "plain warm parchment/cream background with a soft contact shadow. Richly detailed, cohesive "
    "brushwork, characterful and a little eerie, with faint glowing sigil-markings worked into "
    "the body. No text, no border, no watermark."
)

FORCE_VISUAL_KEY = {
    "Cosmos": (
        "serene symmetry, concentric halo-rings and geometric sigils, crystalline filigree; "
        "white, pale gold, soft blue; an aura of calm precision"
    ),
    "Chaos": (
        "broken symmetry, fracturing shifting forms, mismatched parts, jagged runes; oil-slick "
        "iridescence and hot magenta; unstable flickering energy"
    ),
    "Eros": (
        "blossoms, curling vines, moss and ripe fruit growing from the body; warm greens, rose, "
        "honey-gold; soft and overflowing with growth"
    ),
    "Thanatos": (
        "exposed bone, ash, withered hide; cold violet-and-teal soul-fire; desaturated greys "
        "with one sickly accent; quiet decay"
    ),
    "Gaia": (
        "plates of stone and bark, embedded crystal and moss; heavy grounded silhouette; granite "
        "browns and deep greens; immense mass"
    ),
    "Ouranos": (
        "layered feathers, trailing wind-ribbons, sparks of lightning and star-glow; silver-blue "
        "and cyan; weightless, lifted"
    ),
}

# Per-force sigil flavour for the in-game uniqueness layer (doc §5).
SIGIL_MOTIF = {
    "Cosmos": "geometric",
    "Chaos": "jagged",
    "Eros": "floral",
    "Thanatos": "bone-flame",
    "Gaia": "stone-rune",
    "Ouranos": "feather-star",
}

# Stage steers the cute->grim silhouette (doc's broken-evolution-line guidance).
STAGE_NOTE = {
    "baby": "Baby stage: small, oversized head, stubby proportions, curious and endearing.",
    "mid": "Mid stage: adolescent, leaner and more defined, growing into its power.",
    "adult": "Adult stage: fully grown, confident, its force fully expressed.",
    "apex": "Apex stage: an awe-and-dread apex form at divine scale, the line's pinnacle.",
}

# Skipped registry rows: blank/placeholder records (e.g. status 'void', no name/force).
SKIP_STATUSES = {"void"}


# ---------------------------------------------------------------------------
# Prompt builder (pure) — the heart of the genome->prompt prototype.
# ---------------------------------------------------------------------------
def slugify(text):
    """Return a filesystem-safe lowercase slug (a-z0-9 and single hyphens)."""
    slug = re.sub(r"[^a-z0-9]+", "-", (text or "").lower()).strip("-")
    return slug or "creature"


def force_phrase(force):
    """Return the FORCE VISUAL KEY clause for a force, or '' for unknown/blank."""
    return FORCE_VISUAL_KEY.get((force or "").strip(), "")


def build_prompt(row):
    """Compose the final image prompt for one creature row (a dict from creature_registry.csv).

    prompt = STYLE_ANCHOR + primary force-visual-key (+ a touch of secondary) + name/role/stage/
    description + the procedural-sigil uniqueness instruction. Pure: same row -> same string.
    """
    prim = (row.get("force_primary") or "").strip()
    sec = (row.get("force_secondary") or "").strip()
    name = (row.get("name") or "").strip() or "an unnamed creature"
    role = (row.get("role") or "").strip()
    stage = (row.get("stage") or "").strip()
    desc = (row.get("description") or "").strip()

    parts = [STYLE_ANCHOR]

    # Subject line: name + role.
    subject = "Subject: %s" % name
    if role:
        subject += ", a %s-role creature" % role
    subject += "."
    parts.append(subject)

    if desc:
        parts.append(desc if desc.endswith(".") else desc + ".")

    # Primary force look (dominant), with a touch of the secondary.
    pf = force_phrase(prim)
    if pf:
        parts.append("Primary force %s — %s." % (prim, pf))
    sf = force_phrase(sec)
    if sf and sec != prim:
        parts.append("With a touch of %s: %s." % (sec, sf))

    note = STAGE_NOTE.get(stage)
    if note:
        parts.append(note)

    # Procedural-sigil uniqueness instruction (doc §5): vary the seed for one-of-one results.
    motif = SIGIL_MOTIF.get(prim, "occult")
    parts.append(
        "Work a unique glowing %s occult sigil/aura into the creature as its one-of-one mark; "
        "vary it per individual. Portrait 2:3 framing, plain background, no text or border."
        % motif
    )

    return " ".join(p.strip() for p in parts if p.strip())


# ---------------------------------------------------------------------------
# Registry loading + filtering.
# ---------------------------------------------------------------------------
def load_registry(path=REGISTRY):
    """Load creature rows from the CSV (proper csv parsing — descriptions contain commas)."""
    with open(path, newline="", encoding="utf-8") as fh:
        return list(csv.DictReader(fh))


def is_generatable(row):
    """A row is generatable if it is a real creature, not a blank placeholder.

    Many registry rows (batch3/4/5) have a force_primary + art_ref but no name yet; those are
    real creatures and DO get a meaningful force-driven prompt. We only skip 'void'-status rows
    and truly-blank rows that have neither a name nor a primary force.
    """
    if (row.get("status") or "").strip().lower() in SKIP_STATUSES:
        return False
    has_name = bool((row.get("name") or "").strip())
    has_force = bool((row.get("force_primary") or "").strip())
    return has_name or has_force


def select_rows(rows, only=None, batch=None, status=None, limit=None):
    """Filter rows by the CLI selectors and return the chosen subset (order preserved)."""
    only_set = {x.strip() for x in only.split(",")} if only else None
    out = []
    for row in rows:
        if not is_generatable(row):
            continue
        if only_set is not None and row["id"] not in only_set:
            continue
        if batch is not None and row.get("batch") != batch:
            continue
        if status is not None and row.get("status") != status:
            continue
        out.append(row)
    if limit is not None:
        out = out[:limit]
    return out


def output_path(out_dir, row):
    """art/generated/<id>_<name-slug>.png"""
    return os.path.join(out_dir, "%s_%s.png" % (row["id"], slugify(row.get("name"))))


# ---------------------------------------------------------------------------
# Manifest (generate-once / resumable).
# ---------------------------------------------------------------------------
def manifest_path(out_dir):
    return os.path.join(out_dir, "manifest.json")


def load_manifest(out_dir):
    """Load the manifest dict {id -> entry}, or {} if none exists yet."""
    path = manifest_path(out_dir)
    if not os.path.exists(path):
        return {}
    with open(path, "r", encoding="utf-8") as fh:
        data = json.load(fh)
    return data.get("creatures", data) if isinstance(data, dict) else {}


def save_manifest(out_dir, manifest):
    """Persist the manifest atomically (write temp + replace) so a crash never corrupts it."""
    os.makedirs(out_dir, exist_ok=True)
    path = manifest_path(out_dir)
    payload = {
        "schema_version": 1,
        "model": DEFAULT_MODEL,
        "updated_at": _now_iso(),
        "creatures": manifest,
    }
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(payload, fh, indent=2, sort_keys=True)
    os.replace(tmp, path)


def is_done(manifest, row):
    """A creature is 'done' if it has a manifest entry with status 'done'."""
    entry = manifest.get(row["id"])
    return bool(entry) and entry.get("status") == "done"


# ---------------------------------------------------------------------------
# Secret + OpenAI client.
# ---------------------------------------------------------------------------
def load_api_key(secrets_file=SECRETS_FILE):
    """Return the OpenAI key from env OPENAI_API_KEY, else from the gitignored secrets file.

    The secrets file is KEY=VALUE lines; we read OPENAI_API_KEY. Returns None if absent.
    """
    env = os.environ.get("OPENAI_API_KEY")
    if env and env.strip():
        return env.strip()
    if os.path.exists(secrets_file):
        with open(secrets_file, "r", encoding="utf-8") as fh:
            for line in fh:
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                key, _, value = line.partition("=")
                if key.strip() == "OPENAI_API_KEY":
                    return value.strip().strip('"').strip("'") or None
    return None


def _now_iso():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


class OpenAIImageClient:
    """Thin stdlib-urllib wrapper over POST /v1/images/generations (gpt-image-1).

    Kept dumb and replaceable so tests inject a fake. Returns raw PNG bytes.
    """

    def __init__(self, api_key, model=DEFAULT_MODEL, size=DEFAULT_SIZE, url=OPENAI_URL,
                 opener=None):
        self.api_key = api_key
        self.model = model
        self.size = size
        self.url = url
        # `opener` is injectable for tests: a callable(request_dict) -> png_bytes.
        self._opener = opener

    def generate(self, prompt):
        """Generate one image for `prompt`; return PNG bytes. Raises on transport/API error."""
        body = {"model": self.model, "prompt": prompt, "n": 1, "size": self.size}
        if self._opener is not None:
            return self._opener({"url": self.url, "headers": self._headers(), "body": body})
        return self._http_generate(body)

    def _headers(self):
        return {
            "Authorization": "Bearer %s" % self.api_key,
            "Content-Type": "application/json",
        }

    def _http_generate(self, body):
        data = json.dumps(body).encode("utf-8")
        req = urllib.request.Request(self.url, data=data, headers=self._headers(),
                                     method="POST")
        with urllib.request.urlopen(req, timeout=180) as resp:
            payload = json.loads(resp.read().decode("utf-8"))
        # gpt-image-1 returns b64_json by default.
        import base64
        items = payload.get("data") or []
        b64 = items[0].get("b64_json") if items else None
        if not b64:
            raise RuntimeError("OpenAI returned no image data")
        return base64.b64decode(b64)


def generate_with_retry(client, prompt, retries=3, backoff=2.0, sleep=time.sleep):
    """Call client.generate(prompt) with exponential backoff. Raise the last error if all fail."""
    last = None
    for attempt in range(retries):
        try:
            return client.generate(prompt)
        except (urllib.error.URLError, urllib.error.HTTPError, RuntimeError, OSError) as err:
            last = err
            if attempt < retries - 1:
                sleep(backoff * (2 ** attempt))
    raise last


# ---------------------------------------------------------------------------
# Run.
# ---------------------------------------------------------------------------
def price_for(size):
    """Per-image USD price for `size`, falling back to the default-size price if unknown.

    Use `price_is_known(size)` to tell whether the returned price actually matches `size`; the
    CLI surfaces that so a non-whitelisted --size doesn't silently quote the default-size price.
    """
    return PRICE_PER_IMAGE_USD.get(size, PRICE_PER_IMAGE_USD[DEFAULT_SIZE])


def price_is_known(size):
    """True if `size` has its own entry in PRICE_PER_IMAGE_USD (i.e. price_for(size) is exact)."""
    return size in PRICE_PER_IMAGE_USD


def run(args):
    """Execute the pipeline per parsed args; return an exit code (0 ok)."""
    rows = load_registry()
    selected = select_rows(rows, only=args.only, batch=args.batch, status=args.status,
                           limit=args.limit)
    out_dir = args.out_dir
    manifest = load_manifest(out_dir)

    api_key = load_api_key()
    # --dry-run when explicitly requested OR when no key is available (safe default).
    dry_run = args.dry_run or not api_key
    if args.dry_run:
        mode = "dry-run (requested)"
    elif not api_key:
        mode = "dry-run (no OPENAI_API_KEY / tools/.art_secrets.env found)"
    else:
        mode = "live"

    print("Mutants_Game art pipeline — %s" % mode)
    print("  registry : %s (%d generatable of %d rows)"
          % (os.path.relpath(REGISTRY, ROOT), sum(1 for r in rows if is_generatable(r)),
             len(rows)))
    print("  selected : %d  | out: %s  | model: %s  | size: %s"
          % (len(selected), os.path.relpath(out_dir, ROOT) if out_dir.startswith(ROOT)
             else out_dir, DEFAULT_MODEL, args.size))

    to_gen, skipped = [], []
    for row in selected:
        if is_done(manifest, row) and not args.force:
            skipped.append(row)
        else:
            to_gen.append(row)

    unit = price_for(args.size)
    est = len(to_gen) * unit
    print("  plan     : %d to generate, %d already done (skipped)"
          % (len(to_gen), len(skipped)))
    # Make the price basis explicit if --size isn't in the price table (we used the default).
    basis = "" if price_is_known(args.size) else " (price basis: default size %s)" % DEFAULT_SIZE
    print("  estimate : ~$%.2f USD (%d x $%.2f @ %s)%s — $0.00 in dry-run"
          % (est, len(to_gen), unit, args.size, basis))
    if basis:
        warnings.warn(
            "--size %s has no listed price; cost estimate uses the default-size (%s) price."
            % (args.size, DEFAULT_SIZE), RuntimeWarning, stacklevel=2)
    print("")

    if dry_run:
        for row in to_gen:
            print("--- %s  %s  [%s/%s %s]" % (row["id"], row.get("name", ""),
                  row.get("force_primary", ""), row.get("force_secondary", "") or "-",
                  row.get("stage", "") or "-"))
            print(build_prompt(row))
            print("")
        print("DRY RUN: %d prompt(s) shown, 0 API calls, $0.00 spent." % len(to_gen))
        return 0

    if not to_gen:
        print("Nothing to generate — all selected creatures are already done.")
        return 0

    os.makedirs(out_dir, exist_ok=True)
    client = OpenAIImageClient(api_key, model=DEFAULT_MODEL, size=args.size)
    generated, failed = 0, 0
    for row in to_gen:
        prompt = build_prompt(row)
        out_file = output_path(out_dir, row)
        try:
            png = generate_with_retry(client, prompt)
            with open(out_file, "wb") as fh:
                fh.write(png)
            manifest[row["id"]] = {
                "name": row.get("name", ""),
                "prompt": prompt,
                "model": DEFAULT_MODEL,
                "size": args.size,
                "output_file": os.path.relpath(out_file, ROOT).replace("\\", "/"),
                "sha256": hashlib.sha256(png).hexdigest(),
                "status": "done",
                "created_at": _now_iso(),
            }
            generated += 1
            print("  [ok]   %s -> %s" % (row["id"], os.path.basename(out_file)))
        except Exception as err:  # noqa: BLE001 — never crash the run; record + continue.
            failed += 1
            manifest[row["id"]] = {
                "name": row.get("name", ""),
                "prompt": prompt,
                "model": DEFAULT_MODEL,
                "size": args.size,
                "output_file": None,
                "sha256": None,
                "status": "failed",
                "error": "%s: %s" % (type(err).__name__, err),
                "created_at": _now_iso(),
            }
            print("  [FAIL] %s -> %s" % (row["id"], err))
        # Persist after every creature so a crash/Ctrl-C still resumes cleanly.
        save_manifest(out_dir, manifest)

    print("")
    print("Done: %d generated, %d failed, %d skipped. Manifest: %s"
          % (generated, failed, len(skipped),
             os.path.relpath(manifest_path(out_dir), ROOT)))
    return 1 if failed and not generated else 0


def build_arg_parser():
    p = argparse.ArgumentParser(
        description="Generate on-model creature art for Mutants_Game (OpenAI gpt-image-1).",
        epilog="Without a key, runs in --dry-run automatically (prints prompts, no spend).")
    p.add_argument("--dry-run", action="store_true",
                   help="print prompts only; no API calls, no key needed (default if no key)")
    p.add_argument("--limit", type=int, default=None,
                   help="cap the number of creatures processed")
    p.add_argument("--only", default=None,
                   help="comma-separated creature id(s), e.g. AD01,AD03")
    p.add_argument("--batch", default=None,
                   help="only this registry batch (e.g. adult, demon, storybook)")
    p.add_argument("--status", default=None,
                   help="only rows with this status (e.g. confirmed, reviewed)")
    p.add_argument("--force", action="store_true",
                   help="re-generate creatures already marked done in the manifest")
    p.add_argument("--size", default=DEFAULT_SIZE,
                   help="image size WxH (default %s)" % DEFAULT_SIZE)
    p.add_argument("--out-dir", default=DEFAULT_OUT,
                   help="output directory (default art/generated — gitignored)")
    return p


def main(argv=None):
    args = build_arg_parser().parse_args(argv)
    return run(args)


if __name__ == "__main__":
    sys.exit(main())
