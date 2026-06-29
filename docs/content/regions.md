# MUTANTS_GAME — Regions (content build)

**Status:** content-draft (world-builder agent) · **Last updated:** 2026-06-27
**Source canon:** `Mutants_Game_World.md` (8 regions + Threshold hub, force/god/faction map) · `Mutants_Game_Factions.md` (the Nine) · `Mutants_Game_Overworld.md` (force-climate, WFC traversal) · `Mutants_Game_Story.md` (Apotheosis → Succession spine) · `Mutants_Game_Character.md` (3×3 morality grid: 9 ascension-gods + God-Maker + the Unmaking) · `Creature_Codex_Families.md` (force-tagged signature creatures).
**Principle (inherited):** *the world is a graveyard of gods, and you came to rob it.*

---

## How to read a region entry

Each region carries: **force/god identity** · **lore & history** · **inhabitants** (named NPCs/factions + signature creatures, keyed by force) · **1–2 set-pieces** (dungeon / ritual-site / landmark, usable by SimpleDungeons, each with a hook) · **flavor encounters** (funny-grim beats) · a **biome ruleset hook** (the tile palette / hazards / traversal-locks the WFC overworld generator should produce).

**Region count: 11 sections** — the **8 canonical force-regions** + the **Threshold hub** (treated as a region) + **2 net-new regions** designed in-canon (rationale below, §§10–11). The Threshold hub is deliberately gentle (onboarding); the **Verdant Glut** (Eros / Bloomwardens) is built MVP-ready and detailed per the vertical-slice scope.

