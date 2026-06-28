# Open-RPG → Mutants_Game pattern map (Phase 0.5)

**Reference, not a dependency.** GDQuest **Open-RPG** (MIT) is cloned **outside** the repo at
`../_reference/godot-open-rpg` (NOT committed). We adapt **patterns only** — never wholesale code,
and **never into `client/domain/`** (the domain is our pure, parity-tested oracle port; TDD §3.1, §6).
Open-RPG is MIT: keep attribution when we adapt non-trivial code. It targets Godot 4.5+; we're on 4.7.

> The companion **fenix-hub/supabase-examples** (MIT) is cloned at `../_reference/supabase-examples`
> (also not committed) and mapped at the bottom.

## Combat (→ Phase 2: domain port already exists; we learn the *shell*, not the math)

| Open-RPG file | What to learn | Our target module | Phase |
|---|---|---|---|
| `src/combat/combat.gd`, `combat_arena.gd`, `combat_events.gd` | Turn-queue loop, initiative ordering, event signalling | `client/application/battle_controller.gd` | 2 |
| `src/combat/actions/battler_action*.gd` (`_attack`, `_heal`, `_modify_stats`, `_projectile`) | Action/Command objects → serializable battle commands | `client/application/` commands (feeds the deterministic command log, §6.6) | 2 |
| `src/combat/battlers/battler.gd`, `battler_stats.gd` | How a combatant view-model wraps stats/HP **(shape only)** | `client/application/` battler view-model over our `domain/creature.gd` | 2 |
| `src/combat/combat_ai_random.gd`, `CombatAI.tscn` | AI action-selection structure | Beehave trees in `client/application/` — **⚠ AI randomness MUST use the canonical RNG sub-stream (ADR-001), never `randf`/Beehave RNG** | 2 |
| `src/combat/ui/ui_combat.tscn`, `ui/ui_combat.gd` | Battle HUD layout, action menu, target select | `client/presentation/screens/Battle/` | 5 |
| `src/combat/elements.gd` | Type/element-matchup table wiring **(structure only; our forces math is the oracle)** | reference for surfacing force matchups in UI | 5 |

**Hard rule:** the damage/stat/status math comes from the **ported engines** (`domain/`), never from
Open-RPG. We borrow the *orchestration + presentation*, not the numbers.

## Overworld / field (→ Phase 5)

| Open-RPG file | What to learn | Our target module | Phase |
|---|---|---|---|
| `src/field/gameboard/gameboard.gd`, `gameboard_layer.gd`, `pathfinder.gd` | Tile grid model + A* pathfinding | `client/presentation/screens/Overworld/` + a grid service | 5 |
| `src/field/gamepieces/gamepiece.gd`, `gamepiece_registry.gd` | Grid-snapped entity movement + registry | overworld entities | 5 |
| `src/field/field.gd`, `map.gd`, `field_camera.gd` | Field scene composition + camera follow | Overworld scene + **Phantom Camera** rig | 5 |
| `src/field/cutscenes/interaction.gd`, `trigger.gd`, `ui/dialogue_window.gd` | Interaction triggers → dialogue | **Dialogic**-driven NPC encounters | 5 |
| top-level `overworld/`, `combat/` assets | Scene/asset organization | informs `client/presentation/` layout | 5 |

## Inventory & transitions (→ Phase 3/5)
Open-RPG's inventory + map-transition wiring informs our inventory UI (Phase 5) over the `inventory`
table (already in schema), and screen/state transitions in `client/application/` (Phase 3/5).

## supabase-examples → our data/auth layer (→ Phase 3–4)

| Example (`../_reference/supabase-examples`) | What to learn | Our target | Phase |
|---|---|---|---|
| `todo-list/` | Anonymous/auth session + table CRUD via the Godot Supabase addon | `client/infrastructure/dal/` repositories + `infrastructure/supabase/auth.gd` (ADR-011 flow) | 3 |
| `slack-clone/` | Realtime channel subscribe/broadcast + auth | `SyncService` / Succession realtime feeds (TDD §5.7, §8.4) | 3 / later |

**Never** copy example secrets/config; we ship only the anon key (TDD §9.2).
