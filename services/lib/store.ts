// Data-access layer over the Supabase service-role client (TDD §7.2, ADR-004 spirit: a thin
// owned facade, never the addon/types leaking across a boundary). The service-role key
// bypasses RLS, so EVERY method here is called only AFTER an explicit ownership check in the
// handler. The `GameStore` interface is what handlers depend on; tests inject a fake.

import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { ApiError } from "./errors.js";
import type { ServiceEnv } from "./env.js";

export type ArtStatus = "pending" | "ready" | "failed";

export interface ArtAssetRow {
  readonly id: string;
  readonly instance_id: string;
  readonly status: ArtStatus;
  readonly image_url: string | null;
  readonly prompt: string | null;
  readonly seed: number | null;
  readonly model: string | null;
}

export interface ReservationResult {
  /** The art_assets row id (winner's freshly-inserted id, or the existing row's id). */
  readonly id: string;
  /** True iff THIS call won the insert and must proceed to generate (ADR-007). */
  readonly reserved: boolean;
  /** The current row (present whenever a row already existed). */
  readonly existing: ArtAssetRow | null;
}

export interface GodSnapshotInput {
  readonly source_run: string | null;
  readonly source_player: string;
  readonly name: string | null;
  readonly grid: string | null;
  readonly forces: unknown;
  readonly team: unknown;
  readonly signature_moves: unknown;
  readonly shareable: boolean;
}

export interface GodSnapshotRow {
  readonly id: string;
  readonly source_run: string | null;
  readonly source_player: string | null;
  readonly name: string | null;
  readonly grid: string | null;
  readonly forces: unknown;
  readonly team: unknown;
  readonly signature_moves: unknown;
  readonly shareable: boolean;
  readonly created_at: string | null;
}

export interface GameStore {
  /**
   * Two-hop ownership check: does `playerId` own `instanceId`?
   * (creature_instances.run_id → runs.player_id). Used before any art write.
   */
  playerOwnsInstance(playerId: string, instanceId: string): Promise<boolean>;

  /** Does `playerId` own `runId`? Used before publishing a snapshot from a run. */
  playerOwnsRun(playerId: string, runId: string): Promise<boolean>;

  /**
   * Reserve-before-generate (ADR-007, TDD §7.3 step 2). Atomic:
   * `insert into art_assets (instance_id, status) values (.., 'pending')
   *  on conflict (instance_id) do nothing returning id`.
   * Winner: `{ reserved:true }`. Loser/existing: `{ reserved:false, existing }`.
   */
  reserveArtAsset(instanceId: string): Promise<ReservationResult>;

  /** Mark a reserved row ready with the generated artifact metadata. */
  markArtReady(
    instanceId: string,
    data: { image_url: string; prompt: string; seed: number; model: string },
  ): Promise<ArtAssetRow>;

  /** Mark a reserved row failed so it can be retried/reclaimed. */
  markArtFailed(instanceId: string): Promise<void>;

  /** Count this player's art generations since `sinceIso` (monthly cap + rate limit). */
  countPlayerArtSince(playerId: string, sinceIso: string): Promise<number>;

  /** Insert a god snapshot (publish). Caller has already verified run ownership. */
  insertGodSnapshot(input: GodSnapshotInput): Promise<GodSnapshotRow>;

  /** Fetch a snapshot by id, honoring shareability for non-owners. */
  getSnapshotById(id: string, requesterId: string): Promise<GodSnapshotRow | null>;

  /** Fetch a pool of shareable snapshots (random/curated "invasions"). */
  listShareableSnapshots(limit: number): Promise<GodSnapshotRow[]>;
}

const ART_COLUMNS = "id, instance_id, status, image_url, prompt, seed, model";
const SNAPSHOT_COLUMNS =
  "id, source_run, source_player, name, grid, forces, team, signature_moves, shareable, created_at";

