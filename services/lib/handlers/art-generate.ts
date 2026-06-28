// /api/art/generate handler (ADR-007, TDD §7.3). The idempotent, generate-once, moderated,
// cost-capped OpenAI image-gen proxy. Pure dependency injection so the generate-once
// invariant is unit-testable offline (mocked OpenAI + fake store).
//
// Pipeline:
//   1. Verify JWT → player id.
//   2. Verify the player owns instance_id (creature_instances → runs.player_id).
//   3. Reserve-before-generate: insert ... on conflict do nothing. ONLY the winner generates.
//      A losing/existing call returns the stored URL (ready) or reports pending — NO 2nd gen.
//      A losing call that finds a `failed` row atomically reclaims it (failed -> pending) and,
//      if it wins the reclaim, proceeds down the generation path; otherwise reports pending.
//   4. Cost/abuse guardrails: per-player rate limit + monthly cap → 429 past budget. Enforced
//      ONLY once we are truly about to generate (winner / reclaimer) — existing ready/pending
//      readbacks NEVER hit the cap, so idempotent re-fetch is free.
//   5. Moderation gate on the prompt → 422 if flagged.
//   6. Generate (mockable OpenAI) → stream bytes to Storage.
//   7. Persist status='ready' (or 'failed' on error so the row can be retried).

import { ApiError } from "../errors.js";
import { ok, type ServiceRequest, type ServiceResponse } from "../http.js";
import { authenticate, type JwtVerifier } from "../jwt.js";
import { enforceArtBudget, type RateLimitClock, type RateLimitConfig } from "../ratelimit.js";
import type { ImageGenProvider } from "../openai.js";
import { artStoragePath, type StorageUploader } from "../storage.js";
import { ArtGenerateRequest, type ArtGenerateResponse, parseOrThrow } from "../schemas.js";
import type { GameStore } from "../store.js";

export interface ArtGenerateDeps {
  readonly verifier: JwtVerifier;
  readonly store: GameStore;
  readonly imageGen: ImageGenProvider;
  readonly storage: StorageUploader;
  readonly rateLimit: RateLimitConfig;
  readonly clock?: RateLimitClock;
}

export function makeArtGenerateHandler(deps: ArtGenerateDeps) {
  return async function handle(req: ServiceRequest): Promise<ServiceResponse<ArtGenerateResponse>> {
    // 1. Authn
    const auth = await authenticate(req, deps.verifier);

    // Validate body at the boundary.
    const body = parseOrThrow(ArtGenerateRequest, req.body);

    // 2. Authz — player must own the instance.
    const owns = await deps.store.playerOwnsInstance(auth.playerId, body.instance_id);
    if (!owns) {
      throw new ApiError("forbidden", "You do not own this creature instance.");
    }

    // 3. Reserve-before-generate (race-safe idempotency). NO budget check yet: existing
    //    ready/pending readbacks must be free so idempotent re-fetch is never capped.
    const reservation = await deps.store.reserveArtAsset(body.instance_id);
    if (reservation.reserved) {
      // We won the reservation: we are the sole generator for this instance.
      return await generate(deps, auth.playerId, body);
    }

    // Someone already reserved/generated. Decide based on the existing row's status.
    const { existing } = reservation;
    if (existing && existing.status === "ready" && existing.image_url) {
      // Idempotent re-fetch: return the stored URL — spends nothing, bypasses the budget.
      return ok({ status: "ready", image_url: existing.image_url, art_asset_id: existing.id });
    }
    if (existing && existing.status === "failed") {
      // A prior attempt failed. Try to ATOMICALLY reclaim it for a retry (failed -> pending).
      const { claimed } = await deps.store.reclaimFailedArtAsset(body.instance_id);
      if (claimed) {
        // We own the retry: proceed down the normal generation path (budget + moderate + gen).
        return await generate(deps, auth.playerId, body);
      }
      // Someone else is already retrying — report pending rather than generate again.
      return ok({ status: "pending", image_url: null, art_asset_id: existing.id });
    }
    // Still pending (another request is generating).
    return ok({ status: "pending", image_url: null, art_asset_id: reservation.id });
  };
}

/**
 * The actual generation path, run ONLY by the caller that owns the row (reservation winner or
 * failed-row reclaimer). Enforces the cost cap here — so existing-asset readback paths never
 * hit it — and marks the row failed (retryable) on any failure, including a budget rejection.
 */
async function generate(
  deps: ArtGenerateDeps,
  playerId: string,
  body: ArtGenerateRequest,
): Promise<ServiceResponse<ArtGenerateResponse>> {
  try {
    // 4. Cost/abuse guardrails — gate ONLY a real new generation.
    await enforceArtBudget(deps.store, playerId, deps.rateLimit, deps.clock);

    // 5. Moderation gate.
    const moderation = await deps.imageGen.moderate(body.prompt_spec.prompt);
    if (moderation.flagged) {
      await deps.store.markArtFailed(body.instance_id);
      const flagged = Object.entries(moderation.categories)
        .filter(([, v]) => v)
        .map(([k]) => k);
      throw new ApiError("moderation_blocked", "Prompt rejected by content moderation.", {
        categories: flagged,
      });
    }

    // 6. Generate + stream to Storage.
    const image = await deps.imageGen.generateImage({
      prompt: body.prompt_spec.prompt,
      seed: body.sigil_seed,
    });
    const path = artStoragePath(playerId, body.instance_id, body.sigil_seed);
    const { publicUrl } = await deps.storage.upload({
      path,
      bytes: image.bytes,
      contentType: image.contentType,
    });

    // 7. Persist ready.
    const row = await deps.store.markArtReady(body.instance_id, {
      image_url: publicUrl,
      prompt: body.prompt_spec.prompt,
      seed: body.sigil_seed,
      model: image.model,
    });

    return ok({ status: "ready", image_url: row.image_url, art_asset_id: row.id });
  } catch (err) {
    // Any failure after we own the row: mark failed so it is retryable, then rethrow the typed
    // error for the envelope. This includes a budget rejection (rate_limited) — a reserved row
    // we cannot generate must not stay stuck 'pending'.
    if (!(err instanceof ApiError) || err.code !== "moderation_blocked") {
      await safeMarkFailed(deps.store, body.instance_id);
    }
    throw err;
  }
}

async function safeMarkFailed(store: GameStore, instanceId: string): Promise<void> {
  try {
    await store.markArtFailed(instanceId);
  } catch {
    // Best-effort; the row stays 'pending' and can be reclaimed by an operator/retry path.
  }
}
