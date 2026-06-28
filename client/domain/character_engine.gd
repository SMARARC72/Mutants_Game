class_name CharacterEngine
extends RefCounted
## Mutants_Game — CHARACTER LADDER (v0.1): port of oracle/character_engine.py.
## Deterministic, pure functions only (no RNG used by the golden surface):
##   rank_for(deeds), band3(v, labels), GODS lookup, clamp(v).
## DOMAIN layer: 'extends RefCounted', no Node/SceneTree/addons/wall-clock/stdlib-RNG.
## Reproduces the oracle EXACTLY so it matches the committed golden vectors.

const RANKS: Array = ["Mortal", "Adept", "Demigod", "Titan", "God", "Primordial"]

## GODS: keyed by "<oc_label>|<pc_label>" (e.g. "Order|Pure"). Python used a tuple key;
## GDScript dicts can't key on Array reliably for this surface, so we join with "|".
const GODS: Dictionary = {
	"Order|Pure": "The Lawgiver  (Law / Heaven)",
	"Order|Tainted": "The Architect (Order, compromised)",
	"Order|Corrupt": "The Iron Throne (Dominion / Machine)",
	"Balanced|Pure": "The Warden  (Steward)",
	"Balanced|Tainted": "The Broker  (Gray god)",
	"Balanced|Corrupt": "The Plaguelord",
	"Chaos|Pure": "The Free Wild (Liberty / Nature)",
	"Chaos|Tainted": "The Reveler  (Dionysian)",
	"Chaos|Corrupt": "The Devourer (the Abyss)",
}


## Python: max(-100, min(100, v))
static func clamp_axis(v: int) -> int:
	return maxi(-100, mini(100, v))


## Python: labels[0] if v <= -34 else (labels[2] if v >= 34 else labels[1])
static func band3(v: int, labels: Array) -> String:
	if v <= -34:
		return labels[0]
	elif v >= 34:
		return labels[2]
	else:
		return labels[1]


## Python: thr=[0,1,3,5,7,9]; r=RANKS[0]; for i,t: if deeds>=t: r=RANKS[i]; return r
static func rank_for(deeds: int) -> String:
	var thr: Array = [0, 1, 3, 5, 7, 9]  # God at 7 deeds, Primordial at 9
	var r: String = RANKS[0]
	for i in thr.size():
		var t: int = thr[i]
		if deeds >= t:
			r = RANKS[i]
	return r


## GODS[(al, pl)] lookup. grid is [oc_label, pc_label].
static func gods(grid: Array) -> String:
	return GODS[str(grid[0]) + "|" + str(grid[1])]
