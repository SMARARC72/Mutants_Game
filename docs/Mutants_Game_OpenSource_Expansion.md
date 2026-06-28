# Mutants_Game — Open-Source Expansion (brainstorm / planning)

**Status:** 🧠 **brainstorm — NOT committed scope.** A menu of vetted open-source we could adopt to deepen gameplay, UX, capability, and dev velocity. **Date:** 2026-06-27 · URLs + licenses web-verified (sub-agent sweep + direct search). License key from `Mutants_Game_Resources.md` (🟢 use freely · 🟡 attribution/terms · 🔴 avoid/contaminating).

> Everything here is optional and additive. Nothing touches `client/domain/` or determinism. Verify the exact Godot-4.7 build + the in-repo LICENSE before adopting any item flagged *(verify)*.

---

## 1. Animation toolchain — layered (DragonBones + Live2D + native)

A three-tier strategy: cheap-and-everywhere at the base, richer where it matters, premium for hero moments. Cost-aware per your direction (use free tiers now, re-evaluate on pricing later).

| Tier | Tool | License | Use for |
|---|---|---|---|
| **Base (all creatures + player)** | **Godot `Skeleton2D` cutout + mesh-deform** | 🟢 MIT (built-in) | Rig existing painterly art → idle breathe / attack / hurt / death. Zero new art. |
| **Step-up (hero creatures, bosses, the player)** | **DragonBones** via **Daylily-Zeleen/Godot-DragonBones** (GDExtension, Godot 4.x, actively maintained) | 🟢 **MIT, no revenue gate** | Richer 2D skeletal (mesh FFD, IK, smoother organic motion) where native feels stiff. Free forever. https://github.com/Daylily-Zeleen/Godot-DragonBones |
| **Premium (living portraits: god/boss reveals, dossier close-ups)** | **Live2D Cubism (FREE tier)** via **gd_cubism / GDCubism** (Godot 4.3+) | 🟡 **see license note** | "Breathing illustration" portraits — the awe beat on a god/boss reveal or a creature-soul dossier. https://github.com/MizunagiKB/gd_cubism |

**Live2D license note (important, matches your "re-evaluate on pricing later"):** the **gd_cubism plugin is MIT**, but it depends on the **Live2D Cubism Core SDK**, which is under **Live2D's** license — the **FREE tier permits commercial use only while annual sales are under ¥10 M (~$67k USD)**. You're far under that now, so **use it freely**; **budget to purchase a Cubism SDK Publication/Business license if/when revenue approaches the threshold.** Keep Live2D-rigged content *modular* (portraits only) so it's swappable if you ever choose not to license it. DragonBones has **no such gate** — favor it for anything core.

**Recommendation:** native Skeleton2D as the backbone; **DragonBones as the primary step-up** (free, no gate); **Live2D free tier for a handful of premium portraits**, re-evaluated at the revenue threshold.

## 2. Lighting & depth — the full "elevated-2D" stack

All native or 🟢, no 3D. Stacked, these kill the flat-80s read.

| Layer | Tool | License | Effect |
|---|---|---|---|
| **Mood base** | `CanvasModulate` (tint the whole scene; animate for **day-night / the entropy-tide**) | 🟢 built-in | The dim, grimoire darkness the light cuts through |
| **Dynamic lights** | `PointLight2D` / `DirectionalLight2D` (torches, force-glows, sun) | 🟢 built-in | Real light pools; force-colored creature auras |
| **Shadows** | `LightOccluder2D` (occluder polygons on sprites/walls) | 🟢 built-in | Cast shadows = instant depth |
| **Surface relief** | **Laigter** → normal / specular / AO maps for tiles + sprites; set light **height** | 🟢 *(tool GPL, output is yours — R9-safe)* | Lit, 3D-feeling 2D surfaces; the single biggest de-80s win. https://github.com/azagaya/laigter |
| **Bloom / glow** | `WorldEnvironment` glow | 🟢 built-in | Sigil-flare, force-glow, the juice §4.5 |
| **Depth** | `Parallax2D` layers + atmosphere pass | 🟢 built-in | Worlds gain dimensionality |
| **Autotiling polish** | **Better Terrain** (Portponky) | 🟢 MIT | Makes tiled/procedural overworld look hand-laid (coastlines, paths, biome borders). https://github.com/Portponky/better-terrain |
| **Shader effects** | **GodotShaders CC0** (soft-shadow, fog, god-rays, color-grade, vignette, heat-haze, SDF) | 🟢 CC0 | Atmosphere + the SDF (`LightOccluder2D` SDF) for shader-driven effects |

