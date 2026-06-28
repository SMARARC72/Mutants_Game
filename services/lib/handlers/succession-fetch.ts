// /api/succession/fetch handler (TDD §7.4). JWT-authed. Returns shareable snapshots:
//   - GET ?id=<uuid>   → that snapshot if shareable OR owned by the caller (honors RLS).
//   - GET ?pool=<n>    → a pool of shareable snapshots (curated/random "invasions").
// Defaults to a small shareable pool when no params are given.

import { ApiError } from "../errors.js";
import { ok, type ServiceRequest, type ServiceResponse } from "../http.js";
import { authenticate, type JwtVerifier } from "../jwt.js";
import {
  SuccessionFetchQuery,
  type SuccessionFetchResponse,
  type SuccessionSnapshot,
  parseOrThrow,
} from "../schemas.js";
import type { GameStore, GodSnapshotRow } from "../store.js";

export interface SuccessionFetchDeps {
  readonly verifier: JwtVerifier;
  readonly store: GameStore;
}

const DEFAULT_POOL = 10;

function toSnapshot(row: GodSnapshotRow): SuccessionSnapshot {
  return {
    id: row.id,
    source_run: row.source_run,
    source_player: row.source_player,
    name: row.name,
    grid: row.grid,
    forces: row.forces ?? null,
    team: row.team ?? null,
    signature_moves: row.signature_moves ?? null,
    shareable: row.shareable,
    created_at: row.created_at,
  };
}

export function makeSuccessionFetchHandler(deps: SuccessionFetchDeps) {
  return async function handle(
    req: ServiceRequest,
  ): Promise<ServiceResponse<SuccessionFetchResponse>> {
    const auth = await authenticate(req, deps.verifier);
    const query = parseOrThrow(SuccessionFetchQuery, req.query);

    if (query.id) {
      const row = await deps.store.getSnapshotById(query.id, auth.playerId);
      if (!row) {
        // Not found OR not shareable to this caller — same response (no enumeration leak).
        throw new ApiError("not_found", "Snapshot not found or not shareable.");
      }
      return ok({ snapshots: [toSnapshot(row)] });
    }

    const limit = query.pool ?? DEFAULT_POOL;
    const rows = await deps.store.listShareableSnapshots(limit);
    return ok({ snapshots: rows.map(toSnapshot) });
  };
}
