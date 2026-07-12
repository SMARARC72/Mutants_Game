-- Atomic run aggregate compare-and-swap (ADR-003/004, TDD section 10.3).
-- SECURITY INVOKER keeps row-level security authoritative for every call.

create or replace function save_run_cas(p_run jsonb, p_base_save_version integer)
returns jsonb
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_run_id uuid;
  v_player_id uuid;
  v_server_version integer;
  v_new_version integer;
begin
  if auth.uid() is null then
    return jsonb_build_object('status', 'ERROR', 'message', 'authentication required');
  end if;
  if p_run is null or jsonb_typeof(p_run) <> 'object' then
    return jsonb_build_object('status', 'ERROR', 'message', 'run payload must be an object');
  end if;
  if p_base_save_version is null or p_base_save_version < 0 then
    return jsonb_build_object('status', 'ERROR', 'message', 'base save version must be non-negative');
  end if;

  begin
    v_run_id := nullif(p_run ->> 'id', '')::uuid;
    v_player_id := nullif(p_run ->> 'player_id', '')::uuid;
  exception when invalid_text_representation then
    return jsonb_build_object('status', 'ERROR', 'message', 'run id and player id must be UUIDs');
  end;
  if v_run_id is null or v_player_id is null then
    return jsonb_build_object('status', 'ERROR', 'message', 'run id and player id are required');
  end if;
  if v_player_id <> auth.uid() then
    return jsonb_build_object('status', 'ERROR', 'message', 'run owner does not match session');
  end if;

  select save_version into v_server_version from runs where id = v_run_id for update;
  if found then
    if p_base_save_version <> v_server_version then
      return jsonb_build_object(
        'status', 'CONFLICT',
        'save_version', p_base_save_version,
        'server_version', v_server_version,
        'message', format(
          'save_version conflict: base %s is stale; server is at %s.',
          p_base_save_version,
          v_server_version
        )
      );
    end if;
    v_new_version := v_server_version + 1;
    update runs set
      seed = coalesce((p_run ->> 'seed')::bigint, seed),
      act = coalesce((p_run ->> 'act')::integer, act),
      rank = coalesce(p_run ->> 'rank', rank),
      order_chaos = coalesce((p_run ->> 'order_chaos')::integer, order_chaos),
      purity_corrupt = coalesce((p_run ->> 'purity_corrupt')::integer, purity_corrupt),
      notoriety = coalesce((p_run ->> 'notoriety')::integer, notoriety),
      deeds = coalesce((p_run ->> 'deeds')::integer, deeds),
      corruption = coalesce((p_run ->> 'corruption')::integer, corruption),
      drachma = coalesce((p_run ->> 'drachma')::integer, drachma),
      essence = coalesce((p_run ->> 'essence')::integer, essence),
      ichor = coalesce((p_run ->> 'ichor')::integer, ichor),
      gear = coalesce(p_run -> 'gear', gear),
      god_form = case when p_run ? 'god_form' then p_run ->> 'god_form' else god_form end,
      status = coalesce(p_run ->> 'status', status),
      schema_version = coalesce((p_run ->> 'schema_version')::integer, schema_version),
      save_version = v_new_version
    where id = v_run_id;
    return jsonb_build_object(
      'status', 'OK', 'save_version', v_new_version, 'server_version', v_new_version
    );
  end if;

  if p_base_save_version <> 0 then
    return jsonb_build_object(
      'status', 'CONFLICT',
      'save_version', p_base_save_version,
      'server_version', 0,
      'message', 'run does not exist at the requested base version'
    );
  end if;

  insert into runs (
    id, player_id, seed, act, rank, order_chaos, purity_corrupt, notoriety, deeds,
    corruption, drachma, essence, ichor, gear, god_form, status, schema_version, save_version
  ) values (
    v_run_id,
    auth.uid(),
    coalesce((p_run ->> 'seed')::bigint, 0),
    coalesce((p_run ->> 'act')::integer, 0),
    coalesce(p_run ->> 'rank', 'Mortal'),
    coalesce((p_run ->> 'order_chaos')::integer, 0),
    coalesce((p_run ->> 'purity_corrupt')::integer, 0),
    coalesce((p_run ->> 'notoriety')::integer, 0),
    coalesce((p_run ->> 'deeds')::integer, 0),
    coalesce((p_run ->> 'corruption')::integer, 0),
    coalesce((p_run ->> 'drachma')::integer, 0),
    coalesce((p_run ->> 'essence')::integer, 0),
    coalesce((p_run ->> 'ichor')::integer, 0),
    coalesce(p_run -> 'gear', '{}'::jsonb),
    p_run ->> 'god_form',
    coalesce(p_run ->> 'status', 'active'),
    coalesce((p_run ->> 'schema_version')::integer, 1),
    1
  )
  on conflict (id) do nothing
  returning save_version into v_new_version;

  if v_new_version is not null then
    return jsonb_build_object('status', 'OK', 'save_version', 1, 'server_version', 1);
  end if;
  select save_version into v_server_version from runs where id = v_run_id;
  if found then
    return jsonb_build_object(
      'status', 'CONFLICT',
      'save_version', p_base_save_version,
      'server_version', v_server_version,
      'message', 'concurrent create won; reload before saving'
    );
  end if;
  return jsonb_build_object('status', 'ERROR', 'message', 'run is not writable by this session');
exception
  when check_violation or not_null_violation or foreign_key_violation or invalid_text_representation then
    return jsonb_build_object('status', 'ERROR', 'message', sqlerrm);
end;
$$;

revoke all on function save_run_cas(jsonb, integer) from public, anon;
grant execute on function save_run_cas(jsonb, integer) to authenticated;
