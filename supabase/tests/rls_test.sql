-- rls_test.sql — pgTAP proof of Row-Level Security (TDD §5.4, §11.4, D3).
-- For EVERY player-owned table: prove the owner CAN read+write own rows AND a different
-- authenticated user CANNOT. Plus catalog read-only-public, and the god_snapshots
-- shareable rule. "RLS without tests is not done." Run: supabase test db
--
-- Mechanics: setup runs as the superuser (RLS bypassed) to plant two users' fixtures;
-- each assertion block then `set local role authenticated` + sets request.jwt.claims->sub
-- so auth.uid() resolves to the acting user and RLS is actually enforced.

begin;
select plan(61);

-- ---- fixtures (as superuser) ---------------------------------------------
\set uA '00000000-0000-0000-0000-00000000000a'
\set uB '00000000-0000-0000-0000-00000000000b'

insert into auth.users (id, aud, role, email, instance_id, created_at, updated_at)
values (:'uA', 'authenticated', 'authenticated', 'a@test.local', '00000000-0000-0000-0000-000000000000', now(), now()),
       (:'uB', 'authenticated', 'authenticated', 'b@test.local', '00000000-0000-0000-0000-000000000000', now(), now());

insert into players (id, handle) values (:'uA', 'player_a'), (:'uB', 'player_b');

insert into runs (id, player_id, seed) values
  ('00000000-0000-0000-0000-0000000000a1', :'uA', 1),
  ('00000000-0000-0000-0000-0000000000b1', :'uB', 2);

insert into creature_instances (id, run_id, genome) values
  ('00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-0000000000a1', '{}'),
  ('00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-0000000000b1', '{}');

insert into art_assets (id, instance_id, image_url) values
  ('00000000-0000-0000-0000-0000000000a3', '00000000-0000-0000-0000-0000000000a2', 'a.png'),
  ('00000000-0000-0000-0000-0000000000b3', '00000000-0000-0000-0000-0000000000b2', 'b.png');

insert into factions (id, name) values ('f_test', 'Test Faction');

insert into inventory (id, run_id, item_type) values
  ('00000000-0000-0000-0000-0000000000a4', '00000000-0000-0000-0000-0000000000a1', 'organ'),
  ('00000000-0000-0000-0000-0000000000b4', '00000000-0000-0000-0000-0000000000b1', 'organ');

insert into world_state (run_id) values
  ('00000000-0000-0000-0000-0000000000a1'),
  ('00000000-0000-0000-0000-0000000000b1');

insert into faction_standing (run_id, faction_id) values
  ('00000000-0000-0000-0000-0000000000a1', 'f_test'),
  ('00000000-0000-0000-0000-0000000000b1', 'f_test');

insert into rivals (id, run_id, name) values
  ('00000000-0000-0000-0000-0000000000a5', '00000000-0000-0000-0000-0000000000a1', 'rivalA'),
  ('00000000-0000-0000-0000-0000000000b5', '00000000-0000-0000-0000-0000000000b1', 'rivalB');

insert into god_snapshots (id, source_run, source_player, name, shareable) values
  ('00000000-0000-0000-0000-0000000000a6', '00000000-0000-0000-0000-0000000000a1', :'uA', 'gsA_share', true),
  ('00000000-0000-0000-0000-0000000000a7', '00000000-0000-0000-0000-0000000000a1', :'uA', 'gsA_priv',  false),
  ('00000000-0000-0000-0000-0000000000b6', '00000000-0000-0000-0000-0000000000b1', :'uB', 'gsB_share', true),
  ('00000000-0000-0000-0000-0000000000b7', '00000000-0000-0000-0000-0000000000b1', :'uB', 'gsB_priv',  false);

-- seed minimal catalog rows for read tests
insert into species (id, name, force_primary) values ('sp_test', 'Test Mon', 'Gaia');
insert into gear (id, name) values ('g_test', 'Test Gear');
insert into skills (id, name) values ('sk_test', 'Test Skill');

-- helper: become user A / user B (role authenticated; auth.uid() <- sub claim)
\set claimsA '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}'
\set claimsB '{"sub":"00000000-0000-0000-0000-00000000000b","role":"authenticated"}'

