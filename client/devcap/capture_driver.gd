extends Node2D
## Dev-only screenshot driver (NOT shipped; devcap/ is a local harness). Boots a run, walks a
## few screens, saves viewport PNGs to the OUT dir, then quits. Run windowed (rendering needed).

const DEFAULT_OUT := (
	"C:/Users/arahi/AppData/Local/Temp/claude"
	+ "/c--Users-arahi-Documents-Claude-Projects-Mutants-Game"
	+ "/25f1769e-3108-40a6-aa8b-e78af8055c80/scratchpad/caps2"
)
const SHOTS: Array = [
	{"name": "main_menu", "scene": "res://presentation/screens/main_menu.tscn", "needs_run": false},
	{
		"name": "overworld",
		"scene": "res://presentation/overworld/overworld_screen.tscn",
		"needs_run": true
	},
	{"name": "party", "scene": "res://presentation/party/party_screen.tscn", "needs_run": true},
	{"name": "lab", "scene": "res://presentation/lab/lab_screen.tscn", "needs_run": true},
]


func _ready() -> void:
	# Yield once: _ready runs while the root is still assembling this capture scene, and adding
	# sibling scenes immediately trips Node's "parent is busy" guard in windowed builds.
	await get_tree().process_frame
	await _run()
	get_tree().quit()


func _run() -> void:
	var out := _output_dir()
	var mkdir_error := DirAccess.make_dir_recursive_absolute(out)
	if mkdir_error != OK:
		push_error("devcap: cannot create output directory '%s' (error %d)" % [out, mkdir_error])
		get_tree().quit(1)
		return
	var game := get_node_or_null("/root/GameController")
	for shot_v in SHOTS:
		var shot: Dictionary = shot_v
		if bool(shot["needs_run"]) and game != null and not bool(game.call("has_run")):
			game.call("new_run", 424242)
			var run: RunContext = game.call("run")
			# Captures exercise screen composition, not the once-per-run cold open. Without this flag,
			# Dialogic persists above every later screen and the harness photographs one dialogue box
			# five times instead of the actual UI.
			run.flags["intro_played"] = true
		var packed: PackedScene = load(str(shot["scene"]))
		if packed == null:
			continue
		var node := packed.instantiate()
		get_tree().root.add_child(node)
		for _i in 20:
			await get_tree().process_frame
		_clear_toasts()
		await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		var save_error := img.save_png(out.path_join(str(shot["name"]) + ".png"))
		if save_error != OK:
			push_error("devcap: failed to save '%s' (error %d)" % [shot["name"], save_error])
		node.queue_free()
		for _i in 3:
			await get_tree().process_frame
	await _capture_battle(game, out)


## Battle needs a staged pending_battle (mirrors the e2e test's shape), then a few player
## turns so damage numbers / HP glides / the transcript drawer are all live in the shot.
func _capture_battle(game: Node, out: String) -> void:
	if game == null:
		return
	if not bool(game.call("has_run")):
		game.call("new_run", 424242)
	var run: RunContext = game.call("run")
	run.flags["pending_battle"] = {
		"enemy_party": [{"species_id": "SB33"}, {"species_id": "SB14"}],
		"battle_seed": 99173,
		"is_wild": true,
		"region": "verdant_glut",
		"force": "Eros",
	}
	var packed: PackedScene = load("res://presentation/battle/battle_screen.tscn")
	var battle := packed.instantiate()
	get_tree().root.add_child(battle)
	for _i in 25:
		await get_tree().process_frame
	_clear_toasts()
	# Press the first action button (the player path) so a beat round plays for the shot.
	var menu := battle.find_child("ActionMenu", true, false)
	if menu != null:
		for child in menu.get_children():
			if child is Button:
				(child as Button).pressed.emit()
				break
	for _i in 40:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var save_error := img.save_png(out.path_join("battle.png"))
	if save_error != OK:
		push_error("devcap: failed to save battle.png (error %d)" % save_error)
	battle.queue_free()
	for _i in 3:
		await get_tree().process_frame


## Optional command-line override: `-- --devcap-out=C:/path/to/captures`.
## A portable user:// fallback replaces the old machine/session-specific scratch path.
func _output_dir() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--devcap-out="):
			var requested := arg.trim_prefix("--devcap-out=").strip_edges()
			if requested != "":
				return requested.replace("\\", "/").simplify_path()
	var legacy_parent := DEFAULT_OUT.get_base_dir()
	if DirAccess.dir_exists_absolute(legacy_parent):
		return DEFAULT_OUT
	return ProjectSettings.globalize_path("user://devcap")


func _clear_toasts() -> void:
	var toast := get_node_or_null("/root/Toast")
	if toast != null and toast.has_method("dismiss_all"):
		toast.call("dismiss_all")
