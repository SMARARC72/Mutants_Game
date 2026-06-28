extends GdUnitTestSuite
## Phase 3 (ADR-004, TDD §10.3): the DAL contract, exercised against the in-memory FAKE so it
## runs OFFLINE (no addon, no network). Save-then-load returns an equal aggregate; a save whose
## base save_version is STALE is reported as a CONFLICT, never silently overwritten; the catalog
## repository reads the bundled JSON (ADR-006). The Supabase-backed DAL implements the same
## contract over the gateway (see supabase_dal.gd).

const FakeDalScript := preload("res://infrastructure/dal/fake_dal.gd")
const SaveResultScript := preload("res://infrastructure/dal/save_result.gd")
const RunContextScript := preload("res://application/persistence/run_context.gd")


func _aggregate(run_id: String, drachma: int) -> Dictionary:
	var ctx: RunContext = RunContextScript.new()
	ctx.run_id = run_id
	ctx.player_id = "player-1"
	ctx.seed = 42
	ctx.drachma = drachma
	ctx.rank = "Mortal"
	ctx.party = [{"id": "ci-1", "species_id": "AD01", "lineage": {}, "is_dead": false}]
	return ctx.to_dict()


func test_save_then_load_returns_equal_aggregate() -> void:
	var dal := FakeDalScript.make()
	var runs = dal["runs"]
	# First save of a brand-new run: base version 0 -> accepted, store bumps to 1.
	var result: SaveResult = runs.save_run(_aggregate("run-1", 300), 0)
	assert_bool(result.is_ok()).is_true()
	assert_int(result.save_version).is_equal(1)

	var loaded := runs.load_run("run-1")
	assert_dict(loaded).is_not_empty()
	var ctx: RunContext = RunContextScript.from_dict(loaded)
	assert_str(ctx.run_id).is_equal("run-1")
	assert_int(ctx.drachma).is_equal(300)
	assert_int(ctx.save_version).is_equal(1)  # store stamped the accepted version
	assert_int(ctx.party_size()).is_equal(1)


func test_sequential_saves_advance_version() -> void:
	var dal := FakeDalScript.make()
	var runs = dal["runs"]
	var first: SaveResult = runs.save_run(_aggregate("run-2", 1), 0)
	assert_int(first.save_version).is_equal(1)
	# Save again with the correct base (1) -> accepted, advances to 2.
	var second: SaveResult = runs.save_run(_aggregate("run-2", 2), 1)
	assert_bool(second.is_ok()).is_true()
	assert_int(second.save_version).is_equal(2)
	assert_int(runs.current_save_version("run-2")).is_equal(2)


func test_stale_save_version_is_conflict_not_overwrite() -> void:
	var dal := FakeDalScript.make()
	var runs = dal["runs"]
	runs.save_run(_aggregate("run-3", 10), 0)  # version -> 1
	runs.save_run(_aggregate("run-3", 20), 1)  # version -> 2

	# A client that still believes the base is 1 (stale) tries to write -> CONFLICT.
	var stale: SaveResult = runs.save_run(_aggregate("run-3", 999), 1)
	assert_bool(stale.is_conflict()).is_true()
	assert_int(stale.server_version).is_equal(2)
	# The store was NOT overwritten: the conflicting drachma=999 was rejected.
	var ctx: RunContext = RunContextScript.from_dict(runs.load_run("run-3"))
	assert_int(ctx.drachma).is_equal(20)
	assert_int(ctx.save_version).is_equal(2)


func test_creature_instance_repo_round_trip() -> void:
	var dal := FakeDalScript.make()
	var creatures = dal["creatures"]
	var id1: String = creatures.upsert(
		{"id": "ci-1", "run_id": "run-4", "species_id": "AD01", "is_dead": false, "lineage": {}}
	)
	creatures.upsert(
		{"id": "ci-2", "run_id": "run-4", "species_id": "AD02", "is_dead": true, "lineage": {}}
	)
	assert_str(id1).is_equal("ci-1")
	assert_int(creatures.list_for_run("run-4").size()).is_equal(2)
	assert_int(creatures.list_for_run("run-4", false).size()).is_equal(1)  # excludes dead
	assert_str(str(creatures.get_instance("ci-1").get("species_id", ""))).is_equal("AD01")


func test_god_snapshot_publish_fetch() -> void:
	var dal := FakeDalScript.make()
	var snapshots = dal["snapshots"]
	var sid: String = snapshots.publish({"name": "The Rust King", "grid": "Order / Corrupt"})
	assert_str(sid).is_not_empty()
	var fetched := snapshots.fetch(sid)
	assert_str(str(fetched.get("name", ""))).is_equal("The Rust King")
	assert_bool(bool(fetched.get("shareable", false))).is_true()  # defaults shareable
	assert_int(snapshots.list_shareable().size()).is_equal(1)


func test_catalog_reads_bundled_json() -> void:
	var dal := FakeDalScript.make()
	var catalog = dal["catalog"]
	# The catalog is the single source of truth (ADR-006); these are the bundled files.
	assert_bool(catalog.species().size() > 0).is_true()
	assert_int(catalog.gear().size()).is_equal(6)
	assert_int(catalog.skills().size()).is_equal(12)
	assert_int(catalog.factions().size()).is_equal(9)
	# Lookup by id within a kind.
	var horn := catalog.by_id("gear", "beastcaller_s_horn")
	assert_str(str(horn.get("name", ""))).is_equal("Beastcaller's Horn")