-- ==========================================================================
-- PLAYERS
-- ==========================================================================
set local role authenticated;
select set_config('request.jwt.claims', :'claimsA', true);
select is((select count(*)::int from players where id = :'uA'), 1, 'players: A reads own row');
select is((select count(*)::int from players where id = :'uB'), 0, 'players: A cannot read B row');
select lives_ok($$ update players set handle = 'a2' where id = '00000000-0000-0000-0000-00000000000a' $$, 'players: A updates own row');
select throws_ok($$ insert into players (id, handle) values ('00000000-0000-0000-0000-00000000000c', 'c') $$, '42501', NULL, 'players: A cannot insert a row for another uid');

-- ==========================================================================
-- RUNS
-- ==========================================================================
select is((select count(*)::int from runs where player_id = :'uA'), 1, 'runs: A reads own');
select is((select count(*)::int from runs where player_id = :'uB'), 0, 'runs: A cannot read B');
select lives_ok($$ update runs set notoriety = 5 where player_id = '00000000-0000-0000-0000-00000000000a' $$, 'runs: A updates own');
select throws_ok($$ insert into runs (player_id, seed) values ('00000000-0000-0000-0000-00000000000b', 9) $$, '42501', NULL, 'runs: A cannot create a run owned by B');
update runs set notoriety = 99 where id = '00000000-0000-0000-0000-0000000000b1'; -- silently affects 0 rows
select set_config('request.jwt.claims', NULL, true);
reset role;
select is((select notoriety from runs where id = '00000000-0000-0000-0000-0000000000b1'), 0, 'runs: A''s update did not touch B''s row');

-- Atomic save RPC: update, stale conflict, create, and cross-owner denial all remain under RLS.
set local role authenticated;
select set_config('request.jwt.claims', :'claimsA', true);
select ok(
  (result ->> 'status' = 'OK' and (result ->> 'save_version')::int = 2),
  'save_run_cas: owner atomically advances v1 to v2'
) from (select save_run_cas(
  jsonb_build_object(
    'id', '00000000-0000-0000-0000-0000000000a1', 'player_id', :'uA', 'notoriety', 21
  ),
  1
) as result) s;
select ok(
  (result ->> 'status' = 'CONFLICT' and (result ->> 'server_version')::int = 2),
  'save_run_cas: stale base returns conflict with server version'
) from (select save_run_cas(
  jsonb_build_object(
    'id', '00000000-0000-0000-0000-0000000000a1', 'player_id', :'uA', 'notoriety', 999
  ),
  1
) as result) s;
select is(
  (select notoriety from runs where id = '00000000-0000-0000-0000-0000000000a1'),
  21,
  'save_run_cas: stale write does not overwrite data'
);
select ok(
  (result ->> 'status' = 'OK' and (result ->> 'save_version')::int = 1),
  'save_run_cas: owner atomically creates a run at v1'
) from (select save_run_cas(
  jsonb_build_object(
    'id', '00000000-0000-0000-0000-0000000000a8', 'player_id', :'uA', 'seed', 88
  ),
  0
) as result) s;
select is(
  (select save_version from runs where id = '00000000-0000-0000-0000-0000000000a8'),
  1,
  'save_run_cas: created row is owned and versioned'
);
select is(
  (select save_run_cas(
    jsonb_build_object(
      'id', '00000000-0000-0000-0000-0000000000b1', 'player_id', :'uA', 'notoriety', 777
    ),
    0
  ) ->> 'status'),
  'ERROR',
  'save_run_cas: another player''s run is not writable or disclosed'
);

-- ===========================================================================
-- CREATURE_INSTANCES (run-child, single hop)
-- ==========================================================================
set local role authenticated;
select set_config('request.jwt.claims', :'claimsA', true);
select is((select count(*)::int from creature_instances where id = '00000000-0000-0000-0000-0000000000a2'), 1, 'creature_instances: A reads own');
select is((select count(*)::int from creature_instances where id = '00000000-0000-0000-0000-0000000000b2'), 0, 'creature_instances: A cannot read B');
select lives_ok($$ update creature_instances set nickname = 'x' where id = '00000000-0000-0000-0000-0000000000a2' $$, 'creature_instances: A updates own');
select throws_ok($$ insert into creature_instances (run_id, genome) values ('00000000-0000-0000-0000-0000000000b1', '{}') $$, '42501', NULL, 'creature_instances: A cannot add to B run');

