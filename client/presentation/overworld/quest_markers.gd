class_name QuestMarkers
extends RefCounted
## QuestMarkers (W-DRESS) — floating brass quest markers over the overworld cast, driven from
## the LIVE QuestService state (the same defs/dispatch the screen's _advance_quest_for walks):
##   * a small pulsing brass SIGIL-STAR (~14px, bobbing 2px) over an NPC whose step can
##     advance RIGHT NOW (start-able quest / the active quest's current step);
##   * a hollow brass RING over a quest-COMPLETION target (the step that finishes the quest);
##   * a subtle EMBER glow on the boss-lair structure while the boss-goal quest is the active
##     objective — the run's goal has a visible destination.
## Refreshed on build + every quest transition, NEVER during dialogue (the screen defers to
## dialogue-finished). Static under reduce_motion / headless. Pure presentation — markers read
## quest state, they never write it. LOCAL drawing only; colours via GrimoirePalette.

const KIND_NONE := ""
const KIND_AVAILABLE := "available"
const KIND_TURNIN := "turnin"

const MARKER_PX := 14
const BOB_PX := 2.0
const NODE_NAME := "QuestMarker"
const LAIR_NODE_NAME := "LairEmber"

static var _texture_cache: Dictionary = {}


static func clear_runtime_cache() -> void:
	_texture_cache.clear()


# === state -> marker kind (pure; unit-tested directly) ======================================== #


## The marker an NPC entry earns from the live quest state: KIND_TURNIN when the step it
## drives would COMPLETE its quest right now, KIND_AVAILABLE when that step can start/advance
## right now, else KIND_NONE. Reads the same def fields the screen's dispatch does (step_key
## values + the W16a "choice" config), so the marker and the talk can never disagree.
static func kind_for(npc: Dictionary, quests: QuestService) -> String:
	if quests == null or bool(npc.get("sign", false)):
		return KIND_NONE
	var best := KIND_NONE
	for pair: Array in _steps_driven(npc):
		var qdef: Dictionary = pair[0]
		var step_id: String = pair[1]
		var kind := _kind_for_step(qdef, step_id, quests)
		if kind == KIND_TURNIN:
			return KIND_TURNIN
		if kind == KIND_AVAILABLE:
			best = KIND_AVAILABLE
	return best


## Every (quest def, step id) pair this NPC drives: its step_key values plus its choice config.
static func _steps_driven(npc: Dictionary) -> Array:
	var out: Array = []
	for q: Dictionary in OverworldContent.quest_defs():
		var step_key := str(q.get("step_key", ""))
		if step_key != "" and str(npc.get(step_key, "")) != "":
			out.append([q, str(npc.get(step_key, ""))])
	var choice: Dictionary = npc.get("choice", {})
	if not choice.is_empty():
		var qdef := OverworldQuestsGlue.quest_def_by_id(str(choice.get("quest", "")))
		if not qdef.is_empty():
			out.append([qdef, str(choice.get("step", ""))])
	return out


static func _kind_for_step(qdef: Dictionary, step_id: String, quests: QuestService) -> String:
	var qid := str(qdef.get("id", ""))
	var steps: Array = qdef.get("steps", [])
	var index := _index_of(steps, step_id)
	if index < 0 or quests.is_done(qid):
		return KIND_NONE
	if quests.is_active(qid):
		var cursor := int((quests.state().get(qid, {}) as Dictionary).get("step_cursor", 0))
		if cursor != index:
			return KIND_NONE
	else:
		# Inactive: the first talk starts it — but only the FIRST step then advances, and a
		# data trigger (Act-0 gating flags) must already be met.
		if index != 0 or not _trigger_ok(qdef, quests):
			return KIND_NONE
	return KIND_TURNIN if index == steps.size() - 1 else KIND_AVAILABLE


static func _index_of(steps: Array, step_id: String) -> int:
	for i in steps.size():
		if str((steps[i] as Dictionary).get("id", "")) == step_id:
			return i
	return -1


## The data trigger predicate quest starts honour (the content ships flag triggers only).
static func _trigger_ok(qdef: Dictionary, quests: QuestService) -> bool:
	var trigger: Dictionary = qdef.get("trigger", {})
	if trigger.is_empty():
		return true
	if trigger.has("flag"):
		return quests.run_state().flag(str(trigger["flag"]))
	return false


# === node refresh (idempotent; the screen calls it outside dialogue) =========================== #


## Sync every NPC's floating marker to the live quest state. `npcs` are the screen's live
## entries ({name, node, ...def keys}). Creates/retunes/frees the ~14px marker sprite riding
## above each figure; bob+pulse only where animation is allowed.
static func refresh(npcs: Array, quests: QuestService) -> void:
	for npc: Dictionary in npcs:
		var node: Node2D = npc.get("node")
		if node == null or not is_instance_valid(node):
			continue
		var kind := kind_for(npc, quests)
		var marker := node.get_node_or_null(NODE_NAME) as Sprite2D
		if kind == KIND_NONE:
			if marker != null:
				node.remove_child(marker)
				marker.queue_free()
			continue
		if marker != null and str(marker.get_meta("kind", "")) == kind:
			continue
		if marker != null:
			node.remove_child(marker)
			marker.queue_free()
		marker = _make_marker(kind, _hover_height(node))
		node.add_child(marker)
		animate(marker)


