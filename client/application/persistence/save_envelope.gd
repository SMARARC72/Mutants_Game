class_name SaveEnvelope
extends RefCounted
## Versioned-JSON serializer for the WHOLE run (ADR-005, ADR-012, TDD §10). Generalizes the
## narrative-only `NarrativeSave` envelope to the full game: it wraps the run aggregate
## (`RunContext`), the embedded narrative + ink slices, and the deterministic command log.
## Data only via `JSON` — NEVER a Godot Resource / `store_var(full_objects)` (a code-exec
## surface, ADR-012; material because we import friend-shared Succession data).
##
## Shape (self-describing, diffable, migratable):
##   {
##     "header": { save_version, schema_version, app_version, written_at_unix,
##                 run_id, section: "run", checksum },
##     "run":        { ...RunContext.to_dict()... },
##     "narrative":  { ...QuestService.serialize()... },   # the narrative slice (D1/D2)
##     "ink":        { story_state: "<InkPlayer.get_state() json>" },
##     "command_log":{ ...CommandLog.to_dict()... }          # retained alongside (TDD §6.6)
##   }
##
## `save_version` is the SOLE sync conflict key (ADR-005, TDD §10.3); the DAL owns bumping it.
## Parse REFUSES a save newer than this build (no downgrade), runs the forward-only migration
## chain on older saves, and verifies the header checksum.

const SaveMigrationsScript := preload("res://application/persistence/save_migrations.gd")

## The save format version (the SOLE sync conflict key's namespace). MUST equal the migration
## chain's target (SaveMigrations.CURRENT_VERSION) so a freshly written save is, by definition,
## current; `test_envelope_version_mirrors_migration_target` pins the equality. Kept as a literal
## (not a cross-script const reference) to avoid any const-init ordering surprises.
const SAVE_VERSION := 1
const SCHEMA_VERSION := 1
const SECTION := "run"
const DEFAULT_DIR := "user://saves"


## Builds the versioned-JSON string for a full run. `narrative`/`ink_state`/`command_log` are
## optional so a minimal run still serializes. The header carries a checksum over the body
## sections (TDD §10.2 integrity) computed AFTER the sections are fixed.
static func build_json(
	run: Dictionary,
	narrative: Dictionary = {},
	ink_state: String = "",
	command_log: Dictionary = {},
	app_version: String = "0.0.0"
) -> String:
	var envelope := build_dict(run, narrative, ink_state, command_log, app_version)
	return JSON.stringify(envelope, "\t")


## Builds the envelope DICTIONARY (the in-memory form `build_json` stringifies). Exposed so
## the DAL can embed/inspect it without a round-trip through text.
static func build_dict(
	run: Dictionary,
	narrative: Dictionary = {},
	ink_state: String = "",
	command_log: Dictionary = {},
	app_version: String = "0.0.0"
) -> Dictionary:
	var body := {
		"run": run,
		"narrative": narrative,
		"ink": {"story_state": ink_state},
		"command_log": command_log,
	}
	var header := {
		"save_version": SAVE_VERSION,
		"schema_version": SCHEMA_VERSION,
		"app_version": app_version,
		# Time.* is legal here (application/, NOT domain/): a wall-clock stamp for the header;
		# nothing gameplay-deterministic reads it. `updated_at`/written stamps are informational
		# only — save_version (not wall-clock) arbitrates sync (TDD §10.3).
		"written_at_unix": Time.get_unix_time_from_system(),
		"run_id": str(run.get("run_id", "")),
		"section": SECTION,
		"checksum": checksum_of(body),
	}
	var envelope := {"header": header}
	envelope.merge(body)
	return envelope


## Parses a versioned-JSON string to its (migrated) envelope dictionary, or {} on failure.
## Refuses a save NEWER than this build (downgrade, TDD §10.2), then runs the forward-only
## migration chain so an older save reaches the current version. NEVER deserializes a Resource
## (ADR-012) — strictly JSON data.
static func parse_json(text: String) -> Dictionary:
	if text.strip_edges() == "":
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("SaveEnvelope.parse_json: not a JSON object.")
		return {}
	var envelope: Dictionary = parsed
	var header: Dictionary = envelope.get("header", {})
	if int(header.get("save_version", -1)) > SAVE_VERSION:
		push_error("SaveEnvelope: save is newer than this build can read (downgrade refused).")
		return {}
	# Forward-only migration chain: older saves are upgraded; current/equal pass through.
	if not SaveMigrationsScript.is_current(envelope):
		envelope = SaveMigrationsScript.migrate(envelope)
		if int((envelope.get("header", {}) as Dictionary).get("save_version", -1)) != SAVE_VERSION:
			push_error("SaveEnvelope: migration chain did not reach the current save_version.")
			return {}
	return envelope


# --- section accessors (mirror NarrativeSave's helpers) ---------------------- #


static func run_payload(envelope: Dictionary) -> Dictionary:
	return _as_dict(envelope.get("run", {}))


static func narrative_payload(envelope: Dictionary) -> Dictionary:
	return _as_dict(envelope.get("narrative", {}))


static func ink_state(envelope: Dictionary) -> String:
	var ink: Dictionary = _as_dict(envelope.get("ink", {}))
	return str(ink.get("story_state", ""))


static func command_log_payload(envelope: Dictionary) -> Dictionary:
	return _as_dict(envelope.get("command_log", {}))


## True if the envelope's stored header checksum matches a freshly computed one over its body
## (corruption detection, TDD §10.3). A migrated envelope is re-checksummed by re-saving.
static func verify_checksum(envelope: Dictionary) -> bool:
	var header: Dictionary = _as_dict(envelope.get("header", {}))
	if not header.has("checksum"):
		return false
	var body := {
		"run": _as_dict(envelope.get("run", {})),
		"narrative": _as_dict(envelope.get("narrative", {})),
		"ink": _as_dict(envelope.get("ink", {})),
		"command_log": _as_dict(envelope.get("command_log", {})),
	}
	return str(header.get("checksum", "")) == checksum_of(body)


## Deterministic checksum of the body sections: a stable-key JSON string hashed with SHA-256.
## `JSON.stringify(..., "", true, true)` sorts keys, so the digest is stable across runs/OS
## and independent of dictionary insertion order.
static func checksum_of(body: Dictionary) -> String:
	var canonical := JSON.stringify(body, "", true, true)
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(canonical.to_utf8_buffer())
	return ctx.finish().hex_encode()


# --- user:// path helpers ---------------------------------------------------- #


## The canonical save path for a run: `user://saves/{run_id}.json` (TDD §10.1).
static func path_for_run(run_id: String) -> String:
	var safe_id := run_id if run_id != "" else "unknown"
	return "%s/%s.json" % [DEFAULT_DIR, safe_id]


## Writes the JSON to `path`, creating the parent dir if needed. Returns OK / an error code.
static func save_to_path(path: String, json_text: String) -> int:
	var dir := path.get_base_dir()
	if dir != "" and not DirAccess.dir_exists_absolute(dir):
		var mk := DirAccess.make_dir_recursive_absolute(dir)
		if mk != OK:
			return mk
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(json_text)
	file.close()
	return OK


static func load_from_path(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


static func _as_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}
