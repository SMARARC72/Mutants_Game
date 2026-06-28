extends GdUnitTestSuite
## Phase 3 (ADR-005, TDD §6.6 / §11.4): the deterministic command log. Replaying the same log
## over the same initial state twice yields IDENTICAL state (determinism), append assigns
## monotonic seqs, the offline queue tracks pending commands, and the log round-trips as data.

const CommandLogScript := preload("res://application/persistence/command_log.gd")


## A pure, deterministic applier: folds simple arithmetic commands onto a {"total": int} state.
## (Stands in for the oracle; the log itself computes nothing.)
func _apply(state: Variant, command: Dictionary) -> Variant:
	var next: Dictionary = (state as Dictionary).duplicate(true)
	var payload: Dictionary = command.get("payload", {})
	match str(command.get("type", "")):
		"add":
			next["total"] = int(next.get("total", 0)) + int(payload.get("n", 0))
		"mul":
			next["total"] = int(next.get("total", 0)) * int(payload.get("n", 1))
		_:
			pass
	return next


func _filled_log() -> CommandLog:
	var log: CommandLog = CommandLogScript.new()
	log.append("add", {"n": 5})
	log.append("mul", {"n": 3})
	log.append("add", {"n": 2})
	return log


func test_append_assigns_monotonic_seqs() -> void:
	var log: CommandLog = CommandLogScript.new()
	assert_int(log.append("add", {"n": 1})).is_equal(0)
	assert_int(log.append("add", {"n": 1})).is_equal(1)
	assert_int(log.append("add", {"n": 1})).is_equal(2)
	assert_int(log.size()).is_equal(3)


func test_replay_is_deterministic() -> void:
	var log := _filled_log()
	var applier := Callable(self, "_apply")
	# (0 + 5) * 3 + 2 = 17, order matters and is preserved.
	var first: Dictionary = log.replay({"total": 0}, applier)
	var second: Dictionary = log.replay({"total": 0}, applier)
	assert_int(int(first["total"])).is_equal(17)
	assert_int(int(second["total"])).is_equal(17)
	assert_bool(first == second).is_true()


func test_replay_after_round_trip_matches() -> void:
	var log := _filled_log()
	var applier := Callable(self, "_apply")
	var direct: Dictionary = log.replay({"total": 0}, applier)
	# Serialize -> deserialize, then replay again: identical fold.
	var reloaded: CommandLog = CommandLogScript.from_dict(
		JSON.parse_string(JSON.stringify(log.to_dict()))
	)
	var after: Dictionary = reloaded.replay({"total": 0}, applier)
	assert_int(int(after["total"])).is_equal(int(direct["total"]))
	assert_int(reloaded.size()).is_equal(3)


func test_offline_queue_tracks_and_clears() -> void:
	var log := _filled_log()
	assert_bool(log.has_pending()).is_true()
	assert_int(log.pending().size()).is_equal(3)
	# Server accepted up to seq 1 -> only seq 2 remains pending.
	log.mark_synced(1)
	var pending := log.pending()
	assert_int(pending.size()).is_equal(1)
	assert_int(int((pending[0] as Dictionary)["seq"])).is_equal(2)
	log.mark_synced(2)
	assert_bool(log.has_pending()).is_false()
