class_name SupabaseDal
extends RefCounted
## Supabase-backed DAL (ADR-004): the repositories that talk to the live store, ALWAYS through
## `SupabaseGateway` (the single addon seam). The Domain layer never sees this — Application
## services pick a repository implementation (this for online, FakeDal for tests).
##
## The methods are `await`-able because the addon is async. They map run/instance/snapshot
## dicts to/from the `runs`, `creature_instances`, `god_snapshots` tables and read the catalog
## locally (catalog is bundled JSON, not networked — see CatalogRepository: we reuse the fake's
## file reader since it IS the production reader, ADR-006).
##
## save_version conflict (TDD §10.3): `save_run` uses the database `save_run_cas` RPC so create,
## compare, version bump, and write occur in one transaction under RLS. This implementation is
## exercised by `dal_contract_test.gd` against a SCRIPTED FAKE GATEWAY under the same shared
## save/sequential/stale-conflict/list_shareable assertions as the FakeDal — so both conflict
## implementations are actually tested, not just one.

const RepositoriesScript := preload("res://infrastructure/dal/repositories.gd")
const SaveResultScript := preload("res://infrastructure/dal/save_result.gd")
const FakeDalScript := preload("res://infrastructure/dal/fake_dal.gd")
const GatewayScript := preload("res://infrastructure/supabase/supabase_gateway.gd")


class SupabaseRunRepository:
	extends RepositoriesScript.RunRepository

	var _gateway: Object

	func _init(gateway: Object) -> void:
		_gateway = gateway

	func load_run(run_id: String) -> Dictionary:
		var rows: Array = await _gateway.select("runs", {"id": run_id})
		if rows.is_empty():
			return {}
		if not (rows[0] is Dictionary):
			return {}
		# The `runs` row keys its primary key `id`, but the in-memory aggregate / RunContext use
		# `run_id`. Map id -> run_id so the loaded aggregate round-trips through RunContext.
		var aggregate: Dictionary = (rows[0] as Dictionary).duplicate(true)
		if aggregate.has("id") and not aggregate.has("run_id"):
			aggregate["run_id"] = aggregate["id"]
			aggregate.erase("id")
		return aggregate

	func current_save_version(run_id: String) -> int:
		var rows: Array = await _gateway.select(
			"runs", {"id": run_id}, PackedStringArray(["save_version"])
		)
		if rows.is_empty():
			return 0
		var row: Dictionary = rows[0]
		return int(row.get("save_version", 0))

	## Atomic compare-and-swap on save_version. The RPC returns plain data and never silently
	## overwrites a stale or concurrently-created run.
	func save_run(aggregate: Dictionary, base_save_version: int) -> SaveResult:
		var run_id := str(aggregate.get("run_id", ""))
		if run_id == "":
			return SaveResultScript.error("save_run: aggregate has no run_id.")
		var row := _to_runs_row(aggregate)
		var response: Variant = await _gateway.rpc(
			"save_run_cas", {"p_run": row, "p_base_save_version": base_save_version}
		)
		if response is Array and not (response as Array).is_empty():
			response = (response as Array)[0]
		if not (response is Dictionary):
			return SaveResultScript.error("save_run: atomic RPC returned no result.")
		var result := response as Dictionary
		var status := str(result.get("status", "ERROR")).to_upper()
		if status == "OK":
			return SaveResultScript.ok(int(result.get("save_version", 0)))
		if status == "CONFLICT":
			return SaveResultScript.conflict(
				int(result.get("server_version", 0)), base_save_version
			)
		return SaveResultScript.error(str(result.get("message", "save failed")))

	## Projects the aggregate dict onto the `runs` table columns (drops embedded children,
	## which live in their own tables / the local snapshot). Data only.
	static func _to_runs_row(aggregate: Dictionary) -> Dictionary:
		var row := {}
		for col: String in [
			"id",
			"player_id",
			"seed",
			"act",
			"rank",
			"order_chaos",
			"purity_corrupt",
			"notoriety",
			"deeds",
			"corruption",
			"drachma",
			"essence",
			"ichor",
			"gear",
			"god_form",
			"status",
			"schema_version",
		]:
			# `id` is stored under `run_id` in the aggregate; everything else is 1:1.
			var key := "run_id" if col == "id" else col
			if aggregate.has(key):
				row[col] = aggregate[key]
		return row


class SupabaseCreatureInstanceRepository:
	extends RepositoriesScript.CreatureInstanceRepository

	var _gateway: Object

	func _init(gateway: Object) -> void:
		_gateway = gateway

	func list_for_run(run_id: String, include_dead: bool = true) -> Array:
		var rows: Array = await _gateway.select("creature_instances", {"run_id": run_id})
		if include_dead:
			return rows
		var alive: Array = []
		for row in rows:
			if row is Dictionary and not bool((row as Dictionary).get("is_dead", false)):
				alive.append(row)
		return alive

	func get_instance(instance_id: String) -> Dictionary:
		var rows: Array = await _gateway.select("creature_instances", {"id": instance_id})
		if rows.is_empty():
			return {}
		var row: Variant = rows[0]
		return row if row is Dictionary else {}

	func upsert(instance: Dictionary) -> String:
		var instance_id := str(instance.get("id", ""))
		if instance_id == "":
			var inserted: Array = await _gateway.insert("creature_instances", instance)
			if inserted.is_empty():
				return ""
			return str((inserted[0] as Dictionary).get("id", ""))
		var updated: Array = await _gateway.update(
			"creature_instances", {"id": instance_id}, instance
		)
		return instance_id if not updated.is_empty() else ""


class SupabaseGodSnapshotRepository:
	extends RepositoriesScript.GodSnapshotRepository

	var _gateway: Object

	func _init(gateway: Object) -> void:
		_gateway = gateway

	func publish(snapshot: Dictionary) -> String:
		var inserted: Array = await _gateway.insert("god_snapshots", snapshot)
		if inserted.is_empty():
			return ""
		return str((inserted[0] as Dictionary).get("id", ""))

	func fetch(snapshot_id: String) -> Dictionary:
		var rows: Array = await _gateway.select("god_snapshots", {"id": snapshot_id})
		if rows.is_empty():
			return {}
		var row: Variant = rows[0]
		return row if row is Dictionary else {}

	func list_shareable(limit: int = 20) -> Array:
		# RLS already scopes reads to shareable-or-owned; we additionally filter shareable=true.
		# Order by created_at DESC so the result is newest-first (the contract in repositories.gd),
		# matching the FAKE; god_snapshots.created_at exists since 0001_init.sql.
		var rows: Array = await _gateway.select(
			"god_snapshots", {"shareable": true}, PackedStringArray(["*"]), ["created_at", true]
		)
		return rows.slice(0, limit) if rows.size() > limit else rows


## Builds the full set of repositories backed by one gateway. The catalog repository is the
## local file reader (ADR-006 — catalog is bundled, never networked), shared with the fake.
static func make(gateway: Object = null) -> Dictionary:
	var gw: Object = gateway if gateway != null else GatewayScript.new()
	return {
		"runs": SupabaseRunRepository.new(gw),
		"creatures": SupabaseCreatureInstanceRepository.new(gw),
		"snapshots": SupabaseGodSnapshotRepository.new(gw),
		"catalog": FakeDalScript.FakeCatalogRepository.new(),
	}
