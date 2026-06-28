class_name ToastMicrocopy
extends RefCounted
## Funny-grim toast microcopy for the core events (D7 / design §1 tonal contract).
##
## PRESENTATION layer. The dry, in-world voice the design demands — gallows humour that makes
## the dark land harder (design §1: "if a moment makes you laugh and then slightly regret
## laughing, it's on-tone"). One place owns the copy so the voice stays consistent. Each event
## carries a default icon (from `client/assets/icons/**`, colorblind-safe colour+shape) and a
## sound bus cue name the `Toast` facade resolves.

# Event ids the game fires.
const CAUGHT := "creature_caught"
const HARVEST := "part_harvested"
const AWAKEN := "awakening"
const QUEST := "quest_update"
const RIVAL := "rival_approaches"
const CORRUPTION := "corruption_rising"


## event id -> {title, body, icon, sound}. `icon` is a res:// path or "" (facade falls back to
## a force/status glyph); `sound` is a logical cue the facade maps to an audio stream.
static func preset(event_id: String) -> Dictionary:
	match event_id:
		CAUGHT:
			return {
				"title": "Acquired.",
				"body":
				"It is yours now. It does not appear to consent, but the paperwork is in order.",
				"icon": "res://assets/icons/verbs/summon.svg",
				"sound": "chime",
			}
		HARVEST:
			return {
				"title": "Part harvested.",
				"body":
				"One useful organ, ethically sourced (by your standards). The rest, regrettably, was the creature.",
				"icon": "res://assets/icons/verbs/drain.svg",
				"sound": "wet",
			}
		AWAKEN:
			return {
				"title": "It awakens.",
				"body":
				"Something old looks back through new eyes. You should feel proud. You feel watched.",
				"icon": "res://assets/icons/forces/cosmos.svg",
				"sound": "swell",
			}
		QUEST:
			return {
				"title": "The ledger updates.",
				"body":
				"An obligation has shifted. The universe keeps receipts, and now, so do you.",
				"icon": "res://assets/icons/verbs/gambit.svg",
				"sound": "ink",
			}
		RIVAL:
			return {
				"title": "A rival approaches.",
				"body":
				"They have ambitions, a better haircut, and a creature they think can beat yours. Two of those are correct.",
				"icon": "res://assets/icons/verbs/strike.svg",
				"sound": "toll",
			}
		CORRUPTION:
			return {
				"title": "Corruption rises.",
				"body":
				"The rot finds you agreeable. The townsfolk find you less so. You find this... fine, actually.",
				"icon": "res://assets/icons/statuses/madness.svg",
				"sound": "hum",
			}
		_:
			return {"title": "", "body": event_id, "icon": "", "sound": "chime"}