## 3. Expansion catalog — what we haven't considered (by domain)

Impact: ⭐⭐⭐ high · ⭐⭐ medium · ⭐ situational. All 🟢 MIT/CC0 unless flagged.

### A. AI, mechanics & systems
| Item | License | Impact | What it unlocks for us |
|---|---|---|---|
| **LimboAI** (BT **+ Hierarchical State Machines**, visual editor/debugger) | 🟢 MIT (demo art CC-BY) | ⭐⭐⭐ | The **Succession invasion boss** as *authored, phase-based AI* (not a stat-swap) — readable, tunable. Complements Beehave (adds the HSM half). https://github.com/limbonaut/limboai |
| **godot-statecharts** (derkork) | 🟢 MIT | ⭐⭐⭐ | Declarative state machines for **battle phase flow** (input→resolve→status-tick→end) and **Lab splice-wizard** steps — no FSM spaghetti. https://github.com/derkork/godot-statecharts |
| **godot-constraint-solving** (WFC + generic CSP w/ backtracking) | 🟢 MIT | ⭐⭐⭐ | Two wins: procedural **overworld zones per Succession run** (NG+ replay) **AND — the non-obvious one — rule-driven *valid-splice* enforcement in the Lab** (legal force/organ combos guaranteed, no broken outputs). https://github.com/AlexeyBond/godot-constraint-solving |
| **OctoD godot-gameplay-systems** (attributes, buffs/debuffs, abilities, loot, turn-based nodes) | 🟢 MIT | ⭐⭐ | Reference architecture for stats + status effects + post-battle drops feeding parts/kits. Fork pieces, don't adopt whole. https://github.com/OctoD/godot-gameplay-systems |
| **expressobits/inventory-system** (inventory **+ crafting graph**, items as Resources) | 🟢 MIT | ⭐⭐ | The crafting graph is a strong substrate for the **Lab "recipe → spliced creature/part"** pipeline + parts/kits storage. https://github.com/expressobits/inventory-system |
| **inkgd** (inkle **Ink** narrative runtime, pure GDScript) | 🟢 MIT | ⭐⭐ | Deeply branching, variable-driven **occult lore/quest text** where node-dialogue gets unwieldy — *complements* Dialogic. https://github.com/ephread/inkgd |
| **Quest:** Questify (graph editor) or quest-system (Resource-driven) | 🟢 MIT *(verify build)* | ⭐⭐ | Branching objectives that gate Lab unlocks, capture targets, Succession triggers. Pick one. |
| **SimpleDungeons** (prefab-room procedural assembly) | 🟢 MIT *(verify)* | ⭐ | Hand-author occult set-piece rooms; generator stitches them per run (keeps procedural from feeling noise-mushy). |

### B. Content pipeline (1,000+ creatures)
| Item | License | Impact | Unlocks |
|---|---|---|---|
| **godot-csv-data-importer** (timothyqiu) | 🟢 MIT | ⭐⭐⭐ | Author/balance the codex in **sheets → typed Resources** at import. Direct fit for the 1,000+ roster + the registry CSVs you already have. https://github.com/timothyqiu/godot-csv-data-importer |
| **godot-aseprite-wizard** | 🟢 MIT | ⭐ | If any pixel-art (UI bits, effects) is animated in Aseprite → SpriteFrames/AnimationPlayer. Dev-only. |

