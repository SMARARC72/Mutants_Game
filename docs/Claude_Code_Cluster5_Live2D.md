# CLAUDE CODE — Mutants_Game · Integration Cluster 5: Live2D Premium Portraits (Execution Prompt)

> Run inside the repo, **after the UX shell (Cluster 1) and ideally the living-sprite rig work**. Adds **Live2D "living portrait"** close-ups for the highest-awe moments — fully **modular** with a static fallback. Build to the DoD, then **stop and report**. Presentation-only; nothing touches `client/domain/`.

## 0. Authority
- Normative: `Mutants_Game_Integrations.md` §B7. Visual intent: the creature-soul dossier + god/boss "birth/reveal" awe beat (`Claude_Design_Handoff_Brief.md` §4.2, the design's "living portrait"). Deviations → ADR.

## 1. Scope — gd_cubism + Live2D Cubism (free tier)
- **gd_cubism** (🟢 MIT plugin, Godot 4.3+) + the **Live2D Cubism Core SDK** (🟡 Live2D license). **Free tier is clear now** (no sales, not listing). Vendor pinned under `client/addons/`; record in `THIRD_PARTY.md` **with the license note** below.
- **License note (log it):** the Cubism Core SDK free tier permits commercial use only under **~¥10M (~$67k) annual sales**; above that requires a paid Cubism SDK Publication/Business license. **Re-evaluate at that revenue threshold.** The gd_cubism *plugin* is MIT; the *runtime SDK* is the gated part.

## 2. Deliverables

### D1 — `PortraitView` facade (modular, with static fallback)
`presentation/portrait/portrait_view.gd`: **`show(subject, mode)`** renders a **Live2D model if one exists for the subject, else falls back to a static image** (the existing painterly art). Live2D content is **isolated** so the dossier/reveal **never hard-depends** on it — removing Live2D degrades gracefully to static, never breaks.

### D2 — Wire to the awe beats
- **Creature-soul dossier** close-up (breathing portrait) and **god/boss reveal** beats (the birth/ascension moment, with sigil-flare from the juice layer).
- A couple of **sample Live2D-rigged hero portraits** (or a clearly-marked stub model) proving the pipeline end-to-end; everything else uses the static fallback until rigged.

### D3 — Performance + isolation
- Live2D portraits load on demand (not preloaded for every creature); confined to portrait contexts (dossier/reveal), not the field. Confirm no frame-budget regression on the dossier screen.

## 3. Guardrails
- **Presentation-only**; nothing in `client/domain/`; no gameplay effect.
- **Modular/swappable:** the static-image fallback path is the default; Live2D is an enhancement layer behind `PortraitView`. The game must run fully with Live2D absent.
- **License recorded** in `THIRD_PARTY.md` + the license inventory, with the **re-evaluate-at-revenue** reminder. Keep Live2D assets in their own folder so they're easy to remove if the licensing calculus ever changes.
- Pinned versions recorded; CI green.

## 4. Definition of Done
1. gd_cubism vendored + loads in Godot 4.7; Live2D SDK license recorded with the revenue-threshold note.
2. `PortraitView.show()` renders a **breathing Live2D portrait** on the dossier and a **boss reveal**, and **falls back cleanly to static** when no model exists for a subject.
3. The game runs fully with the Live2D folder removed (graceful degradation proven).
4. No dossier-screen frame-budget regression.
5. Nothing in `client/domain/`; project opens headless clean; CI green.
6. `PHASE_Cluster5_REPORT.md` written. **STOP** — all integration clusters complete; hand back the report.

## 5. Done with integrations
After this, the adopted open-source set (Clusters 1–5) is fully integrated, each behind a facade, none in `domain/`, the oracle + determinism intact. Remaining work is gameplay content + the Visual Elevation track + the MVP slice per the TDD runway.
