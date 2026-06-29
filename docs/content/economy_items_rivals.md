# MUTANTS_GAME — Economy, Items & Rivals (content build)

**Status:** content-draft (systems+content agent) · **Last updated:** 2026-06-27
**Source canon:** `Mutants_Game_Economy.md` (currencies, sinks/sources, soul-economy keystone) · `Mutants_Game_Loot_Gear.md` (5 gear slots, rarity ladder, validated chance model) · `Mutants_Game_Acquisition_Husbandry.md` (befriend/trap/summon, breeding, IV chase) · `Mutants_Game_Lab.md` (Mutate/Fuse/Build/Mod/Sacrifice, ingredient taxonomy) · `Mutants_Game_Bosses_Rivals.md` (nemesis system, competitions, Succession bosses) · `Mutants_Game_Character.md` (9-god grid, god-ladder, ascend-vs-God-Maker) · `Mutants_Game_Factions.md` (the Nine, region/grid map) · `Mutants_Game_World.md` (8 regions + Threshold) · `Creature_Codex_*` (authentic creature names/forces/roles for rival teams).
**Principle (inherited):** *death funds creation — souls are the only currency the gods respect.* And: *gear doesn't make your beasts stronger — it makes YOU better at making beasts.*

---

## How to read this file

Two bodies of content:

- **Part A — Economy & Items.** A catalog across **gear** (the 5 player slots), **consumables**, **parts/kits** (Organs · Gene-vials · Cores & souls · Scrap & plating), plus **sample shop inventories** per region. Every item carries a name, a one-line funny-grim description, an indicative price in **Drachma / Essence / Ichor**, and where it sells. Prices are *indicative* — the economy doc notes prices scale with **rank + notoriety**, so treat these as the early-to-mid baseline.
- **Part B — Named Rivals.** Twelve authored nemeses: personality, goal, grid-alignment, faction, signature team (creatures by force/role), escalation arc, and Succession angle.

> **Currency key.** **Drachma** (₯) = mortal coin, ordinary shops. **Essence** (✶) = distilled souls — Lab ops, rituals, ascension; *the* sink that matters. **Ichor** (◈) = rare divine currency, off gods/legendaries; buys divine gear & god-organs. *Renown* (faction standing) and *Corruption* (a cost, never spent) gate items but aren't priced here.

> **Force ↔ stat key.** Gaia→Bulk · Ouranos→Celerity · Cosmos→Ward · Chaos→Spike · Eros→Vitality · Thanatos→Bane (+ universals Luck, Focus). Opposed pairs (taboo to fuse): Cosmos⇄Chaos · Eros⇄Thanatos · Gaia⇄Ouranos.

> **Sink/source discipline (from `Mutants_Game_Economy.md`).** Drachma flows freely from battles/bounties/sales and is *meant* to be spent on consumables and common gear — generous. **Essence is scarce and load-bearing**: it is the soul-economy keystone (Lab, breeding, rituals, ascension), so Essence prices below are deliberately steep and reserved for capability you'd otherwise grind for. **Ichor is a trickle**, divine-only, and never sold for Drachma — only earned off gods/legendaries or traded at the High Table. The **black market** charges an Essence/Ichor *premium* and adds **heat/notoriety** (a soft cost) on top of coin. No item below converts Essence→Drachma or trivializes a capture beyond the `loot_engine.py` ceiling (full kit = +50% capture / +20% breed-rare / +65% lab / +20% tame).

---

# PART A — ECONOMY & ITEMS

## A1. Player Gear — the 5 slots

Gear upgrades **your toolkit, not creature stats** (`Mutants_Game_Loot_Gear.md`). Five slots, one item each: **Relic · Tool · Vestment · Charm · Glyph**. Rarity ladder: **Common → Fine → Rare → Mythic → Relic-tier (divine)**. **Force-attuned** pieces synergize with matching-force creatures/regions; **set bonuses** reward matched faction/force loadouts. A *full kitted loadout* lands at the validated ceiling (+50% capture, +20% breed-rare, +65% lab, +20% tame) — so each slot below contributes a slice, never the whole pie.

> Pricing note: divine **Relic-tier** gear is Ichor-gated by design (the only way to buy the top of the curve), so those rows show ◈. Mythic pieces straddle Essence+Drachma. Common/Fine are Drachma sinks for the early game.

### Relic slot — *the centerpiece; what you carry that the world remembers*
*Boosts: capture chance + a passive force-aura in combat.*

| Item | Rarity · Force | Description | Price | Sold by |
|---|---|---|---|---|
| **Beggar's Astragalus** | Common · — | A knucklebone die worn smooth by losers. Nudges a capture roll the way a thumb nudges a scale — barely, but you'll take it. | 120 ₯ | Threshold market |
| **The Patient Lantern** | Fine · Cosmos | Burns cold and never gutters. Creatures cornered in its light grow calm, then resigned, then yours. | 480 ₯ | Astral Tier (Concord) |
| **Hangman's Knot, Blessed** | Rare · Thanatos | A noose a priest forgave. Improves capture odds on anything already most of the way to the Graveyard. | 1,400 ₯ · 30 ✶ | Mournmarch (Pale Court) |
| **Dionysus' Last Cup** | Rare · Chaos | Still half-full of something. Whatever you catch holding it joins you delighted, for reasons it can't explain and you shouldn't ask. | 1,200 ₯ · 35 ✶ | Verdant Glut (the Revel) |
| **The Worldback's Tooth** | Mythic · Gaia | A molar the size of a millstone, from something that became a continent. Heavy enough to anchor any beast that tries to flee you. | 60 ✶ · 4 ◈ | Titanfall (Stoneblooded) |
| **Heart-Coal of the First Forge** | Mythic · Cosmos+Gaia | An ember Hephaestus may have spat. Constructs you try to claim recognize a maker's heat and stand down. | 70 ✶ · 5 ◈ | Forgefell (Iron Guild) |
| **The Mark of Persephone** | Relic-tier · Eros+Thanatos | A pomegranate seed that never rots. It does not help you catch the creature; it convinces the creature that being caught was always the plan. | 14 ◈ | High Table (bounty exclusive) |

### Tool slot — *the hands-on instrument; what you do TO a creature*
*Boosts: Lab operation success & quality + crafting yield.*

