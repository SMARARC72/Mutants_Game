class_name OverworldQuestsGlue
extends RefCounted
## Quest def/effect/persistence glue (extracted from overworld_screen for the lint line cap —
## the incremental-decomposition rule). Pure data-plumbing between OverworldContent quest defs,
## the screen-local QuestService, and the ACTUAL run (rewards must be real + saved).


static func quest_def_by_id(quest_id: String, region_id: String = "") -> Dictionary:
	for d: Dictionary in OverworldContent.quest_defs(region_id):
		if str(d.get("id", "")) == quest_id:
			return d
	return {}


## The `on_complete` effect of a named step of a quest, or {} if not found.
static func quest_step_effect(
	quest_id: String, step_id: String, region_id: String = ""
) -> Dictionary:
	for s: Dictionary in quest_def_by_id(quest_id, region_id).get("steps", []) as Array:
		if str(s.get("id", "")) == step_id:
			return s.get("on_complete", {}) as Dictionary
	return {}


## E2a: the FIRST advanced quest whose def names an authored scene that actually shipped (the
## generated .dtl is probed — a missing scene keeps the toast behavior). "" when none; the
## screen plays it over the talk/bark beat, so the story's scene fires where the story moved.
static func scene_for_advanced(advanced: Array, region_id: String = "") -> String:
	for quest_id: Variant in advanced:
		var timeline := str(quest_def_by_id(str(quest_id), region_id).get("timeline", ""))
		if timeline != "" and DialogicFacade.timeline_exists(timeline):
			return timeline
	return ""


## E2a: play the advanced quests' authored scene through the screen's dialogue plumbing (the
## OverworldChoices.maybe_play_intro pattern — screen-private state via get()/set()). Returns
## the scene id played ("" when nothing advanced or no scene shipped).
static func play_scene_for(screen: Node, advanced: Array) -> String:
	var scene := scene_for_advanced(advanced, str(screen.call("_region_id")))
	if scene == "":
		return ""
	if screen.get("_dialogue") == null:
		screen.set("_dialogue", DialogicFacade.new())
	var dialogue: DialogicFacade = screen.get("_dialogue")
	var finished := Callable(screen, "_on_dialogue_finished")
	if not dialogue.scene_finished.is_connected(finished):
		dialogue.scene_finished.connect(finished)
	screen.set("_in_dialogue", true)
	screen.emit_signal("dialogue_started", scene)
	dialogue.play_timeline(scene)
	return scene


## Wave 3 (red-team C13): the BOSS-GOAL quest is active from RUN START (no NPC gives it — started
## on every build until it sticks) and completes through the quest_state flags path the moment the
## slice reads cleared (a played boss win sets the victory flag via GameController
## ._mark_slice_cleared). E1b: it is the VERDANT slice's goal — it only syncs (starts/advances)
## while the run stands in the starting region; another region's boss clear must never complete it.
static func sync_boss_goal(screen: Node, quests: QuestService, game: Node) -> void:
	if quests == null or str(screen.call("_region_id")) != EncounterCatalog.STARTING_REGION:
		return
	var qid := str(OverworldContent.BOSS_QUEST["id"])
	if quests.is_done(qid):
		return
	if not quests.is_active(qid) and quests.start(qid):
		screen.call("_persist_quests")
		screen.call("_refresh_objective")
	if game != null and game.has_method("slice_cleared") and bool(game.call("slice_cleared")):
		screen.call("_advance_quest_step", qid, "walk_the_deep_path")


## E2a — drive the catalog quests that resolve by DEED, not talk (QuestCatalog.VICTORY_FLAGS,
## surfaced on the defs as `victory_flag`):
##   * a BOSS quest auto-starts the moment its act-chain trigger opens (its objective lands in
##     the HUD tracker — the act names the god to fell) and COMPLETES when its region's
##     boss-victory flag (GameController._mark_slice_cleared on a played boss win) is on the run;
##   * a WITNESS quest (victory flag "" — the doc's giver is "the moment/game itself") resolves
##     on its own once startable, so the act 5 coda lands without an NPC.
## Called on every overworld build (fresh, post-battle, post-travel). Single pass in def order —
## the doc-ordered chain lets Q5.3 -> Q5.4 cascade inside one pass. Returns the ADVANCED quest
## ids so the screen can play an authored scene for the beat.
static func sync_catalog_quests(screen: Node, quests: QuestService) -> Array:
	var advanced: Array = []
	if screen == null or quests == null:
		return advanced
	var run: RunContext = screen.call("_run_ctx")
	if run == null:
		return advanced
	var started := false
	for def: Dictionary in screen.call("_quest_defs") as Array:
		if not def.has("victory_flag"):
			continue
		var quest_id := str(def.get("id", ""))
		if quests.is_done(quest_id):
			continue
		if not quests.is_active(quest_id) and quests.start(quest_id):
			started = true
		if not quests.is_active(quest_id):
			continue
		var flag := str(def.get("victory_flag", ""))
		if flag != "" and not bool(run.flags.get(flag, false)):
			continue
		var steps: Array = def.get("steps", []) as Array
		if steps.is_empty():
			continue
		var step_id := str((steps[0] as Dictionary).get("id", ""))
		if bool(screen.call("_advance_quest_step", quest_id, step_id)):
			advanced.append(quest_id)
	if started:
		screen.call("_persist_quests")
		screen.call("_refresh_objective")
	return advanced


## Apply a quest effect to the ACTUAL run (corruption / standing / flags), not just the
## screen-local QuestService run-state. Data-only effect dict. Returns true when corruption
## moved (the caller refreshes the mood grade + HUD pip).
static func apply_effect_to_run(game: Node, effect: Dictionary) -> bool:
	if effect.is_empty() or game == null or not game.has_method("run"):
		return false
	var run: RunContext = game.call("run")
	if run == null:
		return false
	if effect.has("set_flag"):
		run.flags[str(effect["set_flag"])] = true
	var corruption_moved := false
	if effect.has("add_corruption"):
		run.corruption += int(effect["add_corruption"])
		corruption_moved = true
	if effect.has("nudge_standing"):
		var pair: Array = effect["nudge_standing"]
		if (
			pair.size() == 2
			and str(pair[0]) == "bloomwardens"
			and game.has_method("adjust_bloomwardens_standing")
		):
			game.call("adjust_bloomwardens_standing", int(pair[1]))
	return corruption_moved


## Serialize quest progress into run.flags and persist the run (quests survive the screen).
static func persist_quests(game: Node, quests: QuestService) -> void:
	if quests == null or game == null or not game.has_method("run"):
		return
	var run: RunContext = game.call("run")
	if run == null:
		return
	run.flags["quest_state"] = quests.serialize()
	# W18 save trust: the witnessed save path first (SaveSentry surfaces the outcome).
	if game.has_method("request_save"):
		game.call("request_save")
	elif game.has_method("save_run"):
		game.call("save_run")


## Restore quest progress from the run (a re-entered overworld keeps quest state).
static func restore_quests(game: Node, quests: QuestService) -> void:
	if quests == null or game == null or not game.has_method("run"):
		return
	var run: RunContext = game.call("run")
	if run != null and run.flags.has("quest_state"):
		quests.deserialize(run.flags["quest_state"] as Dictionary)
