# ADR-007 — Gen proxy: idempotent generate-once, moderated, cost-capped

**Status:** Accepted (TDD §7.3, §5.6) · **Phase:** decided P0, implemented P4

## Context
OpenAI image generation is the primary variable cost. A naive check-then-generate lets two
concurrent requests both call OpenAI (double-spend).

## Decision
`/api/art/generate` reserves the row first: `insert ... on conflict (instance_id) do nothing`.
Only the winner generates; others return the stored URL. Per-player rate limit + monthly cap +
moderation. `art_assets` gets `status` (pending/ready/failed) and **`unique (instance_id)`**.

## Consequences
- Phase 0 adds `art_assets.status` + `unique (instance_id)` (migration 0002) so the reserve-before-
  generate protocol is enforceable. The endpoint itself is built P4. The art_assets RLS policy is
  two-hop (no `run_id` on the table).
