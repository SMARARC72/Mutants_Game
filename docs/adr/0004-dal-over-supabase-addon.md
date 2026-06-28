# ADR-004 — Repository/DAL over the Supabase addon; no addon calls in gameplay

**Status:** Accepted (TDD §3, §5) · **Phase:** decided P0, implemented P3

## Context
Gameplay must stay pure and testable; the Supabase Godot addon is an I/O dependency of varying
maturity (Realtime edge cases).

## Decision
A thin DAL/repository layer (`infrastructure/dal/`, `infrastructure/supabase/`) wraps the addon.
The Domain layer never holds a DB handle or imports the addon. Fall back to direct PostgREST if a
feature lags. Addon pinned `4.x`.

## Consequences
- Phase 0 scaffolds `infrastructure/supabase/` (auth path stub) only; real repositories land P3.
- The `domain/` purity gate forbids addon references in the domain layer.
