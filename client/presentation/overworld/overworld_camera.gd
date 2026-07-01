class_name OverworldCameraRig
extends RefCounted
## Camera rig for the overworld (extracted from overworld_screen to keep it under the
## lint line cap — the incremental-decomposition rule from the realization plan).
##
## Attaches a PhantomCamera2D following the player when the addon is available, else a
## plain Camera2D parented to the player. Both paths clamp the camera to the painted
## layout rect so the view never pans into raw void, and both honour the shared zoom.


## Build and attach the camera. `parent` is the overworld screen, `player` the token to
## follow, `world_rect` the painted layout rect in pixels (Rect2() disables limits).
static func setup(parent: Node, player: Node2D, world_rect: Rect2, zoom_factor: float) -> void:
	if player == null:
		return
	var zoom := Vector2(zoom_factor, zoom_factor)
	if ClassDB.class_exists("PhantomCameraHost") and ClassDB.class_exists("PhantomCamera2D"):
		var cam := Camera2D.new()
		cam.name = "OverworldCamera"
		cam.zoom = zoom
		_apply_camera_limits(cam, world_rect)
		parent.add_child(cam)
		cam.make_current()
		var host: Object = ClassDB.instantiate("PhantomCameraHost")
		if host is Node:
			cam.add_child(host as Node)
		var pcam: Object = ClassDB.instantiate("PhantomCamera2D")
		if pcam is Node2D:
			parent.add_child(pcam as Node2D)
			# follow_mode 1 == GLUED in PhantomCamera2D.FollowMode (glue to the target).
			pcam.set("follow_mode", 1)
			pcam.set("follow_target", player)
			pcam.set("zoom", zoom)  # keep the host from resetting the Camera2D zoom to 1x
			_apply_pcam_limits(pcam, world_rect)
		return
	# Fallback: plain Camera2D parented to the player so it tracks naturally — zoomed +
	# made current so the tiles fill the view and the region is framed around the player.
	var fallback := Camera2D.new()
	fallback.name = "OverworldCamera"
	fallback.zoom = zoom
	_apply_camera_limits(fallback, world_rect)
	player.add_child(fallback)
	fallback.make_current()


static func _apply_camera_limits(cam: Camera2D, rect: Rect2) -> void:
	if rect.size == Vector2.ZERO:
		return
	cam.limit_left = int(rect.position.x)
	cam.limit_top = int(rect.position.y)
	cam.limit_right = int(rect.end.x)
	cam.limit_bottom = int(rect.end.y)


## PhantomCamera2D carries its own limit properties (it drives the Camera2D host).
static func _apply_pcam_limits(pcam: Object, rect: Rect2) -> void:
	if rect.size == Vector2.ZERO:
		return
	pcam.set("limit_left", int(rect.position.x))
	pcam.set("limit_top", int(rect.position.y))
	pcam.set("limit_right", int(rect.end.x))
	pcam.set("limit_bottom", int(rect.end.y))