## The lair EMBER glow: present on the boss-lair structure while the boss-goal quest is live,
## gone once it is done. Idempotent; `lair` is the OverworldStructures plan entry ({} = no-op).
static func refresh_lair(lair: Dictionary, quests: QuestService) -> void:
	if lair.is_empty() or quests == null:
		return
	var node: Node2D = lair.get("node")
	if node == null or not is_instance_valid(node):
		return
	var qid := str(OverworldContent.BOSS_QUEST["id"])
	var want := quests.is_active(qid) and not quests.is_done(qid)
	var glow := node.get_node_or_null(LAIR_NODE_NAME) as Sprite2D
	if not want:
		if glow != null:
			node.remove_child(glow)
			glow.queue_free()
		return
	if glow != null:
		return
	glow = Sprite2D.new()
	glow.name = LAIR_NODE_NAME
	glow.texture = _ember_texture()
	glow.show_behind_parent = true  # the ground glow never covers the altar's painted face
	glow.modulate = Color(1, 1, 1, 0.55)
	if _can_animate(node):
		var tween := glow.create_tween().set_loops()
		tween.tween_property(glow, "modulate:a", 0.75, 1.2).set_trans(Tween.TRANS_SINE)
		tween.tween_property(glow, "modulate:a", 0.4, 1.2).set_trans(Tween.TRANS_SINE)
	node.add_child(glow)


static func _hover_height(node: Node2D) -> float:
	var token := node.get_child(0) as Sprite2D if node.get_child_count() > 0 else null
	if token == null or token.texture == null:
		return -54.0
	return token.offset.y - token.texture.get_height() * 0.5 * token.scale.y - 10.0


static func _make_marker(kind: String, hover_y: float) -> Sprite2D:
	var marker := Sprite2D.new()
	marker.name = NODE_NAME
	marker.set_meta("kind", kind)
	marker.texture = _star_texture() if kind == KIND_AVAILABLE else _ring_texture()
	marker.position = Vector2(0, hover_y)
	return marker


## Attach the bob+pulse once the marker is IN the tree (tweens need it); static otherwise —
## reduce_motion players and headless suites get a fixed marker.
static func animate(marker: Sprite2D) -> void:
	if marker == null or not _can_animate(marker):
		return
	var base_y := marker.position.y
	var tween := marker.create_tween().set_loops()
	tween.set_parallel(false)
	var up := tween.tween_property(marker, "position:y", base_y - BOB_PX, 0.7)
	up.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var down := tween.tween_property(marker, "position:y", base_y + BOB_PX, 0.7)
	down.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var pulse := marker.create_tween().set_loops()
	pulse.tween_property(marker, "modulate:a", 1.0, 0.7)
	pulse.tween_property(marker, "modulate:a", 0.62, 0.7)


# === marker textures (deterministic set_pixel builders, cached) ================================ #


## The AVAILABLE marker: a small filled brass sigil-star (the tamer crest's four long rays).
static func _star_texture() -> ImageTexture:
	var hit: Variant = _texture_cache.get("star")
	if hit is ImageTexture:
		return hit
	var d := MARKER_PX
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := (d - 1) * 0.5
	for y in d:
		for x in d:
			var v := Vector2(x - c, y - c)
			var dist := v.length()
			if dist > c:
				continue
			var ang := fposmod(v.angle(), PI / 2.0)
			var delta := minf(ang, PI / 2.0 - ang)
			var width := 0.30 * (1.0 - dist / c) + 0.04
			if dist <= c * 0.95 and delta < width:
				img.set_pixel(
					x, y, GrimoirePalette.BRASS_BRIGHT if dist < c * 0.7 else GrimoirePalette.BRASS
				)
			elif dist <= c * 0.22:
				img.set_pixel(x, y, GrimoirePalette.BRASS_BRIGHT)
	var tex := ImageTexture.create_from_image(img)
	_texture_cache["star"] = tex
	return tex


## The COMPLETION marker: a hollow brass ring (the seal waiting to be closed).
static func _ring_texture() -> ImageTexture:
	var hit: Variant = _texture_cache.get("ring")
	if hit is ImageTexture:
		return hit
	var d := MARKER_PX
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := (d - 1) * 0.5
	for y in d:
		for x in d:
			var dist := Vector2(x - c, y - c).length()
			if dist <= c * 0.95 and dist >= c * 0.58:
				img.set_pixel(
					x,
					y,
					GrimoirePalette.BRASS_BRIGHT if dist >= c * 0.75 else GrimoirePalette.BRASS
				)
	var tex := ImageTexture.create_from_image(img)
	_texture_cache["ring"] = tex
	return tex


## The lair ember: a soft radial EMBER glow (GrimoirePalette.EMBER) behind the altar's base.
static func _ember_texture() -> Texture2D:
	var hit: Variant = _texture_cache.get("ember")
	if hit is Texture2D:
		return hit
	var grad := Gradient.new()
	var core := GrimoirePalette.EMBER.lightened(0.2)
	grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	grad.colors = PackedColorArray(
		[Color(core, 0.6), Color(GrimoirePalette.EMBER, 0.28), Color(core, 0.0)]
	)
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 160
	tex.height = 160
	_texture_cache["ember"] = tex
	return tex


static func _can_animate(node: Node) -> bool:
	if node == null or not node.is_inside_tree():
		return false
	if DisplayServer.get_name() == "headless":
		return false
	return not OverworldMotion.reduce_motion()
