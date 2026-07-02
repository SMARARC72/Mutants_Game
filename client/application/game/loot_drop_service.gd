class_name LootDropService
extends RefCounted
## LootDropService (Wave 17 · C16) — battle SPOILS: occasional gear drops + drachma, granted when
## a battle result is applied to the run. APPLICATION/game layer policy (like XP_PER_DEFEAT):
## no domain math is invented — the drop TABLE is the GearCatalog, the ROLL is a disjoint
## CanonicalRNG sub-stream, exactly the CaptureService pattern (LootEngine's chances stay the only
## chance MATH; this is a rationed reward schedule).
##
## DETERMINISM: the drop for a battle is a pure function of (run.seed, step index) — the same
## canonical keying the encounter itself used — so a replayed run yields the identical spoils.
## PURE w.r.t. the SceneTree (no Node); the catalog is injected.

## The salt for the gear-drop sub-stream (disjoint from encounter/capture/lab streams).
const DROP_SALT := 0x6EA7_D209

## Roughly one wild victory in five yields a piece of gear — rare enough to stay an event,
## common enough that the Grimoire's gear page stops being fiction.
const DROP_CHANCE := 0.22

## Only field-plausible rarities drop from wild battles; Mythic/Relic-tier gear stays behind
## bosses/factions (docs/Mutants_Game_Loot_Gear.md rarity ladder).
const DROP_RARITIES: Array = ["Fine", "Rare"]

## Drachma spoils per defeated enemy on a WIN (docs/Mutants_Game_Economy.md: battles are a drachma
## source; mortal coin funds the Trader). Application-layer constant — no UI math.
const DRACHMA_PER_DEFEAT := 7


## Roll the gear drop for the battle that ended at `step` of the run seeded `seed`. Returns the
## dropped gear id, or "" (no drop). Deterministic: same (seed, step, catalog) => same answer.
static func roll_drop(seed: int, step: int, gear_catalog: GearCatalog) -> String:
	if gear_catalog == null:
		return ""
	var pool := droppable_ids(gear_catalog)
	if pool.is_empty():
		return ""
	var rng := CanonicalRNG.new(seed).substream(DROP_SALT ^ step)
	if rng.random() >= DROP_CHANCE:
		return ""
	return str(rng.choice(pool))


## The gear ids eligible to drop, in catalog order (stable for the canonical choice draw).
static func droppable_ids(gear_catalog: GearCatalog) -> Array:
	var out: Array = []
	for row in gear_catalog.all():
		if DROP_RARITIES.has(str((row as Dictionary).get("rarity", ""))):
			out.append(str((row as Dictionary).get("id", "")))
	return out


## The drachma spoils for a battle result dict (0 unless the player WON and downed something —
## a flee or a stalemate walk-away pays no coin).
static func drachma_for(result: Dictionary) -> int:
	if not bool(result.get("player_won", false)):
		return 0
	return DRACHMA_PER_DEFEAT * maxi(0, int(result.get("enemy_defeated", 0)))
