class_name SupabaseGateway
extends RefCounted
## The SINGLE place the vendored Supabase addon is touched (ADR-004). Every DB read/write the
## DAL performs goes through this gateway; nothing else in the codebase references the
## `Supabase` autoload, its `database`, or `SupabaseQuery`. This keeps the addon's maturity
## risk (Realtime edge cases, async task signals) contained behind one seam, and lets the DAL
## be unit-tested with a fake gateway offline.
##
## ADR-004 also permits a PostgREST fallback if an addon feature lags — that fallback would
## live HERE (an HTTPRequest path), behind the same method surface, with no DAL changes.
##
## The addon's `database.query(...)` returns a `DatabaseTask` that completes asynchronously
## and the addon emits `selected/inserted/updated/...`. These methods expose an `await`-able
## surface so repositories read as straight-line code. They return plain Arrays/Dictionaries
## (data only, ADR-012) — never addon objects leak past this class.
##
## Phase 3 NOTE: this gateway is the live-stack seam. It is exercised against the running
## Supabase stack (the addon autoload must be present); offline unit tests use FakeDal instead
## of going through here, so the test suite needs neither the addon nor the network.


## Returns the addon's `Supabase.database` node, or null if the autoload is absent (headless
## tests, or before the addon is installed). Callers must null-check.
static func _db() -> Object:
	var supabase: Object = _autoload("Supabase")
	if supabase == null:
		return null
	return supabase.get("database")


## SELECT rows from `table` matching `eq` (column -> value). Returns an Array of row dicts.
## `await`-able: awaits the addon task and returns its data (or [] on error/absent addon).
func select(
	table: String, eq: Dictionary = {}, select_cols: PackedStringArray = PackedStringArray(["*"])
) -> Array:
	var db: Object = _db()
	if db == null:
		push_error("SupabaseGateway.select: Supabase addon not available.")
		return []
	var query := _new_query()
	if query == null:
		return []
	query.from(table).select(select_cols)
	for col in eq:
		query.eq(str(col), str(eq[col]))
	var task: Object = db.query(query)
	var data: Variant = await _await_task(task)
	return data if data is Array else []


## INSERT a single row dict; returns the inserted row(s) representation (Array of dicts).
func insert(table: String, row: Dictionary) -> Array:
	var db: Object = _db()
	if db == null:
		push_error("SupabaseGateway.insert: Supabase addon not available.")
		return []
	var query := _new_query()
	if query == null:
		return []
	query.from(table).insert([row])
	var task: Object = db.query(query)
	var data: Variant = await _await_task(task)
	return data if data is Array else []


## UPDATE rows of `table` matching `eq` with `changes`; returns the updated row(s).
func update(table: String, eq: Dictionary, changes: Dictionary) -> Array:
	var db: Object = _db()
	if db == null:
		push_error("SupabaseGateway.update: Supabase addon not available.")
		return []
	var query := _new_query()
	if query == null:
		return []
	query.from(table)
	for col in eq:
		query.eq(str(col), str(eq[col]))
	query.update(changes)
	var task: Object = db.query(query)
	var data: Variant = await _await_task(task)
	return data if data is Array else []


## Calls a Postgres RPC (used for atomic save_version compare-and-swap; see DAL notes).
func rpc(function_name: String, args: Dictionary = {}) -> Variant:
	var db: Object = _db()
	if db == null:
		push_error("SupabaseGateway.rpc: Supabase addon not available.")
		return null
	var task: Object = db.Rpc(function_name, args)
	return await _await_task(task)


# --- addon plumbing (the ONLY addon-shaped code in the project) -------------- #


## Constructs a fresh SupabaseQuery via the addon script. Returns null if the script is absent.
## (SupabaseQuery is an addon `class_name`; we load the script so this file never hard-binds to
## the addon symbol — keeps a clean parse even before the addon is installed.)
func _new_query() -> Object:
	var query_script: Resource = load("res://addons/supabase/Database/query.gd")
	if query_script == null:
		push_error("SupabaseGateway: SupabaseQuery script missing.")
		return null
	return query_script.new()


## Awaits a DatabaseTask's `completed` signal and returns its `.data` (or null). The addon
## task exposes a `completed(task)` signal and a `data` property; we never expose the task
## itself past this gateway (data only, ADR-012).
func _await_task(task: Object) -> Variant:
	if task == null:
		return null
	if task.has_signal("completed"):
		await task.completed
	return task.get("data")


static func _autoload(node_name: String) -> Object:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		var tree := loop as SceneTree
		if tree.root != null and tree.root.has_node(node_name):
			return tree.root.get_node(node_name)
	return null
