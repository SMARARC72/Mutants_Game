# RED-TEAM CORRECTIONS (BINDING — applied over the synthesis below)

Adopted 2026-07-01 after adversarial feasibility + owner-impact review. Where a correction contradicts the plan body, the correction wins.

**Corrected CORE order (this session):** W0 → W1 → W2(hygiene) → W3(+boss-goal quest, +encounter-test updates) → W4 → W5 → W6(+PhantomCamera damping fix) → W6.5 NEW: Overworld Terrain Thin Slice (tiles/wall/props promoted + per-force PALETTES — pulled from W12) → W8 Battle Beat Queue (PROMOTED to CORE) → W-SND NEW: minimal Sound Exists slice (pulled from W14) → W7 keystone (stretch, with corrections 1-4).

## C1
**Issue:** Wave 7 task 1 ('Run tools/catalog_batch.py over art/batch4 + art/batch5 to fill the 219 empty art_ref rows') will corrupt the registry, not fill it. The 219 rows ALREADY EXIST in docs/creature_registry.csv (ids batch4-001..100 / batch5-001..119) with authored names (Aurelet, Lumbkin, ...) and status 'reviewed' — only art_ref is empty. catalog_batch.py's append_registry() (tools/catalog_batch.py:83-104) dedupes solely on art_ref and only APPENDS new rows with regenerated ids, so rerunning it appends 219 nameless duplicate-id rows (407 -> 626). The QA montages for these batches also already exist (art/montage_batch4_p1..p5, montage_batch5_p1..p5).

**Correction:** Replace the task with a small fill-in-place script: re-derive the identical file order via the same sorted(glob) used by list_images() (tools/catalog_batch.py:39-41 — this is the order the rows were originally appended in, so it reproduces the original 1:1 correspondence) and zip it against the existing batch4/batch5 rows in registry file order, writing only the art_ref column. Run the owner eyeball gate against the montage sheets that already exist — no montage regeneration needed.

## C2
**Issue:** Wave 7's slice_montage.py is an art-quality trap for ~90 of the ~110 montage-cell refs: full-resolution originals exist on disk. SB#N refs (30 rows) have 33 original ~1086x1448 plates in art/storybook/; montage_set2_A/B refs (60 rows) have exactly 60 originals in art/set2/. Cutting thumbnail-fitted cells from contact_sheet_storybook.png (1856x2012 -> ~300px cells) and montage_set2_A/B (1602x1456 -> ~260px cells) then 'promoting' to 512px plates means upscaling already-downscaled thumbnails for the keystone wave's hero art. Only adult#1-10 and demon#1-10 appear to be montage-only (montage_A_4-18 at 2360x1516 gives ~470px cells — marginal).

**Correction:** Rewrite the task: map SB# and set2 refs to their full-res originals in art/storybook and art/set2 (establish the file<->cell correspondence once, under the same 10-minute eyeball gate), and reserve montage-cell cutting for the genuinely montage-only adult#/demon# refs. This changes slice_montage.py from 'cut 110 cells' to 'cut ~20 cells + build two origin-file mappings'.

## C3
**Issue:** Alpha knockout: interior-white protection IS structurally handled — 4-corner floodfill only removes corner-connected pixels, so enclosed white highlights inside creatures are safe by construction. But empirical testing on actual batch4/batch5 plates shows the real failure mode is the OPPOSITE: PIL ImageDraw.floodfill's thresh is measured against the SEED pixel (corners at RGB ~251-253) while the painterly background dips to ~222 at the borders, so tol 18 strands 3-5% of pixels as un-removed near-white background blotches/halos (fill removed only 66-73% of mostly-background 1086x1448 portrait plates). The 'validated locally: tol 18' claim does not hold across batch4-style plates, and the ~20% reject budget will be blown by systematic haloing rather than occasional wisp-chewing.

**Correction:** promote_creatures.py must threshold against a per-image background statistic (e.g., distance to the border-ring median color, or remove all near-white connected components touching the image border), not a single seed-relative tol-18 fill. Keep the erode+feather stage. Re-validate on a batch4 QA contact sheet before committing to the 20% reject budget; expect batch5 (cleaner backgrounds, border_min ~240) to behave better than batch4.

## C4
**Issue:** rembg fallback is not usable as written: `import rembg` fails on this machine (not installed), and installing it pulls onnxruntime plus a ~170MB U2Net model download on first run — directly contradicting the risk register's own line 'no new pip deps on the mainline (PIL+numpy present)'. A Wave 7 session that hits a flagged reject cannot just 'fall back to rembg'.

**Correction:** Either add an explicit one-time setup task (pip install rembg onnxruntime + model prefetch, network required) budgeted before Wave 7, or demote rembg below Photoroom MCP (already connected) as the reject path. Do not leave it as an assumed-available fallback.

## C5
**Issue:** Wave 2 devcap CI screenshots cannot come from `--headless`: .github/workflows/ci.yml runs Godot with --headless (dummy RenderingServer), where viewport captures return blank images — the job as specified uploads black PNGs as 'proof' artifacts. Compounding: project.godot is Forward Plus (Vulkan), which GPU-less ubuntu runners can't run natively.

**Correction:** Run the devcap job under xvfb-run with an explicit rendering fallback (--rendering-driver opengl3 / gl_compatibility, or lavapipe Vulkan) — i.e., windowed-but-virtual, not --headless — or redefine the artifact as a locally-captured pre-push screenshot committed to the PR. The 'screenshot artifact proving it' definition-of-shipped depends on this being fixed first.

## C6
**Issue:** Wave 9's GdUnit acceptance ('same seed -> identical image hash' via SubViewport bake_texture) is vacuous under the test harness: the 58-suite run uses --headless --ignoreHeadlessMode (ci.yml:170), where SubViewports render nothing, so image hashes are trivially equal empty/black images. The test would go green while proving nothing.

**Correction:** Assert determinism on sigil_gen.gd's stroke GEOMETRY (the seeded polar stroke/arc/node arrays) — same seed => identical arrays, unique across 20 seeds — and reserve any pixel-hash comparison for the non-headless devcap path.

## C7
**Issue:** Wave 3's encounter retune breaks client/tests/encounter_director_test.gd and the plan never schedules the test edit. The test asserts hits > 0 over 40 fixed-seed steps with a comment explicitly calibrated to ENCOUNTER_CHANCE ~0.22 (test line ~51); at 0.09 the fixed canonical stream can deterministically yield zero. Wave 13 then changes roll_step's signature (adds tile_class) and folds tile_class into the purpose hash, altering the canonical sequence the test replays.

**Correction:** This is legal (application layer, not domain/goldens) but the plan's '58 suites stay green' framing must add explicit tasks: update encounter_director_test expectations in the same W3 PR (or lengthen the walk so hits>0 holds at 0.09), and in W13 keep tile_class as a defaulted parameter so existing callers/tests compile, updating the determinism assertions for the new purpose hash.

## C8
**Issue:** Wave 6 PhantomCamera API detail: `follow_damping` is a bool property; the amount lives in `follow_damping_value: Vector2` (phantom_camera_2d.gd:276-286, default 0.1,0.1). The plan's 'SIMPLE with follow_damping ~0.2' via the existing pcam.set() pattern would assign 0.2 to a bool. (FollowMode.SIMPLE = 2 is confirmed correct; current code sets follow_mode 1 = GLUED.)

