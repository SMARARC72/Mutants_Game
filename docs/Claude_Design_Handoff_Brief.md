# HANDOFF BRIEF — Mutants_Game: UX/UI & Prototype (for Claude design)

> Paste into a Claude design session (opened with access to the `Mutants_Game` project files where possible). **Goal:** design **all the screens** and a **clickable prototype** — starting with the MVP, in the game's specific funny-grim occult style. You have nothing from prior conversations; this brief + the referenced docs are your complete instructions.

---

## 0. What you're designing

**Mutants_Game** — a *funny-grim, mature-occult creature-collection RPG* (Pokémon × Final Fantasy × Frankenstein): you catch, breed, **splice**, and **ascend** force-born beasts in a world of dead Greek gods, climbing from gutter-rat to throne. **Platform:** desktop (built in **Godot 4.x**, Control-node UI). **Audience:** the creator + friends; depth-loving players. The full design lives in the project docs (see §7); this brief is your UX/UI mandate.

## 1. Tone & visual direction (read first — this is the soul)

- **Funny-grim, mature occult.** Not sci-fi HUDs, not cute mascot UI. Think **grimoires, sigils, altars, bestiary plates, divination.** Dread with a wink.
- **Divination IS the UI language.** Stats are *scryed* readouts, not spreadsheets. The motto from the design is **"deep engine, simple surface"** — show a clean, legible cue on top; reveal the depth on demand (hover/expand).
- **The creature art** is authored/AI-generated painterly concept art with glowing **sigil-marks** (see `art/montage_*.png`). The UI should frame creatures like **illustrated codex plates**, and the procedural per-creature **sigil** is the one-of-one identity motif — use it everywhere (dossier, capture, ascension).
- **Microcopy** carries the gallows humor: every label, tooltip, and empty state has a dry, in-world voice (e.g. a fainted creature: *"…filed for emancipation."*).
- **Overworld = classic 2D Pokémon skeleton, genuinely twisted.** The *foundation* is the old-school top-down tile RPG everyone knows (GB/GBA/DS-era Pokémon): grid movement, a visible avatar, encounter zones, bump-to-talk NPCs, doors/warps, a world you *walk*. That familiarity is the **hook** — but we **diverge hard** from there (full detail in §3.5): mature occult art direction, our own creatures/tiles/biomes, **real movement & traversal twists**, **humor-soaked NPCs**, and **absurdist encounters**. The goal: it reads as "oh, *that* kind of game" for about ten seconds — then it gets weird, funny, and unsettling and you realize it's its own animal.
- **Doesn't take itself too seriously.** The occult dread is real and the stakes mean it — but the world has a sense of humor about itself: gallows humor, deadpan self-deprecation, and the *occasional, rare* fourth-wall crack. The dark lands harder *because* it lets you laugh first.

## 1.5 The roundtable's UX mandate (apply these lenses to every screen)

Design with the full table in the room — each persona owns a pillar; resolve tensions in favor of *fun that lasts*:

- **The Digimon-maker — the creature bond.** Evolution/mutation/awakening must be a **moment**, not a stat change: animation, sigil-flare, a name reveal, a beat of awe. Collection screens should make you *want one more*.
- **Alice (gleefully unhinged) — whimsy, chaos & the absurd.** Inject delight and the unexpected: reactive flourishes, absurd-but-in-world microcopy, non-combat oddball encounters, surprises that reward curiosity, the rare fourth-wall wink. Never sterile, never safe.
- **Hawking — information architecture & accessibility.** Ruthless clarity under the flourish. Every screen answers "what do I do / what just happened / what's at stake" at a glance. Colorblind-safe, legible, no cognitive overload. *Deep engine, simple surface.*
- **Dracula — mood & dread.** Gothic elegance and weight. Permadeath, corruption, and consequence must *feel* heavy and beautiful. The grim half of funny-grim.
- **John Wick — economy of motion.** Snappy, precise, no wasted input. Core-loop actions reachable in minimal clicks; controls tight and responsive; nothing makes the player wait on ceremony they've seen 100 times (skippable).
- **The physicist (on molly) — juice & flow.** Owns **game feel** (see §4.5): the second-to-second feedback that makes everything satisfying. Flow state, never friction.
- **The cloning geneticist — the Lab.** The creation table is the showpiece: tactile, alive, consequential, *fun to fail at* (see §4, Lab).