/** Construct the privileged service-role client. The key never leaves the server. */
export function serviceRoleClient(env: ServiceEnv): SupabaseClient {
  return createClient(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}

/** Supabase-backed `GameStore`. */
export function supabaseStore(client: SupabaseClient): GameStore {
  return {
    async playerOwnsInstance(playerId, instanceId) {
      const { data, error } = await client
        .from("creature_instances")
        .select("id, runs!inner(player_id)")
        .eq("id", instanceId)
        .eq("runs.player_id", playerId)
        .maybeSingle();
      if (error) throw new ApiError("upstream_error", "Ownership check failed.");
      return data !== null;
    },

    async playerOwnsRun(playerId, runId) {
      const { data, error } = await client
        .from("runs")
        .select("id")
        .eq("id", runId)
        .eq("player_id", playerId)
        .maybeSingle();
      if (error) throw new ApiError("upstream_error", "Ownership check failed.");
      return data !== null;
    },

    async reserveArtAsset(instanceId) {
      // on conflict do nothing → empty result means a row already exists.
      const { data: inserted, error: insertErr } = await client
        .from("art_assets")
        .upsert({ instance_id: instanceId, status: "pending" }, { onConflict: "instance_id", ignoreDuplicates: true })
        .select(ART_COLUMNS);
      if (insertErr) throw new ApiError("upstream_error", "Reservation failed.");

      if (inserted && inserted.length > 0) {
        const row = inserted[0] as unknown as ArtAssetRow;
        return { id: row.id, reserved: true, existing: row };
      }

      // Lost the race / already existed — read the current row.
      const { data: existing, error: readErr } = await client
        .from("art_assets")
        .select(ART_COLUMNS)
        .eq("instance_id", instanceId)
        .maybeSingle();
      if (readErr) throw new ApiError("upstream_error", "Reservation read-back failed.");
      if (!existing) throw new ApiError("upstream_error", "Reservation race read-back empty.");
      const row = existing as unknown as ArtAssetRow;
      return { id: row.id, reserved: false, existing: row };
    },

    async markArtReady(instanceId, dataIn) {
      const { data, error } = await client
        .from("art_assets")
        .update({ ...dataIn, status: "ready" })
        .eq("instance_id", instanceId)
        .select(ART_COLUMNS)
        .single();
      if (error) throw new ApiError("upstream_error", "Persist failed.");
      return data as unknown as ArtAssetRow;
    },

    async markArtFailed(instanceId) {
      const { error } = await client
        .from("art_assets")
        .update({ status: "failed" })
        .eq("instance_id", instanceId);
      if (error) throw new ApiError("upstream_error", "Failure-state write failed.");
    },

    async countPlayerArtSince(playerId, sinceIso) {
      const { count, error } = await client
        .from("art_assets")
        .select("id, creature_instances!inner(runs!inner(player_id))", {
          count: "exact",
          head: true,
        })
        .eq("creature_instances.runs.player_id", playerId)
        .gte("created_at", sinceIso);
      if (error) throw new ApiError("upstream_error", "Usage lookup failed.");
      return count ?? 0;
    },

    async insertGodSnapshot(input) {
      const { data, error } = await client
        .from("god_snapshots")
        .insert(input)
        .select(SNAPSHOT_COLUMNS)
        .single();
      if (error) throw new ApiError("upstream_error", "Publish failed.");
      return data as unknown as GodSnapshotRow;
    },

    async getSnapshotById(id, requesterId) {
      const { data, error } = await client
        .from("god_snapshots")
        .select(SNAPSHOT_COLUMNS)
        .eq("id", id)
        .maybeSingle();
      if (error) throw new ApiError("upstream_error", "Fetch failed.");
      if (!data) return null;
      const row = data as unknown as GodSnapshotRow;
      // Mirror RLS: a non-owner may only read shareable snapshots.
      if (!row.shareable && row.source_player !== requesterId) return null;
      return row;
    },

    async listShareableSnapshots(limit) {
      const { data, error } = await client
        .from("god_snapshots")
        .select(SNAPSHOT_COLUMNS)
        .eq("shareable", true)
        .order("created_at", { ascending: false })
        .limit(limit);
      if (error) throw new ApiError("upstream_error", "Fetch failed.");
      return (data ?? []) as unknown as GodSnapshotRow[];
    },
  };
}