-- ==========================================================================
-- ART_ASSETS (TWO-hop: instance -> run -> owner)
-- ==========================================================================
select is((select count(*)::int from art_assets where id = '00000000-0000-0000-0000-0000000000a3'), 1, 'art_assets: A reads own (two-hop)');
select is((select count(*)::int from art_assets where id = '00000000-0000-0000-0000-0000000000b3'), 0, 'art_assets: A cannot read B (two-hop)');
select lives_ok($$ update art_assets set status = 'ready' where id = '00000000-0000-0000-0000-0000000000a3' $$, 'art_assets: A updates own');
select throws_ok($$ insert into art_assets (instance_id, image_url) values ('00000000-0000-0000-0000-0000000000b2', 'x') $$, '42501', NULL, 'art_assets: A cannot attach art to B instance');

-- ==========================================================================
-- INVENTORY
-- ==========================================================================
select is((select count(*)::int from inventory where id = '00000000-0000-0000-0000-0000000000a4'), 1, 'inventory: A reads own');
select is((select count(*)::int from inventory where id = '00000000-0000-0000-0000-0000000000b4'), 0, 'inventory: A cannot read B');
select throws_ok($$ insert into inventory (run_id, item_type) values ('00000000-0000-0000-0000-0000000000b1', 'core') $$, '42501', NULL, 'inventory: A cannot add to B run');

-- ==========================================================================
-- WORLD_STATE
-- ==========================================================================
select is((select count(*)::int from world_state where run_id = '00000000-0000-0000-0000-0000000000a1'), 1, 'world_state: A reads own');
select is((select count(*)::int from world_state where run_id = '00000000-0000-0000-0000-0000000000b1'), 0, 'world_state: A cannot read B');
select lives_ok($$ update world_state set force_tide = 'Gaia' where run_id = '00000000-0000-0000-0000-0000000000a1' $$, 'world_state: A updates own');

-- ==========================================================================
-- FACTION_STANDING
-- ==========================================================================
select is((select count(*)::int from faction_standing where run_id = '00000000-0000-0000-0000-0000000000a1'), 1, 'faction_standing: A reads own');
select is((select count(*)::int from faction_standing where run_id = '00000000-0000-0000-0000-0000000000b1'), 0, 'faction_standing: A cannot read B');
select throws_ok($$ insert into faction_standing (run_id, faction_id) values ('00000000-0000-0000-0000-0000000000b1', 'f_test') $$, '42501', NULL, 'faction_standing: A cannot write to B run');

-- ==========================================================================
-- RIVALS
-- ==========================================================================
select is((select count(*)::int from rivals where id = '00000000-0000-0000-0000-0000000000a5'), 1, 'rivals: A reads own');
select is((select count(*)::int from rivals where id = '00000000-0000-0000-0000-0000000000b5'), 0, 'rivals: A cannot read B');
select throws_ok($$ insert into rivals (run_id, name) values ('00000000-0000-0000-0000-0000000000b1', 'x') $$, '42501', NULL, 'rivals: A cannot add to B run');

