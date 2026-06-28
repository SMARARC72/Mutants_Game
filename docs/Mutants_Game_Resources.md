# Mutants_Game — External Resources & Assets (vetted, license-keyed)

**Purpose:** proven, public building blocks to flesh out the game without reinventing or contaminating the license stack. **Last updated:** 2026-06-27 · all links + licenses web-verified.

> **The one rule.** We **generate our own creatures** (OpenAI pipeline). Everything below is *supplemental*: code patterns to port, overworld tiles, grimoire UI + iconography, fonts, VFX, and audio — the things we don't generate. Never ship another project's creature sprites, names, or music.

## License key (read first — enforces TDD risk R9)

| | Meaning | Rule |
|---|---|---|
| 🟢 **GREEN** | CC0 / public-domain, or MIT/Apache/OFL | Use freely, commercial OK. CC0 needs no attribution; MIT/OFL keep the license text. |
| 🟡 **YELLOW** | CC-BY (attribution required) | Fine to use — **must** credit. Track every one in `CREDITS.md`. |
| 🔴 **RED** | GPL/copyleft code · CC-BY-**SA** assets · IP-encumbered (Pokémon clones) | **Reference/learning only.** Do **not** copy code or ship assets — they force their license onto our game or carry someone else's IP. |

Keep a `CREDITS.md` at repo root the moment you pull the first 🟡 asset.

---

## ⭐ Top picks (start here — highest leverage)

1. 🟢 **GDQuest Open-RPG** (MIT) — the single best code reference: turn-based combat, grid movement, inventory, dialogue, map transitions in Godot 4. Port *patterns*, not wholesale. https://github.com/gdquest-demos/godot-open-rpg
2. 🟢 **Supabase Godot addon (4.x)** + examples (MIT) — our plumbing. Auth/DB/Realtime/Storage out of the box. https://github.com/supabase-community/godot-engine.supabase · examples: https://github.com/fenix-hub/godot-engine.supabase-examples
3. 🟡 **game-icons.net** (CC BY 3.0) — ~4,180 SVGs incl. fantasy/occult/creature/GUI. **Perfect for our 6 forces · 8 verbs · 6 statuses · 3 currencies** iconography. https://game-icons.net
4. 🟢 **Kenney assets** (CC0) — 60k+ UI, tiles, particles, audio; no attribution. The supplemental backbone. https://kenney.nl/assets
5. 🟢 **GodotShaders.com — CC0 filter** (CC0) — 1,200+ ready 2D shaders for the juice layer (glow, dissolve, palette, outline, sigil-flare). https://godotshaders.com/shader-license/cc0/
6. 🟢 **Dialogic 2** (MIT, Godot 4.3+) — dialogue/branching for NPC humor, absurdist encounters, the 4th-wall beats. https://github.com/dialogic-godot/dialogic
7. 🟢 **awesome-godot** (the master finder) — the curated list; use it to vet any addon below. https://github.com/godotengine/awesome-godot

---

## 1. Code — frameworks & patterns to port from

| Resource | License | Use for | Notes |
|---|---|---|---|
| **GDQuest Open-RPG** | 🟢 MIT | Battle structure, grid overworld, inventory, dialogue, map transitions | Godot 4.5+ project; we're on 4.7. Closest match to our needs. https://github.com/gdquest-demos/godot-open-rpg |
| **Maruno17 godotmon-project** | ⚠️ verify LICENSE | Monster catch / raise / battle loop reference | By the Pokémon Essentials lead — credible patterns, but **check the repo LICENSE before copying any code**, and ship none of its assets. https://github.com/Maruno17/godotmon-project |
| **Tuxemon** | 🔴 GPLv3 code / CC-BY-SA assets | **Design/content reference only** — a complete open monster-tamer. Study structure; **do not copy code** (GPL is viral) or assets (share-alike). https://github.com/Tuxemon/Tuxemon |
| Pokémon clones (FireRed remakes, OpMon, Godomon) | 🔴 IP-encumbered | Code-pattern glance only | Often contain Nintendo sprites/names/music — never ship their assets; prefer Open-RPG for clean MIT patterns. |

## 2. Code — Godot addons (find/vet via awesome-godot)