**Two new regions, at a glance (full rationale at each):**
- **§10 The Maw Beneath** — a deep-corruption / abyssal underworld below the Mournmarch, where dead force pools and rots into living entropy. Anchors the **Devourer** (Chaos/Corrupt) and the **Unbound's** Unmaking path; gives the corruption pole a *place*, not just a stat.
- **§11 The Hollow Atelier** — the Lab's own domain: a half-finished demiplane the player's craft accretes into geography. Anchors the **God-Maker** ending and **The Architect** (the build-don't-be-born creed); the only region partly *authored by the player*.

> Force ↔ stat key (for the biome hooks): **Gaia**→Bulk · **Ouranos**→Celerity · **Cosmos**→Ward · **Chaos**→Spike · **Eros**→Vitality · **Thanatos**→Bane. Opposed pairs (taboo to fuse): Cosmos⇄Chaos · Eros⇄Thanatos · Gaia⇄Ouranos.

---

## 1. Threshold — the Hub *(neutral · onboarding)*

**Force / god:** none. The one place the dead gods never claimed — and the only ground the living still hold.

### Lore & history
Threshold is the last mortal city, and it knows it. It was built in the seam between eight grieving regions, on the one patch of dirt where no god fell, bled, or was buried — which is the only reason anything here still ages normally, dies on schedule, and stays dead. The founders called it Threshold because it is the doorway to everywhere and the property of no one; the priests call it that because you are always, here, on the verge of something you'll regret. Both are correct.

It is a city of embassies and apologies. Every faction keeps a house here under an old truce nobody likes and nobody breaks, because Threshold is where you *trade* — creatures, parts, contracts, the occasional soul — and a market only works if no one is currently trying to ascend in the foyer. The truce has a name (the Standstill) and exactly one rule, posted at every gate: *no godhood within the walls.* Push a creature to a pole inside Threshold and the bells ring, the Watch comes, and you finish the ritual outside like everyone else.

You begin here as a nobody with the old knack. The city does not care, which is restful. It has seen ten thousand of you walk in with a starter and a plan, and it has a betting pool on how far you get.

### Inhabitants
**Named NPCs (onboarding cast):**
- **Mother Kestrel** — keeper of the **Foundling Pens**, where your first creature is chosen. Voice: warm, blunt, tired in the way of someone who has buried a great many beasts and a few owners. Teaches catch + the bond. *"It'll love you or it'll eat you. Sometimes both, in that order. Hold out your hand anyway."*
- **The Tallyman** — High Table broker who runs the front desk of mortal ambition. Voice: dry, transactional, never quite threatening. He "invites" you to the game (the Act 0 inciting hook) the way a spider invites a fly to discuss real estate.
- **Quink** — gutter-rat Lab tutor squatting in a condemned undercroft with a stolen altar. Voice: gleeful, twitchy, four-thumbs-up about every terrible idea. Teaches your first **fuse + mutate**. *"Rule one of the Lab: it's only an abomination if it survives. Rule two: oh, that one survived."*
- **Watch-Captain Orrin** — enforces the Standstill. Voice: deadpan civil servant. The closest thing Threshold has to a god, which he finds depressing.

**Faction presence:** all Nine keep embassies, but none hold the ground — Threshold is the neutral table. The **Arena** (run by the High Table) hosts the seasonal cross-faction tournament; the **Bloomwardens'** embassy is the friendliest door and your first standing-tier on-ramp.

**Signature creatures (gentle, mixed-force — the starter pool):** the canonical adult lines in their *baby* forms gather in the Foundling Pens — **Gnawpup** (→Ruinmaw), **Sproutling** (→Worldback), **Dapplefawn** (→Palehart), **Duskling** (→Gloamcat), **Pipling** (→Augurwing), **Tusklet** (→Gravetusk). One of these is your first. Nothing here is higher than T1; nothing here will one-shot a nobody.

### Set-pieces
1. **The Foundling Pens** *(landmark / tutorial dungeon).* A rambling municipal menagerie of orphaned hatchlings nobody claimed. **Hook:** Mother Kestrel won't *give* you one — you have to walk the Pens and let one choose *you*, then survive the first wild scuffle in the training paddock to prove the bond holds. (Gate: completing the Pens unlocks the first overworld gate out to the Verdant fringe.)
2. **The Arena** *(landmark / recurring set-piece).* A sunken bowl of cracked marble where the city watches strangers try to become more than strangers. **Hook:** your first sanctioned fight is a "friendly" — except the Tallyman has quietly entered you into the lowest bracket of the seasonal tournament without asking, "for the experience." (Gate: Arena standing opens cross-faction competition brackets later.)

### Flavor encounters
- A street oracle sells "absolutely certain" prophecies of your ascension for one Drachma. They are word-for-word identical for every customer. They have, statistically, been right four times.
- The Standstill bell rings. Everyone in the market freezes mid-haggle. A sheepish aspirant is escorted out, their half-awakened creature glowing faintly with the embarrassment of nearly becoming a god in a cheese shop.
- A drunk at the embassy district swears every faction recruited him at once and now he can't remember which throne he promised his soul to. He buys you a drink. You should probably not finish it.
- A child offers to trade you a "legendary" for your starter. It is a very confident pigeon. The child is also very confident. You sense a future rival forming, somehow.

### Biome ruleset hook (WFC)
- **Palette:** dense urban tile-set — cobbled plazas, embassy facades (nine distinct faction-colored banners, each paired with an **icon/shield motif** so the read never depends on color alone), market stalls, the Arena bowl, the Lab undercroft, city gates (one per outbound region).
- **Hazards:** none lethal — Threshold is a safe hub. The only "hazard" is the **Standstill zone** (a no-godhood rule-tile that suppresses Apotheosis triggers; flavor-blocks, never damages).
- **Traversal locks:** the **eight region-gates** are the metroidvania spine — each is sealed until story/rank/faction/traversal-upgrade conditions are met. Gate 1 (→ Verdant fringe) opens at tutorial-complete. WFC should treat Threshold as a fixed hand-authored core with procedural *filler* alleys, never a fully-random layout (the hub must stay legible).

---

## 2. The Verdant Glut — Eros *(MVP starter region · the Bloomwardens)*

**Force / god:** **Eros** (Vitality). Ruled in life by **Demeter** (Eros+Gaia, the Harvest-Mother) with **Dionysus** (Chaos+Eros) creeping at the edges. Home of the **Bloomwardens** (Pure) — life is sacred; tend, heal, befriend, never butcher. The deep Glut belongs to **the Revel** (Chaos/Tainted), who think the same life is sacred *and* should be enjoyed until it screams.

### Lore & history
Demeter did not die so much as *lie down*. When the Harvest-Mother fell, she fell into the soil, and the soil took it personally. The Verdant Glut is what a goddess of growth leaves behind when nothing tells the growth to stop: a jungle that has eaten its own ruins twice over, where fruit ripens in an afternoon and rots into something with teeth by dusk, where the line between *garden* and *gullet* is a matter of how long you stand still. Eros here is not gentle romance. It is fecundity — the terrible, indiscriminate yes of life that grows over the dead, through the dead, *out of* the dead, and calls it healing.

The **Bloomwardens** tend the fringe of it, the way you'd tend a beloved animal that has begun, slowly, to regard you as fertilizer. They are healers and befrienders, the warmest faction in the world, and they will weep at the funeral of a creature they euthanized to spare it the deep Glut's mercy. They keep the **fringe** survivable — pruned, sunlit, forgiving — precisely because they've seen what the **Heart** does to the unprepared, and they would rather a nobody learn the bond among the daisies than the digestive vines.

This is where you start your climb (Act 0 → Act 1), and the Glut is kind about it. The fringe is Eros at its most generous: things heal here, the wild beasts are more curious than cruel, and a first mistake is usually survivable. The kindness is a lesson with an expiry date. The Glut wants you to relax. The Glut wants everything to relax. Relaxing is how the Glut feeds.

### Inhabitants
**Named NPCs (Bloomwarden cast — the MVP faction taste):**
- **Matron Sevvy** — local Bloomwarden mother-superior of the fringe, your first faction patron (Stranger → Associate on-ramp). Voice: tender, funny, a hugger with grief behind the eyes. Runs the **Mercy-Garden** infirmary where hurt creatures (yours and wild) are mended. *"We don't catch them, dear. We *invite* them. The cage is just somewhere to invite them into."*
- **Cobb** — a hulking, soft-spoken beast-handler who has never raised his voice and has personally carried a wounded Worldback two miles uphill. Teaches husbandry/bond mechanics. Voice: monosyllabic warmth.
- **Sister Fenwynn** — a young Bloomwarden quietly terrified that the deep Glut is *winning* and the order is in denial. Your first hint that the warm faction has a body count. Voice: earnest, fraying.
- **Old Garran the Pruner** — a hedge-witch on the Bloomwarden/Revel seam who'll teach you the first taste of *mutation* "to make it stronger, so it lives longer" — a Bloomwarden justification for a Revel act. Voice: sly grandmother, unsettlingly cheerful about rot.

**Signature creatures (Eros-primary, fringe pool — MVP roster spine):**
- **Thaliore the Quiet Green** (Eros/Gaia, god-rank) — the region's distant divine echo; not a starter, a far-off Act boss.
- Wild Eros lines (baby→mid→apex) from the families map: **Budwarden → Boughtender → Orchardmother** (orchard wardens), **Saplingstilt → Verdwade → Rootsalve** (mangrove herons, *Eros/Gaia* tidal mercy), **Drizzlet → Rainplume → Monsoonwade** (monsoon herons), **Purrwhisk → Hearthwind → Mantlemother** (hearth-cats), **Prismpup → Gleamwing → Geode-Matron** (crystal-cave bats). For the *radiant* sweetness: the **Gilt Hart / Sunfleece / Aureole** clade (Vol07).
- The **canonical adult lines** as the boss/mid spine: **Pale Hart** (Dapplefawn → Palehart) and **World Tortoise** (Sproutling → Spiked-shell → Worldback) read perfectly as Eros-fringe gentle giants.
- **MVP Legendary boss:** **Orchardmother** (apex of the orchard-warden line) or a Bloomwarden-guarded **Greenwatcher** (Eros/Thanatos, jungle stalker apex) — a guardian of the fringe-into-Heart boundary; the slice's single Legendary wall.
- **Revel creep (deep fringe):** early Chaos/Eros menace — **Tumblebaby → Riotmummer → Bigtopper** (occult carnival beasts), a first whiff of the funny-grim turn.

### Set-pieces
1. **The Mercy-Garden** *(ritual-site / soft dungeon — MVP).* A walled Bloomwarden infirmary-grove where wounded creatures are healed at living altars that run on Eros instead of sacrifice. **Hook:** something the Wardens nursed back to health has *over*-healed — a Worldback whose shell won't stop growing, now fused to the garden wall and still gently, agonizingly thriving. Matron Sevvy can't bring herself to end it; she asks you to. Your first weighty choice (mend it deeper / mercy-kill it / let the Revel "improve" it) seeds a grid nudge (Pure vs. Tainted vs. Corrupt). (Gate: completing it advances Bloomwarden standing Stranger→Associate and unlocks the Mend gear-slot reward — the MVP's one gear slot.)
2. **The Throat of the Glut** *(dungeon — fringe/Heart boundary).* The vine-choked maw where the gentle fringe ends and the digestive deep begins; a humid descent of grasping flora and over-ripe air. **Hook:** Sister Fenwynn's missing patrol went in to "prune one more meter" and didn't come back. The dungeon ends at the MVP Legendary boss guarding the boundary. (Gate: clearing it is the slice's climax and opens the *seal* to the deeper Glut for post-MVP — the metroidvania door to Act 1 proper.)

### Flavor encounters
- A wild fruit, perfectly ripe, rolls hopefully toward your party like a puppy. Your beasts perk up. It has a face. It is *so* happy to see you. (Eat / pet / flee — one of these is correct and it is not the first two.)
- A Bloomwarden funeral for a beetle. Full rites. Six mourners. You are handed a tiny shovel and a hymn-sheet. Declining is somehow the rudest thing you could do all act.
- You find a "healed" creature the Wardens released — it is now *aggressively* healthy, radiating wellness, and will not let you leave the clearing until you, too, agree that you feel great. You do not feel great. You agree anyway.
- A Revel cultist offers to "let your starter blossom into its true self" with one little mutagen. Old Garran, two clearings over, makes the exact same offer in a kindlier voice. Same act. Different smile.

### Biome ruleset hook (WFC)
- **Palette (fringe — the MVP tile-set):** sunlit jungle clearings, orchard rows, flowering canopy, mossed ruins, the Mercy-Garden walls, fungal glades (gentle). Lush, warm, high-saturation greens and golds — but pair every "safe vs. menace" tile read with **shape/icon language** (e.g. bloom-icon = safe heal-tile, fang-vine icon = hazard), never color alone.
- **Hazards (escalate with depth):** *fringe* = none lethal (heal-tiles, mild snare-vines). *Deep fringe* = grasping flora (movement-snare), over-ripe spore clouds (telegraphed, avoidable). *Heart* (post-MVP, gated) = digestive terrain, regrowing maze-walls, the Glut actively re-tiling behind you.
- **Traversal locks:** the **Throat of the Glut** seal gates the Heart behind a Bloomwarden-standing + traversal-upgrade check (a creature that can *cut* or *pacify* living walls). Eros **force-climate** weights spawns toward Vitality/heal-kit creatures and biases gene-expression of anything raised here toward Eros (the slice's husbandry showcase). Deeper = higher-tier, the legendary lurks at the seal.

---

## 3. The Mournmarch — Thanatos *(the Pale Court)*

**Force / god:** **Thanatos** (Bane). Ruled by **Hades** (Thanatos+Gaia, the Underlord — here named **Aidaneus**). Home of the **Pale Court** (Order/Corrupt): death is just unredeemed power, and the dead are a bloodline-bank you can draw against if you have the standing and the stomach.

### Lore & history
The Mournmarch is not the underworld. It is the *lip* of it — the grey country where the land has been so saturated with endings that it forgot how to begin. Hades did not fall; Hades *descended*, on purpose, and never came back up, which the Pale Court insists is winning. What he left behind is a wide cold march of barrows, ash-fens, and graveyards older than memory, where the grass is the color of a held breath and the rivers run slow because even water loses the will. Thanatos here is not violence — violence is loud and alive. Thanatos is the patient subtraction, the quiet after, the debt that always, eventually, gets collected.

The **Pale Court** is the aristocracy of that debt. They are bankers of the soul: every death in their territory is an *asset*, every bloodline a ledger, every reanimation a loan against the future with interest paid in service. They are unfailingly polite, beautifully dressed, and morally bankrupt in a way they've systematized into etiquette. They do not consider themselves evil. They consider themselves *responsible* — somebody has to manage the dead, and the dead are *so* numerous, and waste is the only real sin. They despise the Bloomwardens not because the Wardens are kind, but because the Wardens are *wasteful* — all that grief, all those funerals, all that power left to rot in the ground.

You come here to trade in things the warm regions won't touch: sacrifice tech, soul-craft, the reanimation arts, and the Thanatos creatures that make a death-kit team. The Court will deal with anyone. The Court keeps *excellent* records. The Court remembers exactly what you sold them, and on which terms, and will mention it at the worst possible moment.

### Inhabitants
**Named NPCs (Pale Court cast):**
- **Lady Sepulchre** — the Court's local executrix, a Hand-tier aristocrat who manages the regional ledger of the dead. Voice: silk over iron, devastatingly courteous, never raises her voice because she has never once needed to. *"Grief is just an unpaid invoice, darling. Sign here, and I'll see your sorrow earns out."*
- **The Sexton** — gravekeeper and Lab-adjacent quest-giver who teaches reanimation/sacrifice craft. Voice: lugubrious, dust-dry, secretly the most decent person in the region and aware it's a liability. *"Everything I bury comes back if you pay enough. I keep hoping someone won't."*
- **Marrow** — a child-shaped revenant clerk who has worked the Court's front desk for two centuries and has the manners of a tired adult and the boredom of an eternal one. Hands you bounties. Voice: flat, ancient, occasionally heartbreaking.
- **Brother Quill, Defaulted** — a former Pale Court accountant who fell behind on his own soul-debt and now haunts the fens as a cautionary tale the Court points to fondly. Voice: panicked whisper. A recruitable rival-in-waiting.

**Signature creatures (Thanatos-primary):**
- **Aidaneus, the Underlord** (Thanatos/Gaia, god-rank) — the region's Act boss; killing him runs the whole march *wild* with unredeemed death.
- Wild Thanatos lines: **Sporekin → Mycelreave → Deathcap-Choir** (fungal sporelings, Thanatos/Eros), **Cinderchip → Slagwither → Basaltknell** (basalt golem-beasts), **Palltatter → Vesperdusk → Knellwing** (sepulcher moths, Thanatos/Ouranos), **Dimmote → Pallflutter → Necrolume** (astral moth-spirits, Thanatos/Chaos), **Bogslink → Sigilfen → Quagmire Adjudicant** (mire serpents, Thanatos/Cosmos — the Court's pet "magistrates").
- **Canonical adult line:** **Grave Boar** (Tusklet → Gravetusk) is a Mournmarch native — barrow-rooting, death-tusked.
- **Reanimant horrors (Pale Court exclusives, abomination-tier):** Cinderlich Boneheap, Pallbloom Revenant, Gravebloom Revenant — the Court's high-standing reanimation reward roster.
- **Dead-God echo:** **The Pale Courier of Endings** / **The Last Confessor** (Succession dead-gods) drift the deep fens as secret bosses.

### Set-pieces
1. **The Ledger-Barrow** *(dungeon / vault).* A vast tomb-archive where the Pale Court files the dead like deeds — coffin-drawers stacked to a ceiling no torch reaches, each soul a line-item. **Hook:** Lady Sepulchre offers you a name from the ledger — a powerful dead creature you may "withdraw" (reanimate as a recruit) — but the withdrawal is a *loan*, and the barrow's wards wake the collateral: a dungeon of defaulted reanimants who were *also* once withdrawn and never paid back. (Gate: clears a Pale Court standing tier; unlocks the reanimation Lab branch + a Thanatos legendary recruit.)
2. **The Drowning of Lethe** *(ritual-site).* A slow grey river the Court uses to *launder* memory off a soul before resale — dip a creature and it forgets its old bond, its old owner, its old self, becoming biddable. **Hook:** the Sexton, who runs the rite, quietly hates it and asks you to help one specific soul *resist* the Lethe — a moral fork with the Court watching. (Gate: the rite itself is a mechanic — a "memory-wipe rebond" for captured creatures; refusing it shifts grid toward Pure, completing it toward Corrupt.)

### Flavor encounters
- A funeral procession passes. It is for someone who isn't dead yet. They've been invited "to streamline the paperwork." They wave at you. They seem fine about it. The Pale Court is *very* efficient.
- You find a tombstone with your own name on it, a birth date, and a death date left blank. Beneath: *"Plot reserved. Terms negotiable. — The Court."* It is, somehow, a sales pitch.
- A revenant is on its lunch break, eating nothing, very deliberately, at a small table, because it remembers that it used to enjoy this and is determined to keep up appearances. It nods at you. You nod back. Neither of you mentions it.
- A Pale Court tax-collector apologizes profusely while repossessing a grieving widow's reanimated husband for missed payments. He leaves a condolence card. The card is also an invoice.

### Biome ruleset hook (WFC)
- **Palette:** grey-and-bone tile-set — barrow-mounds, leaning headstones, ash-fens, slow rivers (Lethe-grey), mausoleum facades, gibbet-trees, the Ledger-Barrow's drawer-walls. Desaturated, cold, low-contrast — so **shape/icon language is mandatory** for hazard vs. safe (a skull-glyph for soul-drain tiles, a coin-glyph for Court-toll tiles).
- **Hazards:** *soul-drain mist* (Bane-tile, chips Vitality over time — telegraphed by a pall), *grave-fog* (vision-reduction), *Lethe shallows* (a memory/bond-hazard, not HP damage — risks weakening a creature's bond if it lingers).
- **Traversal locks:** much of the deep march is **Pale Court standing-gated** (toll-bridges, warded barrow-doors that only open to Associates+). A traversal-upgrade (a creature that can *see through* grave-fog, or *ferry* across the Lethe without being laundered) opens the secret-boss fens. Thanatos **force-climate** weights Bane spawns and pushes gene-expression toward Thanatos — the dark mirror of the Verdant's Eros.

---

## 4. Forgefell — Cosmos+Gaia *(the Iron Guild)*

**Force / god:** **Cosmos+Gaia** (Ward + Bulk). Patron: **Hephaestus** (here **Hephaestion**, Cosmos/Gaia) — the Forge, the **Construct patron**. Home of the **Iron Guild** (Order/Tainted): build better gods than were *born*; ethics are an engineering constraint, and a solvable one.

### Lore & history
Forgefell is what happens when a god of making dies in the middle of a project. Hephaestion did not fall in battle — he fell at the workbench, and the workbench was the size of a mountain range, and it did not stop. The region is an industrial ruin that out-lived its maker: vast dead foundries, slag-glaciers, assembly halls where bronze automatons still march half-built loops because nobody ever told them the war was over or the god was gone. Cosmos here is order made *physical* — the rigid, repeating geometry of the machine — fused to Gaia's stubborn mass. It is the most *structured* land in the world, and the most haunted by purpose. Everything here was built to do something. Most of it is still doing it, badly, forever.

The **Iron Guild** moved into the corpse like engineers into a derelict factory: respectfully, ambitiously, and with a complete willingness to scrap whatever doesn't serve the design. Their creed is heresy as procedure — the gods that were *born* (organic, bred, evolved) are flawed prototypes; gods that are *built* (construct, designed, iterated) can be debugged. They are not cruel for cruelty's sake; they are cruel the way a factory is cruel — efficiently, impersonally, with excellent documentation. They will tell you, kindly, that your beloved bred creature is a "legacy system," and they will mean it as constructive feedback. They are "Tainted" on the grid not because they're sadists but because they treat souls as *materials*, and the materials sometimes scream, and the Guild has a form for that.

You come to Forgefell for the construct arts: blueprints, parts, kits, the Lab-gear that makes building (not just breeding) possible. The Guild is the only faction that will teach you to make a god from scratch — which is also, not coincidentally, the philosophy that the **God-Maker** ending is built on (see §11, the Hollow Atelier).

### Inhabitants
**Named NPCs (Iron Guild cast):**
- **Foreman Magnus Cog** — the Guild's regional master-builder, a Hand-tier engineer with bronze grafts where injuries used to be. Voice: clipped, precise, treats feelings as a tolerance problem. *"Sentiment is a manufacturing defect. We can machine it out, if you'll hold still."*
- **Tessella** — a Guild blueprint-keeper who genuinely loves her constructs the way an artist loves a sculpture, which is the closest the Guild gets to warmth. Teaches the construct-build Lab branch. Voice: passionate, technical, a little frightening when you criticize her work.
- **Old Rivet** — a retired Guildsman who is *mostly* construct now and won't say how much. Quest-giver for salvage runs. Voice: creaking, fond, increasingly literal. *"I've replaced everything but the part that worries. Working on it."*
- **Auditor Klemm** — Guild quality-control who inspects *your* creatures for "design flaws" and offers "improvements." Voice: helpful, invasive, the customer-service rep of body horror.

**Signature creatures (Cosmos/Gaia, Construct-class):**
- **Hephaestion, Patron of the Forge** (Cosmos/Gaia, god-rank) — the region's dead patron; his sleeping echo is the Act boss.
- **Talos-class machine-gods:** **Khalybion, the Forge That Woke** (Gaia) and **Aegistheon, the Wall That Numbered Itself God** (Cosmos) — self-ascended construct-gods, Forgefell's superbosses.
- **Foundry-class constructs (built, not bred — the Guild's product line):** **Cogframe Mk.I → Wardengine Mk.II → Bulwark Colossus** (Gaia/Cosmos), **Sigilframe → Wardloom Engine → Sanctwall Colossus** (Cosmos/Gaia), **Pistonward Frame → Hammerhall Engine → Anvilhall Colossus** (Cosmos/Gaia), **Markstone Frame → Wardpylon Engine → Bastionpylon Colossus** (Gaia/Cosmos). These are the high-standing build rewards.
- Wild Gaia/Cosmos crossovers wander the slag: **Grublump → Tunnelward → Stratovault** (subterranean delvers), **Shaleshell → Platewarden → Cathedral-Chiton** (cavern chiton-beasts).

### Set-pieces
1. **The Unfinished Assembly** *(dungeon / factory-crawl).* A cathedral-sized assembly hall where Hephaestion's last, greatest construct sits *84% complete* on the line, surrounded by automatons still trying to finish it from a blueprint none of them can fully read. **Hook:** the Guild wants you to either *complete* the machine-god (and decide who controls it) or *scrap* it for the legendary parts inside — but every automaton in the hall is hard-wired to defend the project to the death. (Gate: completion unlocks a construct legendary / the build-a-god Lab branch; scrapping yields a unique god-organ. Branches the Order/Tainted grid.)
2. **The Slag-Glacier Vaults** *(landmark / salvage-site).* Rivers of cooled bronze and slag, frozen mid-flow, with whole workshops trapped inside like insects in amber. **Hook:** Old Rivet sends you to recover a "legacy core" from a workshop sealed when the god fell — but the slag is *thawing* on a force-tide cycle, and the thing in the workshop has been waiting, patiently, in the warm. (Gate: a parts/kits cache + a salvage-only construct recruit; opens deeper foundry on a tide-timed lock.)

### Flavor encounters
- An automaton has been guarding a door for a thousand years. The door, and the wall it was in, are long gone. It guards the *space* where the door was, magnificently, against you. Walking around is allowed. Walking *through* is, to the automaton, an outrage.
- The Guild offers a free "performance review" of your strongest creature. The review is thorough, accurate, and quietly devastating. It comes with a quote for "remediation." You did not ask for any of this.
- You find a construct that finished its task — actually completed it, the only one in Forgefell that ever did — and then simply stopped, mid-stride, fulfilled. The Guild keeps it as a shrine. Nobody knows what the task was. Everybody is a little jealous of it.
- A foundry whistle blows for a shift change. Ten thousand automatons stop, file out, file back in, and resume identical work, having "rested." The Guild considers this good labor practice. The automatons have no opinion, and that's the point.

### Biome ruleset hook (WFC)
- **Palette:** industrial-ruin tile-set — dead foundries, slag-rivers (cooled, glassy), assembly-line halls, bronze gantries, gear-cogged floors, the Unfinished Assembly's scaffold, pylon-fields. Rigid, grid-aligned geometry (Cosmos) over heavy stone mass (Gaia) — hard-edged, repeating, deliberately *legible* structure. Hazard reads via **glyph/shape** (a gear-glyph for crusher-tiles, a heat-glyph for thaw-hazards).
- **Hazards:** *crusher/piston tiles* (rhythmic, telegraphed — a Celerity/timing check), *slag-thaw* (force-tide-cycled molten flow that opens and seals routes), *automaton patrol-loops* (predictable, exploitable forced-encounter paths).
- **Traversal locks:** the **Cosmos+Gaia** force-climate makes this the great **Ward/Bulk** region (construct-friendly, tank-friendly gene-expression). Deep foundry gates need a *construct* in the party (Guild door-keys read construct-class) or a traversal-upgrade that resists crusher-rhythm. The slag-glacier is a **tide-timed lock** (only crossable at low-thaw). Klemm's "audit" wing is standing-gated.

---

## 5. The Storm Vault — Ouranos *(the High Table)*

**Force / god:** **Ouranos** (Celerity). Ruled by **Zeus** (Ouranos+Cosmos, the Sky-Sovereign — here **Astrapios**). Home of the **High Table** (Balanced): the brokers — contracts, markers, and the *rules* between god-makers. They run the bounties, the rival network, and the neutral services, and they answer to no one because everyone owes them.

### Lore & history
The Storm Vault is the only region that never touched the ground. When the sky-king fell, he didn't crash — he *hung*, and the storm hung with him, and what remained is a shattered archipelago of floating sky-reaches stitched together by lightning and bad contracts: drifting islands of cloud-marble, thunderhead-canyons, and weather that has opinions. Ouranos here is the law of *motion and altitude* — to be high is to be powerful, to be fast is to be free, and to stand still is to fall. Nothing here is fixed; the islands drift, the storms reroute, and the only constant is the **High Table**, which floats above all of it and charges admission.

The **High Table** is not a faction so much as a *clearinghouse*. They are the brokers between every other faction, the issuers of the markers that let god-aspirants compete without immediately murdering each other, the keepers of the rival-network and the bounty-board. They are "Balanced" because balance is their *product* — they sell neutrality, and a referee who picks a side has nothing to sell. They are charming, expensive, and never quite on your side, no matter how much standing you earn, because their side is the *game itself*. They invited you in (Act 0), and they'll be there at the end, taking a cut, having bet on everyone.

You come to the Storm Vault for everything *between* the other powers: bounties on named rivals, entry to the cross-faction circuit, the contracts that let you borrow a faction's tech without joining, and the Ouranos creatures that make a fast, sky-mobile team. The Table deals in *access*. Access is the most expensive thing there is.

### Inhabitants
**Named NPCs (High Table cast):**
- **The Arbiter** — the Table's regional voice, an impeccably neutral broker who has never been seen to favor anyone and has, demonstrably, sold out everyone. Voice: smooth, amused, allergic to commitment. *"I don't take sides. I take *fees*. The fee is, currently, your side."*
- **Mercer Vane** — bounty-master who hands out the named-rival hunts (the nemesis-system on-ramp). Voice: brisk, sporting, treats your rivalries like racehorse form. *"Got a live one for you. Hates your guts, owes me money. Bring them in breathing, the breathing ones pay double."*
- **The Pythian** — a half-mad oracle the Table keeps on retainer to price the future. Voice: lightning-struck, speaks in odds. Sells *probabilistic* prophecy (genuinely useful, legally non-binding).
- **Castellan Mio** — keeper of the floating **Vault** itself, who decides which islands you're cleared to land on. Voice: bureaucratic, vertiginously calm. The gatekeeper of altitude.

**Signature creatures (Ouranos-primary):**
- **Astrapios, the Sky-Sovereign** (Ouranos/Cosmos, god-rank) — the region's distant Act boss, throned in the highest storm.
- **Tachyrion, the Bronze That Outran Its Maker** (Ouranos, machine-god) — a self-ascended sky-construct superboss the Table "sponsors."
- Wild Ouranos lines: **Sandskip → Siroccoub → Khamsoon** (desert nomads, Ouranos/Chaos), **Glimmergrub → Lumenmoth → Constellute** (astral moth-spirits, Ouranos/Eros), **Veldtcolt → Heliodash → Sunmeridian Courser** (savanna runners, Ouranos/Cosmos), **Glimowlet → Teloscry → Aetheraugur, the Counted Sky** (observatory owls, Ouranos/Cosmos — the Table's "auditors").
- **Skyrend Wyverns** (Vol04 Ouranos flight-apex clade: Skyrender · Duskrender · Sunder-the-Gale) — the region's iconic legendary flyers.
- **Canonical adult line:** **Augur Bird** (Pipling → Augurwing) is a Storm Vault native — a sky-reading omen-fowl the Table prizes.

### Set-pieces
1. **The Marker-Vault** *(landmark / contract-dungeon).* The floating heart of the Table — a storm-wrapped island where every contract, marker, and debt in the world is physically *stored* as a charged sky-relic. **Hook:** Mercer Vane needs you to retrieve a specific marker before a rival faction does — but the Vault's lightning-wards read *intent*, and the only way through is to genuinely *not know* which side you'll sell it to (a delicious High Table puzzle). (Gate: clears High Table standing; unlocks the full bounty/competition circuit and a neutral-services hub.)
2. **The Falling Court** *(ritual-site / arena-island).* A drifting amphitheater where aspirants duel *at altitude* — lose your footing and you lose the match (and possibly the long way down). **Hook:** the Pythian has foreseen you'll fight a rival here; the odds are bad; the Table has already taken bets. A skybound duel with a fall-hazard twist on the standard battle. (Gate: a tournament bracket node; winning raises notoriety → tougher rivals, per the nemesis scaling.)

### Flavor encounters
- A storm-island drifts past with a perfectly intact tavern on it, patrons mid-drink, that detached from the mainland a century ago. They wave. They've made it work. They are not, technically, allowed to land.
- The High Table offers you a "completely neutral" tip about a rival. It is true, useful, and was *also* just sold to that rival, about you, for the same price. Balance.
- A bounty target you're hunting is *also* hunting a bounty on *you*, issued by the same broker, who is delighted by the symmetry and has named the matchup.
- You find a contract with your name on it that you don't remember signing. The terms are excellent. The signature is yours. The Pythian smiles and says, "Not *yet*." You decide not to ask.

### Biome ruleset hook (WFC)
- **Palette:** sky-archipelago tile-set — floating cloud-marble islands, thunderhead-canyons, lightning-bridges, drifting platforms, storm-wrapped vaults, the Falling Court's amphitheater. Bright, high, vertiginous — verticality is the theme; pair fall-edge tiles with a clear **shape/edge motif** (a hatched void-edge, never just a color shift).
- **Hazards:** *fall-edges* (the signature — off the island = a real failure-state, telegraphed by hatched void-tiles), *lightning-strike tiles* (rhythmic, telegraphed — a Celerity/timing check), *wind-shear* (forced-movement push toward edges).
- **Traversal locks:** the **Ouranos** force-climate is the great **Celerity** region (fast, evasive, flight-favoring gene-expression). Island-hopping needs a *flight-capable* or *gust-riding* creature as the core traversal-upgrade (the most metroidvania-flavored gate in the world — whole island-chains stay unreachable without sky-mobility). Castellan Mio's landing-clearances are standing-gated; the highest storm (Astrapios) is a rank-gated peak.

---

## 6. The Sunder — Chaos *(the Unbound · the Revel)*

**Force / god:** **Chaos** (Spike). Ruled by **Eris** with **Dionysus** (Chaos+Eros) bleeding in from the Verdant. Home of the **Unbound** (Chaos / any-purity): burn every throne, let no god rule again — the Unmaking path. The **Revel** (Chaos/Tainted) parties in the same wreckage. This is the **reality-warping zone** the Overworld doc calls "the Alice region."

### Lore & history
The Sunder is where the rules went to die and didn't. When Chaos pooled here — and Chaos is the one force that *spreads* rather than settles — it didn't make a landscape so much as *unmake* the idea of one. The Sunder is a region in the way a dream is a building: the layout shifts, scale stops meaning anything, force-advantage inverts without warning, and the local laws of physics are less *laws* than *strong suggestions* that the land enjoys ignoring. Maps don't work. Compasses point inward. Distance is negotiable. Standing in one place too long is how you end up somewhere else, smaller, on fire, and weirdly fine about it.

The **Unbound** are the only ones who *like* it here, because the Unbound believe the entire god-game — the thrones, the Succession, the whole ladder you're climbing — is the real prison, and the Sunder is the one place the prison's rules don't hold. Their creed is the bleakest and the freest: don't ascend, don't replace the gods, *end the gods* — climb only to kill the Primordials and stop the Succession forever (the true/secret **Unmaking** ending). They are not nihilists having fun; they are nihilists who have done the math and find it *load-bearing*. The **Revel**, meanwhile, treats the same lawlessness as the world's best party — ecstasy, indulgence, glorious mutation, consequences optional — and the two factions share the Sunder the way a philosopher and a hedonist share a sinking ship, arguing about whether to bail.

You come to the Sunder for what nowhere else will sell: taboo tech, abominations, opposed-force mutagens, the secret routes, and the catalysts the Revel uses to make a creature *more* than it was ever supposed to be. It is the highest-risk, highest-reward ground in the world. The Sunder gives generously. The Sunder takes the same way.

### Inhabitants
**Named NPCs (Unbound + Revel cast):**
- **The Unmaker** (true name forgotten, possibly never had one) — the Unbound's local prophet of ending. Voice: calm, lucid, terrifyingly reasonable, the sanest-sounding person in the world saying the most unthinkable thing. *"They were nobodies who climbed a ladder and pulled it up behind them. Don't climb it. *Burn* it. I'll hold the torch."*
- **Madame Vermillion** — the Revel's regional impresario, a glorious wreck who hosts the endless party and sells the mutagens. Voice: decadent, warm, utterly without brakes. Teaches the high-risk mutation/taboo-fusion Lab branch. *"Stronger? Darling, *stronger* is the boring part. I can make it *interesting*. Hold its hand and don't let go no matter what it becomes."*
- **Tick** — a small, cheerful, possibly-recurring NPC who is definitely lying about being one person. Hands out secret-route hints. Voice: too many at once, in chorus, pretending to be one.
- **The Cartographer** — a doomed soul mapping the Sunder, who is always exactly one map behind reality and knows it. Voice: exhausted, methodical, magnificent. Sells maps that were true once.

**Signature creatures (Chaos-primary):**
- **Vexenarch the Crowned Riot** (Chaos/Cosmos, god-rank) and **Bakchanyr, the Revel-Lord** (Chaos/Eros, god-rank) — the region's Act bosses; Bakchanyr is Dionysus's heir.
- **Pyriphlagos, the Reactor That Crowned Itself** (Chaos, machine-god) — a self-ascended Chaos superboss.
- Wild Chaos lines: **Cindernewt → Slagscrawl → Vulcanrede** (volcanic salamandrids, Chaos/Cosmos), **Tumblebaby → Riotmummer → Bigtopper the Final Act** (occult carnival beasts, Chaos/Eros), **Cogburr → Gearbramble → Mainspring Pall** (clockwork-grove sprites, Chaos/Cosmos), **Glimmerowlet → Cometstrix → Stargazer Owl** (observatory owls, Chaos/Ouranos).
- **Taboo abominations (the Sunder's exclusive horror-trade):** the **Forbidden Choir** (Vol06 eldritch cluster), chimera-splices (Glasswolf Riotsplice, Mirrorhound Riotweave), entropy-mutants (Galemar Driftmutant, Riftgrowth Slagmutant) — the Unbound/Revel's signature, world-condemned creations.
- **Riotgrief Brood** (Vol10 Chaos/Thanatos demon nukers) — Legendary apex flyers that haunt the warps.

### Set-pieces
1. **The Throne That Won't Sit Still** *(reality-warp dungeon).* The Unbound keep a captured *throne* — pried from some lesser dead god — in the Sunder's deepest warp, as a trophy and a lesson. It will not stay in one shape, place, or size; the dungeon around it re-tiles, inverts force-advantage, and lies about its own layout. **Hook:** the Unmaker invites you to *destroy* the throne (a ritual of refusal — practice for the Primordials), but the throne *wants* an heir and keeps offering itself to you instead. The Sunder's central temptation: ascend, or unmake. (Gate: completing the unmaking ritual opens the Unbound path toward the true ending; *accepting* the throne instead is a dark grid-lurch. Either way unlocks taboo-tech access.)
2. **The Long Party** *(ritual-site / festival-maze).* The Revel's eternal celebration, a shifting carnival-maze where the music never stops and neither does the mutation. **Hook:** Madame Vermillion offers your creature a "blessing" at the party's heart — a guaranteed powerful mutation with a *randomized* taboo cost (the high-roll Lab gamble made flesh). Getting to the heart means navigating a maze that rewards *not* thinking too hard. (Gate: the Revel mutation-catalyst reward + a taboo-fusion recipe; the maze's exit shifts on the force-tide.)

### Flavor encounters
- You walk north for an hour and arrive *behind* yourself, an hour ago, walking north. You both pretend not to notice. It would be rude. One of you is, statistically, the real one.
- A creature here is its own grandparent through a breeding accident the Revel finds hysterical and the Stoneblooded would call a war crime. It seems content. The genealogy is a crime scene.
- The Cartographer hands you a map. It is accurate for exactly as long as you look at it. The moment you trust it, it becomes a lovely drawing of a different place. He apologizes. He's used to it.
- A door in the middle of an empty field. It's locked. There is no wall, no building — just a door, locked, in a field. Walking around it works. Knocking does *something*. Nobody who knocked has said what.

### Biome ruleset hook (WFC)
- **Palette:** anti-coherent tile-set — impossible geometry, floating staircases, inverted horizons, scale-broken props (a giant chair, a tiny mountain), carnival-warp tiles, the shifting throne-room. The one region where the WFC should *intentionally break its own adjacency rules* on a controlled budget — non-Euclidean stitches, mismatched seams, deliberate "wrongness." Hazard reads must still pass **shape/icon** legibility even amid the chaos (the warp is disorienting *by design*, not unfair).
- **Hazards:** *inverted force-advantage tiles* (your strong-vs-weak matchup flips — a strategic hazard, telegraphed by a glyph), *shifting layout* (re-tiling maze-walls), *scale-distortion zones* (size/reach warps that change battle range), *nonsense-logic locks* (puzzle-gates that punish literal thinking).
- **Traversal locks:** the **Chaos** force-climate is the great **Spike** region (volatile, high-variance gene-expression — the place to make a glass-cannon or a taboo). Secret routes open via *grid-alignment* (the Sunder favors the Chaos-aligned), exploration, and "wrong" solutions. This is canon's designated **anything-can-happen pressure valve** — the WFC's stress-test region. Highest-tier and taboo spawns lurk in the deepest warps.

---

## 7. Titanfall — Gaia *(the Stoneblooded clans)*

**Force / god:** **Gaia** (Bulk). Ruled by a **dead Titan** whose corpse *is* the region (Tartaron the Buried Titan / Krathonar the Quaking Titan in the deep strata). Home of the **Stoneblooded** (Balanced/Pure): the old clans — endurance, tradition, the husbandry way; they breed, tame, and bond, and they remember everything.

### Lore & history
Titanfall is a graveyard with a heartbeat. When the Titans fell — and they fell *first*, before the Olympians, in a war the world has mostly forgotten — their bodies became the mountains, and at least one of them isn't entirely dead. The region is a range of corpse-peaks: ribs the size of valleys, a buried skull that forms a whole plateau, strata of fossilized Titan-flesh that the Stoneblooded call **the Old Weight**. Gaia here is *mass and memory* — the slow, patient, unkillable solidity of the ground itself, the force that endures by simply refusing to be moved. Things here are old, heavy, and slow to anger, and when they anger, the ground does it with them.

The **Stoneblooded** are the oldest human culture in the world — clans who lived on the Titan-corpses before there was a Pantheon to fall, who practice husbandry as a sacred art, and who regard the flashy god-game with the patience of people who've watched empires erode. Their creed is *endurance*: don't ascend in a blaze, don't burn the world, *outlast* it. They breed the strongest bonds and the sturdiest creatures, they keep the deepest taming lore, and they are "Pure/Balanced" because their way is slow, honest, and rooted — they would no more splice a creature against its nature than salt their own fields. They distrust the Revel (who mutate what should be bred) above all others. Earning a Stoneblood's respect takes the longest of any faction and means the most.

You come to Titanfall for the husbandry deep-magic: breeding lore, taming techniques, bond-gear, and the Gaia creatures that anchor a team that *cannot be moved*. The clans don't sell so much as *adopt* — prove yourself patient, and they'll teach you things the other factions don't believe are real.

### Inhabitants
**Named NPCs (Stoneblooded cast):**
- **Matriarch Brole** — eldest of the regional clans, who has bred more legendary lines than the Iron Guild has built and considers the Guild adorable. Voice: granite-slow, dry, infinitely patient, the warmth of stone in the sun. *"You want it fast. Everyone wants it fast. The mountain wanted it fast too, once. Now it's a mountain. Sit down."*
- **Durn Oxback** — clan beast-master and breeding-show champion, who teaches the advanced bond/breeding Lab branch. Voice: gruff, fond, speaks to creatures more easily than to people.
- **Little Stone** — a clan child prodigy who already out-tames adults and isn't smug about it, which is somehow worse. A future rival-or-ally. Voice: quiet, observant, alarmingly good.
- **The Listener** — a Stoneblood hermit who claims to hear the buried Titan dreaming and is, disturbingly, sometimes right. Voice: hushed, seismic, speaks in the first-person-plural of the mountain. Quest-giver for the deep-strata.

**Signature creatures (Gaia-primary):**
- **Oreithys the Standing Weight** (Gaia/Ouranos) and **Mordathun the Cairn-King** (Gaia/Thanatos) — god-rank Act bosses rooted in the strata; the buried **Tartaron** / **Krathonar** Titans are the deep superbosses.
- Wild Gaia lines: **Grublump → Tunnelward → Stratovault** (subterranean delvers, Gaia/Cosmos), **Fleeceknoll → Hoarwool → Tundramound** (tundra woolbeasts, Gaia/Eros), **Saplingstout → Boughwarden → Orchardverdict** (orchard wardens, Gaia/Eros), **Cairnkit → Stonevixen → Orrery-Warden** (stargazer foxes, Gaia/Cosmos).
- **Loamhide Drove** (Vol09 Gaia/Chaos earthy tank-beasts) — the clans' iconic heavy-bruiser herd.
- **Canonical adult lines:** **World Tortoise** (Sproutling → Spiked-shell → Worldback — the ur-Gaia gentle colossus) and **Rime Bear** (Rimewarden) are Titanfall natives, the pride of the breeding-shows.

### Set-pieces
1. **The Cairn of the First Beast** *(ritual-site / breeding-ground).* The clans' holiest ground — a vast cairn-circle on the Titan's buried sternum where the Stoneblooded have bred their sacred lines for a thousand generations. **Hook:** Matriarch Bole offers you the rite of the **Old Pairing** — access to a Stoneblood legendary breeding-line — but only if you first prove a *bond* (not a cage) by walking the Cairn with an untamed deep-strata beast at your side and bringing it back willing. (Gate: unlocks the advanced breeding Lab branch + a Gaia legendary lineage; the entry into the Stoneblooded breeding-show competition circuit.)
2. **The Dreaming Strata** *(dungeon / descent).* A descent into the living Titan-corpse, where the deeper you go the more the "rock" is unmistakably *flesh*, slow-pulsing, dreaming. **Hook:** the Listener needs you to descend to where the Titan dreams and either *soothe* it (it's stirring, and a waking Titan ends the region) or *harvest* a fragment of its still-living Gaia for a unique god-organ. The mountain has an opinion about which. (Gate: a Titan-flesh god-organ / a deep Gaia legendary; soothing vs. harvesting branches the Pure/Balanced grid and gates whether the Titan superboss ever wakes.)

### Flavor encounters
- A Stoneblood greets you, asks your business, and listens to your entire grand ambition in total silence. When you finish, they say, "Mm," and go back to grooming a Worldback. You have been, you realize, *assessed*.
- A breeding-show is underway. The grand champion is a tortoise so old and so vast it has lichen, a name, three generations of devoted handlers, and a slow, ancient dignity that makes your entire god-quest feel a little loud.
- A clan elder shows you a cave painting their ancestors made of the Titan *falling*. It is the oldest art in the world. There is a second, smaller figure in it, watching the fall, that the clan won't discuss and that looks, unsettlingly, like you.
- You offer to *buy* a creature. The silence that follows is geological. Eventually someone explains, very gently, as to a child, that the Stoneblooded do not sell family. You apologize. You apologize again. It takes a while to come back from this.

### Biome ruleset hook (WFC)
- **Palette:** corpse-mountain tile-set — rib-ridges, the skull-plateau, fossil-flesh strata, cairn-circles, deep caverns that grade from stone to *meat*, clan-holds carved into Titan-bone. Massive, weighty, vertical-but-grounded — the visual opposite of the Storm Vault's airy drift. Deep-strata "flesh" tiles get a distinct **organic-pulse shape-motif** to read against the upper "stone" tiles.
- **Hazards:** *quake-tiles* (the buried Titan stirs on a cycle — rockfall/tremor, telegraphed), *deep-strata pressure* (a slow Bulk-check the further you descend), *unstable cairns* (crumble-traversal). Nothing fast — Titanfall punishes the *impatient*, not the slow.
- **Traversal locks:** the **Gaia** force-climate is the great **Bulk** region (tanky, high-HP, endurance gene-expression — where you raise a wall). Deep descents need a *heavy/sturdy* traversal-upgrade (a creature that can shoulder through rubble or weather the pressure). The Cairn is **Stoneblooded-standing-gated** (they don't let strangers near the sacred lines). The Titan's dreaming heart is a rank + standing-gated deep secret.

---

## 8. The Tideless — Ouranos+Gaia *(the Deep Choir)*

**Force / god:** **Ouranos+Gaia** (Celerity + Bulk). Ruled by **Poseidon** (Ouranos+Gaia, sea & quakes). Home of the **Deep Choir** (Balanced/Corrupt): the drowned remember; eldritch communion with what sleeps below. They keep the leviathan creatures and the deep secrets, and they hear things in the dark that they really shouldn't repeat — and do.

### Lore & history
The Tideless is a sea that stopped. When Poseidon fell, the waters he ruled didn't drain or freeze — they *settled*, into a vast still drowned country where the tide forgot to come in and never left again. It is a sunken realm of flooded ruins, kelp-cathedrals, and leviathan-haunted trenches under a surface as flat and grey as slate, where the silence is so total that sound *carries forever* and the things in the deep have had eons to learn your language from the drowned who spoke it. Ouranos and Gaia braid here strangely — the *weightless drift* of deep water (Ouranos) over the *crushing mass* of the abyssal floor (Gaia) — a region that is at once the most buoyant and the most pressuring in the world.

The **Deep Choir** are the drowned faithful — communities that went under when the sea died and *kept going*, changed by the pressure and the patient eldritch company below into something that is no longer quite a human congregation. They practice *communion*: listening to the leviathans, the dead, and the deeper-than-dead, and bringing back what they hear. They are "Balanced/Corrupt" not because they're malevolent but because what they commune *with* leaves marks — they've traded pieces of themselves for the deep's secrets, and they'll cheerfully trade pieces of you. Their hymns are beautiful and structurally unsound for the listening mind. They are the eldritch heart of the world's grimness — and, because the funny-grim never fully lifts, they have *excellent* a cappella and a dark sense of humor about drowning.

You come to the Tideless for the abyssal trade: leviathan creatures, Ouranos/Thanatos deep-kit beasts, the secrets the surface forgot, and communion-rites that grant power at a creeping cost. The Choir welcomes you warmly into water you should not enter. They've been hoping you'd visit. They've heard *so* much about you, from below.

### Inhabitants
**Named NPCs (Deep Choir cast):**
- **The Drowned Cantor** — the Choir's regional voice, a serene half-changed priest who speaks for the deep and increasingly *as* it. Voice: tidal, layered, kind in a way that doesn't reach the eyes (which have changed). *"We don't drown the faithful, friend. We *deepen* them. You're already holding your breath, aren't you? You have been for years."*
- **Mother Brine** — keeper of the leviathan-pens, who raised abyssal horrors from eggs and loves them like an over-fond aunt. Teaches the deep-communion / leviathan-bond branch. Voice: bubbling, maternal, salt-cured. *"He's just big-boned. And big-toothed. And he's eaten three handlers, but only when they were sad — he can't *stand* to see them sad."*
- **Fathom** — a Choir child who hasn't fully changed yet and still remembers the surface, and grieves it, and won't say so. Your most human contact here, and the most heartbreaking. Voice: small, deep, fading.
- **The Listener-in-the-Reeds** — a defector *from* the Choir, hiding in the shallows, who can tell you what the deep *actually* wants and is slowly being un-hidden. Voice: frantic, dripping, running out of shore.

**Signature creatures (Ouranos+Gaia + the deep's Thanatos):**
- **Sphairon the Vault-Keeper** (Cosmos/Ouranos) and the drowned **Aellophon the First Gust** (Ouranos/Gaia) — god-rank echoes; **Poseidon's** own sunken throne hides the region's Act boss.
- Wild Ouranos/Gaia + abyssal lines: **Brinenip → Crustgale → Saltskitter** (saltflat scuttlers, Ouranos/Gaia), **Floereel Pup → Skerryslip → Maelpinniped** (fjord seals, Ouranos/Gaia), **Lumphook → Trawljaw → Sounderking** (abyssal anglers, Gaia/Ouranos), **Polypip → Reefdirge → Brineherald** (coral reef-folk, Ouranos/Thanatos — the Choir's literal choir).
- Deep-Thanatos communion-creatures: **Lurewick → Fathommend → Abysswet Matron** (abyssal anglers, Eros/Thanatos), **Polypwretch → Bleachcoil → Necrocoral** (coral reef-folk, Thanatos/Eros).
- **Canonical adult line:** **Tide Serpent** (Tidecoil) is the Tideless's iconic leviathan — Mother Brine's pride.
- **Leviathan superbosses:** the deepest trenches hold a Succession echo — **The Sexton-King of the Deep Loam** drifts the abyssal floor.

### Set-pieces
1. **The Kelp-Cathedral** *(dungeon / drowned-temple).* A sunken cathedral of giant kelp where the Choir holds communion, its drowned nave lit by lure-light and ringing with hymns that carry too far. **Hook:** the Drowned Cantor invites you to *attend* a communion — to descend the nave and listen to what the deep says — but every level down, the hymn rewrites a little more of what you came in believing, and the Listener-in-the-Reeds is screaming at you from the entrance not to reach the altar. (Gate: completing the communion unlocks the Deep Choir leviathan-bond branch + a deep secret; the rite itself is a creeping-corruption mechanic — grid-lurch toward Corrupt with each level, power with each level, a deliberate temptation curve.)
2. **The Pressure-Trench** *(landmark / deep-descent).* A vertical abyssal trench down to the crushing floor where the oldest leviathans sleep and the Old Weight of the dead sea-Titan grinds. **Hook:** Mother Brine needs an egg from the deepest pen, in the trench, where the pressure alone kills the unprepared and the *mother* of the egg is very much present and very much aware. (Gate: a leviathan legendary egg/recruit; the trench is a pressure-gated descent — the Tideless's signature traversal-lock.)

### Flavor encounters
- The Choir invites you to dinner. It's lovely. The food is local. Everyone is so glad you came. Nobody is eating. Everyone is watching you eat. Fathom mouths *don't* from across the table and then smiles, too late, because the Cantor turned.
- A leviathan surfaces, regards you with an eye the size of a door, and *sings* one low note that you feel in your teeth and your grief and a memory you didn't know you had. Then it submerges. You are crying. You don't know why. Mother Brine pats your shoulder. "He likes you."
- You find a message in a bottle, washed up. It's from the Choir. It's addressed to you, by name, dated three years from now, and it says only: *"You'll understand the hymn soon. We saved you a seat. — Below."*
- A perfectly preserved drowned village, mid-daily-life, mannequin-still. A sign says *Threshold's sister-city, lost to the settling.* You realize this is what the deep does. You realize the Choir thinks it's an *improvement*. You leave. Quickly. The hymn follows you up the beach a little way, then stops, patient, willing to wait.

### Biome ruleset hook (WFC)
- **Palette:** drowned tile-set — flooded ruins, kelp-cathedral spires, lure-lit nave, abyssal trench-walls, the flat slate "surface," coral-choir reefs, leviathan-bone landmarks. Buoyant-yet-heavy, dim, blue-black with bioluminescent lure-accents — pair the lure-light "safe vs. lure-trap" reads with **shape/glyph** (a hymn-note glyph for communion tiles, an eye-glyph for leviathan-attention zones), never lure-color alone.
- **Hazards:** *pressure-depth* (a Bulk/Ward check that worsens with descent — the signature gate), *hymn-zones* (a creeping-corruption/morale hazard near communion sites, not flat HP damage), *leviathan-attention tiles* (lingering aggro-zones), *lure-traps* (false-safe bioluminescent tiles).
- **Traversal locks:** the **Ouranos+Gaia** force-climate is the great **Celerity/Bulk** hybrid (buoyant-but-sturdy gene-expression — the deep-diver's region). Descent needs a *pressure-rated* traversal-upgrade (a creature that can withstand the deep) — the Tideless's defining metroidvania gate, sealing the trench's leviathans and secrets behind it. Communion-deeps are Deep Choir standing-gated; the sunken throne (Poseidon's Act boss) is rank + standing-gated.

---

## 9. The Astral Tier — Cosmos *(the Concord)*

**Force / god:** **Cosmos** (Ward). Ruled by **Athena** (Cosmos+Ouranos, ordered war & wisdom) and **Apollo** (Ouranos+Eros, light & healing). Home of the **Concord** (Order/Pure): refill the empty thrones *lawfully* — gods as a cosmic civil service. They keep the Ward and Seal arts, the Cosmos creatures, and the order-gear, and they believe, sincerely, that the apocalypse is a paperwork problem.

### Lore & history
The Astral Tier is the one region the gods' death made *more* orderly, not less. When the law-gods fell, their domain didn't collapse — it *crystallized*, into a vast ordered citadel of crystal and light suspended above the wreck of everything, a place of perfect geometry, recorded names, and rules that still, somehow, *hold*. Cosmos here is pure **structure** — the binding force, the seal, the law that says *this far and no further*, the ward that holds the world's edges from fraying into the Sunder. It is the most beautiful region in the world and the most airless, a heaven run as a bureaucracy, where the light is gentle, the lines are straight, and nothing is ever, ever allowed to be *wild*.

The **Concord** are the would-be restorers of order — a coalition of jurists, sealers, and lawful aspirants who look at the graveyard of gods and see not tragedy but a *vacancy*. Their creed is restoration-by-procedure: the thrones must be refilled, but *lawfully* — gods vetted, bound by covenant, installed as a cosmic civil service answerable to the Concord's law. They are "Order/Pure" and they are *not* villains; they are the genuine, decent, terrifying belief that the world would be safe if only everyone would *comply*. They are the Unbound's mirror and great enemy: the Unbound would burn every throne, the Concord would fill every one and file the deed. To the Bloomwardens they're cold; to the Revel, the police; to *you*, depending on your grid, either the lawful path to a Lawgiver's throne or the wall between you and a freer ending.

You come to the Astral Tier for the Ward arts: sealing and binding skills, the Cosmos creatures that anchor a defensive team, order-gear, and the only *lawful* route up the divine ladder. The Concord will sponsor you — gladly, conditionally, with a contract longer than your life and a clause for every way you might disappoint them.

### Inhabitants
**Named NPCs (Concord cast):**
- **Magistra Caelis** — the Concord's regional high-jurist, who administers the law of the thrones and has read every covenant ever sworn. Voice: luminous, exact, compassionate in principle and merciless in practice. *"We are not unkind. We are *consistent*. You'll find the difference matters less than you'd hope and more than you'd like."*
- **Sealwright Orin** — keeper of the binding-arts, who teaches the Ward/Seal skill branch. Voice: meticulous, devout, treats a perfect seal as a prayer. *"A wild thing is just an unsigned contract. Hold still. This won't hurt. That's the entire point of doing it correctly."*
- **The Assessor** — a Concord examiner who *grades* your worthiness for sponsorship against the law, endlessly, on a rubric. Voice: fair, exhausting, the embodiment of conditional approval.
- **Brother Recant** — a Concord jurist quietly losing his faith in the law he enforces, who can show you the cracks in the crystal. Voice: precise, fraying at the edges, a whistleblower in waiting. A recruitable conscience.

**Signature creatures (Cosmos-primary):**
- **Astrapios** (Ouranos/Cosmos), **Halcyone the Mending Order** (Cosmos/Eros), and **Geometheus the Squared Circle** (Cosmos/Chaos) — god-rank Act bosses of the law-courts.
- **Aegistheon, the Wall That Numbered Itself God** (Cosmos, machine-god) — the Concord's "lawful" pet superboss, a wall that achieved divinity by *rule*.
- Wild Cosmos lines: **Glimmermole → Tunnelwright → Deepwarden Sentinel** (Cosmos/Gaia), **Gustfledge → Squallward → Thunderhead Aegishawk** (Cosmos/Ouranos), **Geodepip → Prismflit → Cathedral-of-Wings** (Cosmos/Ouranos), **Sigilnipper → Wardpincer → Lattice-Bailiff** (saltmarsh crabs, Cosmos/Chaos — the citadel's literal bailiffs).
- **Sigilframe → Wardloom Engine → Sanctwall Colossus** (Cosmos/Gaia foundry-class) — lawful constructs the Concord licenses.
- **Radiant clade (Vol07):** **Reliquary Shell**, **Seraphwing**, **Oriole Choir** — the citadel's sanctioned, luminous Cosmos/Eros creatures.
- **Dead-God echo:** **The Lawgiver, Twice-Crowned** (Succession) — the secret-boss ghost of a *previous* ascendant who took exactly the throne the Concord offers you, and what it cost.

### Set-pieces
1. **The Hall of Empty Thrones** *(landmark / law-dungeon).* The Concord's heart — a crystal hall of vacant god-seats, each one labeled, vetted, and *waiting* for a lawful occupant. **Hook:** Magistra Caelis offers you sponsorship toward one of the empty thrones (the lawful Lawgiver path), but the trial is a *covenant-dungeon*: you must pass the Concord's binding-trials — seal-puzzles, lawful-combat ordeals — to prove you'll wear a crown *correctly*. The dead-god **Lawgiver, Twice-Crowned** waits at the end, the ghost of the last person who passed. (Gate: sponsorship toward the Order/Pure ascension ending; unlocks the Ward/Seal high-tier skill branch + a Cosmos legendary.)
2. **The Crystal Archive** *(ritual-site / vault).* A library-vault where every *name* and *covenant* in the world is bound in crystal — the Concord's claim that to be recorded is to be controlled. **Hook:** Brother Recant smuggles you in to find a *redacted* covenant — proof the Concord once bound a god *unlawfully* and erased it — a secret that could break their authority. The Archive's seal-wards fight you the whole way. (Gate: a lore-bomb that opens an anti-Concord questline + a unique seal-breaking tool; reading it lurches grid away from Order.)

### Flavor encounters
- A Concord clerk asks you to fill out a form to *request a form*. The second form, once granted, requests your worthiness to request the first. You are, an hour later, three forms deep into the prerequisite for asking a single question. The clerk is so helpful. You will never escape.
- A perfectly ordered garden where every flower is the regulation height, color, and spacing. One flower has grown crooked. A Sealwright is, with enormous gentleness and sincere regret, correcting it. It will take all day. He has all the days there are.
- You meet a god-aspirant who passed the Concord's trials, took a lawful throne, and is now bound so thoroughly by covenant that they can't remember what they wanted the throne *for*. They smile at you. They recommend it. The smile doesn't move.
- The citadel's light never changes — no day, no night, no weather, no surprise. A Concord jurist mentions, with real pride, that nothing unexpected has happened here in four hundred years. You believe them. It's the most frightening thing anyone's told you all game.

### Biome ruleset hook (WFC)
- **Palette:** ordered-crystal tile-set — geometric crystal halls, light-bridges, seal-glyph floors, the throne-hall, archive-vaults, regulation gardens, prismatic spires. Bright, symmetrical, *perfect* — the most rigidly grid-aligned WFC region of all (Cosmos = literal structure), the visual antithesis of the Sunder's chaos. Seal/ward tiles read via **glyph-shape** (a binding-sigil for seal-gates), never color-coded alone.
- **Hazards:** *seal-gates* (puzzle-locks requiring the Ward/binding arts to pass — order-as-obstacle), *law-tiles* (zones enforcing a battle rule, e.g. suppressing Chaos/Spike kits — the inverse of the Sunder's anything-goes), *ward-barriers* (hard structural blocks that only a seal-key or seal-breaker opens).
- **Traversal locks:** the **Cosmos** force-climate is the great **Ward** region (defensive, sealing, high-resist gene-expression — where you raise an unbreakable wall). Most of the citadel is *seal-gated* — progress needs binding-arts proficiency or Concord standing (lawful access) or, for the renegade route, Recant's seal-breaker. The Hall of Empty Thrones is the rank + standing-gated endgame-lawful peak. This region's locks are thematically the *opposite* of metroidvania-by-power: here you progress by *compliance*, and the renegade who breaks seals instead is making a grid statement every time.

---

## 10. The Maw Beneath — Deep Corruption *(NEW · the Devourer · the Unbound's deepest reach)*

> **Why this region is in-canon (rationale).** The morality grid's most extreme cell — **Chaos/Corrupt → The Devourer (Abyss)** — and the Story doc's **Unmaking** ending both point *downward*, toward a corruption pole that the eight canonical surface-regions only *gesture* at (the Tideless hints at it, the Sunder borders it, the Mournmarch sits on its lip). Corruption in this world isn't a place yet — it's a stat-axis with no soil. **The Maw Beneath gives the Purity⇄Corruption axis a *floor*** the way Titanfall gives Gaia mass: a deep-corruption / abyssal under-region where spent, spilled force doesn't rest (Mournmarch) or settle (Tideless) but *rots into appetite*. It anchors the Devourer ascension, deepens the Unbound's Unmaking spine into literal descent, and supplies the corruption-pole biome the WFC roster otherwise lacks. It contradicts nothing: it sits *below* the Mournmarch (Thanatos is endings; the Maw is what endings *become* when they curdle), and it is gated as a late, dangerous descent — not a starter zone.

**Force / god:** **Corruption itself** — no single pure force, but the *rot* of all six, with **Chaos** (Spike) and **Thanatos** (Bane) dominant in the blend. No living god rules it. Its would-be sovereign is the ascension-form **The Devourer (Abyss)**; the **Unbound** treat its bottom as the trailhead to the Primordials and the Unmaking.

### Lore & history
Everything falls. That is the Maw's only law, and it is patient about it. When the gods died and their force soaked the land, not all of it stayed where it spilled — force is heavy when it's spent, and spent force *sinks*, down through the Mournmarch's barrows, past the Tideless's deepest trench, into a place below all places where the leavings of a dead cosmos collect and curdle. The Maw Beneath is that sump: not an underworld of the *dead* (the Mournmarch keeps those, neatly filed) but an under-*everything* of the *rotting* — where the six forces, separated from any creature, god, or purpose to hold their shape, break down into a single hungry sludge that the Unbound call **the Rot** and the Pale Court refuses to call anything at all.

It is alive the way a wound is alive. The Rot doesn't *want* in the way a beast wants; it *appetites*, mindlessly, comprehensively, dissolving order, name, and shape back into undifferentiated force and absorbing whatever it touches. Creatures down here aren't born so much as *accreted* — they are the Rot briefly remembering how to be a thing, wearing the half-digested forms of whatever fell in last. Some of them are recognizable. Some of them are recognizable as *people*. The deeper you go, the less anything keeps its edges, until at the very bottom there is rumored to be a place where the Rot has eaten so much that it has, horribly, begun to *think* — and what it thinks about is the rest of the world, and how it, too, eventually falls.

The Maw is the world's open secret and its true floor. The Concord seals the ways down (it is the one thing every lawful instinct screams to contain). The Bloomwardens won't speak of it (life that becomes *this* is the one thing their creed can't love). And the **Unbound** descend it on purpose, because the Unmaking ends here: the only road to killing the Primordials and stopping the Succession forever runs *down*, through the Rot, to the bottom of everything, where the cycle itself can be unmade. The Maw is where the game's bleakest ending begins — and even here, the funny-grim holds: the Rot is *darkly funny* in its total indifference, and the doomed people who live on its ledges have the gallows wit of those with absolutely nothing left to lose.

### Inhabitants
**Named NPCs (the descent's cast):**
- **The Hollow Choirmaster** — the Unbound's deepest-delved prophet, a near-dissolved figure who has gone down further than anyone and come back wrong and *useful*. Voice: thin, echoing, missing words where the Rot ate them, terribly serene. *"It doesn't hate you. That's the worst part. It would eat a god and a child with the same... the same... it doesn't even have the word. Neither do I, now. Come down. I'll show you where the word used to be."*
- **Gristle** — a scavenger who lives on the upper ledges, harvesting half-digested force-relics from the Rot's leavings and selling them to anyone mad enough to buy. Voice: cackling, filthy, the cheeriest person in the abyss because the bar is in hell. Sells corruption-mutagens and abyssal salvage. *"Found a god's *finger* down there last week. Still twitching. Sold it to a Pale Court boy. He cried. Lovely transaction. Want a thumb?"*
- **The Accreted Woman** — a creature wearing the half-remembered shape of someone who fell in, who *almost* remembers being a person and asks you, every time, if you knew her. Voice: fractured, grieving, repeating. The Maw's emotional gut-punch; possibly a *specific* dead NPC the player met above.
- **Warden Last** — a lone Concord seal-keeper stationed at the topmost gate, who has guarded the way down for so long he's forgotten what surface life he's protecting and stays purely out of duty. Voice: cracked, dutiful, the last law at the edge of the lawless. A tragic gatekeeper.

**Signature creatures (the corruption pole):**
- **The Devourer's heralds:** the deepest **entropy-mutants** — **Galemar Driftmutant**, **Riftgrowth Slagmutant**, **Hollowdrift Endmutant**, **Hollowknell Endform** (Chaos/Thanatos abominations) — the Rot's most fully-realized accretions, Legendary-tier abyssal bosses.
- **Soul-amalgams** (the Maw's signature horror — many creatures dissolved into one): **Manyface Sigilswarm**, **Verdant Gravechoir**, **Sapchoir Knellheap** — the Rot wearing several faces at once.
- **Flesh-lattice** abominations: **Thanagloam Soulmesh**, **Knellmesh Soulreaper** — Rot-stitched horrors that read as the corruption-pole's apex predators.
- **Reanimant + taboo-fusion strays** that *fell* from the Mournmarch above and kept rotting: Cinderlich Boneheap, Honeyrot Bridegloam — the bridge-fauna between the death-region and the corruption-region.
- **The Devourer (Abyss)** itself — the Chaos/Corrupt ascension-god — is the region's *true* superboss and endgame stake: the throne you could take here, if becoming the world's hunger is a price you'll pay. Its Succession-echo, the dead-god **The Grudgekeeper of the Burnt Court**, haunts the mid-depths.

### Set-pieces
1. **The Sump of Spent Gods** *(deep dungeon / corruption-descent).* The Maw's central shaft — a downward spiral of ledges where the Rot pools deepest and the half-digested relics of fallen divinity surface and sink. **Hook:** Gristle will guide you down to harvest a **god-relic** (a unique corruption-tier god-organ, more potent and more poisonous than anything above), but every level down, the Rot *learns* a little of your party — copying your creatures' forms, wearing your dead, and the only way out is *before* it finishes learning *you*. (Gate: a corruption-tier god-organ + abyssal-mutagen access; the descent is a creeping-corruption mechanic — grid plunges toward Corrupt per level, power spikes per level, the steepest temptation curve in the game.)
2. **The Mouth at the Bottom** *(ritual-site / endgame-secret).* The rumored floor of everything, where the Rot has eaten enough to *think* — the trailhead of the **Unmaking**. **Hook:** the Hollow Choirmaster brings you to the very bottom, where you can begin the ritual to descend *past* the world toward the Primordials and end the Succession — or where you can let the Devourer's throne, rising from the Rot like a thing surfacing for air, take *you* as the world's new and final hunger. The single bleakest choice in the game, set at its literal lowest point. (Gate: opens the **Unmaking** true-ending path *or* the **Devourer** ascension; either requires the deepest descent and the highest rank — a true-floor endgame lock.)

### Flavor encounters
- The Rot, indifferent, slowly dissolves a discarded crown someone threw down here in disgust centuries ago. It does not know it's a crown. It would eat a crown and a turnip identically. There is something almost restful about being so completely unspecial to something so vast.
- A creature here wears your starter's face — perfectly, lovingly, *wrong* — and pads toward you, delighted, expecting to be fed. You know exactly where it learned the face. You did not bring your starter down here. (You check. You're sure. You check again.)
- Gristle offers you a "two-for-one" on god-fingers. There is no reason a god has this many fingers. You don't ask. Gristle would tell you, and you'd have to *know*.
- You find a Concord seal — one of Warden Last's — *holding*, perfectly, against an entire ocean of Rot, a single straight line of order in the unmaking dark. It is the most futile and the most magnificent thing in the world. The Rot will win. The seal does not care. Neither, you realize, watching it, does Warden Last. You leave him a drink. He won't drink it. He nods.

### Biome ruleset hook (WFC)
- **Palette:** corruption-sump tile-set — descending ledge-spirals, Rot-pools (viscous, faintly luminous with digested force-color), half-dissolved relics jutting from sludge, accretion-spires (the Rot remembering shape), the Mouth's thinking-dark at the bottom. Deliberately *de-cohering* downward — upper ledges still legible, deep tiles smearing toward formlessness (the inverse of the Astral Tier's perfect order). Hazard reads via **shape/glyph** even as form breaks down (a dissolve-glyph for Rot-tiles, a face-glyph for accretion-mimic zones) — corruption is *unsettling*, never unreadably unfair.
- **Hazards:** *Rot-pools* (a corrupting Bane/dissolve tile — lingering damages *and* nudges a creature's purity toward Corrupt, the only hazard that touches the morality stat), *accretion-mimics* (tiles where the Rot wears your party's forms — false-ally ambushes), *formless-deeps* (deep zones where range/scale/edges destabilize, like a grimmer Sunder), *the learning* (a depth-scaled escalation: the longer you linger at a depth, the deadlier its mimics of *you* become).
- **Traversal locks:** **no single force-climate** — the Maw is the *corruption* climate, biasing gene-expression toward the impure/taboo and the Chaos/Thanatos blend (the place to make, or become, an abomination). The descent is hard-gated: the topmost gate is **Concord-sealed** (Warden Last opens it only to the lawless-enough or the lawful-with-cause), and going deeper needs **Rot-resistance** traversal-upgrades (a creature or gear that resists dissolving) — without it, depth itself is the wall. The Mouth at the Bottom is the deepest rank + path-gated lock in the game (the Unmaking / Devourer endgame). This is the **late-game corruption counterpart** to Threshold's gentle start: the world's true floor, sealed for good reason.

---

## 11. The Hollow Atelier — the Lab's Own Domain *(NEW · the God-Maker · The Architect's workshop)*

> **Why this region is in-canon (rationale).** Every region so far is a *dead god's* leavings — but the Apotheosis/Succession spine has one ending the geography never houses: the **God-Maker**, the player who *refuses* a throne and instead becomes the one who *forges* gods for others to climb. And the morality grid's **Order/Tainted → The Architect** cell — the build-don't-be-born creed the Iron Guild only *preaches* — has no soil of its own (Forgefell is a dead *organic* god's foundry, inherited, not authored). **The Hollow Atelier gives the player's own craft a *place*.** Canon already establishes that the Lab reshapes creatures, that Apotheosis *reshapes regions*, and that environmental gene-expression writes a region's force into what you raise there — so a region the player's *accumulated work* writes into existence is the logical terminus of those rules, not a contradiction of them. It is the only region partly **authored by the player**: a half-finished demiplane the Lab accretes geography from, growing as you build, a workshop that is becoming a world. It contradicts nothing — it is unlocked *late* (you can't author a realm as a nobody), it is *yours* rather than any faction's, and it sits "nowhere" the way the God-Maker stands *outside* the nine thrones. Where the Maw Beneath is the world's floor (what happens when force *rots*), the Hollow Atelier is its drafting table (what happens when force is *made to mean something on purpose*).

**Force / god:** **all six and none** — the Atelier has no native force-climate; it takes the *signature* of whatever you've built most. Its would-be sovereign is the **God-Maker** ending (the refusal-of-the-throne, the maker-of-makers). The **Iron Guild** covets it (it is the Architect's dream made real) but cannot hold it — only the hand that *built* it can shape it. It is the one region with a population of *one* that matters: you.

### Lore & history
There is a place that does not exist until you make it. When an aspirant's craft grows great enough — enough fusions survived, enough creatures remade, enough of the old arts mastered — the Lab stops being a *room* and starts being a *direction*. The work accretes a space around itself the way a pearl accretes around grit: a half-finished demiplane stitched out of intention and spent Essence, hanging off the back of reality like a workshop built onto a house that was never zoned for it. The Stoneblooded say it isn't a real place. The Concord refuses to file it (there is no form for a region with one citizen and no god). The Unbound find it *fascinating*. And the Iron Guild would give a limb — several have — to set foot in it, because the Hollow Atelier is the thing Magna Ironwright has preached her whole life and never once achieved: a world you *build* instead of inherit.

It is hollow because it is *unfinished*, and it is unfinished because *you* are. The Atelier is a region in permanent draft: floors that resolve into solidity only where you've done enough work to deserve ground, halls that extend themselves toward whatever you're about to make, vast blank reaches of un-rendered potential waiting for a reason to become something. Build a Cosmos creature and a wing of ordered crystal-glass accretes; raise a Gaia line and the floors thicken to stone; commit an abomination and a corner of the place goes *wrong* in a way that doesn't wash out. The demiplane wears your portfolio. It is the most honest mirror in the world: a region shaped *entirely* by what you've chosen to make, with nowhere to hide the choices.

The horror of the Atelier is quiet and it is *yours*: it is the only region that holds you accountable not to a faction, a god, or a grid, but to the sheer *accumulated weight* of everything you've built and unmade. Every creature you scrapped left a mark here. Every fusion that screamed is still, faintly, audible in the un-rendered dark, because the Atelier remembers the *drafts*, not just the finished work. To walk it is to walk your own craft made architecture — and to arrive, eventually, at the God-Maker's terrible offer: you have built so many things that could become gods. Why climb a throne yourself, when you could become the *forge* the next ten thousand nobodies climb *toward*? The Atelier is where the game asks if you'd rather be a god — or the thing that *makes* them. And in the funny-grim register, the punchline lands soft and cold: the most powerful ending in the world is also the loneliest job in it, and the demiplane you built to escape the thrones turns out to be the throne nobody warned you about.

### Inhabitants
**Named NPCs (the workshop's sparse, strange cast):**
- **Surgeon-Lab-Tech Veil** *(reused from Threshold — follows your craft here once the Atelier manifests)* — the one familiar face, who finds the demiplane "professionally distressing" and stays anyway, because someone has to bleed the entropy off a *region* now, not just a chimera. Voice: clinical, deadpan, quietly awed despite herself. *"Your Lab grew a *geography*. I've seen botches before. I've never had to *mop a horizon*. New record. Hold the screaming — there's more of it now, it has *acoustics*."*
- **The Draftsman** — a figure that is not quite an NPC and not quite a creature: the Atelier's own attempt to render *a helper*, accreted from your habit of building. It hands you tools, completes your half-thoughts, and is unsettlingly eager to be *useful*, because being useful is the only thing keeping it rendered. Voice: helpful, hollow, fading at the edges when you're not building. *"You made me to *finish* things. So I finish them. Please keep making. When you stop, I... thin. Don't stop. I'd rather not find out where I go."*
- **Quink** *(reused from Threshold — the gutter-rat Lab tutor, who would *kill* to see this and possibly did)* — somehow already here, squatting in a half-rendered corner with a better altar than he's ever had, gleeful and territorial about "the best workshop in any world." Voice: twitchy, delighted, four-thumbs-up. *"You did it! You actually— the Lab's a *place* now! I always said it could be! Nobody believed me! Mostly because I was usually on fire when I said it! WORTH IT!"*
- **The Unmade** — the collective, barely-rendered murmur of every creature you scrapped, melted, sacrificed, or unmade, held in the Atelier's un-finished reaches the way the Maw holds the rotting and the Mournmarch holds the dead. Not vengeful — *unfinished*, asking only to have been worth the making. Voice: layered, soft, a draft of many. The Atelier's conscience and its gut-punch. *"...you started us. You didn't... finish us. Were we... were we a bad idea, or just an early one? Tell us we were *practice*. Tell us the practice *mattered*. ...you don't have to mean it. Just say it. We'll render the rest ourselves."*

**Signature creatures (whatever you made — the Atelier has no native pool):**
- The Atelier spawns nothing of its own; it is populated *retroactively* by **your build history** — the creatures you've fused, mutated, and raised drift its halls as echoes, and the region's "signature roster" is literally a readout of your most-built forces and forms. (Mechanically: the Atelier surfaces *your* registry — your prior fusions as walkable ghosts, your scrapped drafts as the Unmade, your masterworks as guardians of the wings they accreted.)
- **Construct-class masterworks** you've built read as the Atelier's natural nobility — the **foundry-class colossi** (Bulwark Colossus, Sanctwall Colossus, Anvilhall Colossus, Bastionpylon Colossus) stand as load-bearing pillars of the wings they helped render, half-architecture themselves.
- **The God-Maker's seed-forms:** any creature you've pushed *toward* a pole but not ascended lingers here as a *candidate* — a god-in-draft, awaiting the Atelier's defining choice (ascend it for someone else to climb, or finish yourself). These are the region's true "bosses": your own near-gods, asking what they're for.
- **The Architect, Self-Authored** — the God-Maker ascension-form itself: not a creature you catch but a thing you *become*, the region's endgame stake. Its Succession-echo is **The First Draftsman** — a dead-god ghost of a *previous* God-Maker, the last hand that built a realm like this and chose to become the forge, haunting the deepest un-rendered reach as a warning and an invitation in one.

### Set-pieces
1. **The Unfinished Wing** *(player-authored dungeon / accretion-hall).* The growing edge of the Atelier — a hall that *extends itself* toward whatever you're about to build, half-rendered, its geometry resolving a beat behind your intent. **Hook:** the Draftsman needs you to *finish* a wing left half-built by your own past work — clearing the Unmade drafts that clutter it (your scrapped creatures, asking to matter) and deciding their fates: complete them (a Pure-leaning mercy, a powerful late recruit), scrap them for good (Tainted-leaning efficiency, a parts cache), or *let them finish themselves* into something you don't control (a Chaos-leaning gamble). The wing renders solid only once you choose. (Gate: completing a wing unlocks a **player-authored Lab-craft tier** — the Atelier lets you *batch* and *template* your best recipes into repeatable, refined formulae, the God-Maker's production line; branches Pure/Tainted/Chaos by how you treat the Unmade.)
2. **The Drafting Throne** *(ritual-site / endgame-secret).* The Atelier's heart — not a throne to *sit* but a workbench *shaped* like one, where the God-Maker's choice is made. **Hook:** The First Draftsman (the dead prior God-Maker) presents the terminal offer at the bench: take an empty throne yourself (walk *out* of the Atelier and ascend as one of the nine — the region dissolves, its purpose spent), *or* refuse the throne and become **the Architect / God-Maker** — bind yourself to the forge, render the Atelier permanent, and become the maker every future nobody climbs toward (your masterworks seeded into others' worlds as the gods *and* the walls). The bleakest-but-grandest choice in the game, set at the bench where you built everything. (Gate: opens the **God-Maker** ending — the refusal-of-apotheosis route — *or* releases you to the standard nine-throne ascension; choosing God-Maker permanently unlocks the Atelier as a persistent realm and seeds your builds into the async-invasion pool as *god-forges*, not just bosses. The deepest craft-gated lock in the game — measured not by rank but by the *weight of everything you've made*.)

### Flavor encounters
- You round a corner into a hall you don't remember building, perfectly rendered, furnished, *finished* — and realize, slowly, that *you didn't build it yet*. The Atelier built it *ahead* of you, from where your craft is *going*. You haven't made the creature it's clearly *for*. You will. The hall is patient. The hall is *sure*.
- The Draftsman proudly presents a creature it "finished for you while you were out." It is *technically* correct — every part you'd have chosen, assembled exactly to spec — and it is *soulless* in a way you can't name and can't fix, a thing built by intention without the *hand*. The Draftsman waits for praise. You don't have the heart. It thins a little anyway.
- You find a blank patch of un-rendered nothing with a small, hand-lettered sign in your own writing that you don't remember leaving: *"SOMETHING GOES HERE. YOU'LL KNOW IT WHEN YOU CAN MAKE IT. DON'T FORCE IT. — Me."* It is the only kind thing the Atelier has ever said to you, and you said it to yourself.
- An Iron Guild emissary somehow gets a *message* through to the Atelier — not a person, the place won't let them in, just a note, slid under a door that leads nowhere. It reads, in Magna Ironwright's blunt hand: *"You built a world. I never could. I'm not jealous. (I'm a little jealous.) When you decide what it's *for*, tell me. I'll bring wine. I'll be sorry it isn't mine. It's honest work. It's the most honest work there is. — M."*

### Biome ruleset hook (WFC)
- **Palette:** *player-authored* tile-set — the Atelier is the one region whose palette is **assembled from the player's build history**, not pre-set. Rendered wings borrow the tile-language of whatever force you built there (Cosmos-built wings = crystal-glass order; Gaia-built = thickened stone; Eros-built = quietly growing; abomination-built = a corner gone *wrong*), stitched onto vast **un-rendered reaches** (a deliberate "draft" tile — blank potential, legible-as-unfinished, never mistaken for a void-hazard). Hazard and state reads use **shape/glyph** as everywhere (a draft-hatching for un-rendered tiles, a tool-glyph for accretion-benches) — the unfinished must read as *unfinished-and-safe-ish*, distinct from the Storm Vault's lethal void-edges.
- **Hazards:** *un-rendered drift* (blank reaches where standing too long *un-finishes* you a little — a soft, reversible "draft" hazard, not death, that the region uses to push you toward *building* your way across rather than walking), *the Unmade* (drifting scrapped-creature echoes — non-hostile by default, but a grief-and-conscience zone that the Pale Court or Revel would *love* to exploit if they could reach it), *accretion-instability* (newly-rendered tiles that haven't "set," which shift until your build that spawned them is *finished* — a self-imposed, craft-paced hazard unique in the world).
- **Traversal locks:** **no native force-climate** — instead the Atelier takes the *signature of your most-built force*, biasing its own gene-expression toward *whatever you make most* (the only region that mirrors the player rather than imposing on them). Traversal is **craft-gated**, not power-gated: you cross un-rendered reaches by *building* the ground (completing fusions/recipes renders new floor), so the wall here is the *depth of your own work* — a metroidvania of your portfolio. The whole region is **late-unlock** (manifests only past a high craft-mastery threshold — you cannot author a realm as a nobody), and the Drafting Throne is the **God-Maker endgame lock**, gated by the accumulated *weight of everything you've built and unmade* rather than any single rank or standing. It is the structural inverse of Threshold: Threshold is the world's gentle, hand-authored *front door* that everyone shares; the Hollow Atelier is the world's hardest-won, *player*-authored *back room* that only your craft can open, and only you will ever truly walk.

---

## Canon notes & flags (for the orchestrator)

- **Region count: 11 sections** = Threshold hub (§1) + the **8 canonical force-regions** (§§2–9) + **2 net-new regions** (§10 The Maw Beneath, §11 The Hollow Atelier). The two new regions deliberately fill the **two morality-grid / ending cells the eight surface-regions never house**: the corruption *floor* (Chaos/Corrupt → the Devourer, and the Unmaking descent) and the *player-authored* terminus (Order/Tainted → the Architect, and the God-Maker refusal-of-throne). Both are gated *late* and contradict no locked canon.
- **CANON GAP — Titanfall's god (flagged, not invented).** `Mutants_Game_World.md` and `Mutants_Game_Factions.md` both leave Titanfall's ruling deity as "**(a dead Titan)**" — *unnamed in the locked docs.* This region content uses **provisional** Titan names drawn from the codex strata (**Tartaron the Buried Titan** / **Krathonar the Quaking Titan**) and provisional Gaia god-rank Act bosses (**Oreithys**, **Mordathun**) so the region is playable — **these are placeholders pending a canon ruling**, not an authored override of the World/Factions docs. Recommend the orchestrator canonize one Titan name (or confirm the namelessness is intentional flavor — "the god so old its name fell off" is itself on-tone).
- **God-name localizations (noted for consistency).** Several regions render Olympian patrons under regional epithets for flavor (Hades→**Aidaneus**, Zeus→**Astrapios**, Hephaestus→**Hephaestion**, Poseidon localized via **Sphairon/Aellophon** echoes). These read as in-world titles, not new gods; if the codex pins a single canonical spelling per Olympian, reconcile to that. No new pantheon members were created.
- **NPC reuse.** Region NPCs are the *region-resident* faces (e.g. Matron Sevvy, Lady Sepulchre, Foreman Magnus Cog); the **faction leaders and the 64-NPC roster** in `docs/content/factions_npcs.md` remain the canonical authority — region casts reference and sit *beside* that roster (e.g. the Bloomwardens' Greenmother Saoirse Lateharvest leads the faction; Matron Sevvy is her local fringe patron). The Hollow Atelier deliberately **reuses** Veil and Quink (Threshold Lab NPCs) as the only familiar faces in a player-authored realm. No conflicting leader names were introduced.
- **Creature references** draw force-tagged signature lines from `Creature_Codex_Families.md` and the Vol/Book codex (real names where they exist); the two new regions lean on the **Abominations** and **Constructs/Succession** books for their corruption- and craft-pole rosters, respectively. No new stats were invented — only force/role/tier references.

*Eleven regions. Eight inherited from the dead, one held by the living, one rotting below them all, and one you build yourself — because the only thing grimmer than a graveyard of gods is being the hand that makes the next ones.*
