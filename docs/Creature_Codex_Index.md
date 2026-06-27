# MUTANTS_GAME — Creature Codex · MASTER INDEX

**Total: 1,067 fully-enriched creatures.** Phase A = 407 art-backed registry creatures (Vols 1–11, all `confirmed`). Phase B = 660 net-new designs awaiting art (Books 1–14; Art field = `TBD (pending art)`).

Every entry carries: art ref · Class/Rank/Tier · force-blend · role · **stat block from the live `stat_engine.py`** · evolution line · signature skill (verb+force) · funny-grim description · acquisition · NOTES. Companion: `Creature_Codex_Families.md` (lineage/synthesis-web map).

---

## Volume / Book map

| File | Scope | Count |
|---|---|---|
| `Creature_Codex_Book01_Pantheon.md` | Pantheon (gods + primordials) | 48 |
| `Creature_Codex_Book02_Constructs_A.md` | Constructs A | 42 |
| `Creature_Codex_Book03_Constructs_B.md` | Constructs B + machine-gods | 48 |
| `Creature_Codex_Book04_Abominations.md` | Taboo abominations | 48 |
| `Creature_Codex_Book05_Succession.md` | Succession Dead Gods | 24 |
| `Creature_Codex_Book06_WildLines_1.md` | Wild lines 1 | 51 |
| `Creature_Codex_Book07_WildLines_2.md` | Wild lines 2 | 51 |
| `Creature_Codex_Book08_WildLines_3.md` | Wild lines 3 | 51 |
| `Creature_Codex_Book09_WildLines_4.md` | Wild lines 4 | 51 |
| `Creature_Codex_Book10_WildLines_5.md` | Wild lines 5 | 51 |
| `Creature_Codex_Book11_WildLines_6.md` | Wild lines 6 | 51 |
| `Creature_Codex_Book12_WildLines_7.md` | Wild lines 7 | 51 |
| `Creature_Codex_Book13_WildLines_8.md` | Wild lines 8 | 51 |
| `Creature_Codex_Book14_WildLines_9.md` | Wild lines 9 | 42 |
| `Creature_Codex_Vol01.md` |  | 20 |
| `Creature_Codex_Vol02.md` |  | 30 |
| `Creature_Codex_Vol03.md` |  | 30 |
| `Creature_Codex_Vol04.md` |  | 30 |
| `Creature_Codex_Vol05.md` |  | 40 |
| `Creature_Codex_Vol06.md` |  | 38 |
| `Creature_Codex_Vol07.md` |  | 50 |
| `Creature_Codex_Vol08.md` |  | 50 |
| `Creature_Codex_Vol09.md` |  | 40 |
| `Creature_Codex_Vol10.md` |  | 40 |
| `Creature_Codex_Vol11.md` |  | 39 |
| **TOTAL** | | **1067** |

## Distribution (all 1,067)

- **By rank:** wild 794 · legendary 165 · god 101 · primordial 6 · (void) 1
- **By class:** organic 952 · construct 114 · - 1
- **By tier (Wild):** T2 295 · T3 281 · - 273 · T1 218
- **By primary force:** Gaia 180 · Thanatos 180 · Ouranos 178 · Eros 178 · Chaos 177 · Cosmos 173 · - 1  ← balanced within 7 across the six poles

## The six forces = the six stats

Gaia→**Bulk** · Ouranos→**Celerity** · Cosmos→**Ward** · Chaos→**Spike** · Eros→**Vitality** · Thanatos→**Bane**  (+ universals **Luck**, **Focus**). Opposed pairs: Cosmos⇄Chaos · Eros⇄Thanatos · Gaia⇄Ouranos. HP = HPBASE + 3·Vitality. All numbers are reproducible: `stat_engine.stat_block(primary, secondary, rank, tier, class)` with default genome.

## Ranks ladder
- **Wild** (T1→T2→T3) — your roster · **Legendary** — named bosses · **God** — named force-vectors (Olympians/Titans) + machine-gods · **Primordial** — the 6 pure poles (ceiling, Apotheosis targets).

---

## Coordination flags for the systems session (read before merging)

- **Stat-doc drift:** `Mutants_Game_StatSpine.md`'s validation table is stale (pre-v0.2.1 balance pass). The live `stat_engine.py` is source-of-truth and matches the AD01 worked example (HP 330). All 1,067 stat blocks come from the live engine. Recommend refreshing the StatSpine table.
- **Phase B needs art:** all 660 net-new creatures (Books 1–14) are flagged `TBD (pending art)`; force/role reads are dossier-intent and should be re-confirmed against renders when generated. Skeleton data (id, force, rank, tier, class, role, theme, locked stats) is in `creature_expansion.csv`.
- **Names & lore live in the codex**, not the registry — they merge back later. The systems session owns `creature_registry.csv` + the `.py` engines; this build never wrote to them.
- **4 name collisions auto-resolved** during QA (renamed the later of each pair): Bristleback→Barrowtusk (S2-22), Rimekit→Sleetkit (batch4-031), Sablecoil→Umbracoil (batch5-047), Aurivex→Solivex (batch5-018). Final corpus: 0 duplicate names.
- **Open juvenile gaps (Phase A):** Emberwyrm, Tidecoil, Rimewarden, Thornmane have apex but no ratified baby. **SB13 Sparkfin** is the shared candidate for *both* Ember Drake and Tide Serpent — assign to one line, not both.
- **Evolution lines are largely proposed.** The registry pre-set only 8 multi-member chains; the rest (Phase A clades + all 150 Phase B WL triads + foundry-classes) are authored groupings flagged for ratification — see `Creature_Codex_Families.md`.
- **Organic↔Construct bridges flagged** (kept as registry class, not reclassified): DM06 Core-golem, b3-066, b5-073–078 Lustreplate, batch4-065 — candidate 'living-core' machine-godhood routes.
- **batch3-078** is an intentional void/blank-render stub (skipped, no stats).
- **A few role/stat-shape mismatches** noted by agents for optional tuning (e.g. WL088-3 nuker on a bruiser HP pool; several bulky-Bane 'assassins') — flagged in-entry, not changed.
- **Divine scale check:** PR-Eros is the durability ceiling of the whole Codex (HP 6400); pure-pole primordials are glass-gods (one towering stat) by design — purity↔fragility in numbers.

---

## How to read an entry
See `Creature_Codex_Vol01.md` (AD01 Ruinmaw) for the gold-standard format every entry follows.

