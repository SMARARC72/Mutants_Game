# CLAUDE CODE — Mutants_Game · Phase 0 Kickoff (Execution Prompt #1)

> Paste this as the first instruction to **Claude Code**, run inside the `Mutants_Game` repo (it has access to all project files). This is **Phase 0 of the engineering runway in the TDD** — foundations & guardrails only. Build it to the Definition of Done, then **stop and report**. Do not start the engine port (Phase 1/2) or any screens (Phase 5).

---

## 0. Who you are / how to operate
You are the founding engineer standing up the production codebase for **Mutants_Game** (a funny-grim occult creature-collection RPG; desktop; Godot 4.7 · Supabase · Vercel · GitHub). The design and architecture are **complete and validated** — your job is to build the foundation exactly as specified, not to redesign.

**Canon & authority (read before writing code, in this order):**
1. **`Mutants_Game_TechnicalDesign.md` — NORMATIVE.** This is the contract. Where it says MUST, it's a gate. Follow it. If you must deviate, write an ADR in `/docs/adr/` explaining why and flag it in your report — never silently diverge.
2. **`Mutants_Game_INDEX.md`** — the map of every doc and engine.
3. **`schema.sql`** — the base DB schema you will migrate from.
4. The **Python engines** (`stat_engine.py`, `level_engine.py`, `lab_engine.py`, `battle_engine.py`, `skill_engine.py`, `status_engine.py`, `loot_engine.py`, `character_engine.py`, `wire_line.py`) — these are the **canonical oracle** for all game behavior. **In Phase 0 you do NOT modify their logic** (relocation + faithful constant extraction only).
5. `Mutants_Game_TechStack.md`, `Mutants_Game_MVP_Slice.md`, `Claude_Design_Handoff_Brief.md` (+ Claude design's delivered output) — context for later phases; **Phase 0 does not consume the design output**, but make a home for it.

**Working style:** small PRs, green CI before merge, conventional commits, ADRs for any decision not already settled in the TDD. Don't gold-plate. Don't touch game-balance numbers. Ask only if something is genuinely undefined by the TDD.

---

## 1. Mission (Phase 0 scope — bounded)
Stand up the repository, the database foundation with security, the constants pipeline, anonymous auth, and CI — so that a team can build on it without drift. **Six deliverables**, each with acceptance criteria. Nothing in this phase ports gameplay or builds UI.

### D1 — Monorepo scaffold + relocate existing files
Create the structure from TDD §12.1 and reorganize the currently-flat project into it (use `git mv`, preserve history):
```
/client      # Godot 4.7 project (scaffold only this phase: project.godot, folder skeleton from TDD §3.2, .gitignore)
/oracle      # the Python engines (move all *_engine.py + wire_line.py here, UNCHANGED) + a tests/ dir
/services    # Vercel/Next app (scaffold only: package.json, /api placeholder, README)
/supabase    # migrations/, seed.sql, tests/ (pgTAP), config
/docs        # move ALL Mutants_Game_*.md design docs here; /docs/adr/ for ADRs
/design      # Claude design's output (style guide, mockups, prototype) — create the dir even if not yet delivered
/tools       # the constants generator, the (later) golden-vector generator
```
- Initialize git if needed; add **Git LFS** with a `.gitattributes` covering art/audio/binaries (`*.png *.jpg *.webp *.wav *.ogg *.mp3` etc.).
- Root `README.md`: what the project is, the repo map, how to run each part locally.
- **Acceptance:** clean tree, history preserved, LFS tracking the binaries, everything imports/builds where applicable.

### D2 — Database: migrations (initial + hardening + RLS)
Using the **Supabase CLI** (timestamped migrations in `/supabase/migrations/` — no manual/ad-hoc DDL):
- `0001_init.sql` — the base schema refactored from `schema.sql` (13 tables).
- `0002_hardening.sql` — per TDD §5.3: `players.id` → `references auth.users(id)` (drop the `gen_random_uuid()` default; **empty-DB migration, not a backfill**); `created_at/updated_at` (+ an `updated_at` trigger) on mutable tables; `runs.save_version int not null default 1` + `schema_version`; convert free-text status/relationship/force columns to enums or CHECKs; on-delete policies (player-owned children `cascade` from `runs`; `god_snapshots.source_run/source_player` → `set null`); non-negative CHECKs on currencies/meters and `corruption ≤ 130`; the `art_assets` additions (`status text default 'pending'`, **`unique (instance_id)`**); the indexes from TDD §5.3 (replace the full `creature_instances(run_id)` index with the partial `where is_dead = false`; add `inventory(run_id,item_type)`, `god_snapshots(shareable) where shareable`).
- `0003_rls.sql` — **RLS enabled on every table, default-deny.** Owner policies via `auth.uid()`; **`art_assets` uses the TWO-hop join through `creature_instances → runs`** (it has no `run_id`); catalog tables (`species, gear, skills, factions`) read-only public, writable only by service role; `god_snapshots` readable when `shareable or source_player = auth.uid()`, writable only by owner. (Copy the policy shapes from TDD §5.4 and complete them for all tables.)
- `seed.sql` — generated from the in-repo catalog (species/gear/skills/factions) so the DB mirror and the future client bundle share one source (TDD §5.2, ADR-006). If catalog isn't yet in a structured file, derive it from the existing registry/docs and note the source.
- **Acceptance:** `supabase db reset` applies all migrations cleanly on a fresh DB.

### D3 — RLS proof (pgTAP)
In `/supabase/tests/`, a pgTAP suite proving, for **every** player-owned table, the **allow** path (owner can read/write own rows) AND the **deny** path (a different authenticated user cannot), plus catalog read-only and the `god_snapshots` shareable rule. (TDD §11.4 — "RLS without tests is not done.")
- **Acceptance:** `supabase test db` is green; deliberately breaking a policy turns a deny-test red.

### D4 — Constants pipeline (`balance_constants.json` + generator)
- Create `/tools/balance_constants.json` by **faithfully transcribing** every balance constant currently in the engines (BST ladder, HPBASE, φ=0.50, genome 0.65–1.35, universals bases, class mods, damage `K=1.5`, force mults 1.5/0.7, single-hit cap 0.55, `ENTROPY_STEP_PER_TURN=0.12`, status bases/caps incl. corruption cap 130, gear/capture/breed constants, morality thresholds & the 3×3 god grid). The engine is the source of truth — transcribe, don't invent.
- Write a generator (`/tools/gen_constants.*`) that emits `client/domain/constants.gd` and `oracle/constants.py` from the JSON.
- Write a **parity test** asserting the JSON values equal the constants the engines actually use today (so the extraction is provably faithful). **Do NOT yet rewire the engines to import the JSON** — that's Phase 1 (it changes engine internals and must land under the golden-vector harness).
- **Note for the report (don't fix now):** the TDD §6.5 reconciliation register (skill_engine global-RNG bug; entropy-step unify to 0.12; the stale `StatSpine.md` validation table — engine `HPBASE{T1:120}` is canonical, do not change it) is **Phase 1** work, except the harmless doc-refresh of the StatSpine table which you may do if convenient.
- **Acceptance:** generator runs in CI; the JSON↔engine parity test is green.

### D5 — Anonymous auth wiring (ADR-011)
- Configure the dev Supabase project for **anonymous sign-ins** + **manual identity linking** (ADR-011). Provide a thin `infrastructure/supabase/` auth path in the client scaffold (or a small script if the client isn't wired yet) that performs an anonymous sign-in and creates the `players` + initial `runs` rows.
- A smoke test: an anonymous user gets a `players` row and, under RLS, **cannot** see another anon user's run.
- **Acceptance:** the anon-sign-in → isolated-row test is green; **only the Supabase anon key** appears in any client config (no service-role/OpenAI keys anywhere near the client — secret-scan must pass).

### D6 — CI skeleton (GitHub Actions)
A PR pipeline (TDD §12.2, the Phase-0 subset): lint (gdformat/gdlint where applicable, eslint, sqlfluff) → the **pgTAP RLS job** against an ephemeral Supabase → the **constants parity test** → **secret scan** → fail-on-red. Wire it to run on every PR.
- **Acceptance:** CI runs green on the Phase-0 PR; introducing a secret or breaking an RLS test makes it red.

---

## 2. Guardrails (non-negotiable)
- **Secrets never in the client.** Client ships the Supabase **anon key** only. OpenAI/service-role keys live only in Vercel/Supabase server env. CI secret-scans.
- **RLS default-deny on every table**; the `art_assets` policy is two-hop (no `run_id` on that table).
- **Don't change game behavior.** Engines are relocated and their constants transcribed; their logic is untouched in Phase 0.
- **Edit `.py` via shell only** (`cat`/`sed`/heredoc) and run with `python3 -B` — the file-editing tools mangle multi-line Python string concatenations in these engines (a recorded incident). Markdown/JSON/SQL/GDScript are safe to edit normally.
- **Determinism discipline starts now:** introduce no wall-clock/global-RNG dependence anywhere that will feed the sim; honor the ADR-001/002 intent so Phase 1 can drop in cleanly.
- **Version pins:** Godot **4.7**, `supabase-community/godot-engine.supabase` **4.x**, **GdUnit4** (or GUT 9.x) for GDScript tests, **pgTAP** for DB tests, current **Supabase CLI**. Pin them in config/CI.
- **Scope discipline:** Phase 0 only. No engine port, no gameplay, no screens.

---

## 3. Definition of Done (the gate — all must be true)
1. Repo reorganized into the monorepo layout, history preserved, LFS active. 
2. `supabase db reset` applies `0001`+`0002`+`0003`+seed on a clean DB with no errors.
3. **pgTAP RLS suite green** — allow + deny proven for every player-owned table; catalog read-only; god_snapshots rule enforced.
4. An **anonymous player row is creatable and RLS-isolated** (smoke test green).
5. `balance_constants.json` exists and its **parity test vs the engines is green**; the generator emits `constants.gd` + `constants.py`.
6. **CI runs green on the PR** and goes red on a planted secret or a broken RLS test.
7. A **`PHASE0_REPORT.md`** at repo root: what was built, exact local-run instructions (db reset, run tests, run CI locally), every deviation (each with an ADR link), and any blockers.
8. **STOP.** Do not begin Phase 1. Hand back the report.

---

## 4. What comes next (context only — NOT this prompt)
**Phase 1 — Determinism core:** implement the canonical RNG (PCG32, ADR-001) + canonical half-to-even rounding (ADR-002) in both GDScript and Python; refactor the oracle onto them and land the §6.5 fixes (skill RNG, entropy step, StatSpine doc); build the golden-vector generator. **Phase 2** ports the eight engines against those vectors. You'll get a dedicated prompt for each. For now: build Phase 0 to the DoD and report.
