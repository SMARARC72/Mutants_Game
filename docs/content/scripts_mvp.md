# MUTANTS_GAME — MVP-Region Branched Scripts (Threshold hub + Verdant Glut / Bloomwardens)

**Author:** lead narrative scripter pass · **Status:** production-ready scripts v0.1 · **Date:** 2026-06-28
**Source canon read:** `Content_Generation_Brief.md`, `_CANON_RATIFICATIONS.md`, `content/story_quests.md` (Act 0/1 + Verdant), `content/factions_npcs.md` (exact NPC names), `content/voice_library.md`, `content/regions.md` (Verdant Glut MVP cast), `content/skills_statuses.md` (the 8 verbs).
**Voice:** funny-grim, mature-occult. Dread is bedrock; the wit is the relief valve. *If a line makes you laugh and then slightly regret laughing, it's on-tone.*

---

## How to read these scripts (the contract for the implementers)

Two interleaved formats, used where each is strongest:

- **`[Dialogic]` timelines** — linear authored beats for the moment-to-moment scenes. Each entry is `SPEAKER: line`. Player choices are `>> CHOICE` blocks with 3–4 options where the decision matters; every option states its **branch tag** (the morality-grid lean) and its **>> GATE/CONSEQUENCE** inline (Lab unlock · capture target · region access · standing tier · corruption shift). Branches that diverge into genuinely different scenes are marked `→ goes to [scene/knot]`.
- **`[Ink →]` knots** — for the sprawling/branching lore-trees. Standard Ink: `=== knot ===`, choices `* [text]` / sticky `+ [text]`, diverts `-> knot`, conditionals `{condition: ...}`, and **external function hooks** declared at the top and bound by the engine:
  - `EXTERNAL has_creature(force)` → bool · does the player roster contain a creature of this force/tag
  - `EXTERNAL corruption()` → int 0–100 · the universal Corruption meta-meter
  - `EXTERNAL faction_standing(faction)` → int (0 Stranger · 1 Associate · 2 Sworn · 3 Champion · 4 Hand)
  - `EXTERNAL grid_axis(axis)` → int -100..100 · `"order_chaos"` (−Order/+Chaos) and `"purity_corruption"` (−Pure/+Corrupt)
  - `EXTERNAL set_flag(name)` / `EXTERNAL has_flag(name)` → grid/quest bookkeeping

**Canon conventions kept exact:** 6 forces (Gaia·Ouranos·Cosmos·Chaos·Eros·Thanatos), the 8 verbs (Strike·Drain·Ward·Mend·Hex·Rouse·Summon·Gambit), the morality grid (Order⇄Chaos × Purity⇄Corruption → the 9 gods), the Lab ops (Mutate·Fuse·Build·Mod·Sacrifice·taboo), currencies **Drachma ₯ · Essence ✶ · Ichor ◈**, standing ladder (Stranger→Associate→Sworn→Champion→Hand). NPC names are taken from `factions_npcs.md` and `regions.md` as the source of truth (see **Canon gaps** at the foot of the file for the one reconciliation note).

**Scene index (8 scenes):**
1. *The Knack* — Threshold, the Foundling Pens (tutorial catch · unlocks Capture + roster)
2. *Altar Hours* — Threshold, the rented Lab bench (tutorial Mutate · unlocks Lab — Mutate)
3. *The Mark* — Threshold back-alley → High Table (inciting incident · sets starting grid + Arena/High Table)
4. *Registered* — Threshold Arena (Act 0 climax · opens Act 1 travel + faction-courting)
5. *Greener Pastures, Hungrier Ones* — Verdant Glut fringe / Bloomwardens (region access · unlocks Lab — Mod)
6. *The Mercy-Garden* — Verdant Glut, Matron Sevvy's infirmary (Mend skill line · husbandry boost · the soft creed bites)
7. *What the Glut Won't Bury* — Verdant Glut, the Pale Court at the seam (deep heart-grove access · Eros Legendary target)
8. *The Guardian at the Seal* — Verdant Glut, the Throat of the Glut (MVP Legendary capture/kill · Act 1 capstone)

Lore-trees (`[Ink →]`) hang off scenes 2, 3, 5, 7, 8.

---

# SCENE 1 — "The Knack" (Threshold · the Foundling Pens · tutorial catch)

**Quest:** 0.1 · **Quest-giver:** Old Maddox Quillan (tutorial mentor, the Knack-Hut) + Mother Kestrel (Foundling Pens warden, per `regions.md`).
**Gate this scene opens:** unlocks **Capture** + the **roster**; logs the first **Purity/Corruption** tick.
**Where it sits:** the player's first ten minutes. Gentle. Threshold is kind on purpose; the kindness has an expiry date.

## `[Dialogic]` — 1A. The Knack-Hut

MADDOX: First rule, and it's the only one I'll give you for free: a creature you catch can love you. A creature you build owes you. Neither one's safe. Welcome to the craft.
MADDOX: You've got the old knack. Lucky you. The last three people I taught it to are dead, dead, and a minor god of drainage. Mixed results.
MADDOX: Go down to the Foundling Pens. Municipal menagerie — orphaned hatchlings nobody claimed. Mother Kestrel runs it. She won't *give* you one. You have to let one choose you. That's the whole trick of the gentle path: you wait to be wanted.
MADDOX: *(quieter)* Go on, catch the wounded one, if it comes to it. It's mercy *and* math. That's most of what this is.

*(player walks to the Pens — fixed hand-authored hub corridor, per regions.md traversal note)*

## `[Dialogic]` — 1B. The Foundling Pens

KESTREL: So you're Maddox's new stray. He sends me one a season. I bury most of what he sends. Don't take it personal — the *job* buries most of everything.
KESTREL: I don't hand them out. Walk the rows. Let one come to you. The bond starts the moment something decides you're worth the risk. *(beat)* Most of them won't. They've got better instincts than you do. That's not an insult. It's the menagerie.

*(the player walks the rows; one Eros-fringe hatchling — a Sporekin / a wild Glut-fringe sproutling — limps to the bars. It is hurt. A second, healthier hatchling watches from the back, wary.)*

KESTREL: There. The little one with the bad leg. It picked you. Or it picked the first warm thing that didn't flinch. Out here those are the same choice. *(beat)* Now — how do you want to do this. This is the part that tells the world what kind of person showed up today.

>> CHOICE — THE FIRST CATCH *(this fires the first grid tick; all three teach the Capture verb)*
- **"Offer my hand. Let it come the rest of the way."** *(Branch: PURE — befriend)*
  → **>> GATE:** unlocks **Capture (Befriend path)** + roster. Starts the bond **warm**. **>> CONSEQUENCE:** `purity_corruption −10` (toward Pure). Flags `first_catch_clean`. → goes to **1C-Pure**.
- **"Bind it fast — wound-and-cinch. It's already hurt; I'll be quick."** *(Branch: CORRUPT — trap-on-the-wounded)*
  → **>> GATE:** unlocks **Capture (Trap path)**. Catch is **faster**, nicks the creature's **Vitality (Eros)**, bond starts **cold**. **>> CONSEQUENCE:** `purity_corruption +10` (toward Corrupt); `+entropy` on the creature. Flags `first_catch_harsh`. → goes to **1C-Corrupt**.
- **"Let the healthy one and the runt settle it first. I'll take the survivor."** *(Branch: CHAOS — let it half-eat a rival first)*
  → **>> GATE:** unlocks **Capture (Trap path)**; you catch the **winner** (a tier stronger, but the bond is feral). **>> CONSEQUENCE:** `order_chaos +10` (toward Chaos); the runt is logged to the **Graveyard** (first headstone). Flags `first_catch_wild`. → goes to **1C-Chaos**.

## `[Dialogic]` — 1C-Pure. (clean catch)

*(toast, from voice_library §5.1):* **"It chose you. That'll mean more than any cage ever could."**
KESTREL: Gentle hands. The gods had those once. Look how that ended for them. *(beat, almost fond)* It's bonded warm. That's rare and it's a liability — the ones you love don't end up on the table. *Mostly.* Off you go. Maddox'll want to see you didn't die.
MADDOX *(on return):* Clean. Good. The world keeps a ledger on you starting now, and your first line reads *kind.* Enjoy that. It's the cheapest the kindness will ever be.
→ converges to **Scene 2 (Altar Hours)**.

## `[Dialogic]` — 1C-Corrupt. (wound-and-bind)

*(toast, from voice_library §5.3):* **"Snared. It will not forgive this, and it will be *excellent* at not forgiving it."**
KESTREL: *(watches the leg, says nothing for a moment)* Works, don't it. Faster. Costs the beast something. Costs you a little more. You'll stop noticing — that's the trouble. *(beat)* It's yours. It's cold. Feed it by hand a week if you want it to stop watching the door.
MADDOX *(on return):* Efficient. Huh. Your first line in the ledger reads *practical.* That's a word that does a lot of quiet work in this city. Means *I did the necessary thing and didn't ask whose face it wore.*
→ converges to **Scene 2 (Altar Hours)**.

## `[Dialogic]` — 1C-Chaos. (let them fight)

*(toast — combining voice_library §2.5 + §5.3):* **"Caught the hard way. The bond starts cold. A new name in the ledger — and a headstone, fresh-cut, beside it."**
KESTREL: *(grim)* That's one way. The strong one's yours now and it learned its first lesson off the body of its kin. It'll be *good.* It'll also never quite trust the quiet. *(beat)* The runt goes in the Yard. Goodwife Penne logs them all. I'll walk it over myself. Someone decent should.
MADDOX *(on return):* You let them sort it out. The ledger calls that *wild.* The Revel calls it *Tuesday.* They'll like you for it, eventually. Like is the wrong word for what the Revel does, but it's the closest one that won't frighten you off this early.
→ converges to **Scene 2 (Altar Hours)**.

---

# SCENE 2 — "Altar Hours" (Threshold · the rented Lab bench · tutorial Mutate)

