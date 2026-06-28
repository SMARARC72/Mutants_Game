# CLAUDE CODE — Mutants_Game · Phase 0.5 Kickoff (Execution Prompt #2)

> Run inside the `Mutants_Game` repo, **after Phase 0 is green** (see `PHASE0_REPORT.md`). This phase **acquires, places, and threads six external building blocks into the plan** — then executes the integration that's optimal *now* and explicitly stages the rest. Build to the Definition of Done, then **stop and report**. Do not start Phase 1 (determinism core).

---

## 0. Orientation & authority
- **`docs/Mutants_Game_TechnicalDesign.md` is normative.** Honor it. Deviations → an ADR in `docs/adr/`.
- **`docs/Mutants_Game_Resources.md`** is the vetted catalog these six come from (license key 🟢/🟡/🔴). Update its status as you integrate.
- This phase adds **dependencies and assets only** — no game logic, no engine port, no screens. The point is to have the right proven parts installed, licensed cleanly, and mapped to where they'll be used.

## 1. The resources (two waves; each: acquire → best use → placement → now vs defer)

**Wave A** (the first six):

| # | Resource | License | Acquire → where | Best use case | Do **now** vs **defer** |
|---|---|---|---|---|---|
| 1 | **GDQuest Open-RPG** | 🟢 MIT | **Clone OUTSIDE the repo** to `../_reference/godot-open-rpg` (do **not** vendor the whole project) | Reference for turn-based combat queue, grid/gamepiece movement, inventory, map transitions, dialogue wiring | **Now:** clone + write the pattern map (§2.5). **Defer:** actual adaptation → Phase 2 (battle) / Phase 5 (overworld). |
| 2 | **Supabase Godot addon (4.x)** | 🟢 MIT | **Vendor pinned** → `client/addons/supabase/` (record version/commit in `client/addons/THIRD_PARTY.md`) | Auth (anonymous-first, ADR-011), DB CRUD behind the DAL, Realtime, Storage | **Now:** install, enable, confirm it loads in Godot 4.7 headless; stub the DAL wrapper. **Defer:** real repositories → Phase 3; Storage/gen → Phase 4. |
| 3 | **game-icons.net** | 🟡 CC BY 3.0 | Download **curated SVGs** → `client/assets/icons/{forces,verbs,statuses,currencies,gear}/` | Iconography for the 6 forces · 8 verbs · 6 statuses · 3 currencies · gear slots | **Now (high-value, finite set):** pick + place one icon per taxonomy entry; write `CREDITS.md`. **Defer:** styling/recolor to the design system → Phase 5. |
| 4 | **Kenney** | 🟢 CC0 | Full packs → local library `../_asset-library/kenney/`; **curated subset** → `client/assets/{ui,tiles,audio,particles}/` | UI frames/buttons/cursors, a top-down tile set for the overworld prototype, UI SFX, particle textures | **Now:** curate a starter subset (UI pack + one tile set + UI audio + particles). **Defer:** full art pass → Phase 5. |
| 5 | **GodotShaders.com (CC0)** | 🟢 CC0 | Curated `.gdshader` files → `client/presentation/shaders/` (each with a provenance header: URL + author + CC0) | The juice layer (TDD/design §4.5): hit-flash, glow/bloom, dissolve, outline, palette-shift, sigil-flare | **Now:** assemble the starter VFX kit (the 5–6 named effects). **Defer:** wiring into battle/Lab → Phase 2/5. |
| 6 | **Dialogic 2** | 🟢 MIT (Godot 4.3+) | **Vendor pinned** → `client/addons/dialogic/` (record version) | NPC dialogue, branching/absurdist encounters, the rare 4th-wall beats (design §3.5) | **Now:** install, enable, build a 3-line smoke timeline that runs. **Defer:** real dialogue authoring → Phase 5. |

**Wave B** (second wave — same treatment):

