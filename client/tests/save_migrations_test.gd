extends GdUnitTestSuite
## Phase 3 (ADR-005, TDD §10.2): the forward-only migration chain never strands a save. A
## synthetic OLD-version (v0) save migrates up to the current SaveEnvelope.SAVE_VERSION and
## then parses + loads as a RunContext. The example v0->v1 migration renames a legacy field.

const SaveMigrationsScript := preload("res://application/persistence/save_migrations.gd")
const SaveEnvelopeScript := preload("res://application/persistence/save_envelope.gd")
const RunContextScript := preload("res://application/persistence/run_context.gd")


## A hand-rolled v0 envelope (predates the current shape): save_version 0 + the legacy
## `zenny` currency field (no `drachma`).
func _legacy_v0_envelope() -> Dictionary:
	return {
		"header":
		{"save_version": 0, "schema_version": 1, "app_version": "0.0.1", "section": "run"},
		"run": {"run_id": "run-old", "rank": "Mortal", "zenny": 250},
		"narrative": {},
		"ink": {"story_state": ""},
		"command_log": {},
	}


func test_envelope_version_mirrors_migration_target() -> void:
	# The envelope's SAVE_VERSION must equal the chain's target, else a fresh save would not
	# be "current" and would needlessly re-migrate (or strand) on load.
	assert_int(SaveEnvelopeScript.SAVE_VERSION).is_equal(SaveMigrationsScript.CURRENT_VERSION)


func test_v0_is_not_current() -> void:
	assert_bool(SaveMigrationsScript.is_current(_legacy_v0_envelope())).is_false()


func test_chain_migrates_v0_to_current() -> void:
	var migrated := SaveMigrationsScript.migrate(_legacy_v0_envelope())
	var header: Dictionary = migrated["header"]
	assert_int(int(header["save_version"])).is_equal(SaveEnvelopeScript.SAVE_VERSION)
	# The field-rename example applied: zenny -> drachma.
	var run: Dictionary = migrated["run"]
	assert_bool(run.has("zenny")).is_false()
	assert_int(int(run["drachma"])).is_equal(250)
	assert_bool(SaveMigrationsScript.is_current(migrated)).is_true()


func test_migration_is_idempotent_on_current_save() -> void:
	# A current-version envelope passes through untouched (no migrator runs).
	var current := SaveEnvelopeScript.build_dict({"run_id": "run-now", "drachma": 10})
	var out := SaveMigrationsScript.migrate(current)
	assert_int(int((out["header"] as Dictionary)["save_version"])).is_equal(
		SaveEnvelopeScript.SAVE_VERSION
	)
	assert_int(int((out["run"] as Dictionary)["drachma"])).is_equal(10)


func test_old_save_loads_through_parse_after_migration() -> void:
	# End-to-end: a v0 JSON string parses (which runs the chain) into a usable RunContext.
	var json := JSON.stringify(_legacy_v0_envelope())
	var envelope := SaveEnvelopeScript.parse_json(json)
	assert_dict(envelope).is_not_empty()
	assert_int(int((envelope["header"] as Dictionary)["save_version"])).is_equal(
		SaveEnvelopeScript.SAVE_VERSION
	)
	var ctx: RunContext = RunContextScript.from_dict(SaveEnvelopeScript.run_payload(envelope))
	assert_str(ctx.run_id).is_equal("run-old")
	assert_int(ctx.drachma).is_equal(250)


func test_v0_with_valid_checksum_migrates_and_stays_verified() -> void:
	# A v0 fixture that carries a VALID v0 checksum must (a) pass the on-load corruption gate
	# against its own body, (b) migrate to current, and (c) come out internally consistent —
	# parse_json recomputes the checksum from the migrated body, so verify_checksum(result) holds.
	var v0 := _legacy_v0_envelope()
	var body := {
		"run": v0["run"],
		"narrative": v0["narrative"],
		"ink": v0["ink"],
		"command_log": v0["command_log"],
	}
	(v0["header"] as Dictionary)["checksum"] = SaveEnvelopeScript.checksum_of(body)

	var envelope := SaveEnvelopeScript.parse_json(JSON.stringify(v0))
	assert_dict(envelope).is_not_empty()
	assert_int(int((envelope["header"] as Dictionary)["save_version"])).is_equal(
		SaveEnvelopeScript.SAVE_VERSION
	)
	# The migration renamed zenny -> drachma; the recomputed checksum matches the NEW body.
	assert_bool(SaveEnvelopeScript.verify_checksum(envelope)).is_true()
	var ctx: RunContext = RunContextScript.from_dict(SaveEnvelopeScript.run_payload(envelope))
	assert_int(ctx.drachma).is_equal(250)
