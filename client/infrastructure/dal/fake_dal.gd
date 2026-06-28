class_name FakeDal
extends RefCounted
## In-memory FAKE of the DAL repositories (ADR-004). Keeps everything unit-testable OFFLINE:
## no addon, no network, no SceneTree. The save_version conflict logic (TDD §10.3) is
## implemented here exactly as the real store must behave. The DAL-contract test runs the SAME
## assertions against BOTH this fake AND the Supabase implementation (the latter via a scripted
## fake gateway), so the two independent conflict implementations are both verified.
##
## Each inner class extends the matching interface in `repositories.gd`. A `FakeStore` holds
## the shared state so the repositories see a consistent world (one run aggregate, its
## instances, snapshots). The catalog fake reads the same `client/catalog/*.json` files as
## production (single source of truth, ADR-006).

const RepositoriesScript := preload("res://infrastructure/dal/repositories.gd")
const SaveResultScript := preload("res://infrastructure/dal/save_result.gd")


## Builds a full set of fakes over one shared store (mirrors SupabaseDal.make). The `store`
## is returned too so a test can inspect/seed it directly.
static func make() -> Dictionary:
	var store := FakeStore.new()
	return {
		"store": store,
		"runs": FakeRunRepository.new(store),
		"creatures": FakeCreatureInstanceRepository.new(store),
		"snapshots": FakeGodSnapshotRepository.new(store),
		"catalog": FakeCatalogRepository.new(),
	}


## Shared in-memory state for the fakes.
class FakeStore:
	extends RefCounted

	## run_id -> aggregate dict (the stored RunContext.to_dict()).
	var runs: Dictionary = {}
	## run_id -> current save_version (the store's authoritative counter).
	var versions: Dictionary = {}
	## instance_id -> instance dict.
	var instances: Dictionary = {}
	## snapshot_id -> snapshot dict.
	var snapshots: Dictionary = {}
	## Monotonic counter for ordering shareable snapshots newest-first (created_at DESC analogue).
	var snapshot_publish_seq: int = 0
	var _snapshot_seq: int = 0

	func next_snapshot_id() -> String:
		_snapshot_seq += 1
		return "snap-%d" % _snapshot_seq


class FakeRunRepository:
	extends RepositoriesScript.RunRepository

	var _store: FakeStore

	func _init(store: FakeStore) -> void:
		_store = store

	func load_run(run_id: String) -> Dictionary:
		var stored: Dictionary = _store.runs.get(run_id, {})
		return stored.duplicate(true)

	func current_save_version(run_id: String) -> int:
		return int(_store.versions.get(run_id, 0))

	## Conflict rule (TDD §10.3): the write is accepted ONLY if the caller's base version
	## equals the store's current version (or the run is brand-new). Otherwise the store has
	## moved on -> CONFLICT (the caller rebases). On accept the store bumps the version and
	## stamps it onto the stored aggregate.
	func save_run(aggregate: Dictionary, base_save_version: int) -> SaveResult:
		var run_id := str(aggregate.get("run_id", ""))
		if run_id == "":
			return SaveResultScript.error("save_run: aggregate has no run_id.")
		var server_version := int(_store.versions.get(run_id, 0))
		var is_new := not _store.runs.has(run_id)
		if not is_new and base_save_version != server_version:
			return SaveResultScript.conflict(server_version, base_save_version)
		var new_version := server_version + 1
		var to_store := aggregate.duplicate(true)
		to_store["save_version"] = new_version
		_store.runs[run_id] = to_store
		_store.versions[run_id] = new_version
		return SaveResultScript.ok(new_version)


class FakeCreatureInstanceRepository:
	extends RepositoriesScript.CreatureInstanceRepository

	var _store: FakeStore

	func _init(store: FakeStore) -> void:
		_store = store

	func list_for_run(run_id: String, include_dead: bool = true) -> Array:
		var out: Array = []
		for instance_id in _store.instances:
			var inst: Dictionary = _store.instances[instance_id]
			if str(inst.get("run_id", "")) != run_id:
				continue
			if not include_dead and bool(inst.get("is_dead", false)):
				continue
			out.append(inst.duplicate(true))
		return out

	func get_instance(instance_id: String) -> Dictionary:
		var inst: Dictionary = _store.instances.get(instance_id, {})
		return inst.duplicate(true)

	func upsert(instance: Dictionary) -> String:
		var instance_id := str(instance.get("id", ""))
		if instance_id == "":
			instance_id = "ci-%d" % (_store.instances.size() + 1)
		var to_store := instance.duplicate(true)
		to_store["id"] = instance_id
		_store.instances[instance_id] = to_store
		return instance_id


