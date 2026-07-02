extends RefCounted
## EndingGate (Batch E2b) — the overworld's FINALE hook, the slice_cleared pattern generalised:
## the overworld already re-checks run state on every quest transition; this glue watches for the
## finale flag (EndingsService.finale_reached — the e2-arc `succession_begins` seam or the
## ingested act-5 climax flag) and pushes the EndingScreen as a UiRouter overlay EXACTLY ONCE
## (the screen latches the resolved ending id into run.flags; a latched ledger never re-fires).
##
## PRESENTATION glue, all STATIC and duck-typed against the calling screen (the CaptureMoment /
## OverworldChoices pattern) — the overworld pays two lines for the whole surface.

const EndingScreenScript := preload("res://presentation/endings/ending_screen.gd")
const ENDING_SCREEN_PATH := "res://presentation/endings/ending_screen.tscn"


## True when the finale flag has landed and no ending is latched yet — the record must close.
static func should_fire(game: Node) -> bool:
	if game == null or not game.has_method("run"):
		return false
	var run: RunContext = game.call("run")
	if run == null:
		return false
	return EndingsService.finale_reached(run) and EndingsService.recorded_ending(run) == ""


## Push the EndingScreen over `screen` when the finale is due. Returns the pushed screen (it has
## already begun: ending resolved + latched), or null when the gate holds (no finale / already
## recorded / no router — never a crash; the next quest transition re-checks).
static func maybe_push(screen: Node, game: Node) -> Node:
	if screen == null or not screen.is_inside_tree() or not should_fire(game):
		return null
	var router := screen.get_node_or_null("/root/UiRouter")
	if router == null or not router.has_method("push_node"):
		return null
	var page: Control = EndingScreenScript.new()
	page.name = "EndingScreen"
	page.call("set_game", game)
	router.call("push_node", page, ENDING_SCREEN_PATH)
	page.call("begin")
	return page