| Addon | License | Use for |
|---|---|---|
| **Dialogic 2** | 🟢 MIT | NPC dialogue, branching encounters, the absurdist + 4th-wall moments (design §3.5) |
| **Beehave** (behavior trees) | 🟢 MIT | Battle AI + overworld NPC behavior — `bitbrain/beehave` (confirm via awesome-godot) |
| **Phantom Camera** | 🟢 MIT | Overworld/battle camera framing, follow, shake-adjacent moves (confirm via awesome-godot) |
| **GdUnit4** / **GUT 9.x** | 🟢 MIT | The GDScript test frameworks (TDD §11) — GdUnit4 has stronger CI + mocking; GUT is the classic |
| Inventory / save-system addons | 🟢 mostly MIT | Reference only — our save is versioned JSON per ADR-012; vet any addon against that |

## 3. Code — Supabase plumbing (Phases 3–4)

| Resource | License | Use for |
|---|---|---|
| **godot-engine.supabase (4.x)** | 🟢 MIT | Auth (anonymous-first, ADR-011), DB CRUD, Realtime, Storage |
| **fenix-hub/.supabase-examples** | 🟢 MIT | Working auth + realtime patterns (Todo, realtime chat) to model our DAL on |

## 4. Code — Determinism (Phase 1, ADR-001)

- **Confirmed:** Godot's built-in `RandomNumberGenerator` already uses **PCG32** — so our canonical-PCG32 choice matches the engine's own family. **But** still implement our *own documented* PCG32 in **both GDScript and Python** (don't rely on Godot's internal float construction matching Python). Canonical C to port from: https://www.pcg-random.org/ (the minimal `pcg32` is ~20 lines).
- **Reference:** `DevinPentecost/godot-seeded-random-sequence` — a seeded-sequence example. https://github.com/DevinPentecost/godot-seeded-random-sequence

## 5. Art — tilesets (overworld: classic-2D-Pokémon, matured per design §1/§3.5)

| Source | License | Use for |
|---|---|---|
| **Kenney** (Roguelike/RPG, 1-Bit, Tiny Town/Dungeon packs) | 🟢 CC0 | Prototype + production top-down tiles; recolor to our parchment-ink palette | https://kenney.nl/assets/category:2D |
| **OpenGameArt — CC0 filter** | 🟢 CC0 (per-asset — verify each) | Dark-fantasy/dungeon top-down tilesets (16×16/32×32). OGA is mixed-license — **confirm CC0 per asset.** https://opengameart.org/content/cc0-tiles-tilesets |

> Tiles set the "old-school Pokémon, grown up" read. Generate creatures over them; the tiles are the world they walk.

## 6. Art — UI, iconography, fonts (the grimoire interface)

| Resource | License | Use for |
|---|---|---|
| **game-icons.net** | 🟡 CC BY 3.0 | Forces / verbs / statuses / currencies / gear icons — the iconography backbone. Credit "Icons by {author}, game-icons.net". https://game-icons.net |
| **Kenney UI Pack / UI Audio / Interface Sounds** | 🟢 CC0 | Panels, frames, buttons, cursors + UI click/confirm SFX. https://kenney.nl/assets/ui-pack |
| **Google Fonts — blackletter/serif (OFL)** | 🟢 OFL | Grimoire headings + readable body. Picks: **UnifrakturCook**, **UnifrakturMaguntia**, **Pirata One**, **New Rocker**, **Germania One** (display) + a clean serif for body. https://fonts.google.com |

## 7. Art — VFX / shaders (the dopamine/juice layer, design §4.5)

| Resource | License | Use for |
|---|---|---|
| **GodotShaders.com (CC0 filter)** | 🟢 CC0 | Hit-flash, dissolve, glow/bloom, outline, palette-shift, sigil-flare, screen-distortion — drop-in for battle/Lab juice. https://godotshaders.com/shader-license/cc0/ |
| **GDQuest godot-shaders** | 🟢 MIT | Curated 2D/3D shaders with playable demos. https://github.com/gdquest-demos/godot-shaders |
| **Kenney Particle Pack** | 🟢 CC0 | Particle textures for crits, awakenings, splice reveals. |

## 8. Audio — SFX & music

