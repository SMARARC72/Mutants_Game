extends Node2D
## TEMP ui-consistency critic driver (delete after the sweep). Walks every overlay/screen the
## critic must judge, staging the exact states asked for, saving viewport PNGs. Run windowed.

const OUT := (
	"C:/Users/arahi/AppData/Local/Temp/claude"
	+ "/c--Users-arahi-Documents-Claude-Projects-Mutants-Game"
	+ "/25f1769e-3108-40a6-aa8b-e78af8055c80/scratchpad/final_caps/ui"
)

const OPTIONS_SCENE := "res://presentation/screens/options_menu.tscn"
const TRADER_SCENE := "res://presentation/camp/trader_shop.tscn"
const JOURNAL_SCENE := "res://presentation/journal/journal_screen.tscn"
const CHARACTER_SCENE := "res://presentation/character/character_sheet.tscn"
const DOSSIER_SCENE := "res://presentation/dossier/dossier_screen.tscn"
const LAB_SCENE := "res://presentation/lab/lab_screen.tscn"
const CAMP_SCENE := "res://presentation/camp/camp_menu.tscn"
const ThresholdScreenScript := preload("res://presentation/overworld/threshold_screen.gd")
const CaptureCardScript := preload("res://presentation/battle/capture_card.gd")


func _ready() -> void:
	await _run()
	get_tree().quit()


func _snap(file_name: String) -> void:
	for _i in 3:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT + "/" + file_name + ".png")
	print("[uicap] saved ", file_name)


func _settle(frames: int = 20) -> void:
	for _i in frames:
		await get_tree().process_frame


func _mount(node: Node) -> void:
	get_tree().root.add_child(node)
	await _settle()


func _unmount(node: Node) -> void:
	if node != null and is_instance_valid(node):
		node.queue_free()
	await _settle(4)


