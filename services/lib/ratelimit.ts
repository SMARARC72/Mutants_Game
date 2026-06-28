// Cost/abuse guardrails for the gen proxy (TDD §7.3 step 3, ADR-007). All generation is
// server-metered: a per-player short-window rate limit AND a monthly cap. Both are derived
// from the durable `art_assets.created_at` history (no extra infra needed for MVP); past
// budget → `429 rate_limited`. Counting is delegated to the GameStore so it is testable.

import { ApiError } from "./errors.js";
import type { GameStore } from "./store.js";

export interface RateLimitConfig {
  readonly perMinute: number;
  readonly monthlyCap: number;
}

export interface RateLimitClock {
  now(): Date;
}

const systemClock: RateLimitClock = { now: () => new Date() };

/**
 * Throws `ApiError('rate_limited')` if the player is over the short-window rate limit or the
 * monthly cap. Returns silently when within budget. Checked BEFORE reservation so we never
 * reserve a row we are about to reject.
 */
export async function enforceArtBudget(
  store: GameStore,
  playerId: string,
  cfg: RateLimitConfig,
  clock: RateLimitClock = systemClock,
): Promise<void> {
  const now = clock.now();

  const minuteAgo = new Date(now.getTime() - 60_000).toISOString();
  const recent = await store.countPlayerArtSince(playerId, minuteAgo);
  if (recent >= cfg.perMinute) {
    throw new ApiError("rate_limited", "Generation rate limit exceeded. Try again shortly.", {
      scope: "per_minute",
      limit: cfg.perMinute,
    });
  }

  const monthStart = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1)).toISOString();
  const monthly = await store.countPlayerArtSince(playerId, monthStart);
  if (monthly >= cfg.monthlyCap) {
    throw new ApiError("rate_limited", "Monthly generation cap reached.", {
      scope: "monthly",
      limit: cfg.monthlyCap,
    });
  }
}