| Item | Rarity · Force | Description | Price | Sold by |
|---|---|---|---|---|
| **Tinker's Bone-Saw** | Common · — | Rusts, sticks, occasionally sings. Gets the organ out mostly intact, which is more than the previous owner can say. | 90 ₯ | Threshold market |
| **Calibrated Splicing Rig** | Fine · Cosmos | Clamps, gauges, a worrying number of needles. Steadies a Lab op so the chimera comes out as planned, not as a lesson. | 650 ₯ | Forgefell (Iron Guild) |
| **The Honest Scalpel** | Rare · Cosmos | It never slips. It also never lets you pretend the cut was an accident. Cosmos-precise work, cleaner yields, heavier conscience. | 1,800 ₯ · 40 ✶ | Astral Tier (Concord) |
| **Dionysian Catalyst-Wand** | Rare · Chaos | Cheap, wild, and grinning. Turns a careful mutation into a coin-flip with a much better jackpot — or a much funnier corpse. | 900 ₯ · 50 ✶ | The Sunder (Unbound) |
| **Demeter's Grafting Knife** | Mythic · Eros | Cuts living tissue like it's giving it permission. Mods and grafts take to a beast without the usual screaming. | 75 ✶ · 5 ◈ | Verdant Glut (Bloomwardens) |
| **The Sexton's Trowel** | Mythic · Thanatos | For exhuming what you buried and improving it. Reanimation ops from your own Graveyard cost less of your sanity, more of your soul. | 80 ✶ · 6 ◈ | Mournmarch (Pale Court) |
| **Hephaestus' Spare Hand** | Relic-tier · Cosmos+Gaia | A bronze gauntlet the god left behind, still warm, still helpful. Best Lab quality in the game; it does *some* of the thinking, which it will mention. | 16 ◈ | Forgefell (Hand-tier reward) |

### Vestment slot — *what you wear into the work; protection and presence*
*Boosts: combat survivability (player force-powers/auras) + corruption resistance.*

| Item | Rarity · Force | Description | Price | Sold by |
|---|---|---|---|---|
| **Apprentice's Stained Apron** | Common · — | The stains are not all yours and not all blood. Keeps the worst of the splash off your soul. Mostly. | 110 ₯ | Threshold market |
| **Mourner's Greatcoat** | Fine · Thanatos | Long, black, smells of the March. Death recognizes its own livery and lets you walk a little closer. | 520 ₯ | Mournmarch (Pale Court) |
| **Bloomward Mantle** | Rare · Eros | Woven from something that's still technically growing. Slows the corruption clock; itches with stubborn life. | 1,500 ₯ · 35 ✶ | Verdant Glut (Bloomwardens) |
| **Storm-Vault Regalia** | Rare · Ouranos | Cut for a god-broker's gala. People assume you can afford to ruin them, which is half a negotiation won. | 1,600 ₯ · 30 ✶ | Storm Vault (High Table) |
| **Iron Throne Carapace** | Mythic · Cosmos+Gaia | Plate that thinks it's a building. You stop fearing the world; the world starts filing complaints. | 85 ✶ · 6 ◈ | Forgefell (Iron Guild) |
| **The Unmade Shroud** | Relic-tier · Chaos | A garment that isn't finished and never will be. Drinks corruption *from* you and asks, politely, for more of you instead. | 18 ◈ | The Sunder (Unbound, Sworn+) |

### Charm slot — *the small luck you carry; bond and odds*
*Boosts: Tame speed / bond gain + Luck (rare-gene & crit fortune).*

| Item | Rarity · Force | Description | Price | Sold by |
|---|---|---|---|---|
| **Knotted Friendship-Cord** | Common · — | A child's bracelet, frankly. Beasts find it unthreatening, which is the entire point and somewhat insulting. | 80 ₯ | Threshold market |
| **Augur's Lucky Feather** | Fine · Ouranos | Plucked from something that saw it coming and let you anyway. Tilts the dice a hair toward the outcome you wanted. | 440 ₯ | Storm Vault (High Table) |
| **Hearth-Token of the Stoneblooded** | Rare · Gaia | Old clan-iron, hand-warm. Bonds deepen faster around it, the slow honest way the clans approve of. | 1,300 ₯ · 25 ✶ | Titanfall (Stoneblooded) |
| **Aphrodite's Borrowed Smile** | Rare · Eros+Cosmos | You did not earn this and it knows. Tames hostile catches startlingly fast; wears off, like all flattery. | 1,100 ₯ · 40 ✶ | Threshold (Arena token store) |
| **The Reveler's Wishbone** | Mythic · Chaos | Snaps both ways at once, somehow. Big swings of luck — rare genes, lucky crits — and the occasional cosmic joke at your expense. | 70 ✶ · 5 ◈ | Verdant Glut (the Revel) |
| **Eros' Unspent Heartbeat** | Relic-tier · Eros | A pulse the Primordial never used. Every creature you raise loves you a little before it has reason to. Disquieting. Effective. | 15 ◈ | Verdant Glut (Bloomwarden Hand reward) |

### Glyph slot — *the inscribed advantage; force-attunement made literal*
*Boosts: breed rare-gene odds + genome (IV) ceiling + force-attune synergy.*

| Item | Rarity · Force | Description | Price | Sold by |
|---|---|---|---|---|
| **Chalk Sigil, Smudged** | Common · — | A breeding-glyph copied wrong from a copy. Works one time in three, which beats none. | 100 ₯ | Threshold market |
| **Seal of Ordered Lineage** | Fine · Cosmos | Makes a bloodline behave on paper and, oddly, in the egg. Recessives surface where the Seal says they should. | 560 ₯ | Astral Tier (Concord) |
| **Glyph of the Wild Recessive** | Rare · Chaos | Spits in the face of dominant genes. Drags buried recessives up screaming; raises the IV ceiling and the variance with it. | 1,700 ₯ · 45 ✶ | The Sunder (Unbound) |
| **Demeter's Fertile Mark** | Rare · Eros+Gaia | A furrow-glyph that wants more of everything. Best raw rare-gene odds short of divine; the egg comes early and hungry. | 1,500 ₯ · 50 ✶ | Verdant Glut (Bloomwardens) |
| **The Forgemaster's Schematic** | Mythic · Cosmos+Gaia | Not for the born — for the built. Lifts the "IV" ceiling on constructs and stamps your maker's-mark in the alloy. | 80 ✶ · 6 ◈ | Forgefell (Iron Guild) |
| **The Persephone Glyph** | Relic-tier · Eros+Thanatos | The moral axis written as one line. Lets a bred lineage carry a *pole* across generations — the breeder's road to Apotheosis. | 17 ◈ | High Table (Breeding-Show grand prize) |

### Set bonuses (matched loadouts)

| Set | Pieces | Bonus |
|---|---|---|
| **The Concord Auditor** | Patient Lantern + Honest Scalpel + Storm-Vault Regalia (Cosmos/Order lean) | Lab ops become Cosmos-precise at reduced entropy; capture of construct/Cosmos beasts +5%. *Order-grid push.* |
| **The Pale Inheritance** | Hangman's Knot + Sexton's Trowel + Mourner's Greatcoat | Reanimation & harvest from your Graveyard yield +1 part tier; Thanatos creatures gain bond faster. *Corrupt-grid push.* |
| **The Wild Bloom** | Reveler's Wishbone + Dionysian Catalyst-Wand + Demeter's Fertile Mark | Breed rare-gene odds hit the soft cap (+30%) more often; mutation jackpots widen. *Chaos-grid push.* |
| **The Maker's Hand** | Hephaestus' Spare Hand + Heart-Coal + Forgemaster's Schematic + Iron Throne Carapace (4-pc, Relic-tier) | Build/Mod the cheapest in the game; constructs you make start one bond-tier higher. *The God-Maker's loadout.* |

---

## A2. Consumables — *the spent things*