-- ==========================================================================
-- GOD_SNAPSHOTS (shareable OR own to read; own to write)
-- ==========================================================================
select is((select count(*)::int from god_snapshots where id = '00000000-0000-0000-0000-0000000000a7'), 1, 'god_snapshots: A reads own private');
select is((select count(*)::int from god_snapshots where id = '00000000-0000-0000-0000-0000000000b6'), 1, 'god_snapshots: A reads B''s SHAREABLE');
select is((select count(*)::int from god_snapshots where id = '00000000-0000-0000-0000-0000000000b7'), 0, 'god_snapshots: A cannot read B''s private');
select lives_ok($$ insert into god_snapshots (source_run, source_player, name) values ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-00000000000a', 'mine') $$, 'god_snapshots: A inserts own');
select throws_ok($$ insert into god_snapshots (source_run, source_player, name) values ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-00000000000b', 'forged') $$, '42501', NULL, 'god_snapshots: A cannot insert as B');
-- Codex PR#1: A cannot attach a snapshot to B's run (source_run must be own or null)
select throws_ok($$ insert into god_snapshots (source_run, source_player, name) values ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-00000000000a', 'forged-run') $$, '42501', NULL, 'god_snapshots: A cannot point source_run at B''s run');

-- ==========================================================================
-- WRITE-OWN (allow) for the remaining child tables — completes "owner can write".
-- ==========================================================================
select lives_ok($$ update inventory set qty = 2 where id = '00000000-0000-0000-0000-0000000000a4' $$, 'inventory: A updates own');
select lives_ok($$ update faction_standing set standing = 1 where run_id = '00000000-0000-0000-0000-0000000000a1' $$, 'faction_standing: A updates own');
select lives_ok($$ update rivals set relationship = 'ally' where id = '00000000-0000-0000-0000-0000000000a5' $$, 'rivals: A updates own');

-- ==========================================================================
-- CROSS-USER WRITE-DENY (update of B's row affects 0 rows) — every owned table.
-- An UPDATE whose target is hidden by RLS USING silently matches 0 rows (no error).
-- ==========================================================================
with u as (update players            set handle = 'hax'        where id     = '00000000-0000-0000-0000-00000000000b' returning 1) select is(count(*)::int, 0, 'players: A cannot update B row') from u;
with u as (update creature_instances set nickname = 'hax'      where id     = '00000000-0000-0000-0000-0000000000b2' returning 1) select is(count(*)::int, 0, 'creature_instances: A cannot update B row') from u;
with u as (update art_assets         set status = 'ready'      where id     = '00000000-0000-0000-0000-0000000000b3' returning 1) select is(count(*)::int, 0, 'art_assets: A cannot update B row') from u;
with u as (update inventory          set qty = 99              where id     = '00000000-0000-0000-0000-0000000000b4' returning 1) select is(count(*)::int, 0, 'inventory: A cannot update B row') from u;
with u as (update world_state        set force_tide = 'Chaos'  where run_id = '00000000-0000-0000-0000-0000000000b1' returning 1) select is(count(*)::int, 0, 'world_state: A cannot update B row') from u;
with u as (update faction_standing   set standing = 99         where run_id = '00000000-0000-0000-0000-0000000000b1' returning 1) select is(count(*)::int, 0, 'faction_standing: A cannot update B row') from u;
with u as (update rivals             set relationship = 'ally' where id     = '00000000-0000-0000-0000-0000000000b5' returning 1) select is(count(*)::int, 0, 'rivals: A cannot update B row') from u;
with u as (update god_snapshots      set name = 'hax'          where id     = '00000000-0000-0000-0000-0000000000b6' returning 1) select is(count(*)::int, 0, 'god_snapshots: A cannot update B''s shareable snapshot') from u;

-- ==========================================================================
-- OWN-ROW INSERT (allow) for run-child tables (players/runs own-insert proven by the
-- D5 anon smoke test; god_snapshots own-insert proven above).
-- ==========================================================================
select lives_ok($$ insert into creature_instances (run_id, genome) values ('00000000-0000-0000-0000-0000000000a1', '{}') $$, 'creature_instances: A inserts into own run');
select lives_ok($$ insert into inventory (run_id, item_type) values ('00000000-0000-0000-0000-0000000000a1', 'core') $$, 'inventory: A inserts into own run');
select lives_ok($$ insert into rivals (run_id, name) values ('00000000-0000-0000-0000-0000000000a1', 'newrival') $$, 'rivals: A inserts into own run');

-- ==========================================================================
-- CATALOG: read-only public; writes denied for normal users
-- ==========================================================================
select is((select count(*)::int from species  where id = 'sp_test'), 1, 'catalog: authenticated reads species');
select throws_ok($$ insert into species (id, name, force_primary) values ('sp_hack','x','Gaia') $$, '42501', NULL, 'catalog: authenticated cannot write species');
select throws_ok($$ update gear set name = 'x' where id = 'g_test' $$, '42501', NULL, 'catalog: authenticated cannot update gear');

-- anonymous (no JWT) can still read catalog
select set_config('request.jwt.claims', NULL, true);
set local role anon;
select is((select count(*)::int from skills where id = 'sk_test'), 1, 'catalog: anon reads skills');
select is((select count(*)::int from factions where id = 'f_test'), 1, 'catalog: anon reads factions');
-- anon (no JWT) has no GRANT on player tables -> denied at the privilege level (even
-- before RLS), which is stronger than RLS-filtering. Assert the hard deny.
select throws_ok($$ select count(*) from runs $$, '42501', NULL, 'anon is denied player tables (no grant)');

reset role;
select set_config('request.jwt.claims', NULL, true);

select * from finish();
rollback;
