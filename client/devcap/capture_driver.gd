extends Node2D
## Dev-only screenshot driver (NOT shipped; devcap/ is a local harness). Boots a run, walks a
## few screens, saves viewport PNGs to the OUT dir, then quits. Run windowed (rendering needed).

const OUT := "C:/Users/arahi/AppData/Local/Temp/claude/c--Users-arahi-Documents-Claude-Projects-Mutants-Game/25f1769e-3108-40a6-aa8b-e78af8055c80/scratchpad/caps2"
const SHOTS: Array = [
	{"name": "main_menu", "scene": "res://presentation/screens/main_menu.tscn", "needs_run": false},
	{"name": "overworld", "scene": "res://presentation/overworld/overworld_screen.tscn", "needs_run": true},
	{"name": "party", "scene": "res://presentation/party/party_screen.tscn", "needs_run": true},
	{"name": "lab", "scene": "res://presentation/lab/lab_screen.tscn", "needs_run": true},
]


func _ready() -> void:
	await _run()
	get_tree().quit()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var game := get_node_or_null("/root/GameController")
	for shot_v in SHOTS:
		var shot: Dictionary = shot_v
		if bool(shot["needs_run"]) and game != null and not bool(game.call("has_run")):
			game.call("new_run", 424242)
		var packed: PackedScene = load(str(shot["scene"]))
		if packed == null:
			continue
		var node := packed.instantiate()
		get_tree().root.add_child(node)
		for _i in 20:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png(OUT + "/" + str(shot["name"]) + ".png")
		node.queue_free()
		for _i in 3:
			await get_tree().process_frame