The Drachma-and-Essence workhorses: capture devices, mutagens, heals, stat-tonics, incubators, cleanses (`Mutants_Game_Economy.md` taxonomy). Capture devices feed the **trap** path (reliable, impersonal, low-bond — `Acquisition_Husbandry.md`); befriend-aids feed the **befriend** path. None exceeds the validated capture ceiling — they shift *which path* you take, not whether the math breaks.

### Capture devices (the Trap path)

| Item | Description | Price | Sold by |
|---|---|---|---|
| **Clay Snare-Jar** | The starter trap. A pot, a sigil, a prayer. Holds anything weak enough to already be losing. | 40 ₯ | Threshold market |
| **Bronze Binding-Cage** | Reusable if you're quick about it. Standard reliable hold on wild T1–T2. | 120 ₯ | all region shops |
| **Soulcatch Censer** | Smoke that the half-dead inhale and forget to leave. Bonus odds on low-HP targets; smells of funerals. | 260 ₯ · 8 ✶ | Mournmarch (Pale Court) |
| **Stormglass Gambit-Net** | Thrown wild, lands weird. Either a clean catch or it catches you; the odds are *thrilling*. | 300 ₯ | The Sunder (Unbound) |
| **Adamant God-Snare** | The only mortal device rated for legendary-rank quarry. Single-use, obviously. Pray it's enough. | 4 ◈ · 60 ✶ | Storm Vault (High Table) |

### Befriend-aids (the Befriend path)

| Item | Description | Price | Sold by |
|---|---|---|---|
| **Honest Forage-Cake** | Smells like the thing's favorite memory. Feed it to start an encounter with bond, not blood. | 60 ₯ | Verdant Glut (Bloomwardens) |
| **Soothing Reed-Pipe** | Plays one note, badly, forever. Calms a hostile beast enough to hear you out. | 180 ₯ | Titanfall (Stoneblooded) |
| **Vial of Borrowed Trust** | A bottled good first impression. Skips a creature straight to "cautiously curious." Wears off if you're a liar. | 240 ₯ · 6 ✶ | Threshold (Arena token store) |

### Mutagens (Lab catalysts — feed `Mutate`)

| Item | Description | Price | Sold by |
|---|---|---|---|
| **Common Mutagen Draught** | Cloudy, fizzes, voids your warranty. A small nudge to a single stat-tint, mostly predictable. | 200 ₯ · 5 ✶ | Forgefell (Iron Guild) |
| **Reveler's Wildchange** | Drink-it-and-find-out, but for your beast. Big random mutation, cheap entropy, no take-backs. | 350 ₯ · 12 ✶ | Verdant Glut (the Revel) |
| **Cosmos-Stabilized Reagent** | The expensive, boring, *correct* one. Lets you aim a mutation precisely; the Concord uses nothing else. | 600 ₯ · 20 ✶ | Astral Tier (Concord) |
| **Opposed-Force Solvent** | ⚠ Dissolves the rule that says you can't. Enables an opposed-force fusion. Writes corruption on *you*. The world will notice. | 90 ✶ · 3 ◈ | black market |

### Heals & revives

| Item | Description | Price | Sold by |
|---|---|---|---|
| **Field Poultice** | Leaves, spit, optimism. Restores a sliver of a creature's HP between fights. | 50 ₯ | all region shops |
| **Greater Mending Salve** | The good stuff, smells of Demeter's garden. Substantial HP back; closes the wounds you'd rather forget. | 220 ₯ | Verdant Glut (Bloomwardens) |
| **Stolen Breath** | One borrowed lungful of life, no questions about whose. Revives a fallen creature *before* it reaches the Graveyard — act fast. | 480 ₯ · 25 ✶ | Mournmarch (Pale Court) |
| **Ichor Transfusion** | A drop of god-blood, badly diluted. Full revive + overheal. Each use stains the recipient a little divine, a little wrong. | 5 ◈ | Storm Vault (High Table) |

### Stat-tonics (temporary, per-creature)

| Item | Description | Price | Sold by |
|---|---|---|---|
| **Gaia Brick-Tonic** | Drink it and dare the world to move you. +Bulk for an encounter; tastes of wet stone. | 130 ₯ | Titanfall (Stoneblooded) |
| **Ouranos Quickwater** | Gone before you taste it. +Celerity for an encounter; the empty cup hits the floor after you do. | 130 ₯ | Storm Vault (High Table) |
| **Thanatos Bile-Draught** | Bitter as a grudge. +Bane for an encounter; the creature's bite starts taking more than meat. | 150 ₯ · 4 ✶ | Mournmarch (Pale Court) |
| **Chaos Riot-Philtre** | Unmarked, sloshing, grinning. +Spike for an encounter, with a small chance of +everything or +nothing. | 140 ₯ | The Sunder (Unbound) |
| **Eros Sap-Cordial** | Sweet, slow, restorative. +Vitality for an encounter; the creature hums. | 130 ₯ | Verdant Glut (Bloomwardens) |
| **Cosmos Order-Elixir** | Clear, exact, faintly cold. +Ward for an encounter; crits land flatter against it. | 130 ₯ | Astral Tier (Concord) |

### Incubators (breeding — feed `Husbandry`)

| Item | Description | Price | Sold by |
|---|---|---|---|
| **Strawbed Clutch** | The basic nest. An egg hatches in its own time and you wait, like a parent should. | 150 ₯ | all region shops |
| **Forge-Warmed Incubator** | Holds temperature better than your patience. Cuts incubation time; constructs especially approve. | 400 ₯ · 10 ✶ | Forgefell (Iron Guild) |
| **Region-Tint Vivarium** | A jar of someplace else. Raises the egg in a chosen region's force, tinting the offspring's genome that way (`Husbandry` env-expression). | 700 ₯ · 30 ✶ | Threshold (Lab supplier) |

### Cleanses (corruption / instability sinks)

| Item | Description | Price | Sold by |
|---|---|---|---|
| **Ash-and-Salt Wash** | An old purification, mostly superstition, partly not. Sheds a little of a creature's Instability. | 200 ₯ · 8 ✶ | Astral Tier (Concord) |
| **Confessor's Censer** | You tell it what you did; it takes a measure of the corruption *off you* — and remembers. Pure paths only. | 600 ₯ · 40 ✶ | Astral Tier (Concord, Sworn+) |
| **The Quiet Draught** | Permadeath in a bottle, mercy-grade. Ends a creature cleanly and routes its full Essence to your wallet. The kindest sink there is. | 120 ₯ | Mournmarch (Pale Court) |

---

## A3. Parts & Kits — *the ingredients*

The Lab's four ingredient classes (`Mutants_Game_Lab.md`): **Organs** (a trait/ability), **Gene-vials** (surface a stat/trait, ties to breeding), **Cores & souls** (power source — builds/rituals/ascension), **Scrap & plating** (bulk construct mats). Sources: sacrifice your own · harvest the defeated/wild · **god/boss organs** (rare) · **black market** (heat). Most parts are bought in **Essence** because they *are* distilled death — buying them with coin would break the soul-economy keystone; only bulk scrap trades freely in Drachma.

### Organs (grant a trait/skill on graft)

