extends GdUnitTestSuite
## Phase 5 · Slice 3b — Camp/pause menu DoD, driven HEADLESSLY (instantiate, assert, drive).
##   * the camp menu builds its themed buttons (Party / Lab / Resume) in code;
##   * Resume emits `resumed` and tears the menu down (closes back to the overworld);
##   * the Lab button targets res://presentation/lab/lab_screen.tscn and is GUARDED when that
##     sibling-track scene is absent (open_lab is a no-op returning "" instead of erroring);
##   * the Party button targets the party screen path.
## Auto-navigate is disabled so the navigation buttons report their target without a scene swap.

const CampMenuScript := preload("res://presentation/camp/camp_menu.gd")


func _make_menu() -> Control:
	var menu: Control = CampMenuScript.new()
	menu.call("set_auto_navigate", false)
	add_child(menu)  # _ready builds the UI (grabs autoloads; injected flags already set).
	return menu


func test_camp_menu_builds_its_buttons() -> void:
	var menu := _make_menu()
	assert_object(menu.find_child("PartyButton", true, false)).is_not_null()
	assert_object(menu.find_child("LabButton", true, false)).is_not_null()
	assert_object(menu.find_child("ResumeButton", true, false)).is_not_null()
	menu.queue_free()


func test_resume_emits_and_closes() -> void:
	var menu := _make_menu()
	var seen := {"resumed": false}
	menu.connect("resumed", func() -> void: seen["resumed"] = true)
	menu.call("resume")
	assert_bool(bool(seen["resumed"])).is_true()
	# queue_free was requested by resume(); the node is on its way out of the tree.
	await get_tree().process_frame
	assert_bool(is_instance_valid(menu)).is_false()


func test_lab_button_targets_the_lab_scene_path() -> void:
	var menu := _make_menu()
	assert_str(str(menu.call("lab_scene_path"))).is_equal("res://presentation/lab/lab_screen.tscn")
	menu.queue_free()


func test_open_lab_is_guarded_when_absent() -> void:
	# The sibling track builds the Lab screen; until then the path does not resolve. open_lab must
	# guard gracefully (returns "" + does not crash) when the scene is missing.
	var menu := _make_menu()
	var available := bool(menu.call("lab_available"))
	var target: String = menu.call("open_lab")
	if available:
		assert_str(target).is_equal("res://presentation/lab/lab_screen.tscn")
	else:
		assert_str(target).is_equal("")  # guarded: no swap, no error.
	menu.queue_free()


func test_party_button_targets_the_party_screen() -> void:
	var menu := _make_menu()
	var target: String = menu.call("open_party")
	assert_str(target).is_equal("res://presentation/party/party_screen.tscn")
	menu.queue_free()
