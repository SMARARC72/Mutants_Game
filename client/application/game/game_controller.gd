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

## Wave 18 SAVE TRUST: request_save() reports its outcome through these instead of returning a
## silently-dropped bool. SaveSentry (autoload) surfaces them as a toast / persistent warning.
signal save_succeeded
signal save_failed(reason: String)

const RunContextScript := preload("res://application/persistence/run_context.gd")
const SaveEnvelopeScript := preload("res://application/persistence/save_envelope.gd")
const FakeDalScript := preload("res://infrastructure/dal/fake_dal.gd")
const WorldGeneratorScript := preload("res://infrastructure/worldgen/world_generator.gd")
const EncounterCatalogScript := preload("res://application/overworld/encounter_catalog.gd")
const GearCatalogScript := preload("res://infrastructure/catalog/gear_catalog.gd")
const LootDropServiceScript := preload("res://application/game/loot_drop_service.gd")

## The run.flags key holding the active/lead party member index (Slice 3b). 0 by default.
const ACTIVE_CREATURE_FLAG := "active_creature"
const InventoryAdapterScript := preload("res://infrastructure/inventory/inventory_adapter.gd")
const MortalityServiceScript := preload("res://application/game/mortality_service.gd")

## Wave 18 — camp Rest: the small essence fee a full night's tending costs (application-layer
## economy constant, like the Bloomwarden deltas; the oracle owns no camp math).
const REST_ESSENCE_FEE := 5

## Fresh-run Lab reagents (Wave 5): one in-force gene-vial + two organs so the Mutate rite is
## committable on a brand-new run. REAL keys from client/catalog/splice_rules.json — "verdant"
## (gene_compat: Eros, the starter line's force) and "claw"/"horn" (ingredient_compat organs).
## [item_type, item_key, qty] rows fed through the InventoryAdapter.
const STARTER_REAGENTS := [
	["gene", "verdant", 1],
	["organ", "claw", 1],
	["organ", "horn", 1],
]

## Slice 4 — Bloomwardens faction standing. The run.flags key holding the standing integer (0 =
## Stranger baseline).
const BLOOMWARDENS_STANDING_FLAG := "bloomwardens_standing"
## Standing deltas: catching/befriending a creature is the Bloomwarden way (+); killing it is butchery
## (-). Small steps — the MVP only wants a taste of reactivity.
const BLOOM_STANDING_ON_CATCH := 5
const BLOOM_STANDING_ON_KILL := -3
## Standing tier thresholds (Mutants_Game_Factions.md: Stranger -> Associate -> Sworn -> Champion ->
## Hand). A standing >= a threshold's value resolves to that tier (checked high-to-low).
const BLOOM_STANDING_TIERS := [
	[60, "Hand"],
	[40, "Champion"],
	[20, "Sworn"],
	[8, "Associate"],
	[0, "Stranger"],
]

var _run: RunContext = null
var _dal: Dictionary = {}
var _catalog: SpeciesCatalog = null
var _world_gen: WorldGenerator = null
var _gear_catalog: GearCatalog = null
## The save_version we last loaded/saved at — the conflict base for the DAL write (TDD §10.3).
var _base_save_version: int = 0
## Live InventoryAdapter over the active run's inventory rows (Slice 3a — the Lab UI's parts drawer).
## Lazily built from run.inventory on first inventory() call; a debit during a Lab commit is visible
## to later reads, and write_inventory() flushes it back to run.inventory before save. NEVER persisted
## (it is a transient view; the rows are the source of truth). Reset whenever the active run changes.
var _inventory: InventoryAdapter = null
## Wave 18: the memorials/scars the LAST apply_battle_result produced (the battle screen reads
## them for the death beat). Transient presentation-facing bookkeeping; the graveyard itself is
## persisted in run.flags.
var _last_deaths: Array = []
var _last_scarred: Array = []
## Wave 18 save trust: how the last save_run() went ({local_ok, dal_ok, reason}) — request_save
## folds it into the save_succeeded/save_failed signals.
var _last_save_report: Dictionary = {}


