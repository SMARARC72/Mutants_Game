# MUTANTS_GAME — Design Bible

**Status:** v0.6 — Signature: **Apotheosis** + **the Succession** · Constructs & Pantheon locked · **Last updated:** 2026-06-25
**Method:** Roundtable + red-team hardening. Design-first; engineering deferred.

---

## 0. North Star

A turn-based creature-collection RPG where you both **befriend and build** life — and ultimately **make gods**. You catch, bond with, evolve, splice, breed, and sacrifice creatures (hand-authored designs animated by a procedural genome) inside a mature-occult world of Greek primordial forces that is grim and funny in equal measure, climbing from gutter-rats to battling — and forging — gods. Every creature is one-of-one; every loss is permanent.

**Locked pillars**

- **Spine:** Tamer × Creator. God-slaying *and god-making* is the destination.
- **Signature:** **Apotheosis → the Succession.** Push a creature/construct (or yourself) to a pure pole to ascend, then **battle, kill, and replace the gods** — and your victorious champion becomes the **world-boss of the next run** (and of your friends' worlds). Unique per save. The game is *about* this.
- **Tone:** Mature occult, *not* pure dread — gallows humor, quirk, chaos over a serious spine. **Funny-grim.** Comedic register ranges by region & character. Ritual & divination are the art *and* UI language.
- **Morality:** Hidden, multi-axis, biological — mutates you *and* your creatures. No on-screen meter. **Player axes: Order⇄Chaos + Purity⇄Corruption** (→ 3×3 grid of 9 emergent gods, see Character doc); creatures' moral axis = Eros⇄Thanatos.
- **Authoring:** **Authored canon + AI uniqueness layer.** Hand-authored designs (base species, named gods, fusion anchors) are the *style bible*; **OpenAI image-gen**, conditioned on that canon, generates each creature's unique look & novel fusions (§5). The authored art controls the AI — it is not replaced by it.
- **Seed-set + division of labor:** the supplied designs (~110 and counting) are the **seed type-set** — the starting point for all types/lines, *not* the final roster. **OpenAI generates images; Claude owns stats, registry, lore, descriptions, and mechanics** (`creature_registry.csv`).
- **Consequences:** Hard / permanent.

---

## 1. The Creature Model

A creature = **Genome (hidden) + Expression (visible)**.

- **Genome:** trait genes, each **dominant or dormant**. Dormant genes surface via breeding, mutation, or moral pressure.
- **Force-vector:** the genome encodes a point in the 3-axis force space (§2). Drives matchups, stats, body, and **purity** (§3).
- **Bond:** tracked per-creature relationship stat; does three jobs (§6).
- **Morality pressure:** how you acquire & raise a creature pressures its genome; the same pressure mutates **you**.

---

## 2. The Forces — 3 opposed axes / 6 poles

| Axis | Pole A | Pole B |
|---|---|---|
| **Order** | **Cosmos** — shields, buffs, control | **Chaos** — variance, mutation, disruption |
| **Life** | **Eros** — healing, growth, summoning *(= mercy)* | **Thanatos** — drain, decay, sacrifice-payoff *(= cruelty)* |
| **Substance** | **Gaia** — HP, defense, terrain | **Ouranos** — speed, energy, initiative |

- **Gods = pure poles.** Primordials are maxed axis-ends; Titans/Olympians are named vectors between them.
- **Eros ⇄ Thanatos is the moral axis.** Mercy → Eros, cruelty → Thanatos.

---

## 2A. Taxonomy — Class × Rank × Tier

Three **orthogonal** axes classify every entity (all carried in `creature_registry.csv`):

- **Class** (how it's made & played): **Organic** — bred, evolved, bonded (Tamer) · **Construct** — built, upgraded (Creator).
- **Rank** (place in the divine ladder): **Wild** (your roster) · **Legendary** (named monster-bosses) · **God** (Olympians/Titans = named force-vectors) · **Primordial** (the 6 pure poles — the ceiling).
- **Tier** (wild evolution stage only): **T1 Base → T2 Mid → T3 Apex.**

Force-blend is independent of all three — a Chaos entity can be Organic or Construct, Wild or God.

---

## 3. The Signature — Apotheosis

**The game's core verb is ascension.** You don't just collect creatures; you raise and remake them toward divinity.

- **Purity:** as you push a creature's force-vector toward one pole (directed breeding, same-pole fusion, sacrificing off-pole traits, raising in matching regions), its **purity** rises.
- **Ascension:** at max purity + a ritual cost, a creature can apotheosize into an **Aspect** (a minor god of that primordial).
- **Bittersweet & permanent:** an ascended creature **leaves your active party** and becomes a *power in the world* — a temple rises, worshippers gather, its region's force-climate tilts toward its pole, new wild creatures appear, NPCs react. You can call on it, but it is no longer a beast in your pocket. *(Funny-grim: your starter wolf is now a minor death-god with opinions about your choices.)*
- **Your save authors its own pantheon.** Which gods you make, of which poles, in which order, reshapes the world uniquely — a *mythology you wrote*. This is the replay engine.
- **The ladder:** Aspects → fuse/combine toward **Titans** (two-pole) and **Olympians** (named) → confront or become a **primordial**. "Battling gods" = facing the poles themselves — sometimes ones you or rivals created.

**Central tension (purity vs. hybridity) + the rule that saves it:** if pure = ascension = strictly best, everyone strips creatures to purity and hybrids die. So ascension is not *better*, it's a **different mode**: a god is the strongest **world-force** but leaves your bench; a maxed **hybrid** is the strongest **battler you keep**. Creator path forges gods; Tamer path keeps a versatile partner forever. Both endgame-valid — the Tamer × Creator spine, holding.

---

## 3A. The Pantheon — the divine ladder

Four rungs, all built from the six forces (a naming + structure layer over the existing vector math — no new math):

1. **Wild creatures** — your roster (base → apex).
2. **Legendary Monsters** — named bosses (Minotaur, Medusa, Cerberus, Harpy, Nemean Lion…); region guardians and gods' servants.
3. **Olympians & Titans** — the pantheon = *named force-vectors* (your demon-lord art is this roster). Zeus = Ouranos+Cosmos · Hades = Thanatos+Gaia · Demeter = Eros+Gaia · Ares = Chaos+Thanatos · **Hephaestus = Cosmos+Gaia (Construct patron)** · Dionysus = Chaos+Eros.
4. **Primordials** — the 6 pure poles. The ceiling.

**Apotheosis climbs *and joins* it:** ascend to **battle, kill, and replace** a god; your save's pantheon becomes partly the gods you made.

## 3B. Constructs — the build-class

A class **orthogonal to force** (a construct still has a force-blend for matchups), embodying the Creator half:

- **Built, not bred:** assembled from parts / materials / souls; upgraded with components, not evolved; can't breed; repairable and rebuildable.
- **Trade-offs:** immune to corruption, disease, aging, bond-loss; vulnerable to Chaos, rust, and soul-effects; obeys without autonomy.
- **Patron:** Hephaestus (Cosmos+Gaia).
- **Machine-gods:** a pure-artifice construct **can apotheosize on its own** into a bronze-colossus forge-god (Talos-class).
- Organic vs Construct = the literal **Tamer (breed/bond) vs Creator (forge/command)** split, through one engine.

## 3C. The Succession — world-boss inheritance (NG+ / friends)

**The endgame loop, and the soul of a friends-game.** Finish a run by taking a throne (killing the gods and ascending) and the game **snapshots your character + your ascended pantheon** into a boss template — a **Dead God.**

- **Next playthrough:** that snapshot seeds the world's apex boss(es). The new protagonist must dethrone *you*. The gods you fight were made by prior runs.
- **Recursive cosmology (lore):** every Olympian/primordial is the petrified record of a past champion — the pantheon is a graveyard of winners; the primordials are the oldest. Power → godhood → becoming the obstacle → being overthrown.
- **Reach (confirmed): both NG+ and friends.** Your champion seeds your own next run AND can be exported so a friend imports it as the bosses in their world. Asynchronous "nemesis" invasion — no live netcode, just snapshot-sharing.
- **Balance:** returning god-bosses scale to climactic-but-beatable, with an optional unscaled "true god" superboss tier.
- *Data: needs a "god snapshot" schema (character build + team forms + vectors + signature moves) — an extension of the registry.*

---

## 4. The Five Verbs

| Verb | Input | Output | Cost / Reversibility |
|---|---|---|---|
| **Evolve** | 1 creature + condition | branches to one of several forms | cheap; mostly reversible |
| **Mutate** | 1 creature + catalyst | semi-random trait shift; surfaces dormant genes | risk of backfire |
| **Fuse** | 2 creatures (consumed) | 1 creature, blended vectors + traits | permanent; inputs destroyed |
| **Breed** | 2 creatures (kept) | offspring egg via dominant/recessive rules | slow; generational |
| **Sacrifice** | creature(s) (destroyed) | permanent upgrade to a beast **or to you** | corruption cost; permanent |

All five double as **tools of purification** feeding §3.

---

## 4A. The Lab — the Creator engine  *(flagged DEEP — the moat; never surface-level)*

The mad-scientist half is the game's moat and must be as deep as battle and leveling. The **Lab** is the bench where these interlock — each gets the roundtable + validation treatment, with real inputs, trade-offs, risk, and theorycraft:

- **Mutation** — directed *and* random. Mutagens/catalysts (force-tinged, environmental, moral) push the genome → stat shifts, dormant-gene surfacing, new traits, or unstable mis-mutations (entropy). A toolkit you aim, not a dice button.
- **Lab-build (constructs)** — assemble from **blueprints + parts/kits + a power source**; quality scales with components and craft. The Creator's "breeding."
- **Sacrifice** — an altar economy: feed creatures/souls to empower another, surface genes, pay rituals (recovery, ascension), or fund forbidden work — at a corruption cost.
- **Fusion / combination** — the synthesis web: fuse two+ beasts into chimeras (iconic results authored, long-tail AI-gen); **taboo fusions** = abominations the world hunts.
- **Modding beasts** — augment *living* creatures with installable parts: grafts, organs, plating, cybernetics, sigil-mods, gene-vials. The **organic↔construct bridge** (graft construct parts onto a beast → the "living core" route to machine-godhood). **Whole-creature augments (no body-slots)**, with trade-offs and rejection/instability risk.

**Lab model (round 1 locked):** **whole-creature operations** (not modular anatomy); **parts = ingredients** consumed by ops, harvested from all four sources (own-sacrifice · defeated/wild · boss/god organs · black market); **dual cost ledger** (routine → creature entropy; big/taboo → *player* corruption; scaling); **precision spectrum** per op (Cosmos-precise/costly ↔ Chaos-wild/cheap).
- **Kits & parts** — the component inventory powering modding & building: **harvested** from defeated/sacrificed creatures and constructs (a limb, a heart, a core, a gland), crafted, or found.

**✓ v0.1 designed & validated** — full spec in `Mutants_Game_Lab.md`, reference impl `lab_engine.py`. Round-2 locks: full ingredient taxonomy (organs/genes/cores/scrap) × all 4 harvest sources; **precise↔wild** method; **freeform + discoverable recipes**; **dual cost ledger** (creature entropy / player corruption); **all taboo work unlocked** (cross-force abominations, god-organ grafts, **splice-yourself**, **reanimate the dead incl. Succession snapshots**); corruption = new powers + locked pure paths.

---

## 5. Expression Pipeline — authored art, procedural soul

Art is **authored & supplied** as the style canon; key forms, named gods & iconic fusions are bespoke designs in a synthesis web, while **OpenAI image-gen (conditioned on that canon)** produces unique individuals and long-tail fusions. The genome layer sits on top:

`authored form + genome → { stat block, ability pool, unique sigil }`

- **Body:** authored design set by the synthesis web, or by dominant blend for wild catches.
- **Stats:** procedurally derived from the force-vector.
- **Sigil:** procedural overlay unique to each individual (feeds §8).
- **Abilities:** from force-pools weighted by the blend.

**Image-gen architecture (OpenAI):** the authored art is the *style anchor*, not the entire supply. OpenAI image-gen (image-reference / style-conditioned from the authored bases) produces the **unique individuals, fusions, mutations, and ascended-god forms** that make every creature truly one-of-one — kept on-model by the authored reference set. Design laws:
- **Generate once, persist forever** — a creature's image + prompt + seed + genome are saved with it; appearance never changes on reload.
- **Authored fallback** — if generation is pending/unavailable, the authored base body shows. No hard runtime dependency mid-battle.
- **Genome → prompt** — the force-vector, traits, and sigil deterministically build the prompt.
- *Risks to solve at engineering:* per-image latency & cost (cache/pre-gen), style drift (strong refs/seeds), content-moderation on grotesque/occult prompts, offline play, output usage terms. Confirm current model + pricing when we build.

---

## 6. Bond — does three jobs

- **Power:** high bond unlocks exclusive evolutions & synergies rivaling sacrifice.
- **Lab-gate:** only trusted creatures submit to fusion/splicing; low-bond ops corrupt or fail.
- **Autonomy:** bonded creatures act independently, fight harder, can refuse cruel orders.

---

## 7. Battle Resolution

**Hybrid:** full vector math under the hood; players see simple per-axis advantage cues. Deep engine, teachable surface.

---

## 8. Attachment — the Creature-Soul (layered)

- **Sigil + true name** — one-of-one signature over an authored body.
- **Lineage & history** — visible ancestry; who was bred / fused / sacrificed to make it.
- **Bond memories** — named traits earned through play.

---

## 9. Acquisition — multiple paths, morality-flavored

**Befriend** / **Trap** / **Summon** — each feeds your hidden morality axes.

---

## 10. The Roundtable (subsystem owners)

Geneticist (genetics / soul economy / archaeology) · "Hongo" (evolution & fusion trees / temperament) · physicist (force matrix / environmental expression) · Dracula (lineage / instability / taboo fusions) · Alice (overworld zones / tonal layer / the Graveyard) · **Hawking (apotheosis & cosmic scaling — now signature-critical)** · John Wick (factions / reactive world).

---

## 11. Open — next pillars

- **Character & morality** — your progression, rank ladder, the other morality axes, **whether you apotheosize too** (current question).
- **Apotheosis specifics** — ascension cost, how "reshapes the world" works, repeatable vs. climactic (current questions).
- **Battle system** — turn flow, action economy, stat list, statuses, party size.
- **World & mythology** — regions, pantheon, how (pre-existing) gods gate progression.
- **Story spine** — plot, demigod premise, endings.
- **Verb gates & economy** — what stops a turn-1 god-beast.
- **Writing voice** — executing the regional comedic registers.

---

## 12. Systems supporting the signature + candidates

**Now core (they are the plumbing of Apotheosis):**
- **Soul economy** — defeated/sacrificed creatures leave essences = the currency for the ascension ritual (and summon / gene-edit).
- **Instability / Corruption** — purification destabilizes; over-pushed creatures can go feral, mutate off-leash, or die before they ascend. The risk on the path to godhood.
- **Genetic archaeology** — excavate rare pure ancestral genes to reach max purity. The breeding endgame.

**Still candidate (flavor / depth):**
- **Temperament / Will** — personality driving battle AI, lab-consent, dialogue.
- **Taboo fusions** — abominations: huge power, instability spike, factions hunt you.
- **Environmental expression** — where you raise/breed/mutate changes which genes surface.
- **The Graveyard** — headstones + epitaphs for the lost/fused/sacrificed; your save's funny-grim history.
- *(meta, later)* run-seeds / NG+ echoes; faction-locked exclusives.

---

## 13. Progression, stats & scaling engine  *(in progress — registry & classes complete; **stat spine v0.2 locked**)*

Goal: **difficult and deeply rewarding**, with theorycrafting depth that never runs out.

- **Leveling — ✓ v0.1 built** (`level_engine.py`): **pure-awakening** growth, *no XP bar*. Combat XP → Luck-rolled **resonance awakenings** (stat surge / dormant-gene / branch); **overclock** to force them at the cost of **entropy** (= the Instability meter); **burnout** if too high (harsh, recoverable); **regress** to purge entropy −45 + unlock a lesser-form trick (down=up). Raisable ceiling; world scales to deeds. *(Character rank ladder still to layer on.)*
- **Battle — ✓ v0.1 built** (`battle_engine.py`, `Mutants_Game_Battle.md`): turn-based core (HP, Celerity init, **shared AP**) + **vector-clash damage** (opposed ×1.5 / same ×0.7, simple cues) + **entropy escalation clock** + **resonance** (same-force chain · combo skills · cross-force overload) + squad 3–5 **real permadeath → Lab parts + Graveyard** (reanimatable). ✓ **Balance pass done** — HP now Vitality-driven (`HPBASE+3·Vit`, Bulk = mitigation only), ratio damage (K=1.5), steeper entropy; even 3v3 resolves in ~7 turns, tank durable-but-killable, supports chip.
- **Status effects — ✓ v0.1 built** (`status_engine.py`, `Mutants_Game_Status.md`): **6 force-signature statuses** (Petrify·Shock·Seal·Madness·Bloom-rot·Wither) + **unified Corruption meta-meter** (overclock-entropy + Lab + afflictions → burnout/feral). Hybrid stacking (DOTs stack, control refreshes); bounded severity; cleansed by Mend/dispel (Corruption persists).
- **Stats — ✓ v0.2 locked:** HYBRID = 6 **pole-stats** (one per force) + 2 universals (Luck, Focus); `floor + force-weighted bonus × wide ±35% genome × brutal tier/rank budget` (god ≈ 7.75× base), + construct mods. Spec: `Mutants_Game_StatSpine.md` · engine: `stat_engine.py`.
- **Skills — ✓ v0.1 built** (`skill_engine.py`, `Mutants_Game_Skills.md`): **force-pool trees** (primary full + secondary partial, teachable/swappable) + **8 verbs** (Strike/Drain/Ward/Mend/Hex/Rouse/Summon/Gambit) + AP+Focus cost + signature moves + **combos discovered by pairing**; learned 4 ways (awakening · Lab transplant · breeding · skill-vials); **ranks** (resource invest). Supports validated. ⚠ tuning notes: Gambits one-shot, shields need a cap.
- **Character ladder — ✓ v0.1 built** (`character_engine.py`, `Mutants_Game_Character.md`): the PLAYER is **narrative-driven** (not a stat-creature) — climbs the god-ladder (Mortal→Primordial) via **deeds/notoriety + corruption**; **2 morality axes** (Order⇄Chaos, Purity⇄Corruption) → a **3×3 grid of 9 emergent gods**; gated notoriety reactions; command + personal force-powers in combat; branching endgame = **ascend (→ Succession boss) or stay mortal God-Maker**. Validated: 3 runs → Lawgiver / Devourer / God-Maker.
- **Genetics:** dominant/dormant genes → hidden potential (IV/EV-style ceilings) bred and mutated for — the min-max / theorycraft endgame.
- **Scaling:** a coherent exponential power-law (Hawking) from rats to gods; the Succession scales bosses to prior champions.
- **Difficulty ↔ reward:** hard/permanent consequences, instability risk, purity-vs-hybridity tradeoffs, god-tier counters; rewards = one-of-one creatures, fusion/gene discovery, registry completion, and thrones.

---

## 14. Tech stack (deferred to engineering)

- **Images:** OpenAI image-gen, conditioned on the authored canon (§5).
- **Databases:** **Supabase (Postgres).** The creature registry and game/save state port here when we build — `creature_registry.csv` is already a clean relational schema (one row per entity), and `stat_engine.py` is pure functions that become app logic / Postgres or edge functions. The Succession "god snapshots" (§3C) also live here.
- **Logic & content:** Claude (stats, registry, lore, mechanics).

---

## 15. World, story & extended systems (orchestrated build · 2026-06-27)

Built autonomously via the roundtable under full delegation. Each has its own doc:

- **World & mythology** — `Mutants_Game_World.md` — cosmology; 8 force-regions + Threshold hub; the 33 god-rank creatures mapped to the Greek Pantheon.
- **Factions & clans** — `Mutants_Game_Factions.md` — 9 factions placed on the morality grid; standing tiers; the clan/competition loop.
- **Story spine** — `Mutants_Game_Story.md` — 4 acts (Mortal→God); grid-driven branching; endings (9 ascensions · the God-Maker · the Unmaking).
- **Bosses, rivals & competitions** — `Mutants_Game_Bosses_Rivals.md` — boss tiers; the nemesis-rival system; 6 competition types (the "fight other trainers" loop).
- **Loot & gear** — `Mutants_Game_Loot_Gear.md` + `loot_engine.py` — 5 player slots boosting capture/tame/breed/lab/combat **chances** (validated).
- **Acquisition & husbandry** — `Mutants_Game_Acquisition_Husbandry.md` — befriend/trap/summon + the breeding/IV chase (Tamer mirror of the Lab).
- **Overworld & exploration** — `Mutants_Game_Overworld.md` — tile-based world; force-climates; reality-warping zones; secrets.
- **Economy & items** — `Mutants_Game_Economy.md` — Drachma/Essence/Ichor; the soul-economy keystone.
- **NPCs & world reactivity** — `Mutants_Game_NPCs_Reactivity.md` — gated, choice-driven world change.
- **Game loop & session flow** — `Mutants_Game_GameLoop.md` — the through-line that interlocks every system.

*In progress: data model & tech architecture · wire-one-full-line vertical proof · balance pass + master index.*

---

## Decision Log

- **2026-06-25** — Locked: Tamer × Creator; mature occult; hidden multi-axis biological morality; creature engine first; Greek primordial forces (3 axes); hard/permanent; bond (3 roles); hybrid battle math; layered creature-soul; multi-path acquisition.
- **2026-06-25 (amend 1)** — Tone → funny-grim (Alice owns it). Art → authored & supplied.
- **2026-06-25 (amend 2)** — Art model → curated fusion-result art (synthesis web). Humor → range across registers.
- **2026-06-25 (amend 3)** — **Signature locked: Apotheosis.** Game reorients around making gods; purity vs. hybridity is the central tension; Soul economy + Instability + Genetic archaeology promoted to core supports. First 10 base designs received (see Bestiary), tiered mixed.
- **2026-06-25 (amend 4)** — **OpenAI image-gen** adopted as the uniqueness layer over authored canon (authored art = style control, not replaced). More base art received (storybook batch). Open: AI scope, generation timing, mature-content moderation.
- **2026-06-25 (amend 5)** — **Division of labor locked:** OpenAI generates images; **Claude owns stats, registry, lore, descriptions, mechanics.** The ~110 supplied designs are the **seed type-set** (start point for all types, not the final roster). **Creature registry started** (`creature_registry.csv`) — ~110 rows seeded (10 adults + 10 apex-demons + 30 base juveniles confirmed; 60 Set-2 drafted).
- **2026-06-27 (amend 16)** — **Autonomous build COMPLETE.** All remaining blocks designed/built/validated: + Data model (`schema.sql`, 13 tables; OpenAI + Succession modeled), + Vertical slice (`wire_line.py` — all 8 engines on one creature ✔), + Balance pass (anti-one-shot hit-cap applied; tuning checklist). Master index: `Mutants_Game_INDEX.md`. **The full mechanical + world + story design is done & proven in code.** Remaining = content (the 407 codex, parallel session) + a playtest tuning sprint.
- **2026-06-27 (amend 15)** — **Orchestrated world+story+systems build** (full delegation, roundtable-driven): World · Factions · Story · Bosses/Rivals/Competitions · Loot & gear (engine) · Acquisition/Husbandry · Overworld · Economy · NPCs/Reactivity · Game-loop — all locked & documented (§15). User-added systems folded in: player loot/gear that boosts breeding/capture/tame chances, and the rival-trainers/competition loop. Remaining: data model · wire-a-line · balance + master index.
- **2026-06-27 (amend 14)** — **Status effects v0.1 built & validated** (`status_engine.py` + `Mutants_Game_Status.md`): 6 force-signature statuses + **Corruption unified as the single meta-meter** across leveling-entropy / Lab / battle → burnout-feral; hybrid stacking; bounded severity; cleansable (Corruption persists). Combat layer (battle + skills + status) now complete. Also: 407-creature registry (batch 5 +119, balanced); creature-codex handoff prompt written for a parallel session.
- **2026-06-25 (amend 13)** — **Character ladder v0.1 built & validated** (`character_engine.py` + `Mutants_Game_Character.md`): narrative-driven player; deeds+corruption climb; 2 axes (Order⇄Chaos, Purity⇄Corruption) → 3×3 grid of 9 emergent gods; gated notoriety; command + force-powers; branching ascend/God-Maker endgame → Succession. **Morality system now fully defined.** (3 runs validated: Lawgiver / Devourer / God-Maker.)
- **2026-06-25 (amend 12)** — **Skills system v0.1 built & validated** (`skill_engine.py` + `Mutants_Game_Skills.md`): force-pool trees (teachable/swappable) · 8 verbs · AP+Focus · ranks · combos-by-pairing · learned 4 ways. Supports proven (Mend/Ward/Rouse/Drain). Balance notes (playtest sprint): Gambits one-shot, Ward-spam oppressive.
- **2026-06-25 (amend 11)** — **Battle balance pass done**: HP → Vitality-driven (`HPBASE+3·Vit`, Bulk = mitigation only; stat spine v0.2.1) · ratio damage (`K·off²/(off+def)`, K=1.5) · steeper entropy (+12%/turn). Even 3v3 now ~7 turns; tanks durable-but-killable; supports chip (not 0).
- **2026-06-25 (amend 10)** — **Battle system v0.1 built & validated** (`battle_engine.py` + `Mutants_Game_Battle.md`): turn-based core kept + shared AP + vector-clash damage + entropy escalation + resonance combos + real permadeath (→ parts/Graveyard, reanimatable). Sim flagged a **balance issue** (HP pools too fat vs damage; supports deal ~0) — balance pass queued (tuning only).
- **2026-06-25 (amend 9)** — **Lab (Creator engine) v0.1 designed & validated** (`Mutants_Game_Lab.md` + `lab_engine.py`): whole-creature ops; 4 ingredient types × 4 harvest sources; precise↔wild; freeform + recipes; dual cost ledger (creature entropy / player corruption); full taboo ceiling (cross-force abominations, god-organ grafts, self-splice, reanimation incl. Succession snapshots); corruption = powers + locked pure paths.
- **2026-06-25 (amend 8)** — **Leveling engine v0.1 built & validated** (`level_engine.py`): pure-awakening (no XP bar) · resonance roll → awakening · overclock→entropy · burnout (recoverable) → regress. **Creator-engine depth MANDATED** (user): mutations, lab-build, sacrifice, fusion, **modding beasts**, **kits/parts** must be first-class deep systems — captured as **§4A The Lab**, the next major design block.
- **2026-06-25 (amend 7)** — Registry **completed** & **classes locked** (Class×Rank×Tier, §2A). **Stat spine v0.1 drafted & validated** on real creatures — 6 pole-stats (`Mutants_Game_StatSpine.md` + `stat_engine.py`). **Tech: Supabase (Postgres)** chosen for databases at engineering (§14).
- **2026-06-25 (amend 6)** — Batch 3 (+78) cataloged; **188 designs**, full vertical slice. **Constructs locked** = distinct build-class (built not bred; can self-ascend to machine-gods). **Pantheon locked** = 4-rung divine ladder (§3A); apotheosis can take a god's throne. **The Succession locked** (§3C) = your final champion+pantheon become the next run's world-boss, shareable to friends' worlds (async nemesis). New requirement captured: **rich progression/stats/genetics/scaling engine** (§13), to build after registry & classes are complete.