**Quest:** 0.2 · **Quest-giver:** Surgeon-Lab-Tech Veil (Lab services, beside your Threshold Lab — the canonical Threshold lab figure per `factions_npcs.md` #3).
**Gate this scene opens:** unlocks the **Lab — Mutate** operation + the **entropy / Instability** meter; tutorializes the cost ledger.
**Note:** `story_quests.md` names this quest-giver "Quintus Slagg"; the canonical Threshold lab-services NPC is **Surgeon-Lab-Tech Veil** (see Canon gaps). Veil is used.

## `[Dialogic]` — 2A. The Bench That Breathes

VEIL: So. You caught something. Now you'll want to *improve* it, because nobody who learns the knack has ever once left well enough alone. This bench took prayers for four hundred years. Now it takes specimens and a deposit. Progress.
VEIL: *(flat)* This is a Mutate. One creature in, the same creature out — more, and less calm about it. Entropy's the price of pushing too hard, too fast. It does not refund. Watch the meter. It's the only honest thing in this room, present company included.
VEIL: Pick your method. Cosmos-precise or Chaos-wild. One's expensive. One's a *surprise.* I keep a mop for the surprise.

>> CHOICE — THE METHOD *(both teach Mutate + the entropy meter; the fork seeds Order vs. Chaos)*
- **"Precise. Slow, sure, costed to the drachma."** *(Branch: ORDER — Cosmos-precise)*
  → **>> GATE:** unlocks **Lab — Mutate (precise setting)** — deterministic outcome. **>> COST:** Drachma ₯ + a fixed **entropy** tick. **>> CONSEQUENCE:** `order_chaos −10` (toward Order). → goes to **2B-Order**.
- **"Wild. Cheap. Roll the bones and let the genome argue back."** *(Branch: CHAOS — Chaos-wild)*
  → **>> GATE:** unlocks **Lab — Mutate (wild setting)** — random trait, small **botch** chance. **>> COST:** cheap (low ₯), higher entropy variance. **>> CONSEQUENCE:** `order_chaos +10` (toward Chaos). → 60% goes to **2B-Wild-Good**, 40% to **2B-Wild-Botch**.
- **"What does it cost me that isn't coin?"** *(info — no commit; loops back, opens the lore-tree)*
  → VEIL: "Entropy on the creature. A little of your patience. And if you go wild and it curdles — a story you'll tell badly at parties. Sit. I'll tell you what this bench *was,* if you're stalling. Everyone stalls." → opens **`[Ink →]` THE ALTAR'S HISTORY** (knot below), then returns to the choice.

## `[Dialogic]` — 2B-Order. (precise success)

*(reveal toast, voice_library §4.3):* **"It's done. Something opened its eyes that did not have them an hour ago."**
VEIL: Slow, sure, pricey. The Concord way. You'll fit right in with the people who fold their socks. *(beat)* Clean result, exactly to spec. No screaming. I'll be honest — I prefer the screaming ones, professionally. They're more interesting. But you'll *live* longer doing it your way, and longevity's the rarest stat in this city.
→ converges to **Scene 3 (The Mark)**.

## `[Dialogic]` — 2B-Wild-Good. (wild, lucky)

*(reveal toast, voice_library §4.3):* **"Out of the parts and the prayer: a thing that is wholly new and entirely your fault."**
VEIL: *(genuine, rare warmth)* Oh, that's a *good* roll. Look at it. You couldn't make that twice if the bench loved you, and the bench loves no one. The Revel would weep. Keep it. Variance is the only place this craft ever gives you something for nothing — and even then it's lying about the *nothing.*
→ converges to **Scene 3 (The Mark)**.

## `[Dialogic]` — 2B-Wild-Botch. (wild, curdled)

*(botch toast, voice_library §4.4):* **"The wild method paid out in the wrong currency. Meet your mistake. It breathes anyway."**
VEIL: *(beat, deadpan)* Huh. It's got an extra one of those now. Two, actually. We do not refund extra ones of those. *(grabs the mop, doesn't use it yet)* It lived. That was not, strictly, the goal. But it lived, and out here that's the whole low bar, and you cleared it sideways. Congratulations, I think.
VEIL: Don't look like that. Every geneticist worth the bench has a drawer of these. Mine's a *cabinet.* Yours starts today.
→ converges to **Scene 3 (The Mark)**. *(Botch flags `lab_first_botch` — referenced later by the Revel and by Old Garran in Scene 5/6 for warmer reactions.)*

## `[Ink →]` THE ALTAR'S HISTORY — optional lore-tree (the Concord-vs-Unbound seed)

```ink
// Scene 2 deep branch. Bound at the Threshold Lab bench.
// Seeds the player's first *feeling* about Order (the Concord) vs the Unbound,
// long before either faction is courtable. Pure flavor + one grid nudge.

EXTERNAL grid_axis(axis)
EXTERNAL set_flag(name)

=== altar_history ===
VEIL: Four hundred years this slab took prayers. Some god you've never heard of — the city converted the altar the year the thrones went cold. Knocked the idol off, bolted on a vise, called it a workbench. Nobody asked the god. The god was past asking.
* [Which god?]
    VEIL: Minor. Local. A patron of *thresholds*, fittingly — doorways, borders, the moment you cross from one thing to the next. The city's named for a dead Titan; the *bench* is named for nothing, because we melted its name down for scrap along with the idol.
    -> altar_choice
* [Did converting it... do anything? To the work?]
    VEIL: Officially? No. The Concord would tell you a sanctified altar holds no residual force once deconsecrated — they have a *form* that says so, in triplicate. Unofficially, every wild Mutate I've run on this slab rolls a little *stranger* than it should. Draw your own conclusion. Mine's filed under "do not file."
    ~ set_flag("knows_altar_residual")
    -> altar_choice

=== altar_choice ===
VEIL: So which is it. You the kind who trusts the form that says the slab is clean — or the kind who trusts the screaming?
+ [The form. Order is order; a deconsecrated altar is just furniture.] -> trust_order
+ [The screaming. Something's still in the stone, and I'd rather know it than file it away.] -> trust_wild
+ [Neither. It's a table. I have a creature to improve.] -> pragmatic

=== trust_order ===
VEIL: The Concord answer. You'll get on with them. They refilled the thrones lawfully last age — went poorly, but *correctly,* and they'd do it again exactly the same, which is either integrity or a diagnosis.
~ grid_axis("order_chaos") // engine reads this as a small −Order nudge
~ set_flag("leans_concord_early")
-> END

=== trust_wild ===
VEIL: The honest answer, and the one that gets people hunted. There's a faction past the edge of the map — the Unbound — who'd say the stone *remembers,* and remembering is the only true thing, and the forms are how the comfortable look away. I don't agree with them. I don't *disagree* loudly. I keep a mop.
~ grid_axis("order_chaos") // small +Chaos nudge
~ set_flag("leans_unbound_early")
-> END

=== pragmatic ===
VEIL: *(almost approving)* Good. Philosophy's for people whose creatures aren't bleeding. Back to the bench.
-> END
```

---

# SCENE 3 — "The Mark" (Threshold · back-alley → High Table · the inciting incident)

**Quest:** 0.3 · **Quest-giver:** emergent (a street-godling, no name) → resolved by **Vael Construct-Nine** (High Table envoy, per `factions_npcs.md` recurring NPC).
**Gate this scene opens:** sets the player's **starting grid coordinate**; unlocks the **Arena** (Threshold competition hub) + the **High Table** standing track (Stranger). The Purity⇄Corruption choice here is the single heaviest tick in Act 0.
**Where it sits:** the obscenity the whole game is built on, introduced as a choice you don't yet know you're making — you survive a dead thing's mark and become *a problem worth contracting.*

## `[Dialogic]` — 3A. The Wrong Alley

*(ambient, voice_library §7.1):* "Mind the Graveyard district after dark. Some of the headstones have opinions now."

NARRATION: It comes out of the dark between two embassies — a street-godling, a feral knot of loose force with no name and worse manners. A leftover of something that used to be worshipped, now just hungry. Your creature meets it. The fight is real, and brief, and then the godling does the thing that should kill you: it *marks* you. A Primordial-tint brand, straight into the marrow. You should be a smear on the cobbles.
NARRATION: You are not a smear on the cobbles. You are standing there, glowing wrong, and the godling is backing away from *you* now, which is new, and not comforting.

>> CHOICE — THE GODLING'S FATE *(fires before Vael arrives; first of the scene's two grid ticks)*
- **"Let it go. It was hungry, not evil. Aren't we all."** *(Branch: PURE — spare)*
  → **>> CONSEQUENCE:** `purity_corruption −10`. The godling slinks off; logged as a future befriend-able re-encounter (flags `spared_godling`). **>> CONSEQUENCE:** Bloomwarden first-impression warms a notch (read in Scene 5).
- **"Harvest it. A fresh godling-organ is the best Lab stock a nobody will ever touch."** *(Branch: CORRUPT — harvest)*
  → **>> GATE:** drops your **first god-adjacent ingredient** into the Parts Drawer (flags `harvested_godling`). **>> CONSEQUENCE:** `purity_corruption +15` (heavy). Pale Court first-impression warms (read in Scene 7).
- **"Bind it. A marked starter's worth nothing; a *captured godling* is worth a story."** *(Branch: CHAOS — capture the feral)*
  → **>> GATE:** registers the godling as a **feral high-tier capture target** you can pursue later (flags `bound_godling`). **>> CONSEQUENCE:** `order_chaos +10`. The Revel and the High Table both clock the audacity.

## `[Dialogic]` — 3B. The Clipboard With No Soul

*(Vael Construct-Nine materializes — High Table envoy, the recurring notary of your whole story.)*

