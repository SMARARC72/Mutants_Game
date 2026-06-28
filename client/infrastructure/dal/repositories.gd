class_name DalRepositories
extends RefCounted
## Repository INTERFACES for the Data Access Layer (ADR-004). The Domain layer never holds a
## DB handle or imports the addon; ALL store access goes through these thin repositories.
## Two implementations satisfy them: `SupabaseDal*` (wraps the vendored Supabase addon via
## `infrastructure/supabase/`) and `Fake*` (in-memory, for offline unit tests).
##
## GDScript has no `interface` keyword; these are abstract base classes whose methods push an
## error if a subclass forgets to override them. Subclasses `extends` the inner classes here
## (each inner class is also exported as a `class_name`-style preload target).
##
## Conventions:
##   - "run aggregate" = a RunContext.to_dict() dictionary (data only, ADR-012).
##   - writes return a SaveResult (OK / CONFLICT / ERROR); save_version is the SOLE conflict
##     key (TDD §10.3) — a stale base version is a CONFLICT, never a silent overwrite.

const SaveResultScript := preload("res://infrastructure/dal/save_result.gd")


## Loads/saves the run aggregate (the `runs` row + embedded children via RunContext).
class RunRepository:
	extends RefCounted

	## Returns the run aggregate dict for `run_id`, or {} if not found.
	func load_run(_run_id: String) -> Dictionary:
		push_error("RunRepository.load_run not implemented.")
		return {}

	## Persists the aggregate. `base_save_version` is the version the caller LOADED; if the
	## store has advanced past it, return SaveResult.conflict(...) (never overwrite). On
	## success the store bumps save_version and returns SaveResult.ok(new_version).
	func save_run(_aggregate: Dictionary, _base_save_version: int) -> SaveResult:
		push_error("RunRepository.save_run not implemented.")
		return SaveResultScript.error("not implemented")

	## The store's current save_version for a run (0 if unknown). Used for conflict checks.
	func current_save_version(_run_id: String) -> int:
		push_error("RunRepository.current_save_version not implemented.")
		return 0


## Per-instance creature CRUD (mirrors `creature_instances`, incl. `lineage`).
class CreatureInstanceRepository:
	extends RefCounted

	## All instance dicts for a run (optionally only living ones).
	func list_for_run(_run_id: String, _include_dead: bool = true) -> Array:
		push_error("CreatureInstanceRepository.list_for_run not implemented.")
		return []

	func get_instance(_instance_id: String) -> Dictionary:
		push_error("CreatureInstanceRepository.get_instance not implemented.")
		return {}

	## Inserts or updates an instance dict; returns the instance id.
	func upsert(_instance: Dictionary) -> String:
		push_error("CreatureInstanceRepository.upsert not implemented.")
		return ""


## God-snapshot read/write (the Succession; cross-run mythology). Client path only.
class GodSnapshotRepository:
	extends RefCounted

	## Persists a snapshot dict (own only — RLS enforces source_player = uid). Returns id.
	func publish(_snapshot: Dictionary) -> String:
		push_error("GodSnapshotRepository.publish not implemented.")
		return ""

	## Fetches a snapshot by id (must be shareable or owned), or {} if not visible.
	func fetch(_snapshot_id: String) -> Dictionary:
		push_error("GodSnapshotRepository.fetch not implemented.")
		return {}

	## A pool of shareable snapshots (for "invasions"), newest first, capped at `limit`.
	func list_shareable(_limit: int = 20) -> Array:
		push_error("GodSnapshotRepository.list_shareable not implemented.")
		return []


## Read-only catalog access (species / gear / skills / factions). Single source of truth is
## `client/catalog/*.json` (ADR-006); this never writes.
class CatalogRepository:
	extends RefCounted

	func species() -> Array:
		push_error("CatalogRepository.species not implemented.")
		return []

	func gear() -> Array:
		push_error("CatalogRepository.gear not implemented.")
		return []

	func skills() -> Array:
		push_error("CatalogRepository.skills not implemented.")
		return []

	func factions() -> Array:
		push_error("CatalogRepository.factions not implemented.")
		return []

	## Convenience lookup by id within a catalog kind ("species"/"gear"/"skills"/"factions").
	func by_id(_kind: String, _id: String) -> Dictionary:
		push_error("CatalogRepository.by_id not implemented.")
		return {}
