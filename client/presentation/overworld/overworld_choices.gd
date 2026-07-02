class_name OverworldChoices
extends RefCounted
## W16a — the Dialogic CHOICE -> QuestService wiring, extracted from overworld_screen to keep
## it under the lint line cap (the OverworldMotion/OverworldTokens extraction pattern).
##
## A timeline branch announces itself as `[signal arg="choice:<tag>"]`; DialogicFacade re-emits
## it as choice_made(scene_id, branch_tag); the screen delegates here. Dispatch is data-driven
## off the NPC's "choice" config in OverworldContent.NPC_DEFS:
##   { "quest": <id>, "step": <step-id>, "headless_branch": <canon tag>,
##     "branches": { <tag>: { "effect": {..run effect..}, "voice_key": <VoiceBook key> } } }
## Both branches advance the SAME step, so a choice quest completes either way (SQ-05's
## contract); the branches differ in run effects and in the authored toast voice.


## Apply the resolved branch for `scene_id`. Effects/toast fire ONLY on a real quest advance —
## a re-talk after completion (or an out-of-order talk whose advance is rejected by the quest
## cursor) must not re-apply corruption or flags.
static func handle(screen: Node, npcs: Array, scene_id: String, branch_tag: String) -> void:
	for npc: Dictionary in npcs:
		if str(npc.get("timeline", "")) != scene_id:
			continue
		var conf: Dictionary = npc.get("choice", {})
		if conf.is_empty():
			continue
		var branch: Dictionary = (conf.get("branches", {}) as Dictionary).get(branch_tag, {})
		if branch.is_empty():
			return
		var quest_id := str(conf.get("quest", ""))
		var step_id := str(conf.get("step", ""))
		if not bool(screen.call("_advance_quest_step", quest_id, step_id, false)):
			return
		screen.call("_apply_effect_to_run", branch.get("effect", {}) as Dictionary)
		screen.call("_persist_quests")
		toast_branch_line(screen, str(branch.get("voice_key", "")))
		return


## Toast a choice branch's authored line (VoiceBook) inside the standard quest-update
## scaffolding (title/icon/sound from the ToastMicrocopy preset — no hand-written copy).
## pick_plain: a toast never interpolates, so {placeholder} variants are skipped (W16b —
## the Act-0 catch branches voice through the §5 capture keys, some of which name the beast).
static func toast_branch_line(screen: Node, voice_key: String) -> void:
	var toast := screen.get_node_or_null("/root/Toast")
	if toast == null:
		return
	var line := VoiceBook.pick_plain(voice_key)
	if line == "" and toast.has_method("event"):
		toast.call("event", "quest_update")  # missing key: fall back to the generic ledger toast
		return
	if toast.has_method("show"):
		var payload := ToastMicrocopy.preset(ToastMicrocopy.QUEST)
		payload["body"] = line
		toast.call("show", payload)
