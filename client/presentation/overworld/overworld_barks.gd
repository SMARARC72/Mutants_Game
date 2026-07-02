class_name OverworldBarks
extends RefCounted
## Wave 16b — ambient PROXIMITY BARKS: the wired NPCs mutter their authored voice_library
## region lines (`bark.region.<region_id>`) in a small floating ink-panel bubble when the
## tamer walks within BARK_RANGE cells. Extracted OverworldChoices-style so the screen only
## carries a one-line hook.
##
## Rationing is a HARD world_state cooldown: at least COOLDOWN_STEPS steps between ANY two
## barks (`last_bark_step`), never during dialogue. The variant pick is DETERMINISTIC — a
## LOCAL hash of (key, step index) inside VoiceBook.pick, never the canonical PCG32 streams.
##
## It also owns the 5TH-REPEAT swap: talk to the SAME NPC a 5th+ time (a `npc_talks`
## world_state counter) and the scene is swapped for the authored out-of-lines beat
## (`fourthwall.over_talked`) — the writers' answer to being farmed for dialogue.

const VoiceBookScript := preload("res://presentation/narrative/voice_book.gd")
const FourthWallScript := preload("res://presentation/narrative/fourth_wall.gd")
const OverworldTileSetScript := preload("res://presentation/overworld/overworld_tileset.gd")

## Hard floor between ANY two ambient barks, in overworld steps (world_state counter).
const COOLDOWN_STEPS := 25
## Barks fire only when the tamer is within this many cells of a wired NPC (Chebyshev).
const BARK_RANGE := 2
## Talking to the same NPC this many times (or more) swaps to the out-of-lines beat.
const OUT_OF_LINES_AT := 5
## How long a bubble lingers before the ink swallows it again (seconds).
const BUBBLE_SECONDS := 2.6

const LAST_BARK_KEY := "last_bark_step"
const TALKS_KEY := "npc_talks"


## The per-step ambient tick (called by the overworld on every completed step). Fires at
## most one bark: cooldown honoured, dialogue suppressed, deterministic line pick. Returns
## the bark line fired ("" when silent) so tests can drive the counter and assert.
static func step_tick(screen: Node, run: RunContext, step_index: int) -> String:
	if screen == null or run == null:
		return ""
	if screen.get("_in_dialogue") == true:
		return ""
	var last := int(run.world_state.get(LAST_BARK_KEY, -COOLDOWN_STEPS))
	if step_index - last < COOLDOWN_STEPS:
		return ""
	var npc := _npc_in_range(screen)
	if npc.is_empty():
		return ""
	var region := str(screen.call("_region_id")) if screen.has_method("_region_id") else ""
	var line := VoiceBookScript.pick("bark.region.%s" % region, step_index)
	if line == "":
		return ""
	run.world_state[LAST_BARK_KEY] = step_index
	bubble(screen, npc, line)
	return line


## Count a talk to `npc_name` in the persistent world_state tally; returns the NEW total
## (JSON round-trips numbers as floats — int()-coerced here).
static func count_talk(run: RunContext, npc_name: String) -> int:
	if run == null or npc_name == "":
		return 0
	var talks: Dictionary = run.world_state.get(TALKS_KEY, {})
	var next := int(talks.get(npc_name, 0)) + 1
	talks[npc_name] = next
	run.world_state[TALKS_KEY] = talks
	return next


## True when `npc_name` has been talked dry (the 5th+ visit swaps to out-of-lines).
static func out_of_lines(run: RunContext, npc_name: String) -> bool:
	if run == null:
		return false
	var talks: Dictionary = run.world_state.get(TALKS_KEY, {})
	return int(talks.get(npc_name, 0)) >= OUT_OF_LINES_AT


## The screen's whole 5TH-REPEAT policy in one call: tally this talk and, when the NPC has
## been talked dry, bubble the authored out-of-lines beat INSTEAD of a scene replay (returns
## true = the caller skips the timeline). An NPC still holding an UNRESOLVED choice quest
## keeps its real scene no matter the tally — a branch must never be talked out of reach.
static func swap_out_of_lines(screen: Node, npc: Dictionary, run: RunContext) -> bool:
	var talks := count_talk(run, str(npc.get("name", "")))
	var conf: Dictionary = npc.get("choice", {})
	if not conf.is_empty() and screen != null and screen.has_method("quest_done"):
		if not bool(screen.call("quest_done", str(conf.get("quest", "")))):
			return false
	if talks < OUT_OF_LINES_AT:
		return false
	play_out_of_lines(screen, npc)
	return true


