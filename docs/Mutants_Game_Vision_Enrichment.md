# Mutants_Game — Vision & Visual Enrichment (roundtable exploration)

**Status:** exploratory · **Date:** 2026-06-27 · all tools/licenses web-verified. Uses the 🟢/🟡/🔴 license key from `Mutants_Game_Resources.md`.

> **The principle:** *elevate, don't restart.* You have a working engine spine, the open-source scaffold, and 1,000+ painterly creatures. The path to "amazing" is making what exists **move, light up, and feel alive** — not rebuilding it in a new dimension. Everything below is ranked by impact-per-effort.

---

## 1. The biggest win — make creatures + the player **LIVE** (no new art)

Right now beasts are static images. The native, free, MIT path turns them into living sprites **without redrawing anything**: cut each painterly creature into parts (head, jaw, limbs, wings, tail), rig with **Godot `Skeleton2D` + `Polygon2D` mesh-deform**, and drive idle/attack/hurt/death from the engine. Add a shader pass for breathing, sway, blink, and force-glow.

What it unlocks instantly: idle **breathing/sway** (creatures feel alive on the dossier + field), **attack lunges + recoil** in battle, **hit-flash + stagger**, **death slump → parts** (the permadeath beat lands), **awakening/splice "birth" reveal** with mesh-scale + sigil-flare. This single system makes the whole game read as alive.

| Option | License | Best for | Cost |
|---|---|---|---|
| **Godot Skeleton2D cutout + mesh deform** ⭐ | 🟢 MIT (built-in) | Our painterly creatures + player — rig existing art, no redraw | Free; ~1–2 days to build a reusable rig template per body archetype, then fast per-creature |
| **DragonBones** + Godot importer | 🟢 free | Richer 2D skeletal if native isn't enough | Free; heavier pipeline |
| **Spine** (Esoteric) | 🟡 **paid** ($69–$369) + runtime license | Industry-grade 2D skeletal, mesh FFD | Money + license terms — only if native proves limiting |
| **Live2D Cubism** | 🟡 free tier / 🔴 revenue-tier license | "Living portrait" dossier/boss close-ups (breathing illustration) | License gates above a revenue threshold — verify before shipping |

**Player character:** same `Skeleton2D` cutout rig for the top-down avatar (directional + a few emotes), or — if you go hybrid (§3) — a 3D Mixamo-animated model on the 2D map.

**Recommendation:** build the **Skeleton2D cutout rig template** first (one per archetype: biped, quadruped, winged, serpentine, blob, construct). It is the highest-impact, lowest-cost, art-preserving win in the whole project. Reuse across all 1,000+ creatures.

## 2. De-"80s" the world — cheaply, staying 2D

The flat look is a *lighting and depth* problem, not a dimension problem. Four stacked moves get you to "matured 2D":

| Move | Tool | License | Effect |
|---|---|---|---|
| **Dynamic lighting** | **Laigter** → normal/specular/AO maps for tiles+sprites, lit by Godot **`Light2D`** + shadows | 🟢 *(see note)* | Kills the flat 80s read — torches, force-glows, time-of-day all cast real light |
| **Depth** | Godot **parallax layers** + a foreground/atmosphere pass | 🟢 MIT (built-in) | Worlds gain dimensionality without 3D |
| **Atmosphere** | CC0 **GodotShaders** (fog, god-rays, color-grade, vignette, heat-haze) | 🟢 CC0 | The grimoire mood; the "entropy tide" weather |
| **Palette** | recolor curated **Kenney/OGA** tiles to parchment-ink | 🟢 CC0 | The design-bible look (§1/§3.5) |

> **Laigter license note:** the *tool* is GPL-3.0, but the normal/AO maps it generates **for your own art are yours** — output isn't a derivative of the tool's source, so it does **not** infect the game (R9-safe). Use freely.

**Net:** classic-2D-Pokémon structure (which you want) + modern lighting + depth + atmosphere = the "grown-up" look, at a fraction of a 3D budget.

## 3. The 2D-vs-3D decision (honest)

**Recommendation: Elevated 2D / 2.5D — not a full 3D pivot.** Reasoning the roundtable converged on:

- **Preserves the investment.** The TDD, the Godot 2D client, the determinism/parity oracle, the classic-2D overworld design, and — critically — your **1,000+ painterly creature illustrations and the OpenAI art pipeline** are all 2D. A 3D pivot re-opens all of it.
- **The killer cost is 3D *creature* art.** 1,000+ unique 3D monster models is the single most expensive thing in game dev; AI image→3D helps but needs cleanup/retopo/rigging per model. Players don't experience a creature-collector as "low-poly" — your painterly art *is* the product.
- **Elevated-2D reaches "amazing" faster.** §1 + §2 deliver a living, lit, atmospheric game in weeks, on the existing foundation.

**If you still want 3D, here's the costed truth + the open-source stack that makes it viable:**

