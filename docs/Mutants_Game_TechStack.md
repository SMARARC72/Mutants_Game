# MUTANTS_GAME — Tech Stack & Architecture (v0.1)

**Status:** reviewed & verified (web-checked 2026-06) · **Target:** desktop · **Last updated:** 2026-06-27
**Principle:** *pick the proven pairing, put secrets behind a server, and don't architect around licenses you don't control.*

---

## The four components → the foundation

| Component | Tech | Role |
|---|---|---|
| **DB** | **Supabase** (Postgres) | data · **Auth** · **Storage** (generated art) · **Realtime** (leaderboards / friends-async) · **Edge Functions** |
| **Engine** | **Godot 4.x** | the game runtime — 2D-tile-native, free/MIT, exports a native **desktop** executable |
| **Front end** | **Godot** (the in-game screens) **+ Vercel/Next.js** (companion web) | game UI is built in Godot; Vercel hosts the **account portal, Succession-sharing site, leaderboards, marketing** |
| **Plumbing** | **Godot↔Supabase addon · Vercel serverless · GitHub + Actions** | integration, secrets, CI/CD |

## Architecture (data flow)

```
 [ Godot desktop client ] --REST/Realtime/Auth/Storage--> [ Supabase ]   (normal reads/writes: player, creatures, save)
          |                         (godot-engine.supabase addon)
          '----HTTPS--> [ Vercel serverless / edge functions ] --> OpenAI image-gen (key server-side)
                                                              --> Succession snapshot sharing
                                                              --> anti-cheat / server-authoritative checks (later)
 [ GitHub ] --Actions--> build Godot desktop exports  +  deploy the Vercel web layer    (Git LFS for art binaries)
```

- **Godot ↔ Supabase** is a supported, out-of-the-box path via the **`supabase-community/godot-engine.supabase`** addon (REST · Realtime · Auth · Storage) in the Godot 4.x Asset Library.
- **Sensitive ops go through Vercel,** never the client: the **OpenAI gen proxy** (gen → store in Supabase Storage → return URL → `art_assets`), Succession sharing, and any server-authoritative validation.

## Where the game logic lives

The reference Python engines (`stat/level/lab/battle/skill/status/loot/character`) become the **canonical spec + test oracle.** For the desktop MVP, **port them to GDScript (client-side)** — simplest for single-player. Keep a thin Vercel server for secrets + sharing; add **server-authoritative** validation later when competitions/leaderboards need to be cheat-resistant. *(Bonus: run the Python engines to generate expected values and assert the GDScript port matches — instant regression tests.)*

## Honest flags (red-team — verified)

1. **Vercel does NOT host a desktop game.** It hosts the **web/serverless layer** (backend API, OpenAI proxy, Succession-sharing site, leaderboards, marketing). The desktop game ships as a **standalone executable** (Steam / itch.io / direct). *(If you ever want it web-playable, Godot exports HTML5 and that build can sit on Vercel — but desktop-first means Vercel = services, not the game.)*
2. **Unity Asset Store assets in Godot = only "non-restricted" ones, per Unity's EULA.** Unity-specific assets (prefabs, C# scripts, shaders, ScriptableObjects) **don't port**; only raw art/audio/standard models do — and only when the asset's license permits non-Unity use, never redistributable/extractable. **Recommendation:** build on your **OpenAI-generated art + engine-neutral/CC0 sources** (Kenney, etc.); treat Unity assets as occasional supplements with a per-asset license check. Don't make them a foundation.

## Gotchas & best practices

- **Supabase RLS** (row-level security) on every table — players touch only their own rows.
- **Never ship the OpenAI key in the client** — proxy via Vercel/edge function.
- **Git LFS** for art (the registry images are large; 1,067 and growing).
- Art-gen is **generate-once → Supabase Storage → persist URL** (`art_assets`).
- Godot **GDScript** as primary; C# only if a library demands it.

## Build foundation order

1. **Repo** (GitHub + LFS) + **Godot 4.x** project + **Supabase** project (apply `schema.sql`, enable RLS).
2. **Plumbing** — Godot↔Supabase auth + CRUD via the addon.
3. **Vercel layer** — OpenAI gen proxy + Succession stub.
4. **Port core engines** (battle/stats/level/lab/loot) to GDScript; test vs. the Python oracle.
5. → **Screens / UX → MVP slice** (the Verdant fringe).

## Verdict

**Sound and well-matched.** Godot + Supabase is a proven, supported pairing; GitHub + Vercel plumb cleanly. The two corrections: **Vercel is the services layer, not the game host**, and **Unity assets are license-checked supplements, not a foundation.** Foundation locked — proceed to UX.

---

*Sources: Godot↔Supabase community addon (github.com/supabase-community/godot-engine.supabase); Unity Asset Store EULA / "use in other engines" (support.unity.com); Vercel for Godot HTML5 vs. desktop-backend role (vercel/github topics).*