## 2. Design-system seeds — the Force palette & iconography

Six primordial forces drive everything; each needs a **color + motif + icon**. Pair color with **shape/icon** (colorblind-safe).

| Force | Stat | Palette | Motif |
|---|---|---|---|
| **Gaia** | Bulk | deep moss + granite brown | stone, bark, heavy |
| **Ouranos** | Celerity | silver-blue + cyan | feathers, wind, lightning |
| **Cosmos** | Ward | white-gold + pale azure | halos, crystalline geometry |
| **Chaos** | Spike | hot magenta + oil-slick iridescence | jagged, glitching, fractured |
| **Eros** | Vitality | rose + honey-gold + verdant | blossoms, vines |
| **Thanatos** | Bane | violet + sickly-teal soul-fire on charcoal | bone, ash, decay |

- **Corruption** (the meta-meter): a creeping **bruise-purple/green** rot accent that intensifies as it fills.
- **Base UI:** aged **parchment** (light surfaces) + deep **occult ink/charcoal** (dark surfaces) with **brass/gold sigil linework.**
- **Also need icons for:** the 8 skill verbs (Strike, Drain, Ward, Mend, Hex, Rouse, Summon, Gambit), the 6 statuses (Petrify, Shock, Seal, Madness, Bloom-rot, Wither), tiers/ranks, the 3 currencies (Drachma, Essence, Ichor).

## 3. Screen inventory (design MVP first ★, then the rest)

**★ MVP screens:** Title / Main menu · **Overworld map** (top-down tile) · Wild-encounter intro · **Battle** · Party/Team · **Creature Dossier** · Catch / capture result · **The Lab** (fuse + mutate only) · Bestiary / registry · Inventory & Gear · basic Shop / market · Save & Settings.

**Post-MVP:** Character **Ascension grid** (the 9-god morality map) · Factions & standing · Competitions / Arena · the **Succession** / friends-invasion · full Lab (build/mod/self-splice/sacrifice) · Breeding/husbandry · region world-map.

## 3.5 The overworld has a *personality* — don't just reskin Pokémon

The classic skeleton is the familiar handhold, not the destination. Four things make the overworld unmistakably ours (roundtable-led — Alice on absurdism, Wick on movement, Dracula holding the dread floor, Hawking keeping it legible):

**A. Movement & traversal twists — real mechanics, not a run button.** Give the player verbs beyond "walk the grid":

- **Ley-line step / sigil-dash** — short ritual dashes along glowing ley-lines etched into the ground; a traversal *skill* with feel and timing, not a teleport menu.
- **Your lead creature walks with you** (HG/SS-style) and *reacts* — emotes at thin places, sniffs out buried parts/secrets, recoils from cursed ground. Bond made visible in the field.
- **Diegetic terrain gates (occult "HMs," done right)** — rubble a Gaia brute shoulders aside, chasms an Ouranos flyer ferries you over, death-veils only a Thanatos creature can part. Traversal rewards a varied team — never a chore-mon "HM slave."
- **The world mutates with you** — as corruption/morality shift, the tile palette, ambient audio, NPC reactions, and even spawn tables drift. The overworld is a *living morality readout* you physically walk through.
- **The entropy tide / occult weather** — a creeping condition (time-of-day × corruption) that changes spawns and makes the map stranger, eerier, and funnier at its peak.
- **Ritual-circle fast travel** (the Threshold network) instead of a bird.