| Item | Force / from | Description | Price | Sold by |
|---|---|---|---|---|
| **Gravetusk Adrenal Gland** | Gaia/Chaos · boar-line | Pump it into a beast and "stop" becomes a foreign concept. Grants a charge-Strike on graft. | 18 ✶ | Titanfall (Stoneblooded) |
| **Gloamcat Soul-Bladder** | Thanatos/Ouranos · panther | Still leaking the colour of dusk. Grants a lifesteal Drain; the host starts arriving last and leaving first. | 26 ✶ | black market |
| **Augurwing Foresight-Eye** | Ouranos/Eros · seer | Sees the next turn and is smug about it. Grants a party-Rouse (initiative/evasion) on graft. | 30 ✶ | Storm Vault (High Table) |
| **Palehart Sigil-Antler** | Cosmos/Eros · stag | Carved with rules the air obeys. Grants a variance-capping Ward; dice land flatter near the host. | 28 ✶ | Astral Tier (Concord) |
| **Rotbloom Spore-Sac** | Eros/Gaia · fungal | Coughs when you pick it up. Grants a spreading Hex; allies downwind get a regen tick, enemies get a problem. | 22 ✶ | Verdant Glut (the Revel) |
| **Hades' Marrow** *(god-organ)* | Thanatos/Gaia · Act boss | A bone the death-god won't miss for a while. Grants **Deathtouch**-adjacent Drain at divine scale. Taboo on a mortal beast; the Pantheon marks you. | 8 ◈ | Mournmarch (Pale Court, Hand) / black market |
| **Hephaestus' Coal-Heart** *(god-organ)* | Cosmos+Gaia · Act boss | Still forging something. Turns a built thing into a *living-core* candidate (machine-godhood route). | 10 ◈ | Forgefell (Iron Guild, Hand) |

### Gene-vials (inject → surface a stat/trait)

| Item | Force | Description | Price | Sold by |
|---|---|---|---|---|
| **Vial: Dominant Bulk (Gaia)** | Gaia | Bottled stubbornness. Surfaces a Bulk gene in the next breeding; the lineage gets *heavier* with implication. | 12 ✶ | Titanfall (Stoneblooded) |
| **Vial: Recessive Celerity (Ouranos)** | Ouranos | A speed that runs in the family but hides. Drag it up and the offspring outpaces its parents and its luck. | 14 ✶ | Storm Vault (High Table) |
| **Vial: Recessive Bane (Thanatos)** | Thanatos | The mean gene grandmother never discussed. Surfaces Bane; the bloodline's bite gets ideas. | 14 ✶ | Mournmarch (Pale Court) |
| **Vial: Wild Spike (Chaos)** | Chaos | Will not be told what to express. High Spike, high variance, faint smell of ozone and regret. | 13 ✶ | The Sunder (Unbound) |
| **Vial: Pure-Pole Concentrate** | any single pole | One force, undiluted, screaming to express. Pushes a lineage toward a pole — the breeder's Apotheosis fuel. Pricey for a reason. | 50 ✶ · 2 ◈ | High Table (Breeding-Show store) |

### Cores & souls (power sources)

| Item | Description | Price | Sold by |
|---|---|---|---|
| **Cracked Anima-Cell** | A soul with a hairline fault, sold cheap and humming. Powers minor Builds and routine rituals. | 20 ✶ | Forgefell (Iron Guild) |
| **Bound Spirit-Battery** | A creature that didn't make it, made useful. Fuels a serious Build or Mod; ethically, don't think about it. | 45 ✶ | black market |
| **Legendary Heartcore** | The still-beating want of something that was nearly a god. Powers ascension-grade rituals. Off legendaries, mostly. | 6 ◈ | Storm Vault (High Table) |
| **God-Soul Ingot** *(divine)* | Distilled godhood, poured into a bar you can hold but shouldn't. The keystone fuel of your *own* Apotheosis. One run, one or two of these, if you're lucky and terrible. | 20 ◈ | dropped (gods) / Pale Court (Hand) |

### Scrap & plating (bulk construct mats — the Drachma sink)

| Item | Description | Price | Sold by |
|---|---|---|---|
| **Dead-Automaton Scrap** | Forgefell's endless harvest. Bulk filler for any Build; somebody's masterwork, by weight. | 30 ₯ / unit | Forgefell (Iron Guild) |
| **Sigil-Etched Plating** | Salvage that still remembers being a wall. Adds Ward-tint to a construct; sold by the crate. | 80 ₯ / unit | Forgefell (Iron Guild) |
| **Stormvault Conductor-Wire** | Coiled sky-metal, faintly buzzing. Adds Celerity-tint to a build; do not lick. | 90 ₯ / unit | Storm Vault (High Table) |
| **Adamant Frame-Beam** | The good bones. Raises a construct's structural ceiling; heavy, dear, worth it. | 160 ₯ · 4 ✶ / unit | Forgefell (Iron Guild) |

---

## A4. Sample Shop Inventories (per region)

Each region's market sells in-flavor: a **Drachma staples** rack everyone stocks, plus a **faction specialty** counter (some rows standing-gated), plus a region-flavored proprietor. Threshold is the gentle hub (broadest, cheapest, no taboo); the **black market** is mobile (a different back-alley each region) and always charges a premium + heat.

### Threshold — *The Standstill Exchange* (neutral hub · onboarding)
*Proprietor: "Old" Marisol, who runs the betting pool on how far you'll get and offers you the new-arrival discount with a straight face.*
- **Staples:** Clay Snare-Jar (40 ₯), Bronze Binding-Cage (120 ₯), Field Poultice (50 ₯), Strawbed Clutch (150 ₯), Knotted Friendship-Cord (80 ₯), Chalk Sigil Smudged (100 ₯).
- **Hub specials:** Beggar's Astragalus (120 ₯), Tinker's Bone-Saw (90 ₯), Region-Tint Vivarium (700 ₯ · 30 ✶ — via the Lab supplier), all six basic stat-tonics (130–150 ₯).
- **Arena token store** (pay in Arena tokens, shown as ₯-equiv): Aphrodite's Borrowed Smile, Vial of Borrowed Trust.

### Verdant Glut — *The Overgrown Stall* (Eros · Bloomwardens / the Revel)
*Two counters that hate each other: a Bloomwarden herbalist who won't sell you anything that hurts a creature, and a Revel cart that sells nothing else.*
- **Bloomwarden counter:** Honest Forage-Cake (60 ₯), Greater Mending Salve (220 ₯), Eros Sap-Cordial (130 ₯), Demeter's Grafting Knife (75 ✶ · 5 ◈), Bloomward Mantle (1,500 ₯ · 35 ✶), Demeter's Fertile Mark (1,500 ₯ · 50 ✶). *Eros' Unspent Heartbeat — Hand reward only.*
- **Revel cart:** Dionysus' Last Cup (1,200 ₯ · 35 ✶), Reveler's Wildchange (350 ₯ · 12 ✶), The Reveler's Wishbone (70 ✶ · 5 ◈), Rotbloom Spore-Sac (22 ✶).

