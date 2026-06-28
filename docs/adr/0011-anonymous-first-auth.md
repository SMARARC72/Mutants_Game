# ADR-011 — Auth: anonymous-first sign-in → optional email link (uid preserved)

**Status:** Accepted (TDD §5.3, §8.1, §9.4, §18 Q1) · **Phase:** wiring P0, full P3

## Context
Friends should play instantly with zero friction and zero PII, yet be able to make an account later
without losing progress.

## Decision
`signInAnonymously()` on first launch → a real `auth.users` row, so `players.id == auth.uid()` from
launch. Linking a permanent email later (manual identity linking) **preserves the uid**, so all FK'd
data carries over with no reparenting. Anonymous users hold no PII.

## Consequences
- `config.toml`: `enable_anonymous_sign_ins = true`, `enable_manual_linking = true`.
- `players.id references auth.users(id)` with the random default dropped (migration 0002, empty-DB).
- Smoke test (`smoke_anon_isolation.mjs`) proves anon sign-in → isolated rows (green). The Godot auth
  path is a Phase-0 interface stub; the real flow + linking land P3.
