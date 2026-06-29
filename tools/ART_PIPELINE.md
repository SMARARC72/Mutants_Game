# AI Creature-Art Pipeline (`tools/gen_art.py`)

Offline, resumable batch generator that produces an on-model **bestiary-plate** image for every
creature in [`docs/creature_registry.csv`](../docs/creature_registry.csv) using the OpenAI Images
API (`gpt-image-1`).

It is a standalone seeding tool — separate from the in-game runtime proxy under
[`services/`](../services) (which does per-player, moderated, cost-capped, generate-once art at
play time). Both share the same locked visual vocabulary so the look stays coherent.

The prompt vocabulary is the **STYLE ANCHOR** + **FORCE VISUAL KEY** from
[`docs/Mutants_Game_ImageGen_Prompts.md`](../docs/Mutants_Game_ImageGen_Prompts.md), copied
verbatim into `gen_art.py` (keep them in sync if the doc changes).

---

## What it does

For each creature row it composes:

```
STYLE ANCHOR  +  Subject (name + role)  +  description
  +  Primary force visual key  +  a touch of the secondary force
  +  stage note (baby / mid / adult / apex)
  +  procedural one-of-one sigil/aura instruction (per-force motif)
```

then calls `gpt-image-1` and writes `art/generated/<id>_<name-slug>.png`, recording the result in
`art/generated/manifest.json`. `art/` is **gitignored** — bulk renders never enter git history;
the curated subset is hand-promoted into `client/assets/**` later (see below).

**Generate-once / resumable:** any creature already marked `done` in the manifest is skipped, so a
run interrupted partway through 400+ creatures resumes for free and never double-spends. Failures
are recorded as `failed` (with the error) and retried on the next run; one bad call never crashes
the batch.

---

## Setup (the OpenAI key)

The tool reads the key from, in order:

1. env var `OPENAI_API_KEY`, else
2. a gitignored file `tools/.art_secrets.env` (`KEY=VALUE` lines).

```bash
# Option A — env var (bash)
export OPENAI_API_KEY=sk-...

# Option A — env var (PowerShell)
$env:OPENAI_API_KEY = "sk-..."

# Option B — local file
cp tools/.art_secrets.env.example tools/.art_secrets.env
# then edit tools/.art_secrets.env and paste your key
```

`tools/.art_secrets.env` is in `.gitignore` and the repo's `tools/secret_scan.sh` gate fails CI on
any committed key — **never commit a real key.**

**With no key set, the tool runs in `--dry-run` automatically** (prints prompts, makes no network
call, spends nothing).

Python: 3.12. No third-party packages required — it uses the stdlib (`urllib`, `csv`, `json`).

---

## Usage

```bash
# Free: print the prompts that WOULD be generated (no key, no network, no spend)
python -B tools/gen_art.py --dry-run --limit 5

# Inspect specific creatures
python -B tools/gen_art.py --dry-run --only AD01,AD03

# Filter by registry batch / status
python -B tools/gen_art.py --dry-run --batch adult
python -B tools/gen_art.py --dry-run --status confirmed

# Live generation (requires a key) — generates only what isn't done yet
python -B tools/gen_art.py --batch adult
python -B tools/gen_art.py --only AD02

# Force re-generation of creatures already done
python -B tools/gen_art.py --only AD02 --force

# Larger size
python -B tools/gen_art.py --only AD02 --size 1024x1536
```

### CLI flags

| Flag         | Meaning |
|--------------|---------|
| `--dry-run`  | Print prompts only. No API calls, no key needed. Default when no key is present. |
| `--limit N`  | Process at most N creatures. |
| `--only ids` | Comma-separated creature id(s), e.g. `AD01,AD03`. |
| `--batch b`  | Only rows in registry batch `b` (`adult`, `demon`, `storybook`, `set2A`, `set2B`, `batch3/4/5`). |
| `--status s` | Only rows with status `s` (`confirmed`, `reviewed`, `draft`). |
| `--force`    | Re-generate creatures already marked `done`. |
| `--size`     | Image size `WxH` (default `1024x1024`). |
| `--out-dir`  | Output directory (default `art/generated`, gitignored). |

Every run prints a summary: how many would generate / are skipped, and a cost estimate.

---

## Cost note

`gpt-image-1` is billed per generated image; a 1024×1024 image is roughly **~$0.04 USD** (larger
sizes more). The printed estimate is a ballpark for planning only — **OpenAI's current pricing is
the source of truth.** A full first pass over the registry's ~400 generatable creatures is on the
order of a few tens of dollars at 1024×1024.

**`--dry-run` is always free** (no network call). Use it to review prompts before spending, and use
`--limit` / `--only` / `--batch` to generate in small, controllable chunks.

---

## How generated art becomes game assets

1. Generate into `art/generated/` (bulk, gitignored, with `manifest.json`).
2. **Curate:** review the renders, generate a few variants per creature (re-run with `--force`),
   pick the best as canon.
3. Promote the chosen file into the committed, curated tree under `client/assets/**` (binaries via
   Git LFS, per `.gitattributes`), following the conventions in
   [`docs/asset_registry.csv`](../docs/asset_registry.csv)
   (`id, name, category, ..., file, size, bg, status, ...`).
4. Log the canon choice back in `docs/creature_registry.csv` (the `art_ref` / `status` columns).

The raw `art/generated/` output stays out of git; only the curated subset the game actually uses is
committed.

---

## Tests

`tools/test_gen_art.py` covers the pure prompt builder and the manifest skip/resume (generate-once)
logic with the OpenAI call **mocked** — no network, no key:

```bash
python -B tools/test_gen_art.py
```
