extends Node
## Settings autoload (D5) — persistent user settings as VERSIONED JSON (ADR-012), never a
## Godot Resource/.tres save. The backbone Maaack's options menu + G.U.I.D.E rebinding wire to.
##
## APPLICATION/autoload layer. Data-only `JSON.parse_string` round-trip with a header
## (`settings_version`), mirroring the save-file policy (ADR-012): we NEVER deserialize a
## Resource here. Audio/video/accessibility live in `data`; input rebindings are stored as a
## plain `{action: [serialised-input...]}` dict so G.U.I.D.E remapping (D4) can persist through
## this one file and survive a restart (D4/D5 acceptance).

signal changed(key: String, value: Variant)

const SETTINGS_VERSION := 1
const SAVE_PATH := "user://settings.json"

const DEFAULTS := {
	"audio":
	{
		"master_volume": 1.0,
		"music_volume": 0.8,
		"sfx_volume": 0.9,
		"muted": false,
	},
	"video":
	{
		"fullscreen": false,
		"vsync": true,
	},
	# Colorblind aid is colour+icon everywhere already (design §5); high_contrast bumps the
	# icon/shape emphasis on screens that can lean on it harder.
	"accessibility":
	{
		"high_contrast": false,
		"reduce_motion": false,
		"skip_seen_transitions": false,
	},
}

var data: Dictionary = {}
## Serialised G.U.I.D.E remappings, persisted across restarts (D4). Opaque to this autoload;
## the `InputService` facade reads/writes it.
var input_remaps: Dictionary = {}


func _ready() -> void:
	load_settings()


## Deep-copy the defaults so callers never mutate the constant.
func _fresh_defaults() -> Dictionary:
	return DEFAULTS.duplicate(true)


func get_value(section: String, key: String, fallback: Variant = null) -> Variant:
	if data.has(section) and (data[section] as Dictionary).has(key):
		return data[section][key]
	if DEFAULTS.has(section) and (DEFAULTS[section] as Dictionary).has(key):
		return DEFAULTS[section][key]
	return fallback


func set_value(section: String, key: String, value: Variant) -> void:
	if not data.has(section):
		data[section] = {}
	data[section][key] = value
	changed.emit("%s/%s" % [section, key], value)


## Store the opaque G.U.I.D.E remap blob (called by `InputService`).
func set_input_remaps(remaps: Dictionary) -> void:
	input_remaps = remaps.duplicate(true)
	changed.emit("input/remaps", input_remaps)


func get_input_remaps() -> Dictionary:
	return input_remaps.duplicate(true)


## Versioned-JSON write (ADR-012): header + data, data-only, no Resource serialization.
func save_settings() -> bool:
	var payload := {
		"settings_version": SETTINGS_VERSION,
		"data": data,
		"input_remaps": input_remaps,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Settings.save_settings: cannot open %s" % SAVE_PATH)
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true


## Versioned-JSON read (ADR-012). Missing/corrupt -> defaults. Migrates older versions
## forward by merging onto defaults (forward-compatible, ADR-012).
func load_settings() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		data = _fresh_defaults()
		input_remaps = {}
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		data = _fresh_defaults()
		return
	var raw := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Settings.load_settings: corrupt file; using defaults.")
		data = _fresh_defaults()
		input_remaps = {}
		return
	var dict := parsed as Dictionary
	data = _migrate(dict.get("data", {}))
	var remaps: Variant = dict.get("input_remaps", {})
	input_remaps = remaps if typeof(remaps) == TYPE_DICTIONARY else {}


## Merge stored values onto a fresh default tree so new keys appear with sane defaults and
## removed/renamed keys fall away — the ADR-012 forward-migration contract.
func _migrate(stored: Variant) -> Dictionary:
	var result := _fresh_defaults()
	if typeof(stored) != TYPE_DICTIONARY:
		return result
	for section: String in result.keys():
		if (stored as Dictionary).has(section) and typeof(stored[section]) == TYPE_DICTIONARY:
			for key: String in (result[section] as Dictionary).keys():
				if (stored[section] as Dictionary).has(key):
					result[section][key] = stored[section][key]
	return result


## Reset everything to defaults (options-menu "restore defaults").
func reset_to_defaults() -> void:
	data = _fresh_defaults()
	input_remaps = {}
	changed.emit("all", null)
