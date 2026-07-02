class_name ToastMicrocopy
extends RefCounted
## Funny-grim toast microcopy for the core events (D7 / design §1 tonal contract).
##
## PRESENTATION layer. Wave 16a: the BODY copy now routes through VoiceBook — the authored
## voice_library banks, ingested verbatim (binding tension 11) — so call sites keep firing
## `event(id)` while the words come from the writers' room. Each event keeps its Wave-1
## authored body as the FALLBACK for a missing key (the book never 404s a toast), plus a
## default icon (colorblind-safe colour+shape) and a sound cue the `Toast` facade resolves.
## `salt` walks the authored variants deterministically (LOCAL hash in VoiceBook.pick —
## never the canonical PCG32 streams): same salt, same line; new salt, fresh line.

const VoiceBookScript := preload("res://presentation/narrative/voice_book.gd")

# Event ids the game fires.
const CAUGHT := "creature_caught"
const HARVEST := "part_harvested"
const AWAKEN := "awakening"
const QUEST := "quest_update"
const RIVAL := "rival_approaches"
const CORRUPTION := "corruption_rising"

# event id -> the VoiceBook key its body draws from (see client/catalog/VOICE_KEYS.md).
const VOICE_KEYS := {
	CAUGHT: "toast.caught",
	HARVEST: "toast.harvest",
	AWAKEN: "toast.awakening",
	QUEST: "toast.quest",
	RIVAL: "toast.rival",
	CORRUPTION: "toast.corruption",
}


## event id -> {title, body, icon, sound}. `icon` is a res:// path or "" (facade falls back to
## a force/status glyph); `sound` is a logical cue the facade maps to an audio stream.
## `salt` selects the VoiceBook variant (0 = the stable default line for that event).
static func preset(event_id: String, salt: int = 0) -> Dictionary:
	var entry := _base(event_id)
	# pick_plain: toasts never interpolate, so {placeholder} variants must not surface raw.
	var voice := VoiceBookScript.pick_plain(str(VOICE_KEYS.get(event_id, "")), salt)
	if voice != "":
		entry["body"] = voice
	return entry


## The authored per-event scaffolding: title/icon/sound + the FALLBACK body used when the
## VoiceBook key is missing (never shown while client/catalog/voice.json is intact).
static func _base(event_id: String) -> Dictionary:
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
