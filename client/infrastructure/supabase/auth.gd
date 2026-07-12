class_name SupabaseAuthPath
extends RefCounted
## Anonymous-first production auth path (ADR-011, TDD section 8.1). Infrastructure only.
## The vendored addon's anonymous task calls GoTrue `/auth/v1/signup` and installs the returned
## access token on `Supabase.auth`; all subsequent gateway requests therefore carry a real JWT.

const GatewayScript := preload("res://infrastructure/supabase/supabase_gateway.gd")

var last_error: String = ""
var _auth_client: Object
var _gateway: Object


func _init(auth_client: Object = null, gateway: Object = null) -> void:
	_auth_client = auth_client
	_gateway = gateway


## Creates a real anonymous auth user, its ownership root, and its initial run. Returns the run id.
## Reusing an already-authenticated client is safe: an existing player row is detected before insert.
func bootstrap_anonymous_run(secure_seed: int) -> String:
	last_error = ""
	var auth_client := _resolve_auth()
	if auth_client == null:
		return _fail(
			"Supabase Auth is unavailable; cloud mode requires configured URL and anon key."
		)
	var user: Object = await _authenticated_user(auth_client)
	if user == null:
		return ""
	var gateway := _resolve_gateway()
	if gateway == null:
		return _fail("Supabase database gateway is unavailable.")
	var user_id := str(user.get("id"))
	if not await _ensure_player(gateway, user_id):
		return ""
	return await _create_run(gateway, user_id, secure_seed)


func _authenticated_user(auth_client: Object) -> Object:
	var user: Object = auth_client.get("client")
	if user == null or str(user.get("id")) == "":
		var task: Object = auth_client.call("sign_in_anonymous")
		if task == null:
			_fail("Anonymous sign-in did not create a task.")
			return null
		if task.has_signal("completed"):
			await task.completed
		var task_error: Variant = task.get("error")
		if task_error != null:
			_fail("Anonymous sign-in failed: %s" % str(task_error))
			return null
		user = task.get("user")
	if user == null:
		_fail("Anonymous sign-in returned no user.")
		return null
	if str(user.get("id")) == "":
		_fail("Anonymous sign-in returned an empty user id.")
		return null
	return user


func _ensure_player(gateway: Object, user_id: String) -> bool:
	var players: Array = await gateway.select("players", {"id": user_id})
	if players.is_empty():
		var inserted_players: Array = await gateway.insert("players", {"id": user_id})
		if inserted_players.is_empty():
			_fail("Could not create the cloud player profile.")
			return false
	return true


func _create_run(gateway: Object, user_id: String, secure_seed: int) -> String:
	var inserted_runs: Array = await gateway.insert(
		"runs", {"player_id": user_id, "seed": secure_seed, "save_version": 1}
	)
	if inserted_runs.is_empty() or not (inserted_runs[0] is Dictionary):
		return _fail("Could not create the initial cloud run.")
	var run_id := str((inserted_runs[0] as Dictionary).get("id", ""))
	if run_id == "":
		return _fail("Initial cloud run returned no id.")
	return run_id


func is_signed_in() -> bool:
	var auth_client := _resolve_auth()
	if auth_client == null:
		return false
	var user: Object = auth_client.get("client")
	return user != null and str(user.get("id")) != ""


func _resolve_auth() -> Object:
	if _auth_client != null:
		return _auth_client
	var supabase := _autoload("Supabase")
	if supabase != null:
		_auth_client = supabase.get("auth")
	return _auth_client


func _resolve_gateway() -> Object:
	if _gateway == null:
		_gateway = GatewayScript.new()
	return _gateway


func _fail(message: String) -> String:
	last_error = message
	return ""


static func _autoload(node_name: String) -> Object:
	var loop := Engine.get_main_loop()
	if loop is SceneTree and (loop as SceneTree).root != null:
		var root := (loop as SceneTree).root
		if root.has_node(node_name):
			return root.get_node(node_name)
	return null