**B. Encounter zones with teeth and wit.** Tall grass becomes **"thin places"**: shimmering veil-tiles that whisper (audio cue), telegraph their risk, and occasionally *misbehave* — a thin place that coughs up a creature far above the local tier is a scare *and* a story. And not every encounter is a fight (see C).

**C. Absurdist & non-combat encounters — Alice's domain.** Hand-placed beats that subvert the "wild creature appears → battle" reflex and reward exploring:

- A creature that **refuses to fight** and just wants to vent about its day.
- A back-alley **bureaucrat of the underworld** who processes your sins in triplicate.
- A cheerful merchant hawking *obviously* cursed goods with a sunny disclaimer ("non-refundable; also it screams at night").
- A doomsday preacher who is confidently, repeatedly wrong about the apocalypse.
- A creature trapped in a slapstick loop you can free — or pointedly not.

Rare, screenshot-worthy, discovery-rewarding — never wallpaper.

**D. NPC humor & the tonal contract.** NPCs carry the **gallows humor, self-deprecation, and the rare fourth-wall crack**:

- Deadpan-grim townsfolk who comment on the absurdity, on your rising notoriety, on game conventions themselves ("you've talked to me five times; I'm out of lines, and frankly, so are you").
- NPC dialogue that **shifts with your corruption** — neighborly → uneasy → terrified → worshipful — played for dark comedy as much as dread.
- **Rare** fourth-wall moments: a signpost that uses your save name; an NPC who suspects it's all a game and is *deeply* unwell about it; a "ghost in the code" cameo that shouldn't be there.

**The tonal contract (Dracula + Hawking hold the line):** dread is the **bedrock**; humor is the **relief valve** — gallows, deadpan, self-aware, *never* quippy-Marvel or zany-for-its-own-sake. The world genuinely unsettles and means its stakes; the jokes make the dark land *harder* by contrast. Fourth-wall breaks stay **rare and a little wrong** — unsettling-funny, not a running gag. **Litmus test:** *if a moment makes you laugh and then slightly regret laughing, it's on-tone.*

## 4. Key UX flows (the hard problems — solve these well)

1. **Core loop:** Overworld → encounter → Battle → catch/defeat → Lab/level → back out. **Overworld** plays as a classic 2D top-down tile RPG (see §1) — walking the world *is* the fun; encounters trigger from grass/ritual zones with a snappy, mood-setting transition (not a long loading screen). Make transitions feel **ritual but fast** — and skippable once seen.
2. **Battle (the crux).** Deep engine, *electric* surface — HP, shared squad AP, Celerity turn order, the force-advantage clash cue, the entropy clock, resonance combos, statuses, the overclock gamble. Full concrete-divergence + dopamine treatment in **§4.1**.
3. **The Lab — *alive* and *fun*.** A living occult creation table: creature(s) + ingredients + a method slider (precise ↔ wild) → a live cost ledger → result preview → the reveal. Full concrete-divergence + dopamine treatment in **§4.2**.
4. **Creature Dossier — the "creature-soul".** One screen layering: the **unique sigil + name**, the **stat block** (scryed, not tabular), **lineage tree**, **bond**, skills, status, and **Corruption** meter. This is the emotional anchor (permadeath must hurt).

## 4.1 Battle — deep engine, *electric* surface (concrete divergence + dopamine)

Standard turn-based is the handhold; the signature systems make it ours. Each is a UX problem of "show the decision, hide the math, make it *feel* incredible" (roundtable — physicist on juice, Wick on snap, Digimon-maker on the creature spotlight, Hawking on legibility, Dracula on stakes):

**What's mechanically ours (and how it should feel):**

