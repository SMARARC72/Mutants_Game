extends GdUnitTestSuite
## WAVE-SND — SfxService / MusicService headless contract: the services instantiate, play()
## no-ops without error while recording `last_played`, apply_bus_volume maps 0..1 linear to
## dB (mute at zero), buses route to Master, MusicService.play_bed tracks the current bed
## without an audio device, and the scene->bed map covers the three auto-bed screens.

const SfxServiceScript := preload("res://autoload/sfx_service.gd")
const MusicServiceScript := preload("res://autoload/music_service.gd")


# === SfxService =====================================================================
func test_sfx_service_instantiates_and_play_records_headless() -> void:
	var sfx: Node = SfxServiceScript.new()
	add_child(sfx)
	await await_idle_frame()
	assert_str(sfx.get("last_played")).is_equal("")
	sfx.call("play", "ui_click")
	assert_str(sfx.get("last_played")).is_equal("ui_click")
	sfx.call("play", "hit_crunch", 0.1)
	assert_str(sfx.get("last_played")).is_equal("hit_crunch")
	sfx.call("play_footstep")
	assert_bool(String(sfx.get("last_played")).begins_with("footstep_")).is_true()
	sfx.queue_free()


func test_buses_exist_and_route_to_master() -> void:
	SfxServiceScript.ensure_buses()
	for bus_name: String in ["Music", "SFX"]:
		var idx := AudioServer.get_bus_index(bus_name)
		(
			assert_int(idx)
			. override_failure_message("bus '%s' was not created" % bus_name)
			. is_not_equal(-1)
		)
		assert_str(AudioServer.get_bus_send(idx)).is_equal("Master")
	# Idempotent: a second call never duplicates buses.
	var count_before := AudioServer.bus_count
	SfxServiceScript.ensure_buses()
	assert_int(AudioServer.bus_count).is_equal(count_before)


func test_apply_bus_volume_maps_linear_to_db_and_mutes_at_zero() -> void:
	SfxServiceScript.ensure_buses()
	var idx := AudioServer.get_bus_index("SFX")
	SfxServiceScript.apply_bus_volume("SFX", 0.5)
	assert_float(AudioServer.get_bus_volume_db(idx)).is_equal_approx(linear_to_db(0.5), 0.01)
	assert_bool(AudioServer.is_bus_mute(idx)).is_false()
	SfxServiceScript.apply_bus_volume("SFX", 1.0)
	assert_float(AudioServer.get_bus_volume_db(idx)).is_equal_approx(0.0, 0.01)
	SfxServiceScript.apply_bus_volume("SFX", 0.0)
	assert_bool(AudioServer.is_bus_mute(idx)).is_true()
	# Restore a sane level for whatever suite runs next.
	SfxServiceScript.apply_bus_volume("SFX", 0.9)


func test_apply_volumes_pushes_settings_values_onto_buses() -> void:
	var settings := get_node_or_null("/root/Settings")
	if settings != null:
		settings.call("set_value", "audio", "music_volume", 0.5)
	var sfx: Node = SfxServiceScript.new()
	add_child(sfx)
	await await_idle_frame()
	sfx.call("apply_volumes")
	var idx := AudioServer.get_bus_index("Music")
	assert_int(idx).is_not_equal(-1)
	if settings != null:
		assert_float(AudioServer.get_bus_volume_db(idx)).is_equal_approx(linear_to_db(0.5), 0.01)
		assert_bool(AudioServer.is_bus_mute(idx)).is_false()
	sfx.queue_free()


# === MusicService ===================================================================
func test_music_service_play_bed_switches_current_bed() -> void:
	var music: Node = MusicServiceScript.new()
	add_child(music)
	await await_idle_frame()
	assert_str(music.call("current_bed")).is_equal("")
	music.call("play_bed", "menu_bed")
	assert_str(music.call("current_bed")).is_equal("menu_bed")
	music.call("play_bed", "battle_drone", 0.1)
	assert_str(music.call("current_bed")).is_equal("battle_drone")
	# Re-requesting the active bed is a no-op, never a restart.
	music.call("play_bed", "battle_drone")
	assert_str(music.call("current_bed")).is_equal("battle_drone")
	music.queue_free()


func test_scene_to_bed_map_covers_auto_bed_screens() -> void:
	var cases := {
		"res://presentation/screens/main_menu.tscn": "menu_bed",
		"res://presentation/screens/options_menu.tscn": "menu_bed",
		"res://presentation/overworld/overworld_screen.tscn": "ambience_marsh",
		"res://presentation/battle/battle_screen.tscn": "battle_drone",
		"res://presentation/lab/lab_screen.tscn": "",
	}
	for path: String in cases:
		(
			assert_str(MusicServiceScript.bed_for_scene_path(path))
			. override_failure_message("bed mapping wrong for %s" % path)
			. is_equal(cases[path])
		)


func test_every_declared_stream_and_bed_asset_exists() -> void:
	for sound_id: String in SfxServiceScript.STREAM_PATHS:
		var path: String = SfxServiceScript.STREAM_PATHS[sound_id]
		(
			assert_bool(ResourceLoader.exists(path))
			. override_failure_message("missing SFX asset for '%s': %s" % [sound_id, path])
			. is_true()
		)
	for bed_id: String in MusicServiceScript.BED_PATHS:
		var path: String = MusicServiceScript.BED_PATHS[bed_id]
		(
			assert_bool(ResourceLoader.exists(path))
			. override_failure_message("missing bed asset for '%s': %s" % [bed_id, path])
			. is_true()
		)
