-- 0002_hardening.sql — production hardening over the base schema (TDD §5.3, §5.6, D2).
-- Runs on a FRESH/EMPTY database as part of the migration chain (supabase db reset),
-- so the auth-id rewire is an empty-DB migration, NOT a backfill (TDD §5.3).

-- ============================================================================
-- 1) IDENTITY: players.id IS the Supabase Auth user id (never client-asserted).
--    Drop the random default (Auth supplies the id); FK to auth.users; cascade on
--    account deletion. Players start anonymous (signInAnonymously -> a real
--    auth.users row); linking an email later preserves the uid (ADR-011).
-- ============================================================================
alter table players alter column id drop default;
alter table players
  add constraint players_id_fkey foreign key (id) references auth.users(id) on delete cascade;

-- ============================================================================
-- 2) AUDIT / VERSIONING — updated_at on mutable tables (trigger-maintained) +
--    save_version / schema_version on the aggregate root (runs). created_at
--    already exists on players/runs/creature_instances/art_assets/god_snapshots.
-- ============================================================================
create or replace function set_updated_at() returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- add updated_at (+ created_at where missing on mutable per-player tables)
alter table players            add column updated_at timestamptz default now();
alter table runs               add column updated_at timestamptz default now();
alter table creature_instances add column updated_at timestamptz default now();
alter table art_assets         add column updated_at timestamptz default now();
alter table inventory          add column created_at timestamptz default now(),
                               add column updated_at timestamptz default now();
alter table faction_standing   add column created_at timestamptz default now(),
                               add column updated_at timestamptz default now();
alter table world_state        add column created_at timestamptz default now(),
                               add column updated_at timestamptz default now();
alter table rivals             add column created_at timestamptz default now(),
                               add column updated_at timestamptz default now();
alter table god_snapshots      add column updated_at timestamptz default now();

-- aggregate-root versioning (save_version is the SOLE sync conflict key, TDD §10.3)
alter table runs
  add column save_version int not null default 1,
  add column schema_version int not null default 1;

-- updated_at triggers on every mutable table
create trigger trg_players_updated            before update on players            for each row execute function set_updated_at();
create trigger trg_runs_updated               before update on runs               for each row execute function set_updated_at();
create trigger trg_creature_instances_updated before update on creature_instances for each row execute function set_updated_at();
create trigger trg_art_assets_updated         before update on art_assets         for each row execute function set_updated_at();
create trigger trg_inventory_updated          before update on inventory          for each row execute function set_updated_at();
create trigger trg_faction_standing_updated   before update on faction_standing   for each row execute function set_updated_at();
create trigger trg_world_state_updated        before update on world_state        for each row execute function set_updated_at();
create trigger trg_rivals_updated             before update on rivals             for each row execute function set_updated_at();
create trigger trg_god_snapshots_updated      before update on god_snapshots      for each row execute function set_updated_at();

-- ============================================================================
-- 3) ENUMS / CHECKS — no invalid state at the store (TDD §5.3). CHECK constraints
--    (the "enums or CHECK" option) keep the columns text-typed and migratable.
--    Force columns are constrained to the six primordials.
-- ============================================================================
do $$ begin
  -- forces ∈ the six (NULL allowed on nullable columns)
  alter table species       add constraint species_force_primary_ck
    check (force_primary in ('Gaia','Ouranos','Cosmos','Chaos','Eros','Thanatos'));
  alter table species       add constraint species_force_secondary_ck
    check (force_secondary is null or force_secondary in ('Gaia','Ouranos','Cosmos','Chaos','Eros','Thanatos'));
  alter table gear          add constraint gear_force_ck
    check (force is null or force in ('Gaia','Ouranos','Cosmos','Chaos','Eros','Thanatos'));
  alter table skills        add constraint skills_force_ck
    check (force is null or force in ('Gaia','Ouranos','Cosmos','Chaos','Eros','Thanatos'));
  alter table world_state   add constraint world_state_force_tide_ck
    check (force_tide is null or force_tide in ('Gaia','Ouranos','Cosmos','Chaos','Eros','Thanatos'));
  -- run lifecycle + rival relationship (provisional Phase-0 value sets; extend via migration)
  alter table runs          add constraint runs_status_ck
    check (status in ('active','ascended','fallen','abandoned'));
  alter table rivals        add constraint rivals_relationship_ck
    check (relationship in ('rival','ally','nemesis','defeated'));
end $$;

