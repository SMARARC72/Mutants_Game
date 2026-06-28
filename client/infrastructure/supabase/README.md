# client/infrastructure/supabase

The thin wrapper over Supabase (auth, DB, storage) used **only** from the Infrastructure
layer. The Domain layer never imports this (TDD §3.1 determinism boundary).

## Secret policy (non-negotiable — TDD §9.2, guardrails)

The desktop client ships **only**:

- `SUPABASE_URL` (public)
- `SUPABASE_ANON_KEY` (public by design — safe under RLS)

The **service-role key** and the **OpenAI key** live exclusively in Vercel/Supabase
server environments and must never appear in `client/`. CI secret-scans for them.

Config is injected at build/runtime (env or an untracked local config), never committed.
See `supabase_config.example.gd` for the shape — copy to a git-ignored real config.

## Files

- `auth.gd` — anonymous-first auth path (ADR-011). Phase-0 interface stub; the live
  flow is proven by `supabase/tests/smoke_anon_isolation.mjs` and implemented in Phase 3.
- `supabase_config.example.gd` — example config (placeholders only; anon key only).

The Supabase Godot addon is vendored in Phase 0.5 (`client/addons/supabase/`); real
repositories (run_repo, instance_repo, …) arrive in Phase 3.