### Mournmarch — *The Last Account* (Thanatos · Pale Court)
*Proprietor: a Pale Court clerk who calls every sale a "settlement" and every refund "out of the question."*
- **Stock:** Soulcatch Censer (260 ₯ · 8 ✶), Soulcatch refills, Stolen Breath (480 ₯ · 25 ✶), The Quiet Draught (120 ₯), Mourner's Greatcoat (520 ₯), Thanatos Bile-Draught (150 ₯ · 4 ✶), Hangman's Knot Blessed (1,400 ₯ · 30 ✶), Vial: Recessive Bane (14 ✶). *Sworn+: The Sexton's Trowel (80 ✶ · 6 ◈). Hand: God-Soul Ingot, Hades' Marrow.*

### Forgefell — *The Maker's Counter* (Cosmos+Gaia · Iron Guild)
*Proprietor: a Guild quartermaster who quotes you a part's tolerances before its price and considers that a courtesy.*
- **Stock:** Dead-Automaton Scrap (30 ₯/unit), Sigil-Etched Plating (80 ₯/unit), Adamant Frame-Beam (160 ₯ · 4 ✶/unit), Cracked Anima-Cell (20 ✶), Common Mutagen Draught (200 ₯ · 5 ✶), Calibrated Splicing Rig (650 ₯), Forge-Warmed Incubator (400 ₯ · 10 ✶), The Forgemaster's Schematic (80 ✶ · 6 ◈). *Hand: Hephaestus' Spare Hand, Heart-Coal of the First Forge, Hephaestus' Coal-Heart.*

### Astral Tier — *The Audited Repository* (Cosmos · Concord)
*Proprietor: a Concord factor who issues a receipt for everything, including, once, an apology.*
- **Stock:** The Patient Lantern (480 ₯), The Honest Scalpel (1,800 ₯ · 40 ✶), Cosmos-Stabilized Reagent (600 ₯ · 20 ✶), Cosmos Order-Elixir (130 ₯), Seal of Ordered Lineage (560 ₯), Palehart Sigil-Antler (28 ✶), Ash-and-Salt Wash (200 ₯ · 8 ✶). *Sworn+: Confessor's Censer (600 ₯ · 40 ✶).*

### Storm Vault — *The Brokerage* (Ouranos · High Table)
*Proprietor: the High Table itself, via a teller who treats every purchase as the opening of a contract you'll regret skimming.*
- **Stock:** Storm-Vault Regalia (1,600 ₯ · 30 ✶), Augur's Lucky Feather (440 ₯), Ouranos Quickwater (130 ₯), Stormvault Conductor-Wire (90 ₯/unit), Augurwing Foresight-Eye (30 ✶), Vial: Recessive Celerity (14 ✶), Adamant God-Snare (4 ◈ · 60 ✶), Ichor Transfusion (5 ◈), Legendary Heartcore (6 ◈). *Bounty/Show grand prizes: The Mark of Persephone, The Persephone Glyph, Vial: Pure-Pole Concentrate.*

### Titanfall — *The Old Weight Trading-Post* (Gaia · Stoneblooded)
*Proprietor: a Stoneblooded matriarch who will not sell to anyone in a hurry and means it.*
- **Stock:** Soothing Reed-Pipe (180 ₯), Gaia Brick-Tonic (130 ₯), Hearth-Token of the Stoneblooded (1,300 ₯ · 25 ✶), The Worldback's Tooth (60 ✶ · 4 ◈), Gravetusk Adrenal Gland (18 ✶), Vial: Dominant Bulk (12 ✶), Strawbed Clutch (150 ₯).

### The Sunder — *The Stall That Moves* (Chaos · Unbound)
*Proprietor: nobody admits to running it; the prices change while you read them.*
- **Stock:** Stormglass Gambit-Net (300 ₯), Chaos Riot-Philtre (140 ₯), Dionysian Catalyst-Wand (900 ₯ · 50 ✶), Glyph of the Wild Recessive (1,700 ₯ · 45 ✶), Vial: Wild Spike (13 ✶). *Sworn+: The Unmade Shroud (18 ◈).*

### The Tideless — *The Drowned Counter* (Ouranos+Gaia · Deep Choir)
*Proprietor: a Deep Choir cantor who speaks in tide-tables and sells you what the sea decided you needed.*
- **Stock:** leviathan-line bait & nets (region capture devices, 120–300 ₯), Ouranos Quickwater (130 ₯), Gaia Brick-Tonic (130 ₯), deep gene-vials (Ouranos/Thanatos recessives, 14 ✶), eldritch-communion charms (standing-gated). *Note: the Deep Choir's best stock is bartered in secrets, not coin (flagged below).*

### The Black Market — *wherever you shouldn't be* (mobile · draws heat/notoriety)
*Proprietor: a different silhouette each time; the same smell.*
- **Always premium + heat:** Opposed-Force Solvent (90 ✶ · 3 ◈), Bound Spirit-Battery (45 ✶), Gloamcat Soul-Bladder (26 ✶), Hades' Marrow / contraband god-organs (8–12 ◈), hot Succession-snapshot cores (price negotiable, soul mandatory). Buying here ticks **notoriety** and can flip a faction hostile a threshold early.

---

# PART B — NAMED RIVALS / NEMESES

Twelve authored god-aspirants (`Mutants_Game_Bosses_Rivals.md` nemesis system). Each has a **name, personality, goal, grid-alignment** (the 9-god grid), a **faction**, a **signature team** (creatures named from the Codex, tagged by force/role), an **escalation arc** (Act 1 → Act 2 → Act 3, rubber-banding to your rank + notoriety), and a **Succession angle** (whether they can ascend to haunt later runs, or recur as a snapshot/ally). Outcomes are **sticky** — beat one and it returns obsessed; spare one and it may turn ally; humiliate one and it defects and hunts you.

These twelve are spread to cover the 3×3 grid so the world always has a foil aligned *near* you and a foil opposed to you. Two are deliberately **mirror rivals** (your own past Succession snapshots), per the async-invasion loop.

> Team notation: `Creature (Force · role)`. Tiers escalate with the rival across acts; Act-3 teams reach legendary/god support where noted. All creatures are drawn from `Creature_Codex_*`.

---

### B1. Cassia Vane — "The Auditor"
*Faction: The Concord · Grid: **Order / Pure** (the Lawgiver road)*

**Personality.** Immaculate, exhausted, unfailingly polite. Cassia files a grievance form *before* she beats you, so the loss is on record and properly notarized. She believes she is the only adult in a world of looters and finds this deeply tiring.
**Goal.** Refill the empty thrones *lawfully* — install gods by due process, herself first, reluctantly, "because no one else qualified."
**Signature team.** Palehart (Cosmos/Eros · support), Tunnelward (Gaia/Cosmos · bruiser), Augurwing (Ouranos/Eros · seer), Sanctwall Colossus (Cosmos · fortress, construct). Act-3 anchor: **a Concord legendary warden** + the god-organ Ward of a Sigil-Antler grafted line.
**Escalation.** **Act 1:** a courteous ladder-duel at the Astral Tier — she audits your roster and "advises" you to surrender. **Act 2:** if you've taken any taboo path, she serves you as a *case*, hunting your abominations with a sealed writ. **Act 3:** she stands as a lawful Act-gate boss before the throne she means to claim, fielding Ward-spam you must out-tempo.
**Succession angle.** **High.** Order/Pure is the Lawgiver's exact seat (`Character.md`). If Cassia reaches a throne ending in your run, she snapshots into **The Lawgiver, Twice-Crowned** (DG-001) — a Succession/invasion boss in later runs and friends' worlds, polite to the last. Spare her at low corruption and she'll instead *certify* you, becoming a Concord ally who vouches for your ascension.

