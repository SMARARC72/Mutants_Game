# MUTANTS_GAME — Competitions (content build)

**Author:** systems-content design pass (the competition layer) · **Last updated:** 2026-06-28
**Source canon:** `Mutants_Game_Bosses_Rivals.md` (the **6 competition types**, the nemesis system, scaling, rewards) · `_CANON_RATIFICATIONS.md` (currency glyphs ₯/✶/◈; gear-slot→boost map; **rival→DG-### uniqueness**; Mordathun = Titanfall's Titan) · `factions_npcs.md` (the Nine, leaders/Hands, the **Stranger→…→Hand** standing ladder) · `regions.md` (the 11 regions + their venues/NPCs) · `economy_items_rivals.md` + `roster_shops_expansion.md` (the **24 named rivals** B1–B24, their teams, grids, and Succession DG-### bindings) · `Content_Generation_Brief.md` (tone, system-fit, voice).
**Voice:** funny-grim, mature-occult. Dread is bedrock; wit is the relief valve. *If a line makes you laugh and then slightly regret laughing, it's on-tone.*

**Principle (inherited):** *the world is full of other people trying to become god. Most of them are in your way.* Competitions are the structured way you climb *over* them — and every trophy is a rung on the Succession, because a champion's standing is a throne-claim with paperwork.

---

## How competitions tie the whole game together (the contract)

This file fills the `Mutants_Game_Bosses_Rivals.md` competition table. Each of the **6 types** is a real progression track that braids three locked systems:

- **Standing** — placing in a faction's circuit moves you along that faction's **Stranger → Associate → Sworn → Champion → Hand** ladder (per `factions_npcs.md`). The ladder *is* the gate: higher rungs open gear, creatures, skills, breeding-lore, and the deeper venues.
- **The rival system (Wick)** — competitions are where you *meet* the 24 named nemeses (B1–B24). Outcomes stay **sticky**: beat one and it returns obsessed; spare one and it may ally; humiliate one and it defects and hunts you. Brackets rubber-band to your **rank + notoriety** — climb the leaderboard and the world sends deadlier foils.
- **The Succession (the throne-climb)** — the apex of the four "ladder" types (Leagues, Arena, the Show circuit, the Contest circuit) feeds a single meta-track, the **Aspirant's Reckoning**, whose final title is a *recognized claim* on an empty throne. When a rival wins their circuit instead of you, *they* ascend — and their snapshot binds their unique **DG-###** as a future invasion boss. Competitions are how the world decides who gets to climb.

> **Reward currencies & gates (key).** **Drachma (₯)** = mortal coin (consumables, common gear, entry fees). **Essence (✶)** = distilled souls (Lab/breeding/ritual rewards, scarce). **Ichor (◈)** = rare divine (off gods/legendaries/championships only). **Renown** + **Corruption** *gate* rewards but aren't priced. **Titles** are permanent standing flags. **Gear-slot→boost** (per `_CANON_RATIFICATIONS.md`): Relic→capture · Tool→lab · Vestment→combat · Charm→tame · Glyph→breed.

> **Force ↔ stat key.** Gaia→Bulk · Ouranos→Celerity · Cosmos→Ward · Chaos→Spike · Eros→Vitality · Thanatos→Bane (+ universals Luck, Focus). Opposed pairs (taboo to fuse): Cosmos⇄Chaos · Eros⇄Thanatos · Gaia⇄Ouranos.

**The 6 types, at a glance:**

| # | Type | Run by | Structure | Tests | Apex feeds |
|---|---|---|---|---|---|
| 1 | **Battle Leagues** | each faction | force-themed gym-ladder (rungs → a Crown) | team-building vs a faction's force/creed | the Reckoning |
| 2 | **The Arena** (Threshold) | the High Table | seasonal neutral bracket (single-elim → finals) | cross-faction adaptability | the Reckoning |
| 3 | **Breeding Shows** | Stoneblooded, Bloomwardens | judged exhibitions (rounds → a Best-in-Show) | genome / purity / bond / rarity | the Reckoning |
| 4 | **Lab-Craft Contests** | Iron Guild, the Revel | submission heats (briefs → a Grand Build) | fusion/mutation creativity & power | the Reckoning |
| 5 | **Clan Wars** | all factions | seasonal faction-vs-faction territory ladder | mustering a faction's whole front | standing + map control |
| 6 | **Bounties** | the High Table | open board (contracts, no bracket) | hunting a *specific* named rival/rogue | the rival loop + Ichor |

---

# 1. BATTLE LEAGUES — *the force-themed gym-ladders*

**Run by:** each faction, in its home region. **Structure:** a **ladder of themed "rungs"** (3–5 ranked challengers per league, each a trainer/Hand fielding the faction's force), climbed in order; clear all rungs to face the league's **Crown-holder** (a leader-tier or signature rival). Each rung is a bracketed battle (`battle_engine.py`), tiered so a fresh team meets fresh challengers. **Format quirk:** every league enforces a **creed-rule** — a battle modifier that forces you to fight the faction's *way*, not just its creatures.

**Rewards (per league):** rung-clears pay **₯ + Renown** and a themed consumable; the Crown-clear grants a **faction Title**, a standing jump (one full tier, e.g. Associate→Sworn), a **force-themed Vestment or skill-line unlock**, and — at the apex leagues — **◈** and a **god-organ** fragment. Crown-holding raises notoriety → tougher rivals → bigger purses.

**Announcers & crowd (the funny-grim texture):** each league has a herald who loves the carnage in their faction's particular key — the Concord *files* it, the Revel *toasts* it, the Pale Court *itemizes* it. The crowd is loyal to the verb, never the noun (per Pomp Castellan).

---

### 1A. The Lawful Ladder — *the Concord (Astral Tier · Cosmos/Ward)*

**Venue:** the **Hall of Empty Thrones'** lower galleries (`regions.md` §9), where vacant god-seats watch you audition.
**Creed-rule — "Sealed Conduct":** Chaos/Spike kits are *suppressed* (the law-tiles dampen them); you win by **out-warding and out-tempo**, not out-bursting. Break a posted rule mid-match (an unsealed taboo on the field) and you forfeit the rung *and* get fined in Renown.
**Rungs (climb in order):** Warder-Adept **Simca of the Eighth Seal** (Cosmos seal-control) → **Auditor Halish Greypledge** (Cosmos/Thanatos attrition, "documenting you fighting him") → **Sub-Notary Oren Tallowmark** (a paperwork-themed stall team he apologizes for).
**Crown-holder:** **Veris Calx, "The Codifier" (B13)** — Order/Pure — who narrates the *clause* you're breaking as he beats you with **Sanctwall Colossus** under a god-organ Ward. Beat him and he certifies your lineage with fussy pride; humiliate his draft and he hardens toward the Iron Throne and re-files you as a *case*.
**Title & reward:** **"Warden of the Empty Bench"** + the **Ward & Seal skill-line** unlock (Containment Seal — the prereq for safely crafting cross-force abominations), a Cosmos Vestment (+corruption-resist), and Concord standing → Sworn. Apex re-run pays **◈** + a Cosmos god-organ fragment.
**Announcer:** **The Recording Clerk**, who reads your win into the permanent record, deadpan: *"Let it be noted the challenger prevailed at 14:22, lawfully, with no objections filed. Congratulations. You are now a precedent. Try to be a good one."*
**Crowd beat:** the gallery applauds by *stamping forms*. A single crooked clap is corrected by a Sealwright before it finishes.

---

### 1B. The Long Climb — *the Stoneblooded (Titanfall · Gaia/Bulk)*

**Venue:** the **Cairn of the First Beast** training-slopes (`regions.md` §7), uphill, always uphill.
**Creed-rule — "Outlast, Don't Outrun":** turn-limits are *off* and damage is *slow*; the league rewards a long, ugly, immovable plan. Ouranos/Celerity speed-kits gain nothing here (the slope eats tempo). You win by **endurance**, the way the clans like it.
**Rungs:** **Durn Oxback** (Gaia fortress-stall, the breeding-show champ moonlighting) → **Little Stone** (the prodigy child, alarmingly good, not smug) → **Herd-Father Bress Gravelhand** (a true-bred Gaia wall six generations deep).
**Crown-holder:** **Karrok Stoneblood, "The Old Weight" (B6)** — Balanced/Pure — the immovable object: a **stall-war** that punishes impatience (Rimewarden, Stratovault, Tundramound, Cathedral-Chiton). He'd rather *not* ascend; out-endure him and he mentors you, humiliate him and he proves he could've taken a throne all along (returns as **Keeper of the Sealed Mountain, DG-007**).
**Title & reward:** **"Mountain-Patient"** + **bond-gear** (Charm-slot: +tame speed, +befriend-odds) and the **environmental gene-expression** tuning unlock (raise offspring in Titanfall to tint them Gaia). Stoneblooded standing → Sworn.
**Announcer:** **The Listener**, who narrates in the buried Titan's first-person-plural and is unsettlingly slow: *"...we have watched this hill for an age. We will watch your match for... however long it takes. We have the time. You, climber, do not. That is the whole lesson."*
**Crowd beat:** the clans don't cheer; they *nod*, once, in geological unison, when you finally earn it. It is the warmest sound in the world and it takes two hours to arrive.

---

### 1C. The Drowned Descant — *the Deep Choir (the Tideless · Ouranos+Gaia/abyssal)*

**Venue:** the **Kelp-Cathedral's** flooded nave (`regions.md` §8), where the hymn carries too far and rewrites what you came in believing.
**Creed-rule — "The Sea Decides Initiative":** turn order is *seized by the venue*, not your Celerity — the deep goes when the deep wants. Control/drown-tempo kits thrive; glass cannons drown. Each rung descends a level, and each level **nudges Corruption** a little (the temptation curve made bracket).
**Rungs:** **Tidewright Hesh of the Low Tongue** (leviathan control) → **The Rememberer, Sloane Saltlung** (drowned-secret debuffs) → **Mother Brine** (her over-fond leviathan pen, "he's just big-toothed").
**Crown-holder:** **Vael Mourncoil, "The Drowned Voice" (B7)** — Balanced/Corrupt — a **controller-prison** where the sea decides initiative (Tidecoil, Brineherald, Fathompsalm, Choirstone Galechorus). Vael answers questions you only *thought*. Befriend-route recruits Vael as a deep-recipe keeper; left to ascend, Vael binds **The Archivist of Silent Things (DG-015)**.
**Alt Crown (defector arc):** **Nerin Saltvow, "The Drowned Bride" (B14)** appears as a weeping alternate finalist in later seasons — talk her *back* a verse at a time, or she binds **The Tender of the Ordered Garden (DG-009)** re-read as a drowned cloister.
**Title & reward:** **"Throat of the Low Note"** + **leviathan capture targets** unlock and Thanatos/Ouranos cross-force breeding lore. Deep Choir standing → Sworn. (Corruption gained scales with how deep you climbed.)
**Announcer:** **Choir-Master Ude**, who *sings* the results in a wet, beautiful, wrong harmony: *"...the challenger... kept their shape... mostly... we are so pleased... we have saved them a seat... below..."*
**Crowd beat:** the drowned congregation hums one sustained note for the whole match. You feel it in your teeth and a grief you didn't know you had. Fathom mouths *don't* from the back pew.

---

### 1D. The Sweet-Rot Riot — *the Revel (Verdant Glut/Sunder · Chaos/Spike)*

**Venue:** **The Long Party's** festival-maze (`regions.md` §6), where the music never stops and neither does the mutation.
**Creed-rule — "Variance Is the Point":** a **random force-advantage inversion** fires each round (your strong-vs-weak matchup flips on a glyph), and a free mutagen is offered between rungs (take it for a random buff *and* a taboo cost). The league rewards loving the outcome you didn't plan.
**Rungs:** **Mixmistress Yarrow Threetongue** (Chaos-wild reagents mid-fight) → **The Ecstatic, Pell Manyhanded** (catalyzed beasts that "shouldn't *be*") → **Brother Vint** (three drinks ahead, fields whatever's left).
**Crown-holder:** **Pyx the Unasked, "The Reveler" (B5)** — Chaos/Tainted — a fight that gets *more* chaotic as it goes, gambits one-shotting both ways (Emberwyrm, Hearthwake, Quagsovereign, Glasswolf Riotsplice, plus a table-fused abomination "for the bit"). Humiliate Pyx and the Revel *adopts* the feud as a festival; befriend Pyx and they fund your wildest runs. Pyx ascends *by accident* → **The Jester That Outlived the Court (DG-010)**.
**Title & reward:** **"Beloved by the Wreckage"** + the **Chaos-wild precision setting** on Lab ops (cheap, high-variance Mutate/Fuse) and a mutation-catalyst Tool. Revel standing → Sworn. (Crafting an opposed-force abomination to win arms the world-bounty and sours the Stoneblooded.)
**Announcer:** **Sober Tem** (the only sober one, deeply suspect), the designated witness *"for the lawsuits"*: *"Someone has to remember the party, so it's me. The challenger won. I think. The scoreboard mutated. Everyone's thrilled. I'm taking notes. The notes are also screaming."*
**Crowd beat:** the crowd is having the best night of several overlapping lives and keeps trying to hand you a drink, a mutation, and a stranger's third arm, in roughly that order.

---

### 1E. The Tariff Bracket — *the Pale Court (the Mournmarch · Thanatos/Bane)*

**Venue:** the **Ledger-Barrow's** audit-floor (`regions.md` §3), where every match is filed as a line-item against the dead.
**Creed-rule — "Everything Has a Lien":** **fallen creatures can be reanimated mid-bracket** — yours *and* theirs — so attrition is the whole game; a win that spends nothing scores higher than a bloodbath. Bane-drain kits thrive.
**Rungs:** **Archivist Mund the Indexed** ("your boar? vault seven") → **Bone-Sexton Halryn Coldmercy** (reanimation surgeon, calls corpses "the patient") → **Collector Veum** (the repossessor who never threatens, simply *arrives*).
**Crown-holder:** **Brother Quill, "The Sexton" (B2)** — Order/Corrupt — a war of attrition where every creature *you've* lost near him, he raises (Gloamcat, Pallbloom Revenant, Veldtmourn, Reliquary Colossus). Ascends as **The Pale Courier of Endings (DG-012)**, who can reanimate the *player's* fallen across runs.
**Alt Crown (the ledger-first cousin):** **Ors Veck, "The Repossessor" (B17)** — colder, never apologizes — runs a **foreclosure variant** where your unsettled Court debts come due as enemies. Cannot be befriended; *can* be out-paid (clear every debt → he closes your file with a chilling *"settled"*). Binds **The Sexton-King of the Deep Loam (DG-006)** re-read as an accountant.
**Title & reward:** **"Registrar of the Owed"** + the **Reanimate-the-dead Lab operation** and the **soul-core harvest** path. Pale Court standing → Sworn.
**Announcer:** **Marrow**, the child-shaped revenant clerk, two centuries bored: *"Challenger wins. I'll file it. ...you'll lose someone eventually, you all do, and then we'll talk about *terms*. Not today. Today you just won. Mind the drawers on your way out."*
**Crowd beat:** the gallery is half spectators and half *collateral* — reanimants on day-release, applauding politely, one of whom is someone's repossessed husband keeping up appearances.

---

### 1F. The High Storm Circuit — *the High Table (Storm Vault · Ouranos/Celerity)*

**Venue:** the **Falling Court** (`regions.md` §5), a drifting amphitheater where losing your footing loses the match (and the long way down).
**Creed-rule — "Altitude Is Initiative":** **fall-edges are live** — ring-outs are a real failure-state, and the highest-Celerity side opens the exchange. Speed and flight rule; slow walls get shoved off the island.
**Rungs:** **Castellan Mio** (landing-clearance gatekeeper, vertiginously calm) → **The Pythian** (sells you the odds, then fields them) → **Mercer Vane** (bounty-master, treats your form like a racehorse).
**Crown-holder:** **Quint Galefellow, "The Squall" (B18)** — Balanced/Ouranos-Chaos — opens every exchange first, betting the fight on tempo (Khamsoon, Siroccoub, Sandskip, Constellute, plus a *rented* Dead-God mercenary). Spare-and-befriend turns Quint into the rival who *bankrolls* your wildest runs; he ascends by *winning his own bet* → **The Squall That Kept the Crown (DG-008)**.
**Title & reward:** **"Sovereign of the First Strike"** + a **flight-capable traversal-upgrade** lead and a neutral gear-stash (usable across factions, no grid penalty). High Table standing → Sworn — and this is the league that **opens the Bounty board** (type 6).
**Announcer:** **The Arena Herald, Pomp Castellan**, on loan and *thrilled*: *"NEW BLOOD AT ALTITUDE! The odds are generous, friend — which is the Table's polite word for *grim* — and the drop is *real*! Win and they'll chant your name! Fall and they'll chant... well, they'll chant 'OHHH'!"*
**Crowd beat:** a storm-island tavern that detached a century ago drifts past mid-match, patrons toasting you, technically not allowed to land, fully committed to the bit.

> **Leagues not given a full ladder** (covered briefly, same template, lower MVP priority): the **Iron Guild's** *Spec Ladder* (Forgefell, construct-only, win by hitting a force/tier spec — Crown: **Halix Dray, B3** / heir **Castle Greel, B24**); the **Bloomwardens'** *Gentle Circuit* (Verdant Glut, befriend/Mend-only, no KOs allowed — Crown: **the Widow Sorrel, B4**); the **Unbound's** *Unleague* (the Sunder, no rules at all, which is itself the rule — Crown: **Ruskin Hale, B9**, if he's curdled far enough). Each grants its faction's signature unlock and standing → Sworn.

---

# 2. THE ARENA — *the seasonal neutral cross-faction tournament (Threshold)*

**Run by:** the **High Table** (registrar **Marker-Keeper Doss Halloway**; announcer **the Arena Herald, Pomp Castellan**). **Venue:** **The Arena** — the sunken bowl of cracked marble in Threshold (`regions.md` §1) where the city watches strangers try to become more than strangers. **Structure:** a **seasonal single-elimination bracket** — sign a marker, get seeded by creature-tier, fight up through **Pit → Heat → Quarter → Semi → the Marble Final**. Because it's neutral ground, *every faction's* creed-rules are *off* — the Arena tests pure **cross-faction adaptability**, the one place all builds meet on equal terms. The Tallyman quietly enters every nobody into the lowest bracket "for the experience" (the Act 0 hook).

**Rewards:** round-wins pay **₯ + Renown** and crowd-favor (a Drachma multiplier that grows as the bowl chants for you); the **Season Champion** wins **◈**, the **"Champion of the Standstill"** title, a neutral **gear-stash** (cross-faction, no grid penalty), and — load-bearing — the title is the **first qualifying win for the Aspirant's Reckoning** (the throne-climb meta-track). Winning a season raises notoriety hard → the next season seeds *tougher* rivals against you (the nemesis scaling, made literal).

**The seasons (≈3–4 named, rotating):**

### 2A. The Greenhorn Season — *the on-ramp (low bracket)*
The season the Tallyman signs you into without asking. A gentle single-elim of fellow nobodies and apprentice aspirants. Your bracket-mates include **the Twins, Oss & Ull** (cocky and nervous), and — improbably — **Now-Insufferable Wick's** fight-career pigeon, **Lord Featherstone** (the Confident Pigeon, scarred, strutting, a genuine low-stakes mirror of your own nobody-to-god arc). **Reward:** **"Blooded in the Bowl"** title + a starter Vestment + the **first Reckoning qualifier**. **Flavor:** the betting-pool the city keeps on every nobody pays out for the first time; someone wins three Drachma on you and weeps with joy.

### 2B. The Crossing Season — *the cross-faction proper (mid bracket)*
The real cross-faction tournament: faction Champions sent to test the neutral ground. You'll draw **at least one named rival here** scaled to your notoriety — early it's **Ruskin Hale (B9)** (your funhouse-mirror co-climber, splitting a friendly bracket before the fork) or **Drubb Gravelorn (B21)** (the Stoneblood who breeds slow and fights *fast*, coming downhill). **Reward:** **"Crossed Blades, Crossed Banners"** title + **◈** + a **second Reckoning qualifier**. **Flavor:** Embassy Row empties into the stands; nine factions watch their champion lose to a nobody and pretend they always expected it.

### 2C. The Marble Crown Season — *the prestige finals (high bracket)*
The season that *means* something — the bowl is packed, the Table's biggest line of the year is open, and the finalists are notorious. The **Marble Final** pairs you against the deadliest rival your run has produced (rubber-banded): **Quint Galefellow (B18)** betting the house on himself, or **Veris Calx (B13)** trying to ratify you into stillness, or your own **Echo (B11)** if you've ascended before. **Reward:** **"Champion of the Standstill"** (permanent) + a **god-organ** + the **capstone Reckoning qualifier** (a season-champion title is a recognized throne-claim). **Flavor:** if you win, the Standstill bell rings *for you* — the one time the city's no-godhood rule bends, because a Marble Champion is allowed, briefly, to look like a god in the foyer.

### 2D. The Echo Season — *the async-invasion exhibition (post-ascension / endgame)*
A special recurring season seeded entirely from **Succession snapshots** — past-run champions (yours and friends', via the async loop) returned as **invasion bosses**. This is where the Arena meets the throne-climb's *back end*: every rival who ascended instead of you (binding their DG-###) can appear here as a bracket wall. **Reward:** **◈** + bragging-rights titles per Echo felled + a roster entry in the world's leaderboard. **Flavor:** the Herald introduces each Echo with genuine awe and a fresh line of odds: *"Returning to the bowl — a god who was once a nobody, exactly like you, who climbed where you're standing and pulled the ladder up! Place your bets! The dead ones pay *triple*!"*

**Announcer (all seasons) — Pomp Castellan, the Arena Herald:** booming, theatrical, sincerely in love with the carnage and the crowd. *"Win and they'll chant your name! Lose and they'll chant the winner's name! The crowd is loyal to the verb, never the noun! Try to die memorably — it's good for the gate!"*
**The crowd & the trophy:** the Arena crowd is Threshold itself — merchants, drunks, embassy clerks, the lamplighter — betting, heckling, and adopting you the instant you're winning. The trophy is the **Marble Laurel**, cut from the bowl's own cracked stone: ugly, heavy, and worth more standing than any gold, because everyone watched you earn it.

---

# 3. BREEDING SHOWS — *the judged exhibitions of genome, purity & bond*

**Run by:** the **Stoneblooded** (Titanfall, the husbandry way) and the **Bloomwardens** (Verdant Glut, the gentle way) — the two factions that *make* strong creatures instead of catching or building them. **Structure:** a **judged exhibition**, not a battle — you enter a *creature* (or a *bonded pair*) and a panel scores it across **rounds**: a Conformation round (stat-spread / force-purity vs the ideal), a Lineage round (genome / rare-recessive depth), a Bond round (befriend-tier / care-evidence), and a Rarity round. Clear the rounds to reach **Best-in-Show**. Brackets are by **tier** (a T1 hatchling doesn't show against a Worldback). **Format quirk:** **no combat** — these circuits reward the *opposite* of the leagues; you win by what you *grew*, and entering a Lab-fused or sacrificed creature is disqualifying at the purity-strict shows (the Revel/Iron Guild "improvements" read as cheating here).

**Rewards:** round-placements pay **✶ (Essence)** + **Renown** and breeding-stock vouchers; **Best-in-Show** grants a faction **Title**, a standing jump, **breed-gear (Glyph-slot: +force-attunement)** or **bond-gear (Charm-slot: +tame/+luck)**, the **rare-gene chase boost** (the 10%→30% recessive uplift), and a **legendary breeding-line** unlock. Show wins feed the **Aspirant's Reckoning** as the "husbandry proof" qualifier — a champion bloodline is a throne-claim the slow way.

**Announcers & crowd:** the judges *are* the show — ceremonious, exacting, in love with a fine genome the way others love a sunrise. The crowd is hushed, reverent, and full of devoted handlers who've spent generations on a single line; the funny-grim is in the *scale* of the devotion (a tortoise with three generations of staff and its own lichen).

---

### 3A. The Cairn Showing — *the Stoneblooded (Titanfall · purity-strict, lineage-deep)*

**Venue:** the **Cairn of the First Beast** (`regions.md` §7), the clans' holiest ground, where sacred lines have been bred for a thousand generations.
**Judging quirk — "Score the True, Not the Strong":** the Stoneblooded panel *penalizes* shortcuts. A flashy Lab-tinted entry scores *below* a humbler true-bred one; rare-recessives surfaced over six generations score highest. Bond is weighted heavily — a cage-caught entry can't reach Best-in-Show, only a *raised* one can.
**Head judge:** **Showmaster Cairn Oldoak** — ceremonious, exacting — *"I don't score the strong ones, child. I score the *true* ones. There's a difference and it's the whole world."* (Assisted by **Matriarch Brole**, who finds the Iron Guild "adorable," and **Durn Oxback**.)
**Featured rivals:**
- **Karrok Stoneblood (B6)** shows a fossil-patient Gaia line and mentors you *if* you took the slow road (rivals you bitterly if you took the Lab).
- **Drubb Gravelorn, "The Rockslide" (B21)** — the clan's embarrassment-and-secret-champion — enters a *flawless* six-generation line and then immediately wants to charge it into the arena; the elders wince. Spare-and-befriend gets you the breeding half he's genuinely good at.
- **Harrow Sceln, "The Clanbreaker" (B15)** — the exile — enters a *perfect* bloodline and then walks it straight to the Forgefell rendering pits, smiling, to fund the next one. The clans turn cold toward *you* if you're seen trading with him. Binds **The Husbanded Engine, Self-Sown (DG-025)**.
**Title & reward:** **"True-Blood Steward"** + the **advanced breeding Lab branch**, a Gaia **legendary lineage**, **bond-gear**, and the **rare-gene chase boost**. Stoneblooded standing → Sworn. (Completes the "Six Generations Deep" quest's circuit half.)
**Crowd beat:** the grand champion is a tortoise so old it has lichen, a name, three generations of devoted handlers, and a slow ancient dignity that makes your entire god-quest feel a little loud. It has *never lost*. It will outlive you. The clans are quietly certain of this and find it comforting.

---

### 3B. The Mercy-Garden Bloom — *the Bloomwardens (Verdant Glut · bond-first, life-sacred)*

**Venue:** the **Mercy-Garden** infirmary-grove (`regions.md` §2), where wounded creatures are mended at living Eros altars.
**Judging quirk — "The Gentleness It's Owed":** the Bloomwarden panel scores **bond and vitality above all** — a creature's *health*, its *trust*, the evidence of *care*. Harvested, sacrificed, or sold history is disqualifying and openly mourned. Uniquely, the show *includes wild entrants* the Wardens befriended (not owned) — you can show a creature that merely *chose* you.
**Head judge:** **Greenmother Saoirse Lateharvest** herself, or her Hand **Hearthward Ona Bramblekind** — *"Love's a method, not a mood. Feed them right, raise them kind, and the bond does three jobs for you. Sentiment with *results*."* (Seed-Keeper **Wll the Quiet** judges the wild-befriended class, mostly through the plants.)
**Featured rivals:**
- **The Widow Sorrel, "The Gardener" (B4)** — warm, barefoot, terrifying — out-bonds you and is *sweet* about it; turns cold and judges hard if you've ever sold or sacrificed a creature. Binds **The Worldmother, Still Blooming (DG-019)**.
- **Mother Cinva-the-Glut, "The Overgrowth" (B16)** — the Bloomwarden hospice-sister who broke wrong — enters something *unsettlingly* lush, too alive, faintly grateful, *more* than was planted. She counts your every mercy as proof she was right (nearly impossible to redeem). Binds **The Glut That Forgave Death (DG-026)**.
- **Archpriest Solmen Vexx, "The Dawnsung" (B20)** — Saoirse's sweetest student, hardening — out-heals and out-*organizes* you, "correcting your inefficient compassion." Keep him wild (befriend beside him, never regiment) to prevent his calcification into **The Dawnrunner, Beloved and Gone (DG-014)**.
**Title & reward:** **"Last Friend of the Doomed"** + the **Mend / Soothe skill-line** (in-encounter befriend on hostile/high-tier targets), the **husbandry bond-growth boost**, and an **Eros legendary befriend target**. Bloomwarden standing → Sworn — pushes you toward the Warden/Lawgiver edge.
**Crowd beat:** between rounds, a full **funeral for a beetle** breaks out, six mourners, a hymn-sheet pressed into your hand. The show *pauses* for it. Everyone agrees the beetle showed beautifully. Declining the shovel is somehow the rudest thing you could do all season.

> **Show circuits not given a full panel** (same template, lower priority): a Threshold **Open Show** run by **Egg-Tender Mirin Softclutch** at the Hatchery rows (neutral, all-comers, the on-ramp — *"this one's going to be rare, don't ask how I know"*); and the wandering **Pilgrim Showing** run by **Mother Wend Truelineage (W-3)**, who left the clans to *spread* the slow way and judges true bloodlines in soil the Stoneblooded would never bless.

---

# 4. LAB-CRAFT CONTESTS — *the fusion & mutation showdowns*

**Run by:** the **Iron Guild** (Forgefell, build-don't-be-born) and the **Revel** (the Sunder, change-for-its-own-sake) — the two factions that *remake* creatures in the Lab. **Structure:** **submission heats**, not battles you steer live. You **submit a fused/mutated creature against a posted brief** (a force/tier/role spec, or an "anything-goes" prompt), the judges score it, and your build then **fights an exhibition** against the heat's other entries on `battle_engine.py` to prove the craft *works*, not just reads well. Win heats → the **Grand Build** final. **The two factions judge opposite things:** the Guild rewards **hitting spec precisely without tipping into abomination**; the Revel rewards **the gloriously over-the-line build the Guild won't make**. They are each other's evil twin, by design.

**Rewards:** heat-wins pay **✶ (Essence)** + **Renown** + reagent caches; the **Grand Build** grants a faction **Title**, a standing jump, **lab-gear (Tool-slot: +operation success / −cost)**, a **discoverable repeatable recipe** (turn a one-off gamble into a mass-produceable formula), and at the apex a **god-organ graft recipe**. Contest wins feed the **Aspirant's Reckoning** as the "craft proof" qualifier — a master-builder is a throne-claim by the Architect/Reveler roads, and the **God-Maker** ending (`regions.md` §11, the Hollow Atelier) is *literally* the apex of this track.

**Announcers & crowd:** the Guild documents everything; the Revel remembers nothing and toasts all of it. The crowd at a Guild contest is a panel of engineers nodding at tolerances; the crowd at a Revel contest is a riot that has grown extra hands to applaud with.

---

### 4A. The Spec Trials — *the Iron Guild (Forgefell · precision, "within spec")*

**Venue:** the **Unfinished Assembly** (`regions.md` §4), the cathedral-sized hall where Hephaestion's last construct sits 84% complete and the automatons still try to finish it.
**Judging quirk — "Within Spec":** the brief names an exact **force / tier / role target**, and you score by *how close you land without going over*. Tipping into an **opposed-force abomination** is an automatic loss *here* (it's the Revel's whole prize, two regions over). Construct-class entries score a precision bonus. Elegance counts: a clean weld beats a strong mess.
**Head judge:** **Foreman Magnus Cog** — clipped, precise, treats feelings as a tolerance problem — *"Sentiment is a manufacturing defect. We can machine it out, if you'll hold still."* (Blueprint-keeper **Tessella** scores artistry; **Auditor Klemm** inspects for "design flaws" and offers "improvements" you didn't ask for.)
**Featured rivals:**
- **Halix Dray, "The Tinker" (B3)** — beats your organic team with a *tin* one, then explains the matchup, kindly; iterates a counter-build to your roster each meeting. The strongest candidate to **recruit** for a God-Maker run. Binds **Cradle-Frame "Evergrowth" (DG-011)**.
- **Castle Greel, "The Iterator" (B24)** — Halix's heir who builds "better gods than Halix" and says so to his face — beats you with a tin team, then *patches it overnight* into a worse matchup for you specifically, treating you as a *changelog*. Binds **The Patch That Shipped Itself, Frame-Eternal (DG-028)**.
- **Sister Ferrum, "The Iron Saint" (B10)** appears in the strict heats as a sealed-writ judge who *sentences* over-spec entries; cannot be befriended once hardened toward **the Iron Throne (DG-005)**.
**Title & reward:** **"Within Spec"** + the **Build operation tier-up** (god-organ graft recipe), the **discoverable repeatable recipe** system at Magna's bench, and a Forgefell lab-gear set (−Build entropy-cost). Iron Guild standing → Sworn. (Completes the "Within Spec" quest.)
**Announcer:** **Auditor Klemm**, helpfully invasive, the customer-service rep of body horror: *"The challenger's submission is within tolerance. Barely. I've taken the liberty of noting four improvements. And a fifth. The fifth is free. The fifth is *load-bearing*. You're welcome. Please hold still."*
**Crowd beat:** the automatons of the hall pause their thousand-year loop to *assess* your build, find it acceptable, and resume — the only approval they're capable of, and the Guild treats it as a standing ovation.

---

### 4B. The Glorious Mistake — *the Revel (the Sunder · variance, over-the-line)*

**Venue:** **The Long Party's** heart (`regions.md` §6), where Madame Vermillion offers a "blessing" with a randomized taboo cost.
**Judging quirk — "Scares the Iron Guild":** the brief is the *opposite* of spec — you score by **how gloriously wrong** the build is. **Opposed-force abominations are the whole point** (and *win*); a safe, in-spec entry is booed off. A randomized mutagen is applied to every entry before judging (your build *and* a taboo surprise). The exhibition fight gets *more* chaotic each round.
**Head judge:** **Sober Tem** (the only sober one, deeply suspect) — *"Bring me something that scares the Iron Guild. They scare easy."* (Mixmistress **Yarrow Threetongue** supplies the reagents; **The Ecstatic, Pell Manyhanded** appraises "things that shouldn't *be*.")
**Featured rivals:**
- **Pyx the Unasked (B5)** challenges you "for fun," fields something that *shouldn't be legal*, and loses cheerfully or wins louder; humiliate Pyx and the Revel adopts the feud as a *festival*. Binds **The Jester That Outlived the Court (DG-010)**.
- **The Thunderfool Errant, Bram Ozzle, "The Accident" (B19)** — stumbles into a contest he didn't sign up for, fields something he made *wrong*, and wins on a **Luck roll** that makes Sober Tem put down his pen. The only rival you can lose to and feel *insulted* rather than outmatched. Binds **The Stumblecrown, Beloved by Dice (DG-027)**.
- **Maddox Thern, "The Grudge-Heavy" (B22)** lurks the deepest heats with **self-spliced** god-organ horrors (Riftgrowth Slagmutant, Cinderlich Boneheap); if you go dark he escalates to prove he's further gone. Binds **The Fault-Line That Was a King (DG-013)**.
**Title & reward:** **"Beautiful Mistake"** + **mutation-catalyst gear** (drops the entropy floor on wild fusions), the **self-splice entry path** (Lab ops on your own character → the first player force-power, corruption-gated), and a **Chaos legendary** from the Sweet Rot. Revel standing → Sworn. (Completes "The Beautiful Mistake" quest; arms the world-bounty and sours the Stoneblooded.)
**Announcer:** **Madame Vermillion**, decadent and brakeless, hosting the heart of the party: *"Stronger? Darling, *stronger* is the boring part. This one made the Iron Guild's emissary *faint* — through a door that leads nowhere — and that, my loves, is a *perfect score*. Drink! Change! Hold its hand and don't let go no matter what it becomes!"*
**Crowd beat:** the crowd judges by *acclaim* — the more wrong the build, the louder the joy — and the winner is carried out on a tide of arms, several of which grew specifically for the occasion and will not be returned.

> **Contest circuits not given a full panel** (same template): the **Concord's** rare *Sanctioned Craft* exhibition (Astral Tier — build a *lawful* construct under a Containment Seal, judged by **Sealwright Orin**, the only place the Concord blesses Lab work); and the **God-Maker capstone** at the **Drafting Throne** (`regions.md` §11), which is less a contest than the *end* of this track — your accumulated builds judged by **The First Draftsman** (the dead prior God-Maker) at the bench where you made everything.

---

# 5. CLAN WARS — *the faction-vs-faction territory campaigns*

**Run by:** **all factions** (declared, brokered, and *bet on* by the High Table). **Structure:** a **seasonal territory ladder** fought over contested borders — not a personal bracket but a **campaign** you fight *for your sworn faction* against its canon **rival faction**. A war runs as a series of **front battles** (`battle_engine.py`) over named border-holds; each hold your side wins shifts the **territory line** on the overworld map, and the season ends when one faction's banner holds the contested ground. You muster a *team for the front*, not a duel-pair — Clan Wars test whether you can field a faction's *whole way of fighting*, repeatedly, under attrition. **You must hold standing (Associate+) with a faction to fight its war**; fighting *against* a faction tanks your standing with them and turns their leader cold.

**Rewards:** front-wins pay **₯ + faction Renown** and war-spoils (gear stripped from the losing front); a **won war** grants a **faction Title**, a **standing jump**, **map control** (the territory line holds into your run — opening shops, spawns, and gated routes on the won ground), war-exclusive gear, and **✶**. Clan Wars don't feed the Reckoning directly (they're *factional*, not a personal throne-claim) — instead they're how a **Hand** consolidates power: winning your faction's war is the prerequisite for the deepest standing rewards and seeds your eventual ascension with a *territory* behind it.

**The canon rivalries (per `factions_npcs.md` — each faction's named enemy):**

### 5A. The Verdant Front — *Bloomwardens vs the Pale Court / Iron Guild*
**Contested ground:** the **Glut's edge**, where the Pale Court harvests Bloomwarden creatures for soul-tech and the Iron Guild renders them for parts. The warmest faction defending the world's most *fragile* creed against the two that would bank or build their dead.
**Front-holds:** the Mercy-Garden walls, the Throat of the Glut, the Sweet-Rot border-tavern.
**Featured rivals:** fighting *for* the Wardens pits you against **Brother Quill (B2)** / **Ors Veck (B17)** (Court) or **Halix Dray (B3)** / **Castle Greel (B24)** (Guild); fighting *for* the Court/Guild makes **Saoirse grieve you while you still live**.
**Title & reward:** **"Shield of the Soft Path"** (Warden side) / **"Efficient Harvest"** (Court/Guild side) + map control of the Glut's edge (befriend-spawn uplift, or a rendering-pit shop) + war-gear. Standing → toward Champion with the side you fought for.
**Crowd/flavor:** a Bloomwarden war is the saddest war in the world — they **weep at the funerals of the enemy creatures they're forced to fell** and hold the line anyway, because mercy that gives up isn't mercy. The Court sends condolence cards. The cards are also invoices.

### 5B. The Slow War — *Stoneblooded vs the Revel*
**Contested ground:** the **Verdant Glut / Titanfall seam** and the deep-strata borders, where the Revel's *mutate-what-should-be-bred* heresy creeps against the clans' thousand-generation bloodlines. The oldest, bitterest grudge: tradition vs transformation.
**Front-holds:** the Cairn approaches, the Sweet-Rot creep, the Dreaming Strata's upper galleries.
**Featured rivals:** for the clans, you face **Pyx (B5)**, **Bram Ozzle (B19)**, and the renegade **Drubb Gravelorn (B21)** (who fights *fast* for a slow faction); for the Revel, **Karrok (B6)** and **Harrow Sceln (B15)** come downhill at you. **Driftblood** (the clan-exile) cheers whichever side spites the elders.
**Title & reward:** **"Warden of the Slow Way"** (clan side) / **"Glorious Spread"** (Revel side) + map control (a breeding-vault route, or a mutagen-cart) + war-gear. Standing → Champion with your side.
**Crowd/flavor:** the clans muster in **geological silence**; the Revel muster in a parade that's already three drinks deep. The war is decided as much by *patience* as by force — and the Revel keeps losing ground precisely because they keep stopping to enjoy the ground they took.

### 5C. The Sealed War — *the Concord vs the Unbound*
**Contested ground:** the **Astral Tier / Sunder border**, the metaphysical front line of the whole game — Order that would *fill every throne and file the deed* against Chaos that would *burn every throne to salt*. The Concord seals; the Unbound unmake. There is no compromise ground, which is the point.
**Front-holds:** the outer seals of the Hall of Empty Thrones, the Throne That Won't Sit Still's approaches, the warded crossings.
**Featured rivals:** for the Concord, **Cassia Vane (B1)**, **Veris Calx (B13)**, and **Sister Ferrum (B10)**; for the Unbound, **Ruskin Hale (B9)** (curdled) and **Maddox Thern (B22)**. **Knot-Cutter Esh** severs your ties to the Concord the moment you fight *for* the Unbound.
**Title & reward:** **"Keeper of the Empty Bench"** (Concord side) / **"Salt in the Wound"** (Unbound side) + map control (a sealed-route opens lawfully, or the taboo-ceiling lifts on the won ground) + war-gear. Standing → Champion; the *opposing* faction turns **permanently hostile** (this is the war that forces the grid choice hardest).
**Crowd/flavor:** the Concord wages war **by procedure** — every front-battle is notarized, every casualty filed, **Auditor Halish Greypledge** "documenting you fighting him." The Unbound wage it by *refusal* — Nael holds a torch and asks, gently, the saddest question in the world, while the rules themselves come loose around you.

### 5D. The Tideline War — *the Deep Choir vs the Concord*
**Contested ground:** the **Tideless shallows**, where the Concord wants the drowned secrets *sealed* and the Deep Choir wants to bring a little of the bottom *up*. Order against the eldritch deep — the Concord's second front, and the one that unsettles even them.
**Front-holds:** the Kelp-Cathedral's outer nave, the Pressure-Trench's lip, the warded shoreline.
**Featured rivals:** for the Choir, **Vael Mourncoil (B7)** and **Nerin Saltvow (B14)**; defecting toward the Court, **Sister Halloran Vex (B23)** turns the war colder mid-season. For the Concord, **Cassia (B1)** and **Ferrum (B10)** again.
**Title & reward:** **"Throat of the Tideline"** (Choir side) / **"Sealer of the Deep"** (Concord side) + map control (a communion-deep opens, or a Concord seal-line holds the shore) + war-gear. Standing → Champion with your side.
**Crowd/flavor:** the Choir wages war in **a cappella** — front-battles open with a hymn that carries too far and rewrites a little of what each side believes it's fighting for. The Concord finds this *deeply* improper and files three objections per verse.

> **The High Table's stake.** The Table doesn't field a war (it has no rival — *and everybody*), but it **books the line on every front** and runs a **mercenary-marker variant**: hire a rival's team to your front for ◈, or take a Table contract to *swing* a war you have no standing in. **Quint Galefellow (B18)** plays both sides loudly "for the line"; **Dolos (B8)** quietly *sent* half the combatants. Winning a war the Table bet against pays a **scandalous** Ichor purse — and opens a fresh line on your ascension.

---

# 6. BOUNTIES — *the named-rival & rogue-creature hunts*

**Run by:** the **High Table** (the only neutral power, the keeper of the rival network). **Structure:** an **open board**, not a bracket — you **take a posted contract** to hunt down a **specific named rival god-maker** or a **rogue creature**, find them in the overworld (they don't come to you), and settle the contract on your terms. Bounties are the **direct interface to the nemesis system (Wick)**: the board *is* how the world hands you your 24 foils (B1–B24) as quests, scaled to your **rank + notoriety**. **Format quirk:** outcomes are **sticky and chosen** — a contract says "bring them in," but *how* (kill / capture / spare / humiliate / recruit) is yours, and it permanently changes that rival's arc. Unlocked by winning a **High Table** circuit (the Storm Circuit league or an Arena season opens the board).

**Rewards:** bounties pay in **◈ (Ichor)** — the Table's signature — scaling with the target's notoriety, plus **₯**, **Renown**, the target's **loosed signature creature** as a capture target, and occasionally a **unique god-organ** from the Table's vault. The board *itself* is the reward loop: every bounty cleared raises notoriety → the board posts deadlier names → bigger Ichor. Bounties feed the **rival loop** and the **Succession** sideways — sparing vs. ending a rival decides whether they ascend (binding their DG-###) or stay mortal.

**Brokers & board (the funny-grim texture):** the board is run by people who treat your blood-feuds as *racehorse form*. The Table has, demonstrably, sold your location to the same rivals it's selling you. Balance is the product.

---

### 6A. The Standing Board — *the on-ramp (Threshold / Storm Vault)*
**Posted by:** **Croupier Sable Ninefold** (deals quests like cards) and **Mercer Vane** (treats your rivalries like form). The everyday board — overdue god-makers, rogue creatures gone feral after a god-death, low-notoriety foils.
**Sample contracts:**
- **"A Live One"** — bring in a rival who *hates your guts and owes the Table money* — "the breathing ones pay double." (Your first scaled foil, often **Ruskin Hale (B9)** pre-fork or **Bram Ozzle (B19)**.)
- **"The Feral Saint"** — a Cosmos **Legendary** gone wild after a partial god-death; the Concord co-signs a *contain-not-kill* clause (befriend-condition for bonus Ichor).
**Reward:** **◈** + the target's loosed creature as a capture target + Renown. **Flavor:** Sable deals you the contract face-up, smiling: *"Got a god-maker three regions over who's *overdue*. Pays in Ichor. Interested? Of course you're interested."*

### 6B. The Long Markers — *the high-stakes board (contracts on the notorious)*
**Posted by:** **Marker-Keeper Doss Halloway** and **the Accountant** (no name, never the same face twice). The board for *named* rivals at full notoriety and the co-signed faction grudges.
**Sample contracts:**
- **"Letters of Marque, Posthumous"** (Pale Court co-signed) — settle the estate of a rogue god-maker who died owing the Court; grants a **Thanatos Legendary** capture target. Reanimating the rival's *team* from their Graveyard snapshot is the dark-bonus (draws notoriety, Bloomwarden hostility).
- **"The Clanbreaker's Ledger"** (Stoneblooded co-signed, out of spite) — hunt **Harrow Sceln (B15)** before he renders one more true bloodline; the clans *fund it personally*.
- **"The Repossessor's Due"** — a contract on **Ors Veck (B17)** himself, takeable only after he's foreclosed on *your* creatures; ending him frees every soul on his cart.
**Reward:** **◈** (scandalous) + a **unique god-organ** + a standing jump with the co-signing faction. **Flavor:** Doss is gruff and weirdly paternal: *"Sign the marker. Win, you collect. Lose, the marker collects. Either way the *Table* collects — that's just the geometry."*

### 6C. The Marker on a God — *the Act-boss bounty (endgame)*
**Posted by:** **The Chairwoman, Indra Vael of the Long Marker** personally (she only deals the biggest line). A High Table contract to **dethrone a named Olympian to the Table's timetable** (`factions_npcs.md` Hook 2) — the bounty board reaching all the way up to the Act bosses.
**Contract:** **"Marker on a God"** — signing grants early **region access** to that god's region and the **Olympian as an Act-boss capture-or-kill target**; fulfilling it pays a **unique god-organ** from the Table's vault. *Defaulting* summons **the Accountant** as a recurring rival.
**Reward:** a **god-organ** + a huge notoriety spike + a Reckoning-adjacent prestige flag. **Flavor:** Indra toasts you before you leave, meaning every word and none of them: *"You're not a player anymore, sweet thing — you're *house*. And when you go for your throne, I'll have the biggest line in history open on you, and I'll be cheering, and I'll mean both."*

### 6D. The Echo Contracts — *the async-invasion bounties (cross-run)*
**Posted by:** the board itself, drawing on the **Succession pool**. Contracts to hunt down **invasion bosses** — past-run champions (yours and friends', via the async loop) loose in your world, each bound to a **DG-###**.
**Contract:** **"Your Last Crown"** — hunt your own **Echo (B11)**, the snapshot of who you became if you ascended; or **"The Road Not Taken"** — face **The Refused (B12)**, the version of you that stayed mortal (a secret/superboss, ignores brackets). Plus any rival who ascended in a prior run, hunting *as* their Dead-God.
**Reward:** **◈** + bragging-rights titles + a leaderboard entry. **Flavor:** the board lists your own past god by its DG-name, and the broker doesn't quite meet your eye: *"This one's... personal, climber. Pays in Ichor. They always do, the ones that used to be you."*

**Announcer/broker voice — across the board:** the Table books your hatreds like sport and is *delighted* by the symmetry when a bounty target turns out to be hunting a bounty on *you*, issued by the same broker, for the same price. **The crowd is the board itself** — a wall of contracts where your name appears as often as a target as a hunter. **The "trophy"** is the cleared marker: a charged sky-relic stamped *settled*, worth standing, Ichor, and the quiet knowledge that the Table has already opened a fresh line on whoever comes for *you* next.

---

# The Aspirant's Reckoning — *how the four ladders feed the throne-climb*

The four **personal** circuits (Battle Leagues §1, the Arena §2, Breeding Shows §3, Lab-Craft Contests §4) each issue **qualifier titles** toward a single meta-track: the **Aspirant's Reckoning**, the High Table's official tally of who has *earned* a throne-claim. It is the bridge between the competition layer and the **Succession** (`Mutants_Game_Bosses_Rivals.md` · `Character.md`):

- **Each circuit proves a path:** Leagues prove you can *fight a creed*, the Arena proves you can *adapt to all of them*, the Shows prove you can *grow* a god (the Stoneblooded/Warden + Bloomwarden/Lawgiver roads), the Contests prove you can *make* one (the Architect/Reveler + God-Maker roads).
- **Qualifiers stack into a claim.** Collect enough circuit-titles and the Table recognizes your **Reckoning standing** — the in-world precondition for an **Apotheosis → Succession** throne ending. The path you qualified *through* nudges which of the **9 grid-gods** you ascend as.
- **The throne-climb is competitive by design.** If a **named rival wins their circuit before you do**, *they* take the Reckoning slot — and **ascend**, snapshotting into their **unique DG-###** as a future **invasion boss** (the async loop). Every champion's league you *don't* win becomes a god you'll later fight. This is the literal mechanism by which "a champion's league feeds the throne climb": the competition leaderboard *is* the Succession bracket.
- **The God-Maker fork.** A player who maxes the **Contest** track can refuse the throne at the **Drafting Throne** (`regions.md` §11) and become the **God-Maker** instead — seeding their builds into the async pool as *god-forges* for the next ten thousand nobodies to climb toward. The Reckoning's apex is a choice between *being* a god and *making* them.

---

# Canon notes & flags (for the orchestrator)

- **Coverage:** all **6 canonical competition types** from `Mutants_Game_Bosses_Rivals.md` are authored — **Battle Leagues** (§1: 6 full ladders + 3 stubbed), **The Arena** (§2: 4 seasons), **Breeding Shows** (§3: 2 full panels + 2 stubbed), **Lab-Craft Contests** (§4: 2 full panels + 2 stubbed), **Clan Wars** (§5: 4 fronts + the Table's mercenary variant), **Bounties** (§6: 4 boards). **Named-event total: 24 fully-authored events** (6 leagues + 4 Arena seasons + 2 shows + 2 contests + 4 wars + 4 bounty-boards + the Reckoning meta-track + 1 mercenary variant), plus ~11 stubbed sub-events at the same template for later expansion.
- **Rivals featured (all 24, by canon name):** every named nemesis B1–B24 appears in at least one competition as a Crown-holder, judge, finalist, front-combatant, or bounty target — placed at the venue + format + grid that `economy_items_rivals.md` / `roster_shops_expansion.md` already assigned them (e.g. Pyx in Lab-Craft/Revel, the Widow Sorrel in Breeding/Bloomwardens, Quint in the Storm Circuit, Karrok in the Long Climb, Veris Calx in the Lawful Ladder). **No rival is invented; no DG-### is reassigned** — all bindings cite the existing unique mappings.
- **Standing + Succession wiring:** every ladder result moves the canon **Stranger→Associate→Sworn→Champion→Hand** ladder and explicitly states its **gate** (skill-line / Lab op / capture target / gear-slot / region access) drawn from `factions_npcs.md`. The **Aspirant's Reckoning** meta-track ties the four personal circuits to the **Apotheosis → Succession** throne-climb and the **async-invasion** loop, per the brief's ask ("a champion's league that feeds the throne climb").
- **Currency + gear consistency:** rewards use the ratified glyphs **₯ / ✶ / ◈** and the ratified **gear-slot→boost** map (Relic→capture · Tool→lab · Vestment→combat · Charm→tame · Glyph→breed). Leagues/Arena lean ₯+Renown→◈ at apex; Shows/Contests pay ✶ (the soul-economy); Bounties pay ◈ (the Table's divine coin).
- **No new canon invented.** Venues reuse the `regions.md` set-pieces (the Arena, the Cairn, the Mercy-Garden, the Unfinished Assembly, the Long Party, the Kelp-Cathedral, the Falling Court, the Ledger-Barrow, the Hall of Empty Thrones); announcers/judges reuse named NPCs from `factions_npcs.md` + `regions.md` + `roster_shops_expansion.md`. No new creatures, stats, gods, or factions were created — only force/role/tier and existing-name references.
- **CANON GAP (minor, flagged not invented):** `Mutants_Game_Bosses_Rivals.md` names the 6 types and the rewards but specifies **no leaderboard/qualifier meta-structure** linking competitions to the Succession. The **Aspirant's Reckoning** is an authored *connective tissue* proposal (consistent with the doc's "leaderboard rank… raises notoriety" line and `Character.md`'s ascension forks) — recommend the orchestrator ratify it (or rename) before the §Game-loop sim wires competition→ascension. Nothing here contradicts a locked doc; the Reckoning only *names* a track the canon implies.
- **CANON GAP (already-scheduled):** the Iron Guild's, Bloomwardens', and Unbound's **Battle Leagues** are stubbed (not full ladders) to keep MVP scope tight — they reuse the §1 template and their canon Crown-rivals (Halix/Castle, Sorrel, Ruskin) are already placed. Flag for a wave-2 expansion pass if full ladders are wanted.

*Six ways to climb over the other nobodies, and every trophy a rung on a taller grave with a better view. The crowd is loyal to the verb. So is the throne.*
