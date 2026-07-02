class_name OverworldQuestsGlue
extends RefCounted
## Quest def/effect/persistence glue (extracted from overworld_screen for the lint line cap —
## the incremental-decomposition rule). Pure data-plumbing between OverworldContent quest defs,
## the screen-local QuestService, and the ACTUAL run (rewards must be real + saved).


static func quest_def_by_id(quest_id: String) -> Dictionary:
	for d: Dictionary in OverworldContent.quest_defs():
		if str(d.get("id", "")) == quest_id:
			return d
	return {}


## The `on_complete` effect of a named step of a quest, or {} if not found.
static func quest_step_effect(quest_id: String, step_id: String) -> Dictionary:
	for s: Dictionary in quest_def_by_id(quest_id).get("steps", []) as Array:
		if str(s.get("id", "")) == step_id:
			return s.get("on_complete", {}) as Dictionary
	return {}


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
	if game.has_method("save_run"):
		game.call("save_run")


## Restore quest progress from the run (a re-entered overworld keeps quest state).
static func restore_quests(game: Node, quests: QuestService) -> void:
	if quests == null or game == null or not game.has_method("run"):
		return
	var run: RunContext = game.call("run")
	if run != null and run.flags.has("quest_state"):
		quests.deserialize(run.flags["quest_state"] as Dictionary)