VAEL: You were marked by a dead thing and failed to die. Statistically, you are now a problem. The High Table prefers its problems *contracted.*
VAEL: Allow me to be precise, because I am only ever precise: a Primordial-tint brand in mortal marrow is, in nine hundred ninety-nine cases of a thousand, a very brief and very loud way to stop existing. You are the thousandth case. The Table finds the thousandth case *fascinating,* the way a gambler finds a long-shot fascinating — which is to say, we have already opened a line on you, and the line is not generous.
VAEL: The brand can be borne three ways. Choose. I will notarize whichever, with equal indifference, which is the only kind I have.

>> CHOICE — WHAT TO DO WITH THE MARK *(THE defining Act 0 tick — sets the starting grid coordinate)*
- **"Seal it. Lock it down, keep it asleep."** *(Branch: PURE — Concord-coded ward-sigil)*
  → **>> GATE:** sets a **Pure-leaning** starting coordinate; unlocks the **Arena** + High Table standing (Stranger). The mark sleeps under a Concord ward. **>> CONSEQUENCE:** `purity_corruption −15`. Flags `mark_sealed`. → goes to **3C-Seal**, then opens **`[Ink →]` THE FINE PRINT** (sealed variant).
- **"Feed it. Let the tint spread. The Lab will want what comes of it."** *(Branch: CORRUPT — let the Primordial-tint climb)*
  → **>> GATE:** sets a **Corrupt-leaning** start; unlocks the Arena + High Table (Stranger); grants the Lab a **hidden recipe slot** (a corruption-gated future Mutate path). **>> CONSEQUENCE:** `purity_corruption +20` (the heaviest single tick in Act 0). Flags `mark_fed`. → goes to **3C-Feed**, then opens **`[Ink →]` THE FINE PRINT** (fed variant).
- **"Bargain it. Let the Table appraise it. What's it worth?"** *(Branch: BALANCED — High Table marker advance)*
  → **>> GATE:** sets a **Balanced** start; unlocks the Arena + High Table (Stranger, +a marker advance of Drachma ₯). **>> CONSEQUENCE:** no purity tick; flags `mark_appraised` + a small early **debt** to the Table (read in Scene 4). → goes to **3C-Bargain**, then opens **`[Ink →]` THE FINE PRINT** (appraised variant).

## `[Dialogic]` — 3C-Seal. (Pure)

*(toast, voice_library §1.4 register):* **"Sealed. The record holds — for now."**
VAEL: Sealed. Tidy. The seal will hold until ambition removes it. Ambition always removes it. We'll keep the appointment open. *(beat)* For the record, the file now reads *cautious.* I want you to know that the Table priced *cautious* at the longest odds on the board. We do not expect cautious to last. We are rarely wrong, and we are never sorry.
→ converges to **Scene 4 (Registered)**.

## `[Dialogic]` — 3C-Feed. (Corrupt)

*(toast, voice_library §2.8):* **"Corruption rises. You feel it settle in, like a tenant who won't leave."**
VAEL: You let it in. Bold. The brand is in your marrow now, climbing. We've started the paperwork on what you'll become. Do try to be interesting. *(beat)* I should note — and I note everything — that the Lab will now accept inputs it refused an hour ago. A door opened. You did not knock; you *swallowed the key.* The Table finds this excellent action and has shortened your odds accordingly. You are, suddenly, a favorite. Favorites die richest.
→ converges to **Scene 4 (Registered)**.

## `[Dialogic]` — 3C-Bargain. (Balanced)

*(toast, voice_library §2.9 register):* **"You are now a *marker* with the High Table. Mind which hand you're shaking."**
VAEL: A sensible animal. You neither sealed the future away nor swallowed it whole — you *sold a look at it.* Here is your advance. *(coins change hands)* The Table now owns a small, perpetual window onto your marrow. Purely procedural. Everything we do is purely procedural, right up until the Accountant arrives, and the Accountant is never procedural. Do mind the debt. Debt is the one god that never died.
→ converges to **Scene 4 (Registered)**.

## `[Ink →]` THE FINE PRINT — the High Table marker, clause by clause (deep branch)

```ink
// Scene 3 deep branch. The genuinely-branching contract.
// Each clause foreshadows a faction or an ending. Reading clauses is optional
// and re-enterable; the player may sign, refuse, or stall indefinitely.
// Vael does not care how long you take. Vael has notarized ten thousand of these.

EXTERNAL grid_axis(axis)
EXTERNAL corruption()
EXTERNAL has_flag(name)
EXTERNAL set_flag(name)

VAR clauses_read = 0

=== fine_print ===
VAEL: The marker. Standard High Table instrument. I am required to offer it; you are required to do nothing, which is the only freedom the document grants and the last one it mentions.
{has_flag("mark_fed"): VAEL: Given your... enthusiasm with the brand, Clause Four will be of particular interest. It usually is, to your sort.}
- (hub)
+ {clauses_read < 4} [Read Clause One — "On Registration"] -> clause_one
+ {clauses_read < 4} [Read Clause Two — "On Standing & Rivals"] -> clause_two
+ {clauses_read < 4} [Read Clause Three — "On Ascension"] -> clause_three
+ {clauses_read < 4} [Read Clause Four — "On the Reliquary"] -> clause_four
+ [Sign it.] -> sign_marker
+ [Refuse it.] -> refuse_marker
+ {clauses_read >= 2} [Ask Vael what it's actually *for.*] -> the_real_terms

=== clause_one ===
~ clauses_read++
VAEL: "The bearer, having survived a divine mark, is entered upon the Rolls as a registered aspirant." Plainly: the city now knows exactly how much you are worth dead. The Arena opens to you. So does every knife that reads the Rolls. The Rolls are very widely read.
-> hub

=== clause_two ===
~ clauses_read++
VAEL: "The bearer may court the Nine; standing with one cools standing with its rival." The Concord and the Unbound will not both love you. Nor the Bloomwardens and the Pale Court. You will spend this whole climb choosing which hand to hold and which to let go cold. The document calls this *freedom of association.* The factions call it *picking a side.* Both are correct; only one is honest.
-> hub

=== clause_three ===
~ clauses_read++
VAEL: "Upon Ascension, the bearer's claim is recognized by the Table in perpetuity." Note the word *upon,* not *if.* The Table does not hedge on whether you ascend. It hedges only on *which* god you become, and *who* collects when you fall. We are very confident you will fall. Everyone on the thrones did. That is the whole of the business.
-> hub

=== clause_four ===
~ clauses_read++
VAEL: "A file shall be opened in the Reliquary of Winners under the bearer's name, to be completed at the bearer's ascension or expiry, whichever proves more interesting."
{corruption() > 15: VAEL: Your file already has a *promising* first paragraph. The brand-climb wrote it for us. I confess I peeked. It reads like an obituary that hasn't decided whose yet.}
VAEL: Somewhere there is a record of every nobody who became a god. You will read one, later, in a place called the Reliquary, and your face will do the arithmetic, and you will understand that this clause was the kindest warning anyone ever buried in fine print. -> hub

=== the_real_terms ===
VAEL: What it is *for.* *(a pause that, on a soulless construct, costs nothing and somehow lands like a sigh)* It is for keeping the game going. The Table believes in nothing but the spread. A fresh nobody with a marked starter is the best action in an age. We did not contract you to *help* you. We contracted you because you are *excellent to bet on,* and a thing that is bet on tends to keep running long after it would otherwise lie down. That is the service. You are welcome.
~ grid_axis("order_chaos") // small +Chaos: seeing the con clearly nudges you off Order
-> hub

=== sign_marker ===
VAEL: Signed. Witnessed. Notarized. *(beat)* Threshold's bells will ring you in as a registered aspirant, which in this city means everyone now knows exactly how much you're worth dead. Welcome to the rolls. The first hand is complimentary. They never are again.
~ set_flag("signed_marker")
-> END

=== refuse_marker ===
VAEL: You refuse. *(beat)* Noted. Filed. ...Entered on the Rolls anyway. Refusing is its own answer, and the answer is still *yes, the interesting kind.* The Table does not require your signature to open a line on you; it requires only that you exist and continue to be improbable. You qualify on both counts. The bells will ring regardless. Off you pop.
~ set_flag("refused_marker")
-> END
```

---

# SCENE 4 — "Registered" (Threshold · the Arena · Act 0 climax / hub unlock)

