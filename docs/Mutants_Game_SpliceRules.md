# Mutants_Game — The Lab Legality Engine & `splice_rules` data model

**Status:** design · **Date:** 2026-06-27 · extends `Mutants_Game_Integrations.md` §A1.1, `Mutants_Game_Lab.md`, and the `lab_engine` oracle.
**What this is:** the rules layer that sits **in front of** `lab_engine` and decides *what recombinations are permitted and how their non-numeric configuration resolves* — encoded as **data**, solved by **godot-constraint-solving**'s generic CSP. It is the heart of the Creator engine; getting the data model right is what lets designers expand the Lab forever without touching GDScript or threatening parity.

---

## 0. The division of labor (read first — prevents the contamination trap)

There are **two** systems and a **hard line** between them. They must not duplicate each other.

| | **`lab_engine` (the oracle)** | **The Legality Engine (new, CSP over `splice_rules`)** |
|---|---|---|
| Owns | **All numbers + the mechanical blend:** force blend (primary 0.6 / secondary 0.4), tier escalation (`T1→T2→T3`, both-T3→T3), `stat_block` stats/HP/BST, entropy & corruption **costs**, mechanical taboo detection (opposed pair) | **The rules layer:** is this op *permitted*? which ingredient-driven **trait/gene/organ slots** are legal & non-conflicting? is a taboo op *unlocked*? which valid **config** when several exist? |
| Produces | the finished creature's **stats** | a validated **`splice_config`** (forces-intent, slots, flags, tier-target, permissions) that it hands to `lab_engine` |
| Determinism | ported, parity-tested (TDD §6) | pure rule eval; seeded choice via canonical RNG; **output persisted** |
| Lives in | `client/domain/` | `infrastructure/lab/` (behind `LabBench`) — **never** `domain/` |

**Flow:** `LabBench.preview(a, b, ingredients, method, player_state)` → **Legality Engine** returns `LEGAL` / `ILLEGAL(reason)` / `TABOO(unlock_cost)` + the candidate `splice_config`(s) → on commit, canonical RNG picks one → **`lab_engine.fuse(config, rng)`** computes the numbers → persist creature + `splice_config` (in `lineage`).

> **The rule of no-duplication:** the Legality Engine **never recomputes the force blend or any stat** — where it would overlap `lab_engine` (e.g. which forces result), **`lab_engine` is authoritative**. The CSP only governs *permission, ingredient/trait/flag resolution, tier-target legality, and choice among legal variants.*

---

## 1. Domain facts the rules build on (from the oracle, canonical)

