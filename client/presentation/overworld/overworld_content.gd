class_name OverworldContent
extends RefCounted
## Authored overworld CONTENT data — the starter region's NPCs + quests — separated from the screen
## LOGIC so adding content (a quest def + NPC entries, the proven SQ side-quest pattern) is pure data
## and never bloats overworld_screen.gd. The screen + QuestService consume these constants.
##
## Each NPC plays its authored Dialogic timeline (registered in project.godot dtl_directory) on INTERACT
## when the tamer stands beside it. A quest names the NPC_DEFS key (its `step_key`) whose value is the
## step that NPC drives, so the overworld's dispatch loops quests generically (no per-quest code). Ring
## colours are drawn from the six-force palette so each token reads as a distinct occult game-piece.

const NPC_DEFS := [
	{
		"name": "Old Marrow",
		"timeline": "marsh_oracle",
		"ring": Color(0.667, 0.376, 0.69),  # Thanatos violet — the bog oracle
		"quest_step": "hear_marrow",
	},
	{
		"name": "Bog-Wretch",
		"timeline": "marsh_encounter",
		"ring": Color(0.435, 0.722, 0.839),  # Ouranos silver-blue — the penny-coloured wretch
		"quest_step": "meet_wretch",
		"species": "S2-07",  # W-DRESS: a creature-NPC — the Frilltoad cutout walks the map
	},
	{
		"name": "Matron Sevvy",
		"timeline": "bloom_matron",
		"ring": Color("e0658c"),  # Eros rose — the Bloomwarden Greenmother
	},
	{
		"name": "Pollen-Factor Dree",
		"timeline": "pollen_factor",
		"ring": Color("d6248c"),  # Chaos magenta — the absurdist cursed-goods merchant
		"melon_step": "covet_melon",
	},
	{
		"name": "The Melon",
		"timeline": "the_melon",
		"ring": Color("e8d8a0"),  # Cosmos gold — the patient melon that waits
		"melon_step": "wait_with_melon",
		"species": "SB09",  # W-DRESS: the patient melon IS the round Sprite-blob cutout
	},
	{
		"name": "Rust Warden",
		"timeline": "rust_warden",
		"ring": Color("e0b95a"),  # lit brass — the Bloomwarden lore/mentor
	},
	{
		"name": "Hearthward Ona",
		"timeline": "hearthward_ona",
		"ring": GrimoirePalette.VERDANT,  # living green — the husbandry tutor (SQ-05 giver)
		"bramble_step": "tend_with_ona",
	},
	{
		"name": "Old Garran",
		"timeline": "old_garran",
		"ring": Color("b14b3a"),  # Chaos rust — the kindly-voiced shortcut, the Revel in disguise
		# W16a: Garran's step is CHOICE-driven — the .dtl asks refuse/accept and the branch
		# (via DialogicFacade.choice_made) advances SQ-05, not the mere act of talking.
		# Both branches complete the quest; they differ in flags, corruption, and toast voice.
		# headless_branch names the canon branch tests/CI resolve instantly (no UI headless).
		"choice":
		{
			"quest": "six_petals_true_bred",
			"step": "answer_garran",
			"headless_branch": "refuse",
			"branches":
			{
				"refuse":
				{
					"effect": {"set_flag": "refused_the_shortcut"},
					"voice_key": "quest.refused_garran",
				},
				"accept":
				{
					"effect": {"set_flag": "took_the_shortcut", "add_corruption": 1},
					"voice_key": "quest.accepted_garran",
				},
			},
		},
	},
	{
		"name": "Sister Wenlow",
		"timeline": "sister_wenlow",
		# hospice grey-green — the Bloomwarden hospice-keeper (SQ-06 giver)
		"ring": GrimoirePalette.VERDANT_ASH,
		"wenlow_step": "hear_wenlow",
	},
	{
		"name": "The Greenwatcher",
		"timeline": "the_greenwatcher",
		# deep shaded green — the gentle apex that plants the living
		"ring": GrimoirePalette.VERDANT_DIM,
		"wenlow_step": "pacify_greenwatcher",
		"species": "S2-38",  # W-DRESS: the gentle apex walks as the Greenmaw cutout
	},
	# --- W16b (correction C14): the Act-0 cast, wired via the proven SQ-06 data pattern. The
	# Threshold spine rides the single shipped region until region travel lands — the quests
	# themselves are pure data and move with their NPCs. Dialogue is VERBATIM scripts_mvp.md
	# Scenes 1-4 / story_quests.md Act 0.
	{
		"name": "Old Maddox",
		"timeline": "maddox_mercy",
		"ring": GrimoirePalette.BRASS,  # the mentor's brass — one rule, free
		"knack_step": "hear_maddox",
	},
	{
		"name": "Mother Kestrel",
		"timeline": "mother_kestrel",
		"ring": GrimoirePalette.PARCHMENT_DIM,  # the municipal menagerie's worn ledger-paper
		# Act-0 first-catch fork (scripts_mvp Scene 1B): the pens ask HOW you catch, and the
		# ANSWER — not the visit — advances The Knack. All three branches complete the step
		# (the quest completes either way); they differ in flags, corruption, and the authored
		# catch toast. Canon/headless branch: the gentle path (Threshold is kind on purpose).
		"choice":
		{
			"quest": "act0_the_knack",
			"step": "meet_kestrel",
			"headless_branch": "offer_hand",
			"branches":
			{
				"offer_hand":
				{
					"effect": {"set_flag": "first_catch_clean"},
					"voice_key": "capture.befriend.success",
				},
				"bind_fast":
				{
					"effect": {"set_flag": "first_catch_harsh", "add_corruption": 1},
					"voice_key": "capture.trap.success",
				},
				"let_them_fight":
				{
					"effect": {"set_flag": "first_catch_wild"},
					"voice_key": "capture.trap.success",
				},
			},
		},
	},
	{
		"name": "Surgeon-Lab-Tech Veil",
		"timeline": "veil_bench",
		"ring": GrimoirePalette.THANATOS,  # the bench that took prayers; now specimens
		"altar_step": "rent_the_bench",
	},
	{
		"name": "Vael Construct-Nine",
		"timeline": "vael_mark",
		"ring": GrimoirePalette.COSMOS,  # a clipboard with no visible soul
		# The Act-0 defining tick is a REAL Dialogic choice (scripts_mvp Scene 3B): the brand
		# can be borne three ways. All three advance the same step (the quest completes either
		# way); the branches differ in flags — and feeding the mark is the one Act-0 choice
		# that costs corruption. Canon/headless branch: seal (the cautious file).
		"choice":
		{
			"quest": "act0_the_mark",
			"step": "answer_the_mark",
			"headless_branch": "seal",
			"branches":
			{
				"seal": {"effect": {"set_flag": "mark_sealed"}, "voice_key": ""},
				"feed":
				{
					"effect": {"set_flag": "mark_fed", "add_corruption": 2},
					"voice_key": "toast.corruption",
				},
				"bargain": {"effect": {"set_flag": "mark_appraised"}, "voice_key": ""},
			},
		},
	},
	{
		"name": "Madam Thessaly Vance",
		"timeline": "thessaly_rolls",
		"ring": GrimoirePalette.WARNING,  # velvet, ledgers, a smile like a closing door
		"rolls_step": "enter_the_rolls",
	},
	# W16b fourth-wall crack #1: a readable SIGN prop on a deterministic cast cell — it uses
	# the run's actual save name, once per run (FourthWall.seen_cracks registry; tension 11).
	{
		"name": "Weathered Signpost",
		"timeline": "",
		"ring": GrimoirePalette.TEXT_MUTED,  # hand-painted, long past repainting
		"sign": true,
	},
]

