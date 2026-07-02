extends Node
## UiRouter (Wave 17) — the SCREEN ROUTER autoload: push/pop CanvasLayer overlays over the
## PERSISTENT current scene, generalising the camp-overlay pattern (overworld_screen.open_camp).
##
## PRESENTATION layer. Camp / Party / Journal / Character / the Trader / the Dossier are PUSHED
## overlays: the overworld (or battle) underneath is never swapped away, so "back" can never land
## on a black screen — pop() only ever removes an overlay, it never touches current_scene. The Lab
## stays a full-screen scene swap (Geneticist veto) and never routes through here.
##
## CONTRACT (W17):
##   * push_scene(path) instantiates the scene inside a fresh CanvasLayer child of this autoload
##     (autoloads sit beside current_scene under /root, so the layer draws OVER the live scene);
##   * each push RECORDS the InputService context active at push time; pop() RESTORES it — so
##     closing the last overlay hands input back to the overworld context exactly;
##   * Esc/back pops EXACTLY one level: screens ask is_top(self) before acting, so a buried camp
##     never reacts to the same CANCEL edge that popped the party page above it;
##   * a layer freed externally (its owner screen died) self-heals out of the stack.
##
## Layers ride 50..(<100) — above gameplay, below Transition (100) and Toast (128).

const InputActions := preload("res://infrastructure/input/input_actions.gd")

const BASE_LAYER := 50

## The overlay stack, bottom -> top. Each entry:
##   { "layer": CanvasLayer, "scene": Node, "path": String, "restore_ctx": String }
var _stack: Array = []

# === push / pop =============================================================================== #


## Instantiate `scene_path` and push it as the top overlay. Returns the scene's root node, or null
## when the path does not resolve (the caller falls back to its legacy navigation — never a crash).
func push_scene(scene_path: String) -> Node:
	if not ResourceLoader.exists(scene_path):
		push_warning("UiRouter.push_scene: missing scene '%s'" % scene_path)
		return null
	var packed: PackedScene = load(scene_path)
	if packed == null:
		return null
	return push_node(packed.instantiate(), scene_path)


## Push an already-built screen node as the top overlay (the code-built path). The screen's own
## _ready switches the InputService context (every menu screen already does); this records the
## PREVIOUS context so pop() can restore it. Returns the pushed node.
func push_node(scene: Node, scene_path: String = "") -> Node:
	if scene == null:
		return null
	# Capture the context BEFORE the scene enters the tree — its _ready switches to its own.
	var restore_ctx := _current_context()
	var layer := CanvasLayer.new()
	layer.name = "RouterOverlay%d" % _stack.size()
	layer.layer = BASE_LAYER + _stack.size()
	_stack.append({"layer": layer, "scene": scene, "path": scene_path, "restore_ctx": restore_ctx})
	# Self-heal: an overlay freed from outside (its owner died) must not corrupt the stack. The
	# handler is idempotent (pop() removes the entry first), so no disconnect bookkeeping is needed.
	layer.tree_exiting.connect(_on_layer_gone.bind(layer))
	layer.add_child(scene)
	add_child(layer)
	return scene


## Pop the TOP overlay: free its layer and restore the InputService context recorded at push time.
## Returns true when an overlay was popped; false on an empty stack (a no-op — never an error, so
## a stray back-press at the root can never unmake the world).
func pop() -> bool:
	if _stack.is_empty():
		return false
	var entry: Dictionary = _stack.pop_back()
	_restore_context(str(entry["restore_ctx"]))
	var layer := entry["layer"] as CanvasLayer
	if layer != null and is_instance_valid(layer):
		layer.queue_free()  # its tree_exiting self-heal finds no entry left — a no-op
	return true


## Pop every overlay (a full unwind — e.g. before the Lab's full-screen scene swap). Restores the
## BOTTOM entry's recorded context (the state before the first push).
func pop_all() -> void:
	var base_ctx := ""
	if not _stack.is_empty():
		base_ctx = str((_stack[0] as Dictionary)["restore_ctx"])
	while not _stack.is_empty():
		var entry: Dictionary = _stack.pop_back()
		var layer := entry["layer"] as CanvasLayer
		if layer != null and is_instance_valid(layer):
			layer.queue_free()
	if base_ctx != "":
		_restore_context(base_ctx)


# === reads (screens + tests) ================================================================== #


## How many overlays are currently pushed.
func depth() -> int:
	return _stack.size()


## The TOP overlay's screen node, or null when nothing is pushed.
func top_scene() -> Node:
	if _stack.is_empty():
		return null
	return (_stack.back() as Dictionary)["scene"] as Node


## True when `node` lives inside ANY pushed overlay (it is router-owned; its back verb should pop
## instead of scene-swapping).
func owns(node: Node) -> bool:
	return _entry_index_of(node) != -1


## True when `node` lives inside the TOP overlay — the only screen whose CANCEL may pop. A buried
## screen sees the same input edge the same frame; this is the "exactly one level" guard.
func is_top(node: Node) -> bool:
	var idx := _entry_index_of(node)
	return idx != -1 and idx == _stack.size() - 1


## One call for a screen's back verb: pop when `node` is the TOP overlay; SWALLOW (return true,
## do nothing) when it is buried; return false when the router does not own it at all (the caller
## then falls back to its legacy navigation).
func pop_from(node: Node) -> bool:
	var idx := _entry_index_of(node)
	if idx == -1:
		return false
	if idx == _stack.size() - 1:
		pop()
	return true


# === internals ================================================================================ #


func _entry_index_of(node: Node) -> int:
	if node == null:
		return -1
	for i in _stack.size():
		var scene := (_stack[i] as Dictionary)["scene"] as Node
		if scene == null or not is_instance_valid(scene):
			continue
		if scene == node or scene.is_ancestor_of(node):
			return i
	return -1


## A pushed layer left the tree WITHOUT pop() (its owner freed it). Drop its entry; if it was the
## top, restore its recorded context so input truth survives external teardown.
func _on_layer_gone(layer: CanvasLayer) -> void:
	for i in _stack.size():
		if (_stack[i] as Dictionary)["layer"] == layer:
			var was_top := i == _stack.size() - 1
			var ctx := str((_stack[i] as Dictionary)["restore_ctx"])
			_stack.remove_at(i)
			if was_top:
				_restore_context(ctx)
			return


func _current_context() -> String:
	var input := get_node_or_null("/root/InputService")
	if input != null and input.has_method("current_context"):
		return str(input.call("current_context"))
	return InputActions.CTX_MENU


func _restore_context(ctx: String) -> void:
	if ctx == "":
		return
	var input := get_node_or_null("/root/InputService")
	if input != null and input.has_method("switch_context"):
		input.call("switch_context", ctx)
