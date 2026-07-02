extends Node2D
## TEMP punchlist-verify driver (critic sweep) — DELETE AFTER USE. Boots a run, walks the
## overworld intro / battle / party / lab, saves PNGs + [VERIFY] log lines for the critic.

const OUT := (
	"C:/Users/arahi/AppData/Local/Temp/claude"
	+ "/c--Users-arahi-Documents-Claude-Projects-Mutants-Game"
	+ "/25f1769e-3108-40a6-aa8b-e78af8055c80/scratchpad/verify_caps"
)


func _ready() -> void:
	await _run()
	get_tree().quit()


func _p(msg: String) -> void:
	print("[VERIFY] " + msg)


func _snap(shot_name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT + "/" + shot_name + ".png")
	_p("snap " + shot_name)


func _wait(frames: int) -> void:
	for _i in frames:
		await get_tree().process_frame


func _key(code: int, down: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code as Key
	ev.physical_keycode = code as Key
	ev.pressed = down
	Input.parse_input_event(ev)


func _run() -> void:
	await get_tree().process_frame  # let root finish setting up children before we add siblings
	DirAccess.make_dir_recursive_absolute(OUT)
	var game := get_node_or_null("/root/GameController")
	if game == null:
		_p("FATAL no GameController")
		return
	game.call("new_run", 424242)
	await _overworld_pass()
	await _party_pass()
	await _lab_pass()
	await _battle_pass(game)
	_p("ALL DONE")


func _overworld_pass() -> void:
	var packed: PackedScene = load("res://presentation/overworld/overworld_screen.tscn")
	var ow := packed.instantiate()
	get_tree().root.add_child(ow)
	await _wait(6)
	_snap("ow_intro_early")
	_p("in_dialogue early=" + str(ow.get("_in_dialogue")))
	await _wait(54)
	_snap("ow_intro_mid")
	_p("in_dialogue mid=" + str(ow.get("_in_dialogue")))
	# Held-CONFIRM test: hold SPACE 90 frames, watch whether the scene fast-forwards.
	_key(KEY_SPACE, true)
	await _wait(30)
	_snap("ow_intro_hold30")
	_p("in_dialogue hold30=" + str(ow.get("_in_dialogue")))
	await _wait(60)
	_key(KEY_SPACE, false)
	_snap("ow_intro_hold90")
	_p("in_dialogue hold90=" + str(ow.get("_in_dialogue")))
	await _wait(10)
	# Mash test: discrete press/release pairs until the scene ends (max 40).
	var mash := 0
	while bool(ow.get("_in_dialogue")) and mash < 40:
		_key(KEY_SPACE, true)
		await _wait(3)
		_key(KEY_SPACE, false)
		await _wait(6)
		mash += 1
	_p("mash_count=" + str(mash) + " in_dialogue=" + str(ow.get("_in_dialogue")))
	await _wait(20)
	_snap("ow_after_intro")
	# Movement-focus test: hold move_right ~0.5s; the cell should change if focus returned.
	var cell0: Vector2i = ow.get("_player_cell")
	Input.action_press("move_right")
	await _wait(40)
	Input.action_release("move_right")
	await _wait(10)
	var cell1: Vector2i = ow.get("_player_cell")
	_p("move_test from=%s to=%s" % [str(cell0), str(cell1)])
	_snap("ow_after_move")
	# Cast log: cells / sign / markers (items 9, 10, 12).
	var npcs: Array = ow.get("_npcs")
	for npc_v in npcs:
		var d: Dictionary = npc_v
		var node: Node2D = d.get("node")
		var marker := "none"
		if node != null and is_instance_valid(node):
			var m := node.get_node_or_null("QuestMarker")
			if m != null:
				marker = str(m.get_meta("kind", "?"))
		_p(
			"npc name=%s cell=%s sign=%s marker=%s"
			% [str(d.get("name", "")), str(d.get("cell", Vector2i.ZERO)), str(d.get("sign", false)), marker]
		)
	_p("player cell=" + str(ow.get("_player_cell")) + " home=" + str(ow.get("_home_cell")))
	# Wide shot: zoom the rig out so the spawn neighbourhood (signpost/props/cast) is visible.
	var rig: Object = ow.get("_cam_rig")
	if rig != null:
		rig.set("zoom", Vector2(0.9, 0.9))
	var cam := get_viewport().get_camera_2d()
	if cam != null:
		cam.zoom = Vector2(0.9, 0.9)
	await _wait(30)
	_snap("ow_wide")
	ow.queue_free()
	await _wait(10)


func _party_pass() -> void:
	var packed: PackedScene = load("res://presentation/party/party_screen.tscn")
	var node := packed.instantiate()
	get_tree().root.add_child(node)
	await _wait(30)
	_snap("party")
	node.queue_free()
	await _wait(10)


func _lab_pass() -> void:
	var packed: PackedScene = load("res://presentation/lab/lab_screen.tscn")
	var lab := packed.instantiate()
	get_tree().root.add_child(lab)
	await _wait(25)
	lab.call("set_creature_a", 0)
	lab.call("set_creature_b", 1)
	await _wait(10)
	var verdict: Dictionary = lab.call("preview")
	_p("lab verdict=" + str(verdict.get("verdict", "none")))
	await _wait(15)
	_snap("lab_verdict")
	var result: Dictionary = lab.call("commit")
	_p("lab commit ok=" + str(not result.is_empty()))
	await _wait(70)
	_snap("lab_commit_mid")
	await _wait(180)
	_snap("lab_commit")
	lab.queue_free()
	await _wait(10)


func _battle_pass(game: Node) -> void:
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
	await _wait(30)
	_snap("battle_open")
	var menu := battle.find_child("ActionMenu", true, false)
	if menu != null:
		for child in menu.get_children():
			if child is Button:
				(child as Button).pressed.emit()
				break
	await _wait(45)
	_snap("battle_beat")
	await _wait(60)
	_snap("battle_settled")
	# No queue_free (devcap convention) — process exit tears down; exit code observed outside.
