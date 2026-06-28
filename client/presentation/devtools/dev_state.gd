class_name DevState
extends RefCounted
## Dev state shim for the LimboConsole state-poke commands (D3). DEV-ONLY.
##
## PRESENTATION/devtools layer. Holds the values poked from the dev console until the real
## run/game-state services land (Phase 1-2/3). Each setter records the poke and emits so a dev
## HUD can observe; today it logs. This is a DEV convenience only — it NEVER feeds gameplay
## outcomes or determinism (the oracle owns those), so it can live outside `domain/` freely.
##
## When the run-state services exist, swap these bodies to call them; the command signatures
## (and thus the console UX) stay identical.

signal poked(key: String, value: Variant)

var seed: int = 0
var corruption: int = 0
var morality_occult: int = 0
var morality_profane: int = 0
var party: Array[String] = []
var gear: Dictionary = {}  # slot -> id
var unlocked_regions: Array[String] = []


func set_seed(value: int) -> void:
	seed = value
	_poke("seed", value)


func set_corruption(value: int) -> void:
	corruption = value
	_poke("corruption", value)


func set_morality(occult: int, profane: int) -> void:
	morality_occult = occult
	morality_profane = profane
	_poke("morality", {"occult": occult, "profane": profane})


func give_creature(id: String) -> void:
	party.append(id)
	_poke("give_creature", id)


func grant_gear(slot: String, id: String) -> void:
	gear[slot] = id
	_poke("grant_gear", {"slot": slot, "id": id})


func unlock_region(id: String) -> void:
	if not unlocked_regions.has(id):
		unlocked_regions.append(id)
	_poke("unlock_region", id)


func _poke(key: String, value: Variant) -> void:
	poked.emit(key, value)
	print("[DEV_TOOLS poke] %s = %s" % [key, str(value)])