| # | Resource | License | Acquire → where | Best use case | Do **now** vs **defer** |
|---|---|---|---|---|---|
| 7 | **GdUnit4** (primary) · GUT 9.x (alt) | 🟢 MIT | **Vendor pinned** → `client/addons/gdUnit4/` | The GDScript unit + **parity** test harness (TDD §11); CI test runner | **Now (foundational):** install GdUnit4 as primary, one passing sample test, **wire into CI headless**. **Defer:** parity suites → Phase 1–2. |
| 8 | **Beehave** (behavior trees) | 🟢 MIT | **Vendor pinned** → `client/addons/beehave/` | Battle AI (enemy/rival action choice) + overworld NPC behavior | **Now:** install + verify + trivial tree. **Defer:** real trees → Phase 2 / Phase 5. ⚠ **determinism rule §4.** |
| 9 | **Phantom Camera** | 🟢 MIT | **Vendor pinned** → `client/addons/phantom_camera/` | Overworld + battle camera (follow, framing, push-in on big hits = juice) | **Now:** install + verify loads. **Defer:** camera rigs → Phase 5 / Phase 2. Presentation-only. |
| 10 | **fenix-hub/.supabase-examples** | 🟢 MIT | **Clone OUTSIDE repo** → `../_reference/supabase-examples` | Working auth + realtime patterns to model the DAL/auth flow on | **Now:** clone + add a section to the Pattern Map (§2.4). **Defer:** adapt → Phase 3–4. |
| 11 | **OpenGameArt** | 🟢 CC0 **per-asset (verify!)** / some 🟡 CC-BY | Full → `../_asset-library/oga/`; curated → `client/assets/tiles/` | Dark-fantasy/dungeon top-down tiles complementing Kenney | **Now:** grab **one verified-CC0** tileset. **Defer:** full tile pass → Phase 5. ⚠ confirm each asset's license. |
| 12 | **Kenney Particle Pack** | 🟢 CC0 | Pack → local library; curated → `client/assets/particles/` | Particle textures for crits, awakenings, splice-reveal (juice §4.5) | **Now:** curate a starter particle subset. **Defer:** full VFX → Phase 2/5. |
| 13 | **Sonniss GameAudioGDC bundle** | 🟢 royalty-free, no attribution | **Local library ONLY** → `../_asset-library/sonniss/` (GBs — never in repo); curated clips → `client/assets/audio/sfx/` | The big SFX source: hit/crit/catch/splice/UI sounds | **Now:** download current-year bundle locally; curate **≤10** starter clips. **Defer:** full SFX pass → Phase 5. |

## 2. Deliverables

### 2.1 Vendored addons (Supabase + Dialogic), pinned & loading
- Place under `client/addons/`. Record exact version/commit + source URL + license in `client/addons/THIRD_PARTY.md`.
- Enable both in `project.godot`. **Acceptance:** Godot 4.7 opens the project headless with **no addon load errors** (`godot --headless --quit` clean); Dialogic runs a trivial timeline; the Supabase addon initializes against the local stack config (anon key only).

### 2.2 Curated icon set + attribution
- One SVG per taxonomy entry (forces ×6, verbs ×8, statuses ×6, currencies ×3, gear slots) under `client/assets/icons/...`, named to match our domain terms.
- **`CREDITS.md`** at repo root: every game-icons.net icon → author + `https://game-icons.net` + CC BY 3.0. **Acceptance:** every 🟡 asset is credited; no icon is unattributed.

### 2.3 Kenney starter kit + GodotShaders juice kit
- Curated CC0 subsets in `client/assets/` and `client/presentation/shaders/`. CC0 → no attribution required, but add a short provenance note per source folder anyway.
- **Acceptance:** the curated binaries are **LFS-tracked** (not bloating base history — see §3); shaders compile in Godot 4.7.

### 2.4 Open-RPG reference + pattern map
- Clone to `../_reference/` (outside the repo; add a note, do not commit it).
- Write **`docs/Open-RPG_Pattern_Map.md`**: a table mapping Open-RPG systems → our target module → which phase adapts it (e.g., their combat turn loop → `client/application/battle_controller.gd` → Phase 2; their gamepiece grid movement → overworld → Phase 5). Note license: MIT, adapt-with-attribution, **patterns only — never wholesale copy, and never into `domain/`**.
- **Acceptance:** the map names the specific Open-RPG files/scenes we'll learn from and where each lands.

### 2.5 Plan integration (thread it in)
- **`ADR-013`** in `docs/adr/` — records the dependency decisions: vendor Supabase+Dialogic+Beehave+Phantom Camera+GdUnit4 (pinned; **GdUnit4 = primary test framework**), Open-RPG + supabase-examples reference-only, the curated-subset asset policy (Kenney/OGA/GodotShaders/Sonniss → local library + curated LFS subset), and the determinism boundary (including the Beehave battle-AI RNG rule below).
- Update **`docs/Mutants_Game_Resources.md`**: mark these six `INTEGRATED` with their in-repo location.
- **`PHASE05_REPORT.md`** at repo root: what was added, where, licenses/attribution status, how to verify locally, and the deferred hooks (what each resource is wired into and in which phase).

### 2.6 Wave-B addons (GdUnit4, Beehave, Phantom Camera), pinned & loading
- Vendor pinned under `client/addons/`; record version/commit/source/license in `client/addons/THIRD_PARTY.md`; enable in `project.godot`.
- **GdUnit4 is the primary test framework** (TDD §11 — stronger CI + mocking; GUT 9.x is the documented alternative). Add one passing sample test and **wire GdUnit4 into the CI test job** (headless) so Phase 1's parity suite has a runner waiting.
- **Acceptance:** project opens headless in Godot 4.7 with **zero** addon errors; the GdUnit4 sample test passes **in CI**; Beehave + Phantom Camera load.

