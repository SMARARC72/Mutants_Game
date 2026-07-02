class_name FourthWall
extends RefCounted
## Wave 16b — the RATIONED fourth-wall one-shot registry (binding tension 11: fourth-wall
## material fires ONLY through this registry, never in boss/death flows). Each authored
## "crack" latches ONCE per run in `run.world_state.seen_cracks`, so the game breaks the
## wall exactly as often as the writers' room budgeted: three cracks this batch —
##   * the weathered SIGNPOST that knows the save's name (`fourthwall.signpost`),
##   * Madam Cessil's reading as a rare peculiar variant (`fourthwall.v2.cessil`),
##   * a ~1-in-8-runs MAIN-MENU tagline flicker (`fourthwall.suspects`).
## All copy comes VERBATIM from the VoiceBook; nothing here writes a quip. Presentation
## randomness is a LOCAL string hash of the run seed — never the canonical PCG32 streams.

const VoiceBookScript := preload("res://presentation/narrative/voice_book.gd")

## run.world_state key holding the {crack_id: true} one-shot registry (JSON-safe).
const CRACKS_KEY := "seen_cracks"

const CRACK_SIGNPOST := "signpost"
const CRACK_CESSIL := "cessil"
const CRACK_MENU := "menu_tagline"

## The menu flicker fires on ~1 run in MENU_FLICKER_DIE (seeded by the run-seed hash).
const MENU_FLICKER_DIE := 8


## True once `crack_id` has already fired this run.
static func seen(run: RunContext, crack_id: String) -> bool:
	if run == null:
		return false
	var cracks: Dictionary = run.world_state.get(CRACKS_KEY, {})
	return bool(cracks.get(crack_id, false))


## Latch `crack_id`: returns true ONLY the first time (the ration), false ever after.
## The caller persists the run (the registry rides world_state into the save).
static func latch(run: RunContext, crack_id: String) -> bool:
	if run == null or seen(run, crack_id):
		return false
	var cracks: Dictionary = run.world_state.get(CRACKS_KEY, {})
	cracks[crack_id] = true
	run.world_state[CRACKS_KEY] = cracks
	return true


## The signpost crack: the authored line, formatted with the run's actual save name,
## latched once. "" when there is no run or the sign has already spoken.
static func signpost_line(run: RunContext) -> String:
	if run == null or not latch(run, CRACK_SIGNPOST):
		return ""
	var line := VoiceBookScript.pick("fourthwall.signpost")
	if line == "":
		return ""
	return line.format({"save": str(run.run_id)})


## The main-menu tagline flicker: the authored watched-by-something line on ~1 run in 8
## (a pure function of the run-seed hash, so the SAME run always reads the same menu).
## "" for the other seven — and always "" without a run identity (fresh installs never
## flicker; the wall stays rationed). `game` is the GameController autoload (or null).
static func menu_tagline(game: Node) -> String:
	var identity := _identity_seed(game)
	if identity == 0:
		return ""
	if absi(hash("crack:%s:%d" % [CRACK_MENU, identity])) % MENU_FLICKER_DIE != 0:
		return ""
	return VoiceBookScript.pick("fourthwall.suspects")


## A stable per-run identity for menu-time seeding: the active run's seed when one is
## loaded, else a LOCAL hash of the latest save path (it carries the run id). 0 = none.
static func _identity_seed(game: Node) -> int:
	if game == null:
		return 0
	if game.has_method("has_run") and bool(game.call("has_run")):
		var run: RunContext = game.call("run")
		if run != null:
			return int(run.seed)
	if game.has_method("_latest_save_path"):
		var path := str(game.call("_latest_save_path"))
		if path != "":
			return absi(hash(path))
	return 0
