extends GdUnitTestSuite
## Phase 3 (ADR-005/012): round-trip serialization. A RunContext and a full SaveEnvelope
## serialize -> JSON -> deserialize INTACT, with no objects/resources crossing the wire (data
## only). Also pins the header invariants (version, section, checksum) and the downgrade refusal.

const RunContextScript := preload("res://application/persistence/run_context.gd")
const SaveEnvelopeScript := preload("res://application/persistence/save_envelope.gd")
const CommandLogScript := preload("res://application/persistence/command_log.gd")


func _sample_context() -> RunContext:
	var ctx: RunContext = RunContextScript.new()
	ctx.run_id = "run-abc"
	ctx.player_id = "player-1"
	ctx.seed = 1234567890123
	ctx.save_version = 3
	ctx.schema_version = 1
	ctx.act = 2
	ctx.rank = "Demigod"
	ctx.corruption = 144  # uncapped player track (ADR-014): legitimately > 130
	ctx.drachma = 500
	ctx.gear = {"Tool": "geneweaver_gloves"}
	ctx.god_form = ""
	ctx.status = "active"
	ctx.party = [
		{
			"id": "ci-1",
			"species_id": "AD01",
			"nickname": "Gnash",
			"genome": {"bulk": 12},
			"lineage": {"fused_from": ["AD02", "AD03"]},
			"is_dead": false,
		},
		{"id": "ci-2", "species_id": "AD02", "lineage": {}, "is_dead": true},
	]
	ctx.inventory = [{"item_type": "organ", "item_key": "ruin_heart", "qty": 2}]
	ctx.world_state = {
		"region_states": {"rust_marsh": {"destabilized": true}}, "force_tide": "Chaos"
	}
	ctx.unlocked_regions = {"rust_marsh": true}
	ctx.flags = {"lab_op_unlocked:necropsy": true}
	ctx.narrative = {"version": 1, "run_state": {"corruption": 144}}
	return ctx


func test_run_context_round_trip_is_pure_data() -> void:
	var ctx := _sample_context()
	var data := ctx.to_dict()
	# Must be a plain JSON-stringifiable dictionary (no objects/resources).
	var json := JSON.stringify(data)
	var parsed: Variant = JSON.parse_string(json)
	assert_bool(parsed is Dictionary).is_true()

	var back: RunContext = RunContextScript.from_dict(parsed)
	assert_str(back.run_id).is_equal("run-abc")
	assert_str(back.player_id).is_equal("player-1")
	assert_int(back.seed).is_equal(1234567890123)
	assert_int(back.save_version).is_equal(3)
	assert_str(back.rank).is_equal("Demigod")
	assert_int(back.corruption).is_equal(144)
	assert_int(back.drachma).is_equal(500)
	assert_int(back.party_size()).is_equal(2)
	assert_int(back.living_party_size()).is_equal(1)
	assert_str(str(back.gear.get("Tool", ""))).is_equal("geneweaver_gloves")
	# Embedded lineage survives intact.
	var first: Dictionary = back.party[0]
	assert_bool((first["lineage"] as Dictionary).has("fused_from")).is_true()
	assert_bool(back.flags.get("lab_op_unlocked:necropsy", false)).is_true()


func test_run_context_load_from_restores_in_place() -> void:
	var ctx: RunContext = RunContextScript.new()
	var data := _sample_context().to_dict()
	ctx.load_from(data)  # in-place restore preserves object identity
	assert_str(ctx.rank).is_equal("Demigod")
	assert_int(ctx.party_size()).is_equal(2)


func test_full_envelope_round_trip() -> void:
	var ctx := _sample_context()
	var log: CommandLog = CommandLogScript.new()
	log.append("fuse", {"a": "ci-1", "b": "ci-2"})
	log.append("capture", {"species": "AD09"})

	var json := SaveEnvelopeScript.build_json(
		ctx.to_dict(), ctx.narrative, '{"flows":{}}', log.to_dict(), "0.3.0"  # opaque ink state string
	)
	var envelope := SaveEnvelopeScript.parse_json(json)
	assert_dict(envelope).is_not_empty()

	# Header invariants.
	var header: Dictionary = envelope["header"]
	assert_int(int(header["save_version"])).is_equal(SaveEnvelopeScript.SAVE_VERSION)
	assert_str(str(header["section"])).is_equal(SaveEnvelopeScript.SECTION)
	assert_str(str(header["run_id"])).is_equal("run-abc")
	assert_bool(header.has("checksum")).is_true()
	assert_bool(SaveEnvelopeScript.verify_checksum(envelope)).is_true()

	# Sections reconstruct.
	var back: RunContext = RunContextScript.from_dict(SaveEnvelopeScript.run_payload(envelope))
	assert_str(back.run_id).is_equal("run-abc")
	assert_int(back.corruption).is_equal(144)
	assert_str(SaveEnvelopeScript.ink_state(envelope)).is_equal('{"flows":{}}')

	var back_log: CommandLog = CommandLogScript.from_dict(
		SaveEnvelopeScript.command_log_payload(envelope)
	)
	assert_int(back_log.size()).is_equal(2)
	assert_str(str(back_log.commands()[0]["type"])).is_equal("fuse")


func test_checksum_detects_tamper() -> void:
	var ctx := _sample_context()
	var envelope := SaveEnvelopeScript.parse_json(SaveEnvelopeScript.build_json(ctx.to_dict()))
	assert_bool(SaveEnvelopeScript.verify_checksum(envelope)).is_true()
	# Mutate the body without recomputing the checksum -> verification fails.
	(envelope["run"] as Dictionary)["drachma"] = 99999
	assert_bool(SaveEnvelopeScript.verify_checksum(envelope)).is_false()


func test_parse_refuses_future_save() -> void:
	var future := SaveEnvelopeScript.build_dict({"run_id": "r"})
	(future["header"] as Dictionary)["save_version"] = SaveEnvelopeScript.SAVE_VERSION + 5
	var json := JSON.stringify(future)
	# A save newer than this build is refused (downgrade), returns {}.
	assert_dict(SaveEnvelopeScript.parse_json(json)).is_empty()
