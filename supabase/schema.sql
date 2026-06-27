-- MUTANTS_GAME — Supabase / Postgres schema (v0.1)
-- Every system ports here. JSONB for flexible/evolving fields; FKs for relationships.
-- Forces are the shared language; corruption is the shared cost; essence is the shared fuel.

-- ========== SPECIES (the registry / templates) ==========
create table species (                      -- the 407-creature registry
  id              text primary key,         -- e.g. 'AD01', 'batch5-044'
  name            text,
  batch           text,
  art_ref         text,                      -- montage index / authored art id
  class           text check (class in ('organic','construct')),
  rank            text check (rank in ('wild','legendary','god','primordial')),
  tier            text,                      -- T1/T2/T3 for wild
  force_primary   text not null,
  force_secondary text,
  role            text,
  evolution_line  text,
  stage           text,                      -- baby/mid/apex
  signature_skill text,
  tags            text[],
  description      text,
  status          text default 'reviewed'
);

-- ========== PLAYERS & RUNS ==========
create table players (
  id              uuid primary key default gen_random_uuid(),
  handle          text unique,
  created_at      timestamptz default now()
);

create table runs (                          -- one playthrough
  id              uuid primary key default gen_random_uuid(),
  player_id       uuid references players(id),
  seed            bigint,
  act             int default 0,
  rank            text default 'Mortal',     -- Mortal..Primordial
  order_chaos     int default 0,             -- -100 Order .. +100 Chaos
  purity_corrupt  int default 0,             -- -100 Pure  .. +100 Corrupt
  notoriety       int default 0,
  deeds           int default 0,
  corruption      int default 0,             -- player corruption track
  drachma         int default 0,
  essence         int default 0,
  ichor           int default 0,
  gear            jsonb default '{}',        -- {slot: gear_id}
  god_form        text,                      -- set on ascension (grid-god name)
  status          text default 'active',
  created_at      timestamptz default now()
);

-- ========== CREATURE INSTANCES (owned, one-of-one) ==========
create table creature_instances (
  id              uuid primary key default gen_random_uuid(),
  run_id          uuid references runs(id),
  species_id      text references species(id),
  nickname        text,
  genome          jsonb not null,            -- per-stat hidden potential (wide +/-35%) + dormant genes
  expression      numeric default 0.30,      -- 0..1 toward ceiling
  bond            int default 0,
  entropy         int default 0,             -- unified corruption/instability meter
  awakenings      int default 0,
  stats_cached    jsonb,                      -- derived block (Bulk..Bane,Luck,Focus,HP,BST)
  skills          text[],                     -- learned skill ids
  status_effects  jsonb default '{}',
  lineage         jsonb default '{}',         -- ancestry / fused-from / sacrificed-for
  sigil_seed      bigint,                     -- procedural one-of-one signature
  is_dead         boolean default false,      -- permadeath -> parts/graveyard
  created_at      timestamptz default now()
);

-- ========== ART (OpenAI image pipeline: generate-once, persist-forever) ==========
create table art_assets (
  id              uuid primary key default gen_random_uuid(),
  instance_id     uuid references creature_instances(id),
  image_url       text,                       -- stored generated image
  prompt          text,                        -- genome -> prompt
  seed            bigint,
  model           text,
  created_at      timestamptz default now()
);

-- ========== ITEMS / GEAR / SKILLS / PARTS ==========
create table gear (
  id text primary key, name text, slot text, rarity text, force text,
  effects jsonb                               -- {capture, breed_rare, tame, lab, combat}
);
create table skills (
  id text primary key, name text, force text, verb text,
  ap int, focus int, effect jsonb
);
create table inventory (                       -- parts/kits/consumables/vials per run
  id uuid primary key default gen_random_uuid(),
  run_id uuid references runs(id),
  item_type text,                              -- organ/gene-vial/core/scrap/skill-vial/consumable/key
  item_key  text, qty int default 1, meta jsonb default '{}'
);

-- ========== WORLD / FACTIONS / RIVALS ==========
create table factions (
  id text primary key, name text, region text, god text, grid text, ideology text
);
create table faction_standing (
  run_id uuid references runs(id), faction_id text references factions(id),
  standing int default 0, primary key (run_id, faction_id)
);
create table world_state (
  run_id uuid references runs(id) primary key,
  region_states jsonb default '{}',            -- per-region: god alive?, force-tilt, destabilized?
  force_tide text
);
create table rivals (                          -- the nemesis system
  id uuid primary key default gen_random_uuid(),
  run_id uuid references runs(id),
  name text, grid text, faction_id text, team jsonb,
  relationship text default 'rival'            -- rival/ally/nemesis/defeated
);

-- ========== THE SUCCESSION (god snapshots = NG+/friend bosses) ==========
create table god_snapshots (
  id              uuid primary key default gen_random_uuid(),
  source_run      uuid references runs(id),
  source_player   uuid references players(id),
  name            text,                        -- the grid-god + custom name
  grid            text,
  forces          jsonb,
  team            jsonb,                        -- the ascended pantheon (boss team)
  signature_moves jsonb,
  shareable       boolean default true,         -- exportable to friends' worlds
  created_at      timestamptz default now()
);

-- indexes
create index on creature_instances(run_id);
create index on species(force_primary);
create index on faction_standing(run_id);
create index on god_snapshots(source_player);
