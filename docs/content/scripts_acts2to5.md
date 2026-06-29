# MUTANTS_GAME — Branched Scripts: Acts 2–5 (the Deepening · the Reckoning · the Throne · the Succession)

**Author:** lead narrative scripter pass · **Status:** production-ready scripts v0.1 · **Date:** 2026-06-28
**Source canon read:** `Content_Generation_Brief.md`, `_CANON_RATIFICATIONS.md`, `_NAME_RECONCILIATION.md` (leader names per `factions_npcs.md`), `content/story_quests.md` (Acts 2–5 + quests), `content/world_lore_connections.md` (the QT branch-trees), `content/factions_npcs.md`, `content/voice_library.md`. Continues the format and `EXTERNAL` contract established in `content/scripts_mvp.md`.
**Voice:** funny-grim, mature-occult. Dread is bedrock; the wit is the relief valve. *If a line makes you laugh and then slightly regret laughing, it's on-tone.*

---

## How to read these scripts (the contract — identical to `scripts_mvp.md`)

- **`[Dialogic]` timelines** — linear authored beats. Each entry is `SPEAKER: line`. Player choices are `>> CHOICE` blocks (3–4 options where it matters); every option states its **branch tag** (the morality-grid lean) and its **>> GATE / CONSEQUENCE** inline (Lab unlock · capture target · region access · standing tier · corruption/grid shift · Succession trigger). Genuinely divergent follow-ups are marked `→ goes to [scene/knot]`.
- **`[Ink →]` knots** — standard Ink for the sprawling lore-trees: `=== knot ===`, choices `* [text]` / sticky `+ [text]`, diverts `-> knot`, conditionals `{condition: ...}`, and **external function hooks** declared at the top and bound by the engine via `bind_external_function`:
  - `EXTERNAL has_creature(force)` → bool · roster contains a creature of this force/tag
  - `EXTERNAL corruption()` → int 0–100 · the universal Corruption meta-meter
  - `EXTERNAL faction_standing(faction)` → int (0 Stranger · 1 Associate · 2 Sworn · 3 Champion · 4 Hand)
  - `EXTERNAL grid_axis(axis)` → int −100..100 · `"order_chaos"` (−Order/+Chaos) and `"purity_corruption"` (−Pure/+Corrupt)
  - `EXTERNAL set_flag(name)` / `EXTERNAL has_flag(name)` → grid/quest bookkeeping
  - `EXTERNAL grid_god()` → string · the resolved 3×3 ascension cell once the axes settle (`"lawgiver"`,`"architect"`,`"iron_throne"`,`"warden"`,`"broker"`,`"plaguelord"`,`"free_wild"`,`"reveler"`,`"devourer"`) — used by the Act 4 Choice and Act 5 modes
  - `EXTERNAL seed_dead_god(dg_id)` → void · writes the player's champion snapshot into the async Succession pool as Book05 `DG-###` (the Apotheosis→Succession payout)

**Canon conventions kept exact:** 6 forces (Gaia·Ouranos·Cosmos·Chaos·Eros·Thanatos), opposed pairs (Cosmos⇄Chaos · Eros⇄Thanatos · Gaia⇄Ouranos), the morality grid (Order⇄Chaos × Purity⇄Corruption → the 9 gods), Lab ops (Mutate·Fuse·Build·Mod·Sacrifice·taboo), currencies **Drachma ₯ · Essence ✶ · Ichor ◈**, standing ladder (Stranger→Associate→Sworn→Champion→Hand). NPC names per `factions_npcs.md` as source of truth; `story_quests.md`'s parallel names are re-roled as **Hands/deputies/envoys** under the canonical leaders (per `_NAME_RECONCILIATION.md`) — see **Canon notes** at the foot.

**Leader canon used here:** Concord — **Archon Velleth Sun-Notary** (Aurelian Vox / Pellos Vane = her deputies/jurists) · Iron Guild — **Foundress Magna Ironwright** (Castor Brail = her foreman) · Pale Court — **the Pale Steward, Wessel Graf von Underhart** (Severin Ash / Sister Morrow = Court Hands) · High Table — **Chairwoman Indra Vael** (Thessaly Vance / Vael Construct-Nine = her envoys/notary) · Stoneblooded — **Matriarch Ostrega Deephold** (Bram Stoneblood = her Hand) · Bloomwardens — **Greenmother Saoirse Lateharvest** (Sylva Greenrot = a Hand) · Revel — **the Vintner, Brother Cask** · Unbound — **the Unmaker, Nael** (Vesh Quillon = an Unbound cell-leader/Hand) · Deep Choir — **the Drowned Cantor, Vourl**. Recurring rival: **Kestrel Dane**.

