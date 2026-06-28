extends GdUnitTestSuite
## Phase 3 (ADR-004, TDD §10.3): the DAL contract, run against BOTH implementations — the
## in-memory FakeDal AND the Supabase-backed DAL (the latter over a SCRIPTED FAKE GATEWAY that
## emulates PostgREST return=representation). The two conflict implementations are independent,
## so the shared assertions (save/sequential/stale-conflict/list_shareable newest-first) run on
## each. Everything runs OFFLINE (no real addon, no network).
##
## save_run/load_run/etc. are awaited uniformly: the Supabase repos are coroutines (they await
## the gateway); the fakes return directly, and `await <value>` yields the value unchanged — so
## one helper body drives both transports.

const FakeDalScript := preload("res://infrastructure/dal/fake_dal.gd")
const SupabaseDalScript := preload("res://infrastructure/dal/supabase_dal.gd")
const RepositoriesScript := preload("res://infrastructure/dal/repositories.gd")
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


# ---------------------------------------------------------------------------- #
# Scripted fake gateway: matches SupabaseGateway's select/insert/update surface with
# PostgREST-style semantics (typed eq match, return=representation, optional order DESC).
# ---------------------------------------------------------------------------- #
class ScriptedGateway:
	extends RefCounted

	# table -> Array of row dicts.
	var _tables: Dictionary = {}
	var _seq: int = 0

	func _rows(table: String) -> Array:
		if not _tables.has(table):
			_tables[table] = []
		return _tables[table]

	func _matches(row: Dictionary, eq: Dictionary) -> bool:
		for col in eq:
			if row.get(col, null) != eq[col]:
				return false
		return true

	func select(
		table: String,
		eq: Dictionary = {},
		_select_cols: PackedStringArray = PackedStringArray(["*"]),
		order_by: Array = []
	) -> Array:
		var out: Array = []
		for row in _rows(table):
			if _matches(row, eq):
				out.append((row as Dictionary).duplicate(true))
		if order_by.size() >= 1:
			var key := str(order_by[0])
			var descending: bool = order_by.size() >= 2 and bool(order_by[1])
			out.sort_custom(
				func(a: Dictionary, b: Dictionary) -> bool:
					if descending:
						return int(a.get(key, 0)) > int(b.get(key, 0))
					return int(a.get(key, 0)) < int(b.get(key, 0))
			)
		return out

	func insert(table: String, row: Dictionary) -> Array:
		var stored: Dictionary = row.duplicate(true)
		# Emulate created_at ordering with a monotonic counter the server would assign.
		_seq += 1
		if not stored.has("created_at"):
			stored["created_at"] = _seq
		_rows(table).append(stored)
		return [stored.duplicate(true)]

	func update(table: String, eq: Dictionary, changes: Dictionary) -> Array:
		var updated: Array = []
		for row in _rows(table):
			if _matches(row, eq):
				for k in changes:
					(row as Dictionary)[k] = changes[k]
				updated.append((row as Dictionary).duplicate(true))
		return updated


## Returns the two DAL sets to test: the fake, and the Supabase DAL over a scripted gateway.
func _both_dals() -> Array:
	return [FakeDalScript.make(), SupabaseDalScript.make(ScriptedGateway.new())]


# ---------------------------------------------------------------------------- #
# Shared assertions (run against each impl).
# ---------------------------------------------------------------------------- #
func _assert_save_then_load(dal: Dictionary, label: String) -> void:
	var runs: RepositoriesScript.RunRepository = dal["runs"]
	var result: SaveResult = await runs.save_run(_aggregate("run-1", 300), 0)
	assert_bool(result.is_ok()).override_failure_message("[%s] new save ok" % label).is_true()
	assert_int(result.save_version).is_equal(1)

	var loaded: Dictionary = await runs.load_run("run-1")
	assert_dict(loaded).is_not_empty()
	var ctx: RunContext = RunContextScript.from_dict(loaded)
	assert_str(ctx.run_id).override_failure_message("[%s] run_id round-trips" % label).is_equal(
		"run-1"
	)
	assert_int(ctx.drachma).is_equal(300)
	assert_int(ctx.save_version).is_equal(1)  # store stamped the accepted version


func _assert_sequential_saves(dal: Dictionary, label: String) -> void:
	var runs: RepositoriesScript.RunRepository = dal["runs"]
	var first: SaveResult = await runs.save_run(_aggregate("run-2", 1), 0)
	assert_int(first.save_version).override_failure_message("[%s] v1" % label).is_equal(1)
	var second: SaveResult = await runs.save_run(_aggregate("run-2", 2), 1)
	assert_bool(second.is_ok()).is_true()
	assert_int(second.save_version).is_equal(2)
	var cur: int = await runs.current_save_version("run-2")
	assert_int(cur).is_equal(2)


func _assert_stale_is_conflict(dal: Dictionary, label: String) -> void:
	var runs: RepositoriesScript.RunRepository = dal["runs"]
	await runs.save_run(_aggregate("run-3", 10), 0)  # -> v1
	await runs.save_run(_aggregate("run-3", 20), 1)  # -> v2
	# Stale base (still believes v1) -> CONFLICT, not overwrite.
	var stale: SaveResult = await runs.save_run(_aggregate("run-3", 999), 1)
	(
		assert_bool(stale.is_conflict())
		. override_failure_message("[%s] stale -> conflict" % label)
		. is_true()
	)
	assert_int(stale.server_version).is_equal(2)
	var ctx: RunContext = RunContextScript.from_dict(await runs.load_run("run-3"))
	assert_int(ctx.drachma).override_failure_message("[%s] not overwritten" % label).is_equal(20)
	assert_int(ctx.save_version).is_equal(2)


