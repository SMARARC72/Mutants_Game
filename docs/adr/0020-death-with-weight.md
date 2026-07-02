# ADR 0020 — Death With Weight: the mercy rule, the Last Light, and session trust

**Status:** Accepted (Wave 18, Realization Master Plan)
**Layer:** application only — HP / `is_dead` never enter `client/domain/`; no oracle constant,
golden vector, or canonical stream changed.

## Context

The plan's Wave 18 makes "death funds creation" real: a party creature can permanently die,
leave the party for a Graveyard memorial, and yield Lab parts. The binding co-requisite is a
TTK/threat sanity pass — *"a Graveyard nobody fills is set-dressing; one that fills every
fight is cruelty"* — and the Dracula veto forbids ever returning to consequence-free full-HP
rebuilds.

## Measurement (the existing balance pipeline, read-only)

`tools/balance_slice_check.py` still PASSES unchanged (no one-shots; every matchup mean in the
5–8 turn band). A read-only oracle probe over the same roster/seeds (300 seeds/matchup,
`battle_engine.simulate`, starter party vs the slice matchups) measured how often a party
creature ENDS a fight at 0 HP:

| matchup | losses | won-with-downed-member |
|---|---|---|
| starter vs T1 wild | 0% | 0% |
| starter vs T2 wild pair | 100% | 0% |
| starter vs T3 elite | 0% | **100% (2 of 3 downed every win)** |
| starter vs legendary boss | 100% | 0% |

Conclusion: "dies whenever it ends at 0 HP" would bury two starters on EVERY elite win
(cruelty), and a raw "loss kills the downed" would empty the party outright on any wipe
(a soft-lock — there is no recruit-from-zero path). Death must be gated by outcome, with a
survivor guarantee.

## Decision — the rule (deterministic, no rolls)

1. **Mercy rule (battle NOT lost — win / catch / stalemate / flee):** nobody dies. Every party
   creature that ended at 0 HP is dragged out by its coven at **1 HP, marked `scarred`**.
   The scar is a persisted mark on the creature dict; camp Rest clears it (for the essence fee).
2. **A LOST battle buries its dead:** every party creature that ended at 0 HP has `is_dead`
   set, leaves `run.party` for `run.flags["graveyard"]` (a memorial dict: name / species /
   sigil tag / cause / turn / region / parts / the dead creature record), and credits **1–2
   wild-rank parts** from `splice_rules.json`'s `ingredient_compat` through the
   InventoryAdapter — picked by FNV-1a over the creature's identity tag (LOCAL hash; the same
   death always yields the same remains; `god_core` is rank-filtered out).
3. **The Last Light:** on a lost battle the active/lead creature survives at 1 HP, scarred —
   a wipe costs every other downed creature *permanently* but can never empty the party.
4. **No re-softening (Dracula veto):** the dead never return; survivors carry their persisted
   wounds (`SkillMonFactory`/`MonFactory` keep the 1-HP floor for SURVIVORS only and skip
   `is_dead` entries outright); camp Rest heals wounds/scars, never graves.

Deaths therefore occur exactly as often as outright LOSSES — rare (the entropy dial and Flee
are always available; losing is a visible, avoidable outcome), fair (deterministic, no roll),
and felt (a loss now costs coven-mates forever, on top of the Wave 3 essence toll).

## Consequences

* `MortalityService` (application/game) owns the rule; `GameController.apply_battle_result`
  invokes it after the Wave 3 HP fold; results without `party_hp` (auto/boss round-trips)
  kill nobody, so canonical auto-battle behavior is unchanged.
* The death beat (battle screen): knell stinger + a 0.8s `mourn` desaturate pulse on the ONE
  existing grade pass (tension 9's two-pass cap holds — no new fullscreen shader) + an
  authored VoiceBook epitaph toast per memorial. Never the word "fainted". Instant/headless
  paths skip the tween, so every synchronous suite stays green.
* Session trust rides the same wave: `request_save()` + `save_succeeded/save_failed`,
  SaveSentry (toast / persistent warning / WM_CLOSE autosave), save inside `new_run`, and the
  Continue gate ("The ledger is illegible." dialog on an unparseable envelope).