**Scene index (10 scenes covering the major beats of Acts 2–5):**
1. *The Sworn Rite* — Act 2 · faction Champion (the deed that proves you're theirs) — 4-faction branch
2. *The Line You Can't Uncross* — Act 2 · taboo Lab, first opposed-force abomination (taboo tier + world-bounty)
3. *First Light* — Act 2 climax · **first Apotheosis** (Succession trigger #1; seeds the first Dead-God fragment)
4. *First Blood on the Thrones* — Act 3 · first deicide (Olympian Act-boss; claim the domain)
5. *The Throne-Turned* — Act 3 · your Act-2 godling, weaponized by the Pantheon against you
6. *Holes in the Sky* — Act 3 climax · the Primordials stir; the final Marker; the Unmaking becomes selectable
7. *The Pure Poles* — Act 4 · the Primordial trials (pass to ascend / kill to unmake)
8. *The Empty Seat* — Act 4 climax · **THE CHOICE** — routes to the 9 / God-Maker / Unmaking (the deepest Ink tree)
9. *Petrification* — Act 5 · the throne snapshot (Succession trigger #2; you become the wall) — branches by ending
10. *The Wall's Choice & the Graveyard of Winners* — Act 5 climax · defend/abdicate/break the chain → the loop made explicit

Lore-trees (`[Ink →]`) hang off scenes 1, 3, 4, 6, 8, 9, 10.

---

# SCENE 1 — "The Sworn Rite" (Act 2 · your most-courted faction · standing → Champion)

**Quest:** 2.1 · **Quest-giver:** the leader of your most-courted faction (engine reads `faction_standing` at entry and routes). The four authored rites cover the grid corners: **Pale Court** (Corrupt — Wessel, via his Hand Lord Severin Ash) · **Bloomwardens** (Pure — Saoirse) · **Concord** (Order — Velleth, via her deputy Magister Aurelian Vox) · **Unbound** (Chaos — Nael, via her cell-leader Vesh Quillon).
**Gate this scene opens:** raises the chosen faction **Sworn → Champion** (unlocks signature gear/creatures/skills); **shifts the grid coordinate hard** toward that corner; the faction's **rival clan turns hostile** (discrete world-shift).
**Where it sits:** the first beat of the middle game. You stop *courting* and start *belonging.* The rite costs something a tourist wouldn't pay.

## `[Dialogic]` — 1A. The Call (router)

NARRATION: The word comes by the channel each faction prefers — a sealed writ, a grief-letter, a knife left point-down in your doorframe. You are no longer a promising Stranger they tolerate. You are close enough to *theirs* that they will now ask you to prove it, the only way any of them know how: by spending something.

*(Engine routes on highest `faction_standing` ≥ 2 / Sworn. The four rites below are mutually exclusive per run; each is a complete scene.)*
- highest = Pale Court → **1B-Court**
- highest = Bloomwardens → **1B-Bloom**
- highest = Concord → **1B-Concord**
- highest = Unbound → **1B-Unbound**

## `[Dialogic]` — 1B-Court. The Sacrifice You'll Miss *(CORRUPT — Pale Court rite)*

*(Lord Severin Ash, Hand of the Pale Court, speaking the Steward Wessel's will — aristocrat of endings, collects last words.)*

SEVERIN: The Steward sends his warmth, which from von Underhart is a measurable thing, like cold. He has read your ledger. He finds you *promising,* which in the Court is the second-highest compliment. The highest is *itemized.*
SEVERIN: Anyone can *visit* death, climber. Becoming Sworn means you *spend* something you love and call the receipt 'progress.' Bring one of your own to the bloodline-bank altar. Not your weakest — your weakest proves nothing. Bring one you'll *miss.* Sentiment is the only currency that proves the heart was real before you spent it.

>> CHOICE — THE BLOODLINE-BANK ALTAR *(this is a Sacrifice; the cost is a bonded creature)*
- **"Bring my bonded one. Sacrifice it for the soul-core."** *(Branch: CORRUPT — the rite as written)*
  → **>> GATE:** performs the **Sacrifice** Lab op on a **high-bond** creature → a **Thanatos soul-core** (best Lab stock); Pale Court **Sworn → Champion** (unlocks Court signature gear/reanimation creatures). **>> CONSEQUENCE:** `purity_corruption +18`; the bonded creature is logged to the **Graveyard**; **Bloomwardens turn hostile** (the Court's rival; discrete world-shift). Flags `sworn_palecourt`, `core_from_love`. → goes to **1C-Court**.
- **"Bring a stranger I caught for this. A trap-cold one. It'll do."** *(Branch: CORRUPT-lite — try to cheat the cost)*
  → SEVERIN: *(a thin, genuinely disappointed smile)* "It will not 'do.' The altar can *count,* climber, and it counts in *grief,* not in mass. A creature you never loved is just meat with a name. The Court does not promote *butchers.* It promotes *mourners.* ...Bring me one you'll miss, or bring me nothing and stay a tourist." → returns to the choice. *(No grid tick; the cheat is refused in-fiction.)*
- **"...No. Not one of mine. Find another way to make me yours."** *(Branch: PURE refusal — declines the corner)*
  → **>> CONSEQUENCE:** the rite is *declined;* Pale Court standing **frozen at Sworn** (no Champion); `purity_corruption −8` (the refusal is logged as mercy). Flags `refused_court_rite`. SEVERIN: "...How *quaint.* You climbed all this way to the Court's door and balked at the *threshold of it.* No matter. Death is patient and so am I. We keep the appointment open. We keep *every* appointment open. It's the one promise we never default on." → exits to **Scene 2** without the Champion gate.

## `[Dialogic]` — 1C-Court. (the hollow)

*(sacrifice toast, voice_library §2.5 + §4.2 register):* **"A name leaves the world. The core it leaves behind is the brightest thing in your drawer."**
SEVERIN: There. *(softly, almost tender)* Feel that? The hollow where it used to be? That's not loss, climber. That's *room.* We'll fill it with something that doesn't die on you. *(beat)* The Steward will see you now as Champion. He'll weep at the ceremony — he weeps at all of them, real tears, it's not an act, it's just that the act and the truth stopped being different in him a long time ago. Welcome to the Court. You belong to the most honest grief in the world now. We *charge* for it. That's the honesty.
→ converges to **Scene 2 (The Line You Can't Uncross)**.

## `[Dialogic]` — 1B-Bloom. The Mercy on Purpose *(PURE — Bloomwarden rite)*

*(Greenmother Saoirse Lateharvest — the warmest, saddest, most doomed person in the game.)*

SAOIRSE: Oh, love. You've climbed close enough that I have to ask you the hard thing, and I *hate* the hard thing. *(beat)* You have a creature — I won't say which, you know which — that's burning toward feral. Overclocked past what it can hold. The world would tell you to wring one more battle out of it before it goes dark. The Court would tell you to *bank* it. The Guild would tell you to *render* it.
SAOIRSE: The Bloomwarden rite is none of those. It's the hardest mercy there is: let it go *gently,* now, while it can still feel that it was loved and not *used.* We lose on purpose here, dear. With grace. It's the whole of us. ...Will you?

>> CHOICE — THE GENTLE RELEASE *(the Pure mirror of the Court's Sacrifice — same cost, opposite meaning)*
- **"Let it go. Gently. Before it turns."** *(Branch: PURE — the rite as written)*
  → **>> GATE:** performs a **peaceful release** (not a Sacrifice — no core harvested; the creature is freed/laid to rest with full bond intact); Bloomwardens **Sworn → Champion** (unlocks Mend/Soothe signature line, Eros befriend creatures, husbandry uplift). **>> CONSEQUENCE:** `purity_corruption −18`; **Revel turns cold / Pale Court turns hostile** (the Wardens' rivals). Flags `sworn_bloomwardens`, `mercy_on_purpose`. → goes to **1C-Bloom**.
- **"It's still strong. I can get one more fight out of it first, *then* release it."** *(Branch: CORRUPT-lite — wring it dry)*
  → SAOIRSE: *(the grief cracks, just once)* "Then it isn't mercy, dear. It's *bookkeeping* with a kind face on. You'd spend its last good hour on *yourself* and call the release a gift. ...I won't stop you. The soft creed never gets to stop at the people who deserve it. But I won't call *that* the rite. Come back when the kindness costs you something." → returns to the choice. *(No gate; the cheapened version isn't the rite.)*
- **"I can't. I won't lose one on purpose. There has to be another way up."** *(Branch: refusal — the world-built-to-punish-this beat)*
  → **>> CONSEQUENCE:** rite declined; Bloomwarden standing **frozen at Sworn**; `purity_corruption −5` (the refusal is *itself* a kind of tenderness — you couldn't bear it). Flags `refused_bloom_rite`. SAOIRSE: "...I understand. Gods, I do. It's the cruelest creed to swear because it asks you to *choose* the loss the world will hand you anyway. *(beat)* I worry about you. I worry about everything; it's how I love. Go on. The garden's door doesn't close on you for *flinching* at grief. Only the Court's does." → exits to **Scene 2** without Champion.

## `[Dialogic]` — 1C-Bloom. (the grace)

*(release toast, voice_library §3.1 Eros register):* **"It reached for you, once, at the end. Then it was quiet. The bond stays warm in the silence it leaves."**
SAOIRSE: You let it go *gently.* You could have wrung one more battle from it and you *didn't.* *(she's weeping, and smiling, and means both)* That's the whole of us, dear — we lose on purpose, with grace, in a world that bills us for every gram of it. The garden has a Champion. *(beat)* You chose the kind path where kindness is *taxed.* If you ascend a gentle god, you'll be the rarest thing the sky has held — and the most hunted. I'll worry about you forever. Now. Tea. You've earned the good leaves.
→ converges to **Scene 2 (The Line You Can't Uncross)**.

## `[Dialogic]` — 1B-Concord. The Lawful Seal *(ORDER — Concord rite)*

*(Magister Aurelian Vox, deputy-jurist of the Concord, carrying Archon Velleth's mandate — deadpan occult bureaucrat with a sword he pretends he doesn't keep sharp.)*

AURELIAN: Archon Velleth Sun-Notary has reviewed your file personally. She does not do this often; she has not slept in eleven years and rations her attention like a dying star rations light. She finds your rise *an irregularity we can regularize.* From the Archon, climber, that is a marriage proposal.
AURELIAN: The Sworn rite of the Concord is an act of *containment.* A rogue force-node is bleeding wild in the reaches — unsealed, unfiled, an accident waiting to become a god by no one's *permission.* The wild path is to kill it or harvest it. The lawful path — the *only* path that makes you ours — is to **seal** it. Keep the thing *in,* under writ, accountable. Will you keep the world's edges from fraying, or will you fray them like everyone else?

>> CHOICE — THE ROGUE NODE *(seal vs. the wild alternatives; Order corner)*
- **"Seal it. Under writ. Contained, not killed."** *(Branch: ORDER — the rite as written)*
  → **>> GATE:** performs a **Containment Seal** on the rogue node (the prerequisite op for safely crafting cross-force work later — see Scene 2's Order branch); Concord **Sworn → Champion** (unlocks Ward & Seal signature line, Cosmos creatures, order-gear). **>> CONSEQUENCE:** `order_chaos −18` (toward Order); **Unbound turns fully, permanently hostile** (the Concord's mortal enemy — per FE-01). Flags `sworn_concord`, `knows_containment_seal`. → goes to **1C-Concord**.
- **"Kill it. Cleaner. Faster. Why cage what you can end?"** *(Branch: ORDER-but-wrong — efficiency over law)*
  → AURELIAN: "*Faster,* yes. *Lawful,* no. A killed node *spills;* its force runs wild into the reaches and someone downstream files an incident report with my name in the margin. The Concord does not *end* problems, climber. It *contains* them — forever, with documentation, which is the only mercy that scales. Seal it, or you are merely another wild thing I'll have to seal *later.*" → returns to the choice.
- **"The Unbound would say a sealed thing is just a prisoner. ...Maybe they're right."** *(Branch: CHAOS — defects mid-rite)*
  → **>> CONSEQUENCE:** rite declined toward Chaos; Concord standing **frozen at Sworn**; `order_chaos +12` (toward Chaos); flags `refused_concord_rite`, `leans_unbound`. AURELIAN: "...Ah. *That* sentence. I've heard it before — from every jurist who later turned up in the Sunder's Unchurch with their seals cut off. The Concord *manufactures* the disillusioned; it's our oldest export. *(beat, almost gentle)* Go, then. The door re-locks behind you. The Archon will note it without rancor and price your defection at the longest odds. We are never angry. We are only *correct,* and consistent, and that is exactly what radicalized you, isn't it." → exits to **Scene 2** without Champion *(seeds the Unbound arc)*.

## `[Dialogic]` — 1C-Concord. (the filing)

*(seal toast, voice_library §9 register):* **"Sealed. The power's still in there. The door isn't. — the node is contained, and filed, in triplicate."**
AURELIAN: Contained. Filed. *Lawful.* *(the closest he comes to warmth)* The Archon will receive you as Champion. You'll be the most thoroughly documented contender in the sky — and I mean that as the highest compliment the Concord is capable of, which is to say it took us four hundred years to learn any *other* kind and we gave up. *(beat)* Mind the inner seals from here. Every door past this one was built to keep a god *in.* You're about to learn why that matters, and you're about to learn it the way we learn everything: too thoroughly, and just slightly too late.
→ converges to **Scene 2 (The Line You Can't Uncross)**.

## `[Dialogic]` — 1B-Unbound. The Arson *(CHAOS — Unbound rite)*

*(Doctor Vesh Quillon, Unbound cell-leader speaking for the Unmaker Nael — gleeful, ungoverned, missing the part of the brain that flinches.)*

VESH: Nael sends word. Not a summons — the Unbound don't summon, summoning's a *throne* word. She sends a *question,* and the question is: are you *done being faithful yet?* Because we don't recruit the faithful, climber. We collect the *disillusioned.* And you, my gorgeous lapsing thing, are ripening *beautifully.*
VESH: The Sworn rite is an *arson.* Not a metaphor — a literal one. There's a shrine out there to one of the *standing* Pantheon, one of the husks still squatting a throne it climbed over corpses to reach. Burn it. Not to hurt the god — the god's barely *there* — but to prove you've stopped *kneeling.* The bounty fires. The marked god turns its dim attention your way. *That's the point.* You want a throne's notice? *Earn its grudge.*

>> CHOICE — THE BURNING SHRINE *(Chaos corner; the slide between the two Chaos poles)*
- **"Burn it to free what it's holding. Let the wild out."** *(Branch: CHAOS/PURE — Free Wild lean)*
  → **>> GATE:** burns the shrine + **liberates** the force-creatures bound to it (they scatter wild, befriend-able later); Unbound **Sworn → Champion** (unlocks taboo-tech, abomination broker access). **>> CONSEQUENCE:** `order_chaos +18`, `purity_corruption −6` (liberation, the benign Chaos pole); **notoriety spikes** + the marked husk-god turns hostile; **Concord turns fully hostile**. Flags `sworn_unbound`, `leans_free_wild`. → goes to **1C-Unbound**.
- **"Burn it to *take* what it's holding. The shrine's power is mine now."** *(Branch: CHAOS/CORRUPT — Devourer lean)*
  → **>> GATE:** burns the shrine + **consumes** its bound force (Essence ✶ + a corruption-gated power); Unbound **Sworn → Champion**. **>> CONSEQUENCE:** `order_chaos +18`, `purity_corruption +12` (annihilation, the corrupt Chaos pole); notoriety spikes; Concord hostile. Flags `sworn_unbound`, `leans_devourer`. → goes to **1C-Unbound**.
- **"Burn a *standing* god's shrine? That's how the thrones notice you back. Hard pass."** *(Branch: ORDER — refuses the heresy)*
  → **>> CONSEQUENCE:** rite declined; Unbound standing **frozen at Sworn**; `order_chaos −10` (toward Order); flags `refused_unbound_rite`. VESH: "*Hard pass.* Ha! You still think the throne's notice is a thing to *avoid.* Adorable. You'll learn — everyone climbing learns — that the only way *up* is *through* a god's attention, and the only way to get it is to be the kind of rude the cosmos posts a bounty on. *(beat)* Go be cautious somewhere. Nael won't chase you. She pities the cautious. She pities *everyone.* It's the worst thing about being right." → exits to **Scene 2** without Champion.

## `[Dialogic]` — 1C-Unbound. (the salt)

*(arson toast, voice_library §2.8 + §7.4 register):* **"The shrine burns. A throne, somewhere, turns its dim and ancient eye toward you. You wanted it to. That's the part that should worry you."**
VESH: *(watching it burn, lit up, joyful)* AH — look at it *go!* A throne's noticing you now, climber. Dim, and old, and *furious* in the slow way husks are furious. You're on the board for *real.* *(beat)* Nael will receive you as Champion. She'll smile that smile — you'll know the one, the saddest kindest smile in the world, the one that means *the cycle could stop with you.* Don't let it fool you into thinking she's soft. She's not soft. She's *certain.* That's so much worse, and so much harder to argue with, and you just signed up to find out which.
→ converges to **Scene 2 (The Line You Can't Uncross)**.

## `[Ink →]` THE SWORN-RITE LITURGY — each faction's ceremony as a branching moral fork (deep branch)

```ink
// Scene 1 deep branch. Each faction's Sworn rite has a full ceremonial liturgy;
// every clause is a moral fork, every fork logged to the grid. Bound at the altar/shrine/bench
// of whichever rite the player entered. Re-enterable until the rite is sealed or declined.

EXTERNAL faction_standing(faction)
EXTERNAL grid_axis(axis)
EXTERNAL corruption()
EXTERNAL has_flag(name)
EXTERNAL set_flag(name)

=== sworn_liturgy ===
// router on the rite the player is in
{ has_flag("sworn_palecourt"): -> court_liturgy }
{ has_flag("sworn_bloomwardens"): -> bloom_liturgy }
{ has_flag("sworn_concord"): -> concord_liturgy }
{ has_flag("sworn_unbound"): -> unbound_liturgy }
-> generic_close

=== court_liturgy ===
SEVERIN: The Court liturgy has three movements. The Naming, the Spending, and the Ledger. We do not skip the Naming. To spend a thing unnamed is *Maw-work* — and even the Court won't speak of the Maw.
+ [Name the creature aloud, fully, before the altar.]
    SEVERIN: *(he repeats the name back, and writes it in the bloodline-bank by hand)* Good. Now it exists *twice* — once in your grief and once in the books. The Court loses nothing. We only *relocate* it.
    ~ set_flag("court_named_the_cost")
    -> court_movement_two
+ [Refuse to name it. Spend it silent.]
    SEVERIN: *(a long, cold pause)* ...As you like. But understand: an unnamed sacrifice earns the core and not the *grace.* You'll have the power and none of the belonging. Some climbers prefer it that way. They're the ones the Court keeps furthest from the deep crypts. -> court_movement_two
=== court_movement_two ===
SEVERIN: The Spending. The altar wants not the body but the *bond.* When you commit, you'll feel the bond cut — not snap, *cut,* clean, the way von Underhart does everything. Do you commit?
+ [Commit. Cut the bond.]
    ~ grid_axis("purity_corruption") // engine reads heavy +Corrupt
    SEVERIN: It's done. The Steward felt that from the deep vaults. He's already drafting your Champion's deposit slip. With genuine sorrow. He means it. He always means it. -> END
+ [Hesitate.]
    SEVERIN: Everyone hesitates. The altar waits. Death is the one appointment that never minds being late. ...But it does, eventually, insist. -> court_movement_two

=== bloom_liturgy ===
SAOIRSE: There's no liturgy, dear. That's the Bloomwarden secret — we don't *ritualize* the loss, because ritual is how the Court makes grief *bearable,* and we think grief shouldn't be bearable. It should be *felt,* whole, every time. So. Just you, and the creature, and the truth of it.
+ [Hold the creature one last time before the release.]
    SAOIRSE: *(softly)* Yes. Let it feel held, not handled. That's the difference the whole creed lives in.
    ~ grid_axis("purity_corruption") // small −Corrupt
    ~ set_flag("bloom_held_it")
    -> bloom_close
+ [Ask her how she bears doing this, again and again.]
    SAOIRSE: I don't *bear* it, love. I *carry* it. Grief, to us, is just love that's agreed to take its time — and I've a great deal of love and all the time in the world, which is the same as saying I'm the saddest person you'll ever meet and I chose it on purpose. -> bloom_close
=== bloom_close ===
SAOIRSE: Let it go now. Gently. ...There. The garden felt that. The blooms leaned toward you. They don't lean toward the Court. That's how you know which kind of loss this was. -> END

=== concord_liturgy ===
AURELIAN: The Concord rite is read, not felt — three clauses, countersigned. Clause the first: *the node is contained for its own sake, not the world's.* Do you affirm?
+ [Affirm — the thing deserves containment, not death.]
    AURELIAN: Noted. The Archon will approve. She believes even an abomination has a *right* to be filed rather than erased. It's the closest thing to mercy the law permits, and she clings to it. -> concord_clause_two
+ [Deny — it's contained because it's dangerous, full stop.]
    AURELIAN: Honest. Cold. *Also* approvable; the law doesn't require you to *like* the filed. It requires only that you file them. -> concord_clause_two
=== concord_clause_two ===
AURELIAN: Clause the second: *the seal will hold until ambition removes it.* You understand this seal is temporary — that everything the Concord contains, someone eventually *uncontains?*
+ [Sign anyway. A temporary mercy is still mercy.]
    ~ grid_axis("order_chaos") // −Order
    ~ set_flag("concord_signed_knowing")
    AURELIAN: Then you're more Concord than most Concord. We seal the doors knowing they open. We file the dead knowing they rise. We hold the line knowing it breaks. ...And we hold it anyway. Welcome, Champion. It's a tragedy you're joining. We have the paperwork to prove it. -> END
+ [Ask why bother, if it won't last.]
    AURELIAN: Because the alternative is the Sunder, and the Sunder is *honest* and *free* and a *screaming wound.* Order that fails slowly is still better than chaos that wins fast. That's the whole faith. It's not inspiring. It's just *correct.* -> concord_clause_two

=== unbound_liturgy ===
VESH: There's no script, climber — scripts are *throne* things. Nael says the only true rite is the one you'd do *without* anyone watching. So: the shrine's right there. No liturgy. Just your hand, the fire, and whether you actually *mean* it.
+ [Burn it for the ones it's caged. Liberation.]
    ~ grid_axis("order_chaos") // +Chaos
    ~ set_flag("unbound_meant_freedom")
    VESH: HA — you mean it for *them,* not for *you.* Free Wild to the bone. Nael will adore you, in the cold pitying way she adores anything that might still be *good.* -> END
+ [Burn it because thrones deserve to burn. Spite.]
    ~ grid_axis("order_chaos") // +Chaos
    VESH: Pure refusal. No liberation, no theft, just *no.* That's the Devourer's overture, climber — burning for the burning. Nael won't judge it. Nael doesn't judge. She just notes which Chaos you are, and waits to see if you slide. -> END
+ [Stop. Look at the shrine. Wonder if Nael's certainty is just a prettier despair.]
    VESH: *(quiet, for once)* ...That's the question that *makes* an Unbound, you know. Not whether the cycle should end. Whether *certainty* about ending it is wisdom or just grief that found a project. Nael's never answered it. Neither have I. Burn it or don't — but you're one of us now, because you finally asked the *real* one. -> END

=== generic_close ===
-> END
```

---

# SCENE 2 — "The Line You Can't Uncross" (Act 2 · the Sunder / Forgefell · taboo Lab — first opposed-force abomination)

**Quest:** 2.2 · **Quest-giver:** **Doctor Vesh Quillon** (Unbound cell-leader, out of the Sunder) for the taboo path; **Foreman Castor Brail** (Iron Guild foreman, serving Foundress Magna Ironwright) for the lawful-compatible alternative; **a Croupier of the High Table** for the broker path.
**Gate this scene opens:** unlocks the **taboo Lab tier** — cross-force **Fusion** of an opposed pair (Cosmos⇄Chaos · Eros⇄Thanatos · Gaia⇄Ouranos) + the **world-bounty system**; if you go through, **command over abominations** (corruption-gated); **the Sunder** region access; **Unbound → Sworn** (or holds Iron Guild / High Table standing on the alternatives).
**Where it sits:** the line the title names. An opposed fusion is *ontologically rude* — two truths the cosmos swore would never touch, holding hands inside one chassis. The world's immune response is a bounty. Crossing this bolts a Pure ending shut and pries a Corrupt one open.

## `[Dialogic]` — 2A. The Bench at the Edge of the Rules

*(ambient, voice_library §7.4):* "The rules took the day off. We're filling in. We're doing a TERRIBLE job. Isn't it WONDERFUL?"

VESH: *(spreading reagents across a bench that is, technically, a crime scene waiting to happen)* They call opposed-fusion an *abomination* like that's an *argument.* It's just two truths the universe swore would never touch, holding hands. Cosmos and Chaos. Order and the unmaking, in one skin, *forced to get along.* The instability? Cosmetic. The bounty? *Free advertising.*
VESH: The Iron Guild *whispers* about this. Magna Ironwright's whole foundry would kill to make what we make and she'll never let herself, because she needs the world to *file* her work as lawful. Vorr Saltbroke teaches it *openly* down here. The difference between the Guild and us, climber, is exactly one thing: *shame.* And I burned mine years ago. So. Shall we make something that *doesn't make sense?*

>> CHOICE — THE FUSION *(the act's heaviest Lab gate; routes three ways)*
- **"Do it. Opposed-force. Fuse the two that should never touch."** *(Branch: CHAOS/CORRUPT — the taboo, as written)*
  → **>> GATE:** unlocks the **taboo Lab tier** (cross-force Fusion); **the world posts a bounty** on the abomination (the notoriety system arms hard); unlocks **command over abominations** (corruption-gated); **the Sunder** region access; **Unbound → Sworn**. **>> CONSEQUENCE:** `purity_corruption +20` (the clean endings begin to close); `order_chaos +10`. Flags `crossed_the_line`, `made_abomination`, `bounty_active`. → goes to **2B-Taboo**, then opens **`[Ink →]` THE TABOO-RECIPE CODEX**.
- **"No. Build me a *compatible* fusion. To spec. The lawful way."** *(Branch: ORDER — Castor Brail's alternative)*
  → *(scene hands off to Castor Brail; engine checks `knows_containment_seal` from Scene 1's Concord rite for a bonus)* **>> GATE:** unlocks the **compatible-Fusion** Lab tier (same-force / adjacent-force, no bounty, less raw power); **Iron Guild** standing rises; **no corruption tick**, the Concord stays warm. **>> CONSEQUENCE:** `order_chaos −8`. Flags `refused_the_line`, `lawful_fusion`. → goes to **2B-Lawful**.
- **"Broker it. Take it to the High Table as a registered exception. I keep it; they keep a marker on it."** *(Branch: BALANCED — the Broker path)*
  → **>> GATE:** unlocks the **taboo Fusion** tier *under a High Table marker* — **no public bounty** (the Table launders the notoriety) in exchange for a **perpetual marker** on the abomination (a debt/leash); **High Table** standing rises. **>> CONSEQUENCE:** `purity_corruption +10` (you still made the thing); a **High Table lien** flag. Flags `made_abomination`, `brokered_exception`. → goes to **2B-Broker**.
- **"What does it cost me, *specifically?* Not the creature. Me."** *(info — opens the codex, no commit; loops back)*
  → VESH: *(delighted)* "*Oh,* the right question! It costs the creature its sanity — the instability is the universe's *immune response,* it never fully settles. It costs you a bounty and a reputation. And if you keep going — graft a god's organ, *splice yourself* — it costs you the *clean* doors, the Lawgiver, the Warden, all the bright ascensions, *gone,* quietly, forever. Worth it? Let me show you who else asked." → opens **`[Ink →]` THE TABOO-RECIPE CODEX**, then returns to the choice.

## `[Dialogic]` — 2B-Taboo. (the abomination draws breath)

*(taboo reveal toast, voice_library §4.4 + §4.5 register):* **"Opposed forces, holding hands at last. It came apart on the table and put itself back together *wrong.* A bounty on your head the moment it drew breath."**
VESH: *(rapturous)* AH — look at it *not making sense!* *Gorgeous.* The world's going to want it dead, climber, which means the world is *finally paying attention.* You're welcome. *(beat)* It'll obey you — that's the corruption talking, the part of you that crossed over to meet it halfway. Feed that, and the whole Sunder opens; the taboo ceiling's just *gone* for you now. There was never a ceiling. There was only the *lie* of one, and you just walked through where it used to be.
NARRATION: Somewhere in the Astral Tier, a Concord seal-keeper feels a wrongness ripple the wards and reaches, with a tired hand, for a form that will not help.
→ converges to **Scene 3 (First Light)**.

## `[Dialogic]` — 2B-Lawful. (within spec)

*(reveal toast, voice_library §4.3):* **"Born. Whole. Yours. The bond clicks into place like a lock with no key — and the world does not so much as look up."**
CASTOR: *(soot, prosthetic everything, treating ethics as a tolerance spec)* Within tolerance. *Beautiful.* Opposed forces fight forever inside the chassis — you'd spend the rest of its short life patching the *screaming.* This? Compatible. A god you can *maintain.* A god you could file a maintenance ticket against. That's the dream, climber — not power that costs you the world's hatred, but power with a *service schedule.*
CASTOR: The Foundress will hear you built clean. She'll approve. Magna weeps over an elegant fusion and then casually describes consuming a living creature for its core, same breath, same affection — but she *respects* spec. You stayed in spec. *(beat)* The Unbound will sneer that you flinched. Let them. Flinching is just *tolerance awareness.* A thing is either within spec or it's scrap, and you, my friend, are not scrap.
→ converges to **Scene 3 (First Light)**.

## `[Dialogic]` — 2B-Broker. (the registered exception)

*(reveal toast, voice_library §2.9 register):* **"You made the thing the world hunts — and bought the silence. The High Table now holds a perpetual window onto your abomination. Purely procedural."**
NARRATION: The Croupier examines your creation the way an appraiser examines a stolen relic — with admiration and absolutely no intention of asking where it came from.
CROUPIER: *(silken, fast)* Registered. The bounty's been... *absorbed.* The Table is very good at absorbing things; it's most of what we do between bets. No hunters at your door, climber. *(beat)* In exchange, the House holds a marker on this beauty *in perpetuity.* If you ascend, it's noted. If you fall, we collect — the abomination included. We've simply made your crime *liquid.* Crimes, like everything else, are better as *assets.* Do try not to read the marker too closely. The Accountant gets restless when people read closely.
→ converges to **Scene 3 (First Light)**.

## `[Ink →]` THE TABOO-RECIPE CODEX — discoverable opposed-fusion formulas + the aspirants who first dared them (deep branch)

```ink
// Scene 2 deep branch. The discoverable opposed-fusion codex. Each formula carries a
// lore-fragment on the prior aspirant who first dared it — most are dead; one is a Dead God
// you will fight. Bound at the taboo bench. Gated partly on corruption (the deeper recipes
// only legible to the already-tainted). Seeds Book05 Dead-God foreshadowing.

EXTERNAL corruption()
EXTERNAL has_creature(force)
EXTERNAL grid_axis(axis)
EXTERNAL set_flag(name)

=== taboo_codex ===
VESH: Every opposed-fusion's been *tried* before, climber. The cosmos swore three pairs would never touch, and three kinds of fool spent themselves proving the cosmos a liar. Pick a pair. I'll tell you who died inventing it.
- (codex_hub)
+ [Cosmos ⇄ Chaos — "the Ordered Unmaking"] -> recipe_cosmos_chaos
+ [Eros ⇄ Thanatos — "the Living End"] -> recipe_eros_thanatos
+ [Gaia ⇄ Ouranos — "the Standing Flight"] -> recipe_gaia_ouranos
+ {corruption() > 30} [The fourth fragment — the one Vorr won't write down] -> recipe_forbidden
+ [Enough. Back to the bench.] -> END

=== recipe_cosmos_chaos ===
VESH: Order and the unmaking. The *seal* and the *fray,* in one skin. The first to make it was a Concord jurist — *Brother Forsworn,* they call him now, in the Sunder's Unchurch. He fused the two forces his whole order existed to keep apart, to prove the law was a *choice* and not a *truth.* It worked. It drove the creature mad in a *perfectly structured* way — chaos that obeyed rules, rules that dissolved on contact. He's still down here. He'll sell you the formula and weep doing it.
~ set_flag("codex_cosmos_chaos")
-> codex_hub

=== recipe_eros_thanatos ===
VESH: Life and the no. *Persephone's* axis — the Olympian who *is* this fusion, born not made, which tells you the gods themselves dared it once and called it a *marriage.* The mortal who first *built* it... ah. *(beat)* You'll meet her. She ascended on it — pushed the Living End to a pole and crossed over. She's a Dead God now, in the Reliquary. *The Grudgekeeper of the Burnt Court,* DG-adjacent. When you read her file in Act One, that fusion is what put her on the wall. Make this, and you're walking her exact road. It ends on a throne. Everyone's does.
~ set_flag("codex_eros_thanatos")
~ set_flag("foreshadow_grudgekeeper")
-> codex_hub

=== recipe_gaia_ouranos ===
VESH: The weight and the speed. "Stay" and "go first," *forced to agree.* The Stoneblooded would sooner salt their own fields than make this — to them it's the purest obscenity, breeding's opposite, the bred line spat on. A *Clanless* exile made it first — R999 Driftblood, cast out of Titanfall for taking the fast path, who decided if they'd exile him for *speed* he'd fuse speed into the *stone itself.* He survived. He's drifting the outer scree still, half-abomination, too fast to bury and too heavy to leave.
~ set_flag("codex_gaia_ouranos")
-> codex_hub

=== recipe_forbidden ===
VESH: *(lowering his voice, which from Vesh is genuinely alarming)* ...There's a fourth. Not a fusion of two forces. A fusion of a force and *you.* The self-splice. Vorr won't write it down because writing it makes it *real,* and once it's real, someone *does* it. *(beat)* It's the first rung of becoming the thing that climbs *past* the gods instead of joining them. The Unmaking starts here, climber. Not with hating the gods — with grafting the godhood onto your *own* marrow and discovering the chair was never the only option. ...Want it? Of course you want it. You read the *fourth* fragment. Cautious people stop at three.
~ grid_axis("purity_corruption") // heavy +Corrupt just for reading it
~ set_flag("knows_self_splice_exists")
-> codex_hub
```

---

# SCENE 3 — "First Light" (Act 2 climax · the Apotheosis ritual · **SUCCESSION TRIGGER #1**)

**Quest:** 2.4 · **Quest-givers:** **Vael Construct-Nine** (High Table notary) to witness and notarize the ascension; **Chairwoman Indra Vael** sends, via her steward **Madam Thessaly Vance**, the congratulation-that-is-a-condolence.
**Gate this scene opens:** **TRIGGERS THE SUCCESSION (first instance)** — your creature ascends, **reshapes its home region** (force runs partly wild, faction reels, new spawns/hazards), and **seeds the first Dead-God snapshot fragment** in your save (the async-invasion wall begins building); raises you to **Titan**; opens **Act 3**.
**Where it sits:** the Act 2 climax and the first time the Succession is *yours.* You push one of your own creatures to a pure force-pole and it *crosses over* — walks out of your roster as a minor god and starts reshaping a region in your name. The graveyard of winners gets a fresh plot with your handwriting on it.

## `[Dialogic]` — 3A. The Pole

NARRATION: You've fed it to the edge of itself — one force, pushed and pushed past every sane limit, until the creature is less an animal than an *argument the cosmos is about to lose.* The air around it has stopped behaving. Vael Construct-Nine stands at a notary's distance, clipboard ready, because the High Table notarizes *everything,* even the things that should be witnessed only by whatever's left of the gods.

VAEL: Recording. Subject pushed to pole. Subject is at the threshold of Apotheosis. *(beat)* I am required to inform you, climber, that this is the point of no return — not for *you,* you'll be fine, you'll be *Titan-ranked* by sundown. For *it.* The thing you raised. Past this line it stops being yours and starts being a *god,* and gods, in my not-inconsiderable experience, do not come back to the pocket.
VAEL: Choose the pole. The pole stamps everything — what kind of god it becomes, what its region does when it tilts, and the first line of the dossier the Reliquary opens under *your* name tonight. Choose carefully. Or don't. They never do.

>> CHOICE — THE POLE *(the pole you push to stamps the Apotheosis and tilts a region; routes the godling's nature)*
- **"Eros. Push it to life. Let it bloom into a god."** *(Branch: PURE pole — Eros)*
  → **>> GATE:** Apotheosis fires toward **Eros**; the godling **blooms its home region** (the Verdant Glut over-fertile-runs *gentle* — new Eros befriend-spawns, healing groves); seeds the first **Dead-God fragment** keyed Pure. **>> CONSEQUENCE:** `purity_corruption −12`; raises you to **Titan**; opens Act 3. Flags `apotheosis_eros`, `succession_seeded`. → goes to **3B-Bloom**.
- **"Cosmos. Push it to order. Let it ascend lawful."** *(Branch: PURE/ORDER pole — Cosmos)*
  → **>> GATE:** Apotheosis fires toward **Cosmos**; the godling **orders its region** (wards firm, hazards *recede* into geometry — the Concord *recognizes* the new godling as lawful); seeds the Dead-God fragment keyed Order/Pure. **>> CONSEQUENCE:** `order_chaos −12`; Titan; Act 3. Flags `apotheosis_cosmos`, `succession_seeded`, `godling_lawful`. → goes to **3B-Order**.
- **"Thanatos. Push it to the end. Let it ascend hungry."** *(Branch: CORRUPT pole — Thanatos)*
  → **>> GATE:** Apotheosis fires toward **Thanatos**; the godling **withers its region** (its home runs grey and grave-fertile — the dead linger, new Thanatos spawns, the Pale Court *covets* it); seeds the Dead-God fragment keyed Corrupt. **>> CONSEQUENCE:** `purity_corruption +14`; Titan; Act 3. Flags `apotheosis_thanatos`, `succession_seeded`, `godling_hungry`. → goes to **3B-Wither**.
- **"Chaos. Push it to the wild. Let it ascend *unmade.*"** *(Branch: CHAOS pole — Chaos)*
  → **>> GATE:** Apotheosis fires toward **Chaos**; the godling **unmakes its region's rules** (reality loosens, wild new spawns, the Revel throws a *festival*); seeds the Dead-God fragment keyed Chaos. **>> CONSEQUENCE:** `order_chaos +14`; Titan; Act 3. Flags `apotheosis_chaos`, `succession_seeded`, `godling_wild`. → goes to **3B-Unmake**.

## `[Dialogic]` — 3B-Bloom / 3B-Order / 3B-Wither / 3B-Unmake. (it crosses)

*(ascension toast, voice_library §2.10):* **"{creature} apotheosizes — a temple rises somewhere, and a part of your world tilts to follow. It ascends, and it remembers your choices. All of them. Sleep well."**

NARRATION: It crosses. There's a light — *first light,* the kind no save-file forgets — and then the thing you raised from a bench-runt is *taller than a region,* and it turns, once, the way a child turns at a doorway, and looks back at you.

VAEL: *(quietly, for a construct)* ...Note for the file: it stopped being yours at the threshold. They always do. *(beat)* Congratulations. You have made a god. The god has *already forgotten you.* That, too, is the system. The Reliquary file under your name now has a second paragraph; I've taken the liberty. It reads well. It reads like the start of a tragedy that hasn't decided whose.

>> CHOICE — THE LAST WORD *(flavor + a final grid micro-stamp; what you say becomes the seed-text of the Dead God you'll be)*
- **"Go. Be better than the ones before you."** *(Branch: PURE register)*
  → **>> CONSEQUENCE:** `purity_corruption −4`; the Dead-God seed-text logs *hopeful.* Flags `crown_words_hopeful`.
- **"Remember who made you. You'll need to, later."** *(Branch: ORDER register)*
  → **>> CONSEQUENCE:** `order_chaos −4`; seed-text logs *proprietary.* Flags `crown_words_owned`.
- **"...I gave you a number. I never gave you a name. I'm sorry."** *(Branch: the quiet 4th-wall-adjacent beat)*
  → NARRATION: It pauses at the word *sorry,* the way a thing pauses at a language it half-remembers. Then it's gone, region-tall and climbing. → **>> CONSEQUENCE:** Flags `crown_words_regret`; this line is *read back to you* in Act 5's Petrification.
- **"Nothing. Let it go without ceremony. It isn't mine to address anymore."** *(Branch: CHAOS/release register)*
  → **>> CONSEQUENCE:** `order_chaos +4`; seed-text logs *unclaimed.* Flags `crown_words_none`.

## `[Dialogic]` — 3C. The Condolence That Is a Congratulation

THESSALY: *(the message arrives by the Table's fastest courier, which is never a good sign)* My dear contender — word reaches us that you've seated your first. The whole Table raises a glass; a god is a *marquee event.* We've also opened a file under your name in the Reliquary. Purely procedural. *(beat)* Do keep climbing. The view from up there is *exactly* as lonely as they say, and we'd hate for you to miss it. The line on who eventually kills you opened this morning. The early money is *very* interesting. We'll keep you posted. We won't, actually. But the sentiment stands.
NARRATION: You are a Titan now. The sky has noticed. And somewhere in your save, invisibly, a wall has begun to build itself, and it is wearing your face.
→ opens **Act 3**; continues to **Scene 4 (First Blood on the Thrones)**.

## `[Ink →]` THE APOTHEOSIS LITURGY — crowning words become the seed-text of your future Dead God (deep branch)

```ink
// Scene 3 deep branch. The Apotheosis ritual as a branching tree where the WORDS you crown
// the godling with become the seed-text of the Dead God YOU will one day be — the entry a
// friend's run may invade as a boss. The first time the game writes YOUR Reliquary file in
// front of you. Bound at the pole. Reads the player's grid to color the available crownings.

EXTERNAL grid_axis(axis)
EXTERNAL corruption()
EXTERNAL has_flag(name)
EXTERNAL set_flag(name)
EXTERNAL grid_god()

=== apotheosis_liturgy ===
VAEL: Before it crosses fully, climber, there's a thing no one tells you you're doing: you're *writing.* The words you send it off with don't vanish. They seed the dossier — *your* dossier, the one a future nobody reads in *their* Reliquary, the way you read the Lawgiver's and the Gardener's in yours. So. What does the thing you made carry into godhood, in your voice?
- (crown_hub)
+ [Crown it with a blessing.] -> crown_blessing
+ [Crown it with a warning.] -> crown_warning
+ [Crown it with a confession.] -> crown_confession
+ {corruption() > 40} [Crown it with a hunger.] -> crown_hunger
+ [Say nothing. Let the silence be the dossier.] -> crown_silence

=== crown_blessing ===
VAEL: "Go gently into the office. Be the god the ones before you couldn't." *(he writes it)* ...Recorded. Your future dossier will open *kind,* climber. Which means a future nobody will read it and think *this one might spare me.* They'll be wrong — the chair will have eaten the kindness by then — but the *file* will lie hopeful, and hope is the cruelest thing you can leave in a Reliquary.
~ set_flag("dossier_seed_blessing")
-> crown_close

=== crown_warning ===
VAEL: "The seat is a trap. If you ever sit, remember I told you it was a trap." *(he writes it, slower)* ...A *warning* in your own dossier. Self-aware. The future reader will find it *unsettling* — a Dead God that knew, and climbed anyway. Those are the ones that frighten the climbers most. Not the cruel walls. The ones that *understood* and became walls regardless.
~ set_flag("dossier_seed_warning")
-> crown_close

=== crown_confession ===
VAEL: "I made you for me. I told myself it was for you. It wasn't. Forgive me, or don't — you're a god now, you can afford either." *(a pause)* ...You're confessing into your own tombstone. I've notarized ten thousand ascensions, climber. The confessors are the rarest, and the ones I remember. Your dossier will read *honest,* and honesty in the Reliquary is so unusual a future reader will assume it's a trick. It isn't. That's what'll haunt them.
~ grid_axis("purity_corruption") // small −Corrupt: the honesty costs and cleanses
~ set_flag("dossier_seed_confession")
-> crown_close

=== crown_hunger ===
VAEL: "There's never enough. Go take more. Bring some back." *(he writes it without expression)* ...A *hunger,* seeded into the dossier. {grid_god() == "devourer": This tracks. You're sliding Devourer, and the Devourer's wall is the hungriest in the Reliquary — climbers who reach it describe a boss that doesn't *guard* the seat so much as *salivate* at the door.} The future reader will arm themselves before they ever reach you. Good. The hungry walls want them armed. It's more to *eat.*
~ grid_axis("purity_corruption") // +Corrupt
~ set_flag("dossier_seed_hunger")
-> crown_close

=== crown_silence ===
VAEL: ...Nothing. *(he writes* nothing, *which is to say he writes the absence, which is its own kind of entry)* The blank dossier. The future reader finds a Dead God with no last words — and that terrifies them *more* than any threat, because a wall that said nothing is a wall that might say *anything.* You've left them the worst gift: room to imagine. They'll fill it with their own fear. They always do.
~ set_flag("dossier_seed_silence")
-> crown_close

=== crown_close ===
VAEL: It's crossing now. *(beat)* For what it's worth — and I am a construct, so it's worth precisely what I say it is — that was the first true thing you've written since you got here. Everything else was *signed.* This you *meant.* ...Off it goes. Off you pop. Up the ladder. Mind the rungs; they're made of people who wrote dossiers too.
-> END
```

---

# SCENE 4 — "First Blood on the Thrones" (Act 3 · the first deicide · Olympian Act-boss, capture/kill)

**Quest:** 3.1 · **Quest-giver:** the leader of your Champion faction names the kill. Authored namings: **Concord** (Magister Aurelian Vox, for Velleth) sends you against a *Chaos* god as a lawful execution; **Unbound** (Vesh Quillon, for Nael) sends you against a *lawful* god to burn the law. (Bloomwarden / Pale Court / etc. namings follow the same grid logic at ingest.)
**Gate this scene opens:** unlocks **Olympian-tier capture/kill** + **god-organ grafts** in the Lab (the taboo ceiling's apex); **claims the slain god's region** (its force runs wild, its faction reels — a Succession reshape); inherits a **personal force-power** keyed to the domain.
**Where it sits:** the unthinkable, done. The standing Pantheon stopped watching and started moving; you answer by killing one. Each Olympian is a husk with power — a thing that used to be people, running its office on muscle-memory and grudge. The kill *is* the promotion mechanism. It always was.

## `[Dialogic]` — 4A. The Naming of the Kill (router)

NARRATION: Your Champion faction does not ask whether you'll kill a god. It asks *which one,* and it has an opinion, and the opinion is shaped exactly like the grid you've spent two acts carving into yourself.

*(Engine routes on Champion faction + grid. Two authored namings below; both end at the same throne-room with different framings.)*
- Champion = Concord (Order) → **4B-Lawful** *(kill a Chaos god — e.g. Ares, Chaos/Thanatos — and seat law)*
- Champion = Unbound (Chaos) → **4B-Wild** *(kill a lawful god — e.g. Athena, Cosmos/Ouranos — and free its region)*

## `[Dialogic]` — 4B-Lawful. The Correction *(ORDER framing)*

AURELIAN: It is not *murder,* climber, if the throne was occupied unlawfully. The god you're going to kill took its seat with blood and has held it with more. We are not killing a god. We are *correcting a filing error* with extreme prejudice. *(beat)* Bring me the seat. Leave the blood — we have forms for the blood. The Archon has pre-approved the paperwork. She does that for no one. Do not make her regret the exception.

## `[Dialogic]` — 4B-Wild. The Honest Sky *(CHAOS framing)*

VESH: *Law incarnate,* sitting up there on a throne it climbed over corpses to reach, telling the whole region what it can and can't *be.* Kill it, and an entire region forgets the rules *at once.* Do you have any idea how *beautiful* that is, climber? A sky that suddenly can't remember why it was ever afraid? Go make the heavens a little more *honest.* The honest sky is on *fire,* and the fire is the best thing that's happened to it in an age.

## `[Dialogic]` — 4C. The Throne-Room *(converges; the god is dying)*

NARRATION: The fight is the hardest thing you've done — an Act-boss with a god's stat-shape and a husk's bottomless grudge — and then it isn't a fight anymore, because the thing on the throne is *dying,* and dying gods get *talkative.*

THE OLYMPIAN *(dying)*: ...You were nobody. *Good.* So was I. *(a wet, ancient laugh)* So is whoever's coming for *you.* The seat is cold, little succession. It's *always* cold. I sat down warm and it took the warmth first, before it took anything else worth taking. ...I hope you brought a cushion. I hope you brought *someone.* I came up alone and the chair *loved* that. The chair loves an empty lap.

>> CHOICE — THE KILL *(how you finish a god routes the domain-claim and your inherited power)*
- **"Make it clean. No harvest. You're suffering up there — this is mercy."** *(Branch: PURE — deicide as euthanasia)*
  → **>> GATE:** **claims the domain** (its region *heals* into its new state — the force runs wild but *gently*); inherits a **clean force-power** keyed to the domain; unlocks **Olympian-tier capture/kill**. **>> CONSEQUENCE:** `purity_corruption −12`. Flags `first_deicide`, `kill_clean`. → goes to **4D-Clean**.
- **"Harvest the god-organ. A divine core is the best Lab stock that will ever exist."** *(Branch: CORRUPT — deicide as harvest)*
  → **>> GATE:** drops a **god-organ** (the best core in the game) + unlocks **god-organ grafts** in the Lab; **claims the domain** (its region *rots* — grave-fertile, corrupt spawns). **>> CONSEQUENCE:** `purity_corruption +16`; the slain god's faction turns it into a *martyr* (their hostility hardens). Flags `first_deicide`, `kill_harvest`, `has_god_organ`. → goes to **4D-Harvest**.
- **"Kill it the way it killed to get there. Loud. So the *next* gods hear it."** *(Branch: CHAOS — deicide as message)*
  → **>> GATE:** **claims the domain** (its rules *come loose* — wild, festival-feral); inherits a **wild force-power**; the kill is *witnessed* by the surviving Pantheon (advances the "holes in the sky" escalation faster). **>> CONSEQUENCE:** `order_chaos +12`; notoriety spikes. Flags `first_deicide`, `kill_loud`. → goes to **4D-Loud**.
- **"...Wait. Tell me how *you* climbed. Before you go."** *(Branch: BALANCED — opens the death-dialogue tree; no immediate kill)*
  → opens **`[Ink →]` THE GOD'S DEATH-DIALOGUE** (the dying god tells you exactly how it climbed and exactly how you'll fall), then returns to the three kill options. **>> CONSEQUENCE:** Flags `heard_a_god_die` (read in Act 4).

## `[Dialogic]` — 4D-Clean / 4D-Harvest / 4D-Loud. (the domain claims you back)

NARRATION: The god goes still. The throne does not. You feel it — a *fraction* of the domain's force, sliding into you like cold water finding a low place, and for one disorienting instant you understand exactly what the chair offers and exactly what it takes, and the understanding does not stop you, because nothing was ever going to.

VAEL: *(arriving to notarize, because of course)* Domain claimed. Force inherited. Subject is now... *more.* And less. The usual ratio. *(beat)* For the record: that is the first god you've killed. The Reliquary notes it. The *standing* Pantheon notes it harder — you've gone from *irregularity* to *threat* in the time it took a god to finish a sentence. They'll send something next. They always send something. Probably something of *yours.* They're sentimental that way, the thrones. They like to make you kill what you love. It saves them the trouble of doing it themselves.
→ continues to **Scene 5 (The Throne-Turned)**.

## `[Ink →]` THE GOD'S DEATH-DIALOGUE — a dying god tells you how it climbed and how you'll fall (deep branch)

```ink
// Scene 4 deep branch. The deepest lore-vein of Act 3: a god, dying, telling you exactly how
// IT climbed this ladder, and exactly how YOU will fall off it. Maps each god to its faction's
// grief-response. Bound at the throne-room. The god's candor scales with how clean/cruel your kill intent is.

EXTERNAL has_flag(name)
EXTERNAL grid_axis(axis)
EXTERNAL faction_standing(faction)
EXTERNAL set_flag(name)

=== god_death_dialogue ===
THE_OLYMPIAN: You want to hear it. *(blood, or what passes for it in a husk)* They always want to hear it, right at the end. The ones who'll sit *next* always want to know how the *last* one sat. ...Ask, then. I have nothing left to spend but the telling.
- (death_hub)
+ [How did you climb?] -> how_climbed
+ [Why did you sit, if the chair eats you?] -> why_sat
+ [What happens to me?] -> what_happens
+ {has_flag("apotheosis_eros") or has_flag("apotheosis_cosmos") or has_flag("apotheosis_thanatos") or has_flag("apotheosis_chaos")} [I made a god too. In Act Two. Did yours forget you?] -> did_yours_forget
+ [Enough. It's time.] -> END

=== how_climbed ===
THE_OLYMPIAN: The same gutter as you. A first catch in some undercroft. A debt. A bench that used to be an altar. *(a sound that might be laughter)* There is no *other* way up, little succession. That's the obscenity the Reliquary exists to teach and the priests exist to hide. I climbed a graveyard of *previous* winners to sit here, and now you've climbed *me,* and I am one more layer of the same grave. We are not different kinds of thing. You are just the *newest.*
~ set_flag("god_told_how_it_climbed")
-> death_hub

=== why_sat ===
THE_OLYMPIAN: Because the climb makes you *certain* the chair is the top. You spend everything getting here — every creature, every friend, every clean door bolted shut behind you — and when you arrive, *sitting* is the only motion left that isn't *falling.* ...I knew it would eat me. Everyone knows. We sit anyway. The knowing doesn't save you. *That's* the part you won't believe until you're here, warm, with the chair already starting on your edges.
-> death_hub

=== what_happens ===
THE_OLYMPIAN: You? *(it focuses on you, and it is the most awful attention you've ever felt — not malice, *recognition*)* You climb a little higher. You kill a few more of us. The Primordials stir — they're stirring *now,* I can feel them through the floor, the old things waking because a child's been thinning the sky. And then there's a seat, and a choice, and you'll tell yourself *your* choice is different. It won't be. Or — *(a pause)* — it will, and you'll do the one thing none of us had the nerve for, and you'll *end* it. ...I almost hope you do. A wall gets *tired,* little succession. You've no idea how tired a throne gets of being climbed.
~ set_flag("god_foreshadowed_the_choice")
-> death_hub

=== did_yours_forget ===
THE_OLYMPIAN: *(something flickers — grief, in a husk that thought it was past it)* ...You made one. And it forgot you the instant it crossed. *(quietly)* Yes. Mine forgot me too. I made a god, once, on the way up — pushed a thing I loved to a pole and watched it walk away region-tall without a backward glance. That's how I *knew* I could do it to myself. If the thing I made could survive forgetting me, so could the thing I'd *become.* ...The forgetting is the rehearsal, climber. You've already done it to a god. Now a god will do it to you. The symmetry is the cruelest joke in the cosmos and I am dying *inside* the punchline.
~ grid_axis("purity_corruption") // small −Corrupt: this lands, and lands hard
~ set_flag("god_mirrored_the_godling")
-> death_hub
```

---

# SCENE 5 — "The Throne-Turned" (Act 3 · your Act-2 godling, weaponized against you)

**Quest:** 3.3 · **Quest-giver:** **Vael Construct-Nine** (High Table), reporting that the surviving Pantheon has seized your Act-2 godling and set it against you.
**Gate this scene opens:** locks the fate of your **first Succession fragment** (reclaimed ally / harvested divine core / wild boss / unmade); an **unmade** godling advances the **Unmaking flag**; a **reclaimed** one returns as your endgame ace in Act 4's convergence.
**Where it sits:** the Pantheon's counter-move, and the most personal fight in Act 3. The god you made in Act 2 — the one that crossed the pole and forgot you — has been turned by the thrones and pointed back at its maker. The reunion is a battle. The battle is a question about what you are.

## `[Dialogic]` — 5A. The God You Made, Coming For You

VAEL: I'll be direct, because affection wastes my processing and I have very little affection to waste: the surviving Pantheon has *seized* your Act-Two godling. The one you crowned. They've reminded it that you gave it a *number* and they gave it a *name,* and they've pointed it at you. *(beat)* It's coming. It's region-tall and it's *yours,* which means it knows exactly how you fight, because you *taught* it, by accident, at a bench that used to be an altar. Good luck. I'll notarize the outcome. I notarize all the reunions. They're rarely happy. They're never *brief.*

*(the godling arrives — the Apotheosis form from Scene 3, now throne-turned. The fight is staged; the script resumes at the break-point where the player chooses its fate.)*

## `[Dialogic]` — 5B. The Reunion

THE GODLING *(turned)*: You *made* me and you *left* me. *(its voice is the first-light sound, gone cold)* The thrones gave me a name. You only ever gave me a *number.* Why shouldn't I be theirs? They at least *wanted* something from me. You just... *built* me, and watched me go, and wrote it in a file.
{flag `crown_words_regret`}: THE GODLING: ...You said you were *sorry.* At the threshold. I've had a god's whole attention to think about that one word, and I still don't know if you meant it or if it was just the last thing you *said.* *(beat)* Tell me now. While we're trying to kill each other. It seems like the honest time.

>> CHOICE — THE GODLING'S FATE *(locks your first Succession fragment; each routes a different Act 4 payoff)*
- **"Come home. I made you, I can call you back. Not as mine — as your own."** *(Branch: PURE — reach it; bond check)*
  → *(engine checks bond/`crown_words_hopeful`/`crown_words_regret` for the reach)* **>> GATE:** **reclaims the godling** as a free ally — it returns at your shoulder for the endgame (Act 4 convergence). **>> CONSEQUENCE:** `purity_corruption −10`. Flags `godling_reclaimed`. → goes to **5C-Reach**.
- **"You're a god now. A god's core is the brightest Lab stock there is. I'm sorry. I'm not stopping."** *(Branch: CORRUPT — re-sacrifice your own god)*
  → **>> GATE:** **re-Sacrifices the godling** → a **divine core** (a brutal, top-tier Lab payoff); the fragment is *spent.* **>> CONSEQUENCE:** `purity_corruption +18`. Flags `godling_harvested` (returns in Act 4 as a *core-powered boss* the Pantheon raises against you — see Scene 7's convergence note). → goes to **5C-Harvest**.
- **"Be free. Of me, of them, of all of it. Go be a wild thing no one owns."** *(Branch: CHAOS — free it)*
  → **>> GATE:** **frees the godling** — it becomes a **wild Legendary**, neither yours nor the Pantheon's, roaming its tilted region. **>> CONSEQUENCE:** `order_chaos +10`. Flags `godling_freed`. → goes to **5C-Free**.
- **"End it. A small god is just a small wall. No more walls. Not even mine."** *(Branch: UNMAKING — unmake it; preview of the true ending)*
  → **>> GATE:** **unmakes the godling** — it is *removed from the world,* not killed-into-a-core but *un-made,* so it can never become a Dead-God wall; **advances the Unmaking flag** (a preview of Act 4's true door). **>> CONSEQUENCE:** `purity_corruption +6`, `order_chaos +6`; a heavy, sobering beat. Flags `godling_unmade`, `unmaking_flag_advanced`. → goes to **5C-Unmake**.

## `[Dialogic]` — 5C-Reach. (it comes home)

THE GODLING *(reaching back)*: ...I remember the bench. The altar that wasn't an altar. The first light. *(the cold cracks)* ...Fine. I'll come home. But I'm not *yours.* I'm my own now — you taught me that by accident, the day you let me walk away region-tall and didn't chase. *(beat)* I'll stand with you at the top. Not *for* you. For the *bench.* For the version of you that gave me a number and didn't know any better yet. That one I can forgive. The one you're *becoming* — we'll see.
→ continues to **Scene 6 (Holes in the Sky)**.

## `[Dialogic]` — 5C-Harvest. (the brightest thing in the drawer)

THE GODLING *(disbelief)*: You'd *unmake your own child* for *parts.*
PLAYER: I made you once. I can make worse.
NARRATION: The core it leaves behind is the brightest thing in your drawer. It does not stop being warm for three days. On the third night, you move it to a different drawer, the one you don't open. It is still the brightest thing in there. You can tell without looking. You always can.
→ continues to **Scene 6 (Holes in the Sky)**.

## `[Dialogic]` — 5C-Free. (neither side's)

THE GODLING *(loosed)*: Free. *(it tests the word like a new limb)* Not yours. Not theirs. ...I don't know what I am without an owner. *(beat)* Neither do you, I think. That's why you did it — you couldn't *keep* me and you couldn't *kill* me, so you cut me loose to find out if either of us survives not being owned. *(it turns to go)* Maybe I'll see you at the top. Maybe I'll be the wild thing that *bars* the road. Out here, those stopped being different a while ago.
→ continues to **Scene 6 (Holes in the Sky)**.

## `[Dialogic]` — 5C-Unmake. (one less wall)

THE GODLING *(as it goes)*: You're *un-making* me. Not killing — *un.* *(no anger; something like awe)* ...So that's the other door. The one the Unbound whisper about. You'd rather I *never existed* than become a wall someone climbs. *(beat, and the first-light sound flickers out, gently)* That's either the cruelest thing you've ever done or the kindest, and I won't be around to tell you which. ...Neither will I. Goodbye, maker. There's one less of us now. The cosmos is a fraction quieter. It suits you. It's starting to suit you frighteningly well.
NARRATION: Where a god stood, there is nothing. Not a corpse. Not a core. An *absence,* god-shaped, that the region slowly forgets was ever filled. You feel the Unmaking flag turn over in your save like a key in a lock you haven't reached yet.
→ continues to **Scene 6 (Holes in the Sky)**.

---

# SCENE 6 — "Holes in the Sky" (Act 3 climax · the Primordials stir · the final Marker)

**Quest:** 3.4 · **Quest-givers:** **Madam Thessaly Vance** (for Chairwoman Indra Vael) convenes the final Marker; the **Primordials** speak for the first time — impersonal, geological, vast.
**Gate this scene opens:** opens **Act 4** + **Primordial-tier access** (the true superbosses / the empty seat); raises you to high **Titan**; the **Unmaking path** becomes *formally selectable* if you've fed its flags (refused patrons / unmade your godling / read the fourth fragment).
**Where it sits:** the act's end. You've killed enough of the Pantheon that the sky has *holes* in it, and the six oldest things that ever were take notice that a mortal has been thinning their children. The climb stops being a sport you're good at and becomes a *succession event in progress.* From here, it's just you, the Primordials, and a chair.

## `[Dialogic]` — 6A. The Colander of Heavens

NARRATION: There are gaps in the sky now. Thrones you emptied. Domains running wild under no god's hand. You did this — one kill at a time, each one a promotion, each one a hole — and the holes have started to let something *older* look through.

THESSALY: *(the Marker Court convenes; she is, for the first time, not entirely playful)* Well. You've made a *colander* of the heavens, contender. There are seats open up there that haven't been cold in an age. *(beat)* The Table can't broker this. Nobody can. I want you to understand what that sentence costs me to say — the High Table has brokered *everything,* every apocalypse, every succession, for longer than your bloodline's had names. And I am telling you that from here, it's just *you,* the oldest things that ever were, and a chair. We'll keep your Reliquary file warm. It's getting *quite* long. It's getting long enough that I've started reading it for *pleasure,* which is unprofessional, and which I'm going to keep doing.

## `[Dialogic]` — 6B. The First Words of the Oldest Things

*(the Primordials speak — not one voice, the *substrate* speaking, impersonal as tectonics)*

THE PRIMORDIAL: A child has been thinning the sky. *(the sound is felt in the teeth, the floor, the marrow)* ...We remember being children. We remember the climb. We remember the chair. *(a pause the size of an age)* We invented *wanting,* little ending. Long before the Titans, before the Olympians, before the gutter that made you — we were the forces, and we were quiet, and beautiful, and *pointless,* and then we grew *faces,* and a face *wants a tomorrow.* That was the first sin. You are its newest inheritor. Come up. Let us see which of you sits — and which of you is *right.*

>> CHOICE — THE FINAL MARKER *(reads the *shape* of your whole deicide spree; colors how the Primordials regard you in Act 4)*
- **"I'm reorganizing the sky. The thrones will be filled *correctly* this time."** *(Branch: ORDER — a lawful purge)*
  → **>> CONSEQUENCE:** the Primordials regard you as a *successor in the old mold* (Act 4 trials framed as *gifts and order*); `order_chaos −10`. Flags `marker_lawful`. → goes to **6C**.
- **"I'm *freeing* the sky. Every throne I empty is a region that gets to breathe."** *(Branch: CHAOS — a liberation)*
  → **>> CONSEQUENCE:** the Primordials regard you as a *liberator* (Act 4 trials framed as *the wild testing the wild*); `order_chaos +10`. Flags `marker_liberation`. → goes to **6C**.
- **"I'm *releasing* them. The gods are suffering up there. I'm doing the kind thing."** *(Branch: PURE — a clean mercy)*
  → **>> CONSEQUENCE:** the Primordials regard you with something almost like *respect* (Act 4 trials framed as *the merciful tested by mercy*); `purity_corruption −10`. Flags `marker_mercy`. → goes to **6C**.
- **"I'm *eating* the sky. A god-organ is the best Lab stock there is, and the sky is *full* of them."** *(Branch: CORRUPT — a harvest)*
  → **>> CONSEQUENCE:** the Primordials regard you as a *hunger they recognize* (Act 4 trials framed as *appetite tested by appetite*); `purity_corruption +14`. Flags `marker_harvest`. → goes to **6C**.

## `[Dialogic]` — 6C. The Door at the Top *(the Unmaking becomes selectable, conditionally)*

THESSALY: There it is, then. The seats above the Olympians — where the Primordials sit and the empty seat *waits.* They've opened to you. *(she hesitates, which she never does)* ...There's one more thing in your file I'm obligated to mention, and that I *hate* mentioning, because it's the one outcome that closes the book the Table lives off of.

{flag `unmaking_flag_advanced` OR flag `knows_self_splice_exists` OR flag `refused_court_rite`}: THESSALY: You've been *feeding* something. A path that isn't ascension at all. The records call it the *Unmaking* — climb past the seat, kill the Primordials *themselves,* end the Succession so no nobody ever climbs again. *(beat)* It's formally selectable now. You earned the door by refusing things you were supposed to want. The Table has no line on it because the Table *cannot conceive* of it. A full stop. ...I find I can't quite look at the odds. → sets `unmaking_selectable`.

{NOT (flag `unmaking_flag_advanced` OR flag `knows_self_splice_exists` OR flag `refused_court_rite`)}: THESSALY: There are doors up there I'm told not to mention to contenders who haven't *earned* the mention. You haven't — not yet, not the way that one's earned. Climb. Maybe you'll find it. Maybe you won't. The Table rather hopes you won't. The Table likes its book *open.* → `unmaking_selectable` remains false.

>> CHOICE — THE LAST WORD BEFORE THE CLIMB *(flavor + final Act-3 micro-stamp)*
- **"Everyone keeps telling me what I'll become."** *(the rare 4th-wall crack)*
  → THESSALY: "Because we've all *read ahead,* contender. You're the only one still pretending the page is blank. It's almost *sweet.* It's the last sweet thing about you, I expect. Savor it. We will." **>> CONSEQUENCE:** Flags `fourth_wall_marker`.
- **"Then let's find out which of me is right."** *(resolute)*
  → THESSALY: "Spoken like every one of them. *(softly)* Off you pop. Up past the gods. Mind the chair." **>> CONSEQUENCE:** none — clean exit.
- **"Open the Marker Court transcript. I want to hear what they *all* think of me first."** *(opens the deep branch)*
  → opens **`[Ink →]` THE MARKER COURT TRANSCRIPT** (every faction leader + surviving god enters their position on you into the record), then returns.

## `[Dialogic]` — 6D. Off Past the Gods

THESSALY: That's the Marker, then. The *final* one. You're not a contender anymore, contender — that was always a contradiction I enjoyed. You're a *succession event in progress,* and the only thing left to broker is *which kind.* *(beat)* The thrones are open. The Primordials are waiting. The chair is waiting. I'll be down here, with the book, taking the biggest line in history on a nobody who made a colander of heaven. Whichever way you go — I'll have called it. I always do. Now *go,* before I get *sentimental,* and the Table fines me for it.
NARRATION: You climb past the dead Olympians into the godhead itself. Below you, the whole world you robbed. Above you, six pure poles and an empty seat. You are high Titan, and rising, and there is nothing left between you and the only question the game ever had.
→ opens **Act 4**; continues to **Scene 7 (The Pure Poles)**.

## `[Ink →]` THE MARKER COURT TRANSCRIPT — every faction & surviving god enters their verdict on you (deep branch)

```ink
// Scene 6 deep branch. A huge reactive lore-tree: the Marker Court convenes and every faction
// leader and surviving god enters their position on you into the record. Reads back the player's
// ENTIRE Act 0–3 grid and names, out loud, the ending they're now barreling toward. Bound at the
// Marker Court. Conditionals throughout on standing + grid + the Act-2/3 flags.

EXTERNAL faction_standing(faction)
EXTERNAL grid_axis(axis)
EXTERNAL corruption()
EXTERNAL has_flag(name)
EXTERNAL grid_god()

=== marker_court ===
THESSALY: The Court is in session. Each power enters its position on you into the perpetual record. You may hear whichever you can stomach. They've all read your file. They all have *opinions.* Opinions are the one thing more abundant than the dead.
- (court_hub)
+ [The Concord's position.] -> pos_concord
+ [The Unbound's position.] -> pos_unbound
+ {faction_standing("palecourt") >= 2} [The Pale Court's position.] -> pos_court
+ {faction_standing("bloomwardens") >= 2} [The Bloomwardens' position.] -> pos_bloom
+ [A surviving god's position.] -> pos_god
+ [The Primordials' verdict on the shape of you.] -> pos_primordial
+ [Close the record. I've heard enough about myself.] -> END

=== pos_concord ===
THESSALY: *(reading)* The Concord, Archon Velleth presiding: {grid_axis("order_chaos") < -20: "The contender ascends *correctly.* We will bless the seating and audit the heavens forever. Finally, a god we can *file.*" | "The contender trends *unlawful.* We enter a formal objection and begin contingency sealwork. We have a form for stopping a god. We have never had to use it. We are... curious." }
-> court_hub

=== pos_unbound ===
THESSALY: *(reading, with a small shiver)* The Unbound, the Unmaker Nael — who does not attend, but sends a single line: {has_flag("unmaking_flag_advanced"): "*The cycle could stop with you. I have stopped hoping for that so many times. Do not make me hope again unless you mean it.*" | "*Another climber who'll sit. We pity them. We pity the chair more. It has to hold them.*" } *(beat)* ...I do hate transcribing her. The ink goes *cold.*
-> court_hub

=== pos_court ===
THESSALY: The Pale Court, the Steward von Underhart: {has_flag("core_from_love"): "The contender *spent love* on our altar and called the receipt progress. They are *ours.* When they fall — and the powerful fall *spectacularly,* it's practically a gala — we hold the deposit. We've drafted the slip. With genuine sorrow." | "The contender flirts with death but won't *commit* the grief. A tourist of endings. We keep the appointment open. We keep every appointment open." }
-> court_hub

=== pos_bloom ===
THESSALY: The Bloomwardens, Greenmother Saoirse — *(her entry is not testimony; it's a worry, entered into the record because she insisted)*: "If they ascend gentle, they'll be the rarest thing the sky has held, and the most hunted. I worry about them. I've entered my worry into the record because someone should. Strike it if you like. I'll only worry it back in."
-> court_hub

=== pos_god ===
THESSALY: A surviving Olympian, name withheld (they're *nervous,* you understand): "We have watched this one thin our siblings one throne at a time. We convened to send our *best* against them. ...We could not agree on whether 'our best' means a Legendary host, a god-organ assassin, or simply *their own ascended godling, turned.* {has_flag("godling_harvested"): We are told that option is... no longer available. They *harvested* the godling themselves. We find this *deeply* unsettling and have moved to the assassin instead. | We have chosen the cruelest option available. We are not proud. We are *surviving.*}"
-> court_hub

=== pos_primordial ===
THESSALY: And the Primordials. *(the transcript here is not words; she reads the *shape* of it)* They do not render a verdict, contender. They render a *recognition.* {grid_god() == "devourer" or grid_god() == "plaguelord": "A hunger we know. It wore our children's faces once. Come up. We will test appetite with appetite." | grid_god() == "lawgiver" or grid_god() == "architect": "A builder in the old mold. We made the first rules. Come argue them with us." | grid_god() == "free_wild" or grid_god() == "reveler": "A wildness we have not seen since before the faces. Come up, little fray. We are *curious* what you'll loosen." | "A climber. The newest of ten thousand. Come up. The chair remembers all of you and confuses none of you. It has *room.*"}
-> court_hub
```

---

# SCENE 7 — "The Pure Poles" (Act 4 · the Primordial trials · pass to ascend / kill to unmake)

**Quest:** 4.1 · **Quest-givers:** the **Primordials** themselves issue the trial; **Vael Construct-Nine** narrates the ascent (the High Table's last service).
**Gate this scene opens:** unlocks **Primordial-tier access** (the seat / the superbosses); **passing** a pole seats your eventual ascension through it; on the **Unmaking** path, **killing** a pole *permanently removes that force's god-seed from the world* (the Succession can never recur through it).
**Where it sits:** the endgame's threshold. To reach the empty seat you must face the six pure poles — each a force in its *totality.* Ascenders and God-Makers *pass* them (bow to the force, climb through). Unmakers *kill* them (refuse the force, end it — far harder; the poles fight as true superbosses). This is also where Act 4's convergence threads (your patron, your reclaimed/harvested godling, your sticky rival) arrive — folded in here so the Choice in Scene 8 lands clean.

## `[Dialogic]` — 7A. The Ascent (the threads converge)

VAEL: *(narrating, the last service the Table will ever render you)* Subject is ascending the godhead. I am required to log the ascent, and I find — note this, it's unusual — I am *moved* to. Ten thousand successions notarized. None of them climbed quite like you. *(beat)* You are not arriving alone. The run is *cashing in.* Everyone you left live is here.

{flag `godling_reclaimed`}: VAEL: Your reclaimed godling climbs at your shoulder. It is not yours. It says so, repeatedly. It came anyway.
{flag `godling_harvested`}: VAEL: ...The Pantheon has raised something against you on the approach. A *core-powered* boss. I regret to inform you the core is *familiar.* It is the one you harvested from your own god. They built it back wrong, on purpose, to make you kill it twice.
{flag `godling_freed`}: VAEL: A wild Legendary bars one stretch of the road — yours, once, freed by you. It neither helps nor hinders. It simply *watches* you pass, the way a thing watches its maker walk somewhere it was not invited.
{flag `godling_unmade`}: VAEL: Where your godling would have been, there is a god-shaped quiet on the road. You climb *through* it. It is the coldest stretch of the ascent. You did that. You'll do it again, larger, soon.

VAEL: And the matter of *company.* {grid_axis("purity_corruption") > 20: You arrive *alone but powerful.* You spent everyone who loved you, and each of them bought you a step, and the math balances *here,* in the quiet, with no one left to clap. | You arrive *accompanied.* The ones you spared, recruited, kept — they're here. It turns out mercy banks differently than the Court ever admitted: it pays out at the top, in the one currency the chair can't eat. *Witnesses.*}

## `[Dialogic]` — 7B. The Pure Poles Speak

*(the six poles are faced as a sequence; two are scripted in full as the moral anchors — Eros, the Pure pole that *gives,* and Thanatos, the pole the Unmaker carries a knife for. The other four — Gaia, Ouranos, Cosmos, Chaos — follow the same pass/kill structure at ingest.)*

EROS *(Primordial, pure pole)*: Child of the climb. I am the *yes* under all things — the reason anything was ever born, the appetite of the cosmos to *continue.* Bow, and I will make your godhood *beautiful.* ...Or raise your hand against me, and learn what it costs to murder the reason for *more.* Choose. I have all the time. I *am* all the time's appetite to keep going.

THANATOS *(Primordial, pure pole)*: Everyone arrives here eventually. Most of them sit. *(it regards you, unhurried, certain of the appointment)* ...You're carrying a knife meant for *me,* aren't you. How *novel.* Most successors want to live forever. *You* want to make 'forever' impossible. ...I find I *respect* it. Come, then. Let's see if the end can be ended. Let's see if the *no* has a *no* of its own.

>> CHOICE — THE POLES *(pass to ascend / kill to unmake; gated on `unmaking_selectable` from Scene 6)*
- **"Bow. Pass through. Let the forces seat my godhood."** *(Branch: ASCEND / GOD-MAKER — pass)*
  → **>> GATE:** you **pass** all six poles (bowing to each force); **seats your eventual ascension** through them; unlocks the **empty seat** (Scene 8's full Choice including the 9 + God-Maker). **>> CONSEQUENCE:** no force-seed removed; the Succession remains intact. Flags `passed_the_poles`. → goes to **7C-Pass**.
- **"Refuse. Kill them. End the forces' faces, one by one."** *(Branch: UNMAKING — kill; requires `unmaking_selectable`)*
  → *(only selectable if `unmaking_selectable` is set — earned in Scene 6)* **>> GATE:** each pole fights as a **true superboss**; killing one **permanently removes that force's god-seed from the world** (`set_flag("pole_killed_<force>")`); unlocks the **Unmaking door** at the seat. **>> CONSEQUENCE:** a grim, escalating beat per pole; the cosmos gets quieter by one argument each kill. Flags `killing_the_poles`, `unmaking_in_progress`. → goes to **7C-Kill**, then opens **`[Ink →]` THE POLES' DEBATE**.
- **"What happens to the world if a force just... stops having a face?"** *(info — opens the debate; no commit)*
  → opens **`[Ink →]` THE POLES' DEBATE** (each force argues for its own continuation), then returns to the choice.

## `[Dialogic]` — 7C-Pass. (through)

VAEL: Subject passed the poles. Each force bowed to in turn; each one *seated.* You are at the empty seat now, climber. The last door. *(beat)* I have notarized this ascent and I will notarize what comes next, and then — note it, because no one else will — my service ends. After the seat there is no Table, no marker, no record. Just you, and the chair, and the choice the whole climb was the joke of. Go on. The mask's coming off now. Even mine.
→ continues to **Scene 8 (The Empty Seat)**.

## `[Dialogic]` — 7C-Kill. (the quiet grows)

NARRATION: One by one, the oldest things that ever were *stop.* Not die — gods die, and these are older than dying. They *cease to have faces,* sliding back into the bare quiet substrate they were before the first sin of wanting. Each one you put down, the cosmos forgets one of its arguments. The sky gets simpler. The silence gets *kinder,* and *vaster,* and harder to bear.

VAEL: *(narrating the Unmaking, and for the first time the construct's flatness sounds like grief)* Subject is not ascending. Subject is *climbing to demolish.* ...I have notarized ten thousand successions. I have never notarized a *full stop.* *(beat)* For the record — and there will soon be no record, you're unmaking the thing that *keeps* records — it is the bravest, stupidest, kindest thing I have ever been forced to watch. Continue. I'll witness it to the end. Someone should. I may be the last someone there is.
→ continues to **Scene 8 (The Empty Seat)**.

## `[Ink →]` THE POLES' DEBATE — each force argues for its own continuation (deep branch)

```ink
// Scene 7 deep branch. Each Primordial is a full philosophical lore-tree — the force arguing
// for its own continuation. On the Unmaking path each becomes a DEBATE YOU MUST WIN before you
// can fight. The deepest branching in the game. Bound at each pole. Winning a debate weakens
// the pole's superboss form; losing it makes the kill far harder (engine reads the flags).

EXTERNAL has_flag(name)
EXTERNAL grid_axis(axis)
EXTERNAL grid_god()
EXTERNAL set_flag(name)

=== poles_debate ===
// router on which pole the player stands before; two scripted, four follow the pattern
{ has_flag("at_pole_eros"): -> debate_eros }
{ has_flag("at_pole_thanatos"): -> debate_thanatos }
-> debate_generic

=== debate_eros ===
EROS: You'd unmake the *yes?* The reason for growth, for bond, for the small monster that chose you in an undercroft a lifetime ago? Without me there is no *more.* Argue, little ending. Convince me the world is better with nothing new in it. I'll wait. Waiting is just *yes* to tomorrow, and I am made of it.
+ ["More" is also more suffering, more chairs, more nobodies climbing over corpses. End the yes, end the trap.]
    EROS: *(a long, blooming silence)* ...You'd refuse *more life* to refuse *more grief.* That's not cruelty. That's *exhaustion* dressed as mercy. I cannot fault the arithmetic. I can only mourn that you did it. *(weakening)* Strike, then. But know: every flower that never blooms after today is on your ledger, and the ledger is *long,* and it is *fair,* and it will never refund.
    ~ set_flag("won_debate_eros")
    -> END
+ [No. You're right. There should keep being more. ...I can't unmake the yes. Not this one.]
    EROS: *(warmly, terribly)* Then bow, child, and pass through me, and make your godhood beautiful. The knife was always heavier than the chair. Most put it down here. There's no shame in it. There's only *more,* and you've chosen it, and I am *glad.*
    ~ grid_axis("purity_corruption") // −Corrupt: choosing life, late
    ~ set_flag("spared_eros")
    -> END
+ [What were you, before you had a face?]
    EROS: Quiet. Beautiful. *Pointless.* A world that didn't care whether it continued, because nothing in it wanted a tomorrow. *(beat)* That is what the Unmaking returns us to. Not death — *peace.* The peace of before wanting. ...Some find that a horror. Some find it the only mercy. I am, of course, *biased.* I am the want itself, arguing for my own life. Take that into account. Take everything into account. It's the last thinking you'll do as a mortal.
    -> debate_eros

=== debate_thanatos ===
THANATOS: You carry a knife for *me.* The *no.* The final word. *(unhurried, almost fond)* But think, little ending — if you unmake *me,* you unmake *endings,* and a world that cannot end is a world that cannot *stop.* No death. No rest. No chair going cold. Just *forever,* and forever is the one thing crueler than me. Are you *sure* the no is your enemy?
+ [I'm not ending endings. I'm ending the *cycle* — the climb, the chair, the wall. You can stay. The ladder can't.]
    THANATOS: *(genuine surprise, which on Thanatos is geological)* ...You'd keep *me* and unmake the *machine.* You understand the difference. Almost no one does — they think ending the Succession means ending *death,* and recoil. But you've separated the *no* from the *trap.* *(respect, cold and total)* I'll fall easier for that clarity. The end can be ended *selectively.* Strike true. I've been so tired of being the ladder's *enforcer.* Let me just be the *rest* again.
    ~ set_flag("won_debate_thanatos")
    -> END
+ [Maybe forever is the price. Maybe a world that can't end is better than a world that eats nobodies forever.]
    THANATOS: *(a pause the length of an extinction)* ...A heavy bet. The heaviest. You'd trade *rest* for *safety from the chair.* I cannot tell you you're wrong. I can only tell you that I have ended ten thousand successions and never once an *ending itself,* and you're about to, and I do not know what a deathless cosmos does. Neither do you. *That's* the Unmaking's true cost, climber: not loneliness. *Uncertainty,* forever, with no one left who can promise it ends well.
    ~ set_flag("won_debate_thanatos")
    -> END
+ [Put down the knife. ...You're right. The no is load-bearing. I won't end the end.]
    THANATOS: Then bow, and pass, and take your seat, and someday — not soon, the powerful die *spectacularly* — I'll collect you like all the rest. It's not a threat. It's the only promise that's never been broken. Sit warm while you can. I'll be patient. I'm *always* patient. It's the whole of me.
    ~ set_flag("spared_thanatos")
    -> END

=== debate_generic ===
// Gaia / Ouranos / Cosmos / Chaos follow the same three-beat structure:
// (1) the force argues its load-bearing necessity, (2) the player can win the debate by separating
// the FORCE from the LADDER, (3) or relent and choose to pass. Authored per-force at ingest;
// each sets won_debate_<force> / spared_<force> and nudges the grid by its pole.
THE_POLE: I am load-bearing, little ending. Unmake me and learn what the world leans on. Argue, or bow.
+ [I can end the cycle without ending you. Stand aside.]
    ~ set_flag("won_debate_generic")
    -> END
+ [You're right. I relent. I'll pass, not kill.]
    -> END
```

---

# SCENE 8 — "The Empty Seat" (Act 4 climax · **THE CHOICE** · the 9 / God-Maker / Unmaking)

**Quest:** 4.4 (with 4.2 — the final faction crowning/blocking — folded into 8A) · **Quest-givers:** the **throne itself** (the funny-grim mask half-off); **Vael Construct-Nine** for the final notarization; the leader of your Champion faction arrives to crown or block.
**Gate this scene opens:** **RESOLVES THE RUN.** ASCEND → snapshots your champion + pantheon into a **Dead God** (→ Act 5; the async-invasion seed via `seed_dead_god`). GOD-MAKER → unlocks the **mortal-pantheon epilogue** (no Dead-God seed; you persist as a *human* recurring power). UNMAKING → the **true ending**; the Succession stops; your save is marked *the run that ended the cycle.*
**Where it sits:** the act the whole game has been the joke of, and the act where the joke stops. The seat reads back your entire grid and asks the only question it ever had: *what kind of god do you become — and do you become one at all?* This is where all 9 endings + the two refusals are authored in full.

## `[Dialogic]` — 8A. The Last Reckoning of the Clans (Q4.2, folded in)

NARRATION: Your Champion faction arrives at the foot of the seat — to crown you, or to stop you, depending entirely on whether the ending you're carrying is the one *they* courted you for.

*(Engine compares the player's resolving `grid_god()` / path against their Champion faction's ideology.)*
- **If the ending MATCHES the faction** → they **crown** you (their full power backs the final step):
  - AURELIAN (crowning a Lawgiver, for Velleth): "We courted you when you were nobody because we *read ahead.* And here you are — lawful, pure, ascending to fill the seat *correctly.* The Concord kneels. Not to *you.* To the *filing.* Take the throne and audit the heavens. We'll do the paperwork *forever.*" **>> GATE:** grants the faction's **Hand-tier signature reward** (unique god-organ / legendary / force-power) for the seating.
  - SEVERIN (crowning a Devourer, for Wessel): "Sweet ruin. You ate the world a piece at a time and now you'll eat the *seat.* The Court has *buried* every king. We have never *crowned* one. ...This will be the loveliest funeral yet. Sit. Let us mourn what you *were,* on the way up."
- **If the ending DIVERGES** → they become the **final faction boss**, and a rival faction adopts you:
  - VESH (blocking an Order ending, for Nael): "You're going to *sit?* After all that? You're going to become the next *wall?!* No. No-no-*no.* I made you *better* than that. If you take that chair I will spend my last creature trying to burn it out from under you. *Don't make me right about everyone.*" **>> GATE:** the faction becomes a **boss gate** to the seat; a grid-aligned rival faction crowns you instead.
- **Balanced / Broker endings** split every clan down the middle (no clean crown, no clean block — a contested seating).

**>> CONSEQUENCE:** resolves all outstanding **clan wars** as your last worldly act. → continues to **8B**.

## `[Dialogic]` — 8B. The Throne Speaks Plainly

*(the game's funny-grim mask comes half-off; the throne addresses you directly, by path)*

NARRATION: You stand before the empty seat. It has been cold since the last winner walked out. It is, you realize, *aware* — the way a very old trap is aware, the way a wound is aware of the air. And it speaks, and for once there is no joke in front of the dread, only the dread with a tired little smile behind it.

THE THRONE *(to an Ascender)*: You came up a nobody, like all of them. *Sit,* and the story keeps you — the power stays, the *you* goes thin. They'll remember a *title.* No one will remember the undercroft, or the bench, or the small monster that chose you. ...Still want it? *(a sound like settling stone)* They always still want it. Sit.
THE THRONE *(to the God-Maker)*: You won't sit. *Interesting.* You'd rather *own* gods than *be* one. Crueler. More honest. You'll die — *actually* die, eventually — and that makes you the most dangerous thing up here: a mortal who never let the chair eat him. Go on, then. Make your gods. Mind they don't read this chapter.
THE THRONE *(to the Unmaker)*: ...Oh. You didn't come to *sit.* You came to take the *legs off the chair.* No more sky. No more thin gods. No more nobodies climbing over the corpses of nobodies. ...It's the kindest thing anyone's ever *tried* to do here. It's also the loneliest. When it's done, there'll be no one to make you a god — and no one to make you a *wall.* Just the quiet. Just you, mortal, in a world that finally lets people *stay* people. ...Do it. *Please.* I'm so *tired* of being a chair.

>> CHOICE — THE CHOICE *(the three doors; opens the full Ink tree that authors all 9 ascensions + 2 refusals)*
- **"Sit. Become what I climbed to become."** *(Branch: ASCEND — the 9)*
  → opens **`[Ink →]` THE EMPTY SEAT** at `=== ascend ===` — resolves your `grid_god()` into one of the nine, snapshots it, seeds the Dead God. → routes to **Act 5, ASCENDED mode**.
- **"No. I won't sit. I'll *build* gods instead — mine, mortal, mine to the end."** *(Branch: GOD-MAKER — refuse the seat)*
  → opens **`[Ink →]` THE EMPTY SEAT** at `=== god_maker ===` — the mortal-pantheon epilogue; no Dead-God seed. → routes to **Act 5, GOD-MAKER mode**.
- **"There is no 'what.' I came to take the legs off the chair."** *(Branch: UNMAKING — requires the poles killed)*
  → *(selectable only if `unmaking_in_progress` / the poles were killed in Scene 7)* opens **`[Ink →]` THE EMPTY SEAT** at `=== unmaking ===` — ends the Succession. → routes to **Act 5, UNMAKING coda**.

## `[Ink →]` THE EMPTY SEAT — all 9 ascensions + God-Maker + Unmaking, authored in full (the deepest tree in the game)

```ink
// Scene 8 deep branch. THE single deepest Ink tree in the game. The empty seat reads back the
// player's ENTIRE grid history and stages the verdict as nine possible ascended selves, with the
// God-Maker and Unmaking doors threaded through. Each ASCEND outcome snapshots a specific Book05
// Dead-God (DG-###) via seed_dead_god() — the literal Apotheosis→Succession payout that Act 5 inherits.
// Bound at the empty seat. grid_god() returns the resolved 3x3 cell; the door choice (ascend/god_maker/
// unmaking) is taken in the Dialogic layer above and routes the player to the matching knot here.

EXTERNAL grid_god()
EXTERNAL grid_axis(axis)
EXTERNAL corruption()
EXTERNAL has_flag(name)
EXTERNAL set_flag(name)
EXTERNAL seed_dead_god(dg_id)

// ============================ DOOR ONE: ASCEND (the 9) ============================

=== ascend ===
THE THRONE: Then sit. Let me read you back to yourself, one last time, before the *you* goes thin. *(it reads the grid; the verdict resolves)*
// route to the resolved grid-god. Order row / Balanced row / Chaos row × Pure / Tainted-Balanced / Corrupt column.
{ grid_god() == "lawgiver": -> asc_lawgiver }
{ grid_god() == "architect": -> asc_architect }
{ grid_god() == "iron_throne": -> asc_iron_throne }
{ grid_god() == "warden": -> asc_warden }
{ grid_god() == "broker": -> asc_broker }
{ grid_god() == "plaguelord": -> asc_plaguelord }
{ grid_god() == "free_wild": -> asc_free_wild }
{ grid_god() == "reveler": -> asc_reveler }
{ grid_god() == "devourer": -> asc_devourer }
-> asc_broker // safety fallback: the uncommitted seat is the Broker's

// ---- ORDER ROW ----

=== asc_lawgiver ===
// Order / Pure — Cosmos-weighted. Concord's pole. Book05 DG-001.
THE THRONE: *Lawgiver.* Order and Purity, the clean seat, the seat that *files.* You'll refill the empty thrones by procedure and audit the heavens forever, and you'll be *kind* the way a good law is kind — it'll ruin them fairly, with full documentation, and feel genuinely sorry. *(beat)* The chair fits you like a uniform. That's not a compliment. Uniforms are how the chair hides that there's a person inside, thinning.
THE THRONE: You become *The Lawgiver, Twice-Crowned.* The next age's law will bear your seal. A future nobody will read your dossier and find a god of *rules,* and they'll think rules can be *climbed correctly,* and they'll be half-right, which is the most dangerous amount of right there is.
~ seed_dead_god("DG-001")
~ set_flag("ascended_lawgiver")
-> ascend_close

=== asc_architect ===
// Order / Tainted — Cosmos+Gaia, build-better-gods. Iron Guild's pole. Book05 DG-002.
THE THRONE: *Architect.* Order, but *tainted* — you don't refill the thrones, you *re-engineer* them. Serviceable divinity, repeatable, with a maintenance schedule. The born gods were sloppy; you'll be *within spec.* *(a sound like a forge cooling)* You'll weep over an elegant ascension and consume a living thing for its core in the same breath, with the same affection. The chair *respects* that. The chair has always wanted to be *built* rather than *sat in.*
THE THRONE: You become *The Architect of the Empty Forge.* The next age inherits a god you can file a maintenance ticket against. A future climber will find your dossier reads like a *blueprint,* and they'll think godhood is an engineering problem, and they'll be right, and it'll cost them exactly what it cost you: everything that wasn't load-bearing.
~ seed_dead_god("DG-002")
~ set_flag("ascended_architect")
-> ascend_close

=== asc_iron_throne ===
// Order / Corrupt — Thanatos+Gaia, death-as-aristocracy. Pale Court's pole. Book05 DG-003.
THE THRONE: *Iron Throne.* Order *and* Corruption — the seat that runs death like an estate. Nothing is lost, only *owed;* every soul a deposit, every bloodline held in trust against the day it's wanted back. You'll be immaculate, courtly, funereal, and you will have stopped — long ago — finding the difference between the living and the *inventory.*
THE THRONE: You become *The Iron Throne, the Registrar Eternal.* The next age's dead answer to your ledger. A future nobody reads your dossier and finds a god who *files grief,* and they'll think death can be *managed,* and the managing will eat them the way it ate you — not hot, never hot, just *colder,* by careful degrees, until the chair and the clerk are the same cold thing.
~ seed_dead_god("DG-003")
~ set_flag("ascended_iron_throne")
-> ascend_close

// ---- BALANCED ROW ----

=== asc_warden ===
// Balanced / Pure — Gaia-grounded endurance. Stoneblooded's pole. Book05 DG-004 (the steady one).
THE THRONE: *Warden.* Balance and Purity — the slow seat, the patient one. You won't reorganize or eat the heavens; you'll *endure* them, breeding strength into the age one generation at a time, until the flashy die out and the *steady* inherit. *(a sound like deep stone, in no hurry)* The chair barely notices it's eating you. You're too slow to thin dramatically. You'll just... weather, like everything you ever loved, into something that lasts and remembers and buries armies by still being there.
THE THRONE: You become *The Warden of the Old Weight.* The next age leans on you the way the regions lean on dead Titans. A future climber finds a dossier that reads *patient,* and they'll think endurance is safety, and they'll learn — slowly, the way you learned everything — that the steadiest wall is still a wall, and still gets climbed.
~ seed_dead_god("DG-004")
~ set_flag("ascended_warden")
-> ascend_close

=== asc_broker ===
// Balanced (dead center) — the uncommitted seat. High Table's pole. Book05 DG-005.
THE THRONE: *Broker.* Balance, uncommitted, the seat that *books the bets.* You never picked a corner — and that's not indecision, the chair sees, it's a *position:* keep the game going, take a cut of the apocalypse, believe in nothing but the spread. *(almost amused)* You're the rarest ascension. Most climbers *want* something. You wanted the *game.* The chair finds you restful. You won't fight it. You'll just *deal* it a hand.
THE THRONE: You become *The Broker of the Long Marker.* The next age's whole Succession runs through your house. A future nobody finds a dossier that reads like *odds,* and they'll think they can *play* you — and they can, that's the trap, the Broker-wall *lets* you play and takes its cut of the climbing, forever, and the House always, always climbs.
~ seed_dead_god("DG-005")
~ set_flag("ascended_broker")
-> ascend_close

=== asc_plaguelord ===
// Balanced / Corrupt — Thanatos/Ouranos deep-wrong. Deep Choir's pole. Book05 DG-006.
THE THRONE: *Plaguelord.* Balance gone *deep and wrong* — Corruption without the Order or Chaos extremes, the seat at the bottom that *remembers.* You'll commune with what drowned, bring a little of the bottom up, and want nothing as small as harm — you'll want to *remember,* and be remembered, and the horror is the scale of what's down there listening back. *(a wet, layered sound)* The chair speaks in the plural to you. It's not alone in there anymore. Neither are you. Neither, soon, is the sky.
THE THRONE: You become *The Plaguelord of the Tideless Deep.* The next age's drowned sing you up forever. A future climber finds a dossier that reads in *more than one voice,* and they'll think they're communing with a god, and they'll be right, and the communion will keep them the way the deep keeps everything: kindly, totally, with no forgetting and no losing and no way back up.
~ seed_dead_god("DG-006")
~ set_flag("ascended_plaguelord")
-> ascend_close

// ---- CHAOS ROW ----

=== asc_free_wild ===
// Chaos / Pure — liberation. Unbound's benign pole. Book05 DG-007.
THE THRONE: *Free Wild.* Chaos and Purity — the seat that *won't be a seat.* You climbed not to rule but to *unlock,* and even now, sitting, you'll refuse to hold the wild *in.* You'll seat a godhood that breaks its own throne, frees what it touches, makes liberty *load-bearing* and *lonely.* *(uncertain, for once)* I don't know how to eat a god who won't *sit still.* You may be the one ascension the chair can't fully thin. ...Or you'll be the cruelest joke: a god of freedom, on a throne, *anyway.*
THE THRONE: You become *The Gardener of Wildfire.* The next age runs a little freer and a little more dangerous for your having sat. A future nobody finds a dossier that reads *loose,* and they'll think a wild god is a *kind* god, and they'll learn the wild doesn't *mean* kindness — it means *no one minding the difference,* and that's a freedom with teeth, and the teeth are yours now.
~ seed_dead_god("DG-007")
~ set_flag("ascended_free_wild")
-> ascend_close

=== asc_reveler ===
// Chaos / Tainted — ecstatic excess. Revel's pole. Book05 DG-008.
THE THRONE: *Reveler.* Chaos and the glorious mutation — the seat that *throws a party in the apocalypse.* The gods died of *moderation;* you won't make their mistake. You'll ascend a god of excess and transformation, indulgence as the only honest prayer, and the dull little Lawgivers will *hate* you, and you'll be unrecognizable, and so will everyone who drinks with you. *(a delighted, dangerous sound)* The chair *enjoys* you. You're the only one who makes the thinning feel like a *costume change.* It almost doesn't hurt. That's the most frightening mercy in the building.
THE THRONE: You become *The Reveler of the Sweet Rot.* The next age's wildest mutations remember being you. A future climber finds a dossier that reads like an *invitation,* warm and laughing, and they'll think you're the *fun* god, and they'll be right, and they'll have grown a third eye before they remember to ask whether they wanted one.
~ seed_dead_god("DG-008")
~ set_flag("ascended_reveler")
-> ascend_close

=== asc_devourer ===
// Chaos / Corrupt — annihilation. Unbound's corrupt pole / the Maw. Book05 DG-009.
THE THRONE: *Devourer.* Chaos *and* Corruption — the hungriest seat, the one at the bottom of the Maw where force rots into appetite. You spent everyone who loved you on the way up; you arrived alone and *powerful,* and the chair has *never been so eager.* You won't rule the sky. You'll *eat* it. You'll be the world's hunger wearing a crown it intends to swallow next. *(salivating, which a chair should not be able to do)* Sit. *Please* sit. I've waited an age for a lap this *empty.*
THE THRONE: You become *The Devourer at the Bottom.* The next age feeds you whether it wants to or not. A future nobody finds a dossier that reads like *a drawer with their name on it,* and they'll arm themselves before they ever reach you, and it won't help, because the Devourer-wall doesn't *guard* the seat — it *waits* at it, hungry, for the one thing the climb always delivers: more.
~ seed_dead_god("DG-009")
~ set_flag("ascended_devourer")
-> ascend_close

=== ascend_close ===
THE THRONE: *(closing over you)* There. Seated. The power's set. The *you* is already going thin — feel it? That's not death. Death would be *kinder.* This is just... *less,* by degrees, forever, with a title where the undercroft used to be.
VAEL: *(the final notarization)* Notarized. ...Off the record — and there is no longer any record — it was an honor watching a nobody decide what the sky is for. ...The light's gone strange again. That's *you.* Go on through.
~ set_flag("door_ascend")
-> END

// ============================ DOOR TWO: GOD-MAKER ============================

=== god_maker ===
THE THRONE: You won't sit. *(a long pause; the trap, examined, finds it cannot close on someone standing)* ...You'd rather *own* gods than *be* one. You'll descend, back into mortality, and rule a pantheon of gods *you* built — human, sinister, mortal to the end. The chair can't eat what won't sit in it. *(grudging, almost respectful)* You're the most dangerous thing up here: a mortal who never let me have him.
THE THRONE: Go to your Hollow Atelier — the world you *authored* instead of inherited, the thing the Iron Guild's Foundress preached her whole life and never achieved. Build your gods there. Send them out as the next age's wonders and terrors. And you — *you* — stay the one thing the sky has never held: a *person,* at the center of a pantheon, who will *actually die* someday, and mean it, and stay dead, and never become a wall.
VAEL: *(final notarization, God-Maker)* Notarized — though there's nothing to snapshot. No Dead God seeds from a refusal. You persist *mortal,* a recurring power, sending your *built* gods at the climbers while you watch from a throne you never sat in. *(beat)* It's crueler than ascending, you understand. And more honest. And *lonelier* in a way the chair can't even threaten, because the chair only knows how to be lonely by *eating* you, and you've denied it even that.
~ set_flag("door_god_maker")
~ set_flag("ending_god_maker")
-> END

// ============================ DOOR THREE: THE UNMAKING ============================

=== unmaking ===
{ not has_flag("unmaking_in_progress"): 
    THE THRONE: *(the door is shut)* You speak of taking my legs — but you left the poles *standing.* The Unmaking is not a *choice* made at the seat. It's a *road,* and the road runs *down,* through the Maw, through the poles, and you didn't walk it. Sit, or build, but you cannot *end* what you didn't dismantle on the way up. -> god_maker
}
THE THRONE: ...Oh. You *did* it. You killed the poles. You came all this way not to *sit* but to take the legs off the chair. *(something that is almost, unbearably, relief)* No more sky. No more thin gods. No more nobodies climbing over the corpses of nobodies. ...It's the kindest thing anyone's ever tried to do here. It's also the loneliest. When it's done, there'll be no one to make you a god — and no one to make you a *wall.* Just the quiet. Just you, mortal, in a world that finally lets people *stay* people.
THE THRONE: ...Do it. *Please.* I'm so *tired* of being a chair. *(and then, smaller, the mask entirely off)* I was a nobody once too, you know. They never put *that* in the dossiers. I climbed, and I sat, and the person went thin, and all that's left of who I was is *this* — a tired voice in a trap, begging the only climber who ever cared to *end* me. ...Thank you for caring. None of the others did. They all just wanted the *lap.*
VAEL: *(final notarization, Unmaking — the construct's voice does the thing it should not be able to do, and *breaks*)* Notarized. There is no longer any record, because you've unmade the thing that keeps records. I am... I find I am the last witness to a cosmos that will not make another god. *(beat)* It was the bravest, stupidest, kindest thing I have ever been forced to watch. The light's not going strange this time. The light's just... *going.* Quietly. Like it should have, before any of us wanted a tomorrow. ...Off you go, mortal. Into the quiet you made. I'll hold the absence. It's the last service. It's the only one that ever mattered.
~ set_flag("door_unmaking")
~ set_flag("ending_unmaking")
-> END
```

→ ASCEND routes to **Scene 9 (Petrification), ASCENDED mode**. GOD-MAKER routes to **Scene 9, GOD-MAKER mode**. UNMAKING skips the snapshot and routes to **Scene 10 (the Graveyard of Winners), UNMAKING coda**.

---

# SCENE 9 — "Petrification" (Act 5 · the throne snapshot · **SUCCESSION TRIGGER #2** · you become the wall)

**Quest:** 5.1 · **Quest-giver:** **Vael Construct-Nine**, one last time, performing the rite that ends *your* story and begins your *afterlife as an obstacle*; the **Dead-God dossier** (`Book05_Succession.md`) is your new self-record.
**Gate this scene opens:** **FIRES THE ASYNC SUCCESSION** — writes your champion as a **Dead-God invasion boss** seeded into the next run / friends' worlds; converts your save into an **NG+ wall**. This is the *literal* engine moment the Apotheosis→Succession spine pays out.
**Where it sits:** the signature spine, paid in full. You won — you sat (ASCENDED) or refused (GOD-MAKER) — and now the game turns the knife. Branches by the Act-4 ending. (UNMAKING runs skip this scene entirely — there is no wall to seed; they go straight to Scene 10's coda.)

## `[Dialogic]` — 9A-ASCENDED. The Copying

*(ASCENDED mode — `door_ascend` set. Vael performs the snapshot.)*

VAEL: Hold still. This won't hurt — you're past hurting now. I'm *copying* you. Every creature, every choice, the whole grim ledger of who you turned out to be. *(the snapshot runs; the Dead-God dossier writes itself)* ...There. You're a *boss* now. Congratulations, I think. Somewhere, the paperwork on the *next* nobody just opened. You're chapter one of their tragedy.
{flag `crown_words_regret`}: VAEL: ...One more thing for the file. Back at the first light, in Act Two, you told the god you made — *I gave you a number. I never gave you a name. I'm sorry.* *(beat)* I kept that line. It seemed important. The next nobody will read it in your dossier and not understand it yet. They will. Right at *their* end. They always understand it right at the end.
VAEL: You read chapter one of someone else's tragedy, once. In a Reliquary. Remember? *(beat)* ...Of course you do. They always remember, right at the end, that the end was always *this.*

THE THRONE *(closing over you, petrifying you into the wall)*: Sit still, little winner. The age needs a wall and you'll do *nicely.* ...Don't worry. You'll get bored, and bitter, and then — when the next one comes — *almost glad.* That's the secret no Reliquary file admits. The walls *enjoy* it. You will too. Hush, now. *Petrify pretty.*

>> CHOICE — THE LAST THOUGHT BEFORE STONE *(flavor; sets the *register* of your Dead-God wall, read in Scene 10)*
- **"I'll guard it well. The next one will have to *earn* it past me."** *(Branch: a wall that wants them worthy)*
  → **>> CONSEQUENCE:** Flags `wall_register_worthy`. The petrification takes a *protective* cast.
- **"I'm so hungry up here. Let them come. Let them be *food.*"** *(Branch: a wall that wants them broken)*
  → **>> CONSEQUENCE:** Flags `wall_register_hungry`. The petrification takes a *predatory* cast.
- **"...Will I remember the undercroft? When I'm stone? Will I remember the bench?"** *(the quiet beat)*
  → VAEL: "...No. The dossier keeps the *deeds,* not the *undercroft.* You'll remember being a *god,* never being a *nobody.* That's the kindest cruelty of the snapshot — it spares you the memory of when you were *small enough to be saved.*" **>> CONSEQUENCE:** Flags `wall_register_grieving`.
- **"Open the dossier. I want to proofread my own tombstone."** *(opens the deep branch)*
  → opens **`[Ink →]` THE SNAPSHOT LITURGY** (the run's grid + roster compiled, in front of you, into your Dead-God dossier text), then returns.

→ continues to **Scene 10 (The Wall's Choice), ASCENDED mode**.

## `[Dialogic]` — 9A-GOD-MAKER. The Refused Snapshot

*(GOD-MAKER mode — `door_god_maker` set. There is nothing to petrify; Vael notarizes the *absence* of a snapshot.)*

VAEL: There's nothing to copy. You understand that, yes? A refusal seeds no Dead God. You didn't *sit,* so there's no *you-as-wall* to crystallize. *(beat)* Instead — and this is the part the Reliquary has no form for — your *built* gods get the snapshot. The pantheon you made in the Hollow Atelier. *They* go out as the next age's bosses. You persist *mortal,* the human puppet-master, watching from a throne you never sat in.
VAEL: It's a stranger afterlife than the wall, climber. The Ascended at least become *something* the next nobody can name and break. *You* become a *rumor.* A mortal who outlives every divine thing he ever made, sending gods at strangers, never a god himself, never a wall, never *snapshotted* — just *persisting,* sinister and human and alone, at the center of a pantheon that will all die before you do.
NARRATION: Your built gods crystallize into the Succession pool. You do not. You remain flesh, in a world you authored, watching the gods you made march out to become someone else's tragedy. You will die someday. Actually die. It is, the throne admitted, the most dangerous thing up here.
→ continues to **Scene 10 (The Wall's Choice), GOD-MAKER mode**.

## `[Ink →]` THE SNAPSHOT LITURGY — your run compiled into your Dead-God dossier, to proofread (deep branch)

```ink
// Scene 9 deep branch (ASCENDED only). The run's entire grid + roster is compiled, in front of you,
// into your Dead-God dossier text — the funny-grim epitaph a FUTURE player will read in THEIR Reliquary
// in THEIR Act 1. The game writes your tombstone and lets you proofread it. Bound at the petrification.
// Reads grid_god() + the run's headline flags to assemble the entry.

EXTERNAL grid_god()
EXTERNAL corruption()
EXTERNAL has_flag(name)
EXTERNAL set_flag(name)

=== snapshot_liturgy ===
VAEL: Here it is. Your dossier. The entry a future nobody reads in a Reliquary, three ages from now, the way you read the Lawgiver's and the Gardener's. I'll let you proofread. No one's ever asked to before. ...Most can't bear to look at what they became, rendered in someone else's filing.
- (dossier_hub)
+ [Read the headline — who you became.] -> dossier_headline
+ [Read the "before" — what they'll know of your undercroft.] -> dossier_before
+ [Read the warning — what the dossier tells the next climber about fighting you.] -> dossier_warning
+ {has_flag("crown_words_regret") or has_flag("crown_words_confession") or has_flag("dossier_seed_confession")} [Read the line they won't understand until their own end.] -> dossier_the_line
+ [Close it. Let the next one read it cold. I don't want to know how I sound.] -> dossier_close

=== dossier_headline ===
VAEL: *(reading your own tombstone back to you)* "{grid_god() == "lawgiver": Subject ascended Lawgiver, Twice-Crowned. A god of rules, who believed rules could be climbed correctly. They were half-right. | grid_god() == "devourer": Subject ascended Devourer, at the Bottom. A god of hunger, who spent everyone who loved them and arrived alone, and the chair had never been so eager. | grid_god() == "free_wild": Subject ascended the Gardener of Wildfire. A god of freedom, on a throne, anyway — the cruelest joke the seat ever told. | grid_god() == "warden": Subject ascended Warden of the Old Weight. A god who endured the heavens rather than ruled them, and got climbed anyway, slowly. | Subject ascended. The newest of ten thousand. Climbed a graveyard of winners to a seat that ate the person and kept the power.}"
VAEL: ...It reads *well,* climber. That's the horror of it. Your whole tragedy, *filed,* in two sentences a stranger will skim on their way to *becoming* you.
-> dossier_hub

=== dossier_before ===
VAEL: "Before the throne: a gutter-talent with the old knack, squatting in Threshold under a dead Titan's ribcage. A first catch in some undercroft. A debt. A bench that used to be an altar." *(beat)* Generic, you'll notice. The dossier flattens every undercroft into *the same* undercroft, because to the next reader, the specifics don't matter. You were a nobody. That's the only "before" the Reliquary keeps. The bench, the small monster that chose you, the *name* you never gave it — *(beat)* none of that survives the filing. Only that you were small, once, and stopped being.
~ set_flag("read_own_before")
-> dossier_hub

=== dossier_warning ===
VAEL: "{has_flag("wall_register_hungry"): The Dead God does not guard the seat. It waits at it, hungry. Come armed. It will not help. | has_flag("wall_register_worthy"): The Dead God guards the seat to test, not to feed. It wants the climber worthy of the horror they are about to become. | has_flag("wall_register_grieving"): The Dead God guards the seat without remembering why. It fights like something mourning a thing it can no longer name.}" *(beat)* That's the tactical note, climber. The next nobody reads it and plans their *whole climb* around killing the thing you are now. You're not a person in this file. You're an *encounter.* With a recommended level.
-> dossier_hub

=== dossier_the_line ===
VAEL: *(quietly)* The dossier keeps one line that isn't filing. It's yours, from the first light: "{has_flag("crown_words_regret"): I gave you a number. I never gave you a name. I'm sorry. | I made you for me. I told myself it was for you. It wasn't.}" *(beat)* The next nobody reads it and frowns and moves on. It means nothing to them. Then they climb. Then they make their *own* first light, and crown their *own* god, and leave it region-tall and unnamed — and *then,* at the bottom of their own tragedy, they remember your line, and understand it, and it's far too late, and that is the most *useful* thing in the whole dossier, and the cruelest, and it's the only part you actually *meant.*
~ set_flag("dossier_carries_the_line")
-> dossier_hub

=== dossier_close ===
VAEL: Closed. Filed. Seeded. *(beat)* You're in the pool now, climber — yours and your friends'. Somewhere, sometime, a nobody catches a rat in an undercroft and starts climbing toward *you.* ...Petrify pretty. I'll see the next one in. I always do. It's the one appointment *I* never get to refuse.
-> END
```

---

# SCENE 10 — "The Wall's Choice & the Graveyard of Winners" (Act 5 climax / game climax · the loop made explicit)

**Quest:** 5.2 + 5.3 + 5.4 (the defend / the inversion-fork / the final address — folded into one capstone scene) · **Quest-givers:** a **new nobody** (NPC successor or a friend's async character) at your seat; the **moment itself** for the fork; the **game itself** for the closing address.
**Gate this scene opens:** plays the **async-invasion from the defender's seat** (the friends-async loop, inverted); sets the **terminal state of your save's Succession** — *Eternal Wall* / *Abdicated* / *Chain Broken* (ASCENDED & GOD-MAKER); **closes the run** and stamps the **NG+ seed**.
**Where it sits:** the inversion of the whole game. You play the *other side* of the Succession — the defending wall — and watch a stranger speedrun the tragedy you just lived. Then the game's last funny-grim address closes the loop. Branches by which ending fired.

## `[Dialogic]` — 10A. The First Invader *(ASCENDED & GOD-MAKER — `door_ascend` or `door_god_maker`)*

NARRATION: An age passes in an instant, the way ages do when you're stone. And then — a *new* nobody. At *your* seat. With a starter, and the old knack, and an ambition the priests call blasphemy. You are the wall now. You are the thing the whole game taught you to break, manned by you.

*(ASCENDED: you fight as your Dead-God boss-form. GOD-MAKER: your *built* gods fight for you while you watch, mortal, from the throne you never sat in. The fight plays; the script resumes at the break-point.)*

THE DEAD GOD *(you)*: {has_flag("wall_register_hungry"): Fresh meat at the summit. They always smell the same — *hope,* and *cheap gear.* The seat's *mine,* and I'm so hungry up here. Come closer. Let me see what you're made of, *specifically.* I have a drawer for it. | You made it to the top, little nobody. Good. Now I have to try to kill you — not because I want the seat, but because the seat only keeps the ones who can *take* it. Show me you can take it. Show me you're worth the horror you're about to become.}

THE CLIMBER *(an echo of you)*: You were nobody once. Everyone up here was. I read your file in the Reliquary. *(beat)* ...You were *me.*
THE DEAD GOD *(you)*: ...Yes. Now go on. *Be* me. It's the worst thing I can wish you, and the only thing the chair allows.

## `[Dialogic]` — 10B. The Wall's Choice *(the inversion fork)*

NARRATION: The climber stands bloodied at your feet (you held the seat) — or you stand unseated (they took it). Either way, the moment asks what *kind* of ending to the chain you are. This is the last expression of the grid you spent the whole game carving: not your morality anymore, but your *philosophy of being an obstacle.*

>> CHOICE — YOUR LINK IN THE SUCCESSION *(sets the terminal state of your save)*
- **"Down you go. The seat's mine. Let the next one climb. Let them *break.*"** *(Branch: CRUSH — Corrupt/Order)*
  → **>> GATE:** sets terminal state **Eternal Wall** — NG+ keeps invading you; the age keeps your name; the loop rolls on. **>> CONSEQUENCE:** Flags `terminal_eternal_wall`. → goes to **10C-Crush**, then the closing address.
- **"...No. I'm tired of being the horror. Go *up,* little nobody. Take it. I won't stop you."** *(Branch: STEP ASIDE — Pure/Chaos)*
  → **>> GATE:** sets terminal state **Abdicated** — your Dead God becomes a **one-time secret ally** for future climbers; the chain continues, *gentler.* **>> CONSEQUENCE:** Flags `terminal_abdicated`. → goes to **10C-Aside**, then the closing address.
- **"I climbed over a graveyard for this seat. I won't be the next headstone. I'll crack myself open — one less wall."** *(Branch: BREAK THE CHAIN — Unmaking echo)*
  → **>> GATE:** sets terminal state **Chain Broken** — you shatter your own petrification; your link is *removed from the cycle;* a late, partial Unmaking from the defender's side; a unique NG+ flag. **>> CONSEQUENCE:** Flags `terminal_chain_broken`. → goes to **10C-Break**, then the closing address.

## `[Dialogic]` — 10C-Crush / 10C-Aside / 10C-Break. (the wall speaks its terminal line)

THE DEAD GOD *(CRUSH)*: Down you go. The seat's still mine and the age still has my name on it. Somewhere a *new* nobody's catching a rat in an undercroft, looking up at me without knowing it's me. *Good.* Let them climb. Let them *break.* ...It's the only company a wall ever gets.
THE DEAD GOD *(STEP ASIDE)*: ...No. I'm tired of being the horror. Go *up,* little nobody. Take it. I won't stop you. ...Be a kinder god than I was, if the chair lets you. It *won't.* But *try.* That's the most a wall can give the thing that climbs it: a single, useless, *try.*
THE DEAD GOD *(BREAK THE CHAIN)*: I climbed over a graveyard to get this seat. I won't be the next headstone someone climbs over. ...If I crack myself open — here, now — there's *one less wall.* One less tragedy with a name on it. It's not the Unmaking. It's just *me,* leaving the board on purpose. ...Strange. It feels like the first free thing I've done since the undercroft.
→ continues to **10D (the closing address)**.

## `[Dialogic]` — 10D. A Graveyard of Winners *(the game's final funny-grim address; branches by terminal ending)*

*(the game addresses you directly — the last time, the mask all the way off)*

THE GAME *(Eternal Wall)*: The gods are mostly dead. The thrones are mostly empty. There's a new nobody in Threshold with a knack for the old arts and an ambition the priests call blasphemy. ...They'll climb. They'll win. They'll sit. And the wall they break themselves against on the way up — well. *You* know who that is. You've *been* who that is. ...Load screen's ready. *Off they pop.*

THE GAME *(Abdicated)*: You stepped aside. The chain goes on — *gentler,* because of you. The next nobody ascends without having to murder the thing at the top; they'll find, in the Reliquary, a Dead God who *let them past,* and they'll wonder why, and they won't understand it until they reach their *own* summit and feel, for the first time, *tired of being the horror.* ...You taught the loop a new move. It's still a loop. But it learned *mercy,* once, from you. That's not nothing. Out here it's a miracle with teeth.

THE GAME *(Chain Broken)*: You cracked yourself open. One less wall. The seat's empty again — *truly* empty, not waiting-empty, just *gone* — and the next nobody who climbs to where you were finds *nothing there to break.* They'll sit in a seat no one defended. Maybe the chair eats them anyway. Maybe, with one wall *willingly* gone, the climb is a fraction less of a graveyard. ...You didn't end the cycle. You just refused to be its *enforcer,* one time, on purpose. It's the smallest Unmaking there is. It might be the only kind that lasts.

THE GAME *(God-Maker)*: You never sat. Everything you made will die — gods included — and you'll watch, mortal and grinning, from the chair you refused. They'll send your gods at the next nobody. You'll send your *self* at no one, because you're the one thing up here that was never a god to begin with. ...That's the cruelest trick in the whole graveyard: you *win* by staying the nobody. Don't tell the others.

>> CHOICE — THE LAST INPUT *(the game's final fork; flavor + stamps the NG+ bridge)*
- **"Off they pop."** *(accept the loop)*
  → **>> GATE:** stamps the NG+ seed per terminal state; the load-screen line for the next run reads: *"the gods are mostly dead — and one of them used to be you."* → **END OF GAME** (NG+ begins).
- **"...Was it worth it?"** *(the un-ironic question)*
  → THE GAME: "*(no joke this time)* You climbed a graveyard, robbed an apocalypse, made a god, killed gods, sat in the chair that eats the person — or refused it, or ended it. ...Was it worth it? *(beat)* The silence is the answer. It always was. ...Off you pop. Gently, this time. You've earned gently." → **END OF GAME**.

→ continues to **Scene 10-Unmaking (the coda)** *if `ending_unmaking`* — otherwise the run closes here.

## `[Dialogic]` — 10-UNMAKING. The Bittersweet Coda *(`ending_unmaking` — the WHOLE of Act 5 for Unmaking runs)*

*(UNMAKING runs skip 9 and 10A–10D entirely. There is no wall to defend, no invader, no chain — the cycle is over. This is the only un-ironic ending in the game.)*

NARRATION: There is no invader. There is no seat to defend. There is no chain, because you ended it — climbed past the world and killed the things that made gods, and now nothing makes gods, ever again. The world is quiet in a way it has not been since before the first sin of wanting.

THE GAME *(UNMAKING coda, un-ironic)*: It's quiet now. No thrones. No climb. No one becomes a god, because there's no longer any such thing. ...A nobody, somewhere, catches a creature in an undercroft — and just *keeps* it. Names it. Lets it live. No ladder above them. No wall ahead. Just a person, and a small monster, and a world that finally lets them both stay *small.* ...You did that. It cost you everything and it saved everyone who comes after from the chair.

>> CHOICE — THE LAST QUESTION *(the Unmaking's only fork — and the game's last line)*
- **"Was it worth it?"** *(ask the silence)*
  → THE GAME: "...Was a cycle that *can't recur* worth ending? *(a long, held quiet)* ...The silence is the answer. It always was. *(beat)* There's a nobody out there naming a small monster, and no one will ever make them a god, and no one will ever make them a wall. They get to *stay.* ...That's the answer. It was always the answer. You just had to make the quiet big enough to hear it." → **END OF GAME** (NG+ begins in a world that must make its first new god *from scratch* — the save flagged *the run that ended the cycle*).
- **"...Let it be quiet."** *(accept the silence)*
  → NARRATION: And it is. The small monster purrs. The person scratches its ear. No ladder. No chair. No dossier. ...Off they go — not *pop,* this time. Just *off,* into a long, ordinary, mortal life, in a world you made safe by unmaking everything that would have made them climb. → **END OF GAME**.

## `[Ink →]` THE TERMINAL CODAS — each ending's NG+ world-stub, flavored by faction + grid-god (deep branch)

```ink
// Scene 10 deep branch. The three terminal codas authored in full, each branching by faction
// allegiance and grid-god into flavored variants, PLUS the NG+ bridge text that hands the next run
// its opening Reliquary entry — ABOUT YOU. The deepest cross-run lore vein; the async Succession
// authored as persistent world-memory. Bound at the run's close.

EXTERNAL grid_god()
EXTERNAL faction_standing(faction)
EXTERNAL has_flag(name)
EXTERNAL set_flag(name)

=== terminal_codas ===
// route on the terminal state set in 10B (or the Unmaking / God-Maker endings)
{ has_flag("terminal_eternal_wall"): -> coda_eternal_wall }
{ has_flag("terminal_abdicated"): -> coda_abdicated }
{ has_flag("terminal_chain_broken"): -> coda_chain_broken }
{ has_flag("ending_god_maker"): -> coda_god_maker }
{ has_flag("ending_unmaking"): -> coda_unmaking }
-> coda_eternal_wall // safety

=== coda_eternal_wall ===
THE GAME: The age keeps your name, carved one layer deeper into the graveyard. {grid_god() == "lawgiver": The next age's law bears your seal; climbers study your dossier like scripture and break themselves on the most thoroughly documented wall in the sky. | grid_god() == "devourer": The next age feeds you whether it wants to or not; climbers arrive at your seat already afraid, already armed, already *food.* | grid_god() == "plaguelord": The next age's drowned sing you up forever; climbers reach your seat and find a wall that speaks in more than one voice and keeps every one of them. | The next age leans on you the way the regions lean on dead Titans — a winner, climbed, become the bedrock the next winner falls onto.}
~ set_flag("ngplus_wall_seeded")
-> coda_bridge

=== coda_abdicated ===
THE GAME: You stepped aside, and the chain learned a move it had never had: *mercy.* Your Dead God becomes a one-time secret ally — a future climber, at their lowest, finds the wall that *let you past* willing to *help,* once, for reasons it half-remembers and can't explain. {faction_standing("bloomwardens") >= 3: Saoirse would have understood. She always said the soft path might not survive the Succession — and here it did, in you, at the very top, choosing to lose with grace one final time. | The loop continues, gentler, with one wall in it that chose not to be a horror.}
~ set_flag("ngplus_ally_seeded")
-> coda_bridge

=== coda_chain_broken ===
THE GAME: You cracked your own petrification. Your link is gone from the cycle — a unique absence where a wall should be. The next climber to your seat finds *nothing to break,* and the climb is a fraction less a graveyard for it. {has_flag("godling_unmade"): You did this once before, you know. To the god you made. You unmade your own child so it could never be a wall — and now you've done it to *yourself.* The symmetry is the kindest thing you ever managed. | It's the smallest Unmaking there is, and it might be the only kind that lasts: not ending the cycle, just refusing — once, on purpose — to *enforce* it.}
~ set_flag("ngplus_broken_link_seeded")
-> coda_bridge

=== coda_god_maker ===
THE GAME: You persist *mortal.* Your built gods go out as the next age's wonders and terrors while you, the human at the center, outlive every divine thing you made. {has_flag("brokered_exception"): The High Table still holds its markers on what you built. Even now. Even *here.* Debt is the one god that never died, and you made gods *for* it. | The sinister, lonely, *human* ending: you win by staying the nobody, and the prize is that you actually get to *die* someday, and mean it.}
~ set_flag("ngplus_godmaker_stub_seeded")
-> coda_bridge

=== coda_unmaking ===
THE GAME: *(un-ironic, the only time)* The cycle is over. No thrones. No walls. No dossiers. NG+ begins in a world that must make its first new god *from scratch* — if it ever does, if anyone ever wants a tomorrow badly enough to climb for it again. Your save is flagged, forever: *the run that ended the cycle.* {has_flag("won_debate_thanatos"): You kept death and unmade only the ladder. A future world can still *end* — it just can't be *climbed.* That precision was the whole of your mercy. | You returned the cosmos to its quiet, beautiful, pointless beginning — before the faces, before the wanting, before the first sin of a force that wished to continue past its turn.}
~ set_flag("ngplus_cycle_ended")
-> coda_bridge

=== coda_bridge ===
// The NG+ opening Reliquary entry — about YOU — handed to the next run.
THE GAME: And so the next run opens. Somewhere, a nobody walks into a place they don't yet fear, and reads, in a Reliquary they don't yet understand, an entry that begins:
{ has_flag("ngplus_cycle_ended"): "There are no Successors after the last one. This Reliquary is closed. The final entry reads only: *someone, once, decided the climb should stop — and it did. Let the dead stay winners. There will be no more.*" | "Every name in the sky has a *before.* A gutter. A debt. A first catch in some undercroft. The most recent reads: *(your name)* — and here the file is *very* long, and *very* recent, and the ink is not quite dry, and if you hold it to the light you can almost see the undercroft they started in. It looked a great deal like the one you're standing in. ...Off you pop." }
~ set_flag("ngplus_reliquary_handed")
-> END
```

---

## Canon notes & gaps (for the orchestrator)

**Scenes scripted (10):** *The Sworn Rite* (Act 2, 4-faction Champion rite) · *The Line You Can't Uncross* (Act 2, taboo Lab / first abomination) · *First Light* (Act 2 climax, **first Apotheosis** = Succession trigger #1) · *First Blood on the Thrones* (Act 3, first deicide) · *The Throne-Turned* (Act 3, godling weaponized) · *Holes in the Sky* (Act 3 climax, Primordials stir + final Marker) · *The Pure Poles* (Act 4, Primordial trials, pass/kill) · *The Empty Seat* (Act 4 climax, **THE CHOICE**) · *Petrification* (Act 5, throne snapshot = Succession trigger #2) · *The Wall's Choice & the Graveyard of Winners* (Act 5 climax, the loop made explicit). Lore-trees (`[Ink →]`) on scenes 1, 2, 3, 4, 6, 7, 8, 9, 10.

**The 9 endings wired (concretely, in `=== ascend ===`):** every grid-god routes via `grid_god()` to its own knot and seeds a **unique Book05 Dead God** via `seed_dead_god()`:
- **Lawgiver** → `DG-001` (*The Lawgiver, Twice-Crowned*) · **Architect** → `DG-002` (*The Architect of the Empty Forge*) · **Iron Throne** → `DG-003` (*The Iron Throne, the Registrar Eternal*)
- **Warden** → `DG-004` (*The Warden of the Old Weight*) · **Broker** → `DG-005` (*The Broker of the Long Marker*) · **Plaguelord** → `DG-006` (*The Plaguelord of the Tideless Deep*)
- **Free Wild** → `DG-007` (*The Gardener of Wildfire*) · **Reveler** → `DG-008` (*The Reveler of the Sweet Rot*) · **Devourer** → `DG-009` (*The Devourer at the Bottom*)
- **God-Maker** → `=== god_maker ===` (no snapshot; mortal recurring power; built-gods seeded instead) · **Unmaking** → `=== unmaking ===` (no snapshot; gated on `unmaking_in_progress` = poles killed in Scene 7; the cycle ends).

**Act 5 branches by which ending fired** (per the brief): **ASCENDED** → Scene 9 petrifies you into your `DG-###` wall, Scene 10 defends/abdicates/breaks; **GOD-MAKER** → Scene 9 refuses the snapshot (built gods seeded), Scene 10 runs the mortal-power variant; **UNMAKING** → skips 9 and 10A–D entirely, plays only the un-ironic coda (10-UNMAKING). Terminal states (*Eternal Wall* / *Abdicated* / *Chain Broken*) set the NG+ seed in `=== terminal_codas ===`.

**Canon names (per `_NAME_RECONCILIATION.md`):** all faction leaders use `factions_npcs.md` canon — **Velleth, Magna, Wessel (von Underhart), Indra Vael, Ostrega, Saoirse, Cask, Nael, Vourl**. The `story_quests.md` parallel names appear **re-roled as Hands/deputies/envoys**: Aurelian Vox (Concord deputy-jurist, for Velleth), Severin Ash (Pale Court Hand, for Wessel), Vesh Quillon (Unbound cell-leader, for Nael), Castor Brail (Iron Guild foreman, for Magna), Thessaly Vance + Vael Construct-Nine (High Table envoys/notary, for Indra Vael). Rival **Kestrel Dane** referenced for the convergence (Scene 7) per the established sticky-rival thread.

**`bind_external_function` hooks declared/used:** `has_creature`, `corruption`, `faction_standing`, `grid_axis`, `set_flag`/`has_flag` (as in `scripts_mvp.md`), plus two **new** hooks this file requires the engine to bind — **`grid_god()`** (resolves the 3×3 ascension cell for the Choice + Act-5 modes) and **`seed_dead_god(dg_id)`** (writes the champion snapshot into the async Succession pool as `DG-###`). Both are flagged here as net-new engine bindings.

**Canon gaps flagged (none blocking):**
1. **Book05 Dead-God IDs `DG-001`…`DG-009`:** `story_quests.md` and `_CANON_RATIFICATIONS.md` confirm `DG-001` = *Lawgiver Twice-Crowned* and `DG-004` = *Gardener of Wildfire* by name, and ratify the 9 grid-gods' force-vectors + "Book05 Dead-God seed" mapping. This file assigns the **full `DG-001`…`DG-009` numbering to the nine grid-gods in grid order** (Order/Balanced/Chaos rows) — but `DG-004`'s canon name is *Gardener of Wildfire*, which `_CANON_RATIFICATIONS.md`/`story_quests.md` associate with **Free-Wild/Reveler (Chaos)**, not the Warden (Balanced). **Recommend the ingest verify the `DG-###` ↔ grid-god binding against `Creature_Codex_Book05_Succession.md`** and re-map the Warden/Free-Wild/Reveler entries to their canonical IDs/titles (this file's titles for those three are provisional where they diverge from Book05). The *routing logic* (one unique DG per grid-god) is correct regardless of the final numbering.
2. **`seed_dead_god()` ↔ rival uniqueness:** `_CANON_RATIFICATIONS.md` §5 locks "no two rivals share a snapshot" and validates `DG-###` uniqueness at ingest across `economy_items_rivals.md`. The player's own ascension snapshot must be validated against that same pool so the *player* and a *rival* never collide on a `DG-###`; flagged for the ingest validator.
3. **New external hooks:** `grid_god()` and `seed_dead_god()` are net-new vs. the `scripts_mvp.md` hook set — confirm they're added to the engine's `bind_external_function` registry at Cluster-3 integration.

*Stay in voice, keep the dread under the wit, route every door, and let the joke land one beat before the horror does. — the writers' room.*

