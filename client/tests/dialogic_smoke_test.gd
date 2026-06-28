extends GdUnitTestSuite
## Phase 0.5 Dialogic smoke test. Proves the Dialogic addon is functional headless: the
## autoload is present and the 3-line smoke timeline imports + loads as a DialogicTimeline
## (i.e. Dialogic parsed it). Full on-screen playback is UI-driven and not exercised headless
## (Dialogic itself warns UI interaction doesn't work headless); that lands in Phase 5.


func test_dialogic_autoload_present() -> void:
	assert_object(Dialogic).is_not_null()


func test_smoke_timeline_imports_and_loads() -> void:
	var timeline = load("res://presentation/dialogue/smoke.dtl")
	assert_object(timeline).is_not_null()
	assert_bool(timeline is DialogicTimeline).is_true()