func _ready() -> void:
	# Default offline wiring. configure() can swap in the Supabase DAL when configured.
	if _dal.is_empty():
		_dal = FakeDalScript.make()
	if _catalog == null:
		_catalog = SpeciesCatalog.new()
	if _world_gen == null:
		_world_gen = WorldGeneratorScript.new()
	if _gear_catalog == null:
		_gear_catalog = GearCatalogScript.new()


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
	run.inventory = _starter_inventory_rows()
	_run = run
	_base_save_version = 0
	_inventory = null  # drop any prior run's live drawer; rebuild lazily from the new run's rows
	_last_deaths = []
	_last_scarred = []
	run_changed.emit(_run)
	# Wave 18 save trust: a brand-new run is continuable from step 0 (the ledger exists before the
	# first fight). Offline the DAL fake resolves synchronously, so new_run stays synchronous too.
	await save_run()
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
	_inventory = null  # the loaded run's drawer is rebuilt lazily from its restored rows
	_last_deaths = []
	_last_scarred = []
	# Mirror the loaded aggregate into the DAL so a later save_run conflict-checks against it.
	_seed_dal_from_run()
	run_changed.emit(_run)
	return true


## Persist the active run: write the versioned-JSON envelope to user:// ALWAYS, and push the run
## aggregate through the DAL (bumping save_version on accept). Returns true on success. No-op (false)
## if there is no active run.
func save_run() -> bool:
	if _run == null:
		_last_save_report = {"local_ok": false, "dal_ok": false, "reason": "no active run"}
		return false
	_ensure_deps()
	# Flush the live parts drawer back into the data-only rows so a Lab debit is in the saved snapshot.
	write_inventory()
	# 1) DAL write (conflict-checked). On accept the store bumps save_version; mirror it back. The
	#    await suspends only for the async Supabase repo; the Fake repo resolves synchronously (no
	#    suspension), so save_run() returns its bool synchronously offline / in tests.
	var dal_ok := true
	var dal_reason := ""
	var result: Variant = await _save_to_dal()
	if result != null and result.is_ok():
		_run.save_version = result.save_version
		_base_save_version = result.save_version
	elif result != null:
		dal_ok = false
		dal_reason = str(result.message)
	# 2) Local user:// save ALWAYS (offline source of truth for Continue). Uses the (possibly
	#    bumped) save_version so the on-disk envelope and the DAL agree.
	var json := SaveEnvelopeScript.build_json(_run.to_dict())
	var path := SaveEnvelopeScript.path_for_run(_run.run_id)
	var err := SaveEnvelopeScript.save_to_path(path, json)
	var reason := dal_reason
	if err != OK:
		reason = "the local ledger refused the ink (error %d)" % err
	_last_save_report = {"local_ok": err == OK, "dal_ok": dal_ok, "reason": reason}
	return err == OK


## Wave 18 SAVE TRUST: save with a spoken outcome. Wraps save_run() and emits save_succeeded /
## save_failed(reason) so every call site stops being fire-and-forget (SaveSentry surfaces the
## signals as a quill-scratch toast / a persistent warning). Returns true only when BOTH the
## local envelope and the DAL write landed. Synchronous offline (the FakeDal never suspends).
func request_save() -> bool:
	var local_ok: bool = await save_run()
	var dal_ok := bool(_last_save_report.get("dal_ok", true))
	if local_ok and dal_ok:
		save_succeeded.emit()
		return true
	save_failed.emit(str(_last_save_report.get("reason", "the ledger did not take the ink")))
	return false


## Wave 18 CONTINUE GATE: the health of the newest local save — "none" (no file), "ok" (the
## envelope parses to a run payload) or "illegible" (a file exists but cannot be trusted: bad
## JSON, checksum mismatch, empty run). The menu turns "illegible" into an in-world dialog
## instead of a dead Continue button.
func continue_health() -> String:
	var path := _latest_save_path()
	if path == "":
		return "none"
	var text := SaveEnvelopeScript.load_from_path(path)
	if text == "":
		return "illegible"
	var envelope := SaveEnvelopeScript.parse_json(text)
	if envelope.is_empty() or SaveEnvelopeScript.run_payload(envelope).is_empty():
		return "illegible"
	return "ok"


# === battle result application ================================================================ #


