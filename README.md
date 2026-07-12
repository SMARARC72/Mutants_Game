# Mutants_Game

A funny-grim, mature-occult **creature-collection RPG** (Pokémon × Final Fantasy × Frankenstein): catch, breed, **splice**, and **ascend** force-born beasts in a world of dead Greek gods, climbing from gutter-rat to throne. Desktop. Stack: **Godot 4.7 · Supabase · Vercel · GitHub**.

This repo holds the **complete, validated design + the reference engines + the production codebase**. The design is locked; engineering proceeds along the phased runway in the TDD.

## Start here (canonical order)

1. **`Project_Architecture_Blueprint.md`** — the implementation-ready map of the current system,
   runtime flows, extension rules, release gates, and remaining production risks.
2. **`VERIFICATION.md`** — the single current release ledger; root `PHASE*_REPORT.md` files are
   historical delivery evidence, not current status.
3. **`docs/Mutants_Game_TechnicalDesign.md`** — the **normative** Technical Design Document
   (determinism/parity, data + RLS, services, save/sync, testing, CI/CD). Where it says MUST, it is a gate.
4. **`docs/Realization_Master_Plan.md`** — the visual/game-feel remediation program and its binding
   red-team corrections.
5. **`docs/Mutants_Game_INDEX.md`** — the map of every design doc and engine.
6. **`docs/Mutants_Game_Design_Bible.md`** — the master product/design canon.

The root `PHASE*_REPORT.md` files are historical delivery records. They are useful evidence, but they
do not describe the current feature level of `main`.

## Repo map (monorepo — TDD §12.1)

```
/client      # Godot 4.7 production client: domain/application/infrastructure/presentation + assets/tests
/oracle      # the canonical Python engines (8 *_engine.py + wire_line.py) + generated constants.py + tests/
/services    # Vercel TypeScript services: generation and succession endpoints + contract tests
/supabase    # migrations/ (0001–0004, including atomic save CAS) + seed + pgTAP/smoke tests
/docs        # ALL design + engineering docs (the *.md corpus) + /docs/adr (architecture decision records)
/design      # Claude design output (style guide, mockups, prototype) — lands here
/tools       # constants pipeline (balance_constants.json, gen_constants.mjs) + catalog/seed tooling
```

> **Promoted runtime art is versioned.** All 406 seedable species ship flat and cutout plates under
> `client/assets/creatures/`; the one registry row without a force is intentionally non-seedable.
> Large raw/source libraries remain outside normal history. See *Adding raw art via LFS* below.

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

## Adding raw art via LFS (optional follow-up)

Raw art (`art/`, ~752 MB) and UI slices (`assets/**.png`, ~62 MB) are **excluded from base history** for a fast, clean repo. To version them via LFS:

```bash
git lfs install
# remove the image excludes from .gitignore (/art/, *.png, *.jpg, …)
git add .gitignore art assets       # LFS picks them up via .gitattributes
git commit -m "Add art + UI assets via Git LFS"
git push                            # GitHub LFS must be enabled for the repo
```

## License / status

Private project. Design complete and red-teamed. The current release line includes the playable Act 0–5
arc, endings, battle/capture, lab, party/dossier, quests/journal, multi-region overworld, persistence,
audio, world dressing, complete creature art, atomic cloud-save contracts, service contracts, and
deterministic parity infrastructure. The 2026-07-11 closeout passed **101 Godot suites / 612 cases**,
all oracle/catalog/art/lint/balance gates, **37 TypeScript service tests**, responsive visual capture,
and clean headless/windowed shutdown. See `VERIFICATION.md` for exact evidence and external-runtime
gates.
