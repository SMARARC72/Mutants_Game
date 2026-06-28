// /api/succession/publish handler (TDD §7.4). JWT-authed. Snapshots the caller's ascended
// pantheon into god_snapshots, shareable per the player's choice. Validates that the caller
// owns `source_run` before persisting (mirrors the RLS WITH CHECK in 0003_rls.sql so a player
// cannot attach Succession data to another player's run).

import { ApiError } from "../errors.js";
import { ok, type ServiceRequest, type ServiceResponse } from "../http.js";
import { authenticate, type JwtVerifier } from "../jwt.js";
import {
  SuccessionPublishRequest,
  type SuccessionPublishResponse,
  parseOrThrow,
} from "../schemas.js";
import type { GameStore, GodSnapshotRow } from "../store.js";

export interface SuccessionPublishDeps {
  readonly verifier: JwtVerifier;
  readonly store: GameStore;
}

function toSnapshotResponse(row: GodSnapshotRow): SuccessionPublishResponse {
  return {
    snapshot: {
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
    },
  };
}

export function makeSuccessionPublishHandler(deps: SuccessionPublishDeps) {
  return async function handle(
    req: ServiceRequest,
  ): Promise<ServiceResponse<SuccessionPublishResponse>> {
    const auth = await authenticate(req, deps.verifier);
    const body = parseOrThrow(SuccessionPublishRequest, req.body);

    // Ownership: the caller must own the source run.
    const owns = await deps.store.playerOwnsRun(auth.playerId, body.source_run);
    if (!owns) {
      throw new ApiError("forbidden", "You do not own the source run for this snapshot.");
    }

    const row = await deps.store.insertGodSnapshot({
      source_run: body.source_run,
      source_player: auth.playerId,
      name: body.name ?? null,
      grid: body.grid ?? null,
      forces: body.forces ?? null,
      team: body.team ?? null,
      signature_moves: body.signature_moves ?? null,
      shareable: body.shareable ?? true,
    });

    return ok(toSnapshotResponse(row));
  };
}