- **Shared squad AP pool — battle is a resource-allocation puzzle**, not one-move-per-creature. You spend a communal pool across the team each turn (dump it on one nuke? spread it thin?). Surface: a tactile AP track that drains and refills in satisfying *chunks*; spending feels like committing chips.
- **Vector-clash force advantage — no type chart to memorize.** A live "your *force* overwhelms theirs" cue, and the damage swings hard on advantage. Surface: the two forces visibly *collide* on the hit — advantage = a bigger, brighter, louder collision. You read the matchup by watching it, not studying a grid.
- **The entropy clock — a built-in tension crescendo.** Every turn the whole battlefield gets deadlier (damage ramps for everyone). Surface: a rising clock with mounting heat — color, audio, and screen energy climb — pushing you to *act*, punishing stalling. Battles build to a climax instead of dragging.
- **Resonance combos — the skill-expression hit.** Pairing same-force or specific creatures lights a **combo prompt** mid-turn; landing it triggers a chained, screen-popping payoff. Surface: a flashing prompt → a chain animation → a damage crescendo. This is the "I'm a genius" dopamine spike.
- **The overclock gamble — legible risk, euphoric reward.** Push toward a force-awakening mid-fight for a burst, banking entropy/corruption. Surface: a high-stakes button with a visible risk/reward readout; success = an euphoric power surge, failure = burnout drama. The gamble is *thrilling*, never opaque.
- **Real permadeath (Dracula).** A downed creature can truly die → parts/Graveyard. Death is **mournful and beautiful**, never a flat "fainted" — and that weight is exactly what makes the wins land.

**Dopamine choreography (second-to-second):** impact frames + force-collision flash + damage-scaled screen-shake + numbers that *pop and arc* + crunchy sound on every hit · anticipation→release on the big swings (overclock, resonance, a kill) · the whole presentation intensifying as entropy climbs · **snappy, skippable** animations with speed/auto options (Wick — never wait on the same anim twice) · attacks that **frame the creature with personality** (the Digimon-maker's spotlight beat).

**Readability guardrail (Hawking):** the deep math — vector-clash, entropy multiplier, AP economy, resonance windows — stays *under* the surface. What the player sees at a glance: *this is strong · this is risky · this is the moment.* **Deep engine, electric surface.**

## 4.2 The Lab — a *living* creation table (concrete divergence + dopamine)

The Lab is the showpiece. It must feel **alive, tactile, and a little dangerous** — a workbench that *breathes*, not a form with a Submit button (roundtable — the geneticist owns the creation UX, physicist on juice, Alice on surprise, Dracula on consequence, Digimon-maker on the reveal, Hawking on the ledger):

**What makes it alive (and how it should feel):**

- **The table reacts in real time.** As you drag ingredients in and move the method dial, the apparatus responds — ingredients bubble/spark/strain, the cost ledger updates live, the result-preview silhouette morphs. Every input has an immediate physical consequence on screen.
- **The method slider (precise ↔ wild) — feel the risk you dial in.** Cosmos-precise = controlled, costly, predictable; Chaos-wild = cheap, volatile, surprising. Surface: sliding toward wild visibly **destabilizes the whole rig** — more shake, more sparks, the preview flickering between possible outcomes. You can *see* the gamble grow.
- **Live cost ledger (Hawking).** Entropy/creature and corruption/player tick up visibly as you push toward taboo. A clear, mounting ledger makes "is this worth it?" a legible gut-check — with dread-colored escalation as you approach the forbidden.
- **The commit is a ritual, not a click.** A tactile "seal the rite / pull the lever / drive the needle" action with weight and a held breath before the result.
- **The reveal — the Lab's signature dopamine hit.** The new/changed creature emerges in a crescendo: light, sigil-flare, the name resolving, a beat of awe. It should feel like *birth*, every single time (the Digimon-maker's moment).
- **Discovery & surprise (Alice).** Wild-method and unknown combos yield the unexpected — a surprise trait, an off-table abomination, a "you have *no idea* what you just made." Failure can be hilarious or horrifying; both are *fun to get*.
- **Consequences that bite (Dracula).** A botched splice, a burnout, a corruption spike lands as a real, visible, gorgeous loss — never a greyed-out error. The sting is the price that makes the wins euphoric.