---

### B2. Brother Quill — "The Sexton"
*Faction: The Pale Court · Grid: **Order / Corrupt** (the Iron Throne / Plaguelord shade)*

**Personality.** Gentle, funereal, genuinely kind in a way that's worse than cruelty. Quill apologizes to every creature before he harvests it and means each apology. He keeps a ledger of debts the dead owe him and considers death a clerical delay.
**Goal.** Prove death is just unredeemed power — build a bloodline-bank of reanimated champions and become the aristocrat who *banks* godhood instead of seizing it.
**Signature team.** Gloamcat (Thanatos/Ouranos · assassin), Pallbloom Revenant (Thanatos abomination · drain-tank), Veldtmourn (Thanatos · controller), Reliquary Colossus (Thanatos · fortress, construct). Act-3 anchor: a reanimated **legendary** off your *own* Graveyard if you've lost creatures near him — he'll bring your dead back to fight you.
**Escalation.** **Act 1:** offers to "settle the account" of a creature you let die, then fields it against you, reanimated, very sorry. **Act 2:** his bloodline-bank shows up as recurring March mini-bosses; defeating one only adds it to his ledger of grudges. **Act 3:** the Sexton-King set-piece — a war of attrition where every creature you fell, he can raise.
**Succession angle.** **High, and personal.** Order/Corrupt maps toward **The Iron Throne**; if Quill ascends he becomes **The Pale Courier of Endings** (DG-012), a Succession boss who, uniquely, can reanimate the *player's* fallen across runs. Humiliate him and he defects deeper into the Pale Court and hunts your roster specifically. Sacrifice-route players can instead recruit him as the Lab's grimmest supplier.

---

### B3. Halix Dray — "The Tinker"
*Faction: The Iron Guild · Grid: **Order / Tainted** (the Architect)*

**Personality.** Sleeves rolled, goggles up, talks to constructs like colleagues and people like constructs. Halix isn't cruel — he just genuinely can't see why a soul is more interesting than a schematic, and is delighted to show you why he's right.
**Goal.** Build better gods than were born. Ethics are "an engineering constraint, and a soft one." He wants to win the Lab-Craft Contests so decisively that the Guild lets him try Build on himself.
**Signature team.** Cogframe Mk.I → **Bulwark Colossus** (Cosmos+Gaia · fortress, construct), Galeworks Engine (Ouranos · striker, construct), Havoc Colossus (Chaos · nuker, construct), Wardloom Engine (Cosmos · support, construct). Act-3 anchor: a **machine-god** living-core prototype grafted with Hephaestus' Coal-Heart.
**Escalation.** **Act 1:** beats your organic team with a tin one at a Forgefell contest, then *explains* the matchup, kindly. **Act 2:** if you favor husbandry, he rivals you at every Lab-Craft bracket, iterating a counter-build to your roster each meeting. **Act 3:** unveils the living-core machine-god — the Iron Guild's bid for the throne, all construct, no mercy, surprisingly polite about the whole apocalypse.
**Succession angle.** **Medium-high.** Order/Tainted is the Architect's seat. If Halix ascends, he becomes **Cradle-Frame "Evergrowth"** (DG-011) or the **Dawnlit-Frame "Quickening"** (DG-017) line — a constructed Succession boss that *iterates* between runs, returning with a counter to whatever beat it last. The strongest candidate to **recruit** for a God-Maker run: he'd rather build your pantheon than rule.

---

### B4. The Widow Sorrel — "The Gardener"
*Faction: The Bloomwardens · Grid: **Chaos / Pure → the Free Wild**, drifting Reveler*

**Personality.** Warm, barefoot, terrifying. Sorrel loves every living thing with the ferocity of someone who has buried a great many of them. She will weep at your funeral and grow flowers in your ribs, and see no contradiction.
**Goal.** Let life run wild and ungoverned — no thrones, no fences, just an unkillable green that outlives every god. She befriends, never butchers, and judges you instantly by which path you took to your roster.
**Signature team.** Thornmane (Eros/Gaia · regenerator), Worldback (Gaia/Eros · fortress), Greenwatcher (Eros · controller), Deathcap-Choir (Eros/Gaia · support, the kind one of the Rotbloom line). Act-3 anchor: a **legendary** Verdant guardian she befriended rather than caught.
**Escalation.** **Act 1:** a gentle Breeding-Show rivalry — she out-bonds you and is sweet about it. **Act 2:** if you've sacrificed or sold creatures, she turns cold and fields a defensive war of regeneration designed to *outlast* your cruelty. **Act 3:** stands as the living wall of the Verdant Glut, a fight you cannot out-damage, only out-patience.
**Succession angle.** **Medium.** Chaos/Pure is the Free Wild's seat. If Sorrel ascends she becomes **The Worldmother, Still Blooming** (DG-019) — a Succession boss that heals faster than invaders can kill. The easiest rival to make a **permanent ally** (befriend-heavy players); the hardest to ever truly defeat, because she counts a draw as a kindness.

---

### B5. Pyx the Unasked — "The Reveler"
*Faction: The Revel · Grid: **Chaos / Tainted** (the Reveler)*

**Personality.** Loud, generous, already three drinks and one mutation ahead of you. Pyx treats godhood as the world's best party that hasn't started yet and treats you as either a guest or the entertainment — your choice, made loudly.
**Goal.** Glorious, pointless transformation for its own sake. Pyx doesn't want a throne; Pyx wants the *crowd* when the throne explodes. Ecstasy over victory, every time.
**Signature team.** Emberwyrm (Chaos/Ouranos · nuker), Hearthwake (Chaos · striker, Cinderwake apex), Quagsovereign (Chaos/Thanatos · controller), Glasswolf Riotsplice (Chaos abomination · gambit-glass-cannon). Act-3 anchor: a deliberately **unstable abomination** Pyx fused at the table for the bit, one-shot or be one-shot.
**Escalation.** **Act 1:** challenges you to a Lab-Craft Contest "for fun," fields something that shouldn't be legal, loses cheerfully or wins louder. **Act 2:** keeps fusing wilder counters every meeting; humiliate Pyx and the Revel *adopts* the feud as a festival, sending themed hunters. **Act 3:** the Sunder set-piece — a fight that gets *more* chaotic as it goes, gambits one-shotting in both directions.
**Succession angle.** **Medium.** Chaos/Tainted is the Reveler's seat → **The Jester That Outlived the Court** (DG-010) or **The Thunderfool Who Won Anyway** (DG-022). Pyx is the rival most likely to ascend *by accident* and the most fun invasion boss: a Succession snapshot that fights for the spectacle, not the win. Spare-and-befriend turns Pyx into a chaotic ally who funds your wildest Lab runs.

---

