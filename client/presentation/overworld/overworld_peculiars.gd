class_name OverworldPeculiars
extends RefCounted
## Wave 16b — the CONTENT side of the peculiar-encounter seam. A sibling wave (W13) teaches
## EncounterDirector to mark a triggered roll `kind == "peculiar"` and routes it to the
## overworld screen's `peculiar_encounter(roll)` / PECULIAR_HOOK. THIS module is what that
## hook calls: it resolves WHICH authored beat fires (OverworldContent.pick_peculiar — a
## pure function of the roll), plays its Dialogic timeline, and applies its resolution to
## the run — a fight that never happens, per the master plan ("an 'encounter' sits down
## and vents — and you can walk away with it in your coven").
##
## INTEGRATION CONTRACT (for the W13 integrator): wire the screen's hook to
##     OverworldPeculiars.play(self, roll)
## The roll needs only its existing canonical fields (step / battle_seed). play() NEVER
## instantiates the battle scene, never stashes pending_battle, and is headless-safe
## (DialogicFacade resolves instantly without a display).
##
## Resolutions (data-driven off OverworldContent.PECULIAR_DEFS):
##   * `befriend_species` — the Conscientious Objector joins the coven through the EXISTING
##     capture shape: CaptureService.to_creature_instance_named -> GameController.add_party_member.
##   * `item` — Pollen-Factor Dree's cursed trinket lands in run.inventory (InventoryAdapter)
##     and arms the deterministic step-count "the bag screams, briefly" follow-up toasts.
##   * `flag` — a pure dialogue beat (the Greenwatcher omen) marks that it was witnessed;
##     a `corrupt_timeline` variant plays instead once run.corruption crosses the threshold.
##   * `crack` — a rationed fourth-wall variant (Madam Cessil), latched ONCE per run through
##     FourthWall's seen_cracks registry; after that the pick falls back to the omen beat.

const CaptureServiceScript := preload("res://application/battle/capture_service.gd")
const FourthWallScript := preload("res://presentation/narrative/fourth_wall.gd")
const VoiceBookScript := preload("res://presentation/narrative/voice_book.gd")
const ToastMicrocopyScript := preload("res://presentation/ui/toast/toast_microcopy.gd")

## run.world_state key: the NEXT step index at which the cursed trinket screams again.
const SCREAM_AT_KEY := "bag_scream_at"


## Play the peculiar beat for a triggered roll. Returns a result dict for tests/observers:
## { "id", "timeline", "joined": species_id|"", "item": item_key|"", "crack": bool }.
static func play(screen: Node, roll: Dictionary) -> Dictionary:
	var game := screen.get("_game") as Node
	var run: RunContext = game.call("run") if game != null and game.has_method("run") else null
	var def := resolve_def(roll, run)
	if def.is_empty():
		return {}
	var timeline := _timeline_for(def, run)
	var result := {
		"id": str(def.get("id", "")),
		"timeline": timeline,
		"joined": "",
		"item": "",
		"crack": bool(def.has("crack")),
	}
	_apply_resolution(screen, game, run, def, roll, result)
	if screen.has_signal("dialogue_started"):
		screen.emit_signal("dialogue_started", timeline)
	# Movement suspends like any NPC scene: reuse (or install) the screen's persistent facade so
	# scene_finished still reaches _on_dialogue_finished after this call returns. Headless the
	# scene resolves synchronously, so _in_dialogue is already false again by the return.
	screen.set("_in_dialogue", true)
	_facade_for(screen).play_timeline(timeline)
	if game != null and game.has_method("save_run"):
		game.call("save_run")
	return result


## The screen's own DialogicFacade (created + installed when it has none yet), wired to its
## dialogue-finished handler — a transient facade would be freed while an on-screen scene is
## still playing and the movement lock would never lift.
static func _facade_for(screen: Node) -> DialogicFacade:
	var facade := screen.get("_dialogue") as DialogicFacade
	if facade == null:
		facade = DialogicFacade.new()
		if "_dialogue" in screen:
			screen.set("_dialogue", facade)
	if screen.has_method("_on_dialogue_finished"):
		var handler := Callable(screen, "_on_dialogue_finished")
		if not facade.scene_finished.is_connected(handler):
			facade.scene_finished.connect(handler)
	return facade


## The def a roll resolves to, AFTER the fourth-wall ration: the rare Cessil variant only
## fires while her crack is unlatched (FourthWall latches it here, once per run); every
## later rare pick falls back to the omen beat. Pure pick itself lives in OverworldContent.
static func resolve_def(roll: Dictionary, run: RunContext) -> Dictionary:
	var def: Dictionary = OverworldContent.pick_peculiar(roll)
	if def.has("crack") and not FourthWallScript.latch(run, str(def["crack"])):
		return OverworldContent.peculiar_def("greenwatcher_omen")
	return def


