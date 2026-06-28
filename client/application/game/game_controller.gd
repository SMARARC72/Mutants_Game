extends Node
## GameController (Phase 5 · Slice 1) — THE autoload that owns the active run (registered in
## project.godot [autoload] as `GameController`). APPLICATION/game layer: the SINGLE source of run
## state for the whole slice. The menu starts/continues a run through it; the overworld reads the
## active region + party from it; battle results are applied back through it; saving goes through it.
##
## It owns exactly one RunContext aggregate (ADR-005) and wires the EXISTING infra — it reimplements
## nothing:
##   * persistence : RunContext + SaveEnvelope (local user:// save ALWAYS) + the DAL run repository
##                   (FakeDal by default — offline + tests; SupabaseDal when configured).
##   * worldgen    : WorldGenerator.get_or_generate (generate-once, persisted/reused via world_state).
##   * content     : SpeciesCatalog + EncounterCatalog for the starter party + region wild pools.
##
## DETERMINISM: the run SEED is the root of every canonical stream (worldgen, encounters, battles),
## so a run replays identically. new_run(seed) with a fixed seed is fully reproducible.

## Emitted whenever the active run changes (new run started or a save loaded). The overworld can
## listen to refresh from the new RunContext.
signal run_changed(run: RunContext)

const RunContextScript := preload("res://application/persistence/run_context.gd")
const SaveEnvelopeScript := preload("res://application/persistence/save_envelope.gd")
const FakeDalScript := preload("res://infrastructure/dal/fake_dal.gd")
const WorldGeneratorScript := preload("res://infrastructure/worldgen/world_generator.gd")
const EncounterCatalogScript := preload("res://application/overworld/encounter_catalog.gd")

var _run: RunContext = null
var _dal: Dictionary = {}
var _catalog: SpeciesCatalog = null
var _world_gen: WorldGenerator = null
## The save_version we last loaded/saved at — the conflict base for the DAL write (TDD §10.3).
var _base_save_version: int = 0


func _ready() -> void:
	# Default offline wiring. configure() can swap in the Supabase DAL when configured.
	if _dal.is_empty():
		_dal = FakeDalScript.make()
	if _catalog == null:
		_catalog = SpeciesCatalog.new()
	if _world_gen == null:
		_world_gen = WorldGeneratorScript.new()


## Inject dependencies (used by tests + when Supabase is configured). Any null arg keeps the
## current/default. Call BEFORE new_run/continue_run. `dal` is a DAL bundle dict (FakeDal.make() /
## SupabaseDal.make(gateway)).
func configure(
	dal: Dictionary = {}, catalog: SpeciesCatalog = null, world_gen: WorldGenerator = null
) -> void:
	if not dal.is_empty():
		_dal = dal
	if catalog != null:
		_catalog = catalog
	if world_gen != null:
		_world_gen = world_gen
	_ensure_deps()


# === run lifecycle ============================================================================ #


## Start a fresh run from `seed`. Builds the run id, a starter party (EncounterCatalog), the starting
## Verdant region, and unlocks it. Does NOT generate the region grid (the overworld does that lazily
## via WorldGenerator), so new_run stays cheap + headless. Emits run_changed. Returns the RunContext.
func new_run(seed: int) -> RunContext:
	_ensure_deps()
	var run: RunContext = RunContextScript.new()
	run.run_id = "run-%d" % seed
	run.player_id = "local"
	run.seed = seed
	run.save_version = 1
	run.schema_version = 1
	run.act = 0
	run.rank = "Mortal"
	run.status = "active"
	run.party = EncounterCatalogScript.starter_party()
	run.world_state = {"active_region": EncounterCatalogScript.STARTING_REGION, "steps": 0}
	run.unlocked_regions = {EncounterCatalogScript.STARTING_REGION: true}
	run.flags = {}
	_run = run
	_base_save_version = 0
	run_changed.emit(_run)
	return _run


## Load the most recent local save (user://saves) and make it the active run. Returns true on
## success, false if there is no readable save. Mirrors the SaveEnvelope local-file path; the DAL is
## the cloud/aggregate mirror but the on-disk save is the offline source of truth for "Continue".
func continue_run() -> bool:
	_ensure_deps()
	var path := _latest_save_path()
	if path == "":
		return false
	var text := SaveEnvelopeScript.load_from_path(path)
	if text == "":
		return false
	var envelope := SaveEnvelopeScript.parse_json(text)
	if envelope.is_empty():
		return false
	var run_payload := SaveEnvelopeScript.run_payload(envelope)
	if run_payload.is_empty():
		return false
	_run = RunContextScript.from_dict(run_payload)
	_base_save_version = _run.save_version
	# Mirror the loaded aggregate into the DAL so a later save_run conflict-checks against it.
	_seed_dal_from_run()
	run_changed.emit(_run)
	return true