class FakeGodSnapshotRepository:
	extends RepositoriesScript.GodSnapshotRepository

	var _store: FakeStore

	func _init(store: FakeStore) -> void:
		_store = store

	func publish(snapshot: Dictionary) -> String:
		var snapshot_id := str(snapshot.get("id", ""))
		if snapshot_id == "":
			snapshot_id = _store.next_snapshot_id()
		var to_store := snapshot.duplicate(true)
		to_store["id"] = snapshot_id
		if not to_store.has("shareable"):
			to_store["shareable"] = true
		# Stamp a monotonic publish seq so list_shareable can return newest-first deterministically
		# (mirrors created_at DESC on the live store).
		_store.snapshot_publish_seq += 1
		to_store["_publish_seq"] = _store.snapshot_publish_seq
		_store.snapshots[snapshot_id] = to_store
		return snapshot_id

	func fetch(snapshot_id: String) -> Dictionary:
		var snap: Dictionary = _store.snapshots.get(snapshot_id, {})
		return snap.duplicate(true)

	## Newest-first (the contract in repositories.gd), capped at `limit`. Sorts by the monotonic
	## publish seq descending — equivalent to created_at DESC on the live store.
	func list_shareable(limit: int = 20) -> Array:
		var shareable: Array = []
		for snapshot_id in _store.snapshots:
			var snap: Dictionary = _store.snapshots[snapshot_id]
			if bool(snap.get("shareable", false)):
				shareable.append(snap.duplicate(true))
		shareable.sort_custom(
			func(a: Dictionary, b: Dictionary) -> bool:
				return int(a.get("_publish_seq", 0)) > int(b.get("_publish_seq", 0))
		)
		return shareable.slice(0, limit) if shareable.size() > limit else shareable


## Reads the same catalog JSON as production (ADR-006 single source of truth). Lazy-loads and
## caches each kind. Used by both the fake and the real DAL (catalog is local, not networked).
class FakeCatalogRepository:
	extends RepositoriesScript.CatalogRepository

	const CATALOG_DIR := "res://catalog"
	# kind -> (file basename, top-level array key inside that JSON).
	const FILES := {
		"species": ["species.json", "species"],
		"gear": ["gear.json", "gear"],
		"skills": ["skills.json", "skills"],
		"factions": ["factions.json", "factions"],
	}

	var _cache: Dictionary = {}

	# Each accessor returns a DEEP COPY so a caller cannot mutate the shared cache (Codex finding).
	func species() -> Array:
		return _load("species").duplicate(true)

	func gear() -> Array:
		return _load("gear").duplicate(true)

	func skills() -> Array:
		return _load("skills").duplicate(true)

	func factions() -> Array:
		return _load("factions").duplicate(true)

	func by_id(kind: String, id: String) -> Dictionary:
		for entry in _load(kind):
			if entry is Dictionary and str((entry as Dictionary).get("id", "")) == id:
				return (entry as Dictionary).duplicate(true)
		return {}

	func _load(kind: String) -> Array:
		if _cache.has(kind):
			return _cache[kind]
		if not FILES.has(kind):
			push_error("FakeCatalogRepository: unknown catalog kind '%s'." % kind)
			return []
		var spec: Array = FILES[kind]
		var path := "%s/%s" % [CATALOG_DIR, str(spec[0])]
		var array_key := str(spec[1])
		var text := ""
		if FileAccess.file_exists(path):
			var file := FileAccess.open(path, FileAccess.READ)
			if file != null:
				text = file.get_as_text()
				file.close()
		var parsed: Variant = JSON.parse_string(text) if text != "" else null
		var result: Array = []
		if parsed is Dictionary and (parsed as Dictionary).has(array_key):
			var raw: Variant = (parsed as Dictionary)[array_key]
			if raw is Array:
				result = raw
		_cache[kind] = result
		return result