## The intro quest, driven by talking to the two marsh NPCs (start on the first, complete on the
## second). Data-only; QuestService applies the effects to its NarrativeRunState + emits signals.
const MARSH_QUEST := {
	"id": "marsh_welcome",
	"name": "A Thin Welcome",
	"description": "The marsh has opinions about you. Hear them out.",
	"step_key": "quest_step",  # the NPC_DEFS key whose value names this quest's step
	"steps":
	[
		{
			"id": "hear_marrow",
			"description": "Heed Old Marrow.",
			"on_complete": {"set_flag": "met_marrow"}
		},
		{
			"id": "meet_wretch",
			"description": "Meet the Bog-Wretch.",
			"on_complete": {"set_flag": "met_wretch"}
		},
	],
	"on_complete": {"set_flag": "marsh_welcomed", "add_corruption": 1},
}

## SQ-04 "The Melon That Waits" — an authored absurdist non-combat side quest. The Pollen-Factor covets
## the melon (start); the tamer then sits and waits with the patient melon (complete). It does NOT
## butcher anything (a Bloomwarden beat: some things you outlast, not befriend). The payoff nudges
## Bloomwarden standing rather than corruption: patience is husbandry.
const MELON_QUEST := {
	"id": "the_melon_that_waits",
	"name": "The Melon That Waits",
	"description":
	"Pollen-Factor Dree wants the melon. The melon has other plans. So, now, do you.",
	"step_key": "melon_step",
	"steps":
	[
		{
			"id": "covet_melon",
			"description": "Hear Pollen-Factor Dree out.",
			"on_complete": {"set_flag": "heard_the_factor"}
		},
		{
			"id": "wait_with_melon",
			"description": "Wait with the melon.",
			"on_complete": {"set_flag": "waited_with_melon"}
		},
	],
	"on_complete": {"set_flag": "melon_outlasted", "nudge_standing": ["bloomwardens", 1]},
}

