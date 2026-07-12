extends GdUnitTestSuite

const AuthPathScript := preload("res://infrastructure/supabase/auth.gd")


class FakeUser:
	extends RefCounted
	var id := "user-anon-1"


class FakeTask:
	extends RefCounted
	signal completed(task: Object)
	var error: Variant = null
	var user: Object = FakeUser.new()

	func finish() -> void:
		completed.emit(self)


class MissingAuthPath:
	extends AuthPathScript

	func _resolve_auth() -> Object:
		return null


class FakeAuth:
	extends RefCounted
	var client: Object = null
	var sign_in_count := 0

	func sign_in_anonymous() -> FakeTask:
		sign_in_count += 1
		var task := FakeTask.new()
		client = task.user
		task.call_deferred("finish")
		return task


class FakeGateway:
	extends RefCounted
	var players: Array = []
	var runs: Array = []

	func select(table: String, filters: Dictionary = {}) -> Array:
		var source: Array = players if table == "players" else runs
		var result: Array = []
		for row in source:
			var matches := true
			for key in filters:
				if (row as Dictionary).get(key) != filters[key]:
					matches = false
			if matches:
				result.append((row as Dictionary).duplicate(true))
		return result

	func insert(table: String, row: Dictionary) -> Array:
		var stored := row.duplicate(true)
		if table == "players":
			players.append(stored)
		else:
			stored["id"] = "run-cloud-1"
			runs.append(stored)
		return [stored.duplicate(true)]


func test_bootstrap_creates_real_owned_player_and_run() -> void:
	var auth := FakeAuth.new()
	var gateway := FakeGateway.new()
	var path := AuthPathScript.new(auth, gateway)
	var run_id: String = await path.bootstrap_anonymous_run(8675309)
	assert_str(run_id).is_equal("run-cloud-1")
	assert_bool(path.is_signed_in()).is_true()
	assert_int(auth.sign_in_count).is_equal(1)
	assert_int(gateway.players.size()).is_equal(1)
	assert_str(str((gateway.players[0] as Dictionary).get("id", ""))).is_equal("user-anon-1")
	assert_int(gateway.runs.size()).is_equal(1)
	assert_str(str((gateway.runs[0] as Dictionary).get("player_id", ""))).is_equal("user-anon-1")
	assert_int(int((gateway.runs[0] as Dictionary).get("seed", 0))).is_equal(8675309)


func test_bootstrap_reuses_existing_session_and_player() -> void:
	var auth := FakeAuth.new()
	auth.client = FakeUser.new()
	var gateway := FakeGateway.new()
	gateway.players.append({"id": "user-anon-1"})
	var path := AuthPathScript.new(auth, gateway)
	assert_str(await path.bootstrap_anonymous_run(42)).is_equal("run-cloud-1")
	assert_int(auth.sign_in_count).is_equal(0)
	assert_int(gateway.players.size()).is_equal(1)


func test_missing_auth_fails_offline_without_crashing() -> void:
	var path := MissingAuthPath.new(null, FakeGateway.new())
	assert_str(await path.bootstrap_anonymous_run(1)).is_empty()
	assert_str(path.last_error).contains("unavailable")
