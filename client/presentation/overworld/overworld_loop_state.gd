class_name OverworldLoopState
extends RefCounted
## Wave 3 "Loop Truth" — the run.world_state bookkeeping the overworld leans on between battles:
##   * PRE-BATTLE POSITION: the exact cell + facing where a fight started, stashed alongside the
##     pending_battle autosave so the post-battle overworld restores the player to the same tile;
##   * POST-BATTLE GRACE: a small step counter armed before every hand-off — the first few steps
##     after a fight never roll a wild encounter (explicitly interim, master-plan tension 8);
##   * ONE-SHOT BOSS LAIR: the flag that records the region climax has already ambushed once, so a
##     lost/fled boss fight never re-ambushes on every subsequent step.
## Pure data helpers over RunContext.world_state (JSON-safe values only — ints in arrays, bools),
## no Node, extracted OverworldCameraRig-style so overworld_screen.gd stays under the file cap.

const OverworldTileSetScript := preload("res://presentation/overworld/overworld_tileset.gd")

const PLAYER_CELL_KEY := "player_cell"
const PLAYER_FACING_KEY := "player_facing"
const GRACE_KEY := "encounter_grace"
const BOSS_FIRED_PREFIX := "boss_lair_fired_"


## Stash the pre-battle position (cell + facing, JSON-safe int pairs) and arm the post-battle
## encounter grace window. Called just before the pending_battle autosave so one save carries all.
static func stash_prebattle(
	run: RunContext, cell: Vector2i, facing: Vector2i, grace_steps: int
) -> void:
	if run == null:
		return
	run.world_state[PLAYER_CELL_KEY] = [cell.x, cell.y]
	run.world_state[PLAYER_FACING_KEY] = [facing.x, facing.y]
	run.world_state[GRACE_KEY] = grace_steps


## The persisted pre-battle cell when present + in-bounds + walkable on `layout`, else `fallback`
## (the canonical spawn). JSON round-trips numbers as floats — int()-coerced here.
static func restore_cell(run: RunContext, layout: Layout, fallback: Vector2i) -> Vector2i:
	var saved := _int_pair(run, PLAYER_CELL_KEY)
	if saved.is_empty() or layout == null:
		return fallback
	var cell := Vector2i(int(saved[0]), int(saved[1]))
	if not layout.in_bounds(cell.x, cell.y):
		return fallback
	if not OverworldTileSetScript.is_walkable(layout.get_cell(cell.x, cell.y)):
		return fallback
	return cell


## The persisted pre-battle facing (a non-zero int pair), else `fallback`.
static func restore_facing(run: RunContext, fallback: Vector2i) -> Vector2i:
	var saved := _int_pair(run, PLAYER_FACING_KEY)
	if saved.is_empty():
		return fallback
	var facing := Vector2i(int(saved[0]), int(saved[1]))
	return facing if facing != Vector2i.ZERO else fallback


## E1b travel: drop the stashed pre-battle cell/facing + the grace window. A Threshold-network
## hop lands at the NEW region's canonical spawn — a stale cross-region cell (often walkable in
## the next layout too) must never place the tamer there.
static func clear_position_stash(run: RunContext) -> void:
	if run == null:
		return
	run.world_state.erase(PLAYER_CELL_KEY)
	run.world_state.erase(PLAYER_FACING_KEY)
	run.world_state.erase(GRACE_KEY)


## Consume one step of the post-battle grace window. Returns true while the step is graced (the
## caller skips the wild roll); the counter decrements toward 0 and persists in world_state.
static func consume_grace(run: RunContext) -> bool:
	if run == null:
		return false
	var grace := int(run.world_state.get(GRACE_KEY, 0))
	if grace <= 0:
		return false
	run.world_state[GRACE_KEY] = grace - 1
	return true


## True once the region's boss lair has ambushed (the one-shot trigger already fired this run).
static func boss_fired(run: RunContext, region_id: String) -> bool:
	if run == null:
		return false
	return bool(run.world_state.get(BOSS_FIRED_PREFIX + region_id, false))


## Record the one-shot boss ambush for `region_id` (persisted by the pre-battle autosave).
static func mark_boss_fired(run: RunContext, region_id: String) -> void:
	if run == null:
		return
	run.world_state[BOSS_FIRED_PREFIX + region_id] = true


## E1c: the extra keys the BOSS hand-off folds into pending_battle — tagged is_boss with the
## role brain, plus the pantheon boss_id + the VERBATIM authored intro/defeat lines
## (boss_kits.json) the battle screen splashes/toasts. Pure data pass-through: the verdant
## slice boss carries "" for all three and keeps its shipped presentation.
static func boss_handoff_extra(roll: Dictionary) -> Dictionary:
	return {
		"is_wild": false,
		"is_boss": true,
		"boss_brain": str(roll.get("boss_brain", "controller")),
		"boss_id": str(roll.get("boss_id", "")),
		"intro_line": str(roll.get("intro_line", "")),
		"defeat_line": str(roll.get("defeat_line", "")),
	}


## A world_state value as a 2-element numeric Array, or [] when absent/malformed.
static func _int_pair(run: RunContext, key: String) -> Array:
	if run == null:
		return []
	var value: Variant = run.world_state.get(key, null)
	if value is Array and (value as Array).size() == 2:
		return value
	return []