## SQ-05 "Six Petals, True-Bred" — an authored Bloomwarden HUSBANDRY beat. Hearthward Ona presses the
## true-bred seed on you (start); Old Garran offers the kindly-voiced Revel shortcut and you ANSWER
## him (complete) — a real Dialogic choice since W16a: refuse (the creed holds; Bloomwarden-voiced
## toast) or accept (wrong-bright; +1 corruption, Revel-voiced toast). The quest completes on BOTH
## branches — the branch effects/toasts live in Old Garran's NPC "choice" config above.
const BRAMBLE_QUEST := {
	"id": "six_petals_true_bred",
	"name": "Six Petals, True-Bred",
	"description":
	"Hearthward Ona would prove the soft creed works. Old Garran would sell a shortcut.",
	"step_key": "bramble_step",
	"steps":
	[
		{
			"id": "tend_with_ona",
			"description": "Take the true-bred seed from Hearthward Ona.",
			"on_complete": {"set_flag": "met_bramblekind"}
		},
		{
			"id": "answer_garran",
			"description":
			"Answer Old Garran's offer — the long pale way, or the quick bright one.",
			"on_complete": {"set_flag": "answered_garran"}
		},
	],
	"on_complete": {"set_flag": "six_petals_true_bred", "nudge_standing": ["bloomwardens", 1]},
}

## SQ-06 "The Bloom That Won't Bury" — an authored Bloomwarden BOUNTY beat with the soft creed's twist.
## Sister Wenlow begs you to stop the Greenwatcher (an apex that "plants" living patients out of its own
## learned mercy) — and NOT to kill it. Hearing her starts it; pacifying the Greenwatcher (the kind way,
## not the blade) completes it, nudging Bloomwarden standing. Befriend, not butcher: the creed, tested.
const WENLOW_QUEST := {
	"id": "the_bloom_that_wont_bury",
	"name": "The Bloom That Won't Bury",
	"description":
	"A Greenwatcher plants the living out of mercy. Sister Wenlow needs it stopped — kindly.",
	"step_key": "wenlow_step",
	"steps":
	[
		{
			"id": "hear_wenlow",
			"description": "Hear Sister Wenlow's grief.",
			"on_complete": {"set_flag": "met_wenlow"}
		},
		{
			"id": "pacify_greenwatcher",
			"description": "Pacify the Greenwatcher — do not kill it.",
			"on_complete": {"set_flag": "greenwatcher_pacified"}
		},
	],
	"on_complete": {"set_flag": "bloom_that_wont_bury", "nudge_standing": ["bloomwardens", 1]},
}

