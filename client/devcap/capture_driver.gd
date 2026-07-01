extends Node2D
## Dev-only screenshot driver (NOT shipped; devcap/ is a local harness). Boots a run, walks a
## few screens, saves viewport PNGs to the OUT dir, then quits. Run windowed (rendering needed).

const OUT := "C:/Users/arahi/AppData/Local/Temp/claude/c--Users-arahi-Documents-Claude-Projects-Mutants-Game/25f1769e-3108-40a6-aa8b-e78af8055c80/scratchpad/caps2"
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
	await _capture_battle(game)


## Battle needs a staged pending_battle (mirrors the e2e test's shape), then a few player
## turns so damage numbers / HP glides / the transcript drawer are all live in the shot.
func _capture_battle(game: Node) -> void:
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
	img.save_png(OUT + "/battle.png")
	# No queue_free here: beats may still be tweening — the process exit tears down.
