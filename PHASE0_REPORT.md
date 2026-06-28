# PHASE 0 — Foundations & Guardrails · Report

**Status:** ✅ Complete — all 6 deliverables built; every gate verified green locally.
**Branch:** `phase-0-foundations` → PR into `main`. **Date:** 2026-06-27.
**Scope discipline:** no engine port, no gameplay, no screens. The Python engines were
**relocated unchanged**; only their constants were transcribed.

---

## TL;DR — Definition of Done

| # | DoD gate | Status | Evidence |
|---|---|---|---|
| 1 | Monorepo layout, single lean baseline, LFS configured | ✅ | `git mv` reorg; `.git` 805 MB → 738 KB; LFS hooks+patterns ready (art excluded by design) |
| 2 | `supabase db reset` applies 0001+0002+0003+seed cleanly | ✅ | reset output: all 3 migrations + seed, no errors |
| 3 | pgTAP RLS suite green (allow+deny every owned table; catalog; god_snapshots) | ✅ | `supabase test db` → **54/54 PASS**; deny-tests proven to have teeth |
| 4 | Anonymous player row creatable + RLS-isolated | ✅ | `smoke_anon_isolation.mjs` → **PASS** (B cannot read/modify A's run) |
| 5 | `balance_constants.json` parity test green; generator emits constants.gd + .py | ✅ | parity **113/113**; `gen_constants.mjs` emits both with float fidelity |
| 6 | CI green on PR; red on planted secret or broken RLS | ✅ (authored + each command verified locally) | `.github/workflows/ci.yml`; secret scan + deny-test teeth proven |
| 7 | This report | ✅ | you're reading it |
| 8 | STOP before Phase 1 | ✅ | Phase 0.5 (resource integration) follows; Phase 1 not started |

---

## Deliverables

### D1 — Monorepo + relocation + lean baseline
- Reorganized the flat project into TDD §12.1 layout via `git mv` (rename-preserving):
  `/oracle` (8 engines + `wire_line.py`, **unchanged**), `/docs` (67 design docs + `/docs/adr`),
  `/supabase`, `/tools`, `/client` (Godot scaffold), `/services` (Vercel scaffold), `/design`.
- **Lean baseline (per your decision):** the single `Foundation Baseline` commit had accidentally
  committed 647 PNGs (~814 MB of `art/` + `assets/`) as plain blobs. Rebuilt it so art is **excluded
  from base history** (matching your `.gitignore`/`.gitattributes`/README plan). `.git` dropped from
  **805 MB → 738 KB**; art files remain on disk, git-ignored. **LFS patterns are active** and ready
  to track binaries if/when added (`git lfs track` lists `*.png …`).
- Root `README.md` rewritten for the monorepo + run instructions.

### D2 — Migrations + seed
- `0001_init.sql` — the 13-table base, faithfully refactored from `schema.sql`.
- `0002_hardening.sql` — `players.id → auth.users(id)` (default dropped, empty-DB); `updated_at` +
  trigger on every mutable table; `runs.save_version`/`schema_version`; force/status/relationship
  CHECKs; on-delete (children CASCADE from runs; `god_snapshots` SET NULL); non-negative + `corruption ≤ 130`
  CHECKs; `art_assets.status` + **`unique (instance_id)`**; partial party index + inventory + shareable indexes.
- `0003_rls.sql` — RLS default-deny on all 13 tables; owner policies via `auth.uid()`; **two-hop**
  `art_assets`; catalog read-only public; `god_snapshots` shareable rule; explicit GRANTs.
- `seed.sql` — generated from the in-repo catalog (ADR-006): **406 species, 6 gear, 12 skills, 9 factions**.

### D3 — pgTAP RLS proof
- `supabase/tests/rls_test.sql`: **54 assertions**, allow+deny (read & write) for every player-owned
  table, catalog read-only (authenticated + anon), and the `god_snapshots` shareable rule.
- Verified the suite has **teeth**: weakening `runs_owner` to `using(true)` turns the "A cannot read B"
  deny-test red.

### D4 — Constants pipeline
- `tools/balance_constants.json` — faithful transcription of **every** balance constant in the engines.
- `tools/gen_constants.mjs` — emits `client/domain/constants.gd` + `oracle/constants.py` (floats stay
  floats, ints stay ints).
- `tools/test_constants_parity.py` — **113 checks** (structural `eq` + `ast`-numeric + derived-fragment;
  every expected value is derived from the JSON, so JSON-side drift turns it red) proving JSON ≡ engines.
  Engines are **not** rewired to import the JSON yet (that's Phase 1).
- Catalog pipeline: `tools/gen_catalog.mjs` (→ `client/catalog/*.json`) + `tools/gen_seed.mjs` (→ `seed.sql`).

### D5 — Anonymous auth wiring
- `config.toml`: `enable_anonymous_sign_ins = true`, `enable_manual_linking = true` (ADR-011).
- `supabase/tests/smoke_anon_isolation.mjs` proves: anon sign-in → own player+run rows; **B cannot read
  or modify A's run** under RLS; catalog readable. Uses the **anon key only**.
- Client interface stub `client/infrastructure/supabase/auth.gd` + `supabase_config.example.gd`
  (anon-key-only; secret policy documented). Secret scan passes.

### D6 — CI
- `.github/workflows/ci.yml`: **lint** (gdformat/gdlint, sqlfluff, eslint) → **constants** (generator
  run + drift gate + parity) → **database** (`db reset` + `test db` + anon smoke) → **secret-scan**
  (`tools/secret_scan.sh` + gitleaks informational). Runs on every PR; fail-on-red. Pinned Python 3.12,
  Node 22, Supabase CLI 2.108.0.
- Every CI command was run locally and is green; the secret scanner was proven to fail on a planted
  OpenAI key.

---

## How to run it locally

**Prereqs:** Docker Desktop running · Node 18+ · Python 3.12 · `npx supabase` (CLI 2.x).

```bash
# 1. Constants generators + parity (D4)
npm ci
npm run gen:all                                  # constants.gd/.py + catalog/*.json + seed.sql
PYTHONUTF8=1 python -B tools/test_constants_parity.py     # -> 113/113 OK  (PYTHONUTF8=1 only needed on Windows)

# 2. Database: migrations + seed + RLS (D2/D3)
npx supabase start
npx supabase db reset                            # applies 0001+0002+0003 + seed, clean
npx supabase test db                             # -> 54/54 pgTAP PASS

# 3. Anonymous isolation smoke (D5)
npm --prefix supabase/tests ci
export SUPABASE_URL=$(npx supabase status -o env | grep '^API_URL=' | cut -d'"' -f2)
export SUPABASE_ANON_KEY=$(npx supabase status -o env | grep '^ANON_KEY=' | cut -d'"' -f2)
node supabase/tests/smoke_anon_isolation.mjs     # -> PASS

# 4. Lint + secret scan (D6 — same commands CI runs)
pip install "gdtoolkit==4.*" "sqlfluff==4.*"
gdformat --check $(git ls-files 'client/**/*.gd' | grep -v addons | grep -v constants.gd)
gdlint        $(git ls-files 'client/**/*.gd' | grep -v addons | grep -v constants.gd)
sqlfluff lint supabase/migrations --dialect postgres
npm run lint:js
bash tools/secret_scan.sh
```

To **prove the gates bite**: `alter policy runs_owner on runs using (true);` then `supabase test db`
(goes red) → `supabase db reset` to restore; or drop a `sk-…` key into a tracked file and run
`tools/secret_scan.sh` (fails).

---

## Deviations & judgment calls (none change game behavior)

1. **Lean baseline / "history preserved" / "LFS active"** — the repo had a **single prior commit**, so
   there is no deeper history to preserve; the reorg used `git mv` (renames recorded) and rebuilt **one**
   lean baseline with raw art **excluded from base history** (your decision). LFS is **configured-and-ready**
   (hooks + `.gitattributes` patterns) but **tracks zero binaries by design** — the patterns activate the
   moment art is added. Matches your committed `.gitignore`/README plan. (ADR-010)
2. **`players.id → auth.users` and `art_assets.unique(instance_id)` live in `0002`** (the kickoff D2
   grouping), whereas TDD §5.3/§5.6 phrase them as "the initial migration." The full chain
   (`0001`+`0002`+`0003`) runs on a **fresh empty DB** via `db reset`, so the end state is identical and
   the "initial migration on an empty DB, not a backfill" intent holds. (ADR-008/011, ADR-007)
3. **`runs.corruption` is floor-only, NOT capped at 130 (ADR-014).** TDD §5.3 / kickoff D2 say
   "corruption ≤ 130", but that cap belongs to the per-combatant **battle-live** meter (status_engine,
   not persisted per TDD §4.2). `runs.corruption` is the cumulative **player track**, fed unclamped
   (lab_engine +18/taboo fuse, +35/self-splice) and can legitimately exceed 130 — a literal cap would
   reject valid save/sync writes in Phase 3. So `check (corruption >= 0)` only. (Found by the Phase-0
   review; `balance_constants.json` still carries the faithful battle constant `status.corruption_cap = 130`.)
4. **CHECK value sets are provisional:** `runs.status ∈ (active, ascended, fallen, abandoned)` and
   `rivals.relationship ∈ (rival, ally, nemesis, defeated)` (the latter from the schema comment). The
   TDD mandates "enums or CHECK" but doesn't enumerate; extend via a future migration if the design adds states.
5. **`analytics` disabled in `config.toml`** — the logflare analytics + vector log-shipper hang
   `supabase start` health checks on Windows (need Docker exposed on tcp://localhost:2375). Not needed
   for Phase-0 verification; Linux CI is unaffected.
6. **Secret scan = custom deterministic gate only.** `tools/secret_scan.sh` is the reliable,
   locally-verifiable gate (catches OpenAI/Anthropic/AWS keys, private keys, and service-role JWTs by
   decoding the payload). The `gitleaks-action` was **removed** after the Phase-0 review noted it needs a
   `GITLEAKS_LICENSE` for org repos and was `continue-on-error` (zero real coverage while looking active).
7. **Toolchain:** Python 3.12 was installed (only a Store stub existed); pinned 3.12 for engines/parity/CI.
   `PYTHONUTF8=1` is needed on Windows for the unicode in engine sample output (not for the tests themselves).

## Notes / not-blockers
- **Godot 4.7 is installed** (winget) and confirmed to open the client scaffold headless — all three
  GDScript classes (`Constants`, `SupabaseAuthPath`, `SupabaseConfigExample`) register with no parse
  errors, validating the generated `constants.gd`. Not a Phase-0 gate; used heavily in Phase 0.5.
- **No cloud Supabase project** — all Phase-0 DB verification ran against the local stack. Provisioning
  `dev`/`staging`/`prod` + wiring CI deploy secrets is a deployment-time step, not a Phase-0 gate.
- Two Phase-0.5 reference docs you added (`docs/Mutants_Game_Resources.md`,
  `docs/Claude_Code_Phase05_Resources.md`) are intentionally **not** in the Phase-0 commit; they belong to Phase 0.5.

## §6.5 reconciliation register (Phase-1 work — recorded, not done here)
Per the kickoff, these are **Phase 1**, recorded for the report: (a) `skill_engine` global-RNG bug;
(b) entropy-step unify (skill `0.08` → canonical `0.12`) — `balance_constants.json` records both the
canonical value and skill's current value so the parity test stays faithful today; (c) the stale
`StatSpine.md` validation table (engine `HPBASE{T1:120}` is canonical — confirmed: Worldback T3 → HP 963).

---

## Adversarial review (self-audit)
A multi-agent review (5 dimensions × independent verification) audited RLS, migrations, parity, CI,
and DoD coverage: **16 findings raised, 13 verified real, all addressed.** The two high-severity ones
were genuinely valuable and are fixed:
- **`runs.corruption ≤ 130` capped the wrong meter** → floor-only (ADR-014).
- **50/93 parity checks couldn't detect JSON-side drift** (hardcoded source fragments) → rewritten to
  derive every expected value from the JSON via `ast` numeric extraction; now **113 checks**, and
  editing a JSON constant (e.g. `damage_k → 9.99`) correctly turns the test **red** (verified).
Other fixes: cross-user **write-deny** + own-row **insert** assertions added for every owned table
(pgTAP now **54** assertions, including the previously-missing `world_state` write-deny); the
misleading gitleaks step removed; `oracle/tests/.gitkeep` added; history/LFS wording corrected.

## STOP
Phase 0 is complete and green. Proceeding to **Phase 0.5** (resource integration) per your second
kickoff; **Phase 1 (determinism core) is not started.**