**Correction:** Set both: pcam.set("follow_mode", 2), pcam.set("follow_damping", true), pcam.set("follow_damping_value", Vector2(0.2, 0.2)).

## C9
**Issue:** Wave sizing: Wave 10 PR-2 is a week masquerading as half an 'L' — it bundles a new JuiceDirector autoload, three dead-shader wirings (hit_flash/dissolve/outline), lunge/recoil tweens, damage-scaled shake, hitstop with ignore-timescale timers, arcing damage numbers, grayscale-safe force matchup badges, a ported+credited grade shader replacing three set_pixel loops, a new EMBER palette semantic, an entropy dial driving vignette/shake/number scale, boss name-splash + HP bar, ButtonJuice micro-scale, and encounter zoom-punch — each with reduce_motion gating and headless no-op modes, all suites green. Similarly, 'Waves 0-6 land in one session' spans ~25 discrete tasks across 7 suites-green PRs each requiring dual-resolution screenshot acceptance.

**Correction:** Split W10 PR-2 into at least three PRs (JuiceDirector + hit/dissolve/outline wiring; grade shader + entropy dial + palette; badges + boss splash + button/encounter juice) and re-baseline capacity: Waves 0-5 is the realistic single-session core, with W6 the first stretch and W7 session 2's opener.

## C10
**Issue:** CORE does not transform the overworld screenshot — the owner's #1 named failure. After Waves 0-7 the overworld field is still ONE moss texture with tint-hacked walls, a procedurally-drawn brass-disc avatar, flat-ring NPCs, no props, no parallax, no light (audit OVERWORLD P0s, VISUAL-CAPTURE P0). W6 fixes only the FELT half (tweens/camera); W12 — 'the visual half of the named overworld failure' by the plan's own words — is EXTENDED, i.e. session 2+. Worse, W0's zoom 1.5→2.35 magnifies the single-texture placeholder read. A CORE-end overworld screenshot would look nearly identical to today's, and the owner's verdict on that axis would not change.

**Correction:** Pull a thin W12 slice into CORE (as a new small wave after W6, ahead of or instead of the W7 stretch): run make_tiles.py over the 28 unpromoted topdown plates + TILE-039_wallcliff as a distinct wall asset + the 10 RGBA props scattered on feature cells, and add the per-force PALETTES entries. This is a PIL script + data-table change (no scene extraction, no autotiling, no lighting needed yet) and it is the single highest-leverage screenshot delta available this session. Defer W12's remaining scope (RegionTiles.tscn extraction, y-sort, parallax, animated avatar, normal maps) to session 2 as planned.

## C11
**Issue:** Battle will not 'feel electric' at CORE end — the owner's second named failure gets zero felt payoff this session. CORE battle after W0-W7: unclipped buttons, fonts, honest banners, real creature plates on the same 88px card lists — but still the audit's P0s: whole enemy turns resolving in ONE frame (W8), no stage/lunge/flash/shake (W10), total silence (W14). Every battle-feel wave is EXTENDED, so the 'plays terribly' verdict on combat survives the session intact.

**Correction:** Promote Wave 8 (async beat queue) from first-EXTENDED into CORE, ahead of the W7 stretch. It is pure presentation, self-contained in battle_screen.gd, needs no assets, and the controller already yields per-action RESOLVED steps for exactly this — while W7 is explicitly allowed to slip to session 2. One readable beat-per-action turn is the minimum bar for 'battle stopped resolving in a single frame' and is a bigger verdict-mover than lab recursion polish. If capacity forbids both, state explicitly in the plan that CORE will NOT answer the battle-feel verdict, so the owner isn't surprised.

## C12
**Issue:** Sound at Wave 14 is mis-sequenced relative to its cost/impact. The audit calls silence 'the largest invisible cause of plays terribly' (BATTLE P0, ART P1, VISUAL-CAPTURE P1) and the plan's own W14 goal line agrees — yet W14 sits behind W9 sigils, W10 stage, W11 capture, W12 terrain, W13 atmosphere, i.e. session 3 territory. Audio has no dependency on any of those: footsteps hook W6's step tween (CORE), UI clicks hook the theme, and beds are CC0 downloads + a two-player autoload.

**Correction:** Split a minimal 'Sound Exists' slice (UI click/confirm, footsteps per tile, one overworld ambience bed, one battle drone, hit/death stingers, sliders wired to AudioServer buses) and schedule it immediately after W8 at the latest — ideally as a CORE S-wave since it also closes the Options 'dead switches' P0 remnant. Leave the adaptive/entropy-crossfade layer and full stinger set in W14.

## C13
**Issue:** First-5-minutes goal communication is not covered in CORE. The 'early quest def naming the boss goal' and the persistent controls chip both live in W17 (session 3). In CORE, W3 makes the boss winnable but nothing tells the player a boss exists or what the run is FOR; the shipped quest tracker shows only marsh_welcome/side-quest lines. The owner's question 'would first-5-minutes communicate a goal?' answers NO for this session.

**Correction:** Move the boss-goal quest def ('something old guards the deep glut') into Wave 3 — it belongs with the wave that makes the boss reachable and one-shot, and it's a pure data add through the already-shipped Phase-13c tracker. Move the collapsible controls chip into Wave 1's focus pass (it is input-truth surface). Leave rebinding and the full router in W17.

## C14
**Issue:** CONTENT P0 'Main story: 0 of 24 wired — no narrative spine' is covered by NO wave. The out-of-scope veto ('batch ingestion of 24 main quests') addresses the batch-tooling approach, but the audit's named fix — wire Act 0 (Quests 0.1-0.4, the Capture-unlock gate, Maddox's canon beat) via the proven 73-line SQ-06 data pattern — appears nowhere in Waves 0-19. Related: the CONTENT P0 'no batch-ingest tooling' is only partially answered (W16 ships ingest_voice.py; quests.json/npcs.json/boss_kits.json emitters are silently dropped rather than explicitly deferred).

