# MUTANTS_GAME — Creature Codex · Volume 1

**Scope:** AD01–AD10 (the ten adult forms) + DM01–DM10 (the ten Unique Monsters / Beasts / Demons). 20 entries.
**Status:** Vol1 complete — AD01…DM10 done. *(Gold-standard reference volume; the bar Vols 2–11 match.)*
**Method:** funny-grim · stats from live `stat_engine.py` (v0.2.1, default genome) · art read from storybook roster sheet #1 (adults) and demon sheets #2–3.

> **Coordination flags for the systems session (do not silently fix — your call):**
> 1. **Stat-doc drift:** `Mutants_Game_StatSpine.md`'s validation table (e.g. Worldback HP 2176, Ruinmaw HP 370) is **stale** — it predates the v0.2.1 balance pass. The live `stat_engine.py` is the source of truth and matches the AD01 worked example exactly (HP 330). All Codex stats come from the live engine. Recommend refreshing the StatSpine table.
> 2. **Juvenile gaps:** Emberwyrm, Tidecoil, Rimewarden, Thornmane have **no confirmed baby** in the registry. Candidates proposed in NOTES (flagged, not hard-assigned) — ratify or override.
> 3. **Demons** are Rank=Legendary/God apex forms (no `tier`); their stats use the rank budget, not a T-tier. God-seeds (Phoenix/Kelpie/Treant) are Apotheosis targets, not bred lines.

---

## AD — The Adult Forms (T2–T3 apex, Wild, Organic)

### AD01 — Ruinmaw
- Art: storybook roster #1, adult 1   |   Class: Organic  Rank: Wild  Tier: T2
- Force-blend: Chaos/Thanatos   (confirmed — grey dire-wolf bound in weeping red sigils)
- Role: feral striker
- Stats (stat_engine): Bulk 30 · Celerity 30 · Ward 30 · Spike 138 · Vitality 30 · Bane 102 | Luck 14 Focus 30 | HP 330 | BST 360
- Evolution line: Ruin Wolf (apex of: Ruin-pup [SB30] → Ruinmaw)
- Signature skill: **Ruin's Hunger** (Drain, Thanatos) — a runed bite that rips Spike damage and feeds a third of it back as HP; below 30% target HP it turns Gambit, doubling down for a spike of self-instability.
- Description: A dire-wolf stitched with red sigils that weep when it's hungry, which is always. It does not hunt to eat so much as to *edit* — whatever it bites, the world has slightly less of afterward. Loyal, in the way an avalanche is loyal to gravity.
- Acquisition: trap (it will not be befriended until it respects you, which means until you survive it)
- NOTES: —

### AD02 — Worldback
- Art: storybook roster #1, adult 2   |   Class: Organic  Rank: Wild  Tier: T3
- Force-blend: Gaia/Eros   (confirmed — boulder-shelled tortoise carrying a living orchard)
- Role: fortress
- Stats (stat_engine): Bulk 245 · Celerity 53 · Ward 53 · Spike 53 · Vitality 181 · Bane 53 | Luck 18 Focus 45 | HP 963 | BST 638
- Evolution line: World Tortoise (apex of: Sprout-shell [SB05] → Spiked-shell [SB26] → Worldback)
- Signature skill: **Orchard Bulwark** (Ward, Gaia) — roots in place and raises its shell as terrain-cover for the whole squad; while rooted the orchard buds, regenerating a sliver of party HP each turn. Immovable, and slow to start — mountains don't hurry.
- Description: A tortoise that kept growing until geography happened. Whole seasons of fruit ripen and fall on its back, and the small things that live in its moss have never known another sky. It remembers every step it has ever taken, which is why it takes so few.
- Acquisition: befriend (offer it something to grow; it has time)
- NOTES: T3-apex despite "adult" framing — it is the top of the World Tortoise chain.