### 2.7 Wave-B references & supplemental assets
- `../_reference/supabase-examples` cloned (not committed); add a section to the Pattern Map (§2.4) noting which example → our auth/DAL module → phase.
- One **verified-CC0** OGA tileset (record its license), the Kenney Particle Pack subset, and **≤10** curated Sonniss SFX placed under `client/assets/**`; full downloads stay in `../_asset-library/` (not committed).
- **Acceptance:** curated assets LFS-tracked; the Sonniss bundle is **not** in git; the OGA asset's license is recorded (CC0, or `CREDITS.md` if CC-BY).

## 3. Repo hygiene (.gitignore / .gitattributes adjustments)
- **Addons must commit fully** (some ship PNGs): add negations so `client/addons/**` and the curated `client/assets/**` are tracked despite the global `*.png` ignore — e.g. `!client/addons/`, `!client/assets/`, and `!**/*.png` *scoped under those paths* (or move the global image-ignore to only `/art/` + bulk dirs). Keep the **bulk** `art/` and `../_asset-library/` out of git.
- **Curated binaries via LFS:** ensure `.gitattributes` LFS patterns cover `client/assets/**` so the few committed PNGs/audio go to LFS, not base history. Verify with `git check-attr filter <file>` → `lfs`.
- **Acceptance:** `git status` shows addons + curated assets tracked; `git ls-files | xargs du` confirms no multi-MB blob landed in base history; bulk libraries remain ignored.

## 4. Guardrails (non-negotiable)
- **Determinism boundary:** none of these touch `client/domain/`. Addons live in `addons/` + are used from `infrastructure/`/`presentation/`; Open-RPG patterns are adapted into `application/`/`presentation/`. The domain stays the pure, parity-tested oracle port (TDD §3.1, §6).
- **License discipline (TDD R9):** retain each addon's LICENSE; credit every 🟡 game-icons asset in `CREDITS.md`; CC0 (Kenney, GodotShaders) needs none. **Do not** introduce any 🔴 here (no GPL code, no Pokémon-clone assets) — none of the six are 🔴, keep it that way.
- **Pin versions** (no floating `main`): record the exact addon version/commit so the build is reproducible.
- **Secrets:** the Supabase addon ships only the **anon** key in client config; service-role/OpenAI stay server-side.
- **Beehave + determinism (critical):** Beehave may drive overworld NPC behavior freely, but **any AI decision that affects a battle outcome MUST draw randomness from the injected canonical RNG sub-stream (ADR-001) — never Beehave's own randomness or global `randf`/`randi`** — or full-battle replay/parity (TDD §6) breaks. Battle AI lives in `application/` and *selects* actions; resolution stays in the deterministic `domain/`.
- **OpenGameArt is mixed-license:** verify each asset is CC0 (or CC-BY → `CREDITS.md`) **before** committing. The site is not the license.
- **Sonniss is gigabytes:** local library only, never committed; only the ≤10 curated clips enter the repo via LFS.
- **Test framework:** GdUnit4 is primary (GUT 9.x is the documented fallback); the choice is recorded in ADR-013.
- **Scope:** acquisition + placement + mapping only. No engine port, no gameplay, no screens. Don't gold-plate the curated subsets — a starter kit, not the full art pass.

## 5. Definition of Done (all true)
1. Supabase + Dialogic vendored at pinned versions under `client/addons/`; project opens headless in Godot 4.7 with **zero addon errors**; Dialogic smoke timeline runs.
2. Curated icon set placed + **`CREDITS.md`** complete (every CC-BY icon attributed).
3. Kenney + GodotShaders starter kits in place; curated binaries LFS-tracked; shaders compile.
4. Open-RPG cloned as external reference (not committed) + **`docs/Open-RPG_Pattern_Map.md`** written.
5. **`ADR-013`** + updated `docs/Mutants_Game_Resources.md` (statuses) + **`PHASE05_REPORT.md`**.
6. `.gitignore`/`.gitattributes` adjusted; no asset bloat in base history; CI still green.
7. **(Wave B)** GdUnit4 vendored + sample test green **in CI**; Beehave + Phantom Camera load headless with zero errors; GdUnit4 wired into the CI test job.
8. **(Wave B)** supabase-examples cloned as reference (not committed); one verified-CC0 OGA tileset + Kenney particles + ≤10 Sonniss SFX curated under `client/assets/**` (LFS); full bundles in `../_asset-library/` (not committed); OGA license recorded.
9. **Nothing added to `client/domain/`.**
10. **STOP** and hand back the report. Do not begin Phase 1.

## 6. What comes next (context only)
**Phase 1 — Determinism core:** canonical PCG32 RNG (ADR-001) + half-to-even rounding (ADR-002) in GDScript + Python, refactor the oracle, land the §6.5 fixes, build the golden-vector generator. The assets/addons staged here get wired in during Phases 2 (battle/juice) and 5 (overworld/UI/dialogue). For now: integrate the six to the DoD and report.