func _assert_list_shareable_newest_first(dal: Dictionary, label: String) -> void:
	var snapshots: RepositoriesScript.GodSnapshotRepository = dal["snapshots"]
	# Publish with shareable=true explicitly: the live DB column defaults it (0001_init.sql), but
	# the scripted gateway does not emulate DB defaults, so we set it for impl-agnostic behavior.
	await snapshots.publish({"name": "first", "shareable": true})
	await snapshots.publish({"name": "second", "shareable": true})
	await snapshots.publish({"name": "third", "shareable": true})
	var listed: Array = await snapshots.list_shareable(20)
	assert_int(listed.size()).override_failure_message("[%s] all 3 listed" % label).is_equal(3)
	# Newest-first (contract in repositories.gd): last published comes first.
	assert_str(str((listed[0] as Dictionary).get("name", ""))).is_equal("third")
	assert_str(str((listed[2] as Dictionary).get("name", ""))).is_equal("first")
	# Cap honored.
	var capped: Array = await snapshots.list_shareable(2)
	assert_int(capped.size()).is_equal(2)
	assert_str(str((capped[0] as Dictionary).get("name", ""))).is_equal("third")


# ---------------------------------------------------------------------------- #
# Contract tests — each runs the shared assertion against BOTH impls.
# ---------------------------------------------------------------------------- #
func test_save_then_load_returns_equal_aggregate() -> void:
	var labels := ["FakeDal", "SupabaseDal"]
	var dals := _both_dals()
	for i in dals.size():
		await _assert_save_then_load(dals[i], labels[i])


func test_sequential_saves_advance_version() -> void:
	var labels := ["FakeDal", "SupabaseDal"]
	var dals := _both_dals()
	for i in dals.size():
		await _assert_sequential_saves(dals[i], labels[i])


func test_stale_save_version_is_conflict_not_overwrite() -> void:
	var labels := ["FakeDal", "SupabaseDal"]
	var dals := _both_dals()
	for i in dals.size():
		await _assert_stale_is_conflict(dals[i], labels[i])


func test_list_shareable_is_newest_first_and_capped() -> void:
	var labels := ["FakeDal", "SupabaseDal"]
	var dals := _both_dals()
	for i in dals.size():
		await _assert_list_shareable_newest_first(dals[i], labels[i])


# ---------------------------------------------------------------------------- #
# Fake-only tests (creature CRUD, snapshot fetch, catalog isolation).
# ---------------------------------------------------------------------------- #
func test_creature_instance_repo_round_trip() -> void:
	var dal := FakeDalScript.make()
	var creatures: RepositoriesScript.CreatureInstanceRepository = dal["creatures"]
	var id1: String = creatures.upsert(
		{"id": "ci-1", "run_id": "run-4", "species_id": "AD01", "is_dead": false, "lineage": {}}
	)
	creatures.upsert(
		{"id": "ci-2", "run_id": "run-4", "species_id": "AD02", "is_dead": true, "lineage": {}}
	)
	assert_str(id1).is_equal("ci-1")
	assert_int(creatures.list_for_run("run-4").size()).is_equal(2)
	assert_int(creatures.list_for_run("run-4", false).size()).is_equal(1)  # excludes dead
	var inst: Dictionary = creatures.get_instance("ci-1")
	assert_str(str(inst.get("species_id", ""))).is_equal("AD01")


func test_god_snapshot_publish_fetch() -> void:
	var dal := FakeDalScript.make()
	var snapshots: RepositoriesScript.GodSnapshotRepository = dal["snapshots"]
	var sid: String = snapshots.publish({"name": "The Rust King", "grid": "Order / Corrupt"})
	assert_str(sid).is_not_empty()
	var fetched: Dictionary = snapshots.fetch(sid)
	assert_str(str(fetched.get("name", ""))).is_equal("The Rust King")
	assert_bool(bool(fetched.get("shareable", false))).is_true()  # defaults shareable


func test_catalog_reads_bundled_json() -> void:
	var dal := FakeDalScript.make()
	var catalog: RepositoriesScript.CatalogRepository = dal["catalog"]
	# The catalog is the single source of truth (ADR-006); these are the bundled files.
	assert_bool(catalog.species().size() > 0).is_true()
	assert_int(catalog.gear().size()).is_equal(6)
	assert_int(catalog.skills().size()).is_equal(12)
	assert_int(catalog.factions().size()).is_equal(9)
	# Lookup by id within a kind.
	var horn: Dictionary = catalog.by_id("gear", "beastcaller_s_horn")
	assert_str(str(horn.get("name", ""))).is_equal("Beastcaller's Horn")


func test_catalog_accessor_returns_copy_not_shared_cache() -> void:
	# Mutating a returned catalog array must NOT corrupt the shared cache (Codex finding).
	var catalog: RepositoriesScript.CatalogRepository = FakeDalScript.FakeCatalogRepository.new()
	var first_call: Array = catalog.gear()
	var original_size := first_call.size()
	first_call.append({"id": "INJECTED"})
	first_call.clear()
	var second_call: Array = catalog.gear()
	assert_int(second_call.size()).is_equal(original_size)