### AD03 — Emberwyrm
- Art: storybook roster #1, adult 3   |   Class: Organic  Rank: Wild  Tier: T3
- Force-blend: Chaos/Ouranos   (confirmed — red winged dragon, furnace-gut, whip tail)
- Role: nuker
- Stats (stat_engine): Bulk 53 · Celerity 181 · Ward 53 · Spike 245 · Vitality 53 · Bane 53 | Luck 18 Focus 45 | HP 579 | BST 638
- Evolution line: Ember Drake (apex; juvenile **unconfirmed** — see NOTES)
- Signature skill: **Cinder Cascade** (Gambit, Chaos) — vents its whole furnace at once for damage scaling off Spike, then overheats itself (self-entropy). The more punishment it has soaked that fight, the bigger the blast — a creature that pays for its best move in advance.
- Description: A winged furnace with opinions, mostly about altitude and arson. It flies the way a thrown torch flies — beautifully, briefly, and toward something flammable. Vets of the wyrm trade agree it is loyal; they disagree on whether that's comforting.
- Acquisition: trap (you do not befriend a fire; you contain it and hope)
- NOTES: Registry leaves the baby open. Leading candidate: **SB13 finned-hatchling** (Ouranos/Chaos) — force-adjacent and dragon-coded — but SB13 is *also* the leading candidate for Tidecoil. Flag for the systems session to assign to one line, not both.

### AD04 — Palehart
- Art: storybook roster #1, adult 4   |   Class: Organic  Rank: Wild  Tier: T2
- Force-blend: Cosmos/Eros   (confirmed — white stag, blue ordered sigils down the flank)
- Role: support
- Stats (stat_engine): Bulk 30 · Celerity 30 · Ward 138 · Spike 30 · Vitality 102 · Bane 30 | Luck 14 Focus 30 | HP 546 | BST 360
- Evolution line: Pale Hart (apex of: Fawn [SB22] → Palehart)
- Signature skill: **Sanctum Sigil** (Ward, Cosmos) — inscribes an ordering-glyph on an ally that caps incoming variance (blunts crits and Chaos-Spike) and bleeds a little of the absorbed harm back as healing. Order made into a fence.
- Description: A stag so composed it seems to have already forgiven you for something you haven't done yet. The sigils on its coat aren't decoration; they're the rules it's quietly enforcing on the air around it. Where it walks, dice land flatter.
- Acquisition: befriend (it chooses the calm; be calm)
- NOTES: —

### AD05 — Tidecoil
- Art: storybook roster #1, adult 5   |   Class: Organic  Rank: Wild  Tier: T2
- Force-blend: Ouranos/Cosmos   (confirmed — long blue finned sea-serpent)
- Role: controller
- Stats (stat_engine): Bulk 30 · Celerity 138 · Ward 102 · Spike 30 · Vitality 30 · Bane 30 | Luck 14 Focus 30 | HP 330 | BST 360
- Evolution line: Tide Serpent (apex; juvenile **unconfirmed** — see NOTES)
- Signature skill: **Undertow** (Hex, Cosmos) — hooks a target in a current that drags its initiative to the back of the order and pins it for a turn. Doesn't hit hard; decides who acts and when, which is worse.
- Description: A serpent built entirely out of the moment before a wave decides what to do. It rarely strikes — it arranges, nudging the fight downhill until your fastest creature is suddenly last and very wet. The deep, it implies, was here before you and has excellent patience.
- Acquisition: summon (call it from tide-pools at the turn of the moon)
- NOTES: Juvenile open. **SB13 finned-hatchling** (Ouranos/Chaos) is the body-match (finned, aquatic) but force-leans Chaos; shared candidate with Emberwyrm — flag for single assignment.