-- ============================================================================
-- 4) ON-DELETE POLICY — player-owned children cascade from runs/players;
--    god_snapshots deliberately SET NULL so the Succession mythology outlives
--    run/player deletion (TDD §5.3, §9.4). Re-create FKs with the on-delete clause.
-- ============================================================================
alter table runs               drop constraint if exists runs_player_id_fkey;
alter table runs               add  constraint runs_player_id_fkey
  foreign key (player_id) references players(id) on delete cascade;

alter table creature_instances drop constraint if exists creature_instances_run_id_fkey;
alter table creature_instances add  constraint creature_instances_run_id_fkey
  foreign key (run_id) references runs(id) on delete cascade;

alter table art_assets         drop constraint if exists art_assets_instance_id_fkey;
alter table art_assets         add  constraint art_assets_instance_id_fkey
  foreign key (instance_id) references creature_instances(id) on delete cascade;

alter table inventory          drop constraint if exists inventory_run_id_fkey;
alter table inventory          add  constraint inventory_run_id_fkey
  foreign key (run_id) references runs(id) on delete cascade;

alter table faction_standing   drop constraint if exists faction_standing_run_id_fkey;
alter table faction_standing   add  constraint faction_standing_run_id_fkey
  foreign key (run_id) references runs(id) on delete cascade;

alter table world_state        drop constraint if exists world_state_run_id_fkey;
alter table world_state        add  constraint world_state_run_id_fkey
  foreign key (run_id) references runs(id) on delete cascade;

alter table rivals             drop constraint if exists rivals_run_id_fkey;
alter table rivals             add  constraint rivals_run_id_fkey
  foreign key (run_id) references runs(id) on delete cascade;

alter table god_snapshots      drop constraint if exists god_snapshots_source_run_fkey;
alter table god_snapshots      add  constraint god_snapshots_source_run_fkey
  foreign key (source_run) references runs(id) on delete set null;

alter table god_snapshots      drop constraint if exists god_snapshots_source_player_fkey;
alter table god_snapshots      add  constraint god_snapshots_source_player_fkey
  foreign key (source_player) references players(id) on delete set null;

-- ============================================================================
-- 5) NUMERIC INTEGRITY — non-negative money/meters; bounded where the engine
--    bounds them (expression ∈ [0,1]).
--    NOTE (ADR-014): runs.corruption is the cumulative PLAYER track, fed UNCLAMPED
--    by lab_engine (+18/taboo fuse, +35/self-splice) and character_engine — it can
--    legitimately exceed 130 in a full run. The "≤130" cap in status_engine is the
--    per-combatant BATTLE-LIVE meter, which TDD §4.2 says is NOT persisted. So we
--    deviate from the literal TDD §5.3 / kickoff "corruption ≤ 130": floor-only here,
--    to avoid rejecting legitimate save/sync writes in Phase 3.
-- ============================================================================
alter table runs
  add constraint runs_drachma_nonneg    check (drachma    >= 0),
  add constraint runs_essence_nonneg    check (essence    >= 0),
  add constraint runs_ichor_nonneg      check (ichor      >= 0),
  add constraint runs_corruption_nonneg check (corruption >= 0),
  add constraint runs_notoriety_nonneg  check (notoriety  >= 0),
  add constraint runs_deeds_nonneg      check (deeds      >= 0);

alter table creature_instances
  add constraint ci_entropy_nonneg     check (entropy    >= 0),
  add constraint ci_bond_nonneg        check (bond       >= 0),
  add constraint ci_awakenings_nonneg  check (awakenings >= 0),
  add constraint ci_expression_range   check (expression >= 0 and expression <= 1);

alter table inventory
  add constraint inventory_qty_nonneg  check (qty >= 0);

-- ============================================================================
-- 6) ART ASSETS — generate-once-persist-forever (ADR-007). status lifecycle +
--    unique(instance_id) so a retry OR a concurrent request never double-generates
--    (closes the OpenAI double-spend race together with reserve-before-generate).
-- ============================================================================
alter table art_assets
  add column status text default 'pending'
    check (status in ('pending','ready','failed')),
  add constraint art_assets_instance_unique unique (instance_id);

-- ============================================================================
-- 7) INDEXES — replace the full creature_instances(run_id) index with the partial
--    hot-party index; add inventory + shareable-snapshot indexes (TDD §5.3).
-- ============================================================================
drop index if exists creature_instances_run_id_idx;
create index creature_instances_run_id_alive_idx
  on creature_instances(run_id) where is_dead = false;
create index inventory_run_id_item_type_idx
  on inventory(run_id, item_type);
create index god_snapshots_shareable_idx
  on god_snapshots(shareable) where shareable;