| Path | Open-source stack (verified) | Honest cost |
|---|---|---|
| **Full 3D** | Creatures via image→3D: **TripoSR**, **TRELLIS.2**, **Stable-Fast-3D** (all 🟢 MIT) or **Hunyuan3D 2.1** (🟡 Tencent license); player + NPCs via **KayKit**/**Quaternius** (🟢 CC0) + **Mixamo** anims (free, commercial-OK) | Re-architect client to 3D; per-creature mesh cleanup + rig + animate; months + ongoing art cost. High risk to the schedule. |
| **Hybrid 2.5D** ⭐ (if any) | 2D world (§2) + **3D player** (Mixamo+KayKit) on it, *or* **billboarded** sprites with normal-mapped lighting | Moderate; gets a 3D "pop" on the avatar/hero moments without 3D-ifying 1,000 creatures |

**Suggested stance:** commit to **elevated-2D now**; keep **hybrid 2.5D** as an optional flourish for the player/boss moments; treat **full-3D** as a possible *sequel/remaster* direction, not this build.

## 4. Low-commitment image→3D experiment (decide with data, not vibes)

Before any 3D commitment, run **TripoSR / TRELLIS.2** (🟢 MIT, local, 6–8 GB VRAM) on **3–5 hero creatures** from your existing art. Evaluate: does stylized painterly art convert cleanly, or does it need heavy cleanup? That one afternoon answers the 3D question empirically and costs nothing. Stable-Fast-3D for speed; TRELLIS.2 for PBR quality.

## 5. Enrichment backlog — to push from "good" to *amazing* (build / bring-in / credit)

| Area | Add | Source / license |
|---|---|---|
| **Living creatures** ⭐ | Skeleton2D rig + idle/attack/hurt/death system | **build** on 🟢 Godot native (§1) |
| **Dynamic lighting** ⭐ | normal-mapped 2D + Light2D + day/night + entropy-tide | **build** w/ 🟢 Laigter + Godot |
| **Audio that reacts** | layered/adaptive music (calm→combat), force-themed stingers | **bring-in** 🟢 Sonniss/Kenney SFX + itch CC0 beds; **build** the layering |
| **Camera & juice** | push-ins on crits, screen-shake, hitstop, slow-mo on kills | **bring-in** 🟢 Phantom Camera + GodotShaders; **build** the triggers |
| **Overworld life** | weather, ambient critters, reactive NPC schedules | **bring-in** 🟢 Beehave; **build** content |
| **Accessibility** | colorblind force-cues (already in design), text scaling, remap | **build** (cheap, high-trust) |
| **"Living portrait" bosses** | Live2D or heavy Skeleton2D on god/boss reveals | 🟡 verify Live2D license, or 🟢 native |

## 6. What the open-source integration already bought you (time-saved accounting)

Rough **solo-developer-equivalent** estimates — order-of-magnitude, not precise. "Saved" = build-from-scratch effort you avoided; integration/adaptation costs some of it back.

| Integrated | Replaced building | Est. saved |
|---|---|---|
| **GDQuest Open-RPG** (MIT patterns) | Turn-based combat structure, grid movement, inventory, dialogue wiring, map transitions | **4–8 weeks** |
| **Supabase Godot addon** + examples | Auth + DB + Realtime + Storage client (sessions, retries) | **2–4 weeks** |
| **Dialogic 2** | A dialogue system **and its editor** | **3–5 weeks** |
| **GodotShaders (CC0)** | The juice/VFX shader library | **2–4 weeks** |
| **game-icons + Kenney + Sonniss** | Icon/UI/tile/SFX **production** for the supplemental layer | **4–8 weeks** |
| **Beehave** | A behavior-tree AI framework | **1–3 weeks** |
| **GdUnit4** | Test framework + CI runner | **1–2 weeks** |
| **Phantom Camera** | Camera/follow/transition system | **1–2 weeks** |
| **PCG32 reference** | Determinism RNG research/impl | **~days** |
| | **Gross** | **~18–36 weeks (≈4.5–9 months)** |
| | **Net after integration tax (~25–35%)** | **≈ 3–6 months of real acceleration** |

**Translation:** the open-source spine has offset roughly a **half-year of solo build effort**, and — just as valuable — handed you *battle-tested* structures (combat loop, auth, dialogue, tests) instead of first-draft ones you'd debug for months. The reference engines stay the oracle; these are the *scaffolding* around them.

## 7. Where this slots into the plan

Open a parallel **"Visual Elevation" track** alongside the gameplay phases (it doesn't touch `domain/` or determinism):

1. **Prototype vertical slice (1–2 weeks):** one creature fully rigged + living (§1) on one **normal-mapped, dynamically-lit** tileset (§2), with camera/juice on a single attack. This *is* the new look — judge "amazing" against it.
2. **Image→3D experiment (1 afternoon, §4)** in parallel — settle the 3D question with data.
3. **Decide direction (§3)** → scale the rig template across archetypes; fold into Phase 5 (MVP screens) so the slice ships looking alive, not flat.

## 8. The decision to make
The one fork that steers the next month: **how far to push the visuals now** — elevated-2D (recommended), add a hybrid-2.5D player flourish, or seriously evaluate full-3D. Everything else above proceeds regardless. *(Asked alongside this doc.)*