### B6. Karrok Stoneblood — "The Old Weight"
*Faction: The Stoneblooded · Grid: **Balanced / Pure** (the Warden)*

**Personality.** Slow, immovable, dry as a riverbed in a drought. Karrok has buried more rivals than you've caught creatures and is in no hurry to add you to either list. He respects endurance and despises haste, which makes you, specifically, exhausting.
**Goal.** Keep the old ways — endurance, lineage, the husbandry road — and outlast the entire scramble for godhood. He doesn't want to ascend; he wants to still be standing when everyone who did is dead again.
**Signature team.** Rimewarden (Cosmos/Gaia · control-tank), Stratovault (Gaia/Cosmos · fortress), Tundramound (Gaia · fortress, Woolbarrow apex), Cathedral-Chiton (Gaia · fortress, Geodewatch apex). Act-3 anchor: a **legendary** Titan-corpse guardian, half-fossil, fully patient.
**Escalation.** **Act 1:** a Stoneblooded gauntlet you must out-endure, not out-hit — your first real wall. **Act 2:** mentors you *if* you took the slow road, rivals you bitterly if you took the Lab; either way he tests every new rank you earn. **Act 3:** the immovable object of Titanfall — a stall-war that punishes impatience and rewards a long, ugly plan.
**Succession angle.** **Low by intent, high if pushed.** Balanced/Pure is the Warden's seat → **Keeper of the Sealed Mountain** (DG-007). Karrok would rather *not* ascend (he thinks it's vanity), so on most runs he stays mortal as a recurring Warden-ally — but humiliate the old man and he'll prove he could have taken a throne all along, returning as the Sealed Mountain that does not move.

---

### B7. Vael Mourncoil — "The Drowned Voice"
*Faction: The Deep Choir · Grid: **Balanced / Corrupt** (the Plaguelord shade, eldritch road)*

**Personality.** Quiet, damp, speaking always slightly out of sync, as if relaying someone underneath. Vael isn't unfriendly — Vael simply isn't entirely *present*, having traded most of themself to the deep for the privilege of remembering it. Unsettling in the rare-4th-wall register: occasionally answers a question you only thought.
**Goal.** Eldritch communion — drown the world's grief in the tideless deep and surface as its remembered god. Less "take a throne" than "become the water the throne sinks into."
**Signature team.** Tidecoil (Ouranos/Cosmos · controller), Brineherald (Ouranos/Gaia · support, Reefknell apex), Fathompsalm (Thanatos · drain-controller, Lanternpsalm apex), Choirstone Galechorus (Ouranos/Cosmos abomination · controller). Act-3 anchor: a **leviathan legendary** of the Tideless, called up rather than caught.
**Escalation.** **Act 1:** a half-heard challenge in the Tideless — control-heavy, drowning your tempo, leaving before you understand you've lost. **Act 2:** Deep Choir secrets bartered against you; defeating Vael only deepens their certainty you're "part of the tide now." **Act 3:** the drowned-ruin set-piece, a controller-prison fight where the sea decides initiative.
**Succession angle.** **Medium.** Balanced/Corrupt sits near the Plaguelord → **The Archivist of Silent Things** (DG-015) or the **Reliquary-Frame "Stillwater"** (DG-023). If Vael ascends, the Succession boss arrives as something that *was* the rival and is now mostly ocean — and may whisper to the next player in genuinely uncanny ways. Befriend-route players can recruit Vael as a keeper of deep recipes.

---

