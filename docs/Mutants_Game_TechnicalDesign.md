# MUTANTS_GAME — Technical Design Document (TDD)

**Version:** 1.2 · **Status:** Reviewed (red-teamed) — ready for engineering; auth + save-format decided · **Date:** 2026-06-27
**Owner:** Engineering Lead (orchestrated) · **Audience:** the build team (senior engineers)
**Supersedes:** nothing · **Companion docs:** `Mutants_Game_TechStack.md` (stack rationale), `Mutants_Game_MVP_Slice.md` (scope), `Mutants_Game_DataModel.md` (data narrative), `Mutants_Game_Design_Bible.md` (master design), `Claude_Design_Handoff_Brief.md` (UX).

> **Reading contract.** This document is the bridge from a fully-designed, Python-validated game to a shippable Godot/Supabase product. It is normative: where it says **MUST**, that is a gate. It assumes the reader has the design docs but not the design conversations. Numeric game constants are **not** re-derived here — the Python reference engines are the single source of truth for those (see §6, §0.4). This doc governs *how the system is built*, not *what the numbers are*.

---

## 0. Document control

### 0.1 Purpose
Define the production architecture, contracts, standards, and execution plan to build Mutants_Game on the locked stack (Godot 4.7 · Supabase · Vercel · GitHub) with **no shortcuts**: deterministic simulation, cross-language parity with the Python oracle, enterprise data integrity, security-by-default, and a test/CI regime strong enough that a team of senior devs can execute in parallel without drift.

### 0.2 Scope
In scope: client architecture (Godot), the domain/simulation port, data architecture (Supabase Postgres + Storage + Realtime), the services layer (Vercel), integration flows, security, save/sync, determinism, testing, CI/CD, observability, performance, coding standards, the phased runway, and the risk register. The **MVP slice** (`Mutants_Game_MVP_Slice.md`) is the first delivery target; this TDD covers the full architecture but flags MVP-vs-later at each layer.

### 0.3 Out of scope
Game-balance numbers (owned by the engines + `Mutants_Game_Balance.md`), creature content (the parallel codex), UX visual design (owned by `Claude_Design_Handoff_Brief.md`), and live-ops/marketing.

