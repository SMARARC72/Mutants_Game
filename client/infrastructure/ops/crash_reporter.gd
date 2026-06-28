class_name CrashReporter
extends RefCounted
## CrashReporter facade (D2) — the ONLY thing in the codebase that touches sentry-godot.
##
## INFRASTRUCTURE/ops layer. Addon types (`SentrySDK`) never cross this boundary; the app calls
## `init(consent)`, `add_breadcrumb(...)`, `capture(...)` and nothing else.
##
## PRIVACY (D2 / TDD §9.2, ADR-008 spirit): opt-in ONLY (nothing is sent unless `consent ==
## true`), self-hostable DSN via ENV (`SENTRY_DSN`, never committed), and NO PII — we attach the
## run `seed`, the save header, and the build version, never email/account. A crash report's seed
## reproduces the bug exactly (pairs with the determinism oracle).
##
## sentry-godot ships its runtime API (`SentrySDK`) as a native GDExtension. When the native
## libs are present (a dev/playtest build that dropped them into `addons/sentry/bin/` and
## activated `sentry.gdextension`), this facade forwards to them. When absent (headless CI, this
## worktree, or a release with reporting compiled out), every call is a safe no-op — so the
## project always imports with ZERO addon errors (D9).

const SENTRY_SINGLETON := "SentrySDK"

var _enabled := false
var _consent := false
var _context := {}


## `consent`: the player's explicit opt-in. With it false, NOTHING is ever transmitted.
## `seed`/`save_header`/`build_version`: the only attached context — all non-PII.
func init(
	consent: bool, seed: int = 0, save_header: Dictionary = {}, build_version: String = ""
) -> void:
	_consent = consent
	_context = {
		"run.seed": seed,
		"build.version": build_version if build_version != "" else _default_build_version(),
	}
	# Attach a flattened, PII-free save header (save_version/schema_version/run_id/etc.).
	for key: String in save_header.keys():
		if _is_pii_key(key):
			continue
		_context["save.%s" % key] = save_header[key]

	if not consent:
		_enabled = false
		return
	var dsn := _read_dsn()
	if dsn == "":
		# No DSN configured -> stay silent (self-hostable, env-only; never hard-coded).
		_enabled = false
		return
	_enabled = _backend_available()
	if _enabled:
		_backend_set_context(_context)


## Drop a breadcrumb (no-op unless enabled + consented). Breadcrumbs are non-PII trail markers
## ("entered_battle", "splice_committed") that give a crash its story.
func add_breadcrumb(message: String, category: String = "app", data: Dictionary = {}) -> void:
	if not _enabled:
		return
	_backend_add_breadcrumb(message, category, _strip_pii(data))


## Capture an error/message. Returns true if it was actually transmitted.
func capture(error_message: String, level: String = "error") -> bool:
	if not _enabled:
		return false
	_backend_capture(error_message, level, _context)
	return true


## True once `init` succeeded with consent + DSN + an available backend.
func is_enabled() -> bool:
	return _enabled


## The non-PII context that would be attached (for tests / a settings "what we send" readout).
func attached_context() -> Dictionary:
	return _context.duplicate(true)


# --- privacy helpers ----------------------------------------------------------------
func _is_pii_key(key: String) -> bool:
	var lowered := key.to_lower()
	for needle in ["email", "account", "name", "user", "ip", "device_id", "phone"]:
		if lowered.findn(needle) != -1:
			return true
	return false


func _strip_pii(data: Dictionary) -> Dictionary:
	var clean := {}
	for key: String in data.keys():
		if not _is_pii_key(key):
			clean[key] = data[key]
	return clean


func _read_dsn() -> String:
	# ENV only (D2): self-hostable, never committed. Empty when unset.
	if OS.has_environment("SENTRY_DSN"):
		return OS.get_environment("SENTRY_DSN").strip_edges()
	return ""


func _default_build_version() -> String:
	var v: Variant = ProjectSettings.get_setting("application/config/version", "")
	if typeof(v) == TYPE_STRING and v != "":
		return v
	return "dev"


# --- backend bridge (the only place SentrySDK is named) -----------------------------
func _backend_available() -> bool:
	# The GDExtension registers `SentrySDK` as a global class when its native libs load.
	return ClassDB.class_exists(SENTRY_SINGLETON) or Engine.has_singleton(SENTRY_SINGLETON)


func _backend_singleton() -> Object:
	if Engine.has_singleton(SENTRY_SINGLETON):
		return Engine.get_singleton(SENTRY_SINGLETON)
	return null


func _backend_set_context(context: Dictionary) -> void:
	var sdk := _backend_singleton()
	if sdk == null:
		return
	for key: String in context.keys():
		if sdk.has_method("set_tag"):
			sdk.call("set_tag", key, str(context[key]))


func _backend_add_breadcrumb(message: String, category: String, data: Dictionary) -> void:
	var sdk := _backend_singleton()
	if sdk != null and sdk.has_method("add_breadcrumb"):
		# sentry-godot signature: add_breadcrumb(message, category, level, type, data).
		sdk.call("add_breadcrumb", message, category, 0, "default", data)


func _backend_capture(error_message: String, level: String, context: Dictionary) -> void:
	var sdk := _backend_singleton()
	if sdk == null:
		return
	_backend_set_context(context)
	if sdk.has_method("capture_message"):
		sdk.call("capture_message", error_message, _level_to_enum(level))


func _level_to_enum(level: String) -> int:
	# sentry-godot Level enum: DEBUG=0 INFO=1 WARNING=2 ERROR=3 FATAL=4.
	match level.to_lower():
		"debug":
			return 0
		"info":
			return 1
		"warning":
			return 2
		"fatal":
			return 4
		_:
			return 3