## Wave 3 (red-team C13) — the BOSS-GOAL quest: active from RUN START (no NPC gives it; the
## overworld auto-starts it), naming the run's goal so the first five minutes communicate what a
## run is FOR. Its single step completes on the boss victory via the existing quest_state flags
## path (the overworld advances it when GameController.slice_cleared() reads true) — so it
## surfaces in the shipped Phase-13c HUD tracker and the Ledger like every other quest. Its
## step_key ("boss_step") is carried by NO NPC, so the NPC dispatch never touches it.
const BOSS_QUEST := {
	"id": "what_guards_the_deep",
	"name": "What Guards the Deep",
	"description":
	"The marsh counts your steps. Somewhere past thirty of them, something old is counting too.",
	"step_key": "boss_step",
	"steps":
	[
		{
			"id": "walk_the_deep_path",
			"description":
			"Something old guards the deep glut — grow, then walk the deep path (30 steps in).",
			"on_complete": {"set_flag": "deep_glut_warden_felled"}
		},
	],
	"on_complete": {"set_flag": "what_guards_the_deep_done"},
}

## W16b (correction C14) — ACT 0, quest 0.1 "The Knack": the capture-unlock gate. Old Maddox's
## "mercy and math" beat (its timeline doubles as W11's first-capture teach) starts it; letting
## one of Mother Kestrel's foundlings choose you completes it. Verbatim scripts_mvp Scene 1.
const KNACK_QUEST := {
	"id": "act0_the_knack",
	"name": "The Knack",
	"description": "Maddox has one rule he'll give you for free. The Foundling Pens keep the rest.",
	"step_key": "knack_step",
	"steps":
	[
		{
			"id": "hear_maddox",
			"description": "Hear Old Maddox out — mercy and math, wearing the same coat.",
			"on_complete": {"set_flag": "maddox_mercy_heard"}
		},
		{
			"id": "meet_kestrel",
			"description": "Walk Mother Kestrel's rows. Let one choose you.",
			"on_complete": {"set_flag": "foundling_chose_you"}
		},
	],
	"on_complete": {"set_flag": "capture_unlocked"},
}

## ACT 0, quest 0.2 "Altar Hours": the tutorial Lab beat. Gated behind The Knack (the
## QuestService trigger predicate — talking to Veil early starts nothing). Scene 2.
const ALTAR_QUEST := {
	"id": "act0_altar_hours",
	"name": "Altar Hours",
	"description":
	"This bench took prayers for four hundred years. Now it takes specimens and a deposit.",
	"step_key": "altar_step",
	"trigger": {"flag": "capture_unlocked"},
	"steps":
	[
		{
			"id": "rent_the_bench",
			"description": "Rent bench time from Surgeon-Lab-Tech Veil. Watch the meter.",
			"on_complete": {"set_flag": "watched_the_meter"}
		},
	],
	"on_complete": {"set_flag": "altar_hours_kept"},
}

## ACT 0, quest 0.3 "The Mark": the inciting incident. CHOICE-driven like SQ-05 — Vael's
## timeline asks how the brand is borne (seal / feed / bargain) and the resolved branch, not
## the talk, advances the step (branch effects live on Vael's NPC "choice" config). Scene 3.
const MARK_QUEST := {
	"id": "act0_the_mark",
	"name": "The Mark",
	"description":
	"You were marked by a dead thing and failed to die. The Table prefers its problems contracted.",
	"step_key": "mark_step",
	"trigger": {"flag": "altar_hours_kept"},
	"steps":
	[
		{
			"id": "answer_the_mark",
			"description": "Answer Vael Construct-Nine. The brand can be borne three ways.",
			"on_complete": {"set_flag": "marked_and_lived"}
		},
	],
	"on_complete": {"set_flag": "arena_opened"},
}

