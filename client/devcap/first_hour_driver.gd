extends Node2D
## TEMP first-hour critic capture driver — NOT shipped, DELETED after the critique pass.
## Plays a fresh run like a new player (menu -> new run -> intro -> walk -> first battle with
## capture flow -> camp/party/dossier -> lab preview+commit -> journal/graveyard -> character
## sheet), saving viewport PNGs at every beat. Run WINDOWED (rendering needed).

const OUT := (
	"C:/Users/arahi/AppData/Local/Temp/claude"
	+ "/c--Users-arahi-Documents-Claude-Projects-Mutants-Game"
	+ "/25f1769e-3108-40a6-aa8b-e78af8055c80/scratchpad/final_caps/first_hour"
)
const RUN_SEED := 20260701

var _game: Node = null
var _shot_idx := 0
var _saw_target_picker := false


func _ready() -> void:
	await _run()
	print("[CAP] DONE")
	get_tree().quit()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_game = get_node_or_null("/root/GameController")
	await _wait(15)
	await _stage_main_menu()
	await _stage_overworld_intro_walk()
	await _stage_battle()
	await _stage_camp()
	await _stage_party_dossier()
	await _stage_lab()
	await _stage_journal()
	await _stage_character()


func _wait(frames: int) -> void:
	for _i in frames:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await _wait(2)
	var img := get_viewport().get_texture().get_image()
	_shot_idx += 1
	var file := "%s/%02d_%s.png" % [OUT, _shot_idx, shot_name]
	img.save_png(file)
	print("[CAP] shot ", file)


# === 1. main menu ============================================================================= #


func _stage_main_menu() -> void:
	var packed: PackedScene = load("res://presentation/screens/main_menu.tscn")
	var menu: Node = packed.instantiate()
	get_tree().root.add_child(menu)
	await _wait(50)
	await _shot("main_menu")
	menu.queue_free()
	await _wait(4)


# === 2. new run -> intro -> walk ============================================================== #