- **Six forces:** Gaia, Ouranos, Cosmos, Chaos, Eros, Thanatos.
- **Opposed pairs** (`OPPOSED`): Cosmos⇄Chaos · Eros⇄Thanatos · Gaia⇄Ouranos. Fusing an opposed pair = **mechanical taboo** (abomination): huge power + entropy + player corruption + world bounty.
- **Tiers:** `T1→T2→T3` (`NEXT`), both-T3 stays T3. Ranks: wild / legendary / god / primordial.
- **Classes:** organic / construct (construct = built, needs plating/cores; stat mods).
- **Ingredient types** (from `inventory`): `organ` (trait), `gene-vial` (gene), `core`/`soul` (power), `scrap`/`plating` (material), `skill-vial`, `consumable`, `key`.
- **The four taboo operations** (Lab design): opposed-force **abomination**, **god-organ graft**, **self-splice** (player → chimera-god), **reanimation** (rebuild from Graveyard / a friend's `god_snapshot`).
- **Dual cost ledger:** routine work → creature **entropy**; big/taboo → player **corruption** (computed by `lab_engine`).

## 2. Operations & their preconditions

Each Lab op is a rule-set entry with **preconditions** the Legality Engine checks before anything else.

| Operation | Inputs | Baseline legality | Taboo / gated when… |
|---|---|---|---|
| **`fuse`** | creature a + b (+ optional ingredients) | legal for compatible/adjacent forces | **opposed forces** → TABOO (needs `corruption ≥ T_abom` **or** unlock `abomination_rites`) |
| **`mutate`** | 1 creature + gene-vial(s)/mutagen | legal if gene compatible w/ host force/class | cross-force gene → TABOO-lite (entropy spike) |
| **`graft`** (mod) | creature + organ/plating/core | legal for matching class/tier | **god-tier organ/core** → TABOO (needs the part **and** `corruption ≥ T_god`) |
| **`self-splice`** | the **player** + organ/core | always gated | requires `corruption ≥ T_self` + unlock `auto_chirurgy` |
| **`reanimate`** | a Graveyard part **or** a `god_snapshot` + cores | gated | requires `soul`/`core` + unlock `necromancy`; reanimating a friend's snapshot = special flags |

Thresholds (`T_abom`, `T_god`, `T_self`) live in `splice_rules` as data (not code), tunable per balance.

## 3. The CSP mapping (how godot-constraint-solving is driven)

The Legality Engine expresses each op as a **constraint-satisfaction problem**; the generic CSP solver finds a consistent assignment (with backtracking) or reports **no-solution → `ILLEGAL`**.

- **Variables** (the result's *non-numeric* config — never the stats):
  - `force_intent` (which of a/b's forces carry; **validated against**, not replacing, `lab_engine.blend`)
  - `tier_target` ∈ legal tiers given inputs + ingredients
  - `class_target` ∈ {organic, construct, hybrid}
  - `trait_slots[]` — one variable per available slot; domain = the legal organs/genes from the provided ingredients
  - `flags` — {taboo, abomination, god_graft, reanimated, chimera} (derived, constrained)
- **Domains:** the allowed values per the ruleset (e.g. `trait_slots[i] ∈ {compatible organs in inventory}`; `tier_target ∈ {max(tA,tB) … ceiling}`).
- **Constraints (the rules, as data):**
  1. **Force compatibility** — same/adjacent allowed; opposed sets `flags.taboo` and requires the gate.
  2. **Ingredient legality** — an organ/gene may occupy a slot only if compatible with `force_intent`/`class_target`; **conflicts** (two organs claiming the same body slot, or mutually-exclusive genes) are disallowed.
  3. **Tier ceiling** — `tier_target` cannot exceed `max(tA,tB)` unless a tier-raising ingredient (e.g. a `core`) is consumed.
  4. **Class rules** — construct outputs require `plating`/`core`; organic+construct → `hybrid` only with a bridging part.
  5. **Gate satisfaction** — any `flags` requiring a taboo gate must have its precondition met (`corruption`, `unlock`, the specific part); else the whole assignment is rejected.
- **Solve → result:**
  - a consistent assignment exists & no gate fails → **`LEGAL`** (+ the `splice_config`).
  - a consistent assignment exists **but** needs an unmet gate → **`TABOO`** (return the unlock/corruption cost so the UI can offer it).
  - no consistent assignment → **`ILLEGAL(reason)`** (the UI shows the specific failing constraint — dread microcopy).
- **Choice among legal variants:** if several assignments satisfy all constraints, pick one with `canonical_rng(run.seed, op_id)`. **Persist the chosen `splice_config`.**

> Backtracking guarantees a *valid* config or a *clean* failure — never a half-formed creature. That's the whole point of using a CSP over ad-hoc `if/else`.

## 4. The `splice_rules` authoring schema (data, versioned)

A single versioned ruleset, `res://catalog/splice_rules.json` (mirrored to `client/domain/constants` only for the *thresholds* it shares with the oracle). Designers edit this; **no GDScript changes** to add rules.

```jsonc
{
  "schema_version": 1,
  "forces": ["Gaia","Ouranos","Cosmos","Chaos","Eros","Thanatos"],
  "opposed": [["Cosmos","Chaos"],["Eros","Thanatos"],["Gaia","Ouranos"]],
  "thresholds": { "T_abom": 40, "T_god": 70, "T_self": 85 },   // player corruption gates
  "unlocks": ["abomination_rites","auto_chirurgy","necromancy"],
  "operations": {
    "fuse": {
      "inputs": { "creatures": 2, "ingredients": "optional" },
      "force_rule": "blend",                      // defers blend to lab_engine; CSP only validates legality
      "tier_rule": { "base": "max", "raise_with": ["core"] },
      "taboo_when": { "forces": "opposed", "gate": { "corruption": "T_abom", "or_unlock": "abomination_rites" } }
    },
    "graft": {
      "inputs": { "creatures": 1, "ingredients": "required" },
      "slots": { "organ": 1, "plating": "n", "core": "0..1" },
      "taboo_when": { "ingredient_rank": "god", "gate": { "corruption": "T_god", "requires_part": "god_core" } }
    }
    /* mutate, self_splice, reanimate … */
  },
  "trait_slots": {                                 // which body slots organs can occupy + conflicts
    "head": { "accepts": ["eye","horn","crest"], "conflicts_with": ["head"] },
    "core": { "accepts": ["heart","soul","reactor"], "max": 1 }
  },
  "ingredient_compat": {                           // organ/gene ↔ force/class legality
    "venom_gland": { "forces": ["Thanatos","Chaos"], "class": ["organic"] },
    "crystal_lattice": { "forces": ["Cosmos"], "class": ["construct","hybrid"] }
  }
}
```

**Output config** the engine hands to `lab_engine`:
```jsonc
{ "op":"fuse", "a":"<inst>", "b":"<inst>", "method":"precise",
  "force_intent":["Thanatos","Chaos"], "tier_target":"T3", "class_target":"organic",
  "trait_slots":{"head":"venom_gland"}, "flags":{"taboo":true,"abomination":true},
  "consumed":["gene_vial:venom","core:lesser"], "rng_seed_tag":"op_4f1a" }
```

## 5. Worked examples

1. **Compatible fuse (legal).** Thanatos/Chaos × Thanatos/Ouranos, precise, no taboo ingredients → CSP: forces adjacent, slots empty, no gate → **LEGAL** → `lab_engine` blends to Thanatos/Chaos T2, computes stats, `entropy +14, corruption +0`.
2. **Opposed fuse (taboo, gated).** Cosmos/Eros × Chaos/Ouranos, wild → CSP detects opposed → `flags.taboo`+`abomination`; player `corruption = 35 < T_abom(40)` and no `abomination_rites` → **TABOO**, returns "requires corruption ≥ 40 or the Abomination Rites." If unlocked → **LEGAL** → `lab_engine`: Cosmos/Chaos T3, `entropy +31, corruption +18`, world-bounty flag.
3. **Illegal graft.** Graft a `crystal_lattice` (Cosmos/construct-only) onto an organic Thanatos beast with no bridging part → `ingredient_compat` fails + no `hybrid` bridge → **ILLEGAL("crystal lattice rejects organic Thanatos flesh")**. No creature produced.
4. **God-organ graft (taboo).** Graft a `god_core` onto a T3 beast; player has the part + `corruption = 72 ≥ T_god(70)` → **LEGAL(taboo)** → `lab_engine` applies god-tier power + heavy corruption cost.

## 6. Persistence, reproducibility, server re-validation
- The chosen `splice_config` is persisted on the result creature (`creature_instances.lineage.splice_config`).
- Because the config is stored, the op reproduces exactly: re-running `lab_engine.fuse(config, rng)` yields the same creature. **The CSP need not re-run** for server re-validation (Succession) — the server re-applies **`lab_engine`** to the stored config (TDD §7.5).
- The `rng_seed_tag` records which canonical sub-stream chose the config (audit/replay).

## 7. Validating the ruleset itself (CI)
- **Coverage lint:** every force, op, and ingredient referenced in content exists in `splice_rules`; every `unlock`/threshold is defined.
- **Soundness property test:** for N random legal inputs, the solver's output **always** satisfies every constraint (no rule violated) — and illegal inputs always return `ILLEGAL`/`TABOO`, never a creature.
- **Parity test:** `lab_engine(config)` reproduces identical stats across the Python oracle and the GDScript port for the same persisted config + seed (ties into TDD §11.2 golden vectors).
- **Balance hooks:** thresholds + costs are data → tunable in the playtest sprint without code changes.

## 8. Why this is worth the rigor
The Lab is the signature system. Encoding its legality as **data solved by a CSP** gives three things ad-hoc code can't: **guaranteed-valid or clean-fail outputs** (no garbage creatures), **designer-expandable rules** (add an organ/gate/taboo by editing JSON), and a **clean parity boundary** (rules gate; the oracle computes). It turns "what can you splice?" from a maintenance liability into a content surface.