## ACT 0, quest 0.4 "Registered": the Act climax. Entering the rolls with Thessaly Vance ends
## the Nobody act — everyone now knows exactly how much you're worth dead. Scene 4.
const REGISTERED_QUEST := {
	"id": "act0_registered",
	"name": "Registered",
	"description": "Win a bracket bout, enter the rolls, become somebody. The worst thing yet.",
	"step_key": "rolls_step",
	"trigger": {"flag": "arena_opened"},
	"steps":
	[
		{
			"id": "enter_the_rolls",
			"description": "Enter the Arena rolls with Madam Thessaly Vance.",
			"on_complete": {"set_flag": "on_the_rolls"}
		},
	],
	"on_complete": {"set_flag": "registered_aspirant"},
}

## W16b — the PECULIAR defs: authored non-combat "encounters" the W13 seam routes here when a
## triggered roll carries kind == "peculiar" (tension 8: Wave 16 adds peculiars). Data only;
## OverworldPeculiars interprets the fields (befriend_species / item+interval / flag+corrupt
## variant / crack) and applies the resolution. Timelines are registered in dtl_directory.
const PECULIAR_DEFS := [
	{
		# The Conscientious Objector (husbandry_bestiary §D + voice_library §5.5): a wild
		# creature that sits down and vents instead of fighting — befriendable, so the walk
		# away can put it IN the coven via the existing capture/party path.
		"id": "conscientious_objector",
		"timeline": "peculiar_objector",
		"befriend_species": "SB22",  # the radiant deer of region.verdant_glut.fauna
		"nickname": "The Objector",
		"voice_key": "capture.refuses",
	},
	{
		# Pollen-Factor Dree's cursed trinket (SQ-04's merchant, regional_cast V-1): a flavor
		# item into run.inventory, plus the rare deterministic "the bag screams, briefly"
		# follow-up toasts every `interval` steps (OverworldPeculiars.tick_bag_scream).
		"id": "dree_cursed_trinket",
		"timeline": "peculiar_dree_trinket",
		"item": {"item_type": "key", "item_key": "dree_cursed_trinket"},
		"interval": 33,
		"voice_key": "shop.cursed",
	},
	{
		# A Greenwatcher omen (SQ-06's gentle apex): pure dialogue — and the one beat that
		# reads the run back, swapping to a corruption-reactive variant once the rot shows.
		"id": "greenwatcher_omen",
		"timeline": "peculiar_omen",
		"corrupt_timeline": "peculiar_omen_corrupt",
		"corrupt_threshold": 2,
		"flag": "greenwatcher_omen_seen",
	},
	{
		# Fourth-wall crack #2 (rare, rationed): Madam Cessil's tent is never in quite the
		# same spot — once per run it is HERE. Latched via FourthWall.seen_cracks; later
		# rare picks fall back to the omen beat (OverworldPeculiars.resolve_def).
		"id": "cessil_reading",
		"timeline": "peculiar_cessil",
		"crack": "cessil",
	},
]

## Region id -> display TITLE for the overworld HUD (Wave 3: the HUD names the region the systems
## actually run — verdant_glut, not a hard-coded "The Rust Marsh"). Falls back to the raw id.
const REGION_TITLES := {
	"verdant_glut": "The Verdant Glut",
}

## Region id -> force-climate SUBTITLE for the overworld HUD — the FALLBACK when the VoiceBook
## carries no authored entry-sting for the region (W16a: region.<id>.enter, voice_library_2 §1.12).
const REGION_CLIMATES := {
	"verdant_glut": "Eros climate · a thin place",
}

## One peculiar pick in PECULIAR_RARE_DIE is the rationed fourth-wall variant (Madam Cessil);
## OverworldPeculiars falls the rare pick back to the omen beat once her crack has latched.
const PECULIAR_RARE_DIE := 8

