# ADR-008 — RLS default-deny on every table; catalog read-only public

**Status:** Accepted (TDD §5.4) · **Phase:** implemented P0

## Context
Security is default-deny. A player must read/write only their own rows; catalog is shared read-only;
secrets never reach the client (anon key + RLS is the model).

## Decision
RLS enabled on all 13 tables. Owner policies via `auth.uid()`. Run-children authorize single-hop via
`run_id`. `art_assets` authorizes via a **TWO-hop** join (creature_instances → runs; it has no
`run_id`). Catalog (species/gear/skills/factions) = `select using (true)`, no write policy (only
service_role writes). `god_snapshots` readable when `shareable or source_player = auth.uid()`,
writable only by owner. Anonymous sign-ins carry the `authenticated` role; `anon` gets catalog reads only.

## Consequences
- Migration 0003 implements all policies + GRANTs. pgTAP suite (`supabase/tests/rls_test.sql`) proves
  allow + deny for every owned table (40 assertions, green); breaking a policy turns a deny-test red.
