# Architecture Decision Records

Canonical decision log for Mutants_Game (TDD §15.2). Each ADR is immutable once Accepted;
revisit by superseding with a new ADR + a TDD version bump.

| ADR | Decision | Status | Phase |
|---|---|---|---|
| [001](0001-canonical-rng.md) | Canonical PCG32 RNG in both languages | Accepted | decided P0 / impl P1 |
| [002](0002-canonical-rounding-and-ordering.md) | Half-to-even rounding + total ordering | Accepted | decided P0 / impl P1 |
| [003](0003-client-authoritative-then-revalidate.md) | Client-authoritative now; server re-validate later | Accepted | impl P4+ |
| [004](0004-dal-over-supabase-addon.md) | DAL over the Supabase addon | Accepted | impl P3 |
| [005](0005-versioned-snapshot-saves.md) | Versioned snapshot saves + command log | Accepted | impl P3 |
| [006](0006-catalog-single-source.md) | Catalog single-sourced in-repo → seed + bundle | Accepted | **impl P0** |
| [007](0007-gen-proxy-generate-once.md) | Gen proxy: idempotent generate-once | Accepted | schema P0 / impl P4 |
| [008](0008-rls-default-deny.md) | RLS default-deny on every table | Accepted | **impl P0** |
| [009](0009-python-oracle-parity-gate.md) | Python oracle + golden-vector parity gate | Accepted | foundation P0 |
| [010](0010-monorepo-trunk-flags.md) | Monorepo + trunk-based + flags | Accepted | **impl P0** |
| [011](0011-anonymous-first-auth.md) | Anonymous-first auth, uid preserved on link | Accepted | **wiring P0** |
| [012](0012-versioned-json-save.md) | Versioned JSON save (no Resource deserialization) | Accepted | impl P3 |
| [013](0013-phase05-dependencies.md) | Phase 0.5 vendored addons + asset policy + Beehave RNG rule | Accepted | **impl P0.5** |
| [014](0014-runs-corruption-uncapped.md) | runs.corruption floor-only (not capped at 130) | Accepted | **impl P0 (deviation)** |