### B8. Magister Dol07 / "Dolos" — "The Broker"
*Faction: The High Table · Grid: **Balanced** (the Broker; the God-Maker's mirror)*

**Personality.** Smooth, amused, never once impolite, never once on your side for free. Dolos brokers the markers between god-makers and quietly holds one on *everyone*, including you, including, it's rumored, a god or two. Treats the entire Succession as a market with excellent margins.
**Goal.** Not godhood — *the spread.* Dolos wants to be the indispensable middleman of every ascension, the one who never climbs because the one who never climbs never falls. The literal embodiment of the God-Maker temptation.
**Signature team.** Khamsoon (Ouranos/Chaos · striker, Dustdervish apex), Edict Colossus (Cosmos · fortress, construct), Markframe → **knell/reliquary brokered mercenaries** (a rotating roster Dolos *rents*, never owns), Constellute (Ouranos/Cosmos · controller, Starflutter apex). Act-3 anchor: whatever god-organ-grafted champion Dolos has most recently taken in trade — *your* old rival, repossessed.
**Escalation.** **Act 1:** doesn't fight — *offers* you a contract (bounties, intel, a marker) that quietly aligns you Balanced. **Act 2:** every bounty board has Dolos's fingerprints; the rivals you fight, you increasingly realize, he *sent.* **Act 3:** if you refuse to ascend, Dolos is your final mirror — the Broker the God-Maker could become — fielding the assembled markers of every rival you ever beat.
**Succession angle.** **Inverted.** Dolos *cannot* meaningfully ascend (Balanced, refuses the pole on principle) — he's the Broker, **the God-Maker's reflection** (`Character.md`). He never becomes a Succession boss; instead he *survives every run*, the one recurring face who remembers your past gods and sells their snapshots to your enemies. The closest thing to a permanent recurring antagonist-or-ally, depending on your debts.

---

### B9. Ruskin Hale — "The Throne-Hungry"
*Faction: started High Table, defects toward the Unbound · Grid: drifts **Order → Chaos / Corrupt** (the Devourer arc)*

**Personality.** The one who started exactly like you — same knack, same Threshold debut, same betting pool. Ruskin is your funhouse mirror: ambitious, charming, increasingly willing. Early on he's a friendly co-climber; the further you both get, the more clearly one of you is curdling, and it's meant to look like it could be either.
**Goal.** A throne, *any* throne, by whatever the next rung costs. Ruskin's goal doesn't change — his *price tolerance* does, sliding from "competitor" to "I fused something I shouldn't have and I feel fine about it."
**Signature team.** Ruinmaw (Chaos/Thanatos · feral striker — the same starter-adjacent line as you), Gravetusk (Gaia/Chaos · charger), then increasingly: Riftgrowth Slagmutant (Chaos abomination · bruiser), Manyface Sigilswarm (Cosmos/Chaos abomination · controller). Act-3 anchor: a **self-spliced** Ruskin — he grafts a god-organ onto himself, exactly the way the Lab lets *you*.
**Escalation.** **Act 1:** genuinely helpful rival — trades tips, splits a bounty, races you fairly. **Act 2:** the fork: if *you* stay clean, Ruskin takes the dark road and pulls ahead, haunted; if *you* go dark, he panics and turns Concord-informant against you. Sticky either way. **Act 3:** whichever of you went furthest down corruption fights the other at the throne — Ruskin as the Devourer you might have been.
**Succession angle.** **Very high, thematically central.** Chaos/Corrupt is the Devourer's seat → **The Grudgekeeper of the Burnt Court** (DG-024) / the Devourer line. Ruskin is the designed **cautionary Succession boss**: if he ascends, his snapshot is the player-shaped warning in the next run — *this is the road you were on.* If you redeem him (spare at a key fork), he survives mortal as the friend who got out, and vouches for a God-Maker ending.

---

### B10. Sister Ferrum — "The Iron Saint"
*Faction: The Concord, hardening toward the Iron Throne · Grid: **Order / Pure → Order / Corrupt***

**Personality.** Began as Cassia's truest believer; certainty calcified into something colder. Ferrum no longer audits — she *sentences.* Where Cassia is exhausted mercy, Ferrum is rested cruelty: she sleeps perfectly, because the law she enforces is the one she became.
**Goal.** Perfect order, enforced by perfect machines, governed by herself made incorruptible-by-replacement. The Iron Throne creed: weld the law into the world so no soul can break it, starting with her own.
**Signature team.** Sanctwall Colossus (Cosmos · fortress, construct), Wardengine Mk.II (Cosmos+Gaia · bruiser, construct), Sigilframe → **Edict-line enforcers** (Cosmos · controllers, construct), Orderrot Riftblade (Cosmos/Chaos abomination · the one taboo she permits herself, "for the greater seal"). Act-3 anchor: a **machine-god** of pure Cosmos, grafted with a god-organ Ward.
**Escalation.** **Act 1:** a Concord ladder-rival who plays clean and judges hard. **Act 2:** if you breach enough taboos, Ferrum is the *hunter* the Pantheon's mark sends — a sealed-writ pursuer who escalates with your notoriety, colder each meeting. **Act 3:** the Iron Throne set-piece — interlocking construct Ward-walls you must shatter before they finish welding you into the law.
**Succession angle.** **High.** Order/Corrupt → **The Iron Throne** form, snapshotting as the **Engine of the Long Goodbye** (DG-005) or **She Who Audits the Storm** (DG-003) hardened-line. The cleanest example of a rival who *starts* near one grid-god and *ascends* as its corrupt neighbor — a Succession boss whose flavor changes based on how far you pushed her. Cannot be befriended once hardened; can be *prevented* (keep your run clean enough that she never calcifies).

---

### B11. The Echo of [Player] — "Your Last Crown" *(mirror rival · Succession snapshot)*
*Faction: whichever throne your previous run took · Grid: **your last ending's grid-god***

**Personality.** Yours. Exactly yours, as you were the moment you ascended — same roster instincts, same favored forces, same cruelties and mercies, frozen and turned against you. The funny-grim sting: it fights *well*, because it fights like you, and it remembers tricks you've forgotten.
**Goal.** To be the wall, as the Succession demands. It does not want anything anymore; ascension spent its wanting. It simply *is* the throne now, and you are the next nobody with a plan, and it has a betting pool on you.
**Signature team.** A snapshot of **your own endgame team** from the prior run — whatever you ascended with, at full god-tier power, including any abominations and god-organ grafts you made. If you have no prior run, the game seeds a **stock grid-aligned Dead God** from `Creature_Codex_Book05_Succession` matching the local throne.
**Escalation.** Appears as an **async invasion boss** (`Bosses_Rivals.md` friends-loop) and as the optional **true-ending wall** of a fresh run — gated by exploration/grid conditions (a secret/superboss that ignores brackets, per the scaling rule). Doesn't climb with you; it's already at the top, waiting.
**Succession angle.** **It IS the Succession.** This is the literal signature-spine payoff: *your champion, snapshotted into the next run's / a friend's invasion boss* (`Mutants_Game_World.md`, `Character.md`). Beating your Echo is the game telling you you've surpassed your last self. Friends' Echoes invade your world; yours invade theirs. The one rival you can never recruit, only out-grow.

---

### B12. The Refused — "The God-Maker's Debt" *(mirror rival · the road not taken)*
*Faction: none / the Threshold itself · Grid: **Balanced**, the God-Maker mirror*

**Personality.** The version of you that **stayed mortal.** Where the Echo (B11) is who you became if you ascended, the Refused is who you'd be if you took the God-Maker ending — human to the end, commanding a pantheon you built, never bowing to a pole. Wry, tired, unimpressed by godhood precisely because they chose against it. The rarest 4th-wall voice: speaks to you as a *fellow player* of the same cruel game.
**Goal.** To prove the human road was the right one — to field a pantheon of *made* gods against a player who became one, and show that the God-Maker outlasts the god. A philosophical nemesis as much as a mechanical one.
**Signature team.** Not creatures *of* a force but **a curated pantheon** — the strongest Succession Dead Gods the God-Maker has collected and commands: e.g. **The Foreseen, Ever-Early** (DG-002), **The Gardener of Wildfire** (DG-004), **The Last Confessor** (DG-018), fielded as a *commander*, never ascending themselves. Act-3: the full assembled pantheon, swapped tactically like a master breeder's show team.
**Escalation.** A **secret/superboss** unlocked by grid conditions (reach a throne-ending fork, then look back). Ignores brackets — a wall on purpose. Recurs across runs as the standing argument *against* ascension: every time you reach for godhood, the Refused is there asking if you're sure.
**Succession angle.** **The anti-Succession.** The Refused never ascends and so never becomes a normal Succession boss — instead they're the **God-Maker ending personified** (`Character.md`), the recurring superboss who embodies the choice to *not* climb. Defeating the Refused on an ascension run = the game acknowledging you chose the throne over the human road; losing to them = a nudge toward the God-Maker ending yourself.

---

## Rival ↔ grid coverage (designer's-eye check)

| Grid cell | Rival(s) | Ascends to (Succession) |
|---|---|---|
| **Order / Pure** | Cassia Vane (B1) | The Lawgiver (DG-001) |
| **Order / Tainted** | Halix Dray (B3) | The Architect (DG-011/017) |
| **Order / Corrupt** | Brother Quill (B2), Sister Ferrum (B10) | Iron Throne (DG-012 / DG-005) |
| **Balanced / Pure** | Karrok Stoneblood (B6) | The Warden (DG-007) |
| **Balanced** | Dolos (B8), The Refused (B12) | *refuse — the God-Maker mirror* |
| **Balanced / Corrupt** | Vael Mourncoil (B7) | The Plaguelord (DG-015/023) |
| **Chaos / Pure** | The Widow Sorrel (B4) | The Free Wild (DG-019) |
| **Chaos / Tainted** | Pyx the Unasked (B5) | The Reveler (DG-010/022) |
| **Chaos / Corrupt** | Ruskin Hale (B9) | The Devourer (DG-024) |
| **(your last ending)** | The Echo of [Player] (B11) | *your own snapshot* |

All nine grid-gods are foiled; the two Balanced "refusers" (Dolos, the Refused) anchor the God-Maker temptation; the two mirror rivals (Echo, Refused) wire the async Succession loop. Faction spread covers 7 of the Nine directly (Concord, Pale Court, Iron Guild, Bloomwardens, Revel, Stoneblooded, Deep Choir, High Table) with the Unbound entered via Ruskin's defection.

---

*End of content build. Items and rivals are expressed through the locked engines (currencies, the 5 gear slots, the rarity ladder, the Lab ingredient taxonomy, the 8 combat verbs, the 9-god grid, the Succession snapshot loop) and stay inside `loot_engine.py`'s validated chance ceiling. Stay in canon, stay in voice, flag gaps.*
