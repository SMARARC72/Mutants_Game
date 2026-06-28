# ADR-016 — AI selects, the deterministic engine resolves

**Status:** Accepted (Integrations §A2 / ADR-016) ·
**Phase:** Integration Cluster 4 (Mechanics) · **Deliverable:** D1 (CombatBrain) + D6 (parity probe)

## Context
Integration Cluster 4 adds battle AI: a Succession invasion boss with phased behaviour, plus
lightweight creature/role brains. The risk is identical to the rest of the cluster — AI logic could
leak a gameplay number or a non-reproducible decision out of the parity-tested oracle
(`client/domain/`), breaking full-battle replay and future server re-validation (TDD §6).

Two hard facts shape the design:

1. **The oracle's `BattleEngine.simulate(teamA, teamB, rng)` is a self-contained auto-battler.** It
   hardcodes target selection (`_first_alive`) and the offense pick, and exposes **no per-turn action
   hook.** It must stay UNTOUCHED — it is the parity oracle the golden vectors
   (`client/tests/golden/battle_engine.jsonl`) and `battle_engine_parity_test.gd` pin char-for-char.
2. **Determinism is non-negotiable.** Any randomness in AI selection that is not drawn from the
   canonical RNG (ADR-001) makes a battle non-replayable.

## Decision
**AI SELECTS, the engine RESOLVES.** Because `simulate` has no selection hook, the interactive/AI
battle mode is a NEW application-layer controller — the oracle is never modified.

- **`application/battle/battle_controller.gd`** drives the turn loop, mirroring `simulate`'s structure
  exactly (initiative = stable sort by −Celerity; per-turn entropy `rnd_dp(1.0+(turn−1)*0.12, 2)`;
  same-force chain ×1.3; opposed-force OVERLOAD roll), but obtains each actor's **target** from the
  brain and then **resolves the strike via `BattleEngine.attack(...)`** (the exposed per-strike
  resolver). `BattleEngine.simulate` stays the auto/parity oracle.
- **`application/ai/combat_brain.gd`** is THE FACADE: `choose_action(battle_state, rng) -> Action`,
  where `Action` is a plain `Dictionary` `{actor, target, offense}` (no Resource — ADR-012). The brain
  **never resolves and never computes a number.** Swapping the AI backend = reimplement this one file
  (Integrations §P3).
- **The non-negotiable RNG rule:** all selection randomness flows through a Blackboard
  (`application/ai/blackboard.gd`) → an **`RngService`** (`application/ai/rng_service.gd`) wrapping an
  injected canonical sub-stream — **never global `randf`/`randi`/`randomize` and never a BT/HSM addon's
  own RNG.** The controller derives **two disjoint sub-streams** from the run RNG: `RES_SALT` for
  resolution (the overload + crit rolls, in `simulate`'s exact order) and `SEL_SALT` for selection, so
  AI choices can never perturb the resolver's numbers.
- **The Succession invasion boss** is an **HSM** (`application/ai/hsm.gd`) of phases
  *Opening → Pressure → Desperation → Apotheosis*, each phase a **Behaviour Tree**
  (`application/ai/behavior_tree.gd`) selecting moves from the imported `god_snapshot` kit (supabase
  `god_snapshots`). Phase transitions are **Blackboard-gated** on own HP%, turn count, squad losses,
  and the entropy clock (`application/ai/succession_boss.gd`). Creature/role brains
  (`application/ai/role_brains.gd`: aggressor / support / controller) are lightweight BTs on the same
  Blackboard. Overworld NPC brains may be free-running (not simulation).

### LimboAI was not vendored — a self-contained BT/HSM ships instead
LimboAI ships a **GDExtension (native binary)** and a clean Godot-4.7 binary could not be vendored or
verified here (Godot is not installable in this environment). The spec explicitly permits a
self-contained GDScript BT/HSM in that case — *the SELECTION/determinism semantics matter more than
the specific library* (the same precedent as the Lab CSP under ADR-015). The vendored **Beehave**
(pure GDScript) was also unsuitable as the in-loop kernel: its `BeehaveTree` is a frame-ticked
SceneTree `Node` (`set_physics_process`/`actor_node_path`/`tick_rate`) and ships **no HSM**, whereas a
per-turn `choose_action()` needs a synchronous value-type tree that runs to completion in one
headless call. We therefore ship a tiny self-contained, synchronous BT + HSM with the SAME selection
semantics and the SAME Blackboard→RngService rule. See `client/addons/THIRD_PARTY.md`.

## Consequences
- **Replay/parity test** (`battle_controller_parity_test.gd`): with the neutral brain (first-alive
  target = `simulate`'s `_first_alive`) and the same resolution sub-stream, the controller reproduces
  `BattleEngine.simulate` **byte-for-byte** across golden seeds; and the same `(seed, teams, brain)`
  yields a byte-identical transcript across repeated runs (validated out-of-engine against the Python
  oracle for 39 golden cases).
- **Boss HSM test** (`succession_boss_hsm_test.gd`): every phase transition fires on its Blackboard
  gate (turn / HP% / squad-loss / entropy), and the phase path is deterministic.
- **Selection-purity test** (`combat_brain_selection_purity_test.gd`): a committed grep over
  `application/ai/` + `application/battle/` proves no `randf`/`randi`/`randomize`/addon-RNG appears,
  and decisions are driven only by the injected canonical stream. A matching CI grep gate enforces it.
- **D6 parity probe**: the dev-only LimboConsole `parity_battle` command (ADR-018) runs the GDScript
  `BattleEngine` on a golden seed, hashes the transcript, and diffs it against the committed Python
  golden vector — the manual counterpart to the automated parity gate (`parity_probe_test.gd`).
- **Nothing added to `client/domain/`**; the CI domain-purity grep gate stays green. The existing
  `battle_engine_parity_test.gd` (auto-sim) is unaffected — the oracle was not touched.