## Apply a BattleSession result back to the run. BACKWARD-COMPATIBLE with Slice 1: still awards xp to
## essence + records last_battle_won. Slice 2 additions (only when the keys are present, so a Slice 1
## auto result is unchanged): a CAUGHT creature_instance is appended to the party, and the last battle
## outcome reason (win/lose/fled/caught) is recorded for the overworld to read. Slice 4 additions:
## Bloomwardens FACTION STANDING reactivity (caught a Verdant creature -> standing up; killed one ->
## standing down — "tend, heal, befriend; never butcher"), and the boss-cleared / slice-victory flags
## when a boss fight is won. Pure bookkeeping — the real xp/level curve is a later slice. Returns the
## run for chaining.
func apply_battle_result(result: Dictionary) -> RunContext:
	if _run == null:
		return null
	var gained := int(result.get("xp", 0))
	_run.essence += gained  # Slice 1 stand-in growth resource.
	# Wave 3 consequence: DEFEAT costs ~25% of banked essence (round down, floor 0) — losing has a
	# price the run actually feels. A flee is an escape, not a defeat; it stays cost-free.
	if not bool(result.get("player_won", false)) and str(result.get("winner", "")) != "fled":
		_run.essence = maxi(0, _run.essence - int(_run.essence / 4.0))
	# Wave 3 consequence: fold the live end-of-battle HP back onto the party — the battle leaves
	# marks. Entries are shaped by the battle screen ({index, hp, max_hp} per surviving mapping);
	# results without the key (auto/boss round-trips, older callers) are untouched.
	for entry: Variant in result.get("party_hp", []) as Array:
		if not (entry is Dictionary):
			continue
		var idx := int((entry as Dictionary).get("index", -1))
		if idx >= 0 and idx < _run.party.size() and _run.party[idx] is Dictionary:
			var creature: Dictionary = _run.party[idx]
			creature["hp"] = int((entry as Dictionary).get("hp", 0))
			creature["max_hp"] = int((entry as Dictionary).get("max_hp", 0))
	_run.flags["last_battle_won"] = bool(result.get("player_won", false))
	_run.flags["last_battle_reason"] = str(result.get("reason", ""))
	# Slice 2: a captured wild creature joins the party (shaped as a creature_instance by the capture
	# service). Append a deep copy so the run owns it independent of the result dict.
	var caught: Dictionary = result.get("caught", {})
	if not caught.is_empty():
		_run.party.append(caught.duplicate(true))
	# Wave 18 DEATH RULE (application layer; HP/is_dead never touch the domain): a battle that was
	# not lost scars its 0-HP members at 1 HP (mercy); a LOST battle buries them — except the lead
	# (the Last Light) — into run.flags["graveyard"], crediting parts ("death funds creation").
	var mortality: Dictionary = MortalityServiceScript.resolve(
		_run, result, active_creature_index(), inventory(), catalog()
	)
	_last_deaths = mortality.get("deaths", [])
	_last_scarred = mortality.get("scarred", [])
	# Slice 4: Bloomwardens reactivity (only in the Verdant region — a "taste of standing" per the MVP).
	_apply_bloomwardens_reactivity(result, caught)
	# Slice 4: a won boss fight clears the slice climax + marks victory (idempotent flag set).
	if bool(result.get("boss_win", false)):
		_mark_slice_cleared()
	# W17 (C16) battle SPOILS: a win pays drachma per defeated enemy (the Trader's coin source) and
	# occasionally drops GEAR into the run drawer — deterministic per (run.seed, step) through the
	# LootDropService's canonical sub-stream. The drop id lands in run.flags for the UI to surface.
	_run.drachma += LootDropServiceScript.drachma_for(result)
	if bool(result.get("player_won", false)) and int(result.get("enemy_defeated", 0)) > 0:
		var drop := LootDropServiceScript.roll_drop(_run.seed, current_step(), gear_catalog())
		if drop != "":
			inventory().add(GearService.GEAR_ITEM_TYPE, drop, 1)
			_run.flags["last_gear_drop"] = drop
	return _run


# === Wave 18: death with weight + camp ======================================================== #


## What the LAST apply_battle_result cost the coven: { "deaths": [memorial dicts — [] when
## nobody died], "scarred": [party indices dragged out at 1 HP] }. The battle screen reads the
## deaths for the death beat (knell + desaturate pulse + epitaph). The persisted ledger itself
## lives in run.flags["graveyard"] (MortalityService.graveyard_of).
func last_mortality() -> Dictionary:
	return {"deaths": _last_deaths.duplicate(true), "scarred": _last_scarred.duplicate()}


