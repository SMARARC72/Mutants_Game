# services — Vercel serverless layer (scaffold)

Privileged compute only (TDD §7). **Never** the game, never normal CRUD (that's the
client ↔ Supabase path). Holds the privileged keys (OpenAI, Supabase service-role) as
Vercel environment secrets — **never** returned to or shipped in the client.

## Planned functions (land in Phase 4)

- `api/art/generate` — OpenAI image-gen proxy (idempotent, generate-once, moderated, cost-capped; ADR-007).
- `api/succession/publish` + `api/succession/fetch` — share/import god-snapshots.
- `api/validate/outcome` — deterministic re-validation for competitive submissions (deferred).
- Companion web (account portal, Succession browser, marketing).

## Phase 0 status

Scaffold only: `package.json` + this README + the `api/` placeholder. No functions, no
secrets. Every endpoint will verify a Supabase JWT and zod-validate input at the boundary
(TDD §7.2, §7.6).
