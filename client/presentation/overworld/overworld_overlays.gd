class_name OverworldOverlays
extends RefCounted
## The overworld's MODAL OVERLAY kit — the camp/pause menu (Slice 3b/W17) and the E1b
## Threshold-network travel circle — extracted from overworld_screen to keep it under the lint
## line cap (the OverworldCameraRig incremental-decomposition rule). Both overlays follow the
## SAME W17 pattern: pushed through the UiRouter over the LIVE overworld (back = pop, never a
## scene swap), falling back to a local CanvasLayer child when the router autoload is absent.
##
## The screen keeps ownership of the live refs (_camp_overlay/_camp_menu/_threshold_screen) and
## the signal handlers; this kit owns the construction, the router/local push, the resume
## teardown, and the region-hop REBUILD (travel switched the run's active region — the overworld
## rebuilds in place through the existing build path, so per-region layouts rehydrate).
## Screen-private state is reached via get()/set()/call() (the OverworldBarks convention).

const InputActionsScript := preload("res://infrastructure/input/input_actions.gd")
const ThresholdScreenScript := preload("res://presentation/overworld/threshold_screen.gd")
const OverworldLoopStateScript := preload("res://presentation/overworld/overworld_loop_state.gd")
const OverworldTileSetKit := preload("res://presentation/overworld/overworld_tileset.gd")
const OverworldCameraKit := preload("res://presentation/overworld/overworld_camera.gd")

## Overlay CanvasLayer level: above gameplay, below Transition (100) + Toast (128).
const OVERLAY_LAYER := 50


## Build + push the camp menu over `screen`. Returns {"overlay": CanvasLayer, "menu": Node}
## ({} when the scene is missing). `on_resumed` is the screen's resume handler.
static func open_camp(screen: Node, camp_scene: PackedScene, on_resumed: Callable) -> Dictionary:
	if camp_scene == null:
		return {}
	var menu: Node = camp_scene.instantiate()
	var overlay: Node = null
	var router: Node = screen.get_node_or_null("/root/UiRouter")
	if router != null and router.has_method("push_node"):
		router.call("push_node", menu, "res://presentation/camp/camp_menu.tscn")
		overlay = menu.get_parent()  # the router's CanvasLayer
	else:
		var layer := CanvasLayer.new()
		layer.name = "CampOverlay"
		layer.layer = OVERLAY_LAYER
		layer.add_child(menu)
		screen.add_child(layer)
		overlay = layer
	# Resume clears the screen's refs; the router pop (or the legacy teardown) frees the overlay.
	if menu.has_signal("resumed"):
		menu.connect("resumed", on_resumed)
	return {"overlay": overlay, "menu": menu}


## The camp resumed: a router-pushed camp pops ITSELF (resume → UiRouter.pop_from restores the
## input context); only the legacy local overlay still needs freeing + the manual context restore.
static func resume_camp(screen: Node, overlay: Node, menu: Node, input: Node) -> void:
	var router: Node = screen.get_node_or_null("/root/UiRouter")
	if router != null and menu != null and bool(router.call("owns", menu)):
		return
	if overlay != null and is_instance_valid(overlay):
		overlay.queue_free()
	if input != null and input.has_method("switch_context"):
		input.call("switch_context", InputActionsScript.CTX_OVERWORLD)


## Build + push the Threshold travel circle (E1b — the ritual circle's page) over `screen`.
## Returns the live ThresholdScreen; the handlers are the screen's traveled/closed methods.
static func open_threshold(
	screen: Node, game: Node, on_traveled: Callable, on_closed: Callable
) -> Node:
	var page: ThresholdScreen = ThresholdScreenScript.new()
	page.set_game(game)
	page.traveled.connect(on_traveled)
	page.closed.connect(on_closed)
	var router: Node = screen.get_node_or_null("/root/UiRouter")
	if router != null and router.has_method("push_node"):
		router.call("push_node", page, "")
	else:
		var layer := CanvasLayer.new()
		layer.name = "ThresholdOverlay"
		layer.layer = OVERLAY_LAYER
		layer.add_child(page)
		screen.add_child(layer)
	return page


## A travel was ACCEPTED (the run's active region already switched): drop the stale position
## stash so the tamer lands at the NEW region's canonical spawn (a stale cross-region cell is
## often walkable in the next layout too), rebuild the overworld in place, and persist the hop
## through the witnessed save path.
static func after_travel(screen: Node, game: Node) -> void:
	OverworldLoopStateScript.clear_position_stash(screen.call("_run_ctx"))
	rebuild_for_travel(screen)
	if game != null and game.has_method("request_save"):
		game.call("request_save")
	elif game != null and game.has_method("save_run"):
		game.call("save_run")


## Rebuild the overworld IN PLACE for a region hop. The fresh-scene build path (battle return)
## never needed teardown; a travel rebuild first frees the two nodes build_from_game would
## otherwise duplicate — the camera rig and the HUD layer — then rebuilds everything from the
## run (new layout, force palette, horizon, structures, cast, pools).
static func rebuild_for_travel(screen: Node) -> void:
	OverworldCameraKit.teardown(screen.get("_cam_rig"), [screen, screen.get("_player")])
	screen.set("_cam_rig", null)
	var hud: Node = screen.get_node_or_null("HUD")
	if hud != null:
		screen.remove_child(hud)  # release the name NOW so the rebuilt layer is findable
		hud.queue_free()
	screen.set("_player_cell", Vector2i.ZERO)  # re-derived from the new region's spawn
	screen.call("build_from_game")
	# The lead cameo crossed the circle too: snap it beside the tamer instead of easing it
	# across the whole map from the old region's pixel coordinates.
	var lead: Variant = screen.get("_lead")
	if lead is Node2D and is_instance_valid(lead as Node2D):
		var centre: Vector2 = screen.call("_cell_center", screen.get("_player_cell"))
		var last_dir: Vector2i = screen.get("_last_dir")
		(lead as Node2D).position = (
			centre - Vector2(last_dir) * float(OverworldTileSetKit.TILE_SIZE)
		)
		screen.set("_lead_target", (lead as Node2D).position)