## Camp REST (Wave 18): a night's tending fully heals every persisted wound and clears the
## "scarred" mark, for a small essence fee (REST_ESSENCE_FEE). Data-only bookkeeping — hp/max_hp
## were engine-written by past battles; no combat number is computed here. Returns
## { ok, healed, fee, reason } (ok=false leaves the run untouched). The caller saves the run.
func rest_at_camp() -> Dictionary:
	if _run == null:
		return {"ok": false, "healed": 0, "fee": 0, "reason": "no active run"}
	if _run.essence < REST_ESSENCE_FEE:
		return {"ok": false, "healed": 0, "fee": REST_ESSENCE_FEE, "reason": "essence"}
	var healed := 0
	for entry: Variant in _run.party:
		if not (entry is Dictionary):
			continue
		var creature: Dictionary = entry
		var tended := false
		if creature.has("hp") and creature.has("max_hp"):
			var ceiling := int(creature.get("max_hp", 0))
			if int(creature.get("hp", 0)) < ceiling:
				creature["hp"] = ceiling
				tended = true
		if creature.has("scarred"):
			creature.erase("scarred")
			tended = true
		if tended:
			healed += 1
	_run.essence -= REST_ESSENCE_FEE
	return {"ok": true, "healed": healed, "fee": REST_ESSENCE_FEE, "reason": ""}


# === Slice 4: Bloomwardens faction standing (a single tracked value in run.flags) ============== #


## The current Bloomwardens standing value (run.flags), or 0 when there is no run.
func bloomwardens_standing() -> int:
	if _run == null:
		return 0
	return int(_run.flags.get(BLOOMWARDENS_STANDING_FLAG, 0))


## The named standing TIER for the current Bloomwardens standing (Stranger..Hand). Pure threshold
## lookup; never crashes. "Stranger" when there is no run.
func bloomwardens_tier() -> String:
	var standing := bloomwardens_standing()
	for entry in BLOOM_STANDING_TIERS:
		if standing >= int((entry as Array)[0]):
			return str((entry as Array)[1])
	return "Stranger"


## Nudge Bloomwardens standing by `delta` (the caller saves the run). Persisted in run.flags. Clamped
## at a floor of 0 (the MVP keeps standing non-negative — hostility depth is a later slice). Returns
## the new standing value (or 0 when there is no run).
func adjust_bloomwardens_standing(delta: int) -> int:
	if _run == null:
		return 0
	var next := maxi(0, bloomwardens_standing() + delta)
	_run.flags[BLOOMWARDENS_STANDING_FLAG] = next
	return next


## Apply the Bloomwardens reactivity hook from a battle result: a CATCH (caught a Verdant creature)
## nudges standing up; a KILL (won, downed an enemy, captured nothing) nudges it down. Only fires for
## battles in the Verdant region (the Bloomwardens' turf). A flee / loss is standing-neutral.
func _apply_bloomwardens_reactivity(result: Dictionary, caught: Dictionary) -> void:
	if _run == null or active_region() != EncounterCatalogScript.STARTING_REGION:
		return
	if not caught.is_empty():
		adjust_bloomwardens_standing(BLOOM_STANDING_ON_CATCH)
		return
	var player_won := bool(result.get("player_won", false))
	var killed := int(result.get("enemy_defeated", 0))
	if player_won and killed > 0:
		adjust_bloomwardens_standing(BLOOM_STANDING_ON_KILL)


## Mark the Verdant slice climax cleared + the slice victory state (idempotent). The boss trigger reads
## the cleared flag to stop re-firing; the victory flag is the run's "slice complete" state.
func _mark_slice_cleared() -> void:
	if _run == null:
		return
	var trigger := EncounterCatalogScript.boss_trigger_for(active_region())
	_run.flags[str(trigger.get("cleared_flag", "verdant_boss_cleared"))] = true
	_run.flags[str(trigger.get("victory_flag", "slice_verdant_victory"))] = true


## True iff the Verdant slice boss has been cleared (the run's victory state).
func slice_cleared() -> bool:
	if _run == null:
		return false
	var trigger := EncounterCatalogScript.boss_trigger_for(active_region())
	return bool(_run.flags.get(str(trigger.get("cleared_flag", "verdant_boss_cleared")), false))


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