## The per-step follow-up for the cursed trinket: once armed, every SCREAM cadence step the
## bag screams, briefly (an authored cursed-goods line as a toast), then re-arms. Purely a
## deterministic function of the world_state counter + step index. Returns the line ("" =
## silent step) so tests can drive the counter.
static func tick_bag_scream(run: RunContext, step_index: int, toast: Node) -> String:
	if run == null or not run.world_state.has(SCREAM_AT_KEY):
		return ""
	var due := int(run.world_state.get(SCREAM_AT_KEY, -1))
	if due < 0 or step_index < due:
		return ""
	var interval := int(OverworldContent.peculiar_def("dree_cursed_trinket").get("interval", 33))
	run.world_state[SCREAM_AT_KEY] = step_index + interval
	var line := VoiceBookScript.pick("shop.cursed", step_index)
	if line != "" and toast != null and toast.has_method("show"):
		var payload: Dictionary = ToastMicrocopyScript.preset(ToastMicrocopyScript.CORRUPTION)
		payload["title"] = "The bag screams, briefly."
		payload["body"] = line
		toast.call("show", payload)
	return line


# --- internals -------------------------------------------------------------------------------- #


## The timeline this def plays NOW: the corruption-reactive variant once the run has rotted
## past the def's threshold, else the plain beat.
static func _timeline_for(def: Dictionary, run: RunContext) -> String:
	if def.has("corrupt_timeline") and run != null:
		if run.corruption >= int(def.get("corrupt_threshold", 2)):
			return str(def["corrupt_timeline"])
	return str(def.get("timeline", ""))


static func _apply_resolution(
	screen: Node, game: Node, run: RunContext, def: Dictionary, roll: Dictionary, result: Dictionary
) -> void:
	var salt := int(roll.get("step", 0))
	if def.has("befriend_species"):
		result["joined"] = _befriend(screen, game, def, salt)
	elif def.has("item"):
		result["item"] = _pocket_item(screen, game, run, def, salt)
	if def.has("flag") and run != null:
		run.flags[str(def["flag"])] = true


## The Conscientious Objector joins through the existing capture/party path (thin wiring:
## the SAME creature_instance shape a battle capture appends). Returns the species id ("").
static func _befriend(screen: Node, game: Node, def: Dictionary, salt: int) -> String:
	if game == null or not game.has_method("add_party_member") or not game.has_method("catalog"):
		return ""
	var species_id := str(def.get("befriend_species", ""))
	var catalog: SpeciesCatalog = game.call("catalog")
	var species: SpeciesData = catalog.get_by_id(species_id) if catalog != null else null
	if species == null:
		return ""
	var instance: Dictionary = CaptureServiceScript.to_creature_instance_named(
		str(def.get("nickname", species.name)), species
	)
	game.call("add_party_member", instance)
	var line := VoiceBookScript.pick(str(def.get("voice_key", "capture.refuses")), salt)
	_toast(screen, ToastMicrocopyScript.CAUGHT, line.format({"creature": species.name}))
	return species_id


## Dree's cursed trinket into run.inventory (InventoryAdapter) + the scream trigger armed.
static func _pocket_item(
	screen: Node, game: Node, run: RunContext, def: Dictionary, salt: int
) -> String:
	if game == null or not game.has_method("inventory"):
		return ""
	var item: Dictionary = def.get("item", {})
	var item_key := str(item.get("item_key", ""))
	if item_key == "":
		return ""
	var inventory: InventoryAdapter = game.call("inventory")
	inventory.add(str(item.get("item_type", "key")), item_key, 1, {"source": "peculiar"})
	if game.has_method("write_inventory"):
		game.call("write_inventory")
	if run != null:
		var interval := int(def.get("interval", 33))
		var step := int(game.call("current_step")) if game.has_method("current_step") else 0
		run.world_state[SCREAM_AT_KEY] = step + interval
	var line := VoiceBookScript.pick(str(def.get("voice_key", "shop.cursed")), salt)
	_toast(screen, ToastMicrocopyScript.CAUGHT, line)
	return item_key


## An authored line inside the standard toast scaffolding (title/icon/sound from the
## ToastMicrocopy preset; body from the VoiceBook). No-op without the Toast autoload.
static func _toast(screen: Node, event_id: String, line: String) -> void:
	if line == "":
		return
	var toast := screen.get_node_or_null("/root/Toast")
	if toast == null or not toast.has_method("show"):
		return
	var payload: Dictionary = ToastMicrocopyScript.preset(event_id)
	payload["body"] = line
	toast.call("show", payload)
