# services — Vercel serverless layer (TDD §7)

Privileged compute only. **Never** the game, never normal CRUD (that's the client ↔ Supabase
path). Holds the privileged keys (OpenAI, Supabase service-role) as **Vercel environment
secrets** — never returned to or shipped in the client (the client ships only the Supabase URL
+ anon key).

TypeScript + zod + `@supabase/supabase-js`, tested with **vitest**. Everything is dependency-
injected so the whole pipeline — including the **generate-once invariant** — runs offline in CI
with a mocked OpenAI and a fake Supabase.

## Endpoints

| Route | Verb | Purpose |
| --- | --- | --- |
| `/api/art/generate` | POST | Idempotent **generate-once** OpenAI image-gen proxy (ADR-007). |
| `/api/succession/publish` | POST | Snapshot the caller's ascended pantheon into `god_snapshots`. |
| `/api/succession/fetch` | GET | Fetch shareable snapshots (by `id`, or a curated/random `pool`). |

Every endpoint: verifies a Supabase **JWT** (JWKS, `sub` = player id, TDD §7.2), zod-validates
input at the boundary, and returns the canonical error envelope `{error:{code,message,details?}}`.

### `/api/art/generate` pipeline (ADR-007, TDD §7.3)

1. Verify JWT → player id.
2. Verify the player owns `instance_id` (`creature_instances` → `runs.player_id`).
3. Cost/abuse guardrails: per-player rate limit + monthly cap → `429` past budget.
4. **Reserve-before-generate** (race-safe): `insert into art_assets (instance_id, status)
   values (.., 'pending') on conflict (instance_id) do nothing returning id`. Only the request
   that wins the insert generates; concurrent/repeat calls return the stored asset — **no second
   OpenAI call**.
5. OpenAI **moderation** gate → `422` if flagged.
6. **Generate** (OpenAI Images — behind a mockable interface) and stream the image to Storage at
   `art/{player_id}/{instance_id}/{sigil_seed}.png`.
7. Persist `status='ready'` (or `'failed'` on error so the row is retryable).

## Layout

```
services/
  api/                      Vercel route entrypoints (thin) + _adapter.ts (Node <-> ServiceRequest)
  lib/
    handlers/               pure request->response handlers (DI'd; the testable core)
    app.ts                  composition root (wires real env/Supabase/OpenAI/Storage)
    jwt.ts                  Supabase JWKS JWT verifier + authenticate() middleware
    store.ts                GameStore interface + Supabase service-role-backed impl (owned facade)
    openai.ts               ImageGenProvider interface + real OpenAI impl (the only key holder)
    storage.ts             StorageUploader interface + Supabase Storage impl
    ratelimit.ts            per-player rate limit + monthly cap
    schemas.ts              zod request/response contracts
    errors.ts / http.ts     error envelope + runtime-agnostic HTTP types
  tests/                    vitest suite + fakes (fake store/openai/storage, real-crypto JWT harness)
  openapi.yaml              checked-in API contract (TDD §7.6)
  .env.example              required server-side secrets (env-only; never committed)
```

## Develop / test

```bash
npm install
npm test        # vitest — generate-once invariant, JWT authz, zod validation, moderation, rate-limit
npm run typecheck
npm run build   # tsc -> dist/ (gitignored)
```

No deploy is wired here ("Keep it buildable + testable with `npm test` (no deploy)").

## Secrets

All privileged secrets are **env-only** (`SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`,
`OPENAI_API_KEY`) — see `.env.example`. They are read in `lib/env.ts` / `lib/app.ts` and never
returned to the client. The repo secret-scan gate (`tools/secret_scan.sh`) must stay green.

## Not in this phase

`/api/validate/outcome` (deterministic re-validation, TDD §7.5) and the companion web app are
deferred; the schema (`god_snapshots`) and determinism (§6) already support them.
