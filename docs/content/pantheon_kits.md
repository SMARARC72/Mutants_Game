# MUTANTS_GAME — Pantheon Succession Kits & HSM Phase Logic

**Author:** combat/boss-design sub-agent · **Status:** content draft v0.1 · **Date:** 2026-06-27
**Source-of-truth read:** `Content_Generation_Brief.md`, `Creature_Codex_Book01_Pantheon.md` (the 42 Olympians/Titans + 6 Primordials), `Creature_Codex_Book05_Succession.md` (24 Dead Gods), `Mutants_Game_Battle.md`, `Mutants_Game_Skills.md`, `Mutants_Game_Character.md`.

---

## 0. How to read these kits (the contract)

Every kit below is **expressible by the live engines** — no invented stats, no off-pole forces. Conventions:

- **Stats are canon.** All god-rank bosses use the god budget **BST 1549** (one stat 594 + a secondary 439, the rest 129; Luck 32 / Focus 85; HP = `HPBASE + 3·Vitality`). Primordials use **BST 2400** (one stat 1400, all else 200; Luck 42 / Focus 120). Stats are copied from the codex entry, never re-rolled.
- **Damage** resolves on the locked formula `dmg = 1.5 · offense² / (offense + defense) × force_mult × entropy × chain × crit`. **Offense** = the higher of Spike/Bane; **Defense** = the higher of Bulk/Ward. **force_mult:** opposed ×1.5 · same ×0.7 · else ×1.0 (opposed pairs: **Cosmos⇄Chaos · Eros⇄Thanatos · Gaia⇄Ouranos**). **Entropy** ramps +12%/turn.
- **Kits are built from the 8 verbs** — Strike · Drain · Ward · Mend · Hex · Rouse · Summon · Gambit — drawn from the boss's primary (full) + secondary (partial) force pools. The **signature move is the canon one from the codex entry, used verbatim**; phase moves are pool-legal skills (sample pool in `Skills.md`) tuned to the boss's force-blend. Pole affinities: Eros→Mend, Thanatos→Drain, Cosmos→Ward, Chaos→Gambit, Gaia→guard/Strike, Ouranos→fast Strike.
- **HSM phases** are the LimboAI `CombatBrain` states: **Opening → Pressure → Desperation → Apotheosis.** Each lists what the boss *prioritizes* (its utility weighting) and the **Blackboard transition trigger** — a readable predicate over `boss_hp_pct`, `turn`, `squad_losses` (boss-side faints), `player_losses`, and `entropy` (the escalation clock). God fights are **multi-phase raids** (Battle.md), so phases gate real behavior change, not just bigger numbers.
- **Apotheosis** is the last stand — the phase where the boss leans into its pure pole and the entropy clock is its ally. Overclock (the mid-fight entropy surge) is a tool every Apotheosis can press once.
- **Succession tie:** each boss notes the **grid-god / Dead-God seed** it maps to (`Character.md` 3×3 grid + `Book05` DG-###). Your ascended champion can *become* this fight — these kits double as the template a snapshotted player-god is instanced into for a friend's / next run's invasion.

**Blackboard keys used below (read-only to the brain):** `boss_hp_pct` · `turn` · `entropy` · `squad_losses` (boss adds/summons that died) · `player_losses` (your faints) · `revive_locked` (set by OL-10-class effects) · `overclocked` (bool).

---

## 1. THE PRIMORDIALS — the pure-pole ceiling (superbosses)

> Six glass-gods. One towering stat at 1400, everything else at 200 (BST 2400). They are the **max-purity Apotheosis targets** — the true-ending wall. Design rule: a Primordial is *unbeatable on its own axis* and *paper on every other*. The fight is the player finding the off-axis seam before the entropy clock makes the god's one stat lethal. These are `summon`-only and only a pure-pole apotheosis can call them — which means **your own end-run champion, if it ascended pure, is instanced as one of these for the next run.**

### PR-Gaia — Gaia, the True Ground · **Primordial · Gaia (pure)**
- **Forces / grid:** pure Gaia (Bulk 1400 · all else 200 · HP 2800). Grid-anchor: the immovable pole *beneath* The Warden / The Lawgiver. Seed-kin: DG-007 *Keeper of the Sealed Mountain*, DG-021 *The Cathedral That Walked Away a Winner*.
- **Menace:** *"To stand on her is normal. To stand against her is a category error she will not notice making fatal."*
- **Kit (verbs × force):**
  - **Become the World** *(signature — Ward, Gaia)* — roots the entire field as her body; the squad shelters behind a planet's worth of Bulk and nothing moves her an inch.
  - **Boulder Smash** (Strike, Gaia) — her only offense; pure Bulk-into-Spike-channel, slow but it lands on the formation.
  - **Bulwark** (Ward, Gaia) — re-roots, refreshing the immovable when chipped.
  - **The Long Settling** (Hex, Gaia) — secondary-flavor weight that roots a striker in place (Gaia guard expressed as control); the ground closing politely.
- **The gimmick — *You cannot out-damage the planet.*** Her Bulk 1400 makes physical (Spike) and Bulk-mitigated hits near-worthless (defense dominates the formula). The seam is **Bane** (mystic offense vs her 200 Ward) **and Ouranos** (opposed ×1.5). The fight *teaches the defense stat*: every Spike attack pings for ~nothing until the player swaps to a Bane/Ouranos line. Entropy is her friend — given enough turns, even Boulder Smash one-shots, so the clock pressures you to find the seam fast.
- **HSM phases:**
  - **Opening** (`turn ≤ 2`) — priority: **Become the World** turn 1, then sit. She does nothing but exist and shrug. Teaches the player their Spike does nothing. → trigger: `turn > 2 OR player lands first Bane hit`.
  - **Pressure** (`boss_hp_pct > 60%`) — priority: alternate **Boulder Smash** on the most-clustered enemies and **Bulwark** re-root. Punishes formation. → trigger: `boss_hp_pct ≤ 60%`.
  - **Desperation** (`boss_hp_pct ≤ 60%`) — priority: **The Long Settling** on whoever carries the Bane/Ouranos seam (root the answer), Boulder Smash everything else. She starts targeting *the counter*. → trigger: `boss_hp_pct ≤ 25% OR entropy ≥ ×2.2`.
  - **Apotheosis** (`boss_hp_pct ≤ 25%`) — priority: **Overclock**, then Boulder Smash every turn at ramped entropy — now each blow is a landslide that can delete a creature. Become the World refreshes only if interrupted. Race condition: kill her before the clock turns her one move lethal. → win/lose resolves here.

### PR-Ouranos — Ouranos, the True Sky · **Primordial · Ouranos (pure)**
- **Forces / grid:** pure Ouranos (Celerity 1400 · all else 200 · HP 2800). Grid-anchor: the speed pole beneath The Free Wild / The Lawgiver's "first word." Seed-kin: DG-002 *The Foreseen, Ever-Early*, DG-008 *The Squall That Kept the Crown*.
- **Menace:** *"There is no going first against him. He is first."*
- **Kit (verbs × force):**
  - **Before You Finish the Thought** *(signature — Strike, Ouranos)* — acts before anything else on the field; a strike at the absolute speed of the open sky, landed before the turn is read.
  - **Gale Slash** (Strike, Ouranos) — fast filler Strike; cheap, always early in the order.
  - **Tailwind** (Rouse, Ouranos) — buffs *his own* initiative/evasion higher, widening an already untouchable speed gap.
  - **Outrun the Verdict** (Strike, Ouranos) — on a kill, takes a second action; the wind doesn't wait for permission.
- **The gimmick — *He always moves first, twice.*** Celerity 1400 means he acts at the top of every round and (via Outrun) again on any kill — the player is permanently on the back foot. But his Bulk/Ward are 200: **he dies to a single big hit if you survive to land it.** The fight is a race to alpha-strike through his evasion before he picks your squad apart one pre-emptive blow at a time. Seam: **Gaia** (opposed ×1.5) burst, or out-Lucking his evasion.
- **HSM phases:**
  - **Opening** (`turn ≤ 1`) — priority: **Tailwind** first (stack the speed lead), establishing that he goes before everyone. → trigger: `turn > 1`.
  - **Pressure** (`player_losses == 0`) — priority: **Gale Slash** the lowest-HP enemy to fish for a kill that procs **Outrun the Verdict** (double turn). Tempo bully. → trigger: `player_losses ≥ 1 OR boss_hp_pct ≤ 55%`.
  - **Desperation** (`boss_hp_pct ≤ 55%`) — priority: **Before You Finish the Thought** on the enemy's biggest threat each round, racing to thin the squad before they assemble lethal alpha. → trigger: `boss_hp_pct ≤ 25%`.
  - **Apotheosis** (`boss_hp_pct ≤ 25%`) — priority: **Overclock** + signature every turn; at high entropy his first-strike alone deletes a creature per round. The player must already have the killing blow loaded — there is no "next turn" against him. → resolves here.

### PR-Cosmos — Cosmos, the True Order · **Primordial · Cosmos (pure)**
- **Forces / grid:** pure Cosmos (Ward 1400 · all else 200 · HP 2800). Grid-anchor: the order pole beneath The Lawgiver / The Architect. Seed-kin: DG-021 *The Cathedral*, DG-023 *Reliquary-Frame "Stillwater"*.
- **Menace:** *"To break its rule you would first have to be the kind of thing its rule permits. You are not."*
- **Kit (verbs × force):**
  - **As It Is Written** *(signature — Ward, Cosmos)* — declares the rules absolute; caps all incoming harm to a trickle and **forbids variance — no crit, no chaos, no exception.**
  - **Aegis** (Ward, Cosmos) — re-seals the dome if cracked.
  - **Bind** (Hex, Cosmos) — orders an enemy out of sequence / silences a skill; the law disallowing your move.
  - **The Index Closes** (Ward→Hex, Cosmos) — converts absorbed variance into a stack that disables the player's most-used skill (order indexing your kit shut).
- **The gimmick — *It bans your luck.*** While **As It Is Written** holds, the player's crit and any Gambit/variance roll is **nullified** — pure-skill damage only, and Ward 1400 eats almost all of it. The seam is **Chaos** (opposed ×1.5, and Chaos *is* the variance it forbids — thematically the only thing that overrides the rule) and **Bane** (mystic vs its 200 everything-but-Ward… wait, Ward is its wall — so the real seam is raw Chaos burst that the ×1.5 multiplier makes land). The fight punishes crit-fishers and rewards a clean Chaos overload.
- **HSM phases:**
  - **Opening** (`turn ≤ 2`) — priority: **As It Is Written** turn 1; from now your crits read "0 — forbidden." Establishes the rule. → trigger: `turn > 2`.
  - **Pressure** (`boss_hp_pct > 50%`) — priority: **Bind** the enemy's Chaos/Gambit carrier (silence the answer), **Aegis** to refresh. Targets the counter on purpose. → trigger: `boss_hp_pct ≤ 50%`.
  - **Desperation** (`boss_hp_pct ≤ 50%`) — priority: **The Index Closes** to disable the player's best skill, stalling for the entropy clock to make its trickle-damage Boulder-of-rules lethal. → trigger: `boss_hp_pct ≤ 25% OR a Chaos overload cracks the dome`.
  - **Apotheosis** (`boss_hp_pct ≤ 25%`) — priority: **Overclock** under the seal — entropy ramps *its* output while the player's stays capped; "order, accelerating." Only a Chaos burst that beats the ×1.5 wall ends it. → resolves here.

### PR-Chaos — Chaos, the True Unmaking · **Primordial · Chaos (pure)**
- **Forces / grid:** pure Chaos (Spike 1400 · all else 200 · HP 2800). Grid-anchor: the ruin pole beneath The Devourer / The Reveler. Seed-kin: DG-010 *The Jester That Outlived the Court*, DG-022 *The Thunderfool Who Won Anyway*.
- **Menace:** *"It is not evil; evil is a structure, and it predates structure. It does not, on the whole, miss you."*
- **Kit (verbs × force):**
  - **The Gap Before Everything** *(signature — Gambit, Chaos)* — opens the original void under the enemy line for a Spike blast that **scales past any ward and any plan**; cannot be predicted, only survived.
  - **Riot Fang** (Strike, Chaos) — raw Spike filler, no setup.
  - **Overload** (Gambit, Chaos) — the big-button gamble; deletes squishies, spikes its own entropy (recoil per the Skills.md balance note).
  - **Unmake the Order** (Gambit→Hex, Chaos) — strips every active Ward/order-effect off the enemy line before the void opens.
- **The gimmick — *No defense saves you; only the clock kills it.*** Spike 1400 + the signature's ward-piercing means **there is no surviving a clean hit by armoring up** — the player must *out-pace* it (kill it first) or *deny its turns* (stun/silence). Its own Bulk/Ward are 200, so it is the original double-edged sword: a glass cannon at the absolute ceiling. Seam: **Cosmos** (opposed ×1.5) burst, or **Ouranos**-speed alpha before it acts — but note **As-It-Is-Written-style order-locks are its hard counter**, which is the deliberate Cosmos⇄Chaos mirror with PR-Cosmos. The two Primordials are designed as each other's answer.
- **HSM phases:**
  - **Opening** (`turn ≤ 1`) — priority: **Unmake the Order** to strip player wards turn 1 (so nothing is mitigated later), then idle-threat. → trigger: `turn > 1`.
  - **Pressure** (`player_losses ≤ 1`) — priority: **Riot Fang** / **Overload** on the squishiest target each round; it picks the squad apart one glass creature at a time. → trigger: `player_losses ≥ 2 OR boss_hp_pct ≤ 50%`.
  - **Desperation** (`boss_hp_pct ≤ 50%`) — priority: **The Gap Before Everything** on the densest cluster — unsurvivable-by-defense AoE; forces the player to have already won the tempo war. → trigger: `boss_hp_pct ≤ 25% OR entropy ≥ ×2.0`.
  - **Apotheosis** (`boss_hp_pct ≤ 25%`) — priority: **Overclock** + signature every turn. At ramped entropy the void deletes whole rows; the player either had the order-lock / lethal alpha ready or they didn't. Pure all-in. → resolves here.

### PR-Eros — Eros, the True Life · **Primordial · Eros (pure)**
- **Forces / grid:** pure Eros (Vitality 1400 · all else 200 · **HP 6400 — the Codex ceiling**). Grid-anchor: the life pole beneath The Warden / The Reveler. Seed-kin: DG-009 *Tender of the Ordered Garden*, DG-019 *The Worldmother, Still Blooming*.
- **Menace:** *"To be near it is to find yourself, alarmingly, recovering."*
- **Kit (verbs × force):**
  - **Everything That Ever Grew** *(signature — Mend, Eros)* — a heal so total it **raises the fallen, mends the unmendable, and keeps going each turn.** Life that does not run out.
  - **Bloom** (Mend, Eros) — squad heal-over-time top-up.
  - **Verdant Gift** (Rouse, Eros) — converts overflow vitality into offense buffs for itself (the relentless will to *be more*).
  - **Reclaim the Fallen** (Mend→Summon, Eros) — re-seeds a faint as a sapling adds, throwing bodies between you and it.
- **The gimmick — *It out-lives the entropy clock.*** HP 6400 + self-rez means you cannot win an attrition fight — chipping is hopeless because it heals faster than you scare it (the Battle.md/Book05 "wall-boss" problem at the absolute extreme). The seam is **Thanatos** (opposed ×1.5, *and* Drain's revive-suppression is the only thing that stops the self-rez) and **burst that beats the per-turn heal in one window**. The fight inverts the usual lesson: the entropy clock is the *player's* friend here — you must out-scale your own damage past its upkeep before it buries you under sheer green patience. **OL-10 / Thanatos revive-lock is the intended hard tech.**
- **HSM phases:**
  - **Opening** (`turn ≤ 2`) — priority: **Bloom** + **Everything That Ever Grew** to establish a heal floor the player can't yet out-damage. Tanks early, does nothing else. → trigger: `turn > 2`.
  - **Pressure** (`boss_hp_pct > 60%`) — priority: **Verdant Gift** to start hitting back (life-as-weapon), Reclaim any add that died. Begins out-scaling. → trigger: `boss_hp_pct ≤ 60%`.
  - **Desperation** (`boss_hp_pct ≤ 60%`) — priority: signature self-rez insurance + Bloom spam; if `revive_locked` is **false**, it heals toward full and the fight resets. The Thanatos check happens here: lock it or lose the race. → trigger: `boss_hp_pct ≤ 25% AND revive_locked == true`.
  - **Apotheosis** (`boss_hp_pct ≤ 25% AND revive_locked`) — priority: **Overclock** Verdant-Gift offense — having lost the heal-lock it goes for a desperate life-flood kill, racing to out-damage the player before its own ramped vitality runs the clock out. Only reachable *after* the revive is suppressed. → resolves here.

### PR-Thanatos — Thanatos, the True Ending · **Primordial · Thanatos (pure)**
- **Forces / grid:** pure Thanatos (Bane 1400 · all else 200 · HP 2800). Grid-anchor: the death pole beneath The Plaguelord / The Devourer. Seed-kin: DG-012 *The Pale Courier of Endings*, DG-024 *The Grudgekeeper of the Burnt Court*.
- **Menace:** *"The word is final, and it has never once been wrong."*
- **Kit (verbs × force):**
  - **The Last Subtraction** *(signature — Drain, Thanatos)* — an absolute Bane drain that withers the line toward nothing, **ignores resistance, and cannot be revived past.** What it takes does not come back.
  - **Soul Leech** (Drain, Thanatos) — sustain filler; chips Bane and tops its own HP.
  - **Wither** (Hex, Thanatos) — caps the player's offense, softening them for the subtraction.
  - **Mark the Ledger** (Hex→Drain, Thanatos) — sets `revive_locked` on the whole enemy line, so your dead stay dead (the mirror of PR-Eros's self-rez; these two bracket the life/death axis as designed opposites).
- **The gimmick — *Your dead do not come back; its drain ignores armor.*** Bane 1400 vs the formula's max-defense means stacking Ward/Bulk barely matters — it withers through everything. Worse, **Mark the Ledger revive-locks your squad**, neutering your own Graveyard/reanimation tech mid-fight, so every loss is permanent against the boss that *is* permanence. Seam: **Eros** (opposed ×1.5) burst and out-healing the drain faster than it subtracts — but it will try to revive-lock your healer-target first. The deliberate PR-Eros mirror: bring life to a death-fight, and it will try to make sure you can't.
- **HSM phases:**
  - **Opening** (`turn ≤ 2`) — priority: **Wither** the squad's offense, then **Soul Leech** to bank HP. Sets up the subtraction; quiet and total. → trigger: `turn > 2`.
  - **Pressure** (`player_losses == 0`) — priority: **Mark the Ledger** on the enemy with the strongest revive/heal kit (lock the answer), then Soul Leech. Targets your recovery on purpose. → trigger: `player_losses ≥ 1 OR boss_hp_pct ≤ 50%`.
  - **Desperation** (`boss_hp_pct ≤ 50%`) — priority: **The Last Subtraction** across the line every time it's up; with the ledger marked, each faint is final. Grinds the squad to nothing. → trigger: `boss_hp_pct ≤ 25%`.
  - **Apotheosis** (`boss_hp_pct ≤ 25%`) — priority: **Overclock** + signature every turn; ramped entropy makes the absolute drain a true line-wipe. The player needs the Eros-burst kill loaded *and* enough bodies left to land it. → resolves here.

---

## 2. THE NINE GRID-GODS — the Succession bosses you can *become* (Character.md 3×3)

> These nine are the ascension forms of the player's 3×3 grid (Order⇄Chaos × Purity⇄Corruption). When you take a throne ending, **your champion is snapshotted into the matching grid-god and seeded as a Succession boss** (Character.md "ASCEND → seeds the next run's Succession boss"). They are therefore the *most important* kits in this doc — the fights a friend / your NG+ inherits. Each is mapped to a **canon force-vector** (a real god-budget stat shape) and its **Book05 Dead-God seed**. Class is Organic unless the grid leans Machine (Iron Throne), which uses a Construct shape. Acquisition is `summon` (they are invaded/seeded, never caught), consistent with Book05.
>
> **Grid → force-vector key (so the snapshot is engine-valid):** Order leans **Cosmos/Gaia** (law, structure); Chaos leans **Chaos/Ouranos** (riot, liberty); Balanced sits **mixed**. Purity leans **Eros/Cosmos** (clean); Corruption leans **Thanatos/Chaos** (rot). The intersection picks the stat shape.

### THE LAWGIVER (Order · Pure) — Law/Heaven · **God · Gaia/Ouranos**
- **Forces / grid:** Gaia 594 / Ouranos 439 (Bulk-striker; the validated Saint-King ascension, Character.md). Stat shape = DG-001. **Seed: DG-001 *The Lawgiver, Twice-Crowned*.**
- **Menace:** *"He is back to enforce rules nobody can find the text of."*
- **Kit (verbs × force):**
  - **Edict of Standing Stone** *(signature — Strike, Gaia)* — plants and brings down a mountain's worth of verdict; Bulk-scaled, staggers the struck a turn.
  - **Boulder Smash** (Strike, Gaia) — filler verdict.
  - **Gale Slash** (Strike, Ouranos) — the secondary pole: a fast follow that lets the law *arrive first* on a key turn.
  - **Bulwark** (Ward, Gaia) — the law standing immovable while it judges.
- **The gimmick — *The verdict is read in order.*** A heavy, two-pole bruiser: Gaia weight that staggers + Ouranos speed to occasionally pre-empt. It announces its target a turn early (the "edict"), then lands it unstoppably — the player must read the telegraph and move the named creature or eat a stagger-lock. Punishes formations that don't respect the law's *queue*.
- **HSM phases:**
  - **Opening** (`turn ≤ 2`) — priority: **Bulwark** + **Boulder Smash**; establishes it as an immovable judge. → trigger: `turn > 2`.
  - **Pressure** (`boss_hp_pct > 55%`) — priority: **Edict of Standing Stone** on the highest-threat enemy, telegraphed; stagger-locks the carry. → trigger: `boss_hp_pct ≤ 55%`.
  - **Desperation** (`boss_hp_pct ≤ 55%`) — priority: chains **Gale Slash → Edict** (speed-pole into verdict) to land judgment before the squad can reposition. → trigger: `boss_hp_pct ≤ 25%`.
  - **Apotheosis** (`boss_hp_pct ≤ 25%`) — priority: **Overclock**; Edict every turn at ramped entropy — each verdict now one-shots through the stagger. The final ruling. → resolves here.

### THE ARCHITECT (Order · Tainted) — the master-builder · **God · Cosmos/Ouranos**
- **Forces / grid:** Cosmos 594 / Ouranos 439 (controller-warder; OL-12 *Sphairon the Vault-Keeper* force-shape). Seed-kin sits between Order's seeds. **Seed: new (Architect form) — closest Book05 echo DG-002 *The Foreseen, Ever-Early* (Ouranos/Cosmos tempo-controller).**
- **Menace:** *"It keeps the stars in their assigned seats and treats your disorder as a personal filing error."*
- **Kit (verbs × force):**
  - **Close the Firmament** *(signature — Ward, Cosmos)* — locks a crystalline dome over its side that caps incoming variance and freezes the enemy's turn order for a beat while it seals.
  - **Aegis** (Ward, Cosmos) — re-seal.
  - **Bind** (Hex, Cosmos) — orders an enemy skill shut / out of sequence.
  - **Tailwind** (Rouse, Ouranos) — the build runs *on schedule*: buffs its own initiative so the dome always lands before the player can break it.
- **The gimmick — *It edits the turn order.*** A tempo-controller: freezes/shuffles your sequence with the dome, then out-initiatives you to keep the lock up. The player fights the *clock and the queue*, not raw damage — the answer is a Chaos carrier (opposed ×1.5) that breaks the dome's variance-cap, or burst inside the freeze window. Tainted-Order: structure used to *deny*, not protect.
- **HSM phases:**
  - **Opening** (`turn ≤ 2`) — priority: **Tailwind** then **Close the Firmament**; establishes the queue-lock. → trigger: `turn > 2`.
  - **Pressure** (`boss_hp_pct > 50%`) — priority: **Bind** the enemy's Chaos/burst carrier (pre-empt the counter), refresh the dome with **Aegis**. → trigger: `boss_hp_pct ≤ 50%`.
  - **Desperation** (`boss_hp_pct ≤ 50%`) — priority: signature on cooldown + Bind chains, stalling for entropy while the player is sequence-locked. → trigger: `boss_hp_pct ≤ 25% OR the dome is broken by a Chaos overload`.
  - **Apotheosis** (`boss_hp_pct ≤ 25%`) — priority: **Overclock** under the dome; its capped-output ramps while yours is frozen. Break the firmament or lose to the schedule. → resolves here.

### THE IRON THRONE (Order · Corrupt) — the Machine · **God · Construct · Cosmos/Thanatos**
- **Forces / grid:** Cosmos 527 / Vitality 238 / Bane shape — the **Construct apex** budget (DG-023 *Reliquary-Frame "Stillwater"* stat shape: Bulk 161 · Ward 527 · Vit 238 · Bane 129, HP 2014, BST 1313). Corrupt-Order = order *weaponized into a machine that does not stop*. **Seed: DG-023 *Reliquary-Frame "Stillwater"* (re-skinned to the throne) / DG-005 *Engine of the Long Goodbye* for the colder builds.**
- **Menace:** *"The reliquary has been empty for ages. It guards it perfectly."*
- **Kit (verbs × force):**
  - **Enshrined Mercy** *(signature — Ward, Cosmos)* — a still, ordered ward over its side that caps variance and slowly mends the warded; nothing behind the glass is allowed to break.
  - **Aegis** (Ward, Cosmos) — re-shrine.
  - **Bind** (Hex, Cosmos) — order-locks an enemy skill.
  - **Decommission** (Drain, Thanatos) — the corrupt secondary: a cold Bane drain that "retires" the most-wounded enemy and revive-locks it (the machine deciding a unit is obsolete).
- **The gimmick — *It will not let your damage land, and it retires your wounded.*** A ward-bastion construct (Ward 527, self-mend) that out-lasts attrition, then **Decommission revive-locks** whatever you let drop — corrupt-Order as bureaucratic euthanasia. The seam is **Chaos** (vs Ward) burst to crack the shrine + **Eros** to out-heal Decommission; but as a Construct it ignores some organic interactions — flag for the Construct-patron domain. Highest staying power among the Order grid-gods.
- **HSM phases:**
  - **Opening** (`turn ≤ 2`) — priority: **Enshrined Mercy** + **Aegis**; builds an un-chippable wall. → trigger: `turn > 2`.
  - **Pressure** (`boss_hp_pct > 55%`) — priority: **Bind** the burst carrier, mend behind the shrine; out-lasting begins. → trigger: `boss_hp_pct ≤ 55% OR player_losses ≥ 1`.
  - **Desperation** (`boss_hp_pct ≤ 55%`) — priority: **Decommission** any wounded enemy (revive-lock it), shrine-refresh; converts your losses into permanent ones. → trigger: `boss_hp_pct ≤ 25%`.
  - **Apotheosis** (`boss_hp_pct ≤ 25%`) — priority: **Overclock** the ward + Decommission spam; it grinds the squad down under glass while the clock runs. Crack it with Chaos or be filed. → resolves here.

### THE WARDEN (Balanced · Pure) — the keeper · **God · Cosmos/Eros**
- **Forces / grid:** Ward 594 / Vitality 439 (warder-healer; OL-21 *Halcyone the Mending Order* / DG-009 *Tender of the Ordered Garden* shape, HP 2617). The "nothing here dies on my watch" pole. **Seed: DG-009 *The Tender of the Ordered Garden* (Book05 durability ceiling).**
- **Menace:** *"You will spend the whole fight chipping at a wall that is healing faster than you are scared, and behind its sigils it is humming."*
- **Kit (verbs × force):**
  - **Liturgy of the Living Wall** *(signature — Ward, Cosmos)* — an ordered sanctum that heals its own swelling vitality each turn and bleeds absorbed harm back as regrowth; out-damage the upkeep or lose.
  - **Aegis** (Ward, Cosmos) — re-sanctify.
  - **Bloom** (Mend, Eros) — squad heal-over-time.
  - **Set the World to Rights** (Ward, Cosmos) — converts a share of absorbed variance into a heal for its most-hurt unit (OL-21's order-that-tucks-you-in).
- **The gimmick — *It out-lives you, kindly.*** Pure-Balanced sustain: a regenerating fortress that wins by attrition, not aggression. The Book05 wall-boss — "chipping is hopeless." Seam: **burst that beats per-turn upkeep in one window** + **Thanatos** (opposed ×1.5 vs its Eros half) to suppress the regrowth. The honest, gentle version of the same problem the Iron Throne solves with cruelty.
- **HSM phases:**
  - **Opening** (`turn ≤ 2`) — priority: **Liturgy** + **Bloom**; sets a heal floor. → trigger: `turn > 2`.
  - **Pressure** (`boss_hp_pct > 60%`) — priority: **Set the World to Rights** to recycle your damage into its healing; pure stall. → trigger: `boss_hp_pct ≤ 60%`.
  - **Desperation** (`boss_hp_pct ≤ 60%`) — priority: Aegis + Bloom spam to deny burst windows; if you can't out-pace upkeep, the fight resets. → trigger: `boss_hp_pct ≤ 25%`.
  - **Apotheosis** (`boss_hp_pct ≤ 25%`) — priority: **Overclock** the regrowth — it heals *faster* as it dies; the player needs the one-window kill loaded. It never strikes back; it simply refuses to end. → resolves here.

### THE BROKER (Balanced · Tainted) — the dealmaker · **God · Cosmos/Thanatos**
- **Forces / grid:** Ward 594 / Bane 439 (warder-attrition controller; OL-23 *Sepulcrast* / DG-015 *Archivist of Silent Things* shape). The middle-path operator who *trades* — protection for a price, life for a debt. **Seed: DG-015 *The Archivist of Silent Things*.**
- **Menace:** *"Everything you do is filed. It is not cruel — it is thorough, which is so much worse."*
- **Kit (verbs × force):**
  - **Sealed in the Record** *(signature — Hex, Cosmos)* — inscribes a target into a binding glyph that silences one skill and drains it shut each turn; high-Focus victims hold out longer before the page closes.
  - **Aegis** (Ward, Cosmos) — keeps itself behind glass while it works.
  - **Wither** (Hex, Thanatos) — caps an enemy's offense (softening the ledger entry).
  - **The Locked Sepulchre** (Ward, Cosmos) — seals its side; anything striking the seal withers (OL-23: a door that is also a sentence).
- **The gimmick — *It silences your kit one skill at a time.*** A control-attrition warder that disables your moves on a timer — the longer the fight, the fewer buttons you have, until your squad is functional but toothless. The player must *win before the record closes on their carry*. Seam: **Chaos** to break the seal + high-**Focus** units (which resist the silence longer — Focus is the soft counter the signature names). Tainted-Balance: neutrality as leverage.
- **HSM phases:**
  - **Opening** (`turn ≤ 2`) — priority: **The Locked Sepulchre** + **Aegis**; safe behind the seal. → trigger: `turn > 2`.
  - **Pressure** (`player_losses == 0`) — priority: **Sealed in the Record** on the enemy's highest-impact skill-user (silence the carry), **Wither** the rest. → trigger: `player_losses ≥ 1 OR boss_hp_pct ≤ 50%`.
  - **Desperation** (`boss_hp_pct ≤ 50%`) — priority: chain silences across the squad, draining each glyph shut; stalls for the clock. → trigger: `boss_hp_pct ≤ 25%`.
  - **Apotheosis** (`boss_hp_pct ≤ 25%`) — priority: **Overclock** + signature every turn; ramped entropy makes the drain-shut land fast and your silenced squad can't answer. Break the seal or be filed silent. → resolves here.

### THE PLAGUELORD (Balanced · Corrupt) — the rot-broker · **God · Thanatos/Eros**
- **Forces / grid:** Vitality 594 / Bane 439 *or* the Construct shape — uses DG-005 *Engine of the Long Goodbye* (Bulk 161 · Vit 238 · Bane 439, HP 2014) for the machine builds, or OL-29 *Philtanaë the Last Kindness* (Vit 594 / Bane 439, HP 3082) for organic. Corrupt-Balance: heal financed by rot, "care" that euthanizes. **Seed: DG-005 *Engine of the Long Goodbye* (Construct) / OL-29 echo (organic).**
- **Menace:** *"It will heal you, it will harm you, and it cannot tell the difference anymore. The brass plate still reads FOR YOUR COMFORT."*
- **Kit (verbs × force):**
  - **Mercy Protocol** *(signature — Drain, Thanatos)* — reaps Bane off the front line and reroutes a share into its own reservoir as healing; euthanasia with a service warranty.
  - **Soul Leech** (Drain, Thanatos) — sustain chip.
  - **Mercy Like a Knife** (Mend, Eros) — heals *its own* side off the life it drains out of yours (OL-29: the garden fed on the graveyard).
  - **Final Absolution** (Hex, Thanatos) — wraps a target in decay that drains and weakens defenses while the lord stays standing.
- **The gimmick — *Its healing is your damage.*** A drain-sustain attrition boss whose offense and self-heal are the *same* action — every point it takes off you, it banks. You can't out-trade it; the seam is **Eros** to out-heal the drain + burst to outrun the reservoir, while **revive-lock awareness** matters (it euthanizes wounded). Corrupt-Balance literalized: mercy and murder as one verb. (Construct build flags the Construct-patron domain.)
- **HSM phases:**
  - **Opening** (`turn ≤ 2`) — priority: **Final Absolution** on the squad's anchor, then **Soul Leech**; sets the rot. → trigger: `turn > 2`.
  - **Pressure** (`boss_hp_pct > 55%`) — priority: **Mercy Protocol** to convert your line's HP into its own; the trade-engine spins up. → trigger: `boss_hp_pct ≤ 55%`.
  - **Desperation** (`boss_hp_pct ≤ 55%`) — priority: **Mercy Like a Knife** to heal toward full off your wounded; if you can't out-burst it, it stabilizes. → trigger: `boss_hp_pct ≤ 25%`.
  - **Apotheosis** (`boss_hp_pct ≤ 25%`) — priority: **Overclock** the drain; at ramped entropy Mercy Protocol reaps the whole front line and heals it back to a wall. Out-heal and out-burst, or be comforted to death. → resolves here.

### THE FREE WILD (Chaos · Pure) — Liberty · **God · Chaos/Ouranos**
- **Forces / grid:** Spike 594 / Celerity 439 (nuker-disruptor; OL-40 *Pandemora* / DG-022 *Thunderfool* shape). Pure-Chaos = freedom without cruelty: wild, fast, unbound, *gleeful* rather than malicious. **Seed: DG-022 *The Thunderfool Who Won Anyway*.**
- **Menace:** *"A bolt with a personality, striking wherever it happens to be looking."*
- **Kit (verbs × force):**
  - **Let It All Out** *(signature — Gambit, Chaos)* — opens everything it's holding: a fast, Spike-soaked burst that strikes the line and scatters their order, releasing more the longer it was contained.
  - **Riot Fang** (Strike, Chaos) — raw Spike.
  - **Gale Slash** (Strike, Ouranos) — fast secondary-pole jab.
  - **Overload** (Gambit, Chaos) — big gamble, recoil downside (Skills.md balance note).
- **The gimmick — *The longer it waits, the bigger it blows.*** A fast glass-nuker that *builds* a Gambit if left alone — the player is forced to pressure it (denying the charge) while eating fast Chaos jabs, a tempo dilemma. Pure-Chaos so it disrupts *order* (shuffles turns) but never revive-locks or rots — liberty, not malice. Seam: **Cosmos** (opposed ×1.5) order-lock to *cancel the charge*, or kill it fast (Spike 594 but glass defenses). The benign mirror of the Devourer.
- **HSM phases:**
  - **Opening** (`turn ≤ 1`) — priority: **Gale Slash** to start fast and begin "containing" the big move (charge ramps with turns). → trigger: `turn > 1`.
  - **Pressure** (`boss_hp_pct > 55%`) — priority: **Riot Fang** jabs + scatter; baits the player into letting **Let It All Out** charge. → trigger: `boss_hp_pct ≤ 55% OR it has charged 3 turns`.
  - **Desperation** (`boss_hp_pct ≤ 55%`) — priority: **Let It All Out** at full charge — line-wide Spike + turn-scatter; then **Overload** follow-ups. The release. → trigger: `boss_hp_pct ≤ 25%`.
  - **Apotheosis** (`boss_hp_pct ≤ 25%`) — priority: **Overclock** + Gambits every turn; reckless, fast, all-in. It would rather go out loud than guard. Pressure it down or get scattered and deleted. → resolves here.

### THE REVELER (Chaos · Tainted) — the riot-host · **God · Chaos/Eros**
- **Forces / grid:** Spike 594 / Vitality 439 (disruptor / sustain-nuker; OL-25 *Bakchanyr the Revel-Lord* / DG-004 *Gardener of Wildfire* shape, HP 2617). The rare nuker that heals its own side. **Seed: DG-004 *The Gardener of Wildfire* (Chaos/Eros).**
- **Menace:** *"Decline its invitation and you insult it; accept and you may not come back the same."*
- **Kit (verbs × force):**
  - **The Party Turns** *(signature — Gambit, Chaos)* — pours the revel over the field: a Spike-heavy frenzy that **confuses the enemy's targeting** while the wine of it mends its own squad.
  - **Riot Fang** (Strike, Chaos) — Spike filler.
  - **Bloom** (Mend, Eros) — the revel sustaining its own.
  - **Bloom of Cinders** (Gambit, Chaos) — detonates its overgrown vitality into a Spike burst, then regrows the loss (DG-004: burns the harvest and replants it).
- **The gimmick — *It turns your squad against itself.*** A frenzy-nuker that **confuses your targeting** (you may hit your own) while healing through the chaos — so the player loses control of *who acts on whom*. Tainted-Chaos: revelry that *corrupts the crowd* without quite being malicious. Seam: **Cosmos** order-lock to clear confusion + **Thanatos** to suppress its self-heal. Sustain + disruption is a nasty combo — burst it before the party "turns" your carry.
- **HSM phases:**
  - **Opening** (`turn ≤ 2`) — priority: **Bloom** + **Riot Fang**; warms up the revel. → trigger: `turn > 2`.
  - **Pressure** (`boss_hp_pct > 55%`) — priority: **The Party Turns** to confuse the squad's targeting, healing itself in the chaos. → trigger: `boss_hp_pct ≤ 55%`.
  - **Desperation** (`boss_hp_pct ≤ 55%`) — priority: **Bloom of Cinders** burst + signature; takes everything, hands some back, takes it again. → trigger: `boss_hp_pct ≤ 25%`.
  - **Apotheosis** (`boss_hp_pct ≤ 25%`) — priority: **Overclock** the frenzy; ramped Party Turns confuses *and* hits hard while it heals — a feral celebration that won't end. Lock the confusion or lose the squad to itself. → resolves here.

### THE DEVOURER (Chaos · Corrupt) — the Abyss · **God · Chaos/Thanatos**
- **Forces / grid:** Spike 594 / Bane 439 (nuker-executioner; OL-27 *Aresh the War-Render* / DG-024 *Grudgekeeper* shape — the validated **Abyss** ascension, Character.md). Corrupt-Chaos = ruin that *compounds and consumes*. **Seed: DG-024 *The Grudgekeeper of the Burnt Court* / DG-010 *The Jester That Outlived the Court*.**
- **Menace:** *"To the Grudgekeeper every kill is an apology owed and collected. The books are about you now."*
- **Kit (verbs × force):**
  - **Settle the Score** *(signature — Drain, Thanatos)* — a vengeful soul-strike that reaps Bane and **stacks higher with every creature it has already felled this fight**; let it live and the rest of you do less and less.
  - **Riot Fang** (Strike, Chaos) — Spike filler.
  - **The Red Work** (Gambit, Chaos) — throws itself into the slaughter; every enemy that falls stacks its Bane higher for the rest of the fight (OL-27).
  - **Erase the Line** (Drain, Thanatos) — withers the front, drains hardest where the formation is already broken; below a threshold turns Gambit and doubles.
- **The gimmick — *Every kill makes it worse.*** A snowballing executioner: each faint you suffer permanently raises its Bane, so a slow loss is a death spiral — the corrupt-Chaos engine of compounding ruin. The player must **deny it kills early** (keep everyone alive through the opening) or it becomes unstoppable by mid-fight. Seam: **Cosmos/Eros** to prevent the first faints (deny the stack) + burst before it compounds. The dark mirror of the Free Wild; the Abyss the player can ascend into.
- **HSM phases:**
  - **Opening** (`turn ≤ 2`) — priority: **Riot Fang** + **Erase the Line** to fish for the *first kill* (the stack starts the spiral). Hunts the weakest. → trigger: `turn > 2 OR player_losses ≥ 1`.
  - **Pressure** (`player_losses ≤ 1`) — priority: **The Red Work** on the lowest-HP enemy; every faint compounds its Bane. → trigger: `player_losses ≥ 2 OR boss_hp_pct ≤ 50%`.
  - **Desperation** (`boss_hp_pct ≤ 50%`) — priority: **Settle the Score** with full stacks across the line; the snowball cashes in. → trigger: `boss_hp_pct ≤ 25%`.
  - **Apotheosis** (`boss_hp_pct ≤ 25%`) — priority: **Overclock** + Erase-the-Line's self-doubling Gambit; with stacks + entropy it wipes rows. If you fed it kills, you have already lost. → resolves here.

---

## 3. ICONIC OLYMPIANS & TITANS — the Act bosses (killing one reshapes its region)

> These are the named God-rank force-vectors from Book01 — **Act bosses**, the heart of the campaign opposition (Bosses_Rivals.md: "killing one reshapes its region"). Priority given to the **six canonical pantheon members** (Zeus/Hades/Hephaestus/Demeter/Dionysus/Ares-types) plus the most distinctive court-anchors and elder Titans. All use the god budget (BST 1549); the signature is the canon Book01 skill verbatim. Acquisition per Book01 (`summon`/`befriend`). These are *not* the player-ascension forms (those are §2) — they are the world's standing gods, fought on the way up.

### OL-11 — Astrapios, the Sky-Sovereign · **God · Ouranos/Cosmos** *(canonical Zeus-type, king of the pantheon)*
- **Forces / grid:** Celerity 594 / Ward 439 (nuker-king; HP 1687). The reigning king — Ouranos speed on a Cosmos backbone (the sovereign, not the storm-vandal). Court of the Open Sky.
- **Menace:** *"He rules by being first — first to speak, first to strike, first to decide the matter closed."*
- **Kit (verbs × force):**
  - **The Final Word** *(signature — Strike, Ouranos)* — a single ruling bolt, fastest action on the field, crushing Celerity-scaled damage to one target that **silences its next skill**; the sky does not appeal.
  - **Gale Slash** (Strike, Ouranos) — fast filler bolt.
  - **Aegis** (Ward, Cosmos) — the sovereign's order-backbone; shields itself/its line.
  - **Bind** (Hex, Cosmos) — orders an enemy out of sequence (royal decree as control).
- **The gimmick — *The king silences dissent.*** A fast nuker that pairs first-strike burst with a **silence**, shutting down the player's key skill on the turn it would matter, all from behind a Cosmos ward. Reads as a *throne* fight: it controls the conversation. Seam: **Gaia** (opposed ×1.5) and **Chaos** (vs its Ward) — the storm-vandal forces it can't out-order. Defeating it cracks open the Open-Sky region.
- **HSM phases:**
  - **Opening** (`turn ≤ 1`) — priority: **Aegis** + **The Final Word** on the enemy carry (silence + tempo lead). Establishes dominion. → trigger: `turn > 1`.
  - **Pressure** (`boss_hp_pct > 55%`) — priority: **Bind** the biggest threat, **Gale Slash** to keep tempo; rules by sequence. → trigger: `boss_hp_pct ≤ 55%`.
  - **Desperation** (`boss_hp_pct ≤ 55%`) — priority: **The Final Word** every cooldown on whoever the player just enabled (silence the answer). → trigger: `boss_hp_pct ≤ 25%`.
  - **Apotheosis** (`boss_hp_pct ≤ 25%`) — priority: **Overclock**; the bolt at ramped entropy one-shots and silences — the last word, literally. → resolves here.

### OL-10 — Aidaneus, the Underlord · **God · Thanatos/Gaia** *(canonical Hades-type)*
- **Forces / grid:** Bane 594 / Gaia 439 (attrition controller; HP 1687). The king downstairs — thorough, not cruel. Court of the Hollow. **Revive-lock is his signature tech** (flag for Graveyard/reanimation systems).
- **Menace:** *"He governs the dead with the weary competence of a man who knows your name is on a future page."*
- **Kit (verbs × force):**
  - **The Lord's Due** *(signature — Drain, Thanatos)* — claims his portion: heavy Bane drain across the enemy line that feeds him HP per soul skimmed and **marks the dying so they cannot be revived.**
  - **Soul Leech** (Drain, Thanatos) — sustain chip.
  - **Wither** (Hex, Thanatos) — caps offense (collecting the debt early).
  - **Bulwark** (Ward, Gaia) — his Gaia half; the immovable ledger-keeper.
- **The gimmick — *He collects, and the collected stay dead.*** Line-wide drain that sustains *him* while **revive-locking your fallen** — directly neutering the player's Graveyard/reanimation loop, the one boss who turns your own death-economy off. Seam: **Eros** (opposed ×1.5) out-heal + burst before the ledger fills; keep nobody dying (no souls to skim). Killing him reshapes the Hollow region and (lore) leaves the underworld unmanaged.
- **HSM phases:**
  - **Opening** (`turn ≤ 2`) — priority: **Wither** the line, **Bulwark** himself; sets up the collection. → trigger: `turn > 2`.
  - **Pressure** (`player_losses == 0`) — priority: **The Lord's Due** to drain + pre-mark; banks HP and locks the morgue. → trigger: `player_losses ≥ 1 OR boss_hp_pct ≤ 50%`.
  - **Desperation** (`boss_hp_pct ≤ 50%`) — priority: signature every cooldown + Soul Leech; sustains through your burst while your dead stay down. → trigger: `boss_hp_pct ≤ 25%`.
  - **Apotheosis** (`boss_hp_pct ≤ 25%`) — priority: **Overclock**; ramped Lord's Due is a sustaining line-wipe and every faint is permanent. Out-heal him fast or be collected in order. → resolves here.

### OL-04 — Hephaestion, Patron of the Forge · **God · Cosmos/Gaia** *(canonical Hephaestus-type)*
- **Forces / grid:** Ward 594 / Bulk 439 (tank / patron-warden; HP 1687). The crooked-legged smith; slowest god to the fight, surest to still be standing. Court of Order; the **Construct-foundry's divine patron** (organic↔construct bridge).
- **Menace:** *"He is the patron of everything made, which in his view includes grudges, kept at the same exacting tolerances as his blades."*
- **Kit (verbs × force):**
  - **Anvil of the Made World** *(signature — Ward, Cosmos)* — forges a tempered aegis onto an ally that **hardens each turn it survives**, and reforges a sliver of every blow it eats into returned guard. Patience, in hammer-strokes.
  - **Aegis** (Ward, Cosmos) — re-temper.
  - **Bulwark** (Ward, Gaia) — the anvil's own weight.
  - **Summon: Forged Servitor** (Summon, Cosmos/Gaia) — the patron *makes things*: calls a Construct add to soak and strike (foundry flavor; ties the Construct-patron domain).
- **The gimmick — *He gets harder the longer you take.*** A scaling tank whose ward *compounds* every turn it survives — a slow fight is a losing fight, the inverse of a burst check. He also **summons Construct adds**, turning a duel into a managed raid. Seam: **Chaos** (opposed ×1.5 vs his Ward) burst *before the aegis stacks*, and clearing adds fast. The patron fight that teaches "don't let the smith finish the work."
- **HSM phases:**
  - **Opening** (`turn ≤ 2`) — priority: **Anvil of the Made World** on himself + **Summon: Forged Servitor**; the forge lights. → trigger: `turn > 2`.
  - **Pressure** (`boss_hp_pct > 55%`) — priority: re-temper the most-hit unit, summon a second servitor; the aegis stacks climb. → trigger: `boss_hp_pct ≤ 55%`.
  - **Desperation** (`boss_hp_pct ≤ 55%`) — priority: **Bulwark** + Aegis to ride out burst windows behind the returned-guard reflect. → trigger: `boss_hp_pct ≤ 25%`.
  - **Apotheosis** (`boss_hp_pct ≤ 25%`) — priority: **Overclock**; a fully-stacked aegis + reflect makes him near-unkillable as the clock runs — crack him before the work is finished. → resolves here.

### OL-08 — Demarei, the Harvest-Mother · **God · Eros/Gaia** *(canonical Demeter-type)*
- **Forces / grid:** Vitality 594 / Bulk 439 (regenerator / sustain-engine; **HP 3082 — highest of the 42 gods**). The durability ceiling of the pantheon. Court of the Bloom. **Seed-kin: DG-019 *The Worldmother, Still Blooming*.**
- **Menace:** *"Generous to a fault and vindictive on a calendar. When she grieves, she takes the seasons with her."*
- **Kit (verbs × force):**
  - **Year of Plenty** *(signature — Mend, Eros)* — sows the field; the whole squad regenerates a swelling share of HP each turn, and a **fallen ally roots back once per battle** as a sapling.
  - **Bloom** (Mend, Eros) — heal-over-time top-up.
  - **Bulwark** (Ward, Gaia) — her Gaia half; the immovable field.
  - **Verdant Gift** (Rouse, Eros) — feeds the harvest into the squad's offense.
- **The gimmick — *Famine on a calendar.*** The pantheon's sustain ceiling: a self-rezzing regenerator (HP 3082) you cannot grind down — and lore-coded so *killing her starves a region* (the world reacts). Seam: **Thanatos** (opposed ×1.5) to suppress the regrowth + revive-lock the once-per-battle sapling + burst past upkeep. The benign twin of the Warden, at higher HP. Reshapes the Bloom region into famine on death.
- **HSM phases:**
  - **Opening** (`turn ≤ 2`) — priority: **Year of Plenty** + **Bloom**; the heal floor is enormous. → trigger: `turn > 2`.
  - **Pressure** (`boss_hp_pct > 60%`) — priority: **Verdant Gift** to start contributing offense while out-healing; **Bulwark** as needed. → trigger: `boss_hp_pct ≤ 60%`.
  - **Desperation** (`boss_hp_pct ≤ 60%`) — priority: re-trigger the sapling-rez if an ally fell; heals toward full if not revive-locked. The Thanatos check lands here. → trigger: `boss_hp_pct ≤ 25%`.
  - **Apotheosis** (`boss_hp_pct ≤ 25%`) — priority: **Overclock** the regen; she out-heals the clock unless burst in one window. Generous to the last, on her schedule. → resolves here.

### OL-25 — Bakchanyr, the Revel-Lord · **God · Chaos/Eros** *(canonical Dionysus-type)*
- **Forces / grid:** Spike 594 / Vitality 439 (disruptor / sustain-nuker; HP 2617). The rare nuker that heals its own side. Court of Misrule. *(Note: this is the standing-god Act-boss; THE REVELER in §2 is the player-ascension form built on the same vector — distinct fights, same flavor root.)* **Seed-kin: DG-004 *Gardener of Wildfire*.**
- **Menace:** *"He cannot tell a triumph from a riot, having started both."*
- **Kit (verbs × force):**
  - **The Party Turns** *(signature — Gambit, Chaos)* — pours the revel over the field: a Spike-heavy frenzy that **confuses enemy targeting** while the wine mends his own squad.
  - **Riot Fang** (Strike, Chaos) — Spike filler.
  - **Bloom** (Mend, Eros) — the revel sustaining its own.
  - **Overload** (Gambit, Chaos) — the wild big-button (recoil downside).
- **The gimmick — *Triumph and riot are the same move.*** A frenzy-nuker that disrupts your control (confusion) and heals through it — sustain + chaos, hard to pin down. Act-boss framing: he hosts the Misrule region, and beating him sobers it up. Seam: **Cosmos** order-lock to clear confusion + **Thanatos** to stop the self-heal. Burst before the party turns your line.
- **HSM phases:**
  - **Opening** (`turn ≤ 2`) — priority: **Bloom** + **Riot Fang**; the revel builds. → trigger: `turn > 2`.
  - **Pressure** (`boss_hp_pct > 55%`) — priority: **The Party Turns** to confuse + self-heal; the floor gets slippery. → trigger: `boss_hp_pct ≤ 55%`.
  - **Desperation** (`boss_hp_pct ≤ 55%`) — priority: **Overload** bursts between Party Turns; chaotic and sustaining. → trigger: `boss_hp_pct ≤ 25%`.
  - **Apotheosis** (`boss_hp_pct ≤ 25%`) — priority: **Overclock** the frenzy; ramped confusion + Spike while he heals. Lock it or lose the squad to itself. → resolves here.

### OL-27 — Aresh, the War-Render · **God · Chaos/Thanatos** *(canonical Ares-type)*
- **Forces / grid:** Spike 594 / Bane 439 (nuker / executioner; HP 1687). War as butchery; loud, gory, insecure — never once stopped while ahead. Court of Misrule. *(Standing-god Act-boss; THE DEVOURER in §2 shares this vector as the Abyss ascension — distinct fights.)* **Seed-kin: DG-024 *Grudgekeeper*.**
- **Menace:** *"He does not win wars so much as feed them."*
- **Kit (verbs × force):**
  - **The Red Work** *(signature — Gambit, Chaos)* — throws himself into the slaughter for a Spike-heavy strike, and **every enemy that falls this fight stacks his Bane higher** for the rest of it. War that compounds.
  - **Riot Fang** (Strike, Chaos) — Spike filler.
  - **Wither** (Hex, Thanatos) — softens a target for the kill.
  - **Soul Leech** (Drain, Thanatos) — chips and sustains off the carnage.
- **The gimmick — *He compounds on corpses.*** A snowballing executioner — each faction he fells permanently raises his Bane, so the fight gets worse the longer (and bloodier) it runs. Act-boss check: **deny him kills**, burst him before the slaughter compounds. Seam: **Cosmos/Eros** to prevent faints + alpha. Killing him stills the war in the Misrule region.
- **HSM phases:**
  - **Opening** (`turn ≤ 2`) — priority: **Wither** + **Riot Fang** hunting the weakest (the first kill starts the stack). → trigger: `turn > 2 OR player_losses ≥ 1`.
  - **Pressure** (`player_losses ≤ 1`) — priority: **The Red Work** on the lowest-HP enemy; feeds on faints. → trigger: `player_losses ≥ 2 OR boss_hp_pct ≤ 50%`.
  - **Desperation** (`boss_hp_pct ≤ 50%`) — priority: full-stack Red Work + Soul Leech; the carnage cashes in. → trigger: `boss_hp_pct ≤ 25%`.
  - **Apotheosis** (`boss_hp_pct ≤ 25%`) — priority: **Overclock** + Red Work every turn; with stacks + entropy he deletes the line. If you fed him, it's over. → resolves here.

### OL-31 — Tartaron the Buried Titan · **God · Gaia/Thanatos** *(elder Titan)*
- **Forces / grid:** Bulk 594 / Bane 439 (fortress / attrition Titan; HP 1687). The deep prison and the thing imprisoned at once; remembers being chained, and by whom. Court of Stone (elder). **Seed-kin: DG-006 *The Sexton-King of the Deep Loam*.**
- **Menace:** *"The young gods do not summon him lightly; he remembers being chained, and by whom."*
- **Kit (verbs × force):**
  - **The Pit Remembers** *(signature — Hex, Thanatos)* — drags the enemy line toward the deep places: a **rooting curse that grows heavier each turn** and grinds down their offense, while his Titan-Bulk ignores the struggle.
  - **Bulwark** (Ward, Gaia) — the buried weight.
  - **Wither** (Hex, Thanatos) — extra offense-cap.
  - **Soul Leech** (Drain, Thanatos) — slow sustain from the rooted.
- **The gimmick — *Down is the only direction.*** A fortress-jailer that **roots harder every turn** — the player is progressively pinned and de-fanged while his Bulk 594 shrugs the reprisal, an attrition prison. A slow strangle, not a burst. Seam: **Ouranos** (opposed ×1.5 vs his Bulk) speed/evasion to escape roots + **Eros** to out-sustain the drain. Elder-Titan gravitas — beating him is breaking a chain the gods themselves set.
- **HSM phases:**
  - **Opening** (`turn ≤ 2`) — priority: **The Pit Remembers** turn 1 (start the root ramp) + **Bulwark**. → trigger: `turn > 2`.
  - **Pressure** (`boss_hp_pct > 55%`) — priority: deepen the root, **Wither** the line; mobility bleeds away. → trigger: `boss_hp_pct ≤ 55%`.
  - **Desperation** (`boss_hp_pct ≤ 55%`) — priority: **Soul Leech** the now-pinned squad + re-root anyone who broke free. → trigger: `boss_hp_pct ≤ 25%`.
  - **Apotheosis** (`boss_hp_pct ≤ 25%`) — priority: **Overclock**; max-stack roots + ramped drain bury the squad in place. Break free with speed or sink. → resolves here.

### OL-19 — Geometheus the Squared Circle · **God · Cosmos/Chaos** *(Court of Order)*
- **Forces / grid:** Ward 594 / Spike 439 (controller / warder; HP 1687). The rule that is correct *and armed*; builds certainties out of edges. *Note the rare same-entry opposed pairing (Cosmos primary, Chaos secondary) — a god who holds order and ruin at once.* **Seed-kin: DG-003 *She Who Audits the Storm* (Cosmos/Chaos).**
- **Menace:** *"Argue with him and the counterexample comes back point-first."*
- **Kit (verbs × force):**
  - **Proof by Contradiction** *(signature — Ward, Cosmos)* — raises a lattice that wards his side and, **when struck, answers each hit with a precise Spike retort aimed back along the line it came from.** Order that disproves you, sharply.
  - **Aegis** (Ward, Cosmos) — re-lattice.
  - **Riot Fang** (Strike, Chaos) — the armed-edge secondary; raw Spike.
  - **Bind** (Hex, Cosmos) — order-locks an enemy skill.
- **The gimmick — *Hitting it hurts you.*** A reflect-warder: the harder you swing, the harder his lattice swings back along your own line — punishing exactly the burst that beats most wards. The player must **out-think the reflect** (chip, or burst the lattice down between refreshes, or use forces it can't retort). Seam: **Chaos** (opposed ×1.5 vs his Ward) to overload the lattice + un-reflectable Drain/Hex pressure. A puzzle-boss for the Order region.
- **HSM phases:**
  - **Opening** (`turn ≤ 2`) — priority: **Proof by Contradiction** + **Aegis**; the armed lattice is up. → trigger: `turn > 2`.
  - **Pressure** (`boss_hp_pct > 50%`) — priority: keep the lattice live, **Bind** the burst carrier; punishes every big hit. → trigger: `boss_hp_pct ≤ 50%`.
  - **Desperation** (`boss_hp_pct ≤ 50%`) — priority: **Riot Fang** offense between reflects; now it hits *and* retorts. → trigger: `boss_hp_pct ≤ 25%`.
  - **Apotheosis** (`boss_hp_pct ≤ 25%`) — priority: **Overclock**; reflect + Spike at ramped entropy turns your own damage lethal to you. Disprove it with Chaos or it disproves you. → resolves here.

### OL-28 — Hollowmarch the Unmaking Step · **God · Thanatos/Chaos** *(Court of the Hollow)*
- **Forces / grid:** Bane 594 / Spike 439 (executioner / hexer; HP 1687). Plague and rout and the long retreat nobody survives, walking. Bears no malice — malice would imply he intends to stop. **Seed-kin: DG-024 *Grudgekeeper* / DG-010 *Jester*.**
- **Menace:** *"He bears you no malice; malice would imply he intends to stop."*
- **Kit (verbs × force):**
  - **Erase the Line** *(signature — Drain, Thanatos)* — a sweeping wither across the enemy front that **drains hardest where their formation is already broken** and lifesteals back; below a threshold it **turns Gambit and doubles**, careless of itself.
  - **Wither** (Hex, Thanatos) — break the formation open first.
  - **Riot Fang** (Strike, Chaos) — the Chaos edge; Spike chip.
  - **Soul Leech** (Drain, Thanatos) — sustain.
- **The gimmick — *It accelerates as it kills.*** Endings that pick up speed: the more broken your line, the harder Erase-the-Line drains — and at low HP it self-doubles into a reckless Gambit. A momentum-of-death boss; once your formation cracks, the subtraction snowballs. Seam: **Eros** (opposed ×1.5) out-heal + **keep the formation whole** (deny the "already-broken" bonus) + burst it before the threshold flip. A faster, formation-punishing cousin to the Underlord.
- **HSM phases:**
  - **Opening** (`turn ≤ 2`) — priority: **Wither** to crack the front open, **Soul Leech**. → trigger: `turn > 2`.
  - **Pressure** (`boss_hp_pct > 50%`) — priority: **Erase the Line** wherever the formation is weakest; drains scale with your disorder. → trigger: `boss_hp_pct ≤ 50%`.
  - **Desperation** (`boss_hp_pct ≤ 50%`) — priority: Erase-the-Line + Riot Fang to keep breaking the line; snowball builds. → trigger: `boss_hp_pct ≤ 25%`.
  - **Apotheosis** (`boss_hp_pct ≤ 25%`) — priority: **Overclock** + the self-doubling Gambit form of Erase the Line; reckless, accelerating, row-wiping. It does not intend to stop. → resolves here.

### OL-30 — Letheon the Sweet Forgetting · **God · Thanatos/Eros** *(Court of the Hollow)*
- **Forces / grid:** Bane 594 / Vitality 439 (controller / drain-support; HP 2617). The gentle end of death — the *forgetting*, the warm grey water where the pain and the name and the fight all quietly let go. **Seed-kin: DG-005 *Engine of the Long Goodbye* (Eros/Thanatos).**
- **Menace:** *"People who meet him at the river feel so much better, and so much less."*
- **Kit (verbs × force):**
  - **Drink of Oblivion** *(signature — Drain, Thanatos)* — offers the line a soft grey rest: a Bane drain that **strips active skills from memory (clears buffs, disables a skill)** and mends his own squad with what he siphons.
  - **Soul Leech** (Drain, Thanatos) — sustain chip.
  - **Wither** (Hex, Thanatos) — offense-cap.
  - **Bloom** (Mend, Eros) — the Eros half; tops his side off (the river's mercy).
- **The gimmick — *It makes you forget your own kit.*** A drain-controller that **wipes your buffs and disables skills** while healing through the theft — the player slowly loses access to their own plan, "peace, taken without asking." Sustain + skill-denial. Seam: **Eros** to out-heal + high-**Focus** units (resist the forgetting longer) + burst before your kit is erased. A control-attrition boss that softens the Hollow region into a hush.
- **HSM phases:**
  - **Opening** (`turn ≤ 2`) — priority: **Wither** + **Bloom**; the grey water rises. → trigger: `turn > 2`.
  - **Pressure** (`boss_hp_pct > 55%`) — priority: **Drink of Oblivion** on the most-buffed enemy (strip + disable), self-mend off the siphon. → trigger: `boss_hp_pct ≤ 55%`.
  - **Desperation** (`boss_hp_pct ≤ 55%`) — priority: chain Oblivion across the squad, erasing buffs and skills while topping himself. → trigger: `boss_hp_pct ≤ 25%`.
  - **Apotheosis** (`boss_hp_pct ≤ 25%`) — priority: **Overclock**; ramped Oblivion strips and disables fast while he heals to a wall. Burst through the hush or be gently forgotten. → resolves here.

---

## 4. Coverage, design notes & canon flags

**Boss count: 25 full kits.**
- **6 Primordials** (§1): PR-Gaia, PR-Ouranos, PR-Cosmos, PR-Chaos, PR-Eros, PR-Thanatos — the complete pure-pole ceiling.
- **9 grid-gods** (§2) — *the player-ascension Succession forms, the doc's priority set*: The Lawgiver, The Architect, The Iron Throne, The Warden, The Broker, The Plaguelord, The Free Wild, The Reveler, The Devourer. The full 3×3 grid (Character.md) is covered, each mapped to a valid force-vector + Book05 Dead-God seed.
- **10 iconic Olympians/Titans** (§3) — Act bosses: all **6 canonical pantheon members** (OL-11 Zeus / OL-10 Hades / OL-04 Hephaestus / OL-08 Demeter / OL-25 Dionysus / OL-27 Ares) + OL-31 Tartaron (elder Titan), OL-19 Geometheus (reflect-puzzle), OL-28 Hollowmarch (momentum-of-death), OL-30 Letheon (skill-erasure).

**Force balance check:** the 25 kits spread across all 6 forces with no pole skew — Gaia (PR-Gaia, Lawgiver, Tartaron), Ouranos (PR-Ouranos, Zeus, Free Wild), Cosmos (PR-Cosmos, Architect, Iron Throne, Warden, Broker, Hephaestus, Geometheus), Chaos (PR-Chaos, Free Wild, Reveler, Devourer, Dionysus, Ares), Eros (PR-Eros, Warden, Plaguelord, Reveler, Demeter), Thanatos (PR-Thanatos, Broker, Plaguelord, Devourer, Hades, Hollowmarch, Letheon, Tartaron). Cosmos and Chaos run slightly heavy because the *grid* itself is order/chaos-weighted (Order and Chaos rows) — intended, not a roster skew.

**Engine-validity confirmation:** every stat shape is copied from a real Book01/Book05 entry (no re-rolls); every signature is the canon skill verbatim; every phase move is pool-legal for the boss's force-blend per `Skills.md`; all transitions read only Blackboard keys the `CombatBrain` already exposes (HP%, turn, entropy, faints). Revive-lock (OL-10/PR-Thanatos/Iron Throne) and self-rez (PR-Eros/Demeter/Warden) are flagged as the intended hard-tech interactions with the Graveyard/reanimation systems.

**Canon gaps & flags (do not silently fix — your call):**
1. **Grid-god → force-vector mapping is *authored here*, not in canon.** Character.md names the 9 grid-gods and confirms 3 of them ascend (Lawgiver=Order/Pure, Devourer=Chaos/Corrupt, + the God-Maker refusal) but does **not** assign each grid-god a force-blend or stat shape. I mapped each to the nearest canon vector (e.g., Warden→Cosmos/Eros via OL-21/DG-009; Devourer→Chaos/Thanatos via OL-27/DG-024). **Recommend the systems session ratify these mappings** — they're the bridge between the player grid and the engine, and Character.md's "Open/next" explicitly lists "mapping each grid-god to its Succession boss form" as unbuilt.
2. **§2 grid-gods reuse §3/Book05 force-vectors by design** (e.g., The Reveler and OL-25 Bakchanyr both Chaos/Eros; The Devourer and OL-27 Aresh both Chaos/Thanatos). They are *distinct fights* (player-snapshot vs standing god) sharing a flavor root — intended, but flag if you want fully unique vectors per grid-god.
3. **No status-effect payload spec yet** (`Battle.md` / `Skills.md` "Open/next"). Kits reference Hex effects (root, silence, offense-cap, confusion, revive-lock, buff-strip) by intent; **exact magnitudes/durations are a playtest-tuning job**, not set here. Gambit downsides (recoil/self-entropy) likewise per the Skills.md balance note.
4. **Multi-phase god-raid structure** (`Battle.md` "Open/next: god-raid multi-phase structure") is the system these HSM phases assume. The 4-phase Opening→Pressure→Desperation→Apotheosis frame is proposed here; **confirm it matches the intended raid scaffold** before wiring `CombatBrain`.
5. **Construct apex builds** (Iron Throne, Plaguelord-machine) inherit Book05's Construct-shape budgets (BST ~1251–1329) — slightly under the organic god BST 1549. Flag the Construct-patron domain (OL-04 Hephaestion) for shared interactions.
6. **Overclock as a boss tool** is extrapolated from `Battle.md` (player-side "Overclock mid-fight for a surge at an entropy cost"). I gave Apotheosis-phase bosses a one-time Overclock; **confirm bosses may Overclock** or restrict to player-only.

*All 25 kits stay in canon, in the funny-grim register, and reference (never contradict) the written pantheon, player grid, and engines.*