## Persist the active run: write the versioned-JSON envelope to user:// ALWAYS, and push the run
## aggregate through the DAL (bumping save_version on accept). Returns true on success. No-op (false)
## if there is no active run.
func save_run() -> bool:
	if _run == null:
		return false
	_ensure_deps()
	# 1) DAL write (conflict-checked). On accept the store bumps save_version; mirror it back. The
	#    await suspends only for the async Supabase repo; the Fake repo resolves synchronously (no
	#    suspension), so save_run() returns its bool synchronously offline / in tests.
	var result: Variant = await _save_to_dal()
	if result != null and result.is_ok():
		_run.save_version = result.save_version
		_base_save_version = result.save_version
	# 2) Local user:// save ALWAYS (offline source of truth for Continue). Uses the (possibly
	#    bumped) save_version so the on-disk envelope and the DAL agree.
	var json := SaveEnvelopeScript.build_json(_run.to_dict())
	var path := SaveEnvelopeScript.path_for_run(_run.run_id)
	var err := SaveEnvelopeScript.save_to_path(path, json)
	return err == OK


# === battle result application ================================================================ #


## Apply a BattleSession result back to the run. BACKWARD-COMPATIBLE with Slice 1: still awards xp to
## essence + records last_battle_won. Slice 2 additions (only when the keys are present, so a Slice 1
## auto result is unchanged): a CAUGHT creature_instance is appended to the party, and the last battle
## outcome reason (win/lose/fled/caught) is recorded for the overworld to read. Pure bookkeeping — the
## real xp/level curve is a later slice. Returns the run for chaining.
func apply_battle_result(result: Dictionary) -> RunContext:
	if _run == null:
		return null
	var gained := int(result.get("xp", 0))
	_run.essence += gained  # Slice 1 stand-in growth resource.
	_run.flags["last_battle_won"] = bool(result.get("player_won", false))
	_run.flags["last_battle_reason"] = str(result.get("reason", ""))
	# Slice 2: a captured wild creature joins the party (shaped as a creature_instance by the capture
	# service). Append a deep copy so the run owns it independent of the result dict.
	var caught: Dictionary = result.get("caught", {})
	if not caught.is_empty():
		_run.party.append(caught.duplicate(true))
	return _run


## Increment the run's overworld step counter (used as the encounter roll index) and return the new
## value. Persisted in world_state so the encounter sequence resumes correctly after load.
func advance_step() -> int:
	if _run == null:
		return 0
	var next := current_step() + 1
	_run.world_state["steps"] = next
	return next


# === accessors ================================================================================ #


func run() -> RunContext:
	return _run


func has_run() -> bool:
	return _run != null


func party() -> Array:
	return _run.party if _run != null else []


func active_region() -> String:
	if _run == null:
		return ""
	return str(_run.world_state.get("active_region", EncounterCatalogScript.STARTING_REGION))


func current_step() -> int:
	if _run == null:
		return 0
	return int(_run.world_state.get("steps", 0))


func catalog() -> SpeciesCatalog:
	_ensure_deps()
	return _catalog


func world_generator() -> WorldGenerator:
	_ensure_deps()
	return _world_gen


## True if a local save exists to continue from (the menu disables "Continue" otherwise).
func has_save() -> bool:
	return _latest_save_path() != ""


# === internals =============================================================================== #


func _ensure_deps() -> void:
	if _dal.is_empty():
		_dal = FakeDalScript.make()
	if _catalog == null:
		_catalog = SpeciesCatalog.new()
	if _world_gen == null:
		_world_gen = WorldGeneratorScript.new()


## Save the run aggregate through the DAL run repository. Returns a SaveResult, or null if the DAL
## has no run repository. The Supabase repository is async (await); the Fake is synchronous — both
## are awaited safely (awaiting a non-coroutine value is a harmless no-op in Godot 4).
func _save_to_dal() -> Variant:
	var repo: Variant = _dal.get("runs", null)
	if repo == null:
		return null
	return await repo.save_run(_run.to_dict(), _base_save_version)


## Seed the DAL store with the loaded run so a subsequent save_run conflict-checks against the right
## base version (only meaningful for the in-memory FakeDal; the Supabase store already has it).
func _seed_dal_from_run() -> void:
	var store: Variant = _dal.get("store", null)
	if store == null:
		return
	# FakeStore mirror: register the run + its version so save_run sees a non-stale base.
	store.runs[_run.run_id] = _run.to_dict()
	store.versions[_run.run_id] = _run.save_version


## The path of the most recently modified save file in user://saves, or "" if none. SaveEnvelope
## writes one file per run_id; "latest" = newest on disk (the Continue target).
func _latest_save_path() -> String:
	var dir_path := SaveEnvelopeScript.DEFAULT_DIR
	if not DirAccess.dir_exists_absolute(dir_path):
		return ""
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return ""
	var best_path := ""
	var best_mtime := -1
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.ends_with(".json"):
			var full := "%s/%s" % [dir_path, name]
			var mtime := FileAccess.get_modified_time(full)
			if mtime > best_mtime:
				best_mtime = mtime
				best_path = full
		name = dir.get_next()
	dir.list_dir_end()
	return best_path