| Resource | License | Use for |
|---|---|---|
| **Sonniss GameAudioGDC bundle** | 🟢 royalty-free, **no attribution**, commercial OK | The big SFX library (200GB+ archive across years). https://sonniss.com/gameaudiogdc |
| **Kenney audio packs** | 🟢 CC0 | UI/impact/retro SFX, no attribution. https://kenney.nl/assets/category:Audio |
| **itch.io — CC0 soundtracks / dark-ambient / horror** | 🟢 CC0 (per-pack — verify) | Dark-ambient/occult music beds. Filter CC0; confirm per pack. https://itch.io/soundtracks/assets-cc0 |

---

## Attribution & avoidance (do this as you go)

- **Track every 🟡 CC-BY asset** in `CREDITS.md` (asset, author, source URL, license) — start it when you pull the first game-icons.net set.
- **Never** import 🔴: GPL code (Tuxemon, etc.) into our client, CC-BY-**SA** assets, or any Pokémon-clone's sprites/names/music. These contaminate the license or carry third-party IP — exactly the TDD R9 risk.
- **OGA / itch.io are mixed-license** — the *site* isn't the license; verify each asset's CC0/CC-BY before use.

## Phase mapping (what to pull, when)

- **Phase 1 (determinism):** PCG32 reference (pcg-random.org), godot-seeded-random-sequence, GdUnit4.
- **Phase 2 (engine port):** Open-RPG combat patterns; GdUnit4.
- **Phase 3–4 (persistence/services):** Supabase addon + fenix-hub examples.
- **Phase 5 (MVP slice/screens):** Kenney/OGA tiles, game-icons.net, OFL fonts, GodotShaders CC0, Dialogic, Beehave, Kenney+Sonniss+itch.io audio.

*Vet anything not on this list through `awesome-godot` and confirm its license before it touches the repo.*

---

## Phase 0.5 integration status (2026-06-27)

The first six (+ Wave B) building blocks are **acquired, placed, and threaded into the plan** (ADR-013).

| Resource | Status | In-repo location / note |
|---|---|---|
| GDQuest Open-RPG (MIT) | ✅ INTEGRATED (reference) | cloned to `../_reference/godot-open-rpg` (not committed); map: `docs/Open-RPG_Pattern_Map.md` |
| Supabase Godot addon (MIT) | ✅ INTEGRATED | `client/addons/supabase` @ `v3.3.0`; enabled; autoload `Supabase` |
| game-icons.net (CC BY 3.0) | ✅ INTEGRATED | 28 curated SVGs in `client/assets/icons/**`; attributed in `CREDITS.md` |
| Kenney (CC0) | 🟡 PARTIAL | dirs + `PROVENANCE.md` in `client/assets/{ui,tiles,particles}`; curated subset pending (bulk in `../_asset-library/`) |
| GodotShaders.com (CC0) | ✅ INTEGRATED (starter) | 3 CC0 shaders in `client/presentation/shaders`; glow/palette/sigil-flare → Phase 5 |
| Dialogic 2 (MIT) | ✅ INTEGRATED | `client/addons/dialogic` @ `2.0-alpha-19`; enabled; 3-line smoke timeline + test |
| GdUnit4 (MIT) | ✅ INTEGRATED | `client/addons/gdUnit4` @ `v6.1.3`; **primary** framework; sample test in CI |
| Beehave (MIT) | ✅ INTEGRATED | `client/addons/beehave` @ `v2.9.2`; loads headless; ⚠ battle-AI RNG rule (ADR-013) |
| Phantom Camera (MIT) | ✅ INTEGRATED | `client/addons/phantom_camera` @ `v0.11.0.2`; loads headless |
| fenix-hub supabase-examples (MIT) | ✅ INTEGRATED (reference) | cloned to `../_reference/supabase-examples` (not committed); mapped in the pattern map |
| OpenGameArt (per-asset) | 🟡 PARTIAL | dir + `PROVENANCE.md`; one verified-CC0 tileset pending (⚠ verify each asset) |
| Kenney Particle Pack (CC0) | 🟡 PARTIAL | dir + `PROVENANCE.md`; curated subset pending |
| Sonniss GameAudioGDC (royalty-free) | 🟡 DEFERRED | dir + `PROVENANCE.md`; bundle is tens-of-GB/gated → local-only, ≤10 curated clips pending |

See `PHASE05_REPORT.md` for verification + the manual download steps for the 🟡 items.
