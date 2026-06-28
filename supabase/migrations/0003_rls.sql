-- 0003_rls.sql — Row-Level Security: default-deny on EVERY table (TDD §5.4, ADR-008, D3).
-- Player-owned tables authorize via auth.uid(); art_assets uses a TWO-hop join (it has
-- no run_id); catalog tables are read-only public (writable only by service_role, which
-- bypasses RLS); god_snapshots is readable when shareable or owned, writable only by owner.
-- Note: anonymous sign-ins carry the `authenticated` role with is_anonymous=true (ADR-011),
-- so player-table grants target `authenticated`; `anon` (no JWT) gets only catalog reads.

-- ---- privileges (RLS is the gate; these GRANTs make RLS-allowed rows reachable) ----
grant usage on schema public to anon, authenticated;

-- catalog: public read
grant select on species, gear, skills, factions to anon, authenticated;

-- player-owned: CRUD for signed-in users (RLS scopes to own rows)
grant select, insert, update, delete on
  players, runs, creature_instances, art_assets,
  inventory, faction_standing, world_state, rivals, god_snapshots
  to authenticated;

-- ============================================================================
-- CATALOG (static): read-only to everyone; no write policy => only service_role.
-- ============================================================================
alter table species  enable row level security;
alter table gear     enable row level security;
alter table skills   enable row level security;
alter table factions enable row level security;

create policy species_read  on species  for select using (true);
create policy gear_read     on gear     for select using (true);
create policy skills_read   on skills   for select using (true);
create policy factions_read on factions for select using (true);

-- ============================================================================
-- PLAYER & RUN (the ownership roots).
-- ============================================================================
alter table players enable row level security;
create policy players_owner on players for all
  using (id = auth.uid())
  with check (id = auth.uid());

alter table runs enable row level security;
create policy runs_owner on runs for all
  using (player_id = auth.uid())
  with check (player_id = auth.uid());

-- ============================================================================
-- RUN-CHILD TABLES — single hop on run_id through the parent run's owner.
-- ============================================================================
alter table creature_instances enable row level security;
create policy creature_instances_owner on creature_instances for all
  using (exists (select 1 from runs r where r.id = run_id and r.player_id = auth.uid()))
  with check (exists (select 1 from runs r where r.id = run_id and r.player_id = auth.uid()));

alter table inventory enable row level security;
create policy inventory_owner on inventory for all
  using (exists (select 1 from runs r where r.id = run_id and r.player_id = auth.uid()))
  with check (exists (select 1 from runs r where r.id = run_id and r.player_id = auth.uid()));

alter table world_state enable row level security;
create policy world_state_owner on world_state for all
  using (exists (select 1 from runs r where r.id = run_id and r.player_id = auth.uid()))
  with check (exists (select 1 from runs r where r.id = run_id and r.player_id = auth.uid()));

alter table faction_standing enable row level security;
create policy faction_standing_owner on faction_standing for all
  using (exists (select 1 from runs r where r.id = run_id and r.player_id = auth.uid()))
  with check (exists (select 1 from runs r where r.id = run_id and r.player_id = auth.uid()));

alter table rivals enable row level security;
create policy rivals_owner on rivals for all
  using (exists (select 1 from runs r where r.id = run_id and r.player_id = auth.uid()))
  with check (exists (select 1 from runs r where r.id = run_id and r.player_id = auth.uid()));

-- ============================================================================
-- ART_ASSETS — NO run_id; authorize via a TWO-hop join creature_instances -> runs.
-- ============================================================================
alter table art_assets enable row level security;
create policy art_assets_owner on art_assets for all
  using (exists (select 1 from creature_instances ci join runs r on r.id = ci.run_id
                 where ci.id = instance_id and r.player_id = auth.uid()))
  with check (exists (select 1 from creature_instances ci join runs r on r.id = ci.run_id
                 where ci.id = instance_id and r.player_id = auth.uid()));

-- ============================================================================
-- GOD_SNAPSHOTS (the Succession) — read shareable OR own; write only your own. The
-- WITH CHECK also requires source_run to be NULL or a run OWNED by the caller, so a player
-- cannot attach forged Succession data to another player's run (Codex review, PR #1).
-- ============================================================================
alter table god_snapshots enable row level security;
create policy god_snapshots_read on god_snapshots for select
  using (shareable or source_player = auth.uid());
create policy god_snapshots_insert on god_snapshots for insert
  with check (source_player = auth.uid()
    and (source_run is null or exists (
      select 1 from runs r where r.id = source_run and r.player_id = auth.uid())));
create policy god_snapshots_update on god_snapshots for update
  using (source_player = auth.uid())
  with check (source_player = auth.uid()
    and (source_run is null or exists (
      select 1 from runs r where r.id = source_run and r.player_id = auth.uid())));
create policy god_snapshots_delete on god_snapshots for delete
  using (source_player = auth.uid());
