# Lab Legality Engine — worked examples (companion to `splice_rules.json`)

Per `docs/Mutants_Game_SpliceRules.md` §5. Each shows the Legality Engine's result — **LEGAL / ILLEGAL(reason) / TABOO(unlock_cost)** — and the `splice_config` it hands to `lab_engine`. **The CSP never computes a stat;** `lab_engine` does. Player state shown as `{corruption, unlocks[]}`.

---

**1. Compatible fuse → LEGAL.** Fuse Ruinmaw (Chaos/Thanatos) × Gloamcat (Thanatos/Ouranos), precise, no taboo ingredients. Forces share Thanatos → not opposed → no gate.
→ `LEGAL` · config `{op:"fuse", force_intent:["Thanatos","Chaos"], tier_target:"T2", class_target:"organic", flags:{}}` → `lab_engine.fuse` blends Thanatos/Chaos T2 and computes stats + `entropy +14, corruption +0`.

**2. Opposed fuse → TABOO (gated).** Fuse a Cosmos/Eros × a Chaos/Ouranos, wild method. Cosmos⇄Chaos are opposed → `flags.taboo + abomination + world_bounty`; gate requires `corruption ≥ T_abom(40)` **or** unlock `abomination_rites`. Player `{corruption:35, unlocks:[]}`.
→ `TABOO` · returns "requires corruption ≥ 40 or the Abomination Rites (or an Opposed-Force Solvent)." With the `opposed_force_solvent` consumed, the gate eases → `LEGAL` → `lab_engine`: Cosmos/Chaos T3, `entropy +31, corruption +18`, world-bounty hook fires.

**3. Illegal graft → ILLEGAL.** Graft `crystal_lattice` (Cosmos, construct/hybrid only) onto an organic Thanatos beast with no bridging part. `ingredient_compat` fails (host class `organic` not in the part's `class`) and no `hybrid_bridge_graftplasm` present.
→ `ILLEGAL("crystal lattice rejects organic Thanatos flesh — no hybrid bridge")`. No creature produced.

**4. God-organ graft → TABOO→LEGAL.** Graft `hades_marrow` (rank `god`, Thanatos/Gaia) onto a T3 Thanatos beast. God-rank part trips `god_graft`; gate `all_of {corruption ≥ T_god(70), requires_part_rank:"god"}`. Player `{corruption:72, has:hades_marrow}`.
→ `LEGAL(taboo)` · config `{op:"graft", trait_slots:{marrow:"hades_marrow"}, flags:{taboo,god_graft,world_bounty}}` → `lab_engine` applies god-tier Drain trait + heavy corruption cost.

**5. Self-splice → TABOO/LEGAL.** Player self-grafts `aphrodite_unspent_heartbeat` (Eros, `class` includes `player`). `self_splice` is `always_gated`: `all_of {corruption ≥ T_self(85), unlock:auto_chirurgy}`.
→ Player `{corruption:80, unlocks:[auto_chirurgy]}` → `TABOO` ("corruption ≥ 85 required"). At `{corruption:88, unlocks:[auto_chirurgy]}` → `LEGAL` · config `{op:"self_splice", player_organ:"aphrodite_unspent_heartbeat", flags:{taboo,self_spliced,chimera,world_bounty}}` → `lab_engine` grants the force-power, writes player corruption, may lock the Pure ending.

**6. Reanimate a friend's god → LEGAL (contraband).** Reanimate using a `succession_snapshot_core` whose `input_kind:"god_snapshot"` is a **friend's** snapshot, with `necromancy` unlocked + a soul/core present. `reanimate` gate `all_of {unlock:necromancy, requires_part_type_any:[soul,core]}`; `god_snapshot` adds `god_graft + world_bounty`; friend's snapshot adds `contraband`.
→ `LEGAL` · config `{op:"reanimate", input_kind:"god_snapshot", source_player:"<friend>", flags:{taboo,reanimated,god_graft,world_bounty,contraband}}` → `lab_engine` reconstitutes from the stored lineage, tags the source player, escalates corruption.

**7. Organic+construct fuse without a bridge → ILLEGAL.** Fuse an organic Eros beast × a construct Cosmos automaton, no `hybrid_bridge_graftplasm`. `class_rule organic+construct = hybrid_requires_bridge`; no bridge → no legal `class_target`.
→ `ILLEGAL("flesh and frame will not hold without a hybrid bridge")`. Add `hybrid_bridge_graftplasm` → `LEGAL` with `class_target:"hybrid"`.

**8. Cross-force mutate → TABOO-lite.** Mutate a Gaia host with `vial_wild_spike` (Chaos gene). Gaia/Chaos aren't opposed, but a cross-force gene trips `mutate.taboo_when {gene_force_opposed_to_host}`/cross handling → `flags.taboo`, severity `taboo_lite`.
→ `TABOO(lite)` → with the gate met (or accepted) → `LEGAL` · config `{op:"mutate", gene_slots:["vial_wild_spike"], flags:{taboo}}` → `lab_engine` surfaces the Spike gene and applies an **entropy spike** (creature instability), not a world bounty.

---

**Reading the results in the UI:** `LEGAL` → commit enabled, "seal the rite." `TABOO` → commit shows the cost/unlock to proceed (dread microcopy from the voice library). `ILLEGAL` → commit disabled, the specific failing constraint surfaced in-voice. Backtracking guarantees a valid `splice_config` or a clean failure — never a half-formed creature.
