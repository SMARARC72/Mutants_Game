extends GdUnitTestSuite
## Cluster 1 UX-shell + Dev/Ops facade tests (D2-D8). Proves the facades work headless without
## leaking addon types: the grimoire Theme builds (D6), the Toast facade stacks + fires (D7), the
## Transition facade runs (D8), Settings round-trips as JSON (D5/ADR-012), CrashReporter is silent
## with consent off + non-PII (D2), and the four input contexts + their actions exist (D4).

const GrimoireTheme := preload("res://presentation/ui/theme/grimoire_theme.gd")
const GrimoirePalette := preload("res://presentation/ui/theme/grimoire_palette.gd")
const ToastMicrocopy := preload("res://presentation/ui/toast/toast_microcopy.gd")
const InputActions := preload("res://infrastructure/input/input_actions.gd")
const CrashReporterScript := preload("res://infrastructure/ops/crash_reporter.gd")
const SettingsScript := preload("res://autoload/settings.gd")


# === D6 — ThemeGen grimoire Theme ===================================================
func test_grimoire_theme_builds_with_force_styles() -> void:
	var theme := GrimoireTheme.build()
	assert_object(theme).is_not_null()
	assert_object(theme.get_stylebox("normal", "Button")).is_not_null()
	assert_object(theme.get_stylebox("panel", "PanelContainer")).is_not_null()


func test_grimoire_theme_binds_fonts_and_surface_variations() -> void:
	var theme := GrimoireTheme.build()
	# The grimoire type pairing is bound: Alegreya as the default body font, Cinzel on titles.
	assert_object(theme.default_font).is_not_null()
	assert_object(theme.get_font("font", "TitleLabel")).is_not_null()
	assert_int(theme.get_font_size("font_size", "TitleLabel")).is_equal(GrimoireTheme.FONT_TITLE)
	# The parchment/plate surface variations resolve to styleboxes.
	assert_object(theme.get_stylebox("panel", "ParchmentPanel")).is_not_null()
	assert_object(theme.get_stylebox("panel", "PlatePanel")).is_not_null()


func test_palette_force_color_resolves_all_six_forces() -> void:
	for force in ["gaia", "ouranos", "cosmos", "chaos", "eros", "thanatos"]:
		assert_object(GrimoirePalette.force_color(force)).is_not_null()
	# Corruption deepens green -> bruise-purple as it fills (design §2).
	var low := GrimoirePalette.corruption_color(0.0)
	var high := GrimoirePalette.corruption_color(1.0)
	assert_bool(low != high).is_true()


# === D7 — Toast facade (stacking, fires, themed copy) ===============================
func test_toast_fires_and_stacks() -> void:
	var toast := preload("res://presentation/ui/toast/toast.gd").new()
	add_child(toast)
	await await_idle_frame()
	toast.event(ToastMicrocopy.CAUGHT)
	toast.event(ToastMicrocopy.HARVEST)
	await await_idle_frame()
	assert_int(toast.visible_count()).is_equal(2)
	toast.dismiss_all()
	await await_idle_frame()
	assert_int(toast.visible_count()).is_equal(0)
	toast.queue_free()


func test_toast_microcopy_presets_have_copy_for_all_core_events() -> void:
	for event_id in [
		ToastMicrocopy.CAUGHT,
		ToastMicrocopy.HARVEST,
		ToastMicrocopy.AWAKEN,
		ToastMicrocopy.QUEST,
		ToastMicrocopy.RIVAL,
		ToastMicrocopy.CORRUPTION,
	]:
		var preset := ToastMicrocopy.preset(event_id)
		assert_str(preset["title"]).is_not_empty()
		assert_str(preset["body"]).is_not_empty()
		assert_str(preset["sound"]).is_not_empty()


# === D8 — Transition facade =========================================================
func test_transition_ritual_runs_and_clears_busy() -> void:
	var transition := preload("res://presentation/ui/transition/transition.gd").new()
	add_child(transition)
	await await_idle_frame()
	var ran := [false]
	await transition.ritual(func() -> void: ran[0] = true)
	assert_bool(ran[0]).is_true()
	assert_bool(transition.is_busy()).is_false()
	transition.queue_free()


# === D5 — Settings persistence (JSON, ADR-012) =====================================
func test_settings_round_trip_as_json() -> void:
	var settings: Node = SettingsScript.new()
	add_child(settings)
	await await_idle_frame()
	settings.set_value("audio", "music_volume", 0.42)
	settings.set_input_remaps({"confirm": {"device": "key", "code": 32}})
	assert_bool(settings.save_settings()).is_true()

	var reloaded: Node = SettingsScript.new()
	add_child(reloaded)
	await await_idle_frame()
	reloaded.load_settings()
	assert_float(reloaded.get_value("audio", "music_volume")).is_equal(0.42)
	# JSON has no int/float distinction; the code value round-trips as a number.
	assert_int(int(reloaded.get_input_remaps()["confirm"]["code"])).is_equal(32)
	settings.queue_free()
	reloaded.queue_free()


# === D2 — CrashReporter (opt-in, no PII) ===========================================
func test_crash_reporter_silent_without_consent() -> void:
	var reporter := CrashReporterScript.new()
	reporter.init(false, 1234, {"save_version": 1})
	assert_bool(reporter.is_enabled()).is_false()
	assert_bool(reporter.capture("forced test error")).is_false()


func test_crash_reporter_attaches_seed_and_strips_pii() -> void:
	var reporter := CrashReporterScript.new()
	reporter.init(true, 9999, {"save_version": 2, "player_email": "leak@example.com"}, "1.2.3")
	var ctx := reporter.attached_context()
	assert_int(ctx["run.seed"]).is_equal(9999)
	assert_str(ctx["build.version"]).is_equal("1.2.3")
	# PII keys are dropped, non-PII save header kept.
	assert_bool(ctx.has("save.save_version")).is_true()
	assert_bool(ctx.has("save.player_email")).is_false()


# === D4 — Input contexts + actions =================================================
func test_four_input_contexts_exist_with_actions() -> void:
	var contexts := InputActions.context_actions()
	for ctx in [
		InputActions.CTX_MENU,
		InputActions.CTX_OVERWORLD,
		InputActions.CTX_BATTLE,
		InputActions.CTX_LAB,
	]:
		assert_bool(contexts.has(ctx)).is_true()
		assert_int((contexts[ctx] as Array).size()).is_greater(0)


func test_every_action_has_a_default_key() -> void:
	var keys := InputActions.default_keys()
	for ctx_actions: Array in InputActions.context_actions().values():
		for action_id: String in ctx_actions:
			(
				assert_bool(keys.has(action_id))
				. override_failure_message("action '%s' has no default key" % action_id)
				. is_true()
			)
