class_name NarrativeRunState
extends RefCounted
## The slice of RUN STATE that narrative reads to TRIGGER + GATE, and writes to
## via QuestService (ADR-017). It is **data only** — corruption, unlocks,
## captures, owned creatures, region access, faction standing. It holds NO
## gameplay math: stats, damage and splice outcomes are the oracle's job
## (`client/domain/`), never narrative's. Narrative only ever flips these flags
## and reads them back; the deterministic engines decide everything else.
##
## Lives in `application/` (orchestration), references no addon and no `domain/`.
## Serializes to the versioned-JSON save as a plain dictionary (ADR-012); never
## stored as a Godot Resource/.tres.

## Occult corruption meter (uncapped, ADR-014). Narrative reads it to gate lore
## branches; the world sim writes the real number — we only nudge via quests.
var corruption: int = 0

## Region ids the player may enter (e.g. "rust_marsh"). Quests unlock these.
var unlocked_regions: Dictionary = {}

## Creature species/instance ids the player owns ("owns(id)" in Ink).
var owned_creatures: Dictionary = {}

## Creature ids the player has captured at least once (capture history).
var captured_creatures: Dictionary = {}

## Faction id -> standing (an opaque integer the world sim owns; we only read it
## for narrative gates and nudge it by whole steps through quest effects).
var faction_standing: Dictionary = {}

## Free-form world flags the quests set/read (e.g. "lab_op_unlocked:necropsy").
var flags: Dictionary = {}


func has_creature(creature_id: String) -> bool:
	return owned_creatures.get(creature_id, false) == true


func owns(creature_id: String) -> bool:
	return has_creature(creature_id)


func has_captured(creature_id: String) -> bool:
	return captured_creatures.get(creature_id, false) == true


func region_unlocked(region_id: String) -> bool:
	return unlocked_regions.get(region_id, false) == true


func standing_with(faction_id: String) -> int:
	return int(faction_standing.get(faction_id, 0))


func flag(key: String) -> bool:
	return flags.get(key, false) == true


# --- mutators: only ever flip narrative-relevant flags, never compute math --- #


func grant_creature(creature_id: String) -> void:
	owned_creatures[creature_id] = true
	captured_creatures[creature_id] = true


func mark_captured(creature_id: String) -> void:
	captured_creatures[creature_id] = true


func unlock_region(region_id: String) -> void:
	unlocked_regions[region_id] = true


func set_flag(key: String, value: bool = true) -> void:
	flags[key] = value


func add_corruption(delta: int) -> void:
	corruption += delta


func nudge_standing(faction_id: String, delta: int) -> void:
	faction_standing[faction_id] = standing_with(faction_id) + delta


# --- serialization (data-only; ADR-012) --- #


func to_dict() -> Dictionary:
	return {
		"corruption": corruption,
		"unlocked_regions": unlocked_regions.duplicate(true),
		"owned_creatures": owned_creatures.duplicate(true),
		"captured_creatures": captured_creatures.duplicate(true),
		"faction_standing": faction_standing.duplicate(true),
		"flags": flags.duplicate(true),
	}


static func from_dict(data: Dictionary) -> NarrativeRunState:
	var state := NarrativeRunState.new()
	state.corruption = int(data.get("corruption", 0))
	state.unlocked_regions = _as_dict(data.get("unlocked_regions", {}))
	state.owned_creatures = _as_dict(data.get("owned_creatures", {}))
	state.captured_creatures = _as_dict(data.get("captured_creatures", {}))
	state.faction_standing = _as_dict(data.get("faction_standing", {}))
	state.flags = _as_dict(data.get("flags", {}))
	return state


static func _as_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}
