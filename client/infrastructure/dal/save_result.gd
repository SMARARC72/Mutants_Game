class_name SaveResult
extends RefCounted
## The outcome of a repository write (ADR-004, TDD §10.3). A save can SUCCEED (the store
## accepted the write and advanced `save_version`) or CONFLICT (the caller's base
## `save_version` was stale — someone else advanced the run since we loaded it). On conflict
## we report it; we NEVER silently overwrite (the client rebases onto `server_version`).
##
## Pure data carrier — no I/O. `save_version` is the SOLE conflict key (updated_at is
## informational only; wall-clock must not arbitrate).

enum Status { OK, CONFLICT, ERROR }

var status: int = Status.OK
## The accepted post-write version (on OK) or the store's current version (on CONFLICT).
var save_version: int = 0
## The store's current version when a conflict was detected (what the client rebases onto).
var server_version: int = 0
var message: String = ""


func is_ok() -> bool:
	return status == Status.OK


func is_conflict() -> bool:
	return status == Status.CONFLICT


static func ok(new_version: int) -> SaveResult:
	var r := SaveResult.new()
	r.status = Status.OK
	r.save_version = new_version
	r.server_version = new_version
	return r


static func conflict(server_ver: int, base_ver: int) -> SaveResult:
	var r := SaveResult.new()
	r.status = Status.CONFLICT
	r.server_version = server_ver
	r.save_version = base_ver
	r.message = (
		"save_version conflict: base %d is stale; server is at %d." % [base_ver, server_ver]
	)
	return r


static func error(msg: String) -> SaveResult:
	var r := SaveResult.new()
	r.status = Status.ERROR
	r.message = msg
	return r