**Correction:** Add Act-0 wiring (4 quests, pure data, scripts_mvp.md Scenes 1-4 riding W16's Dialogic choice support) to Wave 16 or 17 — it is not batch ingestion and the veto does not cover it. Separately, amend the OUT OF SCOPE list to explicitly name 'main-story Acts 1-5 and content batch-ingest tooling beyond voice' so those two P0s are visibly deferred by decision, not lost.

## C15
**Issue:** OSS P0 'Beehave is vendored-dead' is only half-addressed. The audit demands wire-it-or-remove-it (plus fixing THIRD_PARTY.md's false 'battle AI + overworld NPC behavior' claim). The plan's only touch is W6 stripping Beehave debuggers from release exports via feature guards — the two debug autoloads stay registered, the addon stays dead through W19, THIRD_PARTY.md stays wrong, and no wave ever gives the overworld ambient life (the audit's OVERWORLD P1 'flat colored rings / no world life' — named characters like Matron Sevvy remain identical circles even after W16 gives them Dialogic portraits in dialogue boxes only).

**Correction:** Add to Wave 2 (hygiene): remove the BeehaveGlobalMetrics/Debugger autoloads and correct THIRD_PARTY.md to match reality. Then either add 2-3 Beehave ambient critters + NPC idle-wander/face-player trees to Wave 13 (its natural home next to the follower work — determinism-exempt per THIRD_PARTY.md:201-206), and give overworld NPC tokens the same circular plate-cameo treatment the lead uses (cheap after W7 cutouts, slot into W12 or W13) — or explicitly de-vendor Beehave in the out-of-scope list. The current middle state reproduces exactly the 'vendored, autoloaded, never exercised' pattern the owner called out.

## C16
**Issue:** Minor honesty gaps in the plan's own framing: (a) 'Capacity honesty' promises Waves 0-6 + W7 stretch but never states the consequence — that BOTH named failures' visual payoffs (battle W8/W10, overworld W12/W13) land in later sessions, so the owner should expect a foundations-plus-lab-plus-fonts session, not a transformed game; (b) two audit P1 systems (9-god morality movement / CharacterEngine.apply_event, and the drachma/shop economy) appear in no wave AND no out-of-scope line — silently dropped rather than deferred.

**Correction:** (a) Add one sentence to Capacity honesty stating which owner-verdict axes CORE does and does not move (or rebalance per corrections 1-2). (b) Add 'morality-event wiring (apply_event) and shop/drachma economy' to the EXPLICITLY OUT OF SCOPE list, or slot the audit's minimal shop (one camp Shop entry, 2-3 items — it also unblocks the W17 gear-honesty and capture-gear findings) into Wave 17.


---

# MUTANTS — Master Realization Plan (Council Synthesis)

**Mandate:** The owner's verdict — "plays terribly, not even good 2.5D, overworld is terrible quality, open-source tools not effectively used, design has drift" — is answered by ordered, PR-sized waves. The two named failures (overworld quality, battle feel) drive the ordering; the foundations they depend on come first because every persona's plan collapses without them.

**Inviolables (all waves):**
- `client/domain/` and the Python oracle are untouchable except via the constants+golden pipeline. Every move below is presentation/application-layer wiring. All presentation randomness (sigils, barks, voice variant picks) uses a LOCAL `RandomNumberGenerator` — never the canonical PCG32 streams.
- The full headless GdUnit suite (58 suites, ~70s) stays green on Godot 4.7 local for every PR. Any animated system ships an **instant/drain headless mode** in the same PR.
- **Definition of shipped, per wave:** (a) a feel test a player can state, (b) a devcap screenshot artifact proving it, (c) full suite green. No wave merges without all three.
- Every downloaded asset (fonts, textures, audio, ported shaders) lands with license file + PROVENANCE.md entry, binaries via Git LFS.

**Capacity honesty:** ~70s suite runs plus PR cycles mean one autonomous session realistically lands Waves 0–6 with confidence; Wave 7 (the art keystone) is the CORE stretch goal — if PR cycles run long it becomes the opening wave of session 2. Everything after is EXTENDED, sequenced for subsequent sessions.

---

## TENSION RESOLUTIONS (binding)

1. **Fonts (Dracula: IM Fell vs Art Director: Cinzel).** RESOLVED: **Cinzel** (display, engraved-occult, better legibility at title sizes) + **Alegreya** (body — unanimous). Exactly two OFL faces bound in `grimoire_theme.gd` (Dracula's two-face veto holds). IM Fell is the swap candidate if the owner wants more ink-bleed; it is a one-line change later.
2. **Alpha-knockout tool (Digimon-maker: rembg vs Art Director: PIL).** RESOLVED: **PIL corner-floodfill mainline** (validated locally: tol 18 + MinFilter erode + 1px feather, ~6s/plate, zero new deps). rembg is per-plate fallback for flagged rejects only (with `PYTHONUTF8=1`); Photoroom MCP last resort. Budget ~20% hand-flagged rejects (Producer's risk); the flat plate variant is retained for codex/parchment surfaces.
3. **Keystone scope (Digimon-maker: all 407 vs Producer veto: slice only).** RESOLVED: the **pipeline is built for 407**, but promotion **executes slice-scoped (~30 Verdant species + starters + DM06)** in Wave 7. Full 407 promotion is Wave 19, after the import-policy CI gate has proven itself on the slice. Digimon-maker's veto stands in both: `SpeciesArt` MANIFEST is pipeline output (`manifest.json`), never hand-grown const entries.
4. **Skeleton2D rigging (four pillars veto mass rigging).** RESOLVED: **zero rigging this pass.** LivingPlate (shader sway + breath) is the aliveness standard. At most 3 hero rigs in a future session, only after the owner judges LivingPlate insufficient AND one rig measures ≤2ms on the Iris Xe machine (Physicist's gate).
5. **AP HUD (design-bar audit asks for it; HAWKING/Tech Lead/Producer veto).** RESOLVED: the veto wins — the surface never advertises unbuilt mechanics. Wave 3 **deletes the lying "(N AP)" label**. No AP chip bar until an oracle-first AP pool ships as its own future engine phase (out of scope this pass).
6. **Battle juice before pacing (Wick/Physicist/Tech Lead veto).** ENFORCED by ordering: no battle-visual work merges before Wave 8's async beat queue. Waves 10–11 hang on it.
7. **God-script decomposition (Tech Lead: wholesale L vs Producer: veto standalone refactor).** RESOLVED: **incremental extraction only** — each visual wave extracts exactly the child scenes it touches (`BattleStage.tscn` in W10, `RegionTiles.tscn`/`PlayerToken.tscn` in W12, `DialogueLayer.tscn` in W16), public APIs (`build_from_game`, `run_pending_battle`) kept stable so the 58 suites never break. No standalone refactor PR.
8. **Encounter cadence (Alice: don't sterilize vs first-session: retune now).** RESOLVED: Wave 3 ships an **explicitly-interim** flat retune (0.22→~0.09 + 5-step grace) so the treadmill dies today; Wave 13 **replaces** it with thin-place gating (~0.30 on veil tiles / ~0.04 elsewhere) + misbehavior, and Wave 16 adds peculiars. The world keeps its teeth; the risk becomes visible and chosen.
9. **Fullscreen shaders (Dracula: AtmosphereLayer vs Physicist: ≤2 passes vs HAWKING: never over HUD).** RESOLVED: exactly ONE combined grade+vignette pass + ONE fog pass, both owned by `AtmosphereLayer` (Dracula's API). The Physicist's `grimoire_grade.gdshader` (shipped in W10) IS AtmosphereLayer's grade ColorRect. It renders above world / **below HUD**, never past readable text contrast, and all shake/hitstop gates on `accessibility.reduce_motion`. The three 65k `set_pixel` vignette loops are deleted, never multiplied.
10. **Ceremony duration (Wick's never-wait-twice).** BINDING everywhere: every reveal/transition >0.4s honors held-CONFIRM fast-forward or seen-once skip in the same PR; `Transition MIN_COVER_TIME` stays ≤0.3s; hold-to-commit rituals (player-driven) are exempt. No flourish steals input focus on decision surfaces.
11. **Microcopy (Alice + Dracula converge).** All player-facing strings route through **VoiceBook** ingested verbatim from `docs/content/voice_library*.md`. Wave 3 ships one interim authored stalemate line; Wave 16's full ingest replaces call sites without code changes. No hand-written quips in screen code; fourth-wall material only via the rationed one-shot registry, never in boss/death flows.
12. **Duplicate claims — single owners assigned:** SVG background strip → Art Director script (W4, HAWKING consumes in W17). Capture %/wobble/card/tutorial → consolidated into W11. Entropy-math dedupe (`session.entropy()`) → W3. Sigil renderer → one implementation (W9, `sigil_gen.gd`), consumed by capture/lab/dossier. Follower cameo → W13 (needs W6 tween + W7 cutouts). Save trust → W18 (interim soft-lock patch in W0).
13. **Universally vetoed, not in any wave:** Supabase/cloud saves (ADR amendment + CI paths filter in W2); 3D / TripoSR / TRELLIS merges; batch ingestion of 24 quests / pantheon kits; plate regeneration or style transfer (the 412 painterly plates ARE the product); pixel-art CC0 terrain packs as terrain base; new runtime `set_pixel` synthesis; new hard-coded hexes (everything through `GrimoirePalette`); mouse-only interactions; per-screen ad-hoc juice (everything through JuiceDirector).

---

# CORE WAVES (this session)

## Wave 0 — Coordinate Space & Un-clip (S/M) — THE FIRST PR
**Goal:** Define the coordinate space every other wave is authored in; make every primary verb reachable.
**Tasks:**
- `client/project.godot`: add `[display]` before `[rendering]` (~line 90): `window/size/viewport_width=1920`, `viewport_height=1080`, `window/stretch/mode="canvas_items"`, `window/stretch/aspect="expand"`, `window/size/window_width_override=1600`/`height_override=900` (dev laptop).
- `overworld_screen.gd:31` `CAMERA_ZOOM 1.5→~2.35`; set `PhantomCamera2D` `limit_left/right/top/bottom` to the layout rect (:695-722) — kills the void band.
- `main_menu.gd:40,45`: derive emitter position/extents from `get_viewport_rect().size` (not 576/700).
- Interim overflow: wrap `battle_screen.gd` `_root_box` and `lab_screen.gd` picker stack in `ScrollContainer`; move action rows (Flee/Capture; Divine/Splice/Back) into bottom-anchored `PanelContainer`s; cap transcript min-height (`battle_screen.gd:429`) to a viewport fraction.
- `options_menu.gd:139`: rename `_get` → `_setting_value` (parse-error black screen); add Back button + CANCEL handling.
- `camp_menu.gd resume()`: detect standalone root-scene mode → swap to the declared `OVERWORLD_SCENE` (interim soft-lock patch; real router in W17).
**Acceptance:** Screenshots at 1920x1080 AND 1280x720 show Flee, Capture, Splice fully on-screen and clickable; Options opens themed with a working Back; no raw void at overworld edges; camp→Party→back→Resume never black-screens. Suite green.

## Wave 1 — Input Truth (S)
**Goal:** Every discrete press fires exactly once; the whole game is playable without a mouse.
**Tasks:**
- `client/infrastructure/input/input_service.gd:49-53`: replace `is_triggered() and not is_ongoing()` — subscribe each GUIDEAction's `just_triggered` signal (`addons/guide/guide_action.gd:158`) into a per-action frame-stamp dict; `just_pressed()` returns `stamp == Engine.get_process_frames()`.
- Add `GUIDEInputJoyAxis2D` left-stick mappings in `_inputs_for` (:184-200).
- Focus pass: `grab_focus()` on first Button of `main_menu`, `camp_menu`, `party_screen` roster, `lab_screen`, `options_menu`, and `battle_screen._show_action_menu` every turn; wrap-around `focus_neighbor` chains; wire the bound-but-dead battle context (`input_actions.gd:35-38` NAV/CONFIRM/CANCEL/CYCLE_TARGET) to focus + activation.
- Tests: `client/tests/input_service_edge_test.gd` (two held frames → just_pressed exactly once); headless arrow-key traversal of the party roster; **boot-smoke test** instantiating every `.tscn` under `client/presentation` asserting the script compiled (would have caught the Options crash).
**Acceptance:** Hold E through NPC dialogue — plays once, no re-fire; hold Enter at battle end — banner stays until a fresh press; the full loop (menu→overworld→battle→capture→camp→resume) completes keyboard-only AND gamepad-only, brass focus ring visible in screenshots.

## Wave 2 — Enforcement Bar & Asset Policy (S)
**Goal:** "Functional-but-bland" can never ship invisibly green again; the art keystone can't poison VRAM.
**Tasks:**
- Track the untracked `client/devcap` harness; CI job boots headless and uploads overworld/battle/menu/lab/party screenshots at 1920x1080 + 1280x720 as PR artifacts.
- **Texture import ADR:** creature plates ≤512px RGBA, VRAM-compressed (BC7) + mipmaps ON; lossless reserved for UI glyphs. Ship the import preset + `tools/check_asset_contract.py` wired into `ci.yml` (fails PRs on oversize/wrong-import assets). This MUST precede Wave 7.
- Overflow assertion test: walk each screen's tree, fail if any primary Button's `get_global_rect()` lies outside the viewport.
- Hygiene: commit the 34 untracked `.uid` files; fix the `.gitattributes`/`core.autocrlf` mismatch (435 phantom-modified `.import` files); verify LFS patterns cover `client/assets/creatures/*.png`, tiles, audio.
- ADR amendment de-scoping Supabase this pass + `ci.yml` paths filter so the DB job runs only on `supabase/**` (reclaims PR cycle time).
**Acceptance:** A PR that clips a primary button, breaks a screen script, or lands an oversize asset fails CI with a screenshot artifact showing why; `git status` clean after checkout.

## Wave 3 — Loop Truth (M)
**Goal:** The run is winnable, walking isn't futile, and the HUD stops lying — zero art required.
**Tasks:**
- Persist `run.world_state["player_cell"]` + facing in the pre-battle autosaves (`overworld_screen.gd:254-256, :277-278`); restore in `_spawn_player` (:638-651) when present+walkable. Cell round-trip save/load test.
- Encounter interim retune (explicitly interim, superseded by W13): `ENCOUNTER_CHANCE 0.22→~0.09` + 5-step post-battle grace window in `world_state`; one roll per dash.
- Boss wiring: `battle_screen.run_pending_battle` reads `pending.is_boss`; `_finish_battle` emits `boss_win = player_won && enemies wiped` so `GameController._mark_slice_cleared` fires; boss becomes a one-shot lair trigger in `encounter_director.gd`, not an every-step ambush. Played-path GdUnit test asserting `slice_cleared()`.
- Honesty: branch turn-cap-with-enemies-alive into a distinct **"THE WILD SLINKS AWAY — stalemate"** banner (`battle_screen.gd:331-338`, verbatim voice_library line, reduced-reward copy); **delete the "(%d AP)" suffix** (:728); read `session.entropy()` (:700, via `skill_battle_controller.gd:287`) instead of local math.
- Consequence: write live HP back to `run.party` at battle end; defeat costs ~25% essence.
- Wire expression/gene_bonus into `SkillMonFactory`/`MonFactory` via `LevelEngine.current_stats` (application-layer composition; domain untouched) — awakenings become felt.
- `REGION_TITLE` data-driven from the active region id (:35-36) — the HUD says "The Verdant Glut", not "The Rust Marsh".
**Acceptance:** After any battle you stand exactly where the fight started; the region is explorable between fights; beating the boss actually ends the slice; no player ever again sees VICTORY over an undamaged enemy; the HUD names the region the systems actually run.

## Wave 4 — Grimoire Skin (M)
**Goal:** Kill the engine-demo read in one theme PR.
**Tasks:**
- Vendor **Cinzel** + **Alegreya** (SIL OFL, Google Fonts) into `client/assets/fonts/` with OFL.txt + PROVENANCE. In `grimoire_theme.gd build()`: `theme.default_font = Alegreya`, TitleLabel variation = Cinzel-SemiBold (bump FONT_TITLE 30→34). Extend the theme GdUnit test: `default_font != null`. Zero screen files change.
- `tools/restyle_icons.py`: strip the baked `<path d="M0 0h512v512H0z"/>` from all 28 game-icons SVGs in `client/assets/icons/` so `PortraitUtil` modulate yields clean glyphs on transparency (unblocks every pillar's icon use). Promote ~40 styled icons + ~20 curated RGBA item plates from gitignored `/assets` via `docs/asset_registry.csv` into `client/assets/icons|items/` (LFS).
- Parchment: `client/assets/ui/parchment_tile.png` (CC0 — Screaming Brain Studios/Kenney, or procedural `tools/gen_ui_kit.py`; Kenney UI Pack RPG recolored to BRASS #b9933f as 9-patch fallback) + `StyleBoxTexture` type variations **ParchmentPanel/PlatePanel** in `grimoire_theme.gd` using the dead PARCHMENT constants; apply to party detail, lab verdict, journal pages.
- Palette drift: route `character_sheet.gd:182` (#aa60b0) through `GrimoirePalette.corruption_color`; fix `overworld_content.gd` Gruvbox greens. (Full hex sweep trails as follow-up S.)
**Acceptance:** Not one pixel of Open Sans in a full-loop capture — occult serif titles everywhere; force/status icons are clean brass-tinted glyphs with no black boxes; the party detail reads as an open parchment codex page against the ink world.

## Wave 5 — Lab & Hybrid Truth (M)
**Goal:** The splice payoff is real before it is beautiful — hybrids fight, costs bite, recursion works.
**Tasks:**
- `skill_mon_factory.gd:16-18` + `mon_factory.gd:22-24`: when `species_id==""` and `stats_cached.prim/tier` exist, build the Mon from the oracle numbers cached at commit.
- `creature_sheet.gd:26-32`: same `stats_cached` fallback — party shows real force/tier/HP.
- `lab_screen.gd commit()` (:197-207): after LEGAL, apply `run.corruption += creature.corruption`, debit essence, **consume the parents** from `run.party` (the hybrid replaces them).
- `lab_screen.gd _creature_tuple` (:258-274): build from `stats_cached` for hybrids — re-spliceable, restoring the "stronger, stranger, one-of-one" recursion.
- Hybrid portrait: dominant-parent `SpeciesArt.plate` with deterministic corruption-tinted modulate keyed off `lineage.rng_seed_tag` (no new art). VETO honored: never assign hybrids a fake catalog species_id.
- Seed 1 gene-vial + 2 organs in `GameController.new_run` via `InventoryAdapter` (real keys from `splice_rules.json ingredient_compat`) so Mutate is committable on a fresh run.
- Tests: extend `lab_screen_test.gd` + hybrid-battle test (committed hybrid → non-null Mon, non-zero HP, deals damage).
**Acceptance:** Commit a fusion: parents leave the roster, corruption ticks up, the newborn shows real forces/tier/HP with a distinct tinted portrait, deals damage in the next battle — and can itself be fused again. Mutate is committable on a brand-new run.

## Wave 6 — Motion & Camera Feel (M)
**Goal:** Walking stops being a teleporting tax; the felt half of "overworld is terrible" dies today.
**Tasks:** (all in `overworld_screen.gd`; presentation only — deterministic per-tile encounter rolls untouched)
- Replace the instant `_position_player()` in `try_move` (:209) with a 0.11–0.12s position tween (`TRANS_SINE/EASE_OUT` — GDQuest Open-RPG grid pattern per Vision §6). Replace the `STEP_COOLDOWN` wall-clock gate (:30, :370-376) with tween-chaining + input buffering (last direction pressed during the final ~40% of a step). Turn-in-place: a fresh tap only sets facing; held >80ms steps.
- Blocked moves: 0.06s 4–5px nudge tween toward the wall (SFX hook point). `sigil_dash` (:297-311): one continuous accelerated ~0.22s tween + 3 fading afterimage ghosts.
- PhantomCamera2D (:695-722): GLUED → SIMPLE with `follow_damping` ~0.2 + 12–24px look-ahead toward `_last_dir` (limits landed in W0).
- Spike diet (audit-measured): cache `OverworldTileSet.build()` (55.8ms per battle return) in a static dict keyed by force_climate; cache player/NPC/cameo ImageTextures; const-preload `camp_menu.tscn`; add `boot_splash` (brass sigil on ink — the 4.8s boot reads as loading); strip Beehave debuggers/LimboConsole/DevConsole from release exports via feature guards.
- `accessibility.reduce_motion` respected — its first real consumer.
**Acceptance:** Held-direction walking is a continuous glide with zero stutter; tapping a new direction pivots without stepping; walls visibly thunk; a dash is one whoosh; the camera eases behind you with a slight lead; battle entry/return shows no hitch; launch shows a sigil splash instantly.

## Wave 7 — Creature-Art Keystone, Verdant Slice (L) — CORE STRETCH
**Goal:** End the identical-sprout era for everything the player can actually meet. (If PR cycles run long, this opens session 2 — nothing after depends on it landing today except W9+.)
**Tasks:**
- Run `tools/catalog_batch.py` over `art/batch4` (100 files) + `art/batch5` (119) to fill the 219 empty `art_ref` rows in `docs/creature_registry.csv` (verified 1:1 sorted correspondence); emit labeled QA montages. **Gate: 10-minute owner/human eyeball pass over the montages** before promotion.
- New `tools/slice_montage.py` (PIL): cut the 110 montage-cell refs from `art/contact_sheet_storybook.png`, `montage_A_4-18`, `montage_B_19-33`, `montage_set2_A/B` (grid geometry already in catalog_batch.py).
- New `tools/promote_creatures.py`: per registry row — validated PIL knockout (4-corner floodfill thresh 18 → MinFilter(3) erode → 1px feather; rembg fallback for flagged plates, `PYTHONUTF8=1`) → 512px RGBA → `client/assets/creatures/<species_id>.png` via LFS + `manifest.json` + `gaps.json` + knockout QA sheets. Keep the flat plate variant for codex surfaces.
- Replace the hand-typed `SpeciesArt.MANIFEST` (`species_art.gd:14-20`) with a manifest.json loader, keeping `has_art()/plate()` API, adding `cutout()`.
- **Promotion scope this wave: ~30 species** — the Verdant wild pools (SB05/06/07/09/14/17/18/22/26/27/28/32/33, AD02/04/06/07/08/10), elite_pool, DM06 boss, starters. GdUnit: every slice id resolves to a unique file, none hits `_FALLBACK`; asset-contract CI green.
**Acceptance:** Three wild encounters show three DIFFERENT creatures, each a clean painterly cutout sitting directly on ink with no white rectangle; the boss has its own plate; party/lab/camp show the same real art.

---

# EXTENDED WAVES (subsequent sessions, in order)

## Wave 8 — Battle Time Axis (L)
**Goal:** Give combat a time axis — the prerequisite ALL battle juice hangs on.
**Tasks:** Convert `battle_screen.gd:138-147`'s synchronous `_pump` while-loop into an async step queue: collect RESOLVED steps, coroutine plays one beat per action (~0.45s: actor highlight → HP bar tween 0.35s TRANS_CUBIC replacing the direct assign at :543 → damage float → 0.15s settle), parsing the per-action log delta (`_append_delta`). Input latched during playback; held CONFIRM compresses beats to ~0.12s; persisted "Swift Rites" setting (x1/x2/instant). Transcript → `RichTextLabel.append_text` (:684-690), killing the O(n²) rebuild; the transcript is demoted to a collapsible drawer, **not deleted** (HAWKING veto). Ship instant/drain mode (no awaits headless / `JuiceDirector.instant`) so every suite driving `player_use_skill/last_step` stays green. Pure presentation — controller already yields one RESOLVED step per action for exactly this.
**Acceptance:** An enemy round plays as distinct readable beats — who acts, the hit, the HP glide — instead of stacked numbers in one frame; holding Confirm blasts through; nothing ever forces a full-speed replay twice. 58 suites green.

## Wave 9 — LivingPlate & Sigils (M)
**Goal:** Every creature breathes, everywhere; every creature bears a one-of-one mark.
**Tasks:** New `client/presentation/creature/living_plate.tscn+gd` (a real scene): RGBA cutout Sprite2D + cheap `creature_sway.gdshader` (1–2px UV-gradient vertex sway), sine breath scale (y 1.00→1.025), per-instance phase offset hashed from creature uid, elliptical drop shadow, material hooks for the three dead shaders. Swap in at battle cards (`battle_screen.gd:480-486`), party detail (`party_screen.gd:368`), lab pickers (`lab_screen.gd:533`), camp (`camp_menu.gd:118`). Cross-screen contract: no pillar ships static Sprite2D creature stamps that bypass LivingPlate. New `client/presentation/creature/sigil_gen.gd`: deterministic `_draw()` — FNV hash(species_id + instance uid) seeds a LOCAL RNG → 8–16 polar strokes/arcs/nodes in BRASS/BRASS_BRIGHT + force accent; `bake_texture(size)` via SubViewport; stamp at portrait corner (`portrait_util.gd`), roster rows, lab reveal, capture card (W11), dossier (W17). GdUnit: same seed → identical image hash; unique across 20 seeds.
**Acceptance:** Idle on the party screen: creatures visibly breathe and sway, two roster members out of phase; two same-species captures show different sigils; one creature's sigil is pixel-identical across screens.

## Wave 10 — Battle Stage & Impact (L, 2 PRs)
**Goal:** A screenshot reads instantly as "a monster battle"; every hit lands.
**PR-1 (stage):** Extract `BattleStage.tscn` (Node2D behind the HUD — the incremental decomposition slice): player LivingPlate bottom-left, enemy top-right at ~3x card size over an authored backdrop. Promote the 12 backdrop plates (`/assets/tiles/backdrop/TILE-061..072`) into `client/assets/backdrops/` (LFS) with battle (16:9 darkened) + parallax (blurred) PIL variants and `backdrops_manifest.json` keyed by force/biome — battle picks the arena by encounter region. Dock the action bar bottom.
**PR-2 (impact stack):** New autoload `client/autoload/juice.gd` (JuiceDirector): `hit/shake/hitstop/collision_flash/pop_number` — the single juice authority; headless no-op; `reduce_motion` gated. Wire the dead shaders: `hit_flash` flash_amount 1→0 (0.12s) on the struck plate; `dissolve` 0→1 (~0.8s) on death + drifting-parts **GPUParticles2D** (≤500 alive — no new CPUParticles per Physicist veto); `outline` on target-pick + acting-creature spotlight (scale 1.1). Attack lunge = position tween toward target + recoil (TRANS_CUBIC ~0.25s); damage-scaled shake; 60–90ms hitstop (Engine.time_scale dip, ignore-timescale timer) on kills/1.5x hits. Force-colored arcing damage numbers (TRANS_BACK scale-punch, size by damage fraction). Force legibility (HAWKING): matchup badges from `SkillEngine.force_mult` — "▲ OVERWHELMS" / "▼ resisted" (color + glyph, grayscale-safe) on target-picker and skill buttons, repeated in the damage float; two-color collision flash is additive, never the sole cue. Author `grimoire_grade.gdshader` (combined grade+vignette, adapted CC0 godotshaders, credited) replacing the three 65k `set_pixel` loops; add EMBER semantic to `grimoire_palette.gd`; radial entropy dial (draw_arc) heats parchment→ember per turn, driving vignette + shake amplitude + number scale from `session.entropy()`. Boss: `is_boss` → name splash + full-width HP bar. ButtonJuice hover/press micro-scale on themed buttons; encounter-trigger zoom-punch + sigil flash before the ritual wipe.
**Acceptance:** Two creatures face off at plate scale over a painterly biome arena; a mid-hit screenshot shows flash + offset frame + brass number mid-arc; a kill dissolves; turn-1 vs turn-8 is visibly burning; grayscale still distinguishes every matchup; steady 60fps on Iris Xe with juice on.

## Wave 11 — Capture Becomes a Moment (M)
**Goal:** The genre's most-repeated verb gets information and a heartbeat.
**Tasks:** Expose `chance_for(target)` on BattleSession (CaptureService already computes it; :483-487 caches post-roll) → live "Capture — 62%" on the button. On attempt, staged through the beat queue: brass sigil-circle (Line2D/draw_arc, GrimoirePalette.BRASS) closes around the enemy LivingPlate, 1–3 tension pulses scaled by |roll − chance| (near-misses wobble longest), dissolve-into-the-sigil on success / sigil-shatter + enemy lunge on break-free. Success ends on a **capture-result card**: plate large, name resolving letter-by-letter, its sigil stamping in, VoiceBook/toast microcopy. Skippable via held CONFIRM. Onboarding: Dialogic first-capture beat (Maddox, "mercy and math") on the first weakened wild, pointing at the shown %.
**Acceptance:** Odds visible before committing; a near-miss pulses three times and the player groans; a catch ends on a screenshot-worthy card of THEIR creature with name + sigil — not a toast line.

## Wave 12 — Overworld Terrain (L)
**Goal:** The world becomes a place — the visual half of the named overworld failure.
**Tasks:** `tools/make_tiles.py` (PIL): center-crop the 28 unpromoted `/assets/tiles/topdown` plates past the baked frame (~8%/edge), seamless-ify via offset-wrap (np.roll) + cross-fade mask, 512px → `client/assets/tiles/topdown/` (LFS); knock out the 10 prop tiles (TILE-051 boulder, 052 tree, 060 ward-stone…) to RGBA in `client/assets/tiles/props/`. Extend `overworld_tileset.gd` PALETTES with six real per-force entries (ground TILE-031..036, path TILE-038, **wall TILE-039_wallcliff** — a distinct ASSET, not a tint, per HAWKING's colorblind veto, ritual TILE-040). Extract `RegionTiles.tscn` + `PlayerToken.tscn` (incremental decomposition); `y_sort_enabled` + props layer so tall props occlude; `Parallax2D` horizon from the blurred backdrop variants. Interim 4-direction `AnimatedSprite2D` avatar (CC0 Kenney sheet recolored to palette) driven by W6's facing. Normal maps for THIS tileset only (`tools/gen_normalmaps.py`, PIL+numpy Sobel) + one PointLight2D player glow, inside the ≤3ms light budget.
**Acceptance:** Walls read as cliff rock, paths as worn dirt, no repeating seams; props occlude the avatar; a soft painterly horizon sits behind the tiles; a second force-climate renders visibly different ground; grayscale still separates wall from floor.

## Wave 13 — Atmosphere, Thin Places & The Follower (L)
**Goal:** Darkness you can feel; risk you can see; a bond readable in the field.
**Tasks:** New `client/presentation/ui/atmosphere/atmosphere_layer.tscn+gd` (CanvasLayer above world / below HUD): ColorRect #1 = the shared `grimoire_grade` pass; ColorRect #2 = drifting low-alpha fog. API `set_mood(dread, entropy, corruption, force_climate)`; drives the existing CanvasModulate; screens request moods, never add their own fullscreen shaders (Dracula veto). **No brightening the world for readability** — legibility came from W12's distinct assets. Thin places: mark a deterministic subset of feature cells via the worldgen FNV hash; veil shimmer shader + particles; `EncounterDirector.roll_step(step_index, tile_class)` — ~0.30 on thin cells / ~0.04 elsewhere, tile_class folded into the existing purpose hash (step-indexed determinism holds); misbehavior sub-roll (~1/12) draws from the dead `elite_pool` (T3) with a "the veil coughs" toast — the scare-and-a-story beat; `SfxService.play("veil_whisper")` hook for W14. Lead follower: replace the white-coin crop (~:445-460) with the RGBA cutout at tile scale trailing the previous cell (position ring-buffer), h-flipped, idle-bobbing; emote reactions (alert hop near thin places, wall shiver, joy hop after capture). Corruption visible: overworld passes `run.corruption` to AtmosphereLayer lerping toward `corruption_color(t)`; HUD sigil pip thickens/cracks at 25/50/75 with authored toasts. GdUnit: same seed + tile classes ⇒ same encounter/misbehavior sequence; paths near-zero.
**Acceptance:** Before/after overworld shots look like different engines — mist, falling edges, moody grade; paths are safe, shimmering tiles are a dare, and rarely one disgorges something too big; your actual lead trails you and reacts; a corruption-0 vs corruption-60 run is unmistakably two different worlds.

## Wave 14 — Sound Exists (M)
**Goal:** End the silence — the largest invisible cause of "plays terribly".
**Tasks:** Download CC0 (Kenney UI/Impact/RPG packs; Sonniss GDC / FreePD dark-ambient beds) → `client/assets/audio/` via the configured LFS `*.ogg` pattern + PROVENANCE. `SfxService` + `AmbienceService/MusicService` autoloads (two crossfading AudioStreamPlayers): marsh overworld bed, battle drone whose intensity layer crossfades with `session.entropy()`, menu/camp bed. Stingers: death knell, corruption-threshold shudder, boss swell, encounter sting, capture-beat cues, veil whisper (fills W13's hook). Footsteps per tile id from W6's step tween; UI click/confirm via ButtonJuice. Wire Options Music/SFX sliders to real AudioServer buses (retiring the dead switches). Headless test: services load streams and respond to `set_intensity` without a device.
**Acceptance:** Headphones: the marsh hums, battle brings a pulse that audibly thickens as the entropy dial fills, a death tolls a bell, every hit crunches — and the volume sliders audibly do something.

## Wave 15 — The Living Creation Table (L)
**Goal:** The design's showpiece stops being a form with a Submit button.
**Tasks:** Method HSlider precise↔wild (`recipe.method = "wild" if value>=0.5` — **engine stays binary**, parity/goldens untouched per Geneticist veto; the continuum is presentation): bench jitter, spark emission, corruption tint scale with the value; at wild, cycle `legality_solver`'s full configs array (:51-58 — real alternate outcomes, currently only configs[0] shown) at ~8Hz. Hold-to-seal commit (brass progress ring; early release snuffs); reveal: screen dim → conduit particle surge → newborn materializes via `dissolve.gdshader` (1→0) → name types on → ledger count-up → "Again? / Done"; <3s, any input after first-ever viewing skips (Wick); `_juice_enabled` flag keeps `lab_screen_test.gd` green. Taboo pact: verdict panel shifts through `corruption_color`, button reads "Break the Taboo (+18 corruption)" (from constants), two-step arm-then-seal; Forbidden Ladder rail listing graft/self_splice/reanimate from `splice_rules.json` with lock icons vs T_abom 40 / T_god 70 / T_self 85 against run corruption. Staged table rebuild of `_build_ui` (:381-487): subject/donor LivingPlates on ParchmentPanel frames, Line2D conduits to a bubbling central vessel, reagent icon chips with `ingredient_compat` hover tooltips, live cost ledger with count-up tweens. "Again?" pre-arms the newborn as Subject; per-run UNDOCUMENTED discovery stamps + Journal line; rotating gallows microcopy from VoiceBook. All numbers come from LabRecipeBench/LabEngine — no UI-side math (ADR-015).
**Acceptance:** A mid-commit screenshot shows a newborn emerging from dissolve under a sigil flare, name half-resolved; dragging toward Wild makes the rig tremble while the preview flickers between genuinely different outcomes; a taboo fuse feels like signing a pact; the playtester goes back for exactly one more splice.

## Wave 16 — VoiceBook, Choices & Peculiars (L)
**Goal:** The 767 authored lines replace dev-copy; the fight-every-time reflex breaks; dialogue grows a spine.
**Tasks:** `tools/ingest_voice.py` parses `docs/content/voice_library*.md` → `client/catalog/voice.json`; `VoiceBook` static loader (mirror of `toast_microcopy.gd`) with `pick(key, seed)` variant rolls (local RNG). Rewire: ToastMicrocopy presets, capture toasts (§5.1–5.4), battle banners (the W3 interim line is replaced without code changes), region-entry §6 blurbs, empty states. Parity test: every referenced key exists; every §5/§7 section ingested. Dialogic spine: choice pass-through in `dialogic_facade.gd` (Dialogic 2 natively parses `- choice`) + `choice_made(scene_id, branch_tag)` signal → QuestService; `.dch` character files for the 10 wired NPCs; one grimoire Dialogic style (parchment box, INK text, BRASS name — no new hexes); first consumers: Old Garran refuse/accept. Peculiar encounters: `_KIND_SALT` sub-stream in `encounter_director.gd` (~1 in 6 triggered → kind:"peculiar"); `PECULIAR_DEFS` in `overworld_content.gd` wiring three canon beats — the Conscientious Objector (vents instead of fighting; befriend via the existing CaptureService path), Pollen-Factor Dree's cursed trinket (into `run.inventory`; rare "your bag screams, briefly" toasts), a Greenwatcher beat — each a `.dtl` per the proven SQ-06 pattern; `_on_encounter` branches to DialogicFacade, never the battle scene. Ambient barks: proximity bubbles from §7.3, deterministic cooldown, hard cap 1 per ~25 steps; 5th-repeat interaction swaps to the authored out-of-lines bark. Three rationed fourth-wall cracks behind a `run.world_state.seen_cracks` one-shot registry (signpost knows your save name; Madam Cessil's authored line as a rare peculiar; ~1-in-8-runs menu subtitle flicker) — never in boss/death flows. Melon ripening stages on run milestones. GdUnit: fixed seed ⇒ same kind sequence; peculiar never instantiates battle_screen; objector-capture lands in run.party; each crack latches once.
**Acceptance:** In a five-minute walk, one "encounter" sits down and vents — and you can walk away with it in your coven; an NPC asks a real question and the answer changes the quest tracker; catching never shows the same line twice; one day a signpost knows your name and you screenshot it.

## Wave 17 — Dossier, Scryed Legibility & the Screen Router (L)
**Goal:** Every creature gets a soul-page; every readout answers at a glance; navigation becomes structurally soft-lock-proof.
**Tasks:** UiRouter (generalizing `open_camp`'s CanvasLayer pattern, `overworld_screen.gd:104-135`) with push/pop over the persistent overworld: party/journal/character/lab back-buttons pop instead of scene-swapping; camp Resume pops to the live overworld (replacing W0's interim patch); Esc/Tab pops exactly one level; each push/pop switches/restores the InputService context; integration test walks overworld→camp→party→camp→resume asserting overworld current + player_cell unchanged. The Lab stays a full-screen pushed scene (Geneticist veto honored). `dossier_screen.tscn` (authored scene): ParchmentPanel, LivingPlate LARGE, sigil + name header, six pole stats as force-colored icon+bar+number rows (bars AUGMENT numbers, never replace), skills with verb icons, bond + entropy/corruption meters via `corruption_color`, lineage strip reading `lineage.splice.parents`, hybrid composite portrait; opened from roster and the capture card. Party detail (:404-411) → the same icon+bar rows + HP bar; battle status chips (:562-587) → icon+short-label chips with one-line tooltips; grayscale-safe throughout. Gear honesty: gate the equip list on `run.inventory` ownership (`gear_service.gd:25-40` currently validates catalog only); battle victories grant drops through the loot path; unowned gear greyed with acquisition flavor. Onboarding: persistent collapsible controls chip; early quest def naming the boss goal ("something old guards the deep glut"). Rebinding: replace the F/G demo cycler (`options_menu.gd:119-127`) with press-any-key capture → `InputService.rebind` (plumbing exists, ADR-012).
**Acceptance:** Open a spliced hybrid: a real creature page — name, sigil, parents named, non-zero stats — on a light parchment page distinct from every dark screen; permadeath now has a face; a black screen is physically unreachable; a fresh player states controls and goal within 60 seconds; rebinds survive restart.

## Wave 18 — Death With Weight & Session Trust (L)
**Goal:** "Death funds creation" becomes real; the save experience earns trust.
**Tasks:** (application-layer only; confirm with mechanics that HP/is_dead stay out of domain — they do) Set `is_dead` when a creature ends at 0 HP (`battle_session.gd` result application + `game_controller.apply_battle_result`); `SkillMonFactory` honors persisted HP; dead creatures leave `run.party` for `run.flags['graveyard']` and credit parts via InventoryAdapter. **Co-requisite:** TTK/threat retune so death is rare, fair, and felt (wilds currently down a creature in ~3% of fights) — a Graveyard nobody fills is set-dressing; one that fills every fight is cruelty. Death beat: dissolve on the plate + 0.8s AtmosphereLayer desaturate pulse + knell stinger + VoiceBook epitaph, skippable. Graveyard page (journal tab): ParchmentPanel memorials — plate as ink silhouette (modulate black), name, cause, parts yielded; never the word "fainted". Save trust: `GameController.request_save()` with `save_succeeded/save_failed` signals → quill-scratch Toast / persistent themed warning (replaces the 7 fire-and-forget call sites); `WM_CLOSE_REQUEST` autosave autoload (`auto_accept_quit=false`); save inside `new_run()`; gate Continue on envelope parseability with a "The ledger is illegible" dialog. Camp becomes a camp: Rest heals the HP persisted since W3, currency strip (drachma/essence/ichor with icons), Save & Quit to Title. GdUnit: 0-HP creature flagged, excluded from next battle, present in graveyard; e2e loop green. No re-softening ever (Dracula veto): no return to consequence-free full-HP rebuilds.
**Acceptance:** Lose a creature and it is GONE — a mournful 1.5s beat, then a memorial in the grimoire; quit mid-run, relaunch, Continue resumes the exact tile with the same wounds and says so; every save shows a sigil; a corrupt save produces a legible in-world error.

## Wave 19 — Full 407 Promotion, Normal Maps & the Rig Gate (L)
**Goal:** Finish the keystone at library scale; light the world; decide rigs from evidence.
**Tasks:** Run `promote_creatures.py` over the full registry → 407 id-keyed RGBA plates (the W2 asset-contract CI holds the line; `gaps.json` → `gen_art.py --only` gap-fill at ~$0.04/image — $0 until gaps.json proves a gap, per Art Director veto); re-run the ~20% reject QA loop on knockout contact sheets. `gen_normalmaps.py` over remaining tiles + the ~30 highest-traffic cutouts; CanvasTexture .tres packs; extend the Light2D pass (torches, ward-stones, battle rim-light) inside ≤10 lights / ≤4 shadow casters / ≤3ms. **Hero-rig decision gate:** only now, if the owner judges LivingPlate insufficient, prototype ONE Skeleton2D cutout rig (lead or DM06) and measure ≤2ms before any second rig. LimboConsole mspf overlay vs the audit's per-system budgets stays the tuning instrument.
**Acceptance:** No species anywhere resolves to the fallback sprout; ground and creatures catch directional light; the dev overlay reads ≤16.6ms with everything on, on the Iris Xe machine.

---

## RISK REGISTER

| Risk | Mitigation |
|---|---|
| PIL/rembg knockout chews painterly halos/wisps/soul-fire | ~20% hand-flagged reject budget; QA contact sheets per batch; flat-plate variant retained for codex surfaces; Photoroom MCP last resort |
| Montage cell → registry-row mismatch poisons 219 name→image bindings | Mandatory 10-minute human eyeball pass over labeled montages before any promotion (W7 gate) |
| Async beat queue breaks the 58 synchronous test suites | Instant/drain mode designed in from PR one (no awaits headless); public APIs (`run_pending_battle`, `player_use_skill`, `last_step`) never change |
| Scene extraction breaks headless tests | Incremental extraction only, one child scene per wave, scene-structure assertions added alongside |
| Light2D / fullscreen shaders eat the Iris Xe 14ms headroom | Hard caps: ≤10 lights, ≤4 shadow casters, ≤2 fullscreen passes, ≤500 GPU particles; LimboConsole budget overlay; juice never over the HUD layer |
| Mass plate commit stalls VRAM/loads | W2 import ADR (≤512px, BC7+mipmaps) + `check_asset_contract.py` CI gate lands BEFORE W7; LFS pattern verified in W2 |
| Scene-build spikes read as jank under transitions | Budget: any scene build <250ms so `MIN_COVER_TIME` 0.25s covers it; tileset/texture caches (W6); bake, don't synthesize |
| Suite runtime (~70s) throttles PR count | Waves batch related changes; CI screenshot artifacts make review 10-second; Supabase CI paths-filtered (W2) |
| Windows toolchain gotchas (PYTHONUTF8, cold-import hang) | Per memory: `PYTHONUTF8=1` on all Python tools; no new pip deps on the mainline (PIL+numpy present) |
| Death lands before the TTK retune → cruelty or set-dressing | Permadeath (W18) ships WITH the threat retune as a co-requisite, never alone |

## EXPLICITLY OUT OF SCOPE THIS PASS
Oracle/engine mechanics expansion (AP pool, in-battle Overclock, combo-skill tables, Hex AI — each a future oracle-first phase); Supabase/cloud saves; mass Skeleton2D rigging; 3D/TripoSR experiments in-repo; batch ingestion of 24 main quests / pantheon kits / 18 branched scenes; plate regeneration or style transfer; Live2D (revenue-gated license); continuous lab method values in domain.