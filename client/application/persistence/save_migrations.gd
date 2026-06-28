class_name SaveMigrations
extends RefCounted
## Forward-only save migration chain (ADR-005, TDD §10.2 — "never strand a save"). A registry
## maps `save_version n -> n+1` migration functions; on load we apply them IN SEQUENCE from the
## save's version up to the current target (SaveEnvelope.SAVE_VERSION), so an older save is
## never stranded. Loading a FUTURE-version save (downgrade) is refused upstream by the parser
## with a clear message — migrations only ever move forward.
##
## A migration is a Callable(envelope: Dictionary) -> Dictionary: it takes the WHOLE versioned
## envelope and returns the next-version envelope (it must also bump header.save_version). Data
## only (ADR-012); no gameplay math, no I/O.
##
## To add a migration: write a `_migrate_vN_to_vN1` static func, register it in `_registry()`,
## and bump SaveEnvelope.SAVE_VERSION to N+1. Each migration ships with a real old-format
## fixture test (TDD §10.2).

## The current save target the chain migrates UP TO. This is the authoritative version number;
## SaveEnvelope.SAVE_VERSION mirrors it (a test pins them equal). Owning it here — rather than
## preloading SaveEnvelope — avoids a circular preload (envelope -> migrations -> envelope).
const CURRENT_VERSION := 1


## The migration registry: from_version -> Callable(envelope) -> envelope. Keys are the
## CURRENT version of a save; the function upgrades it to from_version + 1.
static func _registry() -> Dictionary:
	return {
		0: Callable(SaveMigrations, "_migrate_v0_to_v1"),
		# 1: Callable(SaveMigrations, "_migrate_v1_to_v2"),  # add when SAVE_VERSION -> 2
	}


## Runs the chain on a parsed envelope: applies registered migrations in order from the
## save's `header.save_version` up to `target` (defaults to the current build's SAVE_VERSION).
## Returns the migrated envelope. If a step is missing or fails to advance the version it
## stops and returns what it has (the caller validates the final version).
##
## Precondition: the save is NOT newer than this build (the parser rejects future saves before
## calling here). Older or equal versions are safe to migrate forward.
static func migrate(envelope: Dictionary, target: int = -1) -> Dictionary:
	var to_version := target if target >= 0 else CURRENT_VERSION
	var registry := _registry()
	var current := envelope.duplicate(true)
	var guard := 0
	while _envelope_version(current) < to_version:
		var from_version := _envelope_version(current)
		if not registry.has(from_version):
			push_error(
				"SaveMigrations: no migration from save_version %d (save stranded)." % from_version
			)
			break
		var migrator: Callable = registry[from_version]
		current = migrator.call(current)
		# A migration MUST advance the version; otherwise we would loop forever.
		if _envelope_version(current) <= from_version:
			push_error(
				"SaveMigrations: migration from %d did not advance the version." % from_version
			)
			break
		guard += 1
		if guard > 64:
			push_error("SaveMigrations: chain exceeded 64 steps; aborting.")
			break
	return current


## True if the envelope is already at (or above) the current target — nothing to migrate.
static func is_current(envelope: Dictionary) -> bool:
	return _envelope_version(envelope) >= CURRENT_VERSION


static func _envelope_version(envelope: Dictionary) -> int:
	var header: Dictionary = envelope.get("header", {})
	return int(header.get("save_version", 0))


# --- migrations (forward-only) ----------------------------------------------- #


## v0 -> v1: the first real migration scaffold. v0 saves predate the `run` section being a
## first-class aggregate; example transform = ensure the `run` section exists and rename the
## legacy `run.zenny` currency field to `run.drachma` (a representative field-rename), then
## bump the header. Idempotent on already-shaped data.
static func _migrate_v0_to_v1(envelope: Dictionary) -> Dictionary:
	var out := envelope.duplicate(true)
	var run: Dictionary = out.get("run", {})
	if not (run is Dictionary):
		run = {}
	# Field rename example: legacy `zenny` -> canonical `drachma`.
	if run.has("zenny") and not run.has("drachma"):
		run["drachma"] = int(run["zenny"])
		run.erase("zenny")
	# Ensure save_version inside the embedded run mirrors the header (kept in lockstep).
	run["save_version"] = 1
	out["run"] = run
	var header: Dictionary = out.get("header", {})
	if not (header is Dictionary):
		header = {}
	header["save_version"] = 1
	out["header"] = header
	return out
