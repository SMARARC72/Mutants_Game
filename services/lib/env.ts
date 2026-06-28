// Server-side configuration — secrets are read from `process.env` ONLY (TDD §9.2). None of
// these values are ever returned to the client; the service-role key + OpenAI key live as
// Vercel env secrets per environment. See services/.env.example for the required names.

import { z } from "zod";

const EnvSchema = z.object({
  // Supabase project URL — also used to derive the JWKS endpoint for JWT verification.
  SUPABASE_URL: z.string().url(),
  // Service-role key: grants the privileged writes (art_assets reservation, snapshot insert).
  // NEVER returned to the client. RLS is bypassed by this role, so all authorization is
  // performed in code (ownership checks) before any write.
  SUPABASE_SERVICE_ROLE_KEY: z.string().min(1),
  // OpenAI key: the gen proxy is the *only* holder (ADR-007).
  OPENAI_API_KEY: z.string().min(1),
  // Storage bucket for generated art (TDD §5.6).
  ART_BUCKET: z.string().min(1).default("creature-art"),
  // Cost guardrails (TDD §7.3 step 3). Defaults are conservative; override per environment.
  ART_RATE_LIMIT_PER_MINUTE: z.coerce.number().int().positive().default(6),
  ART_MONTHLY_CAP: z.coerce.number().int().positive().default(200),
});

export type ServiceEnv = z.infer<typeof EnvSchema>;

/**
 * Parse + validate process env. Throws a descriptive error at boot if a required secret is
 * missing (fail fast — never run half-configured with privileged keys).
 */
export function loadEnv(source: NodeJS.ProcessEnv = process.env): ServiceEnv {
  const parsed = EnvSchema.safeParse(source);
  if (!parsed.success) {
    const missing = parsed.error.issues.map((i) => i.path.join(".")).join(", ");
    throw new Error(`Invalid/missing service environment variables: ${missing}`);
  }
  return parsed.data;
}