**The core tension (why it's addictive):** *real stakes + juicy payoff, every pull.* You always know it might cost you, and you always want to do it again. **"One more splice."**

**Dopamine choreography:** reactive feedback at *every* step (drag-in, dial, ledger tick, commit, reveal) · anticipation→release across the commit→reveal (held breath → birth flash) · escalating spectacle for bigger/taboo ops (a god-organ graft is an *event*, screen-wide) · tactile-everywhere UI — the bench is satisfying just to touch.

## 4.5 Game feel — the dopamine layer (cross-cutting, non-negotiable)

Every action in the loop should land a **little hit of satisfaction**. This isn't polish-for-later; it's a core design pillar. Apply across **every** screen:

- **Reward the verbs.** Hits, catches, level-awakenings, splices, loot drops, faction gains — each gets layered feedback: motion, a flash/particle/sigil-flare, a sound cue, a number that *pops*, a beat of anticipation → payoff. Catching a creature and a successful splice should feel *great* every single time.
- **Anticipation → release.** Build a tiny tension before outcomes (the catch wobble, the resonance roll, the Lab reveal) so the payoff reads as earned, not automatic.
- **Escalating crescendos.** Bigger moments (boss kill, Legendary catch, a god-tier mutation, an ascension) get proportionally bigger juice — screen-wide, memorable, screenshot-worthy.
- **Snappy and responsive (John Wick).** Instant feedback on input; never make the player wait on animation they've seen before — let them skip/speed it. Satisfaction comes from *flow*, not slowness.
- **Tactile UI.** Buttons, sliders, drag-targets respond physically (hover, press, settle). The interface itself feels good to touch.
- **Real stakes make the highs higher.** Permadeath, corruption, and botched experiments must *sting* (Dracula's weight) — that contrast is exactly what makes the wins euphoric. Juice the losses too: a death is mournful and beautiful, not a flat "fainted."

**The test:** a playtester should feel a pull to do the loop *one more time* — and the satisfaction should hold from the first catch to the last god-battle.

## 5. Constraints

- **Godot 4.x Control-node UI**; desktop **1920×1080 baseline**, scalable.
- **Readable at a glance**; depth on hover/expand. Colorblind-safe (color **+** icon/shape always).
- Performance-light (panels/sprites, not video).
- Funny-grim microcopy throughout.

## 6. Deliverables

1. A **design system / style guide** (palette, type, components, iconography, the sigil language).
2. **Wireframes → hi-fi mockups** for every ★ MVP screen — including the **classic-2D overworld** look (tile/biome art direction, avatar, encounter zones) per §1.
3. A **clickable prototype** of the core loop (Overworld → Battle → Catch → Lab → Dossier) that demonstrates the **game-feel/juice** intent (§4.5), not just static screens.
4. A **motion & juice spec** — the feedback choreography for the key verbs (hit, catch, awaken, splice, loot, death) so the dopamine layer is buildable, not vibes.
5. **Handoff specs/assets** for the Godot build (sizes, states, annotations, exportable assets).

## 7. Reference docs (in the project folder)

`Mutants_Game_Design_Bible.md` (master) · `Mutants_Game_MVP_Slice.md` (scope) · `Mutants_Game_Battle.md`, `_Skills.md`, `_Status.md`, `_Lab.md`, `_Character.md`, `_World.md`, `_GameLoop.md` (systems) · `Mutants_Game_Bestiary.md` + `art/montage_*.png` (creatures & art style) · `Mutants_Game_ImageGen_Prompts.md` (the visual style anchor) · `Mutants_Game_TechStack.md` (Godot constraints).

## 8. Working principles

Funny-grim throughout; **deep but readable**; design the MVP screens to a buildable, annotated finish; flag open questions rather than guessing. The surface should make a 9-system game feel *inviting*, not intimidating — that's the whole job.
