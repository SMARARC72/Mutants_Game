# Mutants_Game — Succession (DG-###) Registry & ID scheme

**Date:** 2026-06-28. Flagged by the endings, rivals, and competition agents: `DG-###` Dead-God snapshot IDs are now assigned by multiple files and **collide** (e.g. a player ending and a rival both claim DG-001). This locks one authoritative scheme so no two snapshots share an ID. The ingest validator enforces it.

## The scheme (authoritative)
| Range | Owner | Notes |
|---|---|---|
| **DG-001 … DG-009** | **The 9 grid-god player ascension endings** | Lawgiver 001 · Architect 002 · Iron Throne 003 · Warden 004 · Broker 005 · Plaguelord 006 · Free Wild 007 · Reveler 008 · Devourer 009. These are the *primary* canonical Dead Gods (the player's possible forms). |
| **DG-010 … DG-039** | **Rivals + Book05 named Dead Gods** | The 24 named rivals (B1–B24) + any `Creature_Codex_Book05_Succession.md` originals each take a **unique** ID in this range. |
| **DG-040+** | reserve | player-`god_snapshot`s minted at runtime, friends' shared snapshots, future content. |

## The rule
1. **DG-001…009 belong to the endings.** Any rival/champion currently bound to an ID in 001–009 (e.g. wave-1 rival "Cassia → DG-001") is **remapped to the next free ID ≥ DG-010**.
2. **Every rival binds to a unique ID ≥ DG-010.** No two rivals share; no rival collides with an ending.
3. **Book05 originals** keep their authored IDs where they're ≥ DG-010; where a Book05 original was numbered 001–009, the *title* maps to the corresponding grid-god ending (they're the same Dead God), not a separate snapshot.
4. **Runtime player/friend snapshots** allocate from DG-040+ and are validated unique at publish (TDD §7.4 Succession).

## Reconciliations to apply at ingest
- **Endings agent** assigned grid-gods DG-001…009 (grid order) — **keep** as the scheme above.
- **Rivals (B1–B24)** in `economy_items_rivals.md` + `roster_shops_expansion.md`: bump any binding in 001–009 to ≥ DG-010; verify the 24 are mutually unique (wave-2 already used 006/008/009/013/014/016/020/021 + minted 025–028 — re-seat the few that fall in 001–009).
- **Book05 title↔number drift** (e.g. "Gardener of Wildfire" listed at DG-004 but themed Chaos/Free-Wild): pin the *title* to its grid-god ending (Free Wild = DG-007), and renumber the stray Book05 entry into the 010+ range.
- **Architect (DG-002)** + **Devourer (DG-024 vs DG-010 dual)**: Architect keeps DG-002 (ending); Devourer ending = DG-009, with any DG-024/DG-010 Book05 skins re-seated ≥ DG-010 as alt-forms, not the ending's primary.

**Net:** endings own 001–009; everyone else lives at 010+; the ingest validator dedupes. No two Dead Gods share an ID in the shipping data.
