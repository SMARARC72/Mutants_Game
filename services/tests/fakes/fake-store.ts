// In-memory fake GameStore for offline tests. Models the generate-once invariant faithfully:
// reserveArtAsset is atomic-by-construction (single-threaded JS), so a second reserve for the
// same instance_id returns { reserved:false } with the existing row — exactly like the
// Postgres `on conflict do nothing` path.

import type {
  ArtAssetRow,
  GameStore,
  GodSnapshotInput,
  GodSnapshotRow,
  ReservationResult,
} from "../../lib/store.js";

let idCounter = 0;
function newUuid(prefix: string): string {
  // Deterministic, UUID-shaped id (good enough for fakes; not validated by store).
  idCounter += 1;
  const n = idCounter.toString(16).padStart(12, "0");
  return `${prefix.padEnd(8, "0").slice(0, 8)}-0000-4000-8000-${n}`;
}

export interface FakeStoreOptions {
  /** instance_id → owning player_id. */
  readonly instanceOwners?: Record<string, string>;
  /** run_id → owning player_id. */
  readonly runOwners?: Record<string, string>;
  /** Seed monthly/per-minute usage counts per player. */
  readonly usageCount?: Record<string, number>;
}

export interface FakeStore extends GameStore {
  readonly art: Map<string, ArtAssetRow>;
  readonly snapshots: Map<string, GodSnapshotRow>;
}

export function makeFakeStore(opts: FakeStoreOptions = {}): FakeStore {
  const instanceOwners = { ...(opts.instanceOwners ?? {}) };
  const runOwners = { ...(opts.runOwners ?? {}) };
  const usage = { ...(opts.usageCount ?? {}) };
  const art = new Map<string, ArtAssetRow>(); // keyed by instance_id
  const snapshots = new Map<string, GodSnapshotRow>(); // keyed by id

  const store: FakeStore = {
    art,
    snapshots,

    async playerOwnsInstance(playerId, instanceId) {
      return instanceOwners[instanceId] === playerId;
    },

    async playerOwnsRun(playerId, runId) {
      return runOwners[runId] === playerId;
    },

    async reserveArtAsset(instanceId): Promise<ReservationResult> {
      const existing = art.get(instanceId);
      if (existing) {
        return { id: existing.id, reserved: false, existing };
      }
      const row: ArtAssetRow = {
        id: newUuid("a17"),
        instance_id: instanceId,
        status: "pending",
        image_url: null,
        prompt: null,
        seed: null,
        model: null,
      };
      art.set(instanceId, row);
      return { id: row.id, reserved: true, existing: row };
    },

    async markArtReady(instanceId, data) {
      const cur = art.get(instanceId);
      if (!cur) throw new Error("markArtReady on unreserved instance");
      const row: ArtAssetRow = { ...cur, ...data, status: "ready" };
      art.set(instanceId, row);
      return row;
    },

    async markArtFailed(instanceId) {
      const cur = art.get(instanceId);
      if (cur) art.set(instanceId, { ...cur, status: "failed" });
    },

    async reclaimFailedArtAsset(instanceId) {
      // Atomic-by-construction (single-threaded JS): only flip if currently 'failed'.
      const cur = art.get(instanceId);
      if (cur && cur.status === "failed") {
        art.set(instanceId, { ...cur, status: "pending" });
        return { claimed: true };
      }
      return { claimed: false };
    },

    async countPlayerArtSince(playerId, _sinceIso) {
      return usage[playerId] ?? 0;
    },

    async insertGodSnapshot(input: GodSnapshotInput) {
      const row: GodSnapshotRow = {
        id: newUuid("9d5"),
        source_run: input.source_run,
        source_player: input.source_player,
        name: input.name,
        grid: input.grid,
        forces: input.forces,
        team: input.team,
        signature_moves: input.signature_moves,
        shareable: input.shareable,
        created_at: new Date("2026-01-01T00:00:00.000Z").toISOString(),
      };
      snapshots.set(row.id, row);
      return row;
    },

    async getSnapshotById(id, requesterId) {
      const row = snapshots.get(id);
      if (!row) return null;
      if (!row.shareable && row.source_player !== requesterId) return null;
      return row;
    },

    async listShareableSnapshots(limit) {
      return [...snapshots.values()].filter((s) => s.shareable).slice(0, limit);
    },
  };

  return store;
}
