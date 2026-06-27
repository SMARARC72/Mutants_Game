# Mutants_Game

A funny-grim, mature-occult **creature-collection RPG** (Pokémon × Final Fantasy × Frankenstein): catch, breed, **splice**, and **ascend** force-born beasts in a world of dead Greek gods, climbing from gutter-rat to throne. Desktop. Stack: **Godot 4.7 · Supabase · Vercel · GitHub**.

This repo holds the **complete, validated design + the reference engines + the production codebase**. The design is locked; engineering proceeds along the phased runway in the TDD.

## Start here (canonical order)

1. **`docs/Mutants_Game_TechnicalDesign.md`** — the **normative** Technical Design Document (architecture, the determinism/parity oracle, data + RLS, services, save/sync, testing, CI/CD, the phased runway, risks). Where it says MUST, it's a gate.
2. **`docs/Claude_Code_Phase0_Kickoff.md`** — the Phase 0 execution prompt (foundations & guardrails).
3. **`docs/Mutants_Game_INDEX.md`** — the map of every design doc and engine.
4. **`docs/Mutants_Game_Design_Bible.md`** — the master design.
5. **`PHASE0_REPORT.md`** — what Phase 0 delivered + how to run every part locally.

## Repo map (monorepo — TDD §12.1)

```
/client      # Godot 4.7 project (scaffold this phase: project.godot, domain/application/infra/presentation skeleton)
/oracle      # the canonical Python engines (8 *_engine.py + wire_line.py) + generated constants.py + tests/
/services    # Vercel/Next services layer (scaffold: package.json, /api placeholder, README)
/supabase    # migrations/ (0001 init · 0002 hardening · 0003 RLS) + seed.sql + tests/ (pgTAP) + config.toml
/docs        # ALL design + engineering docs (the *.md corpus) + /docs/adr (architecture decision records)
/design      # Claude design output (style guide, mockups, prototype) — lands here
/tools       # constants pipeline (balance_constants.json, gen_constants.mjs) + catalog/seed tooling
```

> **Raw art is intentionally out of git history.** ~814 MB of `art/` (ChatGPT exports) and `assets/**.png` (UI slices) live on disk but are git-ignored (see `.gitignore`). Git LFS is pre-configured (`.gitattributes`) to track them if/when they are added — see *Adding art via LFS* below.

## Engines are law (the oracle)

The Python engines in `/oracle` (`stat_engine.py`, `level_engine.py`, `lab_engine.py`, `battle_engine.py`, `skill_engine.py`, `status_engine.py`, `loot_engine.py`, `character_engine.py`, `wire_line.py`) **define correct game behavior.** The Godot client ports them and must match via parity tests (TDD §6, §11). Do **not** change their logic outside the process in the TDD.

- **Edit the `.py` engines via shell only** (the editor tooling mangles their multi-line string concatenations — a recorded incident); run with `python -B`. On Windows set `PYTHONUTF8=1` for the unicode in sample output.

## Running each part locally

| Part | Command | Needs |
|---|---|---|
| **Oracle engines** | `cd oracle && python -B stat_engine.py` (etc.) | Python 3.12 |
| **Constants parity test** | `python -B tools/test_constants_parity.py` | Python 3.12 |
| **Regenerate constants** | `node tools/gen_constants.mjs` → `client/domain/constants.gd`, `oracle/constants.py` | Node 18+ |
| **Regenerate seed** | `node tools/gen_seed.mjs` → `supabase/seed.sql` | Node 18+ |
| **DB migrations + seed** | `cd supabase && npx supabase db reset` | Docker, Supabase CLI |
| **RLS proof (pgTAP)** | `cd supabase && npx supabase test db` | Docker, Supabase CLI |
| **Anon-auth smoke test** | `node supabase/tests/smoke_anon_isolation.mjs` (against a running local stack) | Docker, Node |

Full, copy-pasteable instructions are in **`PHASE0_REPORT.md`**.

## Guardrails (from the TDD — non-negotiable)

- **Secrets never in the client** (Supabase **anon** key only; OpenAI/service-role keys are server-side on Vercel). CI secret-scans.
- **RLS default-deny** on every table; `art_assets` authorizes via a **two-hop** join (it has no `run_id`).
- **Determinism is a feature:** all game randomness goes through a canonical seeded RNG (Phase 1); the Python engines are the oracle and parity is a CI gate.
- **No ad-hoc DDL** — every schema change is a timestamped Supabase migration.

## Adding art via LFS (optional follow-up)

Raw art (`art/`, ~752 MB) and UI slices (`assets/**.png`, ~62 MB) are **excluded from base history** for a fast, clean repo. To version them via LFS:

```bash
git lfs install
# remove the image excludes from .gitignore (/art/, *.png, *.jpg, …)
git add .gitignore art assets       # LFS picks them up via .gitattributes
git commit -m "Add art + UI assets via Git LFS"
git push                            # GitHub LFS must be enabled for the repo
```

## License / status

Private project. Design complete and red-teamed. **Phase 0 (foundations & guardrails) delivered** — see `PHASE0_REPORT.md`.
