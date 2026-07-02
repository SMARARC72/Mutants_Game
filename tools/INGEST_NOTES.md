# Quest & Timeline Ingest — structural decisions + warn-lists (Batch E1a)

The authored docs (`docs/content/story_quests.md`, `side_quests.md`, `scripts_mvp.md`,
`scripts_acts2to5.md`) are the SOURCE. `tools/ingest_quests.py` and `tools/gen_timelines.py`
are deterministic transforms — re-runs over unchanged sources are byte-identical. Where a doc
is structurally ambiguous the tools make the **conservative** choice; every such choice is
recorded here so nothing is silently invented.

## ingest_quests.py — decisions

1. **One step per quest.** The docs author exactly one `Objective` line per quest; the
   branch forks are dialogue/scene-layer effects. Every quest therefore emits a single
   step (`id: "objective"`, `step_key: "<quest_id>_step"`) carrying the VERBATIM objective
   text. Branch effects (flags/corruption per fork) belong on Dialogic choice configs —
   the proven Old Garran / Vael-Mark pattern — and are NOT invented into quest defs.
2. **Quest ids.** Main: `act<N>_<slug(title)>` — this makes the four Act-0 ids collide
   exactly with the hand-wired canon ids (`act0_the_knack`, `act0_altar_hours`,
   `act0_the_mark`, `act0_registered`), so the loader's dedupe keeps the hand-wired defs.
   Side: `<slug(title)>` — SQ-04/05/06 likewise collide with the wired
   `the_melon_that_waits` / `six_petals_true_bred` / `the_bloom_that_wont_bury`.
3. **Act gates.** `story_quests.md` states each act climax "opens Act N+1" (Q0.4 → Act 1,
   Q1.4 → Act 2, Q2.4 → Act 3, Q3.4 → Act 4, Q4.4 resolves the run → Act 5). Encoding:
   quest `X.4` sets `act<X+1>_open` on completion; `X.1` (X>0) requires `act<X>_open`;
   within an act the quests chain linearly (`X.Y` requires `act<X>_q<Y-1>_done`) — the
   docs order them as a progression (region access → Lab gate → capstone → climax), and
   linear chaining is the conservative reading. Q5.4 (no act 6) sets `act5_q4_done`.
   **Hand-wired bridge:** the canonical Act-0 climax sets `registered_aspirant` (not
   `act1_open`), so `QuestCatalog.ACT_GATE_ALIASES` maps `act1_open → registered_aspirant`.
   The JSON stays doc-pure; the alias lives in the loader.
4. **Regions.** Side quests name a region in their header (mapped to engine region ids).
   Main quests carry a region only where the giver line carries an unambiguous
   `(Region · God)` tag before any `e.g.` (faction-dependent quests like Q2.1/Q3.1 are
   authored "the leader of your most-courted/Champion faction" — region stays `""`, i.e.
   act-gated but region-agnostic). Act-0 quests default to `threshold` (the authored hub).
5. **Side quests carry `act: -1`** ("not act-gated"): `side_quests.md` states no acts —
   region access is their availability gate ("The Maw Beneath — gated late" gates through
   region access, not an act flag). `prereq_flags` stays empty.
6. **Rewards.** Every standing phrase in the docs' `Gate / Reward` lines is BRANCH-gated
   ("running it clean unlocks…", "handing it to the Guild grants +1…") — emitting one
   unconditionally on quest completion would credit a fork the player may not have taken.
   So quest `on_complete` carries ONLY the deterministic gate flag; the detected standing
   phrases are surfaced as `standing_mentions` (and in the warn-list section below) for
   the dialogue-choice wiring to consume — the wired Old Garran pattern, where branch
   effects live on the NPC choice config. Item grants (`grant_item`), currency payouts,
   Lab sub-unlocks and capture-target registrations are engine features other waves own —
   recorded, not faked, so no effect key is emitted the QuestService cannot honor.
7. **`objective_text` / `title` / `giver_npc` are VERBATIM** doc text minus markdown
   emphasis markers. `story_quests.md`'s NPC names are kept verbatim even where
   `_NAME_RECONCILIATION.md` re-roles them (Sylva Greenrot, Quintus Slagg, Old Marrow…):
   the reconciliation is a CAST decision applied at dialogue level (the generated
   timelines use the canonical speakers), not a quest-data rewrite. The warn-list below
   tracks every giver missing from the cast docs.

