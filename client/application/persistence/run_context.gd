class_name RunContext
extends RefCounted
## The RUN AGGREGATE DTO (ADR-005, TDD §10.4). The single authoritative in-memory unit
## of save: the `runs` row + its embedded children (`creature_instances`, inventory,
## world/factions/flags + the narrative slice). It is **data only** — it holds NO gameplay
## math; the oracle (`client/domain/`) computes every number. This object just carries
## state to and from the versioned-JSON save (ADR-012) and the DAL.
##
## Column mirror (so the cloud Postgres aggregate and the local snapshot stay 1:1):
##   runs:               id, player_id, seed, save_version, schema_version, act, rank,
##                       order_chaos, purity_corrupt, notoriety, deeds, corruption,
##                       drachma, essence, ichor, gear, god_form, status
##   creature_instances: each party entry mirrors a row incl. `lineage` jsonb
##   inventory / world_state / faction_standing -> inventory[], world_state{}, flags{}
##
## Restored IN PLACE (`load_from`) like NarrativeRunState so any cached reference to this
## aggregate (Game owns exactly one) sees the restored state after a reload.

## NOTE (ADR-014): `corruption` is the cumulative PLAYER track, fed UNCLAMPED by the
## engines (no 130 ceiling here — that cap is the per-combatant battle-live meter, which
## is never persisted). We only carry the value; we never clamp or compute it.

# --- runs row ---------------------------------------------------------------- #
var run_id: String = ""
var player_id: String = ""
## bigint seed in Postgres; carried as int (GDScript int is 64-bit).
var seed: int = 0
## save_version is the SOLE sync conflict key (ADR-005, TDD §10.3). The DAL bumps it.
var save_version: int = 1
var schema_version: int = 1
var act: int = 0
var rank: String = "Mortal"
var order_chaos: int = 0
var purity_corrupt: int = 0
var notoriety: int = 0
var deeds: int = 0
var corruption: int = 0
var drachma: int = 0
var essence: int = 0
var ichor: int = 0
## {slot: gear_id} — mirrors runs.gear jsonb.
var gear: Dictionary = {}
var god_form: String = ""
var status: String = "active"

# --- embedded children ------------------------------------------------------- #
## Array of creature-instance dicts. Each mirrors a `creature_instances` row, incl.
## `lineage` (ancestry / fused-from / sacrificed-for). Data only; no Creature objects.
var party: Array = []
## Per-run parts/kits/vials/consumables (mirrors `inventory` rows).
var inventory: Array = []
## Reactive world (mirrors world_state.region_states + force_tide).
var world_state: Dictionary = {}
## Region ids the player may enter (mirror of narrative unlocks; convenience set).
var unlocked_regions: Dictionary = {}
## Free-form world/run flags the services set/read.
var flags: Dictionary = {}
## The narrative slice (QuestService.serialize() payload). Embedded so a full save
## carries the narrative + ink sections without a second file (brief D1/D2).
var narrative: Dictionary = {}

# --- serialization (data-only; ADR-012) -------------------------------------- #


## A plain JSON-stringifiable dictionary mirroring the `runs` aggregate. Deep-copies
## nested containers so the caller cannot mutate our state through the returned dict.
func to_dict() -> Dictionary:
	return {
		"run_id": run_id,
		"player_id": player_id,
		"seed": seed,
		"save_version": save_version,
		"schema_version": schema_version,
		"act": act,
		"rank": rank,
		"order_chaos": order_chaos,
		"purity_corrupt": purity_corrupt,
		"notoriety": notoriety,
		"deeds": deeds,
		"corruption": corruption,
		"drachma": drachma,
		"essence": essence,
		"ichor": ichor,
		"gear": gear.duplicate(true),
		"god_form": god_form,
		"status": status,
		"party": party.duplicate(true),
		"inventory": inventory.duplicate(true),
		"world_state": world_state.duplicate(true),
		"unlocked_regions": unlocked_regions.duplicate(true),
		"flags": flags.duplicate(true),
		"narrative": narrative.duplicate(true),
	}


## Overwrites THIS object's fields from a save dict, IN PLACE (preserves object
## identity for the single Game-owned aggregate; mirrors NarrativeRunState.load_from).
func load_from(data: Dictionary) -> void:
	run_id = str(data.get("run_id", ""))
	player_id = str(data.get("player_id", ""))
	seed = int(data.get("seed", 0))
	save_version = int(data.get("save_version", 1))
	schema_version = int(data.get("schema_version", 1))
	act = int(data.get("act", 0))
	rank = str(data.get("rank", "Mortal"))
	order_chaos = int(data.get("order_chaos", 0))
	purity_corrupt = int(data.get("purity_corrupt", 0))
	notoriety = int(data.get("notoriety", 0))
	deeds = int(data.get("deeds", 0))
	corruption = int(data.get("corruption", 0))
	drachma = int(data.get("drachma", 0))
	essence = int(data.get("essence", 0))
	ichor = int(data.get("ichor", 0))
	gear = _as_dict(data.get("gear", {}))
	god_form = str(data.get("god_form", ""))
	status = str(data.get("status", "active"))
	party = _as_array(data.get("party", []))
	inventory = _as_array(data.get("inventory", []))
	world_state = _as_dict(data.get("world_state", {}))
	unlocked_regions = _as_dict(data.get("unlocked_regions", {}))
	flags = _as_dict(data.get("flags", {}))
	narrative = _as_dict(data.get("narrative", {}))


static func from_dict(data: Dictionary) -> RunContext:
	var ctx := RunContext.new()
	ctx.load_from(data)
	return ctx


# --- convenience accessors (read-only sugar; no math) ------------------------ #


func party_size() -> int:
	return party.size()


## Count of living party members (mirrors the `is_dead = false` hot-party index).
func living_party_size() -> int:
	var alive := 0
	for member in party:
		if member is Dictionary and not bool((member as Dictionary).get("is_dead", false)):
			alive += 1
	return alive


static func _as_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


static func _as_array(value: Variant) -> Array:
	if value is Array:
		return (value as Array).duplicate(true)
	return []