func _stage_overworld_intro_walk() -> void:
	if _game != null:
		_game.call("new_run", RUN_SEED)
	var packed: PackedScene = load("res://presentation/overworld/overworld_screen.tscn")
	var ow: Node = packed.instantiate()
	ow.call("set_auto_hand_off", false)
	get_tree().root.add_child(ow)
	await _wait(45)
	await _shot("intro_knack_1")
	for i in 3:
		_dlg_advance()
		await _wait(32)
		await _shot("intro_knack_%d" % (i + 2))
	var guard := 0
	while _dlg_active() and guard < 40:
		_dlg_advance()
		await _wait(14)
		guard += 1
	if _dlg_active():
		var dlg := get_node_or_null("/root/Dialogic")
		if dlg != null:
			dlg.call("end_timeline")
	await _wait(35)
	await _shot("overworld_first_view")
	# --- the walk: seeded wander, shot every 10 steps, stop on the first battle encounter ---
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var dirs: Array = [
		Vector2i.RIGHT, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP
	]
	var steps := 0
	var battle_found := false
	while steps < 200 and not battle_found:
		var roll: Dictionary = {}
		var moved := false
		var first: Vector2i = dirs[rng.randi_range(0, dirs.size() - 1)]
		var attempts: Array = [first, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
		for d: Vector2i in attempts:
			roll = ow.call("try_move", d)
			if bool(roll.get("moved", false)):
				moved = true
				break
		if not moved:
			print("[CAP] walk stuck at step ", steps)
			break
		steps += 1
		await _wait(7)
		if steps % 10 == 0:
			await _shot("walk_step_%03d" % steps)
		if bool(roll.get("boss", false)):
			print("[CAP] BOSS fired at step ", steps)
			await _wait(6)
			await _shot("boss_ambush_trigger")
			battle_found = true
		elif bool(roll.get("encounter", false)):
			if str(roll.get("kind", "")) == "peculiar":
				print("[CAP] peculiar at step ", steps)
				await _wait(30)
				await _shot("peculiar_step_%03d" % steps)
			else:
				print("[CAP] wild battle at step ", steps, " roll=", roll)
				await _wait(6)
				await _shot("encounter_trigger")
				battle_found = true
	print("[CAP] walked ", steps, " steps; battle_found=", battle_found)
	ow.queue_free()
	await _wait(6)


func _dlg_active() -> bool:
	var dlg := get_node_or_null("/root/Dialogic")
	return dlg != null and dlg.get("current_timeline") != null


func _dlg_advance() -> void:
	var dlg := get_node_or_null("/root/Dialogic")
	if dlg == null:
		return
	var inputs: Variant = dlg.get("Inputs")
	if inputs != null:
		inputs.call("handle_input")


# === 3. the first battle (beats, capture attempt, result card) ================================ #


func _stage_battle() -> void:
	if _game == null or not bool(_game.call("has_run")):
		return
	var run: Variant = _game.call("run")
	var pending: Dictionary = run.flags.get("pending_battle", {})
	if bool(pending.get("is_boss", false)):
		await _boss_preview()
		pending = {}
	if pending.is_empty() and not run.flags.has("pending_battle"):
		run.flags["pending_battle"] = {
			"enemy_party": [{"species_id": "SB33"}],
			"battle_seed": 99173,
			"is_wild": true,
			"region": "verdant_glut",
			"force": "Eros",
		}
		print("[CAP] staged fallback wild battle")
	await _drive_wild_battle()


## A boss fired before any wild fight: capture its splash + opening, then leave WITHOUT
## resolving (no result applied — the run survives for the rest of the pass).
func _boss_preview() -> void:
	var packed: PackedScene = load("res://presentation/battle/battle_screen.tscn")
	var battle: Node = packed.instantiate()
	get_tree().root.add_child(battle)
	await _wait(20)
	await _shot("boss_splash")
	await _wait(70)
	await _shot("boss_battle_open")
	battle.queue_free()
	await _wait(6)


func _drive_wild_battle() -> void:
	var packed: PackedScene = load("res://presentation/battle/battle_screen.tscn")
	var battle: Node = packed.instantiate()
	get_tree().root.add_child(battle)
	await _wait(55)
	await _shot("battle_open")
	var acted := false
	var captures := 0
	var guard := 0
	while guard < 30:
		guard += 1
		await _await_idle(battle)
		if not is_instance_valid(battle):
			return
		var step: Dictionary = battle.call("last_step")
		if str(step.get("kind", "")) == "ended":
			break
		if not acted:
			acted = true
			await _press_attack(battle)
			continue
		captures += 1
		if captures > 5:
			print("[CAP] capture never landed — fleeing")
			battle.call("player_flee")
			await _wait(25)
			await _shot("battle_fled")
			break
		await _press_capture(battle, captures)
	await _wait(30)
	print("[CAP] battle result: ", battle.call("result"))
	var readout: Dictionary = battle.call("capture_readout")
	print("[CAP] capture phases: ", readout.get("phases"))
	var card: Variant = readout.get("card")
	if card != null and is_instance_valid(card):
		await _shot("capture_result_card")
		card.call("advance")
		await _wait(25)
		await _shot("capture_result_card_revealed")
		card.call("advance")
		await _wait(25)
	await _shot("battle_aftermath")
	battle.queue_free()
	await _wait(6)


func _await_idle(battle: Node) -> void:
	var guard := 0
	while guard < 1500:
		guard += 1
		if not is_instance_valid(battle):
			return
		var playing := bool(battle.get("_beats_playing"))
		var kind := str((battle.call("last_step") as Dictionary).get("kind", ""))
		if not playing and (kind == "await_player" or kind == "ended"):
			return
		await get_tree().process_frame


func _press_attack(battle: Node) -> void:
	await _shot("action_menu")
	var menu: Node = battle.find_child("ActionMenu", true, false)
	var pressed := false
	if menu != null:
		for child in menu.get_children():
			if child is Button and not (child.name in ["CaptureButton", "FleeButton"]):
				(child as Button).pressed.emit()
				pressed = true
				break
	if not pressed:
		battle.call("player_pass")
		return
	await _wait(4)
	var picker: Node = battle.find_child("TargetPicker", true, false)
	if picker != null and picker is Control and (picker as Control).visible:
		if not _saw_target_picker:
			_saw_target_picker = true
			await _shot("target_picker")
		for child in picker.get_children():
			if child is Button:
				(child as Button).pressed.emit()
				break
	await _wait(14)
	await _shot("beat_mid")
	await _await_idle(battle)
	await _shot("round_settled")


func _press_capture(battle: Node, attempt: int) -> void:
	var readout: Dictionary = battle.call("capture_readout")
	print("[CAP] capture attempt ", attempt, " chance=", readout.get("chance"))
	if attempt == 1:
		await _shot("action_menu_capture_odds")
	var menu: Node = battle.find_child("ActionMenu", true, false)
	var btn: Node = null
	if menu != null:
		btn = menu.find_child("CaptureButton", true, false)
	if btn is Button:
		(btn as Button).pressed.emit()
	else:
		battle.call("player_capture")
	await _wait(22)
	await _shot("capture_attempt_%d_mid" % attempt)
	await _await_idle(battle)
	await _shot("capture_attempt_%d_after" % attempt)


# === 4. camp ================================================================================== #


func _stage_camp() -> void:
	var packed: PackedScene = load("res://presentation/overworld/overworld_screen.tscn")
	var ow: Node = packed.instantiate()
	ow.call("set_auto_hand_off", false)
	get_tree().root.add_child(ow)
	await _wait(35)
	await _shot("overworld_post_battle")
	ow.call("open_camp")
	await _wait(28)
	await _shot("camp_menu")
	ow.queue_free()
	await _wait(6)


# === 5. party + dossier ======================================================================= #


func _stage_party_dossier() -> void:
	var packed: PackedScene = load("res://presentation/party/party_screen.tscn")
	var party: Node = packed.instantiate()
	get_tree().root.add_child(party)
	await _wait(35)
	await _shot("party_screen")
	var run: Variant = _game.call("run") if _game != null else null
	if run != null and (run.party as Array).size() > 1:
		party.call("select_creature", 1)
		await _wait(12)
		await _shot("party_caught_selected")
	party.call("open_dossier")
	await _wait(30)
	await _shot("dossier")
	var router := get_node_or_null("/root/UiRouter")
	if router != null:
		router.call("pop_all")
	await _wait(6)
	party.queue_free()
	await _wait(6)


# === 6. lab preview + commit ================================================================== #


func _stage_lab() -> void:
	var packed: PackedScene = load("res://presentation/lab/lab_screen.tscn")
	var lab: Node = packed.instantiate()
	get_tree().root.add_child(lab)
	await _wait(35)
	await _shot("lab_bench")
	var verdict: Dictionary = lab.call("preview")
	print("[CAP] lab verdict: ", verdict)
	await _wait(15)
	await _shot("lab_preview")
	lab.call("press_commit")
	if bool(lab.call("pact_required")) and bool(lab.call("pact_armed")):
		await _wait(12)
		await _shot("lab_pact_warning")
		lab.call("press_commit")
	await _wait(4)
	if bool(lab.call("is_sealing")):
		await _wait(22)
		await _shot("lab_seal_hold")
		var guard := 0
		while guard < 600 and (lab.call("last_commit") as Dictionary).is_empty():
			guard += 1
			await get_tree().process_frame
		print("[CAP] lab commit: ", (lab.call("last_commit") as Dictionary).get("verdict"))
		await _wait(35)
		await _shot("lab_reveal_mid")
		guard = 0
		while guard < 900 and bool(lab.call("reveal_playing")):
			guard += 1
			await get_tree().process_frame
		await _wait(25)
		await _shot("lab_commit_result")
	else:
		print("[CAP] lab not sealable (verdict not LEGAL?)")
	lab.queue_free()
	await _wait(6)


# === 7. journal (quests + graveyard) ========================================================== #


func _stage_journal() -> void:
	var packed: PackedScene = load("res://presentation/journal/journal_screen.tscn")
	var journal: Node = packed.instantiate()
	get_tree().root.add_child(journal)
	await _wait(35)
	await _shot("journal_quests")
	print("[CAP] journal standing: ", journal.call("standing_text"))
	print("[CAP] journal graveyard entries: ", journal.call("graveyard_entries"))
	journal.call("show_graveyard")
	await _wait(15)
	await _shot("journal_graveyard")
	journal.queue_free()
	await _wait(6)


# === 8. character sheet ======================================================================= #


func _stage_character() -> void:
	var packed: PackedScene = load("res://presentation/character/character_sheet.tscn")
	var sheet: Node = packed.instantiate()
	get_tree().root.add_child(sheet)
	await _wait(35)
	await _shot("character_sheet")
	print("[CAP] god=", sheet.call("god_text"))
	print("[CAP] path=", sheet.call("ending_path_text"))
	print("[CAP] rank=", sheet.call("rank_text"))
	sheet.queue_free()
	await _wait(4)
