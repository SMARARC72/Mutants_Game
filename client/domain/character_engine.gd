class_name CharacterEngine
extends RefCounted
## Mutants_Game — CHARACTER LADDER (v0.1): port of oracle/character_engine.py.
## Deterministic, pure functions only (no RNG used by the golden surface):
##   rank_for(deeds), band3(v, labels), GODS lookup, clamp(v).
## DOMAIN layer: 'extends RefCounted', no Node/SceneTree/addons/wall-clock/stdlib-RNG.
## Reproduces the oracle EXACTLY so it matches the committed golden vectors.

const RANKS: Array = ["Mortal", "Adept", "Demigod", "Titan", "God", "Primordial"]

## Authored morality/deed events from oracle/character_engine.py. Keys are content contracts: quest,
## dialogue, battle, and lab application code emits one of these ids; this engine alone resolves the
## numerical movement so the nine-god grid can no longer be presentation-only.
const EVENTS: Dictionary = {
	"uphold a law": {"oc": -12, "note": 2},
	"ally a faction": {"oc": -8, "note": -5},
	"break a taboo": {"oc": 12, "note": 8},
	"incite chaos": {"oc": 10, "note": 6},
	"spare / heal": {"pc": -9},
	"refuse power": {"pc": -11},
	"self-splice": {"pc": 14, "corr": 1, "note": 10},
	"sacrifice kin": {"pc": 10, "corr": 1, "note": 7},
	"kill a god": {"deeds": 1, "note": 20},
	"kill a legend": {"deeds": 1, "note": 10},
}

const NOTORIETY_THRESHOLDS: Dictionary = {
	30: "a faction turns hostile",
	60: "a rival god-maker sends hunters",
	90: "the Pantheon itself marks you for death",
}

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


## Apply one authored event to a plain state dictionary. Pure and deterministic: callers pass the
## previously-fired notoriety thresholds and receive an updated state plus newly-triggered messages.
## Unknown event ids are rejected without mutating the supplied state.
static func apply_event(
	state: Dictionary, event_id: String, fired_thresholds: Array = []
) -> Dictionary:
	if not EVENTS.has(event_id):
		return {"ok": false, "event": event_id, "state": state.duplicate(true), "triggered": []}
	var delta: Dictionary = EVENTS[event_id]
	var next := state.duplicate(true)
	var previous_rank := rank_for(int(next.get("deeds", 0)))
	next["order_chaos"] = clamp_axis(int(next.get("order_chaos", 0)) + int(delta.get("oc", 0)))
	next["purity_corrupt"] = clamp_axis(
		int(next.get("purity_corrupt", 0)) + int(delta.get("pc", 0))
	)
	next["deeds"] = maxi(0, int(next.get("deeds", 0)) + int(delta.get("deeds", 0)))
	next["corruption"] = maxi(0, int(next.get("corruption", 0)) + int(delta.get("corr", 0)))
	next["notoriety"] = maxi(0, int(next.get("notoriety", 0)) + int(delta.get("note", 0)))
	next["rank"] = rank_for(int(next["deeds"]))
	var triggered: Array = []
	var fired := fired_thresholds.duplicate()
	for threshold in [30, 60, 90]:
		if int(next["notoriety"]) >= threshold and not fired.has(threshold):
			fired.append(threshold)
			triggered.append(
				{"threshold": threshold, "message": str(NOTORIETY_THRESHOLDS[threshold])}
			)
	return {
		"ok": true,
		"event": event_id,
		"state": next,
		"triggered": triggered,
		"fired_thresholds": fired,
		"rank_up": str(next["rank"]) if str(next["rank"]) != previous_rank else "",
	}
