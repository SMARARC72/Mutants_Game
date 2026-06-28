# ADR-010 — Monorepo + trunk-based + feature-flagged MVP-first delivery

**Status:** Accepted (TDD §12) · **Phase:** implemented P0

## Context
A small team must build in parallel without drift; `main` must stay shippable.

## Decision
Single GitHub monorepo: `/client /oracle /services /supabase /docs /design /tools`. Git LFS for
art/audio binaries. Trunk-based with short-lived branches; PRs require green CI + review.
Conventional Commits; ADRs in `/docs/adr`. Feature flags gate unfinished systems.

## Consequences
- Phase 0 reorganized the flat project into this layout via `git mv` (renames recorded) and rebuilt
  it as a **single lean baseline commit**. The repo had only one prior commit, so there is no deeper
  history to preserve; the rebuild excludes the ~814 MB of raw art from base history.
- **Git LFS is configured** (hooks + `.gitattributes` patterns for art/audio) but **intentionally
  tracks zero binaries** today, because raw art is excluded from history per the lean-baseline
  decision — the patterns activate the moment art is added (see README "Adding art via LFS").
- CI runs lint + constants parity + DB/RLS + secret-scan on every PR.
