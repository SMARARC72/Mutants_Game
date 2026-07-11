extends Node
## DevConsole autoload (D3 / ADR-018) — LimboConsole wrapped + gated behind DEV_TOOLS.
##
## PRESENTATION/devtools layer, DEV-BUILDS ONLY. ADR-018: the console and its commands are
## disabled/compiled out of release. We gate on `is_dev_build()` (debug build OR the `dev_tools`
## feature tag); in a release export this autoload registers NOTHING and the backtick toggle is
## inert. LimboConsole types never leak past this file.
##
## Registers state-poke commands and live parity probes that run the ported GDScript engines and
## diff stable result hashes against the Python oracle's committed golden vectors (TDD §11.2).

const DevState := preload("res://presentation/devtools/dev_state.gd")
const DEV_FEATURE := "dev_tools"

var _console: Object  # the LimboConsole autoload, or null in release / when absent
var _state: DevState


func _ready() -> void:
	if not is_dev_build():
		# ADR-018: release builds get nothing. The console stays dark.
		return
	_state = DevState.new()
	_console = get_node_or_null("/root/LimboConsole")
	if _console == null:
		# LimboConsole autoload not present (e.g. headless without the addon enabled): no-op,
		# but keep DevState available so a dev build without the GUI can still drive pokes.
		return
	_register_commands()
	_console.call(
		"info", "[DEV_TOOLS] Mutants_Game dev console ready. State pokes + parity stubs loaded."
	)


## Dev-only gate (ADR-018): debug builds, or any build exported with the `dev_tools` feature tag.
func is_dev_build() -> bool:
	return OS.is_debug_build() or OS.has_feature(DEV_FEATURE)


## Expose the dev state shim (for tests / a dev HUD).
func state() -> DevState:
	return _state


func _register_commands() -> void:
	# --- state pokes (D3) ---
	_cmd(_state.set_seed, "set_seed", "set_seed <n> — force the run RNG seed (dev only)")
	_cmd(
		_state.set_corruption,
		"set_corruption",
		"set_corruption <n> — set the corruption meta-meter"
	)
	_cmd(
		_state.set_morality,
		"set_morality",
		"set_morality <oc> <pc> — set occult/profane morality axes"
	)
	_cmd(_state.give_creature, "give_creature", "give_creature <id> — add a creature to the party")
	_cmd(_state.grant_gear, "grant_gear", "grant_gear <slot> <id> — equip gear into a slot")
	_cmd(_state.unlock_region, "unlock_region", "unlock_region <id> — unlock an overworld region")

	# --- parity probes (TDD §11.2) ---
	# Both probes run their GDScript engine on a committed Python-oracle vector and report a stable
	# hash plus an unambiguous PARITY_OK / PARITY_DRIFT marker.
	_cmd(
		_parity_battle,
		"parity_battle",
		"parity_battle <seed> — run battle_engine on the golden teams + diff hash vs golden vectors"
	)
	_cmd(
		_parity_splice,
		"parity_splice",
		"parity_splice <a> <b> <method> <seed> — run lab_engine + diff hash vs golden vectors"
	)


func _cmd(callable: Callable, name: String, desc: String) -> void:
	if _console != null and _console.has_method("register_command"):
		_console.call("register_command", callable, name, desc)


# === parity-probe: parity_battle (WIRED, Cluster 4 / D6) =============================
## Runs the GDScript BattleEngine.simulate on the golden teams at `seed`, hashes the transcript, and
## diffs it against the committed Python golden vector for that seed (TDD §11.2). It only READS the
## oracle — it never becomes a source of truth (the determinism rule). The manual counterpart to the
## automated battle_engine_parity_test; the fastest path to triage a parity drift in seconds.
func _parity_battle(seed: int = 0) -> void:
	var report := ParityProbe.battle(seed)
	for line in report:
		_console_out(line)


func _parity_splice(
	parent_a: String = "", parent_b: String = "", method: String = "precise", seed: int = 0
) -> void:
	var report := ParityProbe.lab_fuse(parent_a, parent_b, method, seed)
	for line in report:
		_console_out(line)


func _console_out(line: String) -> void:
	if _console != null and _console.has_method("info"):
		_console.call("info", line)
	else:
		print(line)