### AD06 — Gravetusk
- Art: storybook roster #1, adult 6   |   Class: Organic  Rank: Wild  Tier: T2
- Force-blend: Gaia/Chaos   (confirmed — brown boar, red bristle-mane, tribal tusk-paint)
- Role: charger
- Stats (stat_engine): Bulk 138 · Celerity 30 · Ward 30 · Spike 102 · Vitality 30 · Bane 30 | Luck 14 Focus 30 | HP 330 | BST 360
- Evolution line: Grave Boar (apex of: Boar-piglet [SB12] → Gravetusk)
- Signature skill: **Gravecharge** (Strike, Gaia) — lowers its head and commits; damage scales with the ground it crossed to land the hit, and the impact staggers (delays the target's next turn). No brakes were installed at the factory.
- Description: A boar that has confused "strategy" with "running at the problem faster." Its tusks are painted with the marks of everything it's already flattened, which it cannot read and would charge anyway. Endearing, the way a runaway cart is endearing once you're safely up a tree.
- Acquisition: trap (stand still, then don't)
- NOTES: —

### AD07 — Augurwing
- Art: storybook roster #1, adult 7   |   Class: Organic  Rank: Wild  Tier: T2
- Force-blend: Ouranos/Eros   (confirmed — teal-and-gold plumed bird, fan crest)
- Role: seer
- Stats (stat_engine): Bulk 30 · Celerity 138 · Ward 30 · Spike 30 · Vitality 102 · Bane 30 | Luck 14 Focus 30 | HP 546 | BST 360
- Evolution line: Augur Bird (apex of: Sky-chick [SB15] → Augurwing)
- Signature skill: **Reading of the Augur** (Rouse, Ouranos) — glimpses the next turn and tells the squad about it: party-wide initiative and evasion up for a round. Prophecy as a pep talk.
- Description: A plumed diviner that reads the future in the worst possible omens and then sounds delighted about it. "Ah," it seems to say, fanning its crest, "we all die screaming — but not *this* turn." Somehow that's exactly the information you needed.
- Acquisition: befriend (bring it a question; it already knows the answer)
- NOTES: —

### AD08 — Rimewarden
- Art: storybook roster #1, adult 8   |   Class: Organic  Rank: Wild  Tier: T2
- Force-blend: Cosmos/Gaia   (confirmed — white bear plated in crystalline ice-spines)
- Role: control-tank
- Stats (stat_engine): Bulk 102 · Celerity 30 · Ward 138 · Spike 30 · Vitality 30 · Bane 30 | Luck 14 Focus 30 | HP 330 | BST 360
- Evolution line: Rime Bear (apex; juvenile **unconfirmed** — see NOTES)
- Signature skill: **Hoarfrost Aegis** (Ward, Gaia) — sheaths in rime for a heavy shield and freezes whatever strikes it, slowing the attacker. A wall that bites back with cold.
- Description: An ice-bear that has decided the correct temperature for any disagreement is "lower." It doesn't roar to threaten so much as to lower the room, the morale, and the enemy's reaction time. Glaciers, it will remind you at length, also win by simply not moving.
- Acquisition: trap (it respects only what outlasts the cold)
- NOTES: Juvenile open. Body-match candidate: **SB32 mushroom bear-cub** (a cub, but Gaia/Eros — force-mismatch); or a dedicated frost-cub yet to be drawn. Flag — do not hard-assign.

### AD09 — Gloamcat
- Art: storybook roster #1, adult 9   |   Class: Organic  Rank: Wild  Tier: T2
- Force-blend: Thanatos/Ouranos   (confirmed — violet panther wreathed in soul-flame)
- Role: assassin
- Stats (stat_engine): Bulk 30 · Celerity 102 · Ward 30 · Spike 30 · Vitality 30 · Bane 138 | Luck 14 Focus 30 | HP 330 | BST 360
- Evolution line: Gloam Cat (apex of: Ember-kit [SB10] → Gloamcat)
- Signature skill: **Gloaming Bite** (Drain, Thanatos) — a fast soul-flame strike that lifesteals, and bites deeper the closer the target is to death. It arrives last and leaves first.
- Description: A panther made of the colour the sky goes right before it admits it's night. It drains as it strikes — not out of malice exactly, more the way a draft drains a candle. You will not hear it coming; you will simply start to feel less.
- Acquisition: trap (bait it with a soul brighter than its own)
- NOTES: —

### AD10 — Thornmane
- Art: storybook roster #1, adult 10   |   Class: Organic  Rank: Wild  Tier: T2
- Force-blend: Eros/Gaia   (confirmed — green wood-lion, bark mane, leaf-tufted)
- Role: regenerator
- Stats (stat_engine): Bulk 102 · Celerity 30 · Ward 30 · Spike 30 · Vitality 138 · Bane 30 | Luck 14 Focus 30 | HP 654 | BST 360
- Evolution line: Thorn Lion (apex; juvenile **unconfirmed** — see NOTES)
- Signature skill: **Heartwood Bloom** (Mend, Eros) — digs its roots in and heals itself and the squad's most wounded over several turns; the longer the fight drags, the more it out-lasts. A lion that wins by gardening.
- Description: A lion whose mane is a small forest and whose temperament is the patience of one. Wounds close over with new bark; old scars sprout. It would rather outlive an enemy than beat one, and given a long enough afternoon, it usually does.
- Acquisition: befriend (let it root somewhere; come back next season)
- NOTES: Juvenile open. Body-match candidate **SB21 lion-cub** (Cosmos/Gaia — force-mismatch); force-match candidate **SB33 leaf-stag** (Eros/Gaia, wrong body). Flag — leaning toward a not-yet-drawn leaf-cub.

---

## DM — Unique Monsters, Beasts & Demons (Apex: Legendary / God, Organic)

### DM01 — Shade-wraith
- Art: storybook demon sheet #2, demon 1   |   Class: Organic  Rank: Legendary  Tier: — (apex)
- Force-blend: Thanatos/Chaos   (confirmed — hooded violet wraith trailing tentacles)
- Role: boss / taboo-fusion
- Stats (stat_engine): Bulk 88 · Celerity 88 · Ward 88 · Spike 298 · Vitality 88 · Bane 402 | Luck 24 Focus 60 | HP 914 | BST 1052
- Evolution line: standalone (Legendary boss; reads as a taboo-fusion abomination, not a bred chain)
- Signature skill: **Engulfing Grief** (Drain, Thanatos) — lashes the whole front line, healing per soul it skims, and leaves despair behind (lowers their offense). Sorrow with reach.
- Description: A grief that sat unattended so long it grew limbs and ambitions. It does not hate you — hatred is warm, and there is nothing warm left in it. It simply wants company, and it gets it the only way it knows: by taking.
- Acquisition: summon (it answers any name spoken at a fresh grave; ill-advised)
- NOTES: Tagged taboo-fusion;boss — prime "the world hunts you for making this" content.

### DM02 — Ogre-brute
- Art: storybook demon sheet #2, demon 2   |   Class: Organic  Rank: Legendary  Tier: — (apex)
- Force-blend: Gaia/Chaos   (confirmed — green slab-muscled ogre, scrap armor)
- Role: bruiser
- Stats (stat_engine): Bulk 402 · Celerity 88 · Ward 88 · Spike 298 · Vitality 88 · Bane 88 | Luck 24 Focus 60 | HP 914 | BST 1052
- Evolution line: standalone (Legendary brute)
- Signature skill: **Tantrum** (Strike, Gaia) — a wide cleave that hits harder the more hurt the ogre is; a low-HP Ogre-brute is a structural hazard. Anger management was not on the table.
- Description: All fists, no patience, and a strong working theory that every problem is a piñata. It is not stupid so much as *uninterested* in the parts of a fight that aren't hitting. Reliable, in that you always know exactly what it will do and can do nothing about it.
- Acquisition: trap (let it punch something it can't break, then walk it home tired)
- NOTES: —

### DM03 — Bone-weaver
- Art: storybook demon sheet #2, demon 3   |   Class: Organic  Rank: Legendary  Tier: — (apex)
- Force-blend: Thanatos/Chaos   (confirmed — skeletal spider knit from mismatched bone)
- Role: boss (undead)
- Stats (stat_engine): Bulk 88 · Celerity 88 · Ward 88 · Spike 298 · Vitality 88 · Bane 402 | Luck 24 Focus 60 | HP 914 | BST 1052
- Evolution line: standalone (undead Legendary; a fusion-result, not a bred line)
- Signature skill: **Skein of the Dead** (Summon, Thanatos) — knits expendable bone-spawn from the fallen (the Graveyard pays out); fields a wall of skittering chaff that it cheerfully spends. Death, reused.
- Description: A spider assembled out of someone else's skeleton — several someones, actually, and it is not fussy about whose femur goes where. It builds more of itself faster than you can take it apart, which it finds funny and you will not. Tidiness was never the point; *quantity* was.
- Acquisition: summon (it comes when there are enough bones to be worth its time)
- NOTES: Undead boss; pairs naturally with the Graveyard/reanimation systems.

### DM04 — Eye-tyrant
- Art: storybook demon sheet #2, demon 4   |   Class: Organic  Rank: Legendary  Tier: — (apex)
- Force-blend: Chaos/Ouranos   (confirmed — floating violet eye-tyrant, ring of eyestalks)
- Role: secret boss / eldritch
- Stats (stat_engine): Bulk 88 · Celerity 298 · Ward 88 · Spike 402 · Vitality 88 · Bane 88 | Luck 24 Focus 60 | HP 914 | BST 1052
- Evolution line: standalone (eldritch secret boss)
- Signature skill: **Eye of Misrule** (Hex, Chaos) — its gaze scrambles a target's turn order and shuffles which skill fires; high-Focus victims resist, briefly. Certainty, deleted.
- Description: It sees too much and forgives nothing, which is a tiring way to live and it would like you to share in that. Each eye is fixed on a different one of your mistakes, including the ones you're about to make. Negotiation is possible but never advisable; it has already watched the conversation go badly.
- Acquisition: summon (find the door it's already looking through)
- NOTES: Tagged secret-boss;eldritch — gate behind a real cost.

### DM05 — Phoenix
- Art: storybook demon sheet #2, demon 5   |   Class: Organic  Rank: **God** (god-seed)  Tier: — (apex)
- Force-blend: Ouranos/Chaos   (confirmed — solar firebird, wings of open flame)
- Role: god-seed (Apotheosis / ascension candidate)
- Stats (stat_engine): Bulk 129 · Celerity 594 · Ward 129 · Spike 439 · Vitality 129 · Bane 129 | Luck 32 Focus 85 | HP 1687 | BST 1549
- Evolution line: standalone — an **ascended-form / Apotheosis target**, not a wild chain (Ouranos pole-seed)
- Signature skill: **Schedule of Ash** (Gambit, Chaos) — the first time it would die in a battle, it detonates and is reborn at partial HP. Death is, for the Phoenix, an inconvenient appointment it keeps and resents.
- Description: It dies on schedule and comes back annoyed about the paperwork. Each rebirth is a small apocalypse for whatever was standing nearby — being near a Phoenix's bad morning is its own category of hazard. It has done this longer than fire has had a name, and it is so, so over it.
- Acquisition: summon (offer it an ending worth interrupting)
- NOTES: God-rank god-seed → Apotheosis candidate for the **Ouranos** pole. Stats use the god budget (no T-tier).

### DM06 — Core-golem
- Art: storybook demon sheet #2, demon 6   |   Class: Organic  Rank: Legendary  Tier: — (apex)
- Force-blend: Gaia/Cosmos   (confirmed — boulder-bodied golem around a teal glowing core)
- Role: tank
- Stats (stat_engine): Bulk 402 · Celerity 88 · Ward 298 · Spike 88 · Vitality 88 · Bane 88 | Luck 24 Focus 60 | HP 914 | BST 1052
- Evolution line: standalone (Legendary tank; reads near the Construct patron's domain — see NOTES)
- Signature skill: **Grudge Core** (Ward, Cosmos) — banks a portion of every hit it takes in its core, then discharges the stored harm as a retaliating ward-burst. It keeps score, and it always settles up.
- Description: A boulder with a glowing grudge and a long memory for it. Every blow it eats is filed, dated, and refunded with interest the moment you relax. It is patient the way only a rock can be, and exactly that forgiving.
- Acquisition: summon (wake the core; mind the grudge)
- NOTES: Organic per registry, but its make reads close to the **Construct/Hephaestus** domain — possible organic↔construct bridge piece. Flag, don't reclassify.

### DM07 — Ash-fiend
- Art: storybook demon sheet #2, demon 7   |   Class: Organic  Rank: Legendary  Tier: — (apex)
- Force-blend: Thanatos/Chaos   (confirmed — horned winged demon, burning blade)
- Role: boss / taboo abomination
- Stats (stat_engine): Bulk 88 · Celerity 88 · Ward 88 · Spike 298 · Vitality 88 · Bane 402 | Luck 24 Focus 60 | HP 914 | BST 1052
- Evolution line: standalone (Legendary; taboo-fusion abomination)
- Signature skill: **Soulcleaver** (Drain, Thanatos) — its burning blade reaps; every kill it lands stacks its Bane higher for the rest of the fight. The longer it's let live, the less the rest of you do.
- Description: It brought a sword to a soul fight and has never once regretted the choice. The blade isn't enchanted so much as *grieving* — it takes a little of whatever it cuts and keeps it. Disarming the fiend does not help; the fiend was always the easy half.
- Acquisition: summon (it answers a drawn blade and a bad intention)
- NOTES: taboo-fusion;boss — abomination tier.

### DM08 — Spectral-kelpie
- Art: storybook demon sheet #2, demon 8   |   Class: Organic  Rank: **God** (god-seed)  Tier: — (apex)
- Force-blend: Thanatos/Ouranos   (confirmed — translucent horse of drowned green flame)
- Role: god-seed (Apotheosis / ascension candidate)
- Stats (stat_engine): Bulk 129 · Celerity 439 · Ward 129 · Spike 129 · Vitality 129 · Bane 594 | Luck 32 Focus 85 | HP 1687 | BST 1549
- Evolution line: standalone — **ascended-form / Apotheosis target** (Thanatos pole-seed)
- Signature skill: **Drowning Invitation** (Hex, Thanatos) — lures a single target a step closer, then drags it under: heavy drain plus a slow it can't shrug while "submerged." It has excellent manners and no mercy.
- Description: A drowned horse still politely looking for a rider, and it would so love if that were you. Climb on and the water is already in your lungs; decline and it simply waits, dripping, for the next person who's tired. It remembers every rider. None of them remember much.
- Acquisition: summon (stand at the water's edge and want to be carried)
- NOTES: God-rank god-seed → Apotheosis candidate for the **Thanatos** pole.

### DM09 — Abyssal-leviathan
- Art: storybook demon sheet #2, demon 9   |   Class: Organic  Rank: Legendary  Tier: — (apex)
- Force-blend: Thanatos/Ouranos   (confirmed — deep-sea horror, lantern-lit jaws, fins)
- Role: boss / deep boss
- Stats (stat_engine): Bulk 88 · Celerity 298 · Ward 88 · Spike 88 · Vitality 88 · Bane 402 | Luck 24 Focus 60 | HP 914 | BST 1052
- Evolution line: standalone (Legendary deep boss)
- Signature skill: **The Deep Takes** (Drain, Thanatos) — surges from below for a massive Bane hit and pulls the target *under*, removing it from the turn order for a beat. What goes down does not always come back up.
- Description: The deep, with teeth, and a grudge against anything that floats. It spent a few eras at the bottom deciding the surface had it too good, and has come up to discuss. Its light is friendly. Its light is bait. Everything down there is bait.
- Acquisition: summon (call it up where the water has no floor)
- NOTES: —

### DM10 — Elder-treant
- Art: storybook demon sheet #2, demon 10   |   Class: Organic  Rank: **God** (god-seed)  Tier: — (apex)
- Force-blend: Eros/Gaia   (confirmed — colossal mossy tree-beast, antlered canopy)
- Role: god-seed (Apotheosis / ascension candidate)
- Stats (stat_engine): Bulk 439 · Celerity 129 · Ward 129 · Spike 129 · Vitality 594 · Bane 129 | Luck 32 Focus 85 | HP 3082 | BST 1549
- Evolution line: standalone — **ascended-form / Apotheosis target** (Eros pole-seed)
- Signature skill: **Apology of Roots** (Mend, Eros) — vast regrowth that heals the whole squad each turn and, once per battle, raises a fallen ally back as a sapling at partial HP. Forgiveness, with bark.
- Description: Older than the forest's first apology, and in no hurry to accept yours. It has outlived every fire set to clear it and grown back over the ashes politely, which the fire found infuriating. To it, your whole campaign is a single odd afternoon — and it will likely still be standing to misremember you.
- Acquisition: befriend (sit in its shade long enough to stop being in a rush)
- NOTES: God-rank god-seed → Apotheosis candidate for the **Eros** pole; the registry's huge Vitality (594) makes it the durability ceiling of Vol1 (HP 3082).
