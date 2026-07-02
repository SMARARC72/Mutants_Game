class_name RegionTravel
extends RefCounted
## RegionTravel (E1b "Eleven Regions") — the THRESHOLD NETWORK rules (design §3.5: ritual-circle
## fast travel) + the per-region EXPLORED ledger. APPLICATION/overworld layer, pure functions over
## a RunContext: it decides which regions a run may enter (the world catalog's story gate flag OR
## a direct quest unlock), moves the run's active region, and counts the steps walked IN each
## region (so a region climax reads exploration THERE, never the global step count as instant
## boss-bait after a hop). No RNG, no I/O — everything persists in run.world_state /
## run.unlocked_regions, so a save round-trips the whole network state.

const RegionCatalogScript := preload("res://application/overworld/region_catalog.gd")

## world_state key: {region_id: steps walked while that region was active} (int ledger).
const LEDGER_KEY := "region_steps"
## world_state key the run's position on the network rides (GameController.active_region reads it).
const ACTIVE_KEY := "active_region"
## world_state key of the global step counter (legacy backfill source, see explored_steps).
const STEPS_KEY := "steps"


## True when `run` may stand in `region_id`: the region exists AND (it never seals — verdant +
## threshold — OR a quest unlocked it directly via run.unlocked_regions OR its authored story
## gate flag has landed in run.flags — the E1a act gates).
static func unlocked(run: RunContext, region_id: String) -> bool:
	if run == null or not RegionCatalogScript.has_region(region_id):
		return false
	if RegionCatalogScript.always_open(region_id):
		return true
	if bool(run.unlocked_regions.get(region_id, false)):
		return true
	return bool(run.flags.get(RegionCatalogScript.gate_flag(region_id), false))


## Directly unlock one region (the quest-reward path — e.g. a faction opens you a door early, no
## act gate involved). Returns false without a run or for a region the world doesn't carry.
static func unlock(run: RunContext, region_id: String) -> bool:
	if run == null or not RegionCatalogScript.has_region(region_id):
		return false
	run.unlocked_regions[region_id] = true
	return true


## Ride the circle: move the run's active region to `region_id`. Refused (false, run untouched)
## when the region is locked/unknown or the run already stands there. On acceptance the door is
## also recorded in run.unlocked_regions — a threshold once crossed stays crossed, whatever later
## happens to the story flag that opened it.
static func travel(run: RunContext, region_id: String) -> bool:
	if not unlocked(run, region_id):
		return false
	if str(run.world_state.get(ACTIVE_KEY, "")) == region_id:
		return false
	# Codex #59 P2: seed the legacy ledger BEFORE switching — a pre-E1b save's global step
	# count belongs to the region the run has been standing in (the only one it ever walked),
	# never to the travel destination (which would inherit instant boss-climax progress).
	if not (run.world_state.get(LEDGER_KEY, null) is Dictionary):
		var origin := str(run.world_state.get(ACTIVE_KEY, "verdant_glut"))
		run.world_state[LEDGER_KEY] = {origin: int(run.world_state.get(STEPS_KEY, 0))}
	run.world_state[ACTIVE_KEY] = region_id
	run.unlocked_regions[region_id] = true
	return true


## Count one walked step against `region_id`'s explored ledger. Called by GameController
## .advance_step BEFORE the global counter increments: a pre-E1b save carries no ledger, so the
## first tick backfills the whole legacy count onto the region the run stands in (the only region
## a pre-travel save ever walked) — a resumed verdant run keeps its boss-climax progress exactly.
static func tick_explored(run: RunContext, region_id: String) -> void:
	if run == null or region_id == "":
		return
	if not (run.world_state.get(LEDGER_KEY, null) is Dictionary):
		run.world_state[LEDGER_KEY] = {region_id: int(run.world_state.get(STEPS_KEY, 0))}
	var ledger: Dictionary = run.world_state[LEDGER_KEY]
	ledger[region_id] = int(ledger.get(region_id, 0)) + 1


## The steps walked while `region_id` was the active region. A fresh arrival reads 0 (the climax
## cannot fire off the global count); a pre-ledger save reads the global count for its active
## region (legacy equivalence) and 0 anywhere else. Pure read — never creates the ledger.
static func explored_steps(run: RunContext, region_id: String) -> int:
	if run == null:
		return 0
	var ledger: Variant = run.world_state.get(LEDGER_KEY, null)
	if ledger is Dictionary:
		return int((ledger as Dictionary).get(region_id, 0))
	if str(run.world_state.get(ACTIVE_KEY, "")) == region_id:
		return int(run.world_state.get(STEPS_KEY, 0))
	return 0