## gen_timelines.py — decisions

1. **One `.dtl` per authored scene** (8 MVP + 10 Acts-2–5), ids `mvp_s<NN>_<slug>` /
   `acts_s<NN>_<slug>`, in `client/presentation/dialogue/generated/`. Registered in
   `project.godot` `[dialogic]` `dtl_directory` (sorted merge; `DialogicFacade
   .ensure_directories()` self-heals if an import wipes the maps).
2. **Dialogue is VERBATIM.** Speaker lines and `NARRATION:` lines land word-for-word.
   Stage directions / toast callouts (lines opening with `*(`), `>> GATE/CONSEQUENCE`
   mechanics, `→ goes to/converges` routing markup, and `[Ink →]` knots are NOT dialogue
   and are skipped (Ink trees are a separate engine's content; the toasts are VoiceBook
   keys other waves wired). Skip counts per scene are listed below.
3. **`>> CHOICE` blocks become Dialogic `- choice` events** with the authored option text
   VERBATIM and `[signal arg="choice:<tag>"]` per the wired old_garran convention. Tags
   derive from the option's authored `Flags \`x\`` (first flag) else the branch label —
   deterministic, deduped per choice.
4. **Branch blocks nest under their options** (`→ goes to **X**` targets render inside the
   option, recursively). A block targeted by SEVERAL options (a convergent finish, e.g.
   Acts scene 3's `3B-Bloom / 3B-Order / …`) stays top-level after the choice — Dialogic's
   post-choice flow IS the convergence.
5. **Engine-routed forks** (router lists like Sworn-Rite's "highest standing" and mode
   blocks like Petrification's ASCENDED/GOD-MAKER) are represented as Dialogic choices
   whose option text is the authored block title, tag = slug of the target block id. The
   engine (or the player, until the router glue lands) picks the branch; the doc's routing
   condition is preserved in the scene comment header.
6. **Conditional lines are skipped, counted below.** Lines opening with a `{flag …}` /
   `{grid …}` guard are save-reactive variants; Dialogic-side conditions are a wiring
   feature (VAR bridge) another wave owns. Inline `{…|…}` variants mid-line are kept
   verbatim (cosmetic at play time, parse-safe). Nothing is paraphrased.
7. **Speakers map to existing `.dch` characters where names match** (old_maddox,
   mother_kestrel, veil, vael, thessaly_vance, matron_sevvy, hearthward_ona); every NEW
   speaker gets a generated `.dch` stub in
   `client/presentation/dialogue/characters/generated/` with the canonical display name
   (per `factions_npcs.md` / `_NAME_RECONCILIATION.md`) and an identity colour hashed
   from the name into the six-force GrimoirePalette ring (the OverworldTokens
   name-hash convention). Registered in `dch_directory`.

## quest_catalog.gd — loader decisions

1. `OverworldContent.quest_defs()` UNIONS hand-wired defs (Act-0 spine, SQ-04/05/06,
   marsh/boss goals — canonical, always win the dedupe) with catalog quests for the
   ACTIVE region: catalog entries whose region is the active region, `threshold` (the hub
   rides the shipped region — the W16b pattern), or `""` (region-agnostic main spine).
   BOSS_QUEST stays LAST (the HUD floor rule).
2. Catalog defs express `prereq_flags` as the QuestService `trigger: {"flag": …}`
   predicate (single-flag; the generated chain never needs more than one).
3. Generated quests carry step_keys no NPC declares, so the overworld NPC dispatch never
   touches them (the BOSS_QUEST precedent) — they register, gate, walk, and surface in
   the Journal/HUD once started; giving them to NPCs is later waves' wiring.

<!-- BEGIN ingest_quests.py (generated warn-lists — do not edit) -->

**Counts (actuals):** 24 main (act 0: 4 · act 1: 4 · act 2: 4 · act 3: 4 · act 4: 4 · act 5: 4) · 28 side. Docs promise 24 main / 28 side.

**Standing phrases detected (branch-gated in the doc — surfaced for the dialogue-choice wiring, NOT emitted as unconditional quest rewards):** ash_that_stays_gone -> pale_court; name_one -> iron_guild; out_of_tolerance -> iron_guild; bring_them_in_breathing -> high_table; dont_drink_the_red_one -> revel; a_seal_left_loose -> concord; the_wild_saints_cousin -> concord; one_honest_tap -> iron_guild

**Giver warn-list (not found in regional_cast.md / factions_npcs.md — story_quests.md names are net-new authored per its own canon-gap note; reconcile via _NAME_RECONCILIATION.md, do not invent):**
- act0_altar_hours: Quintus Slagg
- act0_the_mark: Vael Construct-Nine
- act0_registered: Madam Thessaly Vance
- act1_greener_pastures_hungrier_ones: Mother Sylva Greenrot
- act1_the_foremans_problem: Foreman Castor Brail
- act1_the_guardian_at_the_node: Huntmaster Bram Stoneblood
- act1_the_reliquary_of_winners: Archivist Pellos Vane
- act2_the_sworn_rite: Lord Severin Ash
- act2_the_line_you_cant_uncross: Doctor Vesh Quillon
- act2_the_one_who_climbed_beside_you: Kestrel Dane
- act2_first_light: Vael Construct-Nine
- act3_first_blood_on_the_thrones: Magister Aurelian Vox
- act3_the_throne_turned: Vael Construct-Nine
- act3_holes_in_the_sky: Madam Thessaly Vance
- act4_the_last_reckoning_of_the_clans: Concord's Aurelian Vox
- act4_the_empty_seat: Vael Construct-Nine
- act5_petrification: Vael Construct-Nine
- act5_the_first_invader: new nobody
- act5_the_walls_choice: moment itself

<!-- END ingest_quests.py -->

<!-- BEGIN gen_timelines.py (generated skip-lists — do not edit) -->

**Per-scene skip census** (directives = toast/stage/`>> GATE` markup; conditionals = `{flag}`-guarded save-reactive variant lines, left to the Dialogic VAR-bridge wave; unparsed = other non-dialogue lines):

| scene | directives | conditionals | unparsed |
|---|---|---|---|
| mvp_s01_the_knack | 8 | 0 | 0 |
| mvp_s02_altar_hours | 6 | 0 | 0 |
| mvp_s03_the_mark | 8 | 0 | 0 |
| mvp_s04_registered | 3 | 0 | 0 |
| mvp_s05_greener_pastures_hungrier_ones | 8 | 2 | 0 |
| mvp_s06_the_mercy_garden | 8 | 0 | 0 |
| mvp_s07_what_the_glut_wont_bury | 6 | 0 | 0 |
| mvp_s08_the_guardian_at_the_seal | 8 | 2 | 0 |
| acts_s01_the_sworn_rite | 13 | 0 | 0 |
| acts_s02_the_line_you_cant_uncross | 7 | 0 | 0 |
| acts_s03_first_light | 2 | 0 | 0 |
| acts_s04_first_blood_on_the_thrones | 2 | 0 | 0 |
| acts_s05_the_throne_turned | 5 | 1 | 0 |
| acts_s06_holes_in_the_sky | 2 | 2 | 0 |
| acts_s07_the_pure_poles | 3 | 4 | 0 |
| acts_s08_the_empty_seat | 3 | 0 | 3 |
| acts_s09_petrification | 4 | 1 | 0 |
| acts_s10_the_walls_choice_the_graveyard | 5 | 0 | 0 |

**Unmapped speakers (auto title-cased .dch stubs):** (none)

<!-- END gen_timelines.py -->

---

# Boss Kits & Regional Casts Ingest (Batch E1c)

`tools/ingest_bosses.py` and `tools/ingest_casts.py` emit `client/catalog/boss_kits.json`,
`client/catalog/region_bosses.json` (the `{region_id: boss_id}` act-boss seam the integrator
reconciles with E1b's region_pools boss slot) and `client/catalog/npc_casts.json`. Every mapping
decision (species force-proxies, authored-move -> library-skill mappings, CombatBrain role
derivations, region boss assignments, cast counts) is recorded in the GENERATED companion notes:
`docs/content/_INGEST_NOTES_E1C.md` + `docs/content/_INGEST_NOTES_E1C_CASTS.md`.

**Cast timeline convention:** npc_casts.json references per-NPC scenes as
`<npc_snake_case>_<beat>` (beat `intro`) — the E1a generated timelines above are SCENE-scoped
(`mvp_s<NN>_*` / `acts_s<NN>_*`), so no cast id collides with them; the overworld bubbles the
NPC's authored barks (VERBATIM) until a per-NPC `.dtl` with the convention id lands
(`DialogicFacade.timeline_exists` probes the [dialogic] directory). The integrator reconciles
when per-NPC scenes are generated.

---

# E2a — The Playable Arc (Acts 0-5 end to end)

`client/tests/story_arc_test.gd` is the arc's TRUTH: a headless scripted walk from new_run
through the Act-5 finale flag (`act5_q4_done` — Q5.4's on_complete; the ingest emits no
`succession_begins`, see decision 3 above). Everything below is what E2a added/changed to make
that walk close. Data stays generated where it was generated: quests.json/npc_casts.json are
untouched; the new edges live in the LOADER tables (QuestCatalog), the hand-authored overlay
(NpcCastCatalog.QUEST_STEP_CARRY), the hand-wired NPC_DEFS, and region_layouts.json (hand-
authored E1b world data).

## Gate-flag edges added/changed

1. **Region gate corrections (region_layouts.json — the two dead-locks):**
   - `astral_tier.gate_flag`: `act3_open` -> **`act1_q3_done`** — Q1.4's giver (the Concord
     archivist) stands in the Astral Tier; behind act3_open the Act-1 climax could never be
     reached (act2_open is SET by Q1.4 — a chicken-and-egg seal). Gate hint rewritten to match.
   - `sunder.gate_flag`: `act3_open` -> **`act2_q1_done`** — Q2.2's giver (the Unbound
     lab-heretic) works out of the Sunder; its doc Gate line ("unlocks the Sunder region
     access") reads as the quest-completion reward, but the giver must be reachable first.
     Conservative reading: the region opens the moment its quest does.
   - All other gates verified closed-chain: mournmarch/forgefell/titanfall =
     `registered_aspirant` (Act-0 climax), storm_vault/tideless = `act2_open`, maw_beneath =
     `act4_open`, hollow_atelier = `act5_open`.
2. **Boss-victory edges (QuestCatalog.VICTORY_FLAGS — deed-resolved quests):** the E1a ingest
   gave every quest one talk-shaped step; these four DEMAND felling a god per the doc, so their
   step completes on the region's `<id>_boss_victory` flag (set by
   GameController._mark_slice_cleared on a played boss win) instead of a talk. They AUTO-START
   the moment their act-chain trigger opens (the HUD tracker names the kill) via
   OverworldQuestsGlue.sync_catalog_quests, run on every overworld build:
   - `act1_the_guardian_at_the_node` -> **`titanfall_boss_victory`** (Q1.3: "track and defeat
     (or capture) the region's Legendary force-node guardian"; region titanfall).
   - `act3_first_blood_on_the_thrones` -> **`sunder_boss_victory`** (Q3.1: "defeat a chosen
     Olympian" — Bakchanyr the Revel-Lord is the canon Order-kills-a-Chaos-god execution
     (doc: Ares/Dionysus/Hermes); sunder is open by then via the act2_q1_done gate).
   - `act4_the_pure_poles` -> **`maw_beneath_boss_victory`** (Q4.1: the Primordial trial — no
     pr_* kit is a region boss; the Maw's descent is the poles'/Unmaking trailhead and
     gg_devourer its god; maw opens on act4_open, exactly Q4.1's trigger).
   - `act5_the_first_invader` -> **`hollow_atelier_boss_victory`** (Q5.2: the async-invasion
     defense — the Atelier is the succession's workshop and gg_architect its wall-fight
     stand-in; opens on act5_open, exactly the act's gate).
3. **Witness edges (VICTORY_FLAGS value "")**: `act5_the_walls_choice` (giver "the moment
   itself") and `act5_a_graveyard_of_winners` (giver "the game itself") have no diegetic giver
   — they self-start AND self-resolve through the same sync the moment their chain trigger
   lands (Q5.2's / Q5.3's done-flag). The finale flag `act5_q4_done` therefore lands without
   an NPC, as authored.
4. **Q4.4 -> Q5.1 same-talk cascade (accepted, by design):** both are given by Vael
   Construct-Nine and Q5.1's trigger (`act5_open`) is set by Q4.4's completion, so one talk
   resolves the Choice AND the petrification rite — authored-adjacent beats (the notarization
   flows into the snapshot). No other giver carries chain-adjacent quests (verified pairwise).

## Giver placement (warn-list reconciliation — every substitution)

Hand-wired NPC_DEFS (verdant/starting region — the catalog cast never spawns there):
- Q1.1 Mother Sylva Greenrot -> **Matron Sevvy** (the hand-wired Bloomwarden Greenmother).
- Q2.4/Q3.3/Q4.4/Q5.1 Vael Construct-Nine -> **Vael Construct-Nine** (hand-wired, verbatim).
- Q3.4 Madam Thessaly Vance -> **Madam Thessaly Vance** (hand-wired, verbatim).

Catalog casts (NpcCastCatalog.QUEST_STEP_CARRY — merged onto npc_casts.json defs at load):
- Q1.2 Foreman Castor Brail -> **Foundress Magna Ironwright** (Iron Guild leader, forgefell).
- Q1.4 Archivist Pellos Vane -> **Archon Velleth Sun-Notary** (Concord leader, astral_tier).
- Q2.1 Lord Severin Ash -> **The Pale Steward, Wessel Graf von Underhart** (mournmarch).
- Q2.2 Doctor Vesh Quillon -> **The Unmaker, She-Who-Is-Called Nael** (Unbound leader, sunder).
- Q2.3 Kestrel Dane -> **The Chairwoman, Indra Vael** (storm_vault) — the rival's marker is
  High Table business and the "wanderers" cast never spawns (not a region id).
- Q3.2 "a surviving Olympian (e.g. Hephaestion)" -> **The Last Automaton, Unit Called
  "Patience"** (forgefell) — the forge-god's own surviving construct speaks the patron offer.
- Q4.2 "Concord's Aurelian Vox" -> **Archon Velleth Sun-Notary** (Vox re-roles under Velleth
  per _NAME_RECONCILIATION.md).
- Q4.3 "everyone" -> **The Chairwoman, Indra Vael** (the Table brokers the convergence; she
  already holds the rival thread from Q2.3).
- Boss/witness quests (Q1.3/Q3.1/Q4.1/Q5.2/Q5.3/Q5.4) carry NO NPC step — their givers
  (Huntmaster Bram Stoneblood, Magister Aurelian Vox, the Primordials, the new nobody, the
  moment/game itself) resolve as the DEED itself (decision 2/3 above); the quest self-starts
  and the HUD names the objective.

## Timeline hookup (QuestCatalog.QUEST_SCENES)

Quests whose authored scene shipped as a generated .dtl play it on advance (the def's
`timeline` field; DialogicFacade.timeline_exists probes first; steps without scenes keep the
toast): Q1.1 -> mvp_s05, Q2.1 -> acts_s01, Q2.2 -> acts_s02, Q2.4 -> acts_s03, Q3.1 ->
acts_s04, Q3.3 -> acts_s05, Q3.4 -> acts_s06, Q4.1 -> acts_s07, Q4.4 -> acts_s08, Q5.1 ->
acts_s09, Q5.3 -> acts_s10 (the combined walls-choice/graveyard scene — mapped to Q5.3 only so
it never replays for Q5.4). Act 0 keeps its hand-wired NPC scenes; mvp_s06/s07/s08 are the
side-quest/boss beats whose quests already play hand-wired scenes.

## story_arc_test.gd combat shortcuts (documented per the test contract)

The headless walk force-sets ONLY the four real boss-victory flags where a fight would be
required — `titanfall_boss_victory`, `sunder_boss_victory`, `maw_beneath_boss_victory`,
`hollow_atelier_boss_victory` — then drives the same sync the post-battle build runs. Every
other flag in the walk is earned through the real speak_to / choice / travel wiring.