### 0.4 Definitions & glossary
- **Oracle / reference engine** — the validated Python modules (`*_engine.py`). They define canonical behavior; the GDScript port MUST reproduce them within the parity tolerance (§6.4, §11).
- **Parity** — byte/semantically-identical outputs between the Python oracle and the GDScript port for the same `(seed, inputs)`.
- **Run** — one playthrough (the `runs` row + everything FK'd to it). The unit of save.
- **Instance** — an owned, one-of-one creature (`creature_instances` row).
- **Catalog / static data** — design-time data that does not change per player: species, gear, skills, factions. Versioned with the build. *(Species = 407 art-backed today; the full codex targets ~1,067 — size the `species` seed and any UI lists for that growth, not 407.)*
- **Aggregate** — the `run` and all child rows that are saved/loaded/synced as one consistency boundary.
- **Force** — one of the six primordials (Gaia, Ouranos, Cosmos, Chaos, Eros, Thanatos). The shared language of stats, skills, statuses.
- **Entropy** — per-creature instability meter. **Corruption** — per-player meter. Both are the "shared cost."
- **Succession** — endgame snapshot (`god_snapshots`) shared as async invasion bosses.
- **DAL** — Data Access Layer (the repository abstraction over Supabase in the client).
- **Canonical RNG** — the single pseudo-random generator implemented identically in Python and GDScript (§6.3, ADR-001).

### 0.5 Change log
| Ver | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-06-27 | Eng Lead | Initial TDD from ground-truth recon of schema + 9 Python modules (8 engines + wire_line) + design docs; stack version-pinned. |
| 1.1 | 2026-06-27 | Eng Lead | Red-team pass folded in: corrected the HPBASE finding (engine is canonical; the StatSpine table is stale), fixed `art_assets` to a two-hop RLS policy, hardened the determinism contract (total ordering + tiebreakers + tie-case vectors), ratified `ENTROPY_STEP_PER_TURN=0.12` in-doc, closed the gen double-spend race (reserve-before-generate), `save_version` as sole conflict key, Godot-4 grep target, and ~6 further consistency fixes. |
| 1.2 | 2026-06-27 | Eng Lead | Resolved the two Phase-0 open questions as ADR-011 (auth = anonymous-first → optional email-link; uid preserved on upgrade, web-verified) and ADR-012 (save = versioned JSON, data-only, no Godot `Resource` deserialization). |

---

## 1. Architecture principles (the rules every decision answers to)

1. **The Python engines are law.** All gameplay math lives in the engines. The client ports them; it does not reinvent or "improve" them ad hoc. Divergence is a bug, caught by parity tests. *(Rationale: one source of truth, instant regression oracle, server-side re-validation later.)*
2. **Determinism is a feature, not an accident.** Given `(seed, ordered inputs)` the entire simulation is reproducible on any platform and in any language. This unlocks save-as-seed+log, replay, anti-cheat re-validation, and reproducible bug reports. Everything random goes through the **canonical RNG** (§6.3).
3. **Secrets never touch the client.** The OpenAI key, service-role keys, and any privileged credential live only in Vercel/Supabase server contexts. The desktop binary ships with the Supabase **anon** key only (safe by design under RLS).
4. **Security is default-deny.** RLS on every player-owned table; a player can read/write only their own rows. Catalog tables are read-only public. No endpoint trusts client input without validation.
5. **Offline-first, cloud-durable.** A session is fully playable without network; the local save is authoritative during play; the cloud is the durable, cross-device, shareable copy reconciled on sync. No feature blocks on a round-trip except explicitly online ones (gen, Succession, leaderboards).
6. **Layered, testable, no god-objects.** Gameplay (deterministic, pure) is isolated from I/O (DAL, network), which is isolated from presentation (UI). Each layer is unit-testable in isolation.
7. **Everything that ships is versioned and migratable.** Save schema, DB schema, catalog data, and the wire protocol all carry versions and forward-only migrations. We never strand a save.
8. **No band-aids.** Known issues are fixed at the root and recorded (§6.5 reconciliation register). We do not ship "temporary" hacks without an ADR and a tracked removal task.

---

## 2. System architecture

### 2.1 Context (C4 level 1)
```
                         ┌─────────────────────────────┐
                         │           Player            │
                         └──────────────┬──────────────┘
                                        │ plays (desktop)
                         ┌──────────────▼──────────────┐
                         │   Mutants_Game (Godot 4.7)   │  standalone desktop exe (Win/macOS/Linux)
                         │   deterministic sim + UI     │
                         └───┬───────────────┬──────────┘
            REST/Realtime/   │               │  HTTPS (JWT)
            Auth/Storage     │               │
                 ┌───────────▼──────┐   ┌────▼─────────────────────┐
                 │     Supabase     │   │   Vercel services layer   │
                 │ Postgres+Auth+   │   │  gen-proxy · succession   │
                 │ Storage+Realtime │   │  validate · companion web │
                 └───────┬──────────┘   └────┬─────────────────────┘
                         │ service-role            │ server-side keys
                         └─────────►  OpenAI Images ◄┘ (key never in client)
```

### 2.2 Containers (C4 level 2)
| Container | Tech | Responsibility | Trust |
|---|---|---|---|
| **Game client** | Godot 4.7, GDScript (typed) | Deterministic simulation (ported engines), UI, local save, DAL to Supabase, calls to Vercel for privileged ops | Untrusted (runs on player machine) |
| **Postgres** | Supabase Postgres (pin the exact provisioned major across all 3 projects — Supabase currently provisions PG 17 for new projects) | Durable state, RLS-enforced ownership, catalog mirror, Succession store | Trusted store; enforces ownership |
| **Auth** | Supabase Auth (GoTrue) | Player identity, JWT issuance | Trusted |
| **Storage** | Supabase Storage | Generated art binaries (CDN-backed) | Trusted; signed/public-read per bucket policy |
| **Realtime** | Supabase Realtime | Leaderboard/Succession feeds (later) | Trusted |
| **Services** | Vercel serverless (Node/TS) | OpenAI gen proxy, Succession publish/fetch, deterministic re-validation, companion web | **Trusted compute**; holds privileged keys |
| **CI/CD** | GitHub + Actions + Git LFS | Build/test/parity/exports/migrations/deploy | Trusted pipeline |

### 2.3 Deployment topology
- **Client:** GitHub Actions exports signed desktop builds (Windows `.exe`, macOS `.app` notarized, Linux binary) → distributed via itch.io/Steam/direct. Not hosted on Vercel.
- **Backend:** three Supabase projects — `dev`, `staging`, `prod` — schema-identical, migrated from the same SQL migration chain.
- **Services:** Vercel project with `preview` (per-PR) and `production` deployments; environment-scoped secrets.
- **Data residency:** single primary region to start (lowest latency to the player base); documented for later multi-region if the friend network globalizes.

### 2.4 Why this shape (anti-patterns rejected)
- **No game logic on Vercel for normal play.** Single-player sim is client-side; Vercel is for secrets + sharing + (later) validation. Avoids latency and cost on the hot path.
- **No direct client→OpenAI.** Key exposure + cost abuse. Always proxied.
- **No ORM magic in gameplay.** The DAL is explicit and thin; gameplay never holds a DB handle.

---

## 3. Client architecture (Godot 4.7)

### 3.1 Layered architecture
The client is four layers, dependencies pointing downward only:

```
  Presentation  (Scenes, Control nodes, view-models)         ── no game math, no SQL
        │
  Application   (use-cases / services: BattleController,     ── orchestration, no I/O details
                 LabController, SaveService, SyncService)
        │
  Domain        (ported engines: Stat/Level/Lab/Battle/      ── PURE, deterministic, no I/O,
                 Skill/Status/Loot/Character + Creature model)   no Godot node deps
        │
  Infrastructure(DAL/repositories, Supabase addon wrapper,   ── all I/O, network, disk
                 Vercel client, RNG service, Clock)
```

**Hard rule:** the **Domain** layer has zero dependencies on Godot nodes, the Supabase addon, the filesystem, or wall-clock time. It is plain typed GDScript operating on data + an injected RNG. This is what makes it unit-testable and parity-testable headless. *(Enforced by code review + a CI grep gate that fails if `domain/` references `Node`, `SceneTree`, the Supabase addon, or any wall-clock/global-RNG API: `Time.`, `randf`, `randi`, `randomize`, `Engine.get_process_frames`. Note: Godot 4 has no `OS.get_unix_time` — the time API is `Time.*`, which is exactly what must be forbidden here.)*

### 3.2 Project structure
```
res://
  domain/            # pure ported engines + models (NO node/I-O deps)
    rng.gd           # canonical PRNG (ADR-001)
    math.gd          # canonical rounding/ops (ADR-002)
    creature.gd      # the shared Creature aggregate (§6.2)
    stat_engine.gd  level_engine.gd  lab_engine.gd  battle_engine.gd
    skill_engine.gd status_engine.gd loot_engine.gd character_engine.gd
    constants.gd     # ALL balance constants, single source (§6.5)
  application/       # controllers / use-cases (orchestrate domain + infra)
    battle_controller.gd  lab_controller.gd  capture_service.gd
    save_service.gd       sync_service.gd     art_service.gd
  infrastructure/
    dal/             # repositories: run_repo, instance_repo, world_repo ...
    supabase/        # thin wrapper over the addon (auth, db, storage)
    services_api/    # typed client for the Vercel endpoints
    clock.gd  device_id.gd  logger.gd
  presentation/
    screens/         # one folder per screen (Title, Overworld, Battle, Lab, Dossier ...)
    components/       # reusable Control widgets (force icon, stat scry, sigil)
    theme/           # the design-system theme resource (from Claude design)
  catalog/           # bundled static data (species.json, gear.json, skills.json, factions.json) + version
  autoload/          # singletons (Game, Settings, EventBus, ServiceLocator)
  tests/             # GdUnit4 suites mirroring domain/ + application/ + golden vectors
```

### 3.3 Autoloads (singletons) — minimal and explicit
- `Game` — top-level state machine (Boot → Menu → InRun → Battle → Lab …) and the current `RunContext`.
- `ServiceLocator` — constructs and hands out infrastructure services (DAL, SupabaseClient, ServicesApi, RNG factory). Enables dependency injection + test doubles.
- `EventBus` — typed signals for cross-screen events (decoupling presentation). Never carries game math.
- `Settings` — user prefs (audio, accessibility, keybinds), persisted locally.

No other globals. Gameplay state lives in the `RunContext` aggregate owned by `Game`, not in scattered singletons.

### 3.4 State management
- One authoritative in-memory **`RunContext`** (the loaded aggregate: run + instances + world + inventory + standings + rivals). All mutations go through Application-layer services, which (a) apply the domain operation and (b) enqueue persistence.
- Presentation reads from `RunContext` via view-models and reacts to `EventBus` signals. Presentation never mutates domain state directly.
- **Command pattern** for player actions that change state (CaptureCommand, FuseCommand, AwakenCommand, …): each is serializable, which feeds the deterministic event log (§6.6) and the undo-free audit trail.

### 3.5 UI architecture (Control nodes)
- **MVVM-lite:** each screen has a `*_screen.tscn` (View, Control nodes) + a `*_view_model.gd` (formats domain state for display, translates input into Application commands). View-models depend on Application, never on Infrastructure.
- The **theme** is a single Godot `Theme` resource produced from the Claude design handoff; components consume theme variables (no hard-coded colors). Colorblind-safe: every force is color **+** icon/shape (per the brief).
- Battle/Lab "deep engine, simple surface" (per UX brief) is achieved by view-models exposing *only* the decision-relevant projections; the full math stays in Domain.

### 3.6 Threading & performance model
- The simulation is fast (turn-based, small teams) and runs on the main thread within a frame budget. **Exception:** any operation that could exceed ~8 ms (bulk save serialization, catalog load, image decode) runs on a Godot `WorkerThreadPool` task or is chunked, never blocking the render thread.
- Network calls (Supabase/Vercel) are **always** async (signals/awaits); the UI shows optimistic state + a pending indicator and reconciles on completion.
- Frame budget target 16.6 ms (60 FPS) on the min-spec desktop (§16). Sim step must be <1 ms typical.

### 3.7 Error handling
- Domain functions are **total**: they validate inputs and return typed results; they never `assert`-crash on player-reachable input. Programmer errors (contract violations) use `assert` in debug builds.
- Infrastructure wraps every external call in a `Result`/`Error` type (no silent failure); the Application layer decides retry/surface. User-facing errors are funny-grim per the UX voice but actionable.
- A global handler logs uncaught errors to the local log + (opt-in) crash reporting (§15).

---

## 4. Domain / simulation layer — the heart of the system

### 4.1 What we are porting
Eight gameplay engines plus `wire_line.py` (the integration proof — 9 Python modules total). Art-ingest tooling stays in Python, outside the port surface. Recon established exact signatures, constants, and RNG use; the port reproduces them. Complexity tiers from recon:
- **Low** (pure, minimal RNG): `stat_engine`, `status_engine`, `character_engine`, `loot_engine`.
- **Medium** (internal state + RNG sequencing): `level_engine`, `lab_engine`.
- **Medium-high** (live mutation + RNG + needs the §6.5 fixes): `battle_engine`, `skill_engine`.

### 4.2 The Creature aggregate (canonical in-memory model)
Recon synthesized the implicit shared model. We make it explicit as `domain/creature.gd` — the single struct every engine reads/writes (fields grouped by origin):
- **Identity:** `species_id, name, prim, sec, rank, tier, cls`.
- **Ceiling (from stat_engine):** `ceiling{8 stats}, hp_ceiling, bst_ceiling, genome{8 floats 0.65–1.35}`.
- **Growth (level_engine):** `expression(0.30–1.0), genes[], gene_bonus{}, entropy, awakenings, burnouts`.
- **Derived (computed):** `stats{8}, hp, maxhp`.
- **Combat-live:** `alive, current_hp, shield, buff, defdown`.
- **Affliction (status_engine):** `status{name→{stacks,dur}}` (persisted to `creature_instances.status_effects`). The `corruption(0–130)`/`feral` fields are **battle-live only** (per-combatant, like `current_hp`) and are **not** persisted per-instance — the persisted per-creature instability meter is `entropy`; player-level corruption lives on `runs.corruption`.
- **Skills:** `kit[], ranks{skill→int}`.
- **Persistence:** `sigil_seed, lineage{}, bond`.

This maps 1:1 to the `creature_instances` table (§5.3); the DAL (de)serializes between them. Live-only fields (`current_hp, shield, buff, defdown, alive`) are battle-scoped and not persisted.

### 4.3 Engine contracts (ported signatures)
The port preserves these public contracts (from recon; full constant tables live in `domain/constants.gd`). They are shown in their **post-ADR-001 form**, where the oracle's trailing `seed:int` is refactored to an injected `rng` in *both* languages:
- **stat_engine:** `stat_block(prim, sec, rank, tier, cls, genome) -> {stats, hp, bst}`; `roll_genome(rng) -> {8 floats}`. Pure given `genome`; `roll_genome` is the only RNG user.
- **level_engine:** `awaken(rng, expression, gene_bonus, genes) -> {expression, events[]}`; `current_stats(ceiling, expression, gene_bonus) -> {stats}`. RNG: surge `uniform(0.10,0.22)`, gene `<0.35`, branch `<0.20`.
- **lab_engine:** `fuse(a, b, method, rng) -> {name,prim,sec,tier,stats,hp,bst,taboo,entropy,corruption,method}`; `blend(parts) -> (prim,sec)`. RNG: `randint(12,24)` entropy roll.
- **battle_engine:** `force_mult(att,dfn) -> float`; `Mon`; `attack(att,dfn,ent,chain,overload,rng,log)`; `simulate(teamA,teamB,rng) -> log[]`. Damage `K·off²/(off+def)·fm·ent·chain·crit`, `K=1.5`, single-hit cap `0.55·maxhp`, entropy `+12%/turn`.
- **skill_engine:** `SKILLS` table, `Mon`, `damage(...)`, `support(...)`, `act(...)`, `battle(A,B,rng) -> log[]`. **Note: §6.5 fixes required** (global-RNG bug, entropy-step divergence).
- **status_engine:** `apply(c,name,log)`, `add_corruption(c,amt,src,log)`, `tick(c,allies,log)`, `cleanse(c,log)`. Deterministic (no RNG). Corruption cap 130, feral ≥100.
- **loot_engine:** `capture_chance(method,tier,hp_frac,bond,gear,morality_fit) -> float (0.02–0.95)`; `breed_roll(gear, rng) -> (rare,chance,iv_ceiling)`. RNG only in `breed_roll`.
- **character_engine:** `rank_for(deeds)`, `band3(v,labels)`, the `GODS` 3×3 grid, `EVENTS`, `NOTO`. Deterministic.

### 4.4 The port is signature-faithful but idiomatic
We keep function names, return shapes, and constant values **identical** to the oracle (parity depends on it), with these deliberate, parity-preserving changes applied to **both** the refactored oracle and the port simultaneously: (a) the trailing `seed:int` parameter becomes an injected `rng` (ADR-001) — no engine constructs its own RNG, so the §4.3 `(…, rng)` signatures are the canonical post-refactor form; (b) Python `round()` → canonical `math.rnd()` (§6.4); (c) `Mon`/state become explicit typed objects; (d) the §6.5 known issues are fixed in oracle and port together, so the oracle stays valid as the test source of truth.

---

## 5. Data architecture (Supabase Postgres)

### 5.1 Source schema & posture
`schema.sql` defines 13 tables (species, players, runs, creature_instances, art_assets, gear, skills, inventory, factions, faction_standing, world_state, rivals, god_snapshots). It is sound in shape (JSONB for evolving fields, FKs for relationships, seed on `runs` for determinism) but ships **without** three production necessities we add here: **RLS policies, auth wiring, and a migrations framework**. These are MUST-haves before any networked build.

### 5.2 Migrations (no ad-hoc DDL, ever)
- **Tooling:** Supabase CLI migrations (timestamped SQL files in `supabase/migrations/`), applied to dev→staging→prod via CI. `schema.sql` is refactored into the initial migration `0001_init.sql`; every subsequent change is a new forward-only migration. No manual SQL in any environment.
- **Seed:** catalog data (species, gear, skills, factions) loaded via `supabase/seed.sql` generated from the in-repo catalog files (§6 ADR-006) so the DB mirror and the client bundle come from one source.
- **Typed access:** generate TypeScript types (for Vercel) and a GDScript schema constants file from the live schema in CI, so drift between code and DB fails the build.

### 5.3 Ownership, keys, integrity (hardening over the base schema)
Applied as migrations on top of `schema.sql`:
- **`players.id`** becomes the Supabase Auth user id: `players.id uuid references auth.users(id)`. Identity is never client-asserted. This is established in the **initial migration on an empty database** — the base schema's `gen_random_uuid()` default is dropped (Auth supplies the id) — **never as a backfill on populated data** (it is a PK that everything FKs to). Players start **anonymous** (`signInAnonymously` → a real `auth.users` row), so `players.id` exists from first launch; linking a permanent email later (ADR-011) **preserves the uid**, so no row is ever reparented.
- **Add audit/versioning columns** to every mutable table: `created_at timestamptz default now()`, `updated_at timestamptz` (trigger-maintained), and on the aggregate root `runs`: `save_version int not null default 1`, `schema_version int`, `updated_at`.
- **Foreign keys get `on delete` policy** (currently unspecified): player-owned children `on delete cascade` from `runs`; `god_snapshots` deliberately **`on delete set null`** for `source_run`/`source_player` so the Succession mythology survives run deletion (matches design intent: snapshots outlive saves).
- **Tighten CHECKs/enums:** convert free-text status/relationship/force fields to enums or `CHECK` constraints (e.g., `runs.status`, `rivals.relationship`, force columns ∈ the six). Prevents invalid state at the store.
- **Indexes:** the base schema already indexes `creature_instances(run_id)`; **replace** it with the partial `creature_instances(run_id) where is_dead = false` (covers the hot party query without duplicating), and add `inventory(run_id, item_type)`, `faction_standing(run_id)`, `god_snapshots(shareable) where shareable`, and a GIN index on heavily-queried JSONB (`world_state.region_states`) only if query patterns require it (measure first).
- **Numeric integrity:** money/meters (`drachma, essence, ichor, corruption, entropy, bond`) get `CHECK (>= 0)` and, where bounded, upper `CHECK`s (corruption ≤ 130 mirrors the engine).

### 5.4 Row-Level Security (default-deny, every table)
RLS is **enabled on all tables**; policies below are the contract (illustrative SQL, finalized in the security migration):
```sql
alter table runs enable row level security;
create policy run_owner on runs
  using (player_id = auth.uid())
  with check (player_id = auth.uid());

-- run-child tables authorize via their parent run's owner (single hop on run_id)
alter table creature_instances enable row level security;
create policy ci_owner on creature_instances
  using (exists (select 1 from runs r where r.id = run_id and r.player_id = auth.uid()))
  with check (exists (select 1 from runs r where r.id = run_id and r.player_id = auth.uid()));
-- (same single-hop run_id pattern for inventory, world_state, faction_standing, rivals)

-- art_assets has NO run_id (it FKs only instance_id) -> authorize via a TWO-hop join.
-- (Alternative: denormalize run_id onto art_assets for a single-hop policy + cheaper check.)
alter table art_assets enable row level security;
create policy art_owner on art_assets
  using (exists (select 1 from creature_instances ci join runs r on r.id = ci.run_id
                 where ci.id = instance_id and r.player_id = auth.uid()))
  with check (exists (select 1 from creature_instances ci join runs r on r.id = ci.run_id
                 where ci.id = instance_id and r.player_id = auth.uid()));

-- catalog tables: read-only to everyone, writable only by service role
alter table species enable row level security;
create policy species_read on species for select using (true);
-- no insert/update/delete policy => only service_role (which bypasses RLS) can seed

-- Succession: read shareable snapshots (for invasions), write only your own
alter table god_snapshots enable row level security;
create policy gs_read on god_snapshots for select using (shareable or source_player = auth.uid());
create policy gs_write on god_snapshots for insert with check (source_player = auth.uid());
```
**Test obligation:** every policy has a pgTAP test proving both the allowed and the denied path (§11.4). RLS without tests is not done.

### 5.5 Static vs runtime data
- **Static (catalog):** `species, gear, skills, factions` — design data, identical for all players, versioned with the build, seeded into Postgres for server-side validation/analytics. Client reads the **bundled** copy (offline, fast).
- **Runtime (per-player):** everything FK'd to `players`/`runs`. The cloud copy is the durable record; the client holds a working mirror (§7).

### 5.6 Storage (generated art)
- Bucket `creature-art` (public-read, service-write): generated images, path `art/{player_id}/{instance_id}/{sigil_seed}.png`. Public-read is acceptable (non-sensitive game art) and CDN-cached; write only via the Vercel gen proxy using service role.
- `art_assets` row is the system of record (URL + prompt + seed + model + a `status` column added in migration: `pending`/`ready`/`failed`). **Generate-once-persist-forever** is enforced by a **`unique (instance_id)` constraint added in the initial migration** (it is absent from the base `schema.sql`) **plus the reserve-before-generate protocol in §7.3** — together they make a retry *or a concurrent request* never double-generate, which also prevents OpenAI double-spend (ADR-007).

### 5.7 Realtime (later)
Leaderboards and "a friend's god invaded your world" notifications use Supabase Realtime channels keyed by player. Not in MVP; the schema (`god_snapshots`) already supports the data. Channels are authorized by RLS-equivalent checks.

---

## 6. Determinism & the parity oracle (the make-or-break section)

### 6.1 Why this is non-negotiable
Three high-value capabilities depend on the simulation being bit-reproducible across Python and GDScript: (1) the Python engines remain a *live regression oracle* for the client; (2) saves can be stored compactly as `seed + event log` and replayed; (3) Vercel can **re-validate** a submitted outcome server-side for anti-cheat (Succession/leaderboards) by re-running the same deterministic sim. Lose determinism and all three collapse. Therefore determinism is engineered, not hoped for.

### 6.2 The shared state object
Defined in §4.2 (`Creature` aggregate) + a `RunContext` for player/world state. Both are plain data; engines are pure functions over them + an RNG. No engine reads wall-clock or global state. Every collection whose iteration affects results is **explicitly total-ordered** (see §6.4): the 8 stats, teams, the gene pool, force-blend sorts, and initiative all use a fixed key plus a deterministic tiebreaker — because Python's tie-resolution (dict insertion-order, stable `sorted`, first-wins `min`/`max`) does **not** match GDScript by default and would silently diverge.

### 6.3 ADR-001 — Canonical RNG (replace `random.Random` in both languages)
**Decision:** implement **one** PRNG — **PCG32** (or documented SplitMix64-seeded xoshiro256\*\*) — identically in `domain/rng.gd` (GDScript) and a new `canonical_rng.py` used by the refactored oracle. All engines take an injected RNG instance; no engine calls a language-stdlib RNG.
**Why not port Python's Mersenne Twister?** MT is heavier and, more importantly, `random.random()`/`uniform`/`randint` use specific 53-bit float construction and rejection schemes that are error-prone to replicate exactly in GDScript. A small, fully-specified generator we control on both sides is the no-shortcut answer.
**Spec (frozen):** the RNG exposes `next_u32()`, `next_float()` (documented `u32 / 2^32` construction), `uniform(a,b)`, `randint(a,b)` (documented inclusive, rejection-free modulo-bias-corrected), `choice(seq)`. Each engine call site documents which it uses (recon already enumerated them). Seeding is explicit (`RNG.new(seed)`); sub-streams use documented seed derivation (e.g., `splitmix64(parent_seed ^ purpose_const)`).
**Consequence:** the Python oracle is refactored to use `canonical_rng.py` so it stays the source of truth *and* matches the client. This is done once, under parity tests, via shell-edit of the `.py` files (per the standing tooling constraint that file-tools mangle the engines).

### 6.4 ADR-002 — Canonical arithmetic & rounding
**Problem (recon):** Python `round()` is banker's rounding (half-to-even); GDScript `round()` is half-away-from-zero. Damage/stat/HP all call `round()`. Unreconciled, the port diverges on exact ties.
**Decision:** implement `math.rnd(x)` (half-to-even) in both languages and use it **everywhere** the engines currently use `round()`. Keep balance math integer-first; define operation order explicitly in code (no relying on language evaluation nuances). Floats are only intermediate; all persisted/compared results are integers or fixed-precision (genome stored to 3 decimals as the oracle does).
**Tolerance:** parity tests assert **exact** integer equality for stats/HP/damage; for the few floats surfaced (expression, entropy multiplier) assert equality at the documented precision (2–3 dp).

**ADR-002 (cont.) — Total ordering (parity-critical).** Python's `sorted` is stable, `min`/`max`/`choice`-over-a-list return the *first* tie, and dict iteration is insertion-order. GDScript guarantees **none** of these. Therefore the domain layer MUST: (a) use a **total** comparator with an explicit tiebreaker on every sort — e.g. initiative `(-Celerity, species_index)`, force-blend `(-weight, pole_index)`; (b) implement every `min`/`max`/argmin as explicit **first-wins**; (c) iterate any dict that feeds an RNG draw or an output (e.g. the `GENES` pool in `level_engine.awaken`, the `POLES` order in `lab_engine.blend`) through a fixed `*_ORDER` constant list, never native key order. The golden generator (§11.2) MUST include deliberate tie cases (equal Celerity, equal blend weights, equal HP-fraction) so these paths are parity-tested, not discovered in production.

**Integer bounds.** All balance intermediates fit comfortably in int64 (worst case ≈ `1.5·1400² ≈ 2.9M` in the damage formula). No engine relies on Python arbitrary-precision integers, so GDScript `int` (int64) is safe; this is asserted, not assumed.

### 6.5 Reconciliation register (root-cause fixes, no band-aids)
Recon surfaced three real defects in the oracle. They are fixed in the oracle **and** the port, under parity tests, before the port is declared done:
1. **`skill_engine` mixes RNG sources.** It seeds `random.Random(seed)` *and* `random.seed(seed)`, then `act()` calls global `random.random()` for the Rouse check instead of the instance. **Fix:** thread the injected canonical RNG through `act()`; delete all global-random use. *(Owner: domain port; tracked.)*
2. **Entropy-step divergence (three values in the wild).** `battle_engine` uses `+0.12/turn`, `skill_engine` uses `+0.08/turn`, and `Battle.md` is itself self-contradictory (`+10%/turn` in one line, `+12%/turn` in another). **Decision — ratified here, not deferred to a self-contradictory doc:** `ENTROPY_STEP_PER_TURN = 0.12`. Update `skill_engine` to match and correct `Battle.md`'s stale `+10%` prose. The value lives once in `balance_constants.json`. *(Owner: domain.)*
3. **Stale StatSpine validation table (NOT a constant conflict).** Earlier drafting mis-read this. The engine's `HPBASE = {T1:120,…}` is **correct and internally consistent**: a T1 pup with Vitality 17 → HP `120 + 3·17 = 171`; Worldback → 963, matching `Battle.md` and the Codex. The `210`/`2176` figures in `Mutants_Game_StatSpine.md` are **stale HP *output* cells** from before the v0.2.1 balance pass, not HPBASE constants. **Fix:** the **engine is the oracle** — regenerate the StatSpine validation table from `stat_engine.py`; do **not** touch `HPBASE`. (This is a doc refresh, not a code change.) The constant-consolidation below still applies, to prevent *future* drift. *(Owner: design-doc refresh.)*

All constants consolidate into `domain/constants.gd` and `constants.py` generated from **one** canonical source (a `balance_constants.json` checked into the repo), eliminating drift class-wide.

### 6.6 Save-as-replay (enabled by determinism)
Because the sim is deterministic, the durable record of a run can be `(seed, ordered command log)`; full state is a fold of commands over the seed. We persist **both** the materialized aggregate (for fast load + queries) **and** the command log (for audit/replay/validation). The log is the basis for server-side re-validation (§8.4) and reproducible bug reports (attach seed+log).

---

## 7. Services layer (Vercel serverless)

### 7.1 Role & boundaries
Vercel hosts **privileged compute**, never the game and never normal CRUD (that's the client↔Supabase path). Three production functions + a companion web app:
1. **`/api/art/generate`** — OpenAI image-gen proxy (the only holder of the OpenAI key).
2. **`/api/succession/publish`** + **`/api/succession/fetch`** — share/import god-snapshots.
3. **`/api/validate/outcome`** — deterministic re-validation for competitive submissions (later, but specified now).
Plus the companion web (account portal, Succession browser, marketing) as a standard Next.js app.

### 7.2 Auth & trust
Every endpoint requires a valid Supabase **JWT** (the player's access token) in `Authorization: Bearer`. The function verifies the JWT against the Supabase JWKS, extracts `sub` (= player id), and authorizes the action. Functions use the **service-role key** only for the specific writes they own (e.g., inserting `art_assets`), scoped server-side — the service-role key is a Vercel env secret, never returned to the client.

### 7.3 `/api/art/generate` — the gen pipeline (ADR-007)
**Contract:**
```
POST /api/art/generate
Authorization: Bearer <supabase_jwt>
Body: { instance_id: uuid, genome_hash: string, sigil_seed: int, prompt_spec: {…} }
→ 200 { status:"ready", image_url, art_asset_id }      // already existed OR generated now
→ 202 { status:"pending", job_id }                      // long gen, poll/realtime
→ 4xx { error, code }                                   // moderation, quota, bad input
```
**Pipeline (idempotent, generate-once):**
1. Verify JWT → player id. Verify the player owns `instance_id` (query `creature_instances`→`runs.player_id`).
2. **Idempotency & reservation (race-safe):** `insert into art_assets (instance_id, status) values (…, 'pending') on conflict (instance_id) do nothing returning id`. If **no** row is returned, one already exists → return its stored URL (or report `pending` if still generating). **Only the request that wins the insert proceeds to generate.** A plain check-then-generate would let two concurrent requests both call OpenAI (double-spend); reserving the row first closes that race.
3. **Cost/abuse guardrails:** per-player rate limit (token bucket in Postgres/Upstash) + a monthly generation cap; reject with `429` past budget. All gen is server-metered.
4. **Moderation:** run the prompt (and, if used, the output) through OpenAI moderation; reject disallowed content. The mature-occult theme is in-bounds, but gore/sexual/minor-safety filters are enforced — logged.
5. **Generate:** call OpenAI Images with the deterministic prompt (`genome → prompt`, `sigil_seed`); on success, stream the image to Supabase Storage at the canonical path.
6. **Persist:** `update art_assets set image_url=…, prompt=…, seed=…, model=…, status='ready' where instance_id=…` (the row was reserved in step 2; on generation failure set `status='failed'` so it can be retried/reclaimed).
7. Return the URL. Failures are typed and retryable; a failed gen never leaves a half-written `art_assets` row (transactional insert after successful upload).

### 7.4 `/api/succession/*` — the friend mythology
- **publish:** validates the caller owns the `source_run`, snapshots the ascended pantheon into `god_snapshots` (`shareable=true` per player choice). Returns a shareable id/code.
- **fetch:** returns shareable snapshots (by code, or a curated/random pool for "invasions"), honoring `shareable` and RLS. Imported snapshots become a boss in the importer's world (client-side).
- No live netcode — fully async, store-and-forward. This matches the design (async invasion bosses).

### 7.5 `/api/validate/outcome` — server-authority (deferred, specified)
For competitive/Succession-affecting results, the client submits `(seed, command_log, claimed_result_hash)`. The function re-runs the **same deterministic engines** — specifically the **existing Python oracle executed server-side**, never a third re-implementation (a Node port would triple the parity surface to Python+GDScript+TS) — from the seed+log and compares the result hash. Match → accept; mismatch → reject + flag. This is *only possible because of §6*. MVP is single-player and trust-the-client; this endpoint lights up when leaderboards/competitions ship. Designing it now keeps the sim honest (we never add nondeterminism that would break it).

### 7.6 API conventions
- Versioned routes (`/api/v1/...`), typed request/response (zod-validated at the boundary), consistent error envelope `{error:{code,message,details}}`, structured logging with a request id, idempotency keys on all mutating endpoints, and per-endpoint rate limits. OpenAPI spec generated and checked into the repo.

---

## 8. Integration & data flows (the sequences that matter)

### 8.1 Auth & first load
```
Client → Supabase Auth: anonymous sign-in on first launch (restore session thereafter; optional email-link later — ADR-011) → JWT
Client → DAL → Supabase: select run where player_id = uid (RLS scopes it)
   ├─ run exists → hydrate RunContext (run + instances + world + inventory + standings + rivals)
   └─ none → create run (seed = secure-random) → seed starting state
Client: load bundled catalog (species/gear/skills/factions) — offline, instant
Client → Game state machine: enter overworld
```

### 8.2 Battle round (fully client-side, deterministic)
```
Overworld encounter → BattleController.begin(teamA, teamB, battle_seed = derive(run.seed, encounter_id))
loop turns (≤cap):
   order by Celerity (deterministic)
   for each actor: ViewModel surfaces decision → player/AI chooses command
       BattleController → battle_engine/skill_engine + status_engine.tick (injected canonical RNG)
       EventBus emits juice events (hit, crit, resonance, death) → Presentation
resolve: deaths → parts/Graveyard (instances flagged is_dead) → rewards
BattleController → SaveService.persist(delta)   // async write-through
```
No network in the hot loop. The `battle_seed` derivation makes the fight reproducible.

### 8.3 Lab splice + art-gen (client sim + server gen)
```
LabController.preview(a, b, method)        // pure domain: cost ledger + result preview, no commit
player confirms (the "seal the rite" commit)
LabController.fuse(a, b, method, rng=derive(run.seed, op_id))   // domain → new instance, entropy/corruption applied
SaveService.persist(new instance, costs)   // Supabase write (RLS)
ArtService.request(new_instance)           // → Vercel /api/art/generate
   ├─ 200 ready → set sprite
   └─ 202 pending → show authored-fallback art; swap on completion (Realtime/poll)
```
Art is **never** blocking: the creature exists and is playable with fallback art immediately; the unique one-of-one image fills in.

### 8.4 Succession publish/import
```
Ascension reached → CharacterController computes grid-god → SuccessionService.publish(run)
   → Vercel /api/succession/publish → god_snapshots row (shareable)
Friend's client → /api/succession/fetch(code) → snapshot → instantiates an invasion boss in their world
(Optional later) outcome of beating it → /api/validate/outcome
```

### 8.5 Offline → online reconciliation
See §10. Briefly: writes made offline are queued and replayed on reconnect; the client is authority for its own single-player run; server reconciles by `updated_at`/`save_version`.

---

## 9. Security architecture

### 9.1 Threat model (STRIDE, scoped to a single-player-with-async-sharing game)
| Threat | Vector | Mitigation |
|---|---|---|
| **Spoofing** | Forged identity / another player's data | Supabase Auth JWT; `players.id = auth.users.id`; RLS `auth.uid()` on every row. |
| **Tampering** | Edited save / forged outcomes | Client-authoritative for *own* single-player run (acceptable; no shared economy in MVP). For competitive/Succession: deterministic server re-validation (§7.5). DB CHECKs bound impossible values. |
| **Repudiation** | "I didn't do that" | `created_at/updated_at`, audit columns, command log; server logs with request ids. |
| **Information disclosure** | Key leakage, cross-player reads | Secrets only server-side; anon key + RLS in client; cross-player reads blocked by RLS (tested via pgTAP). |
| **Denial of service / cost abuse** | Gen-spam draining OpenAI budget | Per-player rate limits + monthly caps + server metering on `/api/art/generate`; Vercel/Supabase platform limits. |
| **Elevation of privilege** | Client calling privileged ops | Service-role key never in client; privileged writes only inside Vercel functions after JWT authz. |

### 9.2 Secrets management
- **Client ships:** Supabase URL + **anon** key only (public by design, safe under RLS).
- **Vercel holds:** OpenAI key, Supabase **service-role** key, JWT signing secrets — as environment secrets, per environment (dev/preview/prod), never logged.
- **No secret in Git.** `.env` files git-ignored; CI uses encrypted secrets. A secret-scanning gate runs in CI.

### 9.3 Input validation & content safety
- Every Vercel endpoint zod-validates input at the boundary; every DB write is RLS- and CHECK-guarded.
- AI-generated art passes OpenAI moderation; the mature theme is allowed but child-safety/sexual/gore policies are enforced server-side and logged. A takedown path (nullify `art_assets.image_url`, regenerate) exists.

### 9.4 PII & data lifecycle
- **PII is minimal:** anonymous players hold **no PII at all** until they choose to link an email (ADR-011); after linking, only email/identity sits in Supabase Auth. Gameplay tables hold no sensitive personal data. Document this in a short privacy note.
- **Deletion:** "delete my account" cascades player-owned rows (FK `on delete cascade` from `players`/`runs`), nullifies `god_snapshots.source_player` (keeps the depersonalized boss in others' worlds, matching design — disclosed to users), and purges Storage art. GDPR/CCPA-aligned even though the audience is friends.
- **Backups:** Supabase automated backups (point-in-time on the paid tier); migrations + seed are in Git, so the schema is reproducible; user-content (art) is in Storage with versioning.

### 9.5 Anti-cheat posture (honest)
MVP single-player: editing your own save harms no one — we do not waste effort fighting it. The moment results affect *others* (leaderboards, Succession competition), the deterministic re-validation in §7.5 is the authority. We never design a feature that makes the sim nondeterministic, because that would forfeit this defense.

---

## 10. Save system, persistence & sync

### 10.1 Model (ADR-005)
The unit of save is the **run aggregate**. Two representations, one source of truth:
- **Cloud (authoritative, durable):** the normalized Postgres rows (already the schema). This is the system of record.
- **Local (working mirror + offline buffer):** a serialized snapshot of the loaded `RunContext` written as **versioned JSON** to `user://saves/{run_id}.json` (ADR-012 — data-only via `JSON.parse_string`; **never** a Godot `Resource`/`store_var(full_objects)`, which can instantiate arbitrary scripts on load — material because we import friend-shared Succession data), plus an **offline write queue** of pending commands.

We deliberately reject full event-sourcing as the primary store (too heavy for a single-player game) but **keep the deterministic command log** (§6.6) alongside the snapshot for audit/replay/validation — best of both.

### 10.2 Versioning & migration (never strand a save)
- Local save header: `{save_version, schema_version, app_version, run_id, written_at, checksum}` (JSON, ADR-012).
- A **forward-only migration chain** (`migrate_v1_to_v2`, …) runs on load when `save_version` < current; each migration is unit-tested with real old-format fixtures. Loading a future-version save (downgrade) is refused with a clear message.
- DB `schema_version` on `runs` lets the server detect and (if needed) lazily migrate JSONB blobs.

### 10.3 Sync & conflict resolution
- **Write path:** Application services apply a command → mutate `RunContext` → persist locally (immediate) → enqueue a cloud write (async, write-through). UI is optimistic.
- **Reconnect:** flush the offline queue in order; each write carries the run's `save_version`. The server accepts monotonic versions.
- **Conflict (rare in single-player, real across devices):** `save_version` — a per-run monotonic counter the server increments on accept — is the **sole** conflict key. `updated_at` is informational only (wall-clock is unreliable across devices and must not arbitrate). The server rejects a write whose base `save_version` is stale; the client rebases onto the server aggregate and a conflict snapshot is stored (we never silently destroy data). Ties are impossible because the server serializes the increment.
- **Integrity:** writes are transactional per aggregate delta; a partial network failure leaves the local save authoritative and the queue intact. Corruption detection via a checksum in the save header; a corrupt local save falls back to the last cloud snapshot.

### 10.4 What is saved (from recon)
Instances (genome, expression, entropy, genes/gene_bonus, skills, status, lineage, sigil_seed, is_dead, bond), run state (rank, both morality axes, notoriety, deeds, corruption, currencies, gear, god_form, seed), world (faction_standing, rivals, region_states, force_tide), art (prompt/seed/url), and Succession (god_snapshots). Live battle-only fields are never persisted.

---

## 11. Testing strategy (the quality gate)

### 11.1 The pyramid + the oracle
- **Parity tests (the keystone):** golden vectors generated from the Python oracle assert the GDScript port matches exactly. This is the highest-value suite and a hard CI gate.
- **Unit:** every domain engine + every migration + view-model formatting (GdUnit4, headless).
- **Integration:** Application controllers against in-memory fakes of the DAL; DB/RLS against a real ephemeral Supabase (pgTAP).
- **End-to-end:** scripted core-loop run (overworld→battle→catch→lab→save/load) in a headless Godot harness.
- **Performance/soak:** frame-budget and long-session memory tests (§14).

### 11.2 Parity harness (Python ↔ GDScript)
- **Generator (`tools/gen_golden.py`):** for each engine, enumerate representative `(seed, inputs)` across the input space (forces, ranks/tiers, classes, methods, edge HP fractions, opposed/same matchups, taboo fusions, burnout paths) and emit `tests/golden/<engine>.jsonl` of `{inputs, seed, expected_output}`.
- **Asserter (GdUnit4):** loads the same vectors, runs the GDScript engine with the canonical RNG seeded identically, asserts equality (exact ints; documented-precision floats). Any mismatch fails CI with a diff.
- **Coverage target:** ≥ 1000 vectors/engine for the stochastic ones (level, battle, skill, lab, and loot's `breed_roll`), exhaustive for the deterministic ones (status, character, and loot's `capture_chance` — which has no RNG). Vectors MUST include the determinism tie-cases from §6.4 (equal Celerity, equal blend weights, equal HP-fraction). The oracle and port are refactored **together** under this harness (§6.5 fixes land here first).

### 11.3 Determinism tests
- Same seed → identical full battle/lab/level transcripts across N runs and across OS targets (Win/macOS/Linux export sanity). Replay test: fold the command log over the seed → equals the materialized aggregate.

### 11.4 Database & RLS tests (pgTAP)
- Every RLS policy: prove the owner can, and a different user cannot, read/write each table (the explicit allow + deny pair). Constraint tests for CHECKs/enums and cascade behavior. Run against an ephemeral DB in CI via `supabase db reset` + `supabase test db`.

### 11.5 Services tests
- Vercel functions: unit (zod validation, authz, idempotency) + contract tests against the OpenAPI spec + a mocked OpenAI; the **generate-once** invariant is explicitly tested (second call returns the same asset, no second generation).

### 11.6 Gates & coverage
- CI is **red** if: any parity vector fails, any RLS deny-path passes, domain coverage < 90%, lint fails, types drift from the DB, or a secret is detected. No merge on red. Coverage is a floor, parity is the ceiling of truth.

## 12. CI/CD & environments

### 12.1 Repository
- **Monorepo** (GitHub): `/client` (Godot), `/oracle` (Python engines + golden generator), `/services` (Vercel/Next), `/supabase` (migrations + seed + pgTAP), `/docs` (design + this TDD). **Git LFS** for art/audio binaries (the registry images are large and growing — already a known constraint).
- Trunk-based with short-lived feature branches; PRs require green CI + one review. Conventional Commits; semantic versioning for the client; ADRs in `/docs/adr`.

### 12.2 Pipelines (GitHub Actions)
- **PR check (every push):** lint (gdformat/gdlint, eslint, sqlfluff) → typecheck → **oracle tests** → **golden vector regen check** (oracle output stable) → **GDScript unit + parity** (headless Godot + GdUnit4) → **pgTAP RLS** (ephemeral Supabase) → services unit/contract → secret scan → coverage gate.
- **Main merge:** the above + build **desktop exports** (Win/macOS/Linux) as artifacts + deploy `services` to Vercel preview + apply migrations to `staging`.
- **Release tag:** sign/notarize exports, publish to distribution, deploy services to `production`, apply migrations to `prod` (gated, with a dry-run + backup), generate release notes.
- **Determinism matrix:** parity + replay tests run on all three OS runners to catch platform float/RNG drift early.

### 12.3 Environments
| Env | Supabase | Vercel | Purpose |
|---|---|---|---|
| dev | `dev` project | local/preview | day-to-day |
| staging | `staging` project | preview | pre-release verification, migration rehearsal |
| prod | `prod` project | production | players |
Config via environment variables; no env-specific code branches. Migrations always flow dev→staging→prod, never hand-applied.

### 12.4 Release & rollback
- **Feature flags** (a small config table + bundled defaults) gate unfinished systems (full Lab, competitions, Succession) so `main` is always shippable — matching the MVP-first plan.
- **Rollback:** client = re-publish previous signed build; services = Vercel instant rollback; DB = forward-fix migration (never destructive down-migrations in prod) + PITR backup as the last resort. Every migration is rehearsed on staging with a prod-shaped dataset.

---

## 13. Observability
- **Client:** structured local logs (rotating), opt-in crash/error reporting (e.g., Sentry-style) with the seed + save header attached for reproducibility; a "report bug" action bundles seed+command-log.
- **Services:** structured JSON logs with request ids; metrics on gen latency/cost/error-rate, Succession publish/fetch, validation mismatches (a spike = cheating or a determinism regression — alert).
- **Database:** Supabase logs + slow-query insight; constraint-violation rate alerts. (RLS-denied-spike alerting is a *post-launch* refinement — at friend-scale a deny is more likely a client bug than an attacker, so it ranks below the gen-cost and validation-mismatch alarms.)
- **Dashboards & alerts:** gen cost vs budget, error budgets per service, parity-failure alarms in CI. Define SLOs once there are real users; pre-launch the alarms that matter are **gen cost** and **validation mismatch**.

---

## 14. Performance, scalability & cost
- **Client budget:** 60 FPS (16.6 ms/frame) on min-spec (define: ~2015 dual-core + integrated GPU); sim step < 1 ms; battle resolve < 1 frame; scene loads chunked; memory ceiling documented and soak-tested for multi-hour sessions (no leaks in the `RunContext`/EventBus).
- **DB:** per-query budgets; the four+ indexes (§5.3) cover the hot reads (party by run, standings, snapshots). JSONB used for flexible fields but hot filters are real columns or GIN-indexed only where measured.
- **Services:** stateless functions scale horizontally on Vercel; mind cold starts on the gen path (keep the function warm/lightweight; the OpenAI call dominates latency anyway). 
- **Cost model (watch items):** OpenAI image generation is the primary variable cost → metered, capped, generate-once (§7.3). Supabase Storage egress for art is CDN-cached. Everything else is within free/low tiers at friend-scale. A simple cost dashboard tracks gen spend.
- **Scale path:** friend-scale today; the architecture (stateless services, RLS-partitioned data, async sharing) scales to thousands without redesign. Multi-region and read-replicas are documented future levers, not built now.

---

## 15. Coding standards & ADR index

### 15.1 Standards (enforced in CI)
- **GDScript:** statically typed everywhere (`func f(x:int)->int`), `class_name` for domain types, gdformat/gdlint clean, no `Node` deps in `domain/`, no magic numbers (constants module). Naming: `PascalCase` types, `snake_case` members, `SCREAMING_SNAKE` consts.
- **Python (oracle):** edited **via shell only** (file-tools mangle multi-line string concatenations — a recorded incident); `python3 -B` to avoid stale `.pyc`; type hints; the oracle imports constants from the shared `balance_constants.json`.
- **SQL:** migrations only, reviewed, sqlfluff-clean, every policy paired with a pgTAP test.
- **TypeScript (services):** strict mode, zod at boundaries, no `any`, OpenAPI kept in sync.
- **Reviews:** every PR reviewed; security-touching PRs (RLS, secrets, endpoints) require a second reviewer.

### 15.2 ADR index (decisions recorded in `/docs/adr`)
- **ADR-001** Canonical RNG replaces stdlib RNG in both languages (§6.3).
- **ADR-002** Canonical half-to-even rounding + integer-first math (§6.4).
- **ADR-003** Client-authoritative sim now; deterministic server re-validation for competitive later (§7.5, §9.5).
- **ADR-004** Repository/DAL over the Supabase addon; no addon calls in gameplay (§3, §5).
- **ADR-005** Versioned snapshot saves + retained command log; forward-only migrations (§10).
- **ADR-006** Catalog data single-sourced in-repo, seeded to Postgres, bundled to client (§5.5).
- **ADR-007** Gen proxy: idempotent generate-once, moderated, cost-capped (§7.3).
- **ADR-008** RLS default-deny on every table; catalog read-only public (§5.4).
- **ADR-009** Python engines are the oracle; golden-vector parity gates CI (§11.2).
- **ADR-010** Monorepo + trunk-based + feature-flagged MVP-first delivery (§12).
- **ADR-011** Auth: anonymous-first sign-in → optional identity-link to email OTP/magic-link; the uid is preserved across the upgrade, so all FK'd data carries over with no reparenting (§5.3, §8.1, §9.4). Requires enabling anonymous sign-ins + manual identity linking on the Supabase project.
- **ADR-012** Local save = versioned JSON (data-only); the client never deserializes a Godot `Resource`/`store_var(full_objects)` from save or shared data (arbitrary code-execution surface) (§10).

---

## 16. Engineering runway (phased, parallelizable, with Definition of Done)

Foundations first, then the vertical slice. Workstreams that can run in parallel are marked ∥. Each phase has an explicit DoD; nothing is "done" until its tests are green.

**Phase 0 — Foundations & guardrails.** Repo + LFS + monorepo layout; three Supabase projects; refactor `schema.sql` → `0001_init.sql`; **RLS + auth wiring + pgTAP** for every table; CI skeleton (lint/test gates); `balance_constants.json` + generated `constants.gd`/`constants.py`. **DoD:** RLS allow/deny tests green; CI runs on PR; a player row is creatable and isolated.

**Phase 1 — Determinism core (the keystone).** ∥ (a) canonical RNG + canonical rounding in both languages; (b) refactor the Python oracle onto them and land the §6.5 fixes (skill RNG, entropy step, HPBASE drift); (c) golden-vector generator. **DoD:** oracle re-validated; golden vectors emitted; reconciliation register closed.

**Phase 2 — Domain port.** Port the 8 engines to typed GDScript against the golden vectors (low-complexity first: stat/status/character/loot → level/lab → battle/skill). **DoD:** parity suite green for all engines on all three OS runners; `Creature` aggregate finalized.

**Phase 3 — Persistence & DAL.** ∥ Repositories over the addon; `RunContext` hydrate/persist; local save + versioning/migration; offline queue + sync (§10). **DoD:** create→play→save→reload→cloud-sync round-trips; save-migration fixtures pass; conflict path covered.

**Phase 4 — Services.** ∥ Vercel gen proxy (idempotent/moderated/capped) + Storage wiring + `art_assets`; Succession publish/fetch stub; JWT verify. **DoD:** generate-once proven by test; art persists; no key in client.

**Phase 5 — Vertical slice / MVP (the Verdant fringe).** Wire the loop: overworld tile movement + encounters → battle (port) → capture (loot) → basic Lab (fuse/mutate) → leveling (awaken/overclock) → 1 gear slot → the Bloomwarden boss; ~25 creatures seeded; the MVP screens from the design handoff. **DoD:** the `Mutants_Game_MVP_Slice.md` success criteria met (loop is moreish, no one-shots, fights 5–8 turns, readable systems); E2E core-loop test green.

**Phase 6 — Playtest & tune.** Sweep `Mutants_Game_Balance.md` dials against telemetry; lock. **DoD:** balance targets hit in instrumented play.

*Sub-agent ownership maps cleanly:* a determinism/engine owner (P1–P2), a data/backend owner (P0, P3, P4 services-DB), a client/gameplay owner (P3 DAL, P5 loop), a UX-integration owner (P5 screens from the design handoff). Parity + RLS gates keep them from drifting.

---

## 17. Risk register
| # | Risk | Impact | Likelihood | Mitigation | Owner |
|---|---|---|---|---|---|
| R1 | **Cross-language determinism drift** (RNG/float/rounding) | High | Med | Canonical RNG + rounding (ADR-001/002); parity gate on 3 OSes; integer-first math | Determinism |
| R2 | **Supabase Godot addon gaps/maturity** (Realtime/edge cases) | Med | Med | Thin DAL wrapper isolates it; fall back to direct REST (PostgREST) if a feature lags; pin addon `4.x` version | Backend |
| R3 | **OpenAI gen cost/latency/moderation** | High (cost) | Med | Generate-once + caps + metering; async with authored fallback; moderation gate | Services |
| R4 | **Desktop export signing/notarization** (macOS Gatekeeper, Win SmartScreen) | Med | High | Budget time in CI for signing/notarization; document per-OS; test installers early | DevOps |
| R5 | **Save migration breakage** strands player runs | High | Low | Versioned saves + tested migration chain + fixtures; never destructive down-migrations | Client |
| R6 | **Scope creep from the deep design** (9 systems) | Med | High | Feature-flagged MVP-first; the slice gate; out-of-scope list is law for v1 | Lead |
| R7 | **Engine/doc constant drift** (e.g., HPBASE) | Med | Med (already present) | Single `balance_constants.json`; reconciliation register §6.5; constants generated, never hand-copied | Domain |
| R8 | **Secret leakage** in client/Git | High | Low | Anon-key-only client; Vercel secrets; CI secret scan; no service-role anywhere near the binary | Security |
| R9 | **Unity-asset license contamination** | Med | Low | Engine-neutral/CC0 + OpenAI art only; per-asset license check; no Unity prefabs/scripts/shaders | Lead |

---

## 18. Open questions (decide before/at the phase they gate)
1. ~~**Identity:** …~~ **DECIDED — ADR-011:** anonymous-first sign-in → optional link to email OTP/magic-link. Web-verified that Supabase anon→permanent conversion **preserves the uid**, so all FK'd data carries over with no reparenting. *(Resolved 2026-06-27.)*
2. **RNG choice:** PCG32 vs xoshiro256\*\* — pick one and freeze (ADR-001). *(Recommendation: PCG32 — small, well-documented, easy to match.)*
3. ~~**Local save format:** …~~ **DECIDED — ADR-012:** versioned JSON (data-only). Language-neutral (mirrors the Postgres aggregate; oracle-readable), diffable for deterministic bug reports, trivially migratable, and avoids the **code-execution surface** of Godot `Resource`/`store_var(full_objects)` deserialization — material because we import friend-shared Succession data. *(Resolved 2026-06-27.)*
4. **Distribution:** Steam vs itch.io vs direct — affects signing/DRM/build matrix (R4). 
5. **Catalog of record:** keep the CSV registry or promote to JSON as the single catalog source (ADR-006). *(Recommendation: JSON in-repo, generated to seed + bundle.)*
6. **Telemetry scope/consent** for the playtest sprint (Phase 6) — what we measure, opt-in copy.

---

## Appendix A — Canonical data contracts
- **Creature aggregate:** §4.2 (maps to `creature_instances`). 
- **RunContext:** `runs` row + child collections (instances, inventory, faction_standing, rivals, world_state). 
- **Golden-vector record:** `{ "engine": str, "inputs": {…}, "seed": int, "expected": {…} }` (one JSON object per line, `tests/golden/<engine>.jsonl`).
- **balance_constants.json:** the single source for all engine constants (BST ladder, HPBASE, φ, genome range, K, force mults, single-hit cap, entropy step, status bases/caps, gear/capture/breed constants, morality thresholds). Generated into `constants.gd` and `constants.py` in CI.

## Appendix B — Engine → table → screen traceability
| Engine | Reads/writes | Persists to | Surfaced in (screen) |
|---|---|---|---|
| stat_engine | genome, ceiling, stats | `creature_instances.genome/stats_cached` | Dossier |
| level_engine | expression/genes/entropy | `creature_instances` | Dossier / awaken FX |
| lab_engine | fuse/mutate + costs | `creature_instances`, `runs.corruption`, `inventory` | The Lab |
| battle_engine | live combat | (live only) → results to instances | Battle |
| skill_engine | skills/combos | `skills`, `creature_instances.skills` | Battle / Dossier |
| status_engine | afflictions/corruption | `creature_instances.status_effects/entropy` | Battle / Dossier |
| loot_engine | capture/breed odds | `runs.gear`, `inventory` | Capture / Husbandry |
| character_engine | morality/rank/grid | `runs` (axes, deeds, god_form) | Ascension / world reactivity |

## Appendix C — Pre-build checklist (gate to start engineering)
- [ ] ADR-001/002 frozen (RNG + rounding) · [ ] `balance_constants.json` created, §6.5 reconciled · [ ] Supabase projects + RLS migration + pgTAP green · [ ] CI skeleton with parity + RLS gates · [x] **auth method chosen — ADR-011** (Q1) · [x] **save format chosen — ADR-012** (Q3) · [ ] golden-vector generator producing vectors · [ ] design handoff mockups available for Phase 5 screens.

---

*End of TDD v1.0. This document is normative for the build. Changes go through an ADR + a version bump. The Python engines remain the source of truth for game behavior; this document is the source of truth for how that behavior becomes a shipped product.*