### C. UX / UI
| Item | License | Impact | Unlocks |
|---|---|---|---|
| **Maaack's Game Template** | 🟢 MIT | ⭐⭐⭐ | Drop-in **main/pause/options menus** (audio/video/keybind + gamepad), loading screens, persistent settings, credits. Collapses weeks of menu plumbing; ships in real Steam titles. https://github.com/Maaack/Godot-Game-Template |
| **G.U.I.D.E** (Godot Unified Input Detection Engine) | 🟢 MIT | ⭐⭐⭐ | Unified KB/mouse/**gamepad**, runtime rebinding, **input contexts** (menu vs battle vs overworld), combos/hold. The input backbone. https://github.com/godotneers/G.U.I.D.E |
| **ThemeGen** | 🟢 MIT | ⭐⭐ | Define the **grimoire UI theme in code** (semantic colors, StyleBox inheritance, light/dark) — tames a large Control UI. https://github.com/Inspiaaa/ThemeGen |
| **NotificationEngine** | 🟢 MIT | ⭐⭐ | Toasts from anywhere: "creature caught / part harvested / quest update / rival approaches." https://github.com/Amose3535/NotificationEngine |
| **EasyTransition** | 🟢 MIT | ⭐⭐ | One-call stylized **overworld↔battle transitions** (ritual feel) + threaded loading cover. https://github.com/IUXGames/EasyTransition |
| **ProtonControlAnimation** | 🟢 MIT | ⭐ | Hover/show **UI juice** on any Control, no code. https://github.com/HungryProton/proton_control_animation |
| **ControllerIcons** | 🟢 MIT (art CC0) | ⭐ | Auto-correct device glyphs, hot-swaps KB↔pad. Use only if not using G.U.I.D.E's prompts. https://github.com/rsubtil/controller_icons |

### D. Accessibility (you're already color+icon safe — this completes it)
| Item | License | Impact | Unlocks |
|---|---|---|---|
| **Godot 4.5+ native AccessKit** | 🟢 engine (MIT) | ⭐⭐⭐ | Native **screen-reader** on Control nodes + OS **reduced-motion / high-contrast** flags. You're on 4.7 → this is the accessibility backbone, first-party. |
| **CVD Simulation Shader** (CC0) + **godot-eyesee-color** (MIT) | 🟢 CC0/MIT | ⭐⭐ | Scientifically-accurate **colorblind testing** (Protan/Deutan/Tritan) to *verify* the force cues read — a test tool, not a ship-fix. |
| **HauntedBees Accessibility Suite** | 🟢 MIT | ⭐ | Lift **text-scaling** + **subtitle/caption** components (no standalone addon for these). https://github.com/HauntedBees/Godot-Accessibility-Suite |

### E. Dev velocity, ops & distribution
| Item | License | Impact | Unlocks |
|---|---|---|---|
| **gdtoolkit** (gdlint + gdformat) | 🟢 MIT | ⭐⭐⭐ | Format/lint GDScript + **pre-commit + CI** (runs without the Godot binary). Code-quality backbone (likely already in your CI — confirm). https://github.com/Scony/godot-gdscript-toolkit |
| **GodotSteam** *(Codeberg — GitHub is archived)* | 🟢 MIT (Steamworks proprietary) | ⭐⭐⭐ | Achievements, **Steam Cloud saves**, leaderboards, rich presence, **Workshop/UGC**. The distribution layer when you ship. https://codeberg.org/godotsteam/godotsteam |
| **sentry-godot** (Godot 4.5+) | 🟢 MIT | ⭐⭐⭐ | **Crash + GDScript-error reporting**, self-hostable — for a clean playtest sprint. https://github.com/getsentry/sentry-godot |
| **LimboConsole** (or PankuConsole) | 🟢 MIT | ⭐⭐⭐ | In-game **debug/cheat console** — *live-evaluate breeding/splice/damage and diff against the Python oracle*; a parity-test velocity multiplier. https://github.com/limbonaut/limbo_console |
| **godot-debug-menu** | 🟢 MIT | ⭐⭐ | F3 perf overlay (FPS/frametime/1%-lows) **in release builds** — testers screenshot metrics into bug reports. https://github.com/godot-extended-libraries/godot-debug-menu |
| **abarichello/godot-ci** | 🟢 MIT | ⭐⭐ | Docker image + CI templates: headless export Win/Linux + itch.io deploy. https://github.com/abarichello/godot-ci |
| **Talo Game Services** | 🟢 MIT | ⭐⭐ | **Self-hostable** telemetry + player stats — privacy-first playtest data on infra you control. https://github.com/TaloDev/godot |
| **GodotModLoader** | 🟡 **CC0** *(not MIT — log it)* | ⭐ | Runtime ZIP mods + Steam Workshop/Thunderstore — community content (fits the Succession ethos) much later. https://github.com/GodotModding/godot-mod-loader |
| **KoBeWi Auto-Export-Version** | 🟢 MIT | ⭐ | Stamp build/version from git on every export — free playtest-build discipline. |

## 4. The non-obvious wins (if you read nothing else)

1. **Constraint-solving in the *Lab*, not just the map.** Everyone uses WFC for terrain (real NG+ win). The novel move: the same backtracking CSP enforces **legal splice combinations** — rule-driven, guaranteed-valid recombination instead of ad-hoc checks. (`godot-constraint-solving`, MIT.)
2. **LimboAI's HSM makes the Succession boss an *authored feature*.** Your ascended champion invading a friend's run deserves real phase logic, not a stat-swap — LimboAI's BT+HSM + visual debugger delivers exactly that, MIT, alongside Beehave.
3. **There's a ready-made, all-MIT, self-hostable playtest toolchain** you probably haven't wired: **sentry-godot** (crashes) + **godot-debug-menu** (in-release perf) + **LimboConsole** (live cheat/parity probing) + **gdtoolkit** (pre-commit/CI) + **Talo** (private telemetry). No third-party data exposure.
4. **G.U.I.D.E + Maaack's Template = input, rebinding, gamepad, and the whole settings shell in two installs** — the highest effort-saved-per-dependency in the sweep.
5. **Ink (`inkgd`) for the deep occult lore** branches, sitting *next to* Dialogic (node-dialogue for scenes, Ink for sprawling variable-driven narrative).

## 5. License cautions (log these)
- **Live2D Cubism Core SDK** = Live2D license (free < ¥10 M/~$67k annual sales, then paid). The **gd_cubism plugin is MIT**; the **runtime is the gated part**. Keep Live2D content modular; re-evaluate at the revenue threshold.
- **GodotModLoader = CC0**, not MIT — note in `CREDITS.md`/license inventory.
- **Tooltips Pro** (deep RPG tooltips) ships under the **Anti-Capitalist Software License** → **avoid for a sellable game**; build tooltips on `RichTextLabel` or a permissive addon.
- **GodotSteam** → pull from **Codeberg** (GitHub mirror is archived); Steamworks itself is proprietary (fine to integrate, can't redistribute the SDK).
- **Save-addon guardrail:** avoid any `ResourceSaver`/`.tres`/`.res`-based save addon — conflicts with **ADR-012** (data-only versioned JSON) and is a code-execution risk. Stay JSON.
- **Laigter** tool is GPL, but its **output maps are yours** (not a derivative) → safe (R9).
- Everything **recommended** is **MIT or CC0** — no GPL/AGPL/CC-BY-SA in shippable code.

## 6. If/when you adopt — suggested clustering (brainstorm, not commitment)
- **Now-ish (dev velocity, low risk):** gdtoolkit, LimboConsole, godot-debug-menu, sentry-godot, godot-csv-data-importer, KoBeWi version-stamp.
- **Phase 5 (MVP screens/UX):** Maaack's Template, G.U.I.D.E, ThemeGen, NotificationEngine, EasyTransition, the lighting stack (§2), the animation tiers (§1).
- **Mechanics deepening:** LimboAI + godot-statecharts, godot-constraint-solving (overworld + Lab rules), expressobits crafting, a quest addon, inkgd.
- **Accessibility pass:** native AccessKit + CVD testing + HauntedBees components.
- **Pre-launch:** GodotSteam, Talo, godot-ci, (later) GodotModLoader.

*All items remain optional. Adopt one, prove it in a branch, keep it only if it earns its place — same discipline as the rest of the build.*
