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
