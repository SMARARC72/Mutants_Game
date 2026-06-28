// Typed, zod-validated request/response contracts at every boundary (TDD §7.6). Validation
// failures throw `ApiError('invalid_request')` with the zod issues in `details`.

import { z } from "zod";
import { ApiError } from "./errors.js";

const uuid = z.string().uuid();

// ---------------------------------------------------------------------------
// /api/art/generate
// ---------------------------------------------------------------------------
export const ArtGenerateRequest = z.object({
  instance_id: uuid,
  genome_hash: z.string().min(1).max(256),
  sigil_seed: z.number().int(),
  prompt_spec: z
    .object({
      // The deterministic prompt text (genome → prompt) assembled client-side; the server
      // re-moderates it before spending. Bounded to keep moderation/gen costs sane.
      prompt: z.string().min(1).max(4000),
      style: z.string().max(256).optional(),
    })
    .strict(),
});
export type ArtGenerateRequest = z.infer<typeof ArtGenerateRequest>;

export const ArtGenerateResponse = z.object({
  status: z.enum(["ready", "pending"]),
  image_url: z.string().url().nullable(),
  art_asset_id: uuid,
});
export type ArtGenerateResponse = z.infer<typeof ArtGenerateResponse>;

// ---------------------------------------------------------------------------
// /api/succession/publish
// ---------------------------------------------------------------------------
export const SuccessionPublishRequest = z.object({
  source_run: uuid,
  name: z.string().min(1).max(120).optional(),
  grid: z.string().max(120).optional(),
  forces: z.unknown().optional(),
  team: z.unknown(),
  signature_moves: z.unknown().optional(),
  shareable: z.boolean().default(true),
});
export type SuccessionPublishRequest = z.infer<typeof SuccessionPublishRequest>;

export const SuccessionSnapshot = z.object({
  id: uuid,
  source_run: uuid.nullable(),
  source_player: uuid.nullable(),
  name: z.string().nullable(),
  grid: z.string().nullable(),
  forces: z.unknown(),
  team: z.unknown(),
  signature_moves: z.unknown(),
  shareable: z.boolean(),
  created_at: z.string().nullable(),
});
export type SuccessionSnapshot = z.infer<typeof SuccessionSnapshot>;

export const SuccessionPublishResponse = z.object({
  snapshot: SuccessionSnapshot,
});
export type SuccessionPublishResponse = z.infer<typeof SuccessionPublishResponse>;

// ---------------------------------------------------------------------------
// /api/succession/fetch  (GET ?id=<uuid>  OR  GET ?pool=<n>)
// ---------------------------------------------------------------------------
export const SuccessionFetchQuery = z
  .object({
    id: uuid.optional(),
    pool: z.coerce.number().int().min(1).max(50).optional(),
  })
  .refine((q) => (q.id ? !q.pool : true), {
    message: "Provide either `id` or `pool`, not both.",
  });
export type SuccessionFetchQuery = z.infer<typeof SuccessionFetchQuery>;

export const SuccessionFetchResponse = z.object({
  snapshots: z.array(SuccessionSnapshot),
});
export type SuccessionFetchResponse = z.infer<typeof SuccessionFetchResponse>;

// ---------------------------------------------------------------------------
// helper
// ---------------------------------------------------------------------------
export function parseOrThrow<T>(schema: z.ZodType<T>, input: unknown): T {
  const result = schema.safeParse(input);
  if (!result.success) {
    throw new ApiError("invalid_request", "Request validation failed.", {
      issues: result.error.issues.map((i) => ({ path: i.path.join("."), message: i.message })),
    });
  }
  return result.data;
}
