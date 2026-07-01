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
		"bramble_step": "refuse_garran",
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
## true-bred seed on you (start); Old Garran offers the kindly-voiced Revel shortcut and you turn it
## down (complete). The soft creed's proof: love is a method, not a mood. The payoff advances
## Bloomwarden standing (toward Associate) — patience, again, is husbandry; no corruption.
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
			"id": "refuse_garran",
			"description": "Turn down Old Garran's shortcut.",
			"on_complete": {"set_flag": "refused_the_shortcut"}
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

## Region id -> display TITLE for the overworld HUD (Wave 3: the HUD names the region the systems
## actually run — verdant_glut, not a hard-coded "The Rust Marsh"). Falls back to the raw id.
const REGION_TITLES := {
	"verdant_glut": "The Verdant Glut",
}

## Region id -> force-climate SUBTITLE for the overworld HUD. Falls back to "" (subtitle hidden).
const REGION_CLIMATES := {
	"verdant_glut": "Eros climate · a thin place",
}


## Every overworld quest, in one place — the screen registers + dispatches over this list, so a new
## quest is a const above + an entry here (plus its NPC_DEFS step entries). No screen-logic change.
## BOSS_QUEST rides last so an NPC-given quest's objective outranks it in the HUD tracker once one
## is active (the boss goal is the always-on floor, not a squatter).
static func quest_defs() -> Array:
	return [MARSH_QUEST, MELON_QUEST, BRAMBLE_QUEST, WENLOW_QUEST, BOSS_QUEST]


## The HUD title for a region id ("The Verdant Glut"), falling back to the id itself.
static func region_title(region_id: String) -> String:
	return str(REGION_TITLES.get(region_id, region_id))


## The HUD force-climate subtitle for a region id, or "" when unmapped (the HUD hides it).
static func region_climate(region_id: String) -> String:
	return str(REGION_CLIMATES.get(region_id, ""))