func _run() -> void:
	await get_tree().process_frame  # leave _ready's child-setup window before mounting
	DirAccess.make_dir_recursive_absolute(OUT)
	var game := get_node_or_null("/root/GameController")
	if game == null:
		push_error("[uicap] no GameController")
		return

	# --- 1. Options: idle + armed rebind capture ------------------------------------------------ #
	var options: Node = (load(OPTIONS_SCENE) as PackedScene).instantiate()
	await _mount(options)
	await _snap("options_idle")
	var rebind := options.find_child("RebindButton_confirm", true, false)
	if rebind is Button:
		options.call("begin_rebind_capture", "confirm", rebind)
	await _snap("options_rebind_capture")
	await _unmount(options)

	# --- boot a run ------------------------------------------------------------------------------ #
	game.call("new_run", 424242)
	await _settle(5)
	var run: RunContext = game.call("run")

	# --- 2. Trader (one item deliberately unaffordable: 30 < 40) -------------------------------- #
	run.drachma = 30
	var trader: Node = (load(TRADER_SCENE) as PackedScene).instantiate()
	await _mount(trader)
	await _snap("trader")
	await _unmount(trader)

	# --- 3. Threshold travel circle -------------------------------------------------------------- #
	var threshold: Control = ThresholdScreenScript.new()
	await _mount(threshold)
	await _snap("threshold")
	# free directly (its close() paths emit signals we don't need)
	threshold.queue_free()
	await _settle(4)

	# --- 4. Journal: quests tab + graveyard tab -------------------------------------------------- #
	var qs := QuestService.new()
	qs.register(OverworldContent.quest_defs())
	qs.start("marsh_welcome")
	qs.advance("marsh_welcome", "hear_marrow")
	qs.start("the_melon_that_waits")
	qs.advance("the_melon_that_waits", "covet_melon")
	qs.advance("the_melon_that_waits", "wait_with_melon")
	run.flags["quest_state"] = qs.serialize()
	run.flags["graveyard"] = [
		{
			"name": "Thornlash",
			"species_id": "SB07",
			"sigil": "thornlash-1",
			"force": "Eros",
			"cause": "Felled by Grave-Boar",
			"turn": 6,
			"region": "verdant_glut",
			"parts": ["claw", "horn"],
			"creature": {"species_id": "SB07", "is_dead": true},
		},
		{
			"name": "Sprout-shell",
			"species_id": "SB05",
			"sigil": "sprout-2",
			"force": "Gaia",
			"cause": "The lab took it apart",
			"turn": 11,
			"region": "verdant_glut",
			"parts": [],
			"creature": {"species_id": "SB05", "is_dead": true},
		},
	]
	var journal: Node = (load(JOURNAL_SCENE) as PackedScene).instantiate()
	await _mount(journal)
	await _snap("journal_quests")
	journal.call("show_graveyard")
	await _settle(8)
	await _snap("journal_graveyard")
	await _unmount(journal)

	# --- 5. Character sheet (mid-run morality so bars read) -------------------------------------- #
	run.order_chaos = 35
	run.purity_corrupt = -20
	run.corruption = 45
	run.deeds = 7
	run.notoriety = 3
	var sheet: Node = (load(CHARACTER_SCENE) as PackedScene).instantiate()
	await _mount(sheet)
	await _snap("character_sheet")
	await _unmount(sheet)

	# --- 6. Dossier: a real (founder/caught) creature -------------------------------------------- #
	var dossier: Node = (load(DOSSIER_SCENE) as PackedScene).instantiate()
	get_tree().root.add_child(dossier)
	dossier.call("show_creature", 0)
	await _settle()
	await _snap("dossier_real")
	await _unmount(dossier)

	# --- 7. Capture card (instant reveal end-state) ---------------------------------------------- #
	var caught := {
		"species_id": "SB14",
		"nickname": "Marsh-thing",
		"genome": {},
		"expression": 0.5,
		"bond": 0.2,
		"entropy": 0,
		"awakenings": 0,
		"stats_cached": {},
		"skills": [],
		"status_effects": {},
		"lineage": {"captured": true, "from_species": "SB14"},
		"is_dead": false,
	}
	var line := VoiceBook.pick("capture.befriend.success").format({"creature": "Marsh-thing"})
	var card: Control = CaptureCardScript.new()
	get_tree().root.add_child(card)
	card.call("build", caught, "Marsh-thing", "Eros", line, true)
	await _settle()
	await _snap("capture_card")
	await _unmount(card)

	# --- 8. Lab: slider both ends over a LEGAL fuse ---------------------------------------------- #
	run.party = [{"species_id": "SB07"}, {"species_id": "AD10"}]
	run.essence = 40
	var lab: Node = (load(LAB_SCENE) as PackedScene).instantiate()
	await _mount(lab)
	lab.call("set_method_value", 0.0)
	await _settle(10)
	await _snap("lab_precise")
	lab.call("set_method_value", 1.0)
	await _settle(10)
	await _snap("lab_wild")
	# Commit the fuse -> the newborn hybrid (for the hybrid dossier below).
	lab.call("set_method_value", 0.0)
	lab.call("select_op", "fuse")
	lab.call("set_creature_a", 0)
	lab.call("set_creature_b", 1)
	lab.call("commit")
	await _settle(30)
	await _snap("lab_committed")
	await _unmount(lab)

	# --- 9. Dossier: the hybrid newborn ----------------------------------------------------------- #
	var hybrid: Dictionary = {}
	for entry_v in run.party:
		var entry: Dictionary = entry_v
		if bool((entry.get("lineage", {}) as Dictionary).get("spliced", false)):
			hybrid = entry
			break
	if not hybrid.is_empty():
		var dossier2: Node = (load(DOSSIER_SCENE) as PackedScene).instantiate()
		get_tree().root.add_child(dossier2)
		dossier2.call("show_creature_dict", hybrid)
		await _settle()
		await _snap("dossier_hybrid")
		await _unmount(dossier2)

	# --- 10. Lab: taboo pact armed state ---------------------------------------------------------- #
	run.party = [{"species_id": "AD04"}, {"species_id": "AD01"}]
	run.corruption = 50
	run.essence = 40
	var lab2: Node = (load(LAB_SCENE) as PackedScene).instantiate()
	await _mount(lab2)
	lab2.call("select_op", "fuse")
	lab2.call("set_creature_a", 0)
	lab2.call("set_creature_b", 1)
	await _settle(10)
	await _snap("lab_taboo_preview")
	lab2.call("press_commit")  # first press only ARMS the pact
	await _settle(10)
	await _snap("lab_taboo_armed")
	await _unmount(lab2)

	# --- 11. Camp menu (context: the hub these overlays hang off) --------------------------------- #
	var camp: Node = (load(CAMP_SCENE) as PackedScene).instantiate()
	await _mount(camp)
	await _snap("camp_menu")
	await _unmount(camp)