## W16b fourth-wall crack #1: the weathered SIGNPOST reads once per run — the authored line
## formatted with the run's actual save name, latched via FourthWall's registry, persisted,
## bubbled over the sign. Ever after it is just a sign, and it has said everything it knows
## (returns "": the ration holds). Returns "signpost" on the one read.
static func read_signpost(screen: Node, npc: Dictionary, run: RunContext, game: Node) -> String:
	var line := FourthWallScript.signpost_line(run)
	if line == "":
		return ""
	bubble(screen, npc, line)
	if game != null and game.has_method("save_run"):
		game.call("save_run")
	return "signpost"


## The veil coughs: announce a misbehavior draw (moved from overworld_screen for the line cap
## — W-DRESS). world.veil_coughs is the reserved ingest key; weather.rare is the shipped
## authored fallback per the VoiceBook contract.
static func toast_misbehavior(screen: Node) -> void:
	var toast := screen.get_node_or_null("/root/Toast")
	if toast == null or not toast.has_method("show"):
		return
	var line := VoiceBookScript.pick("world.veil_coughs")
	if line == "":
		line = VoiceBookScript.pick("weather.rare")
	toast.call("show", {"title": "The veil coughs.", "body": line, "sound": "hum"})


## The authored out-of-lines beat, bubbled over the exhausted NPC in place of a replayed
## scene. Returns the line (always authored; the key ships in voice.json).
static func play_out_of_lines(screen: Node, npc: Dictionary) -> String:
	var line := VoiceBookScript.pick("fourthwall.over_talked")
	if line == "":
		return ""
	bubble(screen, npc, line)
	return line


## A small floating speech bubble: ink panel, parchment text, brass hairline — anchored
## above the NPC's token and swallowed again after BUBBLE_SECONDS. Headless/out-of-tree
## safe: without a tree to time the fade, the bark still COUNTS (the cooldown is state,
## not presentation) and no node is left behind.
static func bubble(_screen: Node, npc: Dictionary, line: String) -> void:
	var anchor := npc.get("node") as Node2D
	if anchor == null or not is_instance_valid(anchor) or not anchor.is_inside_tree():
		return
	var old := anchor.get_node_or_null("BarkBubble")
	if old != null:
		old.queue_free()
	var panel := PanelContainer.new()
	panel.name = "BarkBubble"
	panel.z_index = 20
	var style := StyleBoxFlat.new()
	style.bg_color = GrimoirePalette.INK_PANEL
	style.border_color = GrimoirePalette.BRASS
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(7)
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = line
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(210, 0)
	label.add_theme_color_override("font_color", GrimoirePalette.TEXT_ON_INK)
	label.add_theme_font_size_override("font_size", 12)
	panel.add_child(label)
	anchor.add_child(panel)
	var tile := float(OverworldTileSetScript.TILE_SIZE)
	panel.position = Vector2(-110, -tile * 1.35 - 34)
	# The fade timer rides INSIDE the panel so it dies with it — a detached SceneTreeTimer
	# lambda would outlive a freed screen and log freed-capture errors across suites.
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = BUBBLE_SECONDS
	timer.autostart = true
	timer.timeout.connect(panel.queue_free)
	panel.add_child(timer)


## The nearest wired NPC within BARK_RANGE cells of the tamer (Chebyshev — "within 2
## cells" reads as the visible neighbourhood), or {} when the field is empty.
static func _npc_in_range(screen: Node) -> Dictionary:
	var npcs_value: Variant = screen.get("_npcs")
	if not (npcs_value is Array) or not screen.has_method("player_cell"):
		return {}
	var npcs: Array = npcs_value
	var player: Vector2i = screen.call("player_cell")
	var best: Dictionary = {}
	var best_d := BARK_RANGE + 1
	for npc: Dictionary in npcs:
		if bool(npc.get("sign", false)):
			continue  # props read, they don't mutter
		var cell: Vector2i = npc.get("cell", Vector2i.ZERO)
		var d := maxi(absi(cell.x - player.x), absi(cell.y - player.y))
		if d <= BARK_RANGE and d < best_d:
			best = npc
			best_d = d
	return best
