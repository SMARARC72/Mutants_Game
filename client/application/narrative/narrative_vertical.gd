class_name NarrativeVertical
extends Node
## The sample vertical (ADR-017, deliverable D4) wired end-to-end as one object:
##
##   Ink lore branch (with an EXTERNAL query: region_unlocked / has_creature)
##     -> a Dialogic encounter (funny-grim, a rare 4th-wall beat)
##       -> a quest that GATES something real by writing run state via QuestService
##         -> save -> reload -> state intact.
##
## This proves the split: Ink DECIDES (branches + flips quest vars), Dialogic RENDERS
## (the VN beat), QuestService owns STATE (unlocks a Lab op + marks a capture target).
## No gameplay math anywhere — only gates/triggers.
##
## Designed to run headless: Dialogic playback no-ops (display-guarded in the facade)
## but the flow still completes so CI/tests can drive it.

const InkBridgeScript := preload("res://application/narrative/ink_bridge.gd")
const DialogicFacadeScript := preload("res://presentation/narrative/dialogic_facade.gd")
const NarrativeSaveScript := preload("res://application/narrative/narrative_save.gd")

const STORY_PATH := "res://presentation/narrative/stories/rust_marsh_omen.inkjson"
const SAVE_PATH := "user://narrative_vertical_save.json"

# The quest definition this vertical gates with. Data-only; QuestService applies the
# effects to run state. Completing it unlocks a Lab op + marks a capture target —
# both narrative-relevant flags, never stats.
const QUEST_DEF := {
	"id": "rust_marsh_omen",
	"name": "Omens in the Rust",
	"description": "The marsh has your name in oxidation. Rude. Investigate.",
	"steps":
	[
		{
			"id": "read_the_omens",
			"description": "Kneel and read the rust-omens.",
			"on_complete": {"set_flag": "saw_marsh_omen"},
		},
		{
			"id": "meet_the_wretch",
			"description": "Survive the Bog-Wretch's opinions.",
			"on_complete": {"mark_captured": "bog_wretch"},
		},
	],
	# Finishing the quest gates the real things: a Lab op unlock + region access.
	"on_complete":
	{
		"unlock_region": "rust_marsh",
		"set_flag": "lab_op_unlocked:necropsy",
		"add_corruption": 2,
	},
}

var _bridge: InkBridge
var _dialogic: RefCounted  # DialogicFacade


## Builds the vertical with a fresh (or supplied) QuestService and registers the quest.
func setup(quest_service: QuestService = null) -> void:
	var quests: QuestService = quest_service if quest_service != null else QuestService.new()
	quests.register([QUEST_DEF])
	_bridge = InkBridgeScript.new(quests)
	add_child(_bridge)
	_dialogic = DialogicFacadeScript.new()


func quest_service() -> QuestService:
	return _bridge.quest_service()


func ink_bridge() -> InkBridge:
	return _bridge


## Loads the Ink story + wires the quest-driver variable observers.
func load() -> bool:
	return await _bridge.load_story(
		STORY_PATH, ["quest_rust_marsh_omen_start", "quest_rust_marsh_omen_advance"]
	)


## Runs the full slice: walk the Ink branch (choosing "read the omens"), let Ink flip
## the quest-start var (observer starts the quest), render the Dialogic encounter, then
## advance the quest through both steps so it gates run state. Returns a transcript
## (data only) so tests/CI can assert what happened on screen.
func run() -> Array:
	var transcript: Array = []
	var quests: QuestService = quest_service()

	# 1) Ink decides: advance to the first choice point.
	while _bridge.can_continue():
		var line: String = _bridge.continue_story()
		if line.strip_edges() != "":
			transcript.append({"source": "ink", "text": line.strip_edges()})

	# 2) Pick the lore branch that starts the quest (choice 0 = "read the omens").
	if _bridge.has_choices():
		transcript.append({"source": "ink_choices", "choices": _bridge.current_choices()})
		_bridge.choose(0)
		while _bridge.can_continue():
			var line: String = _bridge.continue_story()
			if line.strip_edges() != "":
				transcript.append({"source": "ink", "text": line.strip_edges()})

	# The Ink branch set quest_rust_marsh_omen_start = true; the bridge observer has
	# already called QuestService.start("rust_marsh_omen"). Advance step 1 (read omens).
	quests.advance("rust_marsh_omen", "read_the_omens")
	transcript.append({"source": "quest", "event": "advanced", "step": "read_the_omens"})

	# 3) Dialogic renders the encounter the Ink branch requested (render_timeline). WAIT
	#    for it to finish before granting rewards: on-screen, play_timeline returns true
	#    and scene_finished fires when the timeline ends, so we await it; headless, it
	#    returns false having already resolved synchronously, so we fall straight through.
	var timeline: String = str(_bridge_render_timeline())
	if timeline != "":
		transcript.append({"source": "dialogic", "timeline": timeline})
		if _dialogic.play_timeline(timeline):
			await _dialogic.scene_finished

	# 4) The encounter resolved -> advance the final step; the quest auto-completes and
	#    its on_complete effect GATES run state (unlock region + Lab op + corruption).
	quests.advance("rust_marsh_omen", "meet_the_wretch")
	transcript.append({"source": "quest", "event": "completed", "id": "rust_marsh_omen"})

	return transcript


## Reads the Ink VAR that names the Dialogic timeline to render (Ink decides "what",
## Dialogic decides "how it looks").
func _bridge_render_timeline() -> String:
	var value: Variant = _bridge._ink.get_variable("render_timeline")
	return str(value) if value != null else ""


# --- save / reload (versioned JSON, ADR-012) --- #


func save() -> int:
	var payload: Dictionary = quest_service().serialize()
	var ink_state: String = _bridge.ink_state_json()
	var json: String = NarrativeSaveScript.build_json(payload, ink_state, "cluster3")
	return NarrativeSaveScript.save_to_path(SAVE_PATH, json)


## Loads the save into a freshly-built vertical (proving state survives a round-trip).
## Returns true on success; the restored QuestService is then queryable.
func restore() -> bool:
	var text: String = NarrativeSaveScript.load_from_path(SAVE_PATH)
	if text == "":
		return false
	var envelope: Dictionary = NarrativeSaveScript.parse_json(text)
	if envelope.is_empty():
		return false
	quest_service().deserialize(NarrativeSaveScript.quest_payload(envelope))
	_bridge.restore_ink_state(NarrativeSaveScript.ink_state(envelope))
	return true