## The active run's parts/vials inventory as an InventoryAdapter (Slice 3a — the Lab UI reads its
## ingredient drawer through this). Lazily built from run.inventory; the SAME live adapter is returned
## on later calls so a debit during a Lab commit is visible to a later read. write_inventory() flushes
## it back to the data-only run.inventory before save. Returns an empty adapter when there is no run.
func inventory() -> InventoryAdapter:
	if _run == null:
		return InventoryAdapterScript.new()
	if _inventory == null:
		_inventory = InventoryAdapterScript.from_rows(_run.inventory)
	return _inventory


## Flush the live inventory adapter back into the data-only run.inventory rows (call before save so
## the persisted snapshot matches the in-memory drawer). No-op when no run / no adapter was created.
func write_inventory() -> void:
	if _run == null or _inventory == null:
		return
	_run.inventory = _inventory.to_dict()


## The Lab gate's player_state ({corruption, unlocks, has_parts}) for the LegalitySolver. corruption
## is the run's cumulative player track; unlocks/has_parts come from run.flags (data-only lists the
## later progression slices populate — default empty so a fresh run gates taboo ops as designed).
func lab_player_state() -> Dictionary:
	if _run == null:
		return {"corruption": 0, "unlocks": [], "has_parts": []}
	return {
		"corruption": _run.corruption,
		"unlocks": _as_string_array(_run.flags.get("lab_unlocks", [])),
		"has_parts": _as_string_array(_run.flags.get("lab_parts", [])),
	}


## Append a spliced creature_instance (the Lab UI's commit output) to the active party. Deep-copied
## so the run owns it. Returns the new party size, or -1 when there is no active run.
func add_party_member(creature_instance: Dictionary) -> int:
	if _run == null:
		return -1
	_run.party.append(creature_instance.duplicate(true))
	return _run.party.size()


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


## The gear catalog facade (Slice 3b). Lazily constructed + cached like the species catalog.
func gear_catalog() -> GearCatalog:
	_ensure_deps()
	return _gear_catalog


func world_generator() -> WorldGenerator:
	_ensure_deps()
	return _world_gen


# === party: active/lead creature (Slice 3b) =================================================== #


## The index of the active/lead party member (persisted in run.flags). Clamped to a valid party
## index; 0 when there is no run / empty party.
func active_creature_index() -> int:
	if _run == null or _run.party.is_empty():
		return 0
	var idx := int(_run.flags.get(ACTIVE_CREATURE_FLAG, 0))
	return clampi(idx, 0, _run.party.size() - 1)


## The active/lead creature_instance dict, or {} when there is no run / empty party.
func active_creature() -> Dictionary:
	if _run == null or _run.party.is_empty():
		return {}
	var entry: Variant = _run.party[active_creature_index()]
	return entry if entry is Dictionary else {}


## Set the active/lead party member by index. Persists to run.flags (the caller saves the run).
## Out-of-range indices are ignored (returns false); a valid set returns true.
func set_active_creature(index: int) -> bool:
	if _run == null or index < 0 or index >= _run.party.size():
		return false
	_run.flags[ACTIVE_CREATURE_FLAG] = index
	return true


## True if a local save exists to continue from (the menu disables "Continue" otherwise).
func has_save() -> bool:
	return _latest_save_path() != ""


# === internals =============================================================================== #


## The data-only inventory rows a fresh run starts with (STARTER_REAGENTS through the adapter, so
## stacking/shape stay single-sourced). Pure data — no gameplay number is computed here.
static func _starter_inventory_rows() -> Array:
	var inv: InventoryAdapter = InventoryAdapterScript.new()
	for entry in STARTER_REAGENTS:
		var row: Array = entry
		inv.add(str(row[0]), str(row[1]), int(row[2]))
	return inv.to_dict()


static func _as_string_array(value: Variant) -> Array:
	# Coerce a flags value into an Array[String] of ids (defensive: flags are free-form data).
	var out: Array = []
	if value is Array:
		for v in value:
			out.append(str(v))
	return out


func _ensure_deps() -> void:
	if _dal.is_empty():
		_dal = FakeDalScript.make()
	if _catalog == null:
		_catalog = SpeciesCatalog.new()
	if _world_gen == null:
		_world_gen = WorldGeneratorScript.new()
	if _gear_catalog == null:
		_gear_catalog = GearCatalogScript.new()


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