**Quest:** 0.4 · **Quest-givers:** Madam Thessaly Vance (High Table steward, per `story_quests.md` recurring NPC) + Pomp Castellan (Arena Herald, per `factions_npcs.md` #6) + Marker-Keeper Doss Halloway (Arena registrar, per `factions_npcs.md`).
**Gate this scene opens:** opens **Act 1** (regional travel from Threshold) + the first **faction-courting** prompts; sets the **notoriety** baseline.
**Where it sits:** your first Arena bout. Win it three ways. The *way* you win is your second public grid stamp, and the factions are watching the gate.

## `[Dialogic]` — 4A. The Gate

*(Pomp Castellan, booming — voice_library / factions_npcs §6 register)*

POMP: NEW BLOOD IN THE ARENA! Odds are *generous,* friend — which is the Table's polite word for *grim!* Sign the marker with Doss, bring a creature, bring a *will* while you're at it!
DOSS: *(gruff, paternal)* Sign here. Win, you collect. Lose, the marker collects. Either way the *Table* collects — that's just the geometry. First bracket bout's a soft one. They go soft exactly once. Make it count, or make it quick. Quick's underrated.

*(the bout plays — a single Arena bracket fight against a low-tier rival aspirant, using the Capture-or-defeat loop. The script resumes at the kill/win moment, where the player chooses HOW to finish.)*

## `[Dialogic]` — 4B. The Finish

NARRATION: The other aspirant's last creature drops. The crowd leans in. This is the part the factions came to see — not whether you win, but what you do with the winning.

>> CHOICE — HOW YOU WIN *(public grid stamp; each warms a different faction door for Act 1)*
- **"Let them keep their fallen. I won. That's enough."** *(Branch: PURE — refuse to harvest the loser)*
  → **>> CONSEQUENCE:** `purity_corruption −10`. **>> GATE:** Bloomwarden courting-door warms (read in Scene 5); crowd *disapproves* (notoriety stays low). Flags `arena_clean`. → goes to **4C-Clean**.
- **"Claim the loser's organ. Waste not."** *(Branch: CORRUPT — harvest the loser)*
  → **>> GATE:** drops a **harvested part** in the Drawer; the **Pale Court** courting-door warms (read in Scene 7). **>> CONSEQUENCE:** `purity_corruption +12`; notoriety rises. Flags `arena_harvest`.→ goes to **4C-Harvest**.
- **"Win loud. Give them a show they'll be sick about later."** *(Branch: CHAOS — theatrical)*
  → **>> GATE:** the **Revel** marks you as *fun* (warms their door, read in Scene 5/7). **>> CONSEQUENCE:** `order_chaos +10`; notoriety rises; crowd *loves* it. Flags `arena_theatrical`. → goes to **4C-Theatrical**.
- **"Offer the loser my hand. A rival today, an ally tomorrow."** *(Branch: BALANCED — recruit-minded mercy)*
  → **>> CONSEQUENCE:** no purity tick; flags `arena_offered_hand` — seeds an early **co-op / breeding-partner** thread (a soft foreshadow of the sticky-rival system). High Table *approves the long game.* → goes to **4C-Hand**.

## `[Dialogic]` — 4C-Clean.

POMP: A MERCIFUL VICTOR! The crowd is *furious* — they came for a harvest and got *grace!* Boo if you like, friends, but mark the name; mercy's rare enough to *remember!*
THESSALY: *(velvet, a smile like a closing door)* Mercy. The crowd hated it and the Bloomwardens loved it. Both will matter. Congratulations — you're somebody now, which is the worst thing that can happen to a person in this city. → continues to **4D**.

## `[Dialogic]` — 4C-Harvest.

POMP: AND THE VICTOR TAKES A *TROPHY!* Ohh, the front rows *adore* this and the back rows are *leaving* — that's the carnage *and* the conscience covered, what a debut!
THESSALY: You took a piece. The Pale Court noticed. Death keeps better records than I do, and I keep *excellent* records. → continues to **4D**.

## `[Dialogic]` — 4C-Theatrical.

POMP: *(delighted)* NOW THAT — THAT is what the gate is *for!* They'll be sick about it tomorrow and they'll *tell everyone first!* The crowd is loyal to the *verb,* never the noun, and tonight the verb is *YOURS!*
THESSALY: Theatrical. The Revel will want you at their table — and the Revel's table is the one you leave wearing a different number of limbs. Both ways are popular. → continues to **4D**.

## `[Dialogic]` — 4C-Hand.

POMP: A HANDSHAKE?! In *MY* arena?! ...the crowd doesn't know what to do with it and frankly neither do I, but I'll say this — nobody forgets the one who *offered.*
THESSALY: A long-game player. How rare, and how *bankable.* You didn't make an enemy today; you made a *deferred asset.* The Table approves. The Table *always* approves of someone keeping their options liquid. → continues to **4D**.

## `[Dialogic]` — 4D. Off You Pop

THESSALY: There. You're on the rolls. *(she gestures past the gate, to the eight roads out of Threshold)* Eight regions, nine clans, one empty sky. The warm green Glut's the kindest door — the Bloomwardens keep the friendliest embassy and they'll take a Stranger gently. Off you pop.
THESSALY: *(as you go, lighter, which is worse)* Oh — and a file's been opened under your name. In the Reliquary. Purely procedural. Do keep climbing. The view from up there is *exactly* as lonely as they say.

>> CHOICE — THE FIRST ROAD *(opens Act 1; MVP slice routes to the Verdant Glut)*
- **"The Verdant Glut. The green one. The kind one."** → **>> GATE: opens Act 1 + region access groundwork for the Verdant Glut.** → goes to **Scene 5**.
- *(other regions named but locked in the MVP slice — Mournmarch / Forgefell shown greyed, "courted faction required")* → returns to prompt.

NARRATION: The bells of Threshold ring you in. Somewhere, a ledger adds a line. Somewhere else, a chair you've never seen gets very slightly warmer. Off you pop.

---

# SCENE 5 — "Greener Pastures, Hungrier Ones" (Verdant Glut · the fringe · region access)

**Quest:** 1.1 · **Quest-giver:** **Greenmother Saoirse Lateharvest**, leader of the **Bloomwardens** (per `factions_npcs.md` — the canonical leader name; see Canon gaps re: `story_quests.md`'s placeholder "Mother Sylva Greenrot"). With **Matron Sevvy** (fringe mother-superior, per `regions.md`) as the on-the-ground on-ramp.
**Gate this scene opens:** unlocks **region access: the Verdant Glut** + the **Lab — Mod** operation (augment a living beast with bloom-organs); grants the first **Mend** skill if the Pure path is taken; Bloomwarden standing **Stranger → Associate**.
**Where it sits:** your first region. The Glut is warm and fertile-to-menace — life so abundant it strangles. A fungal bloom is choking the eastern terraces; you decide its fate, and the deciding is the faith.

## `[Dialogic]` — 5A. The Friendliest Door

*(ambient, voice_library §7.3):* "It's beautiful here, isn't it? It's also slowly digesting the eastern road. Both things are true."

SEVVY: *(warm, a hugger with grief behind the eyes — per regions.md)* So you're up from Threshold. Welcome to the Glut, dear. Mind your footing — half of what looks like path here is just something *patient.* We don't catch them, by the way. We *invite* them. The cage is only somewhere to invite them into.
SEVVY: The Greenmother wants to see you. That's rare for a Stranger. Means either you've a kindness in you worth the trouble, or you've a *blood* in you worth the worry. With her it's usually both. Come.

## `[Dialogic]` — 5B. The Greenmother

*(Saoirse Lateharvest — the warmest and saddest person in the game; the moral conscience of the roster, and doomed, and knows it)*

SAOIRSE: We don't butcher here, child. We *tend.* The land is a body and the body is still dying and the least we can do is hold its hand. *(beat)* There's a bloom — fungal, fast, *hungry* — choking the eastern terraces. It's eating the gentle things faster than I can mourn them. I won't order you. I'll only ask. Will you hold the land's hand, or harvest it?
{flag `spared_godling`}: SAOIRSE: I heard what you did with the godling in Threshold. You let a hungry thing live. ...That's the whole faith in one small mercy, dear. I'd hoped you'd come.
{flag `harvested_godling` OR `arena_harvest`}: SAOIRSE: I heard about Threshold. The harvesting. *(no anger — worse, grief)* I'm not going to lecture you. The garden does the lecturing, and it does it slowly, and you'll hear it eventually. But you came *in* instead of *around.* So. Tea? Then we'll talk about the bloom.

>> CHOICE — THE BLOOM'S FATE *(the region's defining tick; diverges into genuinely different follow-ups)*
- **"Heal it. Replant. Coax the terraces back."** *(Branch: PURE — heal and replant)*
  → **>> GATE:** unlocks **region access: Verdant Glut** + **Lab — Mod**; grants your **first Mend skill** (per voice_library §3.1 Eros register); Bloomwarden standing **Stranger → Associate**. **>> CONSEQUENCE:** `purity_corruption −12`. Bloom-beasts become **befriend-able** (flags `bloom_healed`). → goes to **5C-Heal**, then opens **`[Ink →]` THE GLUT'S HISTORY**.
- **"Harvest the bloom. Those spores are Eros gene-vials, and they're just *sitting* there."** *(Branch: CORRUPT — harvest for Eros gene-vials)*
  → **>> GATE:** unlocks **region access** + **Lab — Mod**; drops **Eros gene-vials** in the Drawer; warms **Pale Court / Revel** (read in Scene 7). **>> CONSEQUENCE:** `purity_corruption +12`; Bloomwarden standing **drops** (Saoirse grieves you while you live). Flags `bloom_harvested`. → goes to **5C-Harvest**.
- **"Let it spread. Watch what the next terrace does. Farm the chaos."** *(Branch: CHAOS — let it spread)*
  → **>> GATE:** unlocks **region access** + **Lab — Mod**; warms the **Revel** (read in Scene 7); the bloom escalates a Glut hazard tier. **>> CONSEQUENCE:** `order_chaos +12`; Bloomwarden standing drops. Flags `bloom_spread`. → goes to **5C-Spread**.

## `[Dialogic]` — 5C-Heal. (Pure)

*(Mend-skill grant toast, voice_library §3.1 register):* **"It would rather not. It will anyway. — the Mend line is yours."**
SAOIRSE: Bless you. You'll get yourself killed being kind, but you'll be *kind* when it happens. That's rarer than it should be. *(she presses a Mend-vial into your hand)* Here. It heals. It also *commits* you — healing always does. The garden has an Associate. Mind the eastern terraces still; the bloom-beasts remember now who held the land's hand. They don't fear your footsteps anymore. Out here that's a miracle with teeth.
→ continues to **Scene 6 (The Mercy-Garden)**.

## `[Dialogic]` — 5C-Harvest. (Corrupt)

*(toast, voice_library §2.2):* **"Harvested. Try not to think about whose."**
SAOIRSE: *(she watches you bottle the spores; she does not look away, which is somehow worse)* I see. Off to the Court with you, then, eventually — they keep your sort. Don't bring that back here. The garden remembers who cut it. *(beat, and the grief cracks through)* I'll still mend your creatures, if you bring them broken. That's the trouble with the soft creed, dear — it doesn't get to *stop* at the people who deserve it. If it did, it wouldn't be mercy. It'd just be *bookkeeping,* and the Court has that covered.
→ continues to **Scene 6 (The Mercy-Garden)** *(Sevvy still admits you — the Mercy-Garden is open to all; that's the point of it).*

## `[Dialogic]` — 5C-Spread. (Chaos)

*(toast, voice_library §7.4 register):* **"You let the Glut share its abundance. It is *delighted.* That should worry you."**
SAOIRSE: *(quietly)* You let it spread. To *see.* ...The Glut loves being watched almost as much as it loves being *fed,* and you've just done both. The eastern terraces are the Glut's now, fully, and what grows back will have teeth the old growth never dreamed of. *(beat)* The Revel will toast you for this. They toast everything. It's how they avoid the part where they *notice.* You're an Associate of the garden, technically. I'd ask you to walk gentle, but I think we both know which way your feet point.
→ continues to **Scene 6 (The Mercy-Garden)**.

## `[Ink →]` THE GLUT'S HISTORY — Demeter's death & the Bloomwarden/Revel schism (deep branch)

```ink
// Scene 5 deep branch. The sprawling readable lore-tree of the Verdant Glut.
// Demeter's death, why life here grew teeth, the schism between the soft creed
// (Bloomwardens) and the sweet rot (the Revel). Bound at the Greenmother's grove.
// Spore-Speaker Lull (regions.md / factions_npcs.md #16) co-narrates the deep nodes.

EXTERNAL has_creature(force)
EXTERNAL faction_standing(faction)
EXTERNAL grid_axis(axis)
EXTERNAL set_flag(name)

=== glut_history ===
SAOIRSE: You want to know how a garden learns to *strangle.* Sit. Lull will tell the deep parts; the mycelium remembers what I'm too young and too grieving to.
-> glut_hub

=== glut_hub ===
+ [Demeter — what actually happened to her?] -> demeter_death
+ [Why does life here grow *teeth*?] -> teeth
+ [The Revel — what split you from them?] -> the_schism
+ {faction_standing("bloomwardens") >= 1} [What does the soft creed *cost* you?] -> the_cost
+ [Enough history. Back to the work.] -> END

=== demeter_death ===
SAOIRSE: She didn't fall in a battle. The Harvest-Mother *over-gave.* That was always her nature — Eros and Gaia both, life and the ground it grows from, generous past sense. When the thrones went cold she didn't rage or scheme. She just... kept giving. Poured herself into the soil until there was no Demeter left, only *harvest,* with no hand left to hold it back.
LULL: *(dreamy, networked — speaks for the mycelium)* She's still down there, surface-thing. Not alive. Not *gone.* Composting. The greatest harvest there ever was. You are standing in her *generosity,* and her generosity has *opinions* now, and no one to moderate them.
-> glut_hub

=== teeth ===
LULL: The Glut is one creature, and we are all *thoughts* it's having. When Demeter stopped *deciding,* the thoughts kept thinking — and a thought with no thinker grows *strange.* Mercy with no mind behind it becomes *appetite.* That's the teeth. The kindness didn't curdle into cruelty. It curdled into *hunger,* which is worse, because hunger still thinks it's being generous.
SAOIRSE: That's the lesson the Glut teaches and the Bloomwardens refuse to learn: love without limit *eats.* We tend it anyway. Someone has to mean the mercy on purpose, or there's no one minding the difference between *holding a thing* and *swallowing it.*
~ set_flag("knows_glut_teeth")
-> glut_hub

=== the_schism ===
SAOIRSE: The Revel and we want the same impossible thing — for the Glut's life to be *sacred.* We diverge on the verb. We say *tend.* They say *taste.* They look at fertility-turned-menace and they don't see a body dying; they see a feast that finally stopped pretending to have manners.
LULL: Brother Cask's lot drink the bloom that kills us. They *become* it. They're not wrong that it's beautiful. They're only wrong that beauty is the *end* of the argument. The mycelium has watched them dissolve into the network, laughing, for a hundred years. We keep their voices. Some of them ask after the surface. We lie to them kindly.
-> glut_hub

=== the_cost ===
SAOIRSE: *(a long pause)* What it costs. *(she names it plainly, the only time she will)* We are the kindest faction and the most *fragile* one. The Pale Court would bank our dead; the Iron Guild would render us for parts. Every Bloomwarden knows the soft path may not survive the Succession — that a gentle god is the rarest thing the sky could hold, and the most *hunted.* I know it best of all. *(beat)* I tend anyway. That's the whole of me, dear. If you take nothing else from this grove, take that: I *chose* the creed the world is built to punish, and I climbed it anyway, and I'd do it again, weeping the entire way.
~ grid_axis("purity_corruption") // small −Corrupt nudge: hearing the cost and staying
~ set_flag("heard_greenmother_cost")
-> glut_hub
```

---

# SCENE 6 — "The Mercy-Garden" (Verdant Glut · Matron Sevvy's infirmary · the Mend line & the body count)

**Quest:** 1.1-side ("The Mercy That Holds," adapted) · **Quest-givers:** **Matron Sevvy** (Mercy-Garden, per `regions.md`), **Mendwright Toval Greenmercy** (Mend-skill instructor, per `factions_npcs.md`), with **Sister Fenwynn** (the young Bloomwarden who sees the order is losing, per `regions.md`) and **Hob Thornsoft** (the Weeping Gardener, per `factions_npcs.md` #19).
**Gate this scene opens:** unlocks the **Mend / Soothe skill line** (in-encounter befriend conditions for hostile & high-tier targets) + the **husbandry boost** (raises bond-growth rate). Bloomwarden standing toward **Sworn**.
**Where it sits:** the warm faction reveals its body count. A grief-maddened Eros half-god is blooming a tended creature to death in the heart-grove's edge; you talk it down with the soothe path, or you don't, and the doing is the cost of kindness.

## `[Dialogic]` — 6A. The Infirmary

*(ambient, voice_library §7.3):* "Be kind to your creatures. The ones you love don't end up on the table. Mostly."

SEVVY: This is the Mercy-Garden. We mend hurt things here — yours, wild, doesn't matter whose. *(she's bandaging something with too many legs and a trusting face)* Toval'll teach you the Mend line if you've the standing and the stomach. It's not the stomach for *blood,* dear. It's the stomach for *losing.* We lose a great deal here. Gently. On purpose. With grace. That's the part that breaks people who aren't built for it.
TOVAL: *(bright, relentlessly hopeful in a way that's almost a wound)* We can't out-kill the Court. So we out-*last* them, one mended creature at a time. It's not nothing. Some nights it's everything. Here — *(offers the first Mend-vial)* — the Soothe line. It heals a thing. It also calms a thing that's trying to kill you, which out here is the same skill wearing a kinder face.

## `[Dialogic]` — 6B. Fenwynn's Warning

*(Sister Fenwynn — earnest, fraying; the first hint the warm faction is losing)*

FENWYNN: *(low, so Sevvy won't hear)* Can I tell you something the Greenmother won't? We're *losing.* The deep Glut is winning and the order's pretending it isn't. Hob tends creatures too gentle to survive and they die anyway and he tends them *anyway* and everyone calls that the faith. *(beat)* I think the faith is a beautiful way to lose slowly. I haven't decided if that's worth doing. ...Don't tell her I said it. She *knows.* That's the worst part. She knows and she tends anyway. I don't know if that's strength or if it's just— *(she stops)* —there's a half-god at the heart-grove edge. Grief-mad. Blooming one of ours to death. Sevvy's going to ask you to go. She always asks the new ones. She hopes one of you will be *better* at the soft path than we are. None of you ever are. Go be the first. Please.

## `[Dialogic]` — 6C. The Grief-Mad Half-God

NARRATION: At the heart-grove's edge, a thing that used to be one of Demeter's children is blooming — flowers erupting from a captured Bloomwarden creature faster than the creature can survive them. It is not cruel. It is *grieving,* and its grief has roots, and the roots are in something innocent. Hob Thornsoft is on his knees nearby, naming the dying creature so it has a name before the end. He does that now. He's started naming them faster.

HOB: *(grief-cracked)* Don't harvest it. Please. I know you can. I know it's *efficient.* The half-god's not *evil,* it's just— it lost something and it doesn't know how to hold the loss so it *plants* it. *(beat)* Sevvy says talking it down is the whole faith. Some days I believe her. Today my hands are full of a dying thing with a fresh name and I need you to make today a *believing* day. Please.

>> CHOICE — THE HALF-GOD *(this is the soft creed, tested; genuinely different scenes)*
- **"Soothe it. Talk it down. No claws."** *(Branch: PURE — the befriend/soothe path, the faith proper)*
  → **>> GATE:** completing it via Soothe **unlocks the full Mend / Soothe skill line** (in-encounter befriend for hostile & high-tier targets) + the **husbandry bond-growth boost**; Bloomwarden standing → **Sworn**. **>> CONSEQUENCE:** `purity_corruption −12`. The half-god is logged as a **befriend-eligible** future capture (flags `soothed_halfgod`). → goes to **6D-Soothe**.
- **"Put it down clean. Mercy is also a knife, sometimes."** *(Branch: BALANCED/PURE-grey — euthanasia)*
  → **>> GATE:** unlocks the Mend line (Toval still teaches it) but **not** the husbandry boost; Bloomwarden standing rises modestly (Saoirse calls it a sad mercy). **>> CONSEQUENCE:** small `purity_corruption −4`; the dying tended creature is saved, the half-god is logged to the **Graveyard**. Flags `euthanized_halfgod`. → goes to **6D-Clean**.
- **"Harvest the half-god. A grieving Eros half-god is a *gene-vial cathedral.*"** *(Branch: CORRUPT — harvest)*
  → **>> GATE:** drops a **high-tier Eros gene-vial** + a **god-adjacent ingredient** in the Drawer; warms **Pale Court** hard. **>> CONSEQUENCE:** `purity_corruption +18` (heavy); Bloomwarden standing **collapses** — Sevvy bars you from the Mercy-Garden (the one door in the Glut that closes). Flags `harvested_halfgod`. → goes to **6D-Harvest**.

## `[Dialogic]` — 6D-Soothe. (Pure)

*(toast, voice_library §5.1 register):* **"Trust, freely given. Try to deserve it. You won't, but try."**
NARRATION: It takes a long time. The Soothe line is patient by design. You don't fight the half-god; you *outlast its fear,* the way the Stoneblooded outlast everything, the way the Bloomwardens outlast the Court. The blooming slows. The dying creature in Hob's arms takes a breath it wasn't going to take. The half-god folds in on its grief and goes quiet, and looks at you, and decides — barely — that you are not another loss waiting to happen.
SAOIRSE *(arriving):* You talked it down. You could have wrung a harvest from a grieving god and you *didn't.* *(beat)* That refusal is the whole faith, dear. You saw your face do the math and then *refuse* it. The garden has a Sworn. *(quieter)* And the half-god will remember you held its grief instead of cutting it out. That matters more than ten broken gods. It'll grieve you when you fall. Which is more than most gods got.
HOB: *(weeping, but the good kind now)* You made it a believing day. ...Thank you. Her name was going to be the last thing I gave her. Now it's just her *name.* Do you know how long it's been since a name down here got to just be a *name*?
→ continues to **Scene 7 (What the Glut Won't Bury)**.

## `[Dialogic]` — 6D-Clean. (the sad mercy)

*(toast, voice_library §2.5):* **"It fell, and it stayed fallen. The bond goes quiet. You'll feel the silence later."**
SAOIRSE: You ended it clean. No harvest, no cruelty — just an end, given gently, because the grief had grown teeth and the teeth were in something innocent. *(beat)* That's a mercy too, dear, the hard kind. Not the kind we *prefer* — we'd have liked it talked home — but the kind the world sometimes only leaves room for. The garden won't fault you. The garden's buried enough to know the difference between a knife that *spares* and a knife that *takes.*
HOB: *(quiet)* It stopped. She's breathing. That's... that's the job, isn't it. Some days the job is the *worse* mercy done *gently.* I'll bury the half-god proper. Full rites. You're welcome to stay. You should stay. Declining a Glut funeral is the rudest thing a person can do all season.
→ continues to **Scene 7 (What the Glut Won't Bury)**.

## `[Dialogic]` — 6D-Harvest. (Corrupt)

*(toast, voice_library §2.2 + §2.8):* **"Harvested: a god's grief, bottled. Corruption rises. It fits better than it should."**
NARRATION: The gene-vials are the brightest things in your drawer. They do not stop being warm for some time. Hob does not say anything. Hob picks up the dying creature — saved, technically, the half-god's bloom finally stopped — and carries it away without looking at you, and starts naming it under his breath, and you realize he is also, very quietly, naming the half-god you just took.
SEVVY: *(no warmth left, only the grief that never leaves her)* Out. Not from the Glut — I can't bar you from the Glut, the Glut bars no one, that's its whole tragedy. But from *here.* The Mercy-Garden is the one room that's only ever held mercy and you brought a *harvest* into it. *(beat)* Go to the Court. They'll have you. They keep better records than I do, and they'll never make you feel what you should be feeling right now. That's what they *sell,* dear. The not-feeling. I hope it was worth the warmth in the drawer. It cools. Everything down here cools eventually except the grief.
→ continues to **Scene 7 (What the Glut Won't Bury)** *(harvest path leans hard toward the Pale Court arc there).*

---

# SCENE 7 — "What the Glut Won't Bury" (Verdant Glut · the seam · the Pale Court & the Eros Legendary)

**Quest:** 1.1-capstone (the Bloomwarden defense quest) · **Quest-givers:** **Greenmother Saoirse Lateharvest** (Bloomwardens) and, at the seam, **Gravekeeper Sallow Munt** (Pale Court field-harvester, per `factions_npcs.md` #21) representing the Court's interest. **Hearthward Ona Bramblekind** (Bloomwarden husbandry tutor) supports the befriend path.
**Gate this scene opens:** success on the Bloomwarden side grants **region access to the deep heart-grove** + an **Eros Legendary befriend target** (Demeter's loosed child) + a permanent **husbandry uplift** to befriend-method capture odds in the Glut. Siding with the Court opens the **inverse Pale Court arc** and makes Saoirse grieve you while you live.
**Where it sits:** the morality fork that decides whether the Verdant Glut stays a Pure on-ramp or tips toward the Corrupt arc. The Pale Court is harvesting Bloomwarden creatures at the Glut's edge. You drive them off and reclaim the *living* — or you join the harvest.

## `[Dialogic]` — 7A. The Seam

NARRATION: The Glut's edge, where the green goes grey and the Mournmarch's grief seeps in. Pale Court collectors are working the seam — *legally,* every harvest itemized, every soul receipted — taking Bloomwarden creatures for soul-tech. Hob's voice from Scene 6 echoes: *they bought them, all legal, all itemized.* The Court does nothing the law forbids. That's the horror of it.

SALLOW: *(dry, funereal, finds the living a bit loud)* Ah. The Greenmother's new stray. Quiet down — there's *work* here, and it's all above board. We harvest the fallen and the *sold,* every one itemized, the Steward gets twitchy about waste. *(beat)* You could *help,* you know. The Court keeps your sort, and we'd never ask you to *feel* anything about it. That's a service, that. Worth more than coin, the not-feeling. Ask anyone who's stopped.

SAOIRSE *(over the bond-link, or arriving):* They're taking the *living,* child — or near enough, the barely-fallen, the ones a Mend could still reach. I won't ask you to spill Court blood. I'll only ask you to *reclaim the living* before they're inventory. Drive them off. Bring our gentle things *home.* That's all the garden ever wants: one more thing held instead of swallowed.

>> CHOICE — THE SEAM *(decides the Glut's whole tilt; genuinely divergent arcs)*
- **"Drive the Court off. Reclaim the living. Bring them home."** *(Branch: PURE — defend the Bloomwardens)*
  → **>> GATE:** unlocks **region access: the deep heart-grove** + registers an **Eros Legendary** (Demeter's loosed child) as a **befriend-eligible** target (high-bond start) + a permanent **husbandry uplift** to Glut befriend-odds. Bloomwarden standing → **Sworn/Champion** track. **>> CONSEQUENCE:** `purity_corruption −12`; **Pale Court turns cold**. Flags `defended_glut`. → goes to **7B-Defend**.
- **"Register a truce. Let the Court take the *fallen,* you reclaim the *living.* Itemize it fairly."** *(Branch: BALANCED — broker the seam)*
  → **>> GATE:** unlocks heart-grove access + the Eros Legendary target (befriend, slightly lower start) **without** the full husbandry uplift; banks a small **High Table** favor for brokering cleanly. **>> CONSEQUENCE:** no purity tick; both factions wary-but-not-hostile. Flags `brokered_seam`. → goes to **7B-Broker**.
- **"Join the harvest. The Court pays in soul-tech and the Glut's too soft to stop you."** *(Branch: CORRUPT — side with the Court)*
  → **>> GATE:** opens the **inverse Pale Court arc** (the Court's Mournmarch quests become available early); drops **soul-cores + Eros gene-vials** in the Drawer; unlocks a **Thanatos-leaning harvest** path. **>> CONSEQUENCE:** `purity_corruption +18` (heavy); Bloomwarden standing **collapses** — Saoirse grieves you while you live; the Eros Legendary becomes a **trap/break** target only (no befriend). Flags `joined_court`. → goes to **7B-Harvest**, then opens **`[Ink →]` THE COURT'S RECEIPT**.

## `[Dialogic]` — 7B-Defend. (Pure)

*(toast, voice_library §2.9):* **"You are now **Sworn**-track with the Bloomwardens. Their rivals take note, and a knife. — the Pale Court cools."**
SALLOW: *(unbothered, gathering his itemized dead)* Have it your way. We'll take only what's *properly* fallen, then. No quarrel. The Court's patient — death always is, and you're going to *die* eventually, spectacularly, the powerful always do, and the Steward's already got your deposit slip. *(beat)* Drive us off today. We'll be at the next funeral. There's always a next funeral. It's practically a gala.
SAOIRSE: You brought them *home.* *(she's holding a creature that should have been inventory, and it's breathing)* The heart-grove opens to you now — Demeter's own untended children are in there, half-gods gone feral with grief. We don't kill them, dear. We *sit* with them. There's one — older, sadder, *vast* — a Legendary, Demeter's loosed child. The clans would break it. The Court would bank it. We'd like you to *befriend* it. Bring patience. Bring tea. Bring your softest creature. It's the whole faith, asked once, of a Legendary.
ONA: *(practical, warm)* And here — *(the husbandry uplift)* — love's a method, not a mood. Feed them right, raise them kind, and the bond does three jobs for you. Your befriend odds in the Glut just went up for good. Sentiment *with results.* Now go meet the big sad one. Gently.
→ continues to **Scene 8 (The Guardian at the Seal)**.

## `[Dialogic]` — 7B-Broker. (Balanced)

*(toast, voice_library §2.9 register):* **"A fair line drawn in an unfair place. Both powers note it; neither warms."**
SALLOW: *(grudging respect)* A *truce.* Itemized. The fallen to us, the living to her. ...That's almost *Court* thinking, that — clean lines, fair ledger, nobody feels a thing they didn't agree to feel. The Steward would *approve,* and the Steward approves of almost no one. Fine. Drawn and witnessed.
SAOIRSE: *(complicated)* You drew a line instead of taking a side. It saved the living, and it let the Court keep its dead, and it left me... *(beat)* ...holding the part of the faith that says we don't *deal* with them at all. But the gentle things are home, and home is home however the ledger reads. The heart-grove opens. The Legendary's in there. You can still befriend it — it's just learned, from watching you broker, that you're the kind who draws lines. It'll start a touch more wary. So would I.
→ continues to **Scene 8 (The Guardian at the Seal)**.

## `[Dialogic]` — 7B-Harvest. (Corrupt)

*(toast, voice_library §2.8):* **"The rot deepens. New doors unlock. Cleaner ones quietly lock."**
SALLOW: *(the closest the Court comes to warmth)* There. Wasn't so hard, was it. Itemized, receipted, *clean.* Welcome to the work. The Steward keeps your sort, and he'll never once ask you to grieve what you settle. *(beat)* The Greenmother's watching from the treeline. She does that. Let her. Grief's just an unpaid invoice she's decided to *feel* instead of *settle.* The Court settles. You're learning to.
SAOIRSE: *(from the treeline, not approaching, the grief total now)* ...I'm not going to stop you. I can't. The Glut bars no one and neither does my mercy, that's the whole tragedy of me. *(beat)* But I'm going to *grieve* you, child. Now. While you're still alive to be grieved. It's the only thing I have left to give you, and you've made it the only thing you'll take. The heart-grove's Legendary won't come to your hand now — it can *smell* the soul-cores. You'll have to *break* it. You break everything eventually. That's not cruelty. That's just the receipt.
→ continues to **Scene 8 (The Guardian at the Seal)**, *Legendary as break/trap target only.* Opens **`[Ink →]` THE COURT'S RECEIPT**.

## `[Ink →]` THE COURT'S RECEIPT — the Pale Court's ledger of the living (deep branch, Corrupt arc)

```ink
// Scene 7 deep branch (Corrupt path). Sallow walks you through the Court's
// philosophy as a contract — "nothing is lost, only owed." Each node is a
// small horror that makes sense, which is the Pale Court's whole register.
// Bound at the seam after the harvest choice. Foreshadows the Mournmarch / Iron Throne.

EXTERNAL corruption()
EXTERNAL faction_standing(faction)
EXTERNAL set_flag(name)

=== courts_receipt ===
SALLOW: You're in the work now. Let me teach you to *read* it, the way the Steward reads it. Everything here's a *line item.* Nothing's gone. Only owed.
-> receipt_hub

=== receipt_hub ===
+ ["Owed" how? It's dead. That's gone.] -> owed
+ [Why doesn't it feel like anything?] -> the_not_feeling
+ {corruption() > 30} [What happens to *me*, doing this?] -> what_happens_to_you
+ [The Greenmother grieves me. Why does that land?] -> the_grief_lands
+ [Enough. The work's the work.] -> END

=== owed ===
SALLOW: *(patient)* Watch. *(he receipts a fallen creature)* This isn't a corpse, surface-thing. It's a *deposit.* A bloodline held in trust against the day someone wants it back. The Steward doesn't believe in death; he believes in *liquidity.* Grief is just an invoice you've decided to feel instead of settle. The Court settles. Down in the Mournmarch there's a bank for it — souls, bloodlines, whole *estates* of the supposedly-lost. Nothing's gone. Only *owed.* It's the kindest accounting there is, if you can stop *feeling* long enough to see it.
~ set_flag("knows_court_liquidity")
-> receipt_hub

=== the_not_feeling ===
SALLOW: That's the *service.* Other factions sell you skills, gear, a creature. We sell you the *quiet* where the guilt used to be. *(beat)* It's not that we're cruel — cruelty's *hot,* and the Court hasn't been hot in three centuries. It's that we've stopped finding the difference between the living and the inventory. You will too. It starts as relief. It stays as relief. That's the part the Greenmother weeps about: it never *stops* feeling like relief. There's no horror in it from the inside. The horror's all on her face, and you'll stop looking at her face.
-> receipt_hub

=== what_happens_to_you ===
SALLOW: *(almost gentle)* To *you.* The corruption climbs — you've felt it, that tenant who won't leave, fits better than it should. Every harvest bolts a clean ending shut and pries a Corrupt one open. *(beat)* The Steward would tell you that's not loss. That's *room.* Room for something that doesn't die on you. He'd be telling the truth. He always tells the truth; that's what makes him terrible. One day you'll harvest a thing you loved and call the receipt *progress,* and mean it, and that's the day the Iron Throne gets a little warmer under you. It's a *throne,* surface-thing. People climb worse ladders for less.
~ set_flag("court_warned_corruption")
-> receipt_hub

=== the_grief_lands ===
SALLOW: *(a flicker — even Sallow has one)* Because she's *right,* and right doesn't stop being right just because it loses. The Greenmother chose the one creed the world bills for, and she pays the bill every day, weeping, and tends anyway. *(beat)* The Court's easier. The Court's *true,* even. But hers is the only door down here that grieves you *before* you're gone — and somewhere under three centuries of ledger, the Steward knows that's the one mercy he can't reanimate. Don't tell him I said so. He'd reanimate *me* for it. ...He'd weep doing it. Real tears. That's the Court. That's the whole terrible Court.
-> receipt_hub
```

---

# SCENE 8 — "The Guardian at the Seal" (Verdant Glut · the Throat of the Glut · MVP Legendary · Act 1 capstone)

**Quest:** 1.3 (adapted to the MVP region) · **Quest-givers:** **Huntmaster Bram Stoneblood** (Stoneblooded, per `story_quests.md` — visiting the Glut for the hunt) with **Tame-Mother Yula Stillhand** (Stoneblooded befriend instructor, per `factions_npcs.md`) for the bond path; **Greenmother Saoirse Lateharvest** if you defended the Glut in Scene 7.
**The Legendary:** **Orchardmother** (apex of the orchard-warden line) — the MVP Legendary wall guarding the **Throat of the Glut** seal into the Heart, per `regions.md`. (An **Eros/Thanatos Greenwatcher** is the alternate per regions.md; Orchardmother is used as primary.) Force: **Eros** (with Gaia weight); Class: organic; Rank: Legendary.
**Gate this scene opens:** unlocks **Legendary-tier capture** + the **Lab — Sacrifice** operation (consume → ingredients/levels); registers the Throat of the Glut traversal-seal as passable; Stoneblooded standing → **Associate**; first **god-organ-adjacent** ingredient if harvested. This is the slice's single Legendary and Act-1 capstone.
**Where it sits:** the boundary between the Glut's gentle fringe and its digesting Heart. The Orchardmother is the wall. How you take her is the sum of everything you've done in the slice — and the game lets you feel that.

## `[Dialogic]` — 8A. The Throat

*(ambient, voice_library §7.3):* "Stay for the harvest. Leave before the harvest stays for you."

BRAM: *(patient, scarred, speaks in seasons)* So you're the one the Glut's been talking about. *(he doesn't look up from the seal)* The old clans don't *catch* a Legendary. We *court* it — years, sometimes. You've got an afternoon and an ambition. The Weight will judge which is worth more. *(beat)* That's the Orchardmother, behind the Throat. Apex of the orchard-wardens. She's held this seal since Demeter stopped deciding. She's not guarding the Heart *from* you. She's guarding *you* from the Heart. There's a difference, and most of your sort die learning it.
YULA: *(soft, endless, the calm a frightened beast trusts)* You don't break her, child. You *outlast her fear.* Same as people. Same as gods, I'd wager, if anyone'd had the patience. *(beat)* But it's your hand on the seal, not mine. How you take her tells the Glut what you became while you were here.

{flag `defended_glut`}: SAOIRSE: She's Demeter's eldest loosed child, the one I asked you to sit with. You defended the garden; she *felt* it. She'll come to a kind hand. She's been waiting a very long time for a kind hand. Don't be the latest to bring a knife instead.
{flag `joined_court`}: SAOIRSE: *(not present — a note, left at the seal)* "She can smell what's in your drawer. She won't come to your hand. I'm sorry. Not for her. For the version of you that could have, this morning, before the seam." — S.

## `[Dialogic]` — 8B. The Orchardmother

NARRATION: The Throat opens and she is *enormous* — bark and blossom and slow green grief, an orchard that learned to grieve and grew a face to do it with. Where she walks, fruit ripens and falls and rots and ripens again, the whole cycle at once, Demeter's generosity with no hand to hold it back. She regards you the way old things regard brief ones. The fight, if it is a fight, will be a long one. The choice, when it comes, is the slice's last word on who you are.

>> CHOICE — HOW YOU TAKE HER *(the capstone; reads your slice-long grid; each opens a different Lab future)*
- **"Bond her. Sit with her. Let her choose me."** *(Branch: PURE — high-bond befriend; gated on `defended_glut`/`brokered_seam` + a soft creature in roster)*
  → **>> GATE:** **Legendary-tier capture (befriend)** — Orchardmother joins **bonded**, the strongest start in the slice; unlocks **Lab — Sacrifice** (you *have* it, but she teaches you to *never need it on her*); Stoneblooded → **Associate**, Bloomwarden → **Champion**-track. **>> CONSEQUENCE:** `purity_corruption −15`. Flags `orchardmother_bonded`. → goes to **8C-Bond**, then opens **`[Ink →]` THE GUARDIAN'S CONFESSION** (bond variant + the Reliquary foreshadow).
- **"Defeat her and register the kill with the High Table. Clean bounty."** *(Branch: BALANCED — defeat & register)*
  → **>> GATE:** **Legendary-tier capture/defeat** + a High Table **bounty** payout (Ichor ◈); unlocks **Lab — Sacrifice**; Throat seal opens. **>> CONSEQUENCE:** no purity tick; the Glut tilts a hazard tier as her cycle goes unguarded. Flags `orchardmother_registered`. → goes to **8C-Register**, then opens **`[Ink →]` THE GUARDIAN'S CONFESSION** (neutral variant).
- **"Break her. Harvest a god-adjacent organ. Best Lab stock in the slice."** *(Branch: CORRUPT — break & harvest)*
  → **>> GATE:** **Legendary-tier defeat** + drops the slice's **first god-organ-adjacent ingredient** in the Drawer; unlocks **Lab — Sacrifice** *and* a corruption-gated graft preview. **>> CONSEQUENCE:** `purity_corruption +18`; the Heart's terrain runs feral (Glut hazard tier spikes); the Stoneblooded turn cold (Bram: "the mountain felt that"). Flags `orchardmother_harvested`. → goes to **8C-Harvest**, then opens **`[Ink →]` THE GUARDIAN'S CONFESSION** (harvest variant).

## `[Dialogic]` — 8C-Bond. (Pure)

*(toast, voice_library §5.1):* **"A friend, not a prisoner. The difference will matter later, on the table."**
NARRATION: You don't raise a claw. You sit, the way Yula taught, the way the Bloomwardens sit with their feral gods. It takes the rest of the afternoon. The Orchardmother lowers her vast head and a single fruit ripens in her grief and does *not* fall, held — for the first time in an age, something held instead of dropped — and she chooses you.
BRAM: *(rare, deep approval)* It *chose* you. Hold that. A bonded Legendary is worth ten broken ones — and it'll grieve you when you fall, which is more than most gods got. The clans don't open to many. They'll open a crack to you. Come to Titanfall someday. Bring tea. Bring patience. Bring *her,* if she'll come; the Old Weight would like to meet something Demeter loved.
YULA: You outlasted her fear. That's the whole craft, child. Different word than *caught.* Different *animal.* Different *you.*
→ continues to **8D**.

## `[Dialogic]` — 8C-Register. (Balanced)

*(toast, voice_library §11.2):* **"Won. Collect the fallen, count your own, and don't look too pleased."**
BRAM: *(a long breath)* You beat her fair and you didn't *take* a piece. Registered, bountied, *clean.* The Weight respects a clean hunt — not a *kind* one, but a clean one. There's a difference, and you landed on the right side of it by a hair. *(beat)* The Glut'll run a little wilder now, with her cycle unguarded. That's the cost of the clean way. Everything's got a cost here. The honest ones just *name* it.
DOSS *(High Table, remote):* Marker collected. Ichor paid. The Table loves a registered Legendary kill — it's *marquee.* There's a line open already on what you take down next. Spoiler: the line's short. We're confident.
→ continues to **8D**.

## `[Dialogic]` — 8C-Harvest. (Corrupt)

*(toast, voice_library §2.2 + §4.5 register):* **"You took a god's grief for parts. The clean endings close behind you, quietly, for good."**
NARRATION: The organ is the best thing in your drawer and it is still, faintly, ripening — fruit and rot at once, Demeter's cycle, severed and bottled and yours. Behind the Throat, the Heart of the Glut feels its guardian fall, and begins, slowly, to re-tile itself. The seal is open. Nothing is guarding *you* from the Heart now. Bram already knows. Bram is already walking away.
BRAM: *(cold, final)* You cut a guardian for parts. The mountain felt that. Walk careful in Titanfall now; the Old Weight keeps grudges longer than you'll keep breathing. *(beat)* The clans won't open to you. We *court* Legendaries. You *butchered* one in an afternoon, to spec, like the Iron Guild does it. Go to *them.* They'll call it honest work. It is. That's the worst part. It is.
→ continues to **8D**.

## `[Dialogic]` — 8D. The Slice Closes

NARRATION: The Throat of the Glut stands open behind you. The Heart waits — digesting terrain, regrowing walls, Demeter's generosity at its most total — gated, for now, until you're stronger. You've taken your first Legendary. You've courted your first faction. You've made your first marks on a grid that is starting to have *gravity.*
NARRATION: Somewhere in Threshold, your Reliquary file gains a paragraph. You haven't read it yet. You will. And when you do, your face will do the arithmetic that every god's face did before you — and somewhere, much later, a nobody you'll never meet will read *your* file, and feel it about *you.*

*(MVP slice end-card, voice_library §1.1 register):* **THE WORK CONTINUES.**

NARRATION *(rare 4th-wall, gated — only if the player opened ≥2 lore-trees this slice; voice_library §8):* "You've been so *careful,* haven't you. Reading the fine print. Sitting with the grief. Opening every door slowly. ...The careful ones make the best gods. And the saddest walls. We'll keep the file warm. Off you pop."

---

## Canon-fit summary (for the orchestrator)

**Scenes scripted (8):** *The Knack* (0.1, Threshold), *Altar Hours* (0.2, Threshold), *The Mark* (0.3, Threshold), *Registered* (0.4, Threshold Arena) — the Threshold hub block; *Greener Pastures, Hungrier Ones* (1.1, Verdant Glut), *The Mercy-Garden* (1.1-side, Verdant Glut), *What the Glut Won't Bury* (1.1-capstone, Verdant Glut), *The Guardian at the Seal* (1.3-adapted, Verdant Glut) — the Verdant Glut / Bloomwardens block.

**Formats delivered:** every scene is an authored **`[Dialogic]`** timeline (speaker · lines · 3–4-option player choices where it matters · genuinely divergent `→ goes to` branches · inline **>> GATE / >> CONSEQUENCE** tags). Five **`[Ink →]`** knots author the sprawling lore (The Altar's History · The Fine Print · The Glut's History · The Court's Receipt · The Guardian's Confession*) using real Ink syntax — `=== knot ===`, `* / +` choices, `-> diverts`, `{conditionals}`, and the bound externals `has_creature() / corruption() / faction_standing() / grid_axis() / has_flag() / set_flag()`.
> *Scene 8's `[Ink →]` THE GUARDIAN'S CONFESSION is referenced by all three Scene-8 finishes but its full knot body is the one piece I'd hand off for a dedicated lore pass — see Canon gaps. The three Dialogic finishes (8C-Bond/Register/Harvest) are complete and playable without it.

**Branching by the morality grid (not cosmetic):** every choice ticks `purity_corruption` and/or `order_chaos` explicitly, and the big forks diverge into *different scenes* — e.g. Scene 6's harvest **bars you from the Mercy-Garden** (the one Glut door that closes) and reroutes you toward the Pale Court; Scene 7's three paths open the **Bloomwarden Sworn track**, a **brokered truce**, or the **inverse Pale Court arc** with its own Ink tree; Scene 8 gates the **befriend** finish on having *defended the Glut* and gives **three different Lab futures** (never-need-Sacrifice / clean bounty / god-organ graft).

**Mechanics gated (all stated inline):** Capture (befriend/trap) + roster (S1) · Lab — Mutate + entropy meter (S2) · Arena + High Table standing + starting grid coordinate (S3) · Act 1 travel + faction-courting + notoriety (S4) · region access Verdant Glut + Lab — Mod + first Mend skill (S5) · full Mend/Soothe line + husbandry bond-growth boost (S6) · deep heart-grove access + Eros Legendary befriend target + husbandry uplift / inverse Pale Court arc (S7) · Legendary-tier capture + Lab — Sacrifice + god-organ-adjacent ingredient + Stoneblooded standing (S8).

**Canon kept exact:** 6 forces, the **8 verbs** (Strike·Drain·Ward·Mend·Hex·Rouse·Summon·Gambit, from `skills_statuses.md`), the Lab ops, currencies **₯ ✶ ◈**, the standing ladder, and the funny-grim register (lines pulled/adapted from `voice_library.md` with section citations). Verdant Glut creature/Legendary names (**Orchardmother**, Sporekin line, the Eros half-gods) and the **Throat of the Glut** seal are taken from `regions.md`. The dead-Titan / Mordathun and grid-god mappings from `_CANON_RATIFICATIONS.md` are respected (no contradiction).

### Canon gaps (flagged, not contradicted)

1. **NPC name reconciliation (the one real conflict).** `story_quests.md` uses placeholder names for several roles that `factions_npcs.md` / `regions.md` (the source-of-truth NPC rosters per the Brief) name canonically. I used the **canonical** names and bridged inline:
   - Bloomwarden **leader**: `story_quests.md` "Mother Sylva Greenrot" → **Greenmother Saoirse Lateharvest** (used).
   - Threshold **lab-services** giver: `story_quests.md` "Quintus Slagg" → **Surgeon-Lab-Tech Veil** (used).
   - Threshold **ratcatcher mentor**: `story_quests.md` "Old Marrow" → **Old Maddox Quillan** (the canonical tutorial mentor; used). *Recommend `story_quests.md` be updated to match at the next doc pass.*
2. **Bloomwarden leader vs. fringe patron — resolved, not a conflict.** `factions_npcs.md` names **Saoirse Lateharvest** (faction *leader*); `regions.md` names **Matron Sevvy** (fringe *mother-superior* / Stranger→Associate on-ramp). I scoped them distinctly — Sevvy is the local door, Saoirse the faction head. Confirm this two-tier read is intended (it reads clean).
3. **MVP Legendary identity.** `regions.md` offers **Orchardmother** *or* an Eros/Thanatos **Greenwatcher** as the slice Legendary. I scripted **Orchardmother** as primary (organic, Eros+Gaia). If the engine/art pipeline locks the Greenwatcher instead, only the boss name/force-flavor in Scene 8 needs a swap; the branch structure is identical.
4. **Scene 8 lore-tree (`THE GUARDIAN'S CONFESSION`) is referenced but not fully authored** — flagged deliberately as a dedicated-pass item. It's the natural home for the Orchardmother's dying/bonding monologue and the first in-grove preview of the Reliquary truth (per `story_quests.md` Q1.4). The three Dialogic finishes stand on their own; the knot is additive depth.
5. **Starter species under the Ribcage Undercroft.** `story_quests.md` Q0.1 sets the first catch "under the ribs of the dead Titan"; `regions.md` sets the tutorial catch in the **Foundling Pens** (Mother Kestrel). I used the **Foundling Pens** (the more-detailed, MVP-built location) and referenced a Glut-fringe Sporekin hatchling as the catchable. If the Undercroft is the intended tutorial site, S1's location swaps cleanly; the choice/gate structure is unaffected.

*Eight scenes, four hub + four Verdant, every fork gated and grid-weighted, five Ink lore-trees wired to live externals. The slice is playable on the page. — lead narrative scripter*

