class_name VoiceBook
extends RefCounted
## The authored voice catalog (Wave 16a) — every player-facing line the writers' room shipped,
## ingested VERBATIM from docs/content/voice_library*.md by tools/ingest_voice.py into
## client/catalog/voice.json as {key: [variant strings]} (binding tension 11: no hand-written
## quips in screen code; call sites ask the book).
##
## PRESENTATION layer, static + cached (mirrors ToastMicrocopy's shape): parse once, then
## `pick(key, salt)` rolls a variant with a LOCAL string hash — deterministic per (key, salt),
## varied across salts — never the canonical PCG32 streams. Callers keep their own fallback
## copy for missing keys (`pick` returns "" so the fallback path is explicit).

const VOICE_PATH := "res://catalog/voice.json"

static var _book: Dictionary = {}
static var _loaded := false


## The line for `key`, variant chosen by hash(key + salt). Same (key, salt) => same line
## (stable per call site); different salts walk the variants. "" when the key is missing.
static func pick(key: String, salt: int = 0) -> String:
	var variants := lines(key)
	if variants.is_empty():
		return ""
	var index := _fnv1a_32("%s#%d" % [key, salt]) % variants.size()
	return str(variants[index])


## Like pick(), but skips variants carrying unfilled {placeholder} tokens — for call sites
## (toasts) that never interpolate. Walks variants deterministically from the salted index;
## "" when the key is missing or EVERY variant needs interpolation (Codex #55 P2).
static func pick_plain(key: String, salt: int = 0) -> String:
	var variants := lines(key)
	if variants.is_empty():
		return ""
	var start := _fnv1a_32("%s#%d" % [key, salt]) % variants.size()
	for i in variants.size():
		var line := str(variants[(start + i) % variants.size()])
		if not line.contains("{"):
			return line
	return ""


## FNV-1a over UTF-8 bytes, 32-bit — stable across engine versions (String.hash() is not
## guaranteed to be; Sourcery #55). Mirrors SigilGen.fnv1a_32 (kept local: layering).
static func _fnv1a_32(text: String) -> int:
	var h := 0x811C9DC5
	for b in text.to_utf8_buffer():
		h = ((h ^ int(b)) * 0x01000193) & 0xFFFFFFFF
	return h


## True when the catalog carries at least one line for `key`.
static func has_key(key: String) -> bool:
	return not lines(key).is_empty()


## All variants for `key` (copy), [] when missing.
static func lines(key: String) -> Array:
	_ensure_loaded()
	var value: Variant = _book.get(key)
	if value is Array:
		return (value as Array).duplicate()
	return []


## Every real key in the book, sorted (parity tests; excludes the "_meta" record).
static func keys() -> Array:
	_ensure_loaded()
	var out: Array = []
	for key in _book:
		if not str(key).begins_with("_"):
			out.append(str(key))
	out.sort()
	return out


## How many authored lines the ingest recorded (JSON floats -> int at the boundary).
static func line_count() -> int:
	_ensure_loaded()
	var meta: Dictionary = _book.get("_meta", {})
	return int(meta.get("line_count", 0))


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(VOICE_PATH):
		push_warning("VoiceBook: %s missing — every pick() falls back." % VOICE_PATH)
		return
	var raw := FileAccess.get_file_as_string(VOICE_PATH)
	var parsed: Variant = JSON.parse_string(raw)
	if parsed is Dictionary:
		_book = parsed
	else:
		push_error("VoiceBook: %s did not parse as a JSON object." % VOICE_PATH)
