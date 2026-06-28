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
## save_version conflict (TDD §10.3): `save_run` enforces the SOLE conflict key. The robust
## path is an atomic compare-and-swap in Postgres (an RPC: update ... where save_version =
## base returning save_version). Until that RPC ships we do a read-check-write here and DOCUMENT
## the race window below. This implementation is exercised by `dal_contract_test.gd` against a
## SCRIPTED FAKE GATEWAY (emulating PostgREST return=representation) under the same shared
## save/sequential/stale-conflict/list_shareable assertions as the FakeDal — so both conflict
## implementations are actually tested, not just one.
##
## KNOWN DIVERGENCE (P3, pending the atomic CAS RPC): on the UPDATE path a concurrent writer that
## advanced save_version between our read and write is caught (the optimistic `where save_version =
## server_version` guard returns no rows -> CONFLICT). On the INSERT path (a brand-new run) two
## concurrent creates race; the loser hits the PK/unique constraint and the gateway surfaces an
## empty result, which we report as ERROR (not CONFLICT). The fix is the same atomic RPC; a lost
## concurrent create is vanishingly rare for client-generated run ids.

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

	## Compare-and-swap on save_version (TDD §10.3). Reads the current version; if it differs
	## from `base_save_version` the store moved on -> CONFLICT (no overwrite). Otherwise writes
	## with save_version = base + 1. NOTE: the read-check-write below has a race window between
	## clients; the production hardening is an atomic Postgres RPC (see class doc) — swap the
	## body for `_gateway.rpc("save_run_cas", ...)` when it lands, no caller change.
	func save_run(aggregate: Dictionary, base_save_version: int) -> SaveResult:
		var run_id := str(aggregate.get("run_id", ""))
		if run_id == "":
			return SaveResultScript.error("save_run: aggregate has no run_id.")
		var existing: Array = await _gateway.select(
			"runs", {"id": run_id}, PackedStringArray(["save_version"])
		)
		var is_new := existing.is_empty()
		var server_version := 0
		if not is_new:
			server_version = int((existing[0] as Dictionary).get("save_version", 0))
			if base_save_version != server_version:
				return SaveResultScript.conflict(server_version, base_save_version)
		var new_version := server_version + 1
		var row := _to_runs_row(aggregate)
		row["save_version"] = new_version
		if is_new:
			var inserted: Array = await _gateway.insert("runs", row)
			if inserted.is_empty():
				return SaveResultScript.error("save_run: insert returned no row.")
		else:
			var updated: Array = await _gateway.update(
				"runs", {"id": run_id, "save_version": server_version}, row
			)
			# An empty update result means the WHERE (incl. save_version) matched nothing — a
			# concurrent writer advanced the version between our read and write: CONFLICT.
			if updated.is_empty():
				var now: int = await current_save_version(run_id)
				return SaveResultScript.conflict(now, base_save_version)
		return SaveResultScript.ok(new_version)

	## Projects the aggregate dict onto the `runs` table columns (drops embedded children,
	## which live in their own tables / the local snapshot). Data only.
	static func _to_runs_row(aggregate: Dictionary) -> Dictionary:
		var row := {}
		for col in [
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
