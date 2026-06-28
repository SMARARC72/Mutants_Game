// /api/art/generate handler (ADR-007, TDD §7.3). The idempotent, generate-once, moderated,
// cost-capped OpenAI image-gen proxy. Pure dependency injection so the generate-once
// invariant is unit-testable offline (mocked OpenAI + fake store).
//
// Pipeline:
//   1. Verify JWT → player id.
//   2. Verify the player owns instance_id (creature_instances → runs.player_id).
//   3. Cost/abuse guardrails: per-player rate limit + monthly cap → 429 past budget.
//   4. Reserve-before-generate: insert ... on conflict do nothing. ONLY the winner generates.
//      A losing/existing call returns the stored URL (ready) or reports pending — NO 2nd gen.
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

    // 3. Cost/abuse guardrails (checked BEFORE reserving a row).
    await enforceArtBudget(deps.store, auth.playerId, deps.rateLimit, deps.clock);

    // 4. Reserve-before-generate (race-safe idempotency).
    const reservation = await deps.store.reserveArtAsset(body.instance_id);
    if (!reservation.reserved) {
      // Someone already reserved/generated. Return the stored result; NEVER generate again.
      const existing = reservation.existing;
      if (existing && existing.status === "ready" && existing.image_url) {
        return ok({ status: "ready", image_url: existing.image_url, art_asset_id: existing.id });
      }
      if (existing && existing.status === "failed") {
        // A prior attempt failed; surface it as retryable rather than silently re-spending.
        throw new ApiError("upstream_error", "A prior generation failed; retry later.", {
          art_asset_id: existing.id,
        });
      }
      // Still pending (another request is generating).
      return ok({ status: "pending", image_url: null, art_asset_id: reservation.id });
    }

    // --- We won the reservation: we are the sole generator for this instance. ---
    try {
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
      const path = artStoragePath(auth.playerId, body.instance_id, body.sigil_seed);
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
      // Any failure after reservation: mark failed so the row is retryable, then rethrow the
      // typed error (moderation_blocked / upstream_error) for the envelope.
      if (!(err instanceof ApiError) || err.code !== "moderation_blocked") {
        await safeMarkFailed(deps.store, body.instance_id);
      }
      throw err;
    }
  };
}

async function safeMarkFailed(store: GameStore, instanceId: string): Promise<void> {
  try {
    await store.markArtFailed(instanceId);
  } catch {
    // Best-effort; the row stays 'pending' and can be reclaimed by an operator/retry path.
  }
}
