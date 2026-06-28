class_name NarrativeSave
extends RefCounted
## Versioned-JSON serializer for the narrative layer (ADR-012, deliverable D2/D4).
## Quest + Ink story state are serialized as **data only** via `JSON` — never as a
## Godot Resource / `store_var(full_objects)` (that is a code-exec surface, ADR-012).
##
## Shape (a self-describing, diffable, migratable blob):
##   {
##     "header": { "save_version", "schema_version", "app_version",
##                 "written_at_unix", "section": "narrative" },
##     "narrative": { ...QuestService.serialize()... },
##     "ink": { "story_state": "<InkPlayer.get_state() json string>" }
##   }
##
## This is the narrative slice; the full-game save (other tracks) embeds the same
## `narrative` + `ink` sections into its own versioned envelope. Kept standalone here
## so the sample vertical can prove save -> reload -> state intact on its own.

const SAVE_VERSION := 1
const SCHEMA_VERSION := 1


## Builds the versioned-JSON string. `app_version` is informational (build header).
## `ink_state` is the opaque InkPlayer state String (may be empty if no story loaded).
static func build_json(
	quest_payload: Dictionary, ink_state: String, app_version: String = "0.0.0"
) -> String:
	var envelope := {
		"header":
		{
			"save_version": SAVE_VERSION,
			"schema_version": SCHEMA_VERSION,
			"app_version": app_version,
			# Time.* is legal here: this is application/, NOT domain/. The save header
			# wants a wall-clock stamp; nothing gameplay-deterministic reads it.
			"written_at_unix": Time.get_unix_time_from_system(),
			"section": "narrative",
		},
		"narrative": quest_payload,
		"ink":
		{
			"story_state": ink_state,
		},
	}
	return JSON.stringify(envelope, "\t")


## Parses a versioned-JSON string back to its envelope dictionary, or {} on failure
## / wrong section. NEVER deserializes a Resource (ADR-012) — strictly JSON data.
static func parse_json(text: String) -> Dictionary:
	if text.strip_edges() == "":
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("NarrativeSave.parse_json: not a JSON object.")
		return {}
	var envelope: Dictionary = parsed
	var header: Dictionary = envelope.get("header", {})
	if int(header.get("save_version", -1)) > SAVE_VERSION:
		push_error("NarrativeSave: save is newer than this build can read.")
		return {}
	return envelope


static func quest_payload(envelope: Dictionary) -> Dictionary:
	return envelope.get("narrative", {})


static func ink_state(envelope: Dictionary) -> String:
	var ink: Dictionary = envelope.get("ink", {})
	return str(ink.get("story_state", ""))


## Writes the JSON to `user://` (or any res-less path). Returns OK / an error code.
static func save_to_path(path: String, json_text: String) -> int:
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