## The single shipped region whose catalog quests ride the overworld (E1a: region
## travel will parameterize this; until then the Threshold spine + the Verdant
## slice ride the one shipped region, the W16b pattern).
const ACTIVE_REGION := "verdant_glut"


## Every overworld quest, in one place — the screen registers + dispatches over this list, so a new
## quest is a const above + an entry here (plus its NPC_DEFS step entries). No screen-logic change.
## BOSS_QUEST rides last so an NPC-given quest's objective outranks it in the HUD tracker once one
## is active (the boss goal is the always-on floor, not a squatter). The Act-0 spine (W16b/C14)
## rides between the side quests and the floor: none of it auto-starts, so a fresh run's tracker
## still opens on the boss goal until Maddox is heard.
##
## E1a: the hand-wired defs UNION the ingested catalog (QuestCatalog — generated
## from story_quests.md + side_quests.md) for the ACTIVE region. Dedupe is by id
## and the HAND-WIRED def always wins (Act-0 spine, SQ-04/05/06 and the goals
## stay canonical); catalog quests gate themselves via their act-chain triggers
## and carry step_keys no NPC declares, so the NPC dispatch never touches them.
static func quest_defs() -> Array:
	var hand_wired: Array = [
		MARSH_QUEST,
		MELON_QUEST,
		BRAMBLE_QUEST,
		WENLOW_QUEST,
		KNACK_QUEST,
		ALTAR_QUEST,
		MARK_QUEST,
		REGISTERED_QUEST,
	]
	var seen: Dictionary = {}
	for def: Dictionary in hand_wired:
		seen[str(def.get("id", ""))] = true
	seen[str(BOSS_QUEST["id"])] = true
	var defs: Array = hand_wired.duplicate()
	for def: Dictionary in QuestCatalog.defs_for_region(ACTIVE_REGION):
		var quest_id := str(def.get("id", ""))
		if seen.has(quest_id):
			continue
		seen[quest_id] = true
		defs.append(def)
	defs.append(BOSS_QUEST)
	return defs


## The peculiar def a triggered roll resolves to — a PURE function of the roll's canonical
## fields (step + battle_seed), hashed LOCALLY (never the canonical PCG32 streams), so the
## same roll always sits down with the same beat. The rare Cessil variant fires on ~1 pick in
## PECULIAR_RARE_DIE; the caller (OverworldPeculiars.resolve_def) applies the one-shot ration.
static func pick_peculiar(roll: Dictionary) -> Dictionary:
	var salt := "peculiar:%d:%d" % [int(roll.get("step", 0)), int(roll.get("battle_seed", 0))]
	var h := absi(hash(salt))
	if h % PECULIAR_RARE_DIE == 0:
		return peculiar_def("cessil_reading")
	var mains: Array = []
	for def: Dictionary in PECULIAR_DEFS:
		if not def.has("crack"):
			mains.append(def)
	if mains.is_empty():
		return {}
	return mains[absi(hash("pick:" + salt)) % mains.size()]


## The peculiar def with `id`, or {} when unknown (single lookup for the resolver + tests).
static func peculiar_def(id: String) -> Dictionary:
	for def: Dictionary in PECULIAR_DEFS:
		if str(def.get("id", "")) == id:
			return def
	return {}


## The HUD title for a region id ("The Verdant Glut"), falling back to the id itself.
static func region_title(region_id: String) -> String:
	return str(REGION_TITLES.get(region_id, region_id))


## The HUD region blurb for a region id, or "" when unmapped (the HUD hides it). W16a: the
## authored region entry-sting from the VoiceBook ("region.<id>.enter" — verbatim library
## copy, keyed per region) with the hand-written climate line as fallback.
static func region_climate(region_id: String) -> String:
	var sting := VoiceBook.pick("region.%s.enter" % region_id)
	if sting != "":
		return sting
	return str(REGION_CLIMATES.get(region_id, ""))
