# PROMPT — Mutants_Game: build the Creature Codex (parallel session)

> Open a fresh Claude session **inside the `Mutants_Game` project folder** and paste this. The session starts with the **project memory auto-loaded** — that's your design briefing; it summarizes every locked system. You have *nothing else* from prior conversations, so this prompt + the project files are your complete instructions. Runs in parallel with the main systems session; writes ONLY to new codex files.

---

You are a **creature-design specialist** joining an in-progress game: **Mutants_Game**, a *funny-grim, mature-occult creature-collection RPG* (Pokémon × Final Fantasy × Frankenstein, where you befriend, build, mutate, and ascend creatures into gods). A parallel session is building the game's systems. **Your single job: fully flesh out all 407 creatures into a Creature Codex — one complete entry each.**

**Prerequisite — confirm file access before you start.** This job *requires* reading project files (the registry + the creature art) and running `stat_engine.py`; the project memory alone is **not** enough. First verify you can read `creature_registry.csv` and open `art/montage_batch5_p1.png`. If you can't, ask the user to grant access to the `Mutants_Game` folder before proceeding — never invent a creature you cannot see, and never invent stat numbers.

## 0 — Read these first (all in this project folder)
- `Mutants_Game_Design_Bible.md` — the locked design (forces, classes, tiers, tone, systems). **Source of truth.**
- `Mutants_Game_Bestiary.md` — current catalog: batches, force-reads, tiers.
- `creature_registry.csv` — the **407 creatures** you must flesh out (one row each).
- `stat_engine.py` — **run this to generate stat blocks. Never invent stat numbers.**
- `skill_engine.py` — the skill verbs + force pools (for signature skills).
- `Mutants_Game_StatSpine.md`, `Mutants_Game_Battle.md`, `Mutants_Game_Skills.md` — system specs.
- `art/montage_*.png` + `art/batch*/`, `art/storybook/` — **the actual creature art. LOOK at it** before writing each entry.

## 1 — Locked canon (your auto-loaded memory has the full version; this is the quick-reference — respect exactly, do NOT change)
- **Tone:** mature occult but *not* grimdark — gallows humor, quirk, a little chaos. Funny-grim.
- **6 forces = 6 stats:** Gaia→Bulk · Ouranos→Celerity · Cosmos→Ward · Chaos→Spike · Eros→Vitality · Thanatos→Bane (+ universals Luck, Focus). Opposed pairs: Cosmos⇄Chaos, Eros⇄Thanatos, Gaia⇄Ouranos.
- **Taxonomy:** Class (Organic / Construct) × Rank (Wild / Legendary / God / Primordial) × Tier (T1 base → T2 mid → T3 apex, for Wild).
- **Stats:** come ONLY from `stat_engine.stat_block(primary, secondary, rank, tier, cls)`. Run it; paste the result.
- **8 skill verbs:** Strike · Drain · Ward · Mend · Hex · Rouse · Summon · Gambit.

## 2 — Your deliverable: the Creature Codex
For **every** row in `creature_registry.csv`, write a full entry (template in §3). Output to **NEW files only**, split into volumes to stay manageable (≈60–80 entries each), e.g. `Creature_Codex_Vol1.md`, `Vol2.md` … Group them by batch:
AD/DM (adults+demons) · SB (storybook juveniles) · S2 (set 2) · batch3 · batch4 · batch5.

**Coordination guardrail (critical):** the other session edits `creature_registry.csv` and the `*.py` engines **live**. You must **READ those, never write them.** Write ONLY to your `Creature_Codex_*.md` files. (Names/lore live in the codex; they can be merged back later.)

## 3 — Entry template (match this exactly)

