# Mutants_Game — Content Generation Brief (the shared contract)

**Every content sub-agent reads this first, then the relevant design docs, then produces in-canon content to the templates below.** This is what keeps a parallel, multi-agent content build consistent and *mechanical* (not just flavor). When canon here is thin, **read the source doc** (named per section) and **flag gaps** — never invent a contradiction.

---

## 1. Canon snapshot (do not contradict)

- **Tone:** funny-grim, mature-occult. Dread is bedrock; humor is the relief valve — **gallows, deadpan, dry, self-deprecating, with rare unsettling 4th-wall cracks.** Never quippy-Marvel, never zany-for-its-own-sake. **Litmus:** *if a line makes you laugh and then slightly regret laughing, it's on-tone.* Mature, occult, Greek-myth-of-dead-gods.
- **6 forces** (each = a stat): **Gaia**(Bulk) · **Ouranos**(Celerity) · **Cosmos**(Ward) · **Chaos**(Spike) · **Eros**(Vitality) · **Thanatos**(Bane). Universals: Luck, Focus. **Opposed pairs:** Cosmos⇄Chaos · Eros⇄Thanatos · Gaia⇄Ouranos. (Opposed fusion = taboo *abomination*.)
- **Taxonomy:** Rank = wild (T1/T2/T3) · legendary · god · primordial. Class = organic · construct. (Orthogonal to force.)
- **Morality:** two axes — **Order⇄Chaos** and **Purity⇄Corruption** → a 3×3 grid of **9 emergent gods**: Lawgiver · Architect · Iron Throne (Order) / Warden · Broker · Plaguelord (Balanced) / Free-Wild · Reveler · Devourer (Chaos). Endgame: ascend as one of the 9, or refuse → **God-Maker**, or **the Unmaking**.
- **Signature spine:** **Apotheosis → the Succession** — push a creature to a pure force-pole and it ascends into a minor god that reshapes your world; on a throne ending, your champion is snapshotted into the next run's / a friend's async **invasion boss**.
- **9 factions** and **8 regions + the Threshold hub** are **named in `Mutants_Game_Factions.md` / `Mutants_Game_World.md`** — **use those canonical names** (read them; don't rename).
- **Currencies:** Drachma (coin) · Essence (soul-fuel) · Ichor (divine).
- **Already written (match the bar, don't redo):** the pantheon (42 Olympians + 6 Primordials, `Creature_Codex_Book01`), the player ladder (`Character.md`), the 407 art-backed creatures.

## 2. Voice rules
- Mature occult dread first; wit second. Gallows humor, deadpan irony, dry understatement, the occasional absurdist beat, **rare** 4th-wall.
- No real-world IP, no Pokémon/Nintendo names or riffs, no modern slang/memes, no quippy one-liners.
- Cruelty with a wink, never edgelord-for-shock. Death, corruption, sacrifice are *weighty* — the humor makes them land harder, never undercuts them.
- Colorblind-safe principle for any UI copy: never rely on color words alone (pair with icon/shape language).

## 3. System-fit rules (this is what makes content *mechanical*)
- **Names:** unique across the corpus; occult/mythic/evocative; signal force + role + tier; **never** a real-world IP name.
- **Creature descriptions:** **one line, ~15–30 words**, in-voice, hinting force/role/behavior. (Full profiles for net-new tiers live in the codex; the registry wants the crisp line.)
- **Faction/quest content must gate a real mechanic** — a Lab unlock, a capture target, region access, gear, a standing tier. State the gate explicitly.
- **Any creature/boss kit must be expressible by the engines** — valid forces, tier, class, a skill kit from the 8 verbs. Don't invent stats; reference forces/roles.
- **Respect force balance** — don't skew the roster toward one pole.
- **Reference, never contradict,** the written canon (pantheon, player grid, factions, regions).

## 4. Output convention
- Each agent **writes its section to `docs/content/<file>.md`** (create the folder). One agent = one file = no conflicts.
- **Creatures:** output a table **`| id | name | description |`** for every registry row you touch — **sync the name/description from the `Creature_Codex_*` files where they already exist; generate only where genuinely missing.** Key on the registry `id`. Do **not** edit `creature_registry.csv` directly (a later ingest step merges by id).
- Return (to the orchestrator) a 3–5 line summary: your segment, counts produced/synced, and any **canon gaps** you hit.

## 5. Per-section templates

**Creatures** (`content/creatures_*.md`): the `| id | name | description |` table. Naming: evoke the primary/secondary force + role; mythic-occult; distinct.

**Voice & microcopy library** (`content/voice_library.md`): categorized lines — UI/menu labels & buttons, **notifications** (caught/harvested/awakening/burnout/death/quest/rival/corruption-rising), battle barks (per role + per force), Lab flavor (preview/commit/reveal/botch), catch flavor (success/fail/befriend/trap), per-force flavor blurbs, ambient NPC barks, **rare** 4th-wall lines. Aim for breadth (200–300+ lines) in the funny-grim register.

**Factions & NPCs** (`content/factions_npcs.md`): per faction (canonical name) — **leader** (name, title, voice, goal), **2–3 quest-givers / Hands**, **standing-tier reactions** (Stranger → … → Hand dialogue beats), **1–2 quest hooks** each that **gate a real mechanic**. Plus a **starter NPC roster** (named, role, location, voice, sample barks).

**Regions** (`content/regions.md`): per canonical region — lore/history, who/what lives there (named NPCs + signature creatures), 1–2 **set-pieces** (a dungeon/ritual-site for SimpleDungeons), flavor encounters, and a **biome ruleset hook** (what WFC should produce). Keep the Threshold hub distinct (gentle onboarding).

**Quests/story** (`content/quests.md`): per act, a few authored quest beats (objective, branch by morality grid, the **gate** it opens), with sample Dialogic scene lines and Ink-style branching where the lore sprawls.

**Pantheon Succession kits** (`content/pantheon_kits.md`): per god (use the named pantheon) — a **boss kit** (forces, signature moves) + **HSM phases** (Opening→Pressure→Desperation→Apotheosis) for the LimboAI `CombatBrain`.

**Economy/items** (`content/economy_items.md`): item/gear names + one-line descriptions + indicative prices in the 3 currencies + sample shop stocks per region; respect the economy sinks/sources.

**Rivals** (`content/rivals.md`): named nemeses — personality, goal, grid-alignment, signature team, how they escalate.

---

*The systems are built and hungry. This brief is the contract that fills them consistently. Stay in canon, stay in voice, keep it mechanical, flag gaps — and we turn a framework into a world.*
