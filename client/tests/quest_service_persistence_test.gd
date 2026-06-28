extends GdUnitTestSuite
## Cluster 3 (ADR-017, D1/D4): QuestService persists quest + run state to the
## versioned-JSON save (ADR-012) and reloads it intact. Also asserts the core
## guardrail: a quest GATES run state (unlock/flag/capture) without computing any
## gameplay numbers. Uses the Questify-backed tracker through QuestTrackerFacade.

const QuestServiceScript := preload("res://application/narrative/quest_service.gd")
const RunStateScript := preload("res://application/narrative/run_state.gd")
const NarrativeSaveScript := preload("res://application/narrative/narrative_save.gd")

const QUEST_DEF := {
	"id": "marsh_omen",
	"name": "Omens in the Rust",
	"description": "Read the marsh. Regret it.",
	"steps":
	[
		{
			"id": "read",
			"description": "Read the rust-omens.",
			"on_complete": {"set_flag": "saw_omen"}
		},
		{
			"id": "wretch",
			"description": "Meet the Wretch.",
			"on_complete": {"mark_captured": "bog_wretch"}
		},
	],
	"on_complete":
	{"unlock_region": "rust_marsh", "set_flag": "lab_op_unlocked:necropsy", "add_corruption": 2},
}


func _make_service() -> QuestService:
	var service: QuestService = QuestServiceScript.new()
	service.register([QUEST_DEF])
	return service


func test_start_marks_active() -> void:
	var service := _make_service()
	assert_bool(service.is_active("marsh_omen")).is_false()
	assert_bool(service.start("marsh_omen")).is_true()
	assert_bool(service.is_active("marsh_omen")).is_true()
	assert_bool(service.is_done("marsh_omen")).is_false()


func test_trigger_gate_blocks_start_until_run_state_met() -> void:
	var gated_def := {
		"id": "deep_marsh",
		"name": "Deeper Still",
		"description": "Only once the marsh lets you in.",
		"trigger": {"region_unlocked": "rust_marsh"},
		"steps": [{"id": "descend", "description": "Descend."}],
	}
	var service: QuestService = QuestServiceScript.new()
	service.register([gated_def])
	# Trigger unmet -> start refused.
	assert_bool(service.start("deep_marsh")).is_false()
	assert_bool(service.is_active("deep_marsh")).is_false()
	# Open the region, then it may start.
	service.run_state().unlock_region("rust_marsh")
	assert_bool(service.start("deep_marsh")).is_true()
	assert_bool(service.is_active("deep_marsh")).is_true()


func test_advancing_through_steps_gates_run_state() -> void:
	var service := _make_service()
	service.start("marsh_omen")
	var run := service.run_state()

	# Nothing gated yet.
	assert_bool(run.flag("saw_omen")).is_false()
	assert_bool(run.region_unlocked("rust_marsh")).is_false()

	service.advance("marsh_omen", "read")
	assert_bool(run.flag("saw_omen")).is_true()  # step effect applied

	service.advance("marsh_omen", "wretch")
	# Final step auto-completes the quest -> quest-level effect gates the real things.
	assert_bool(service.is_done("marsh_omen")).is_true()
	assert_bool(run.has_captured("bog_wretch")).is_true()
	assert_bool(run.region_unlocked("rust_marsh")).is_true()
	assert_bool(run.flag("lab_op_unlocked:necropsy")).is_true()
	assert_int(run.corruption).is_equal(2)


func test_save_reload_state_intact() -> void:
	# Drive a quest partway, save to versioned JSON, reload into a fresh service.
	var service := _make_service()
	service.start("marsh_omen")
	service.advance("marsh_omen", "read")
	service.run_state().add_corruption(7)
	service.run_state().grant_creature("rust_homunculus")

	var payload := service.serialize()
	var json := NarrativeSaveScript.build_json(payload, "", "test")

	# Round-trip through the versioned-JSON envelope (ADR-012).
	var envelope := NarrativeSaveScript.parse_json(json)
	assert_dict(envelope).is_not_empty()
	assert_int(int(envelope["header"]["save_version"])).is_equal(NarrativeSaveScript.SAVE_VERSION)

	var reloaded: QuestService = QuestServiceScript.new()
	reloaded.register([QUEST_DEF])  # definitions must be present to rebuild graphs
	reloaded.deserialize(NarrativeSaveScript.quest_payload(envelope))

	# Quest progress survived.
	assert_bool(reloaded.is_active("marsh_omen")).is_true()
	assert_bool(reloaded.is_done("marsh_omen")).is_false()
	# Run state survived.
	var run := reloaded.run_state()
	assert_bool(run.flag("saw_omen")).is_true()
	assert_int(run.corruption).is_equal(7)
	assert_bool(run.has_creature("rust_homunculus")).is_true()

	# And it can keep going post-reload -> finishes + gates run state.
	reloaded.advance("marsh_omen", "wretch")
	assert_bool(reloaded.is_done("marsh_omen")).is_true()
	assert_bool(reloaded.run_state().region_unlocked("rust_marsh")).is_true()


func test_run_state_serialization_is_pure_data() -> void:
	var run: NarrativeRunState = RunStateScript.new()
	run.unlock_region("ash_quarter")
	run.grant_creature("tin_seraph")
	run.add_corruption(3)
	run.nudge_standing("ashen_choir", -2)
	var data := run.to_dict()
	# It is a plain JSON-stringifiable dictionary (no objects/resources).
	var json := JSON.stringify(data)
	var back := NarrativeRunState.from_dict(JSON.parse_string(json))
	assert_bool(back.region_unlocked("ash_quarter")).is_true()
	assert_bool(back.has_creature("tin_seraph")).is_true()
	assert_int(back.corruption).is_equal(3)
	assert_int(back.standing_with("ashen_choir")).is_equal(-2)
