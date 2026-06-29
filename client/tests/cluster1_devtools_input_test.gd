extends GdUnitTestSuite
## Cluster 1 runtime integration: the live DevConsole/LimboConsole + InputService/G.U.I.D.E
## autoloads (D3, D4). Exercises the real singletons gdUnit boots, proving the facades drive the
## vendored addons without leaking their types to the app.

const InputActions := preload("res://infrastructure/input/input_actions.gd")


# === D3 — LimboConsole state pokes + parity stubs (dev build) =======================
func test_dev_console_registers_state_pokes_and_parity_stubs() -> void:
	var dev := get_node_or_null("/root/DevConsole")
	assert_object(dev).is_not_null()
	# gdUnit runs as a debug build, so DEV_TOOLS is on.
	assert_bool(dev.is_dev_build()).is_true()
	var console := get_node_or_null("/root/LimboConsole")
	assert_object(console).is_not_null()
	for cmd in [
		"set_seed",
		"set_corruption",
		"set_morality",
		"give_creature",
		"grant_gear",
		"unlock_region",
		"parity_battle",
		"parity_splice",
	]:
		(
			assert_bool(console.has_command(cmd))
			. override_failure_message("command '%s' not registered" % cmd)
			. is_true()
		)


func test_dev_state_pokes_record_values() -> void:
	var dev := get_node_or_null("/root/DevConsole")
	var state: Object = dev.state()
	assert_object(state).is_not_null()
	state.set_seed(777)
	state.set_corruption(42)
	state.give_creature("gaia_brute_001")
	assert_int(state.seed).is_equal(777)
	assert_int(state.corruption).is_equal(42)
	assert_bool(state.party.has("gaia_brute_001")).is_true()


# === D4 — InputService over G.U.I.D.E ==============================================
func test_input_service_switches_contexts() -> void:
	var input := get_node_or_null("/root/InputService")
	assert_object(input).is_not_null()
	for ctx in [
		InputActions.CTX_MENU,
		InputActions.CTX_OVERWORLD,
		InputActions.CTX_BATTLE,
		InputActions.CTX_LAB,
	]:
		input.switch_context(ctx)
		assert_str(input.current_context()).is_equal(ctx)


func test_overworld_movement_reads_both_wasd_and_arrow_keys() -> void:
	# Regression: the overworld avatar ignored the ARROW keys (it only read WASD), so players who
	# reached for the arrows by instinct saw a frozen-looking game. In CTX_OVERWORLD both WASD
	# (MOVE_*) and the arrows (NAV_*) must yield a movement vector.
	var input := get_node_or_null("/root/InputService")
	assert_object(input).is_not_null()
	# This relies on the Godot InputMap fallback (action_press drives is_action_pressed); guard so the
	# test is meaningful (the project boots without the GUIDE engine singleton -> fallback is active).
	assert_bool(InputMap.has_action(InputActions.MOVE_UP)).is_true()

	input.switch_context(InputActions.CTX_OVERWORLD)

	Input.action_press(InputActions.MOVE_UP)  # W -> up
	var wasd: Vector2 = input.movement_vector()
	Input.action_release(InputActions.MOVE_UP)
	assert_float(wasd.x).is_equal(0.0)
	assert_float(wasd.y).is_equal(-1.0)

	Input.action_press(InputActions.NAV_LEFT)  # arrow-left -> left
	var arrow: Vector2 = input.movement_vector()
	Input.action_release(InputActions.NAV_LEFT)
	assert_float(arrow.x).is_equal(-1.0)
	assert_float(arrow.y).is_equal(0.0)

	input.switch_context(InputActions.CTX_MENU)


func test_input_service_rebind_persists_to_settings() -> void:
	var input := get_node_or_null("/root/InputService")
	var settings := get_node_or_null("/root/Settings")
	assert_object(input).is_not_null()
	assert_object(settings).is_not_null()
	input.rebind(InputActions.CONFIRM, "key", KEY_F)
	var binding: Dictionary = input.binding_of(InputActions.CONFIRM)
	assert_int(int(binding["code"])).is_equal(KEY_F)
	# It went through the Settings JSON blob (ADR-012), not a Resource.
	assert_bool(settings.get_input_remaps().has(InputActions.CONFIRM)).is_true()
	input.clear_rebind(InputActions.CONFIRM)
