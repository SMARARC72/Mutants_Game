extends Node2D
## TEMP CRITIC DRIVER (boss-ending sweep) — DELETE AFTER USE. Forces the Mournmarch pantheon
## boss battle through the production pending_battle hand-off, screenshots the staged beats,
## then forces the finale flags and re-enters the overworld to verify the EndingScreen fires,
## finishing on the title's closed-ledger Continue gate. Run WINDOWED (rendering needed).

const OUT := (
	"C:/Users/arahi/AppData/Local/Temp/claude"
	+ "/c--Users-arahi-Documents-Claude-Projects-Mutants-Game"
	+ "/25f1769e-3108-40a6-aa8b-e78af8055c80/scratchpad/final_caps/ending"
)
const SEED := 777001
const REGION := "mournmarch"

const EncounterDirectorScript := preload("res://application/overworld/encounter_director.gd")
const OverworldLoopStateScript := preload("res://presentation/overworld/overworld_loop_state.gd")
const SkillBattleControllerScript := preload("res://application/battle/skill_battle_controller.gd")


func _ready() -> void:
	await _run()
	get_tree().quit()


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT + "/" + shot_name + ".png")
	print("CRITIC shot: ", shot_name)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _run() -> void:
	# Root is still assembling its children during _ready — wait a frame before add_child(root).
	await get_tree().process_frame
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(OUT)
	var game := get_node_or_null("/root/GameController")
	if game == null:
		print("CRITIC FAIL: no GameController")
		return
	var settings := get_node_or_null("/root/Settings")
	if settings != null and settings.has_method("set_value"):
		settings.call("set_value", "battle", "swift_rites", "x1")
		settings.call("set_value", "accessibility", "reduce_motion", false)
	var run: RunContext = game.call("new_run", SEED)
	run.world_state["active_region"] = REGION
	run.unlocked_regions[REGION] = true
	# Stacked deck: three god-proxy creatures so the climax completes on camera.
	run.party = [
		{"species_id": "batch3-020", "nickname": "Witness One", "kit_override": ["Soul Leech", "Wither"]},
		{"species_id": "batch3-029", "nickname": "Witness Two", "kit_override": ["Soul Leech", "Wither"]},
		{"species_id": "batch3-027", "nickname": "Witness Three", "kit_override": ["Soul Leech", "Wither"]},
	]
	# --- Phase A: the Mournmarch pantheon boss, through the PRODUCTION hand-off shape --------- #
	var catalog: SpeciesCatalog = game.call("catalog")
	var director = EncounterDirectorScript.for_region(SEED, REGION, catalog)
	var trigger: Dictionary = EncounterCatalog.boss_trigger_for(REGION)
	var roll: Dictionary = director.boss_step(int(trigger["min_steps"]))
	print("CRITIC boss roll: ", roll.get("boss_id"), " | intro=", roll.get("intro_line"))
	var pending := {
		"enemy_party": roll["enemy_party"],
		"battle_seed": int(roll["battle_seed"]),
		"region": REGION,
		"force": "Thanatos",
	}
	pending.merge(OverworldLoopStateScript.boss_handoff_extra(roll), true)
	run.flags["pending_battle"] = pending
	var battle: Control = (
		(load("res://presentation/battle/battle_screen.tscn") as PackedScene).instantiate()
	)
	get_tree().root.add_child(battle)
	await _wait(0.7)
	await _shot("01_boss_splash")
	await _wait(1.8)
	await _shot("02_boss_stage_threatbar")
	# Drive the fight: first damage skill each player turn; catch one mid-beat frame.
	var step: Dictionary = battle.call("last_step")
	var took_mid := false
	var guard := 0
	while str(step.get("kind", "")) == "await_player" and guard < 120:
		guard += 1
		var actor: Variant = step.get("actor")
		var skill := _damage_skill(actor)
		if skill == "":
			battle.call("player_pass")
		else:
			battle.call("player_use_skill", skill, 0)
		if not took_mid:
			await _wait(0.30)
			await _shot("03_midfight_beat")
			took_mid = true
			battle.call("cycle_swift_rites")  # x1 -> x2: halve the remaining beats
		var wait_guard := 0
		while bool(battle.get("_beats_playing")) and wait_guard < 900:
			wait_guard += 1
			await get_tree().process_frame
		step = battle.call("last_step")
	await _wait(1.2)
	var result: Dictionary = battle.call("result")
	print(
		"CRITIC battle end: winner=", result.get("winner"),
		" boss_win=", result.get("boss_win"), " turns=", guard
	)
	await _shot("04_victory_epitaph_toast")
	await _wait(1.5)
	await _shot("04b_victory_settled")
	battle.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	# --- Phase B: force the finale, re-enter the overworld ------------------------------------ #
	run = game.call("run")
	run.flags["act5_q4_done"] = true
	run.flags["god_maker"] = true
	var over: Node = (
		(load("res://presentation/overworld/overworld_screen.tscn") as PackedScene).instantiate()
	)
	get_tree().root.add_child(over)
	await _wait(1.4)
	await _shot("05_ending_reveal")
	await _wait(4.5)
	await _shot("06_ending_full")
	var router := get_node_or_null("/root/UiRouter")
	var page: Node = null
	if router != null and router.has_method("top_scene"):
		page = router.call("top_scene")
	if page == null:
		print("CRITIC FAIL: ending screen did not fire")
		return
	print("CRITIC ending: id=", page.call("ending_id"), " name=", page.call("name_text"))
	over.queue_free()
	await get_tree().process_frame
	# Keep this driver alive through the production scene swap: park a dummy as current_scene.
	var dummy := Node2D.new()
	dummy.name = "CriticDummyScene"
	get_tree().root.add_child(dummy)
	get_tree().current_scene = dummy
	# Press the REAL verb (save -> pop_all -> ritual swap to the title).
	var verb := page.find_child("SaveAndCloseButton", true, false)
	if verb != null:
		(verb as Button).pressed.emit()
	else:
		page.call("save_and_close")
	# Poll for the title's Continue button (the swap runs on the Transition autoload).
	var cont: Node = null
	for _i in 600:
		await get_tree().process_frame
		var cs := get_tree().current_scene
		if cs != null and cs != dummy:
			cont = cs.find_child("ContinueButton", true, false)
			if cont != null:
				break
	await _wait(1.0)
	await _shot("07_title_after_close")
	if cont == null:
		print("CRITIC FAIL: title / ContinueButton never appeared")
		return
	print("CRITIC continue_health: ", game.call("continue_health"))
	(cont as Button).pressed.emit()
	await _wait(0.8)
	await _shot("08_closed_ledger_gate")
	print("CRITIC done")


func _damage_skill(actor: Variant) -> String:
	if actor == null:
		return ""
	for skill in (actor as AbilityContainer).abilities():
		var verb := SkillBattleControllerScript.verb_of(str(skill))
		if not SkillBattleControllerScript.is_support_verb(verb):
			return str(skill)
	return ""