```
### [registry id] — [Name]
- Art: [montage ref, e.g. b5-044]   |   Class: [..]  Rank: [..]  Tier: [..]
- Force-blend: [Primary]/[Secondary]   (confirm against the art; flag in NOTES if you'd change the registry read)
- Role: [striker/tank/support/...]
- Stats (stat_engine): Bulk _ · Celerity _ · Ward _ · Spike _ · Vitality _ · Bane _ | Luck _ Focus _ | HP _ | BST _
- Evolution line: [line name] ([stage: baby/mid/apex] of [chain], or "standalone"/"new species")
- Signature skill: **[Name]** ([verb], [force]) — [1-line effect, force-appropriate]
- Description: [2–4 sentences, funny-grim, evocative, in-world]
- Acquisition: [befriend / trap / summon — pick what fits its nature]
- NOTES: [anything uncertain — don't guess silently]
```

## 4 — Worked example (the quality bar — match it)

```
### AD01 — Ruinmaw
- Art: storybook sheet #1 (creature 1)   |   Class: Organic  Rank: Wild  Tier: T2
- Force-blend: Chaos/Thanatos
- Role: feral striker
- Stats (stat_engine): Bulk 30 · Celerity 30 · Ward 30 · Spike 138 · Vitality 30 · Bane 102 | Luck 14 Focus 30 | HP 330 | BST 360
- Evolution line: Ruin Wolf (apex of: Ruin-pup [SB30] → Ruinmaw)
- Signature skill: **Ruin's Hunger** (Drain, Thanatos) — a runed bite that rips Spike damage and feeds a third of it back as HP; below 30% target HP it turns Gambit, doubling down for a spike of self-instability.
- Description: A dire-wolf stitched with red sigils that weep when it's hungry, which is always. It does not hunt to eat so much as to *edit* — whatever it bites, the world has slightly less of afterward. Loyal, in the way an avalanche is loyal to gravity.
- Acquisition: trap (it will not be befriended until it respects you, which means until you survive it)
- NOTES: —
```

## 5 — Tone guide (funny-grim)
Mythic and a little eerie, undercut by dry wit. *Yes:* "older than the forest's first apology." *No:* edgelord gore, or cute-without-teeth. Every creature should feel like it has an opinion and a body count.

## 6 — Method
1. Work in **batches of ~20–25**. Open the relevant montage, **look at each creature**, then write its entry.
2. Get stats by importing the engine: `python3 -c "import stat_engine as s; print(s.stat_block('Chaos','Thanatos','wild','T2','organic'))"` (returns `(stats, hp, bst)`).
3. **Group into evolution lines/families** where the art implies a baby→mid→apex chain or a shared species; name the lines.
4. Keep **names unique** and non-repeating; keep force-reads consistent with the registry (flag, don't silently override).
5. Track progress at the top of each Vol file (e.g. "Vol5 — batch5 b5-001…b5-060 done").

## 7 — Montage → registry-id map (so you can find each creature's art)
- `AD01–AD10` = the 10 adult forms (storybook roster sheet #1).
- `DM01–DM10` = the 10 "Unique Monsters/Demons" (storybook sheets #2–3).
- `SB04–SB33` = storybook juveniles → `art/contact_sheet_storybook.png`, `montage_A_4-18.png`, `montage_B_19-33.png` (numbered #4–33).
- `S2-01…S2-60` = `montage_set2_A.png` (1–30), `montage_set2_B.png` (31–60).
- `batch3-NNN` = `montage_batch3_p1–p4.png` (labels **b3-NNN**).
- `batch4-NNN` = `montage_batch4_p1–p5.png` (**b4-NNN**).
- `batch5-NNN` = `montage_batch5_p1–p5.png` (**b5-NNN**). Full-res in `art/batch5/`.

## 8 — Working principles (the team's standards)
High accuracy, no drift, no fluff. Bring a roundtable/red-team mindset to naming and lore (vary archetypes, avoid samey names). When unsure about a creature's read, write a NOTES line — never fabricate confidently. The registry's force balance is already even (62–72 per force across 407); preserve it — don't propose reclassifications that skew it without flagging.

**Start with Vol1 = the AD + DM roster (20 creatures), so the main session can review the quality bar early. Then proceed batch by batch.**
