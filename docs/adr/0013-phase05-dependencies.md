# ADR-013 — Phase 0.5 dependency & asset decisions

**Status:** Accepted (Phase 0.5) · **Context:** TDD R9 (license hygiene), §3.1 (determinism boundary),
§11 (testing). Source catalog: `docs/Mutants_Game_Resources.md`.

## Decision

**Vendor (pinned, committed under `client/addons/`):** Supabase `v3.3.0`, Dialogic `2.0-alpha-19`,
GdUnit4 `v6.1.3`, Beehave `v2.9.2`, Phantom Camera `v0.11.0.2` — all MIT (🟢). Exact versions recorded
in `client/addons/THIRD_PARTY.md`; enabled in `client/project.godot`. No floating `main`.

**GdUnit4 is the primary test framework** (TDD §11 — stronger CI integration + mocking). GUT 9.x is the
documented fallback only. GdUnit4 is wired into CI headless (the `godot-tests` job).

**Reference-only (cloned OUTSIDE the repo, NOT committed):** GDQuest **Open-RPG** (MIT) and
**fenix-hub/supabase-examples** (MIT) at `../_reference/`. We adapt **patterns only**, never wholesale
code, and **never into `client/domain/`** (see `docs/Open-RPG_Pattern_Map.md`).

**Curated-subset asset policy:** full third-party packs (Kenney, OpenGameArt, Sonniss GameAudioGDC) live
in a local library `../_asset-library/` (NOT committed; Sonniss is tens of GB / gated). Only **curated
subsets** enter the repo under `client/assets/**`, with binaries via **Git LFS** (`.gitattributes`); the
bulk dirs stay git-ignored. GodotShaders.com (CC0) + project-authored CC0 shaders under
`client/presentation/shaders/`.

**License discipline (R9):** retain each addon's LICENSE (recorded in THIRD_PARTY.md); every 🟡 game-icons
asset is credited in repo-root `CREDITS.md`; CC0 (Kenney, GodotShaders, project shaders) needs none. **No
🔴** (no GPL code, no IP-encumbered/Pokémon-clone assets) is introduced.

## Determinism boundary (critical)

None of these touch `client/domain/` (the pure, parity-tested oracle port — TDD §3.1, enforced by the CI
domain-purity gate). Addons are used from `infrastructure/`/`presentation/`; Open-RPG patterns are adapted
into `application/`/`presentation/`.

**Beehave RNG rule:** Beehave may drive overworld NPC behavior freely, but **any AI decision that affects a
battle outcome MUST draw randomness from the injected canonical RNG sub-stream (ADR-001) — never Beehave's
own randomness or global `randf`/`randi`** — or full-battle replay/parity (TDD §6) breaks. Battle AI lives
in `application/` and *selects* actions; resolution stays in deterministic `domain/`.

## Consequences

- 5 addons load headless in Godot 4.7 with zero errors; GdUnit4 sample + Dialogic smoke + shader/icon
  smoke pass (7/7). One vendored-code change: a 2-line Godot-4.7 compat patch to Dialogic (THIRD_PARTY.md).
- `.uid`/`.import` files are committed (Godot 4.4+ practice) so UIDs resolve on clean clones/CI.
- Heavy/gated asset downloads (full Kenney, OGA tilesets, Sonniss bundle) are documented as manual
  next-steps in `PHASE05_REPORT.md` and the per-folder `PROVENANCE.md` — not auto-fetched this phase.
