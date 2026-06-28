class_name WorldGenerator
extends RefCounted
## WorldGenerator — the region-generation FACADE (ADR-014, D2 + D5). INFRASTRUCTURE layer: the ONE
## interface callers use to obtain a region Layout. It composes:
##   * WfcSolver        — organic biome/connective-tissue fill (WFC2D, D2), and
##   * DungeonAssembler — authored SimpleDungeons set-piece rooms stitched on top (D5),
## both seeded by canonical_rng(run.seed, region_id) and, on solver failure, replaced by an AUTHORED
## fallback layout (no soft-lock). It computes NO gameplay number — it lays out tiles; it does not
## compute stats (Cluster 4 §3 / domain-purity gate; this lives in infrastructure/, never domain/).
##
## GENERATE-ONCE + PERSIST (ADR-007/014): generate() produces a Layout ONCE. The caller persists it
## via store()/world_state, and on a later load uses load_layout()/get_or_generate() which REHYDRATE
## the stored dict and NEVER re-run the solver. The solver is a client-side authoring aid, not the
## oracle — only its OUTPUT (the tile grid) is canonical, exactly like the Lab's persisted
## splice_config (ADR-014 / Integrations A1.2).
##
## THREADING (ADR-014): the WFC solve runs on a WorkerThreadPool task so a large region does not
## hitch the frame. Determinism is INDEPENDENT of thread scheduling: the solve draws ALL randomness
## from the injected CanonicalRNG sub-stream (a pure value object, not wall-clock/thread-order
## dependent), so whichever worker thread runs it, the SAME (region_id, seed) yields a bit-identical
## grid. `generate()` is the synchronous facade most callers want; `generate_threaded()` is the
## explicit WorkerThreadPool path the spec calls for (used by the game when generating off the main
## thread). Both produce the SAME Layout for the same inputs.
##
## BETTER TERRAIN SEAM: the WFC output is plain tile ids. A "Better Terrain"-style autotiler would
## run as a RENDER-TIME pass over this grid (cosmetic; it adds no tile that changes traversability),
## so it is intentionally NOT part of generation/persistence — the persisted Layout stays the
## canonical source and autotiling is re-derivable on display. (Hook: presentation reads Layout.tiles
## and applies its terrain set; nothing here blocks on vendoring it.)

## Where in RunContext.world_state generated layouts are stored (keyed by region_id).
const WORLD_STATE_KEY := "region_layouts"
# FNV-1a 64-bit basis/prime as int64 (GDScript int wraps two's-complement) — same scheme LabBench
# uses to turn a string op_id into a substream purpose, so worldgen + lab derive purposes the same
# way. A salt distinguishes the worldgen stream from any other (region, seed) consumer.
const _FNV_BASIS := -3750763034362895579  # 0xCBF29CE484222325
const _FNV_PRIME := 1099511628211
const _WORLDGEN_SALT := 0x7717  # arbitrary fixed salt; keeps the worldgen stream distinct.

var _rules: RegionRules


## Inject the region ruleset. If null, load the default catalog; if THAT fails, the generator still
## works for every region via its built-in authored fallback (the no-soft-lock guarantee).
func _init(rules: RegionRules = null) -> void:
	_rules = rules if rules != null else RegionRules.load_default()


# --- the facade ------------------------------------------------------------------------------- #


## generate(region_id, seed) -> Layout. The synchronous facade. Seeds a canonical sub-stream from
## (seed, region_id), runs WFC, stitches set-piece rooms, and on ANY solver failure returns the
## authored fallback for that region. Always returns a non-empty, fully-tiled Layout (never crashes
## / never an empty grid) — the no-soft-lock contract.
func generate(region_id: String, seed: int) -> Layout:
	var rng := region_rng(seed, region_id)
	return _generate_with_rng(region_id, seed, rng)


## The WorkerThreadPool path (ADR-014: "Runs on a WorkerThreadPool task → no frame hitch").
## IMPORTANT: this is a BLOCKING call — it runs the CPU-heavy solve on a worker thread and WAITS for
## it, so the work happens OFF the calling thread (no frame hitch from the solve itself) but the
## caller does not return until the layout is ready. This matches the intended generate-once-at-
## region-load usage (the overworld needs the Layout before it can place anything). For a truly
## non-blocking flow, a caller can run THIS method itself on a worker / coroutine; the result is
## identical regardless, because randomness is the injected canonical sub-stream (thread-order-
## independent). Returns the SAME Layout generate() would.
func generate_threaded(region_id: String, seed: int) -> Layout:
	# Only plain data crosses into the task closure (region_id/seed/result) — never `self` — to avoid
	# any thread-safety confusion about shared mutable state. The result slot is written by the task.
	var ctx := {"region_id": region_id, "seed": seed, "result": null}
	var task_id := WorkerThreadPool.add_task(func() -> void: _threaded_task(ctx))
	WorkerThreadPool.wait_for_task_completion(task_id)
	var out: Variant = ctx["result"]
	# Defensive: if the task somehow left no result, fall back to the synchronous path.
	return out if out is Layout else generate(region_id, seed)


func _threaded_task(ctx: Dictionary) -> void:
	ctx["result"] = generate(str(ctx["region_id"]), int(ctx["seed"]))


# --- generate-once + persistence (ADR-007/014) ----------------------------------------------- #


## Return the persisted layout for `region_id` if `world_state` already holds one (REUSE, no
## solver), else generate it ONCE, store it into `world_state` in place, and return it. This is the
## generate-once entry point the overworld uses: first visit generates + persists; every later load
## rehydrates. Mutates `world_state` (adds WORLD_STATE_KEY[region_id]) so the caller can save it.
func get_or_generate(region_id: String, seed: int, world_state: Dictionary) -> Layout:
	var existing := load_layout(region_id, world_state)
	if existing != null:
		return existing
	var layout := generate(region_id, seed)
	store(layout, world_state)
	return layout


## Rehydrate the persisted Layout for `region_id` from `world_state`, or null if none stored. NEVER
## regenerates (ADR-014). Pure read.
func load_layout(region_id: String, world_state: Dictionary) -> Layout:
	var bag: Variant = world_state.get(WORLD_STATE_KEY, {})
	if not (bag is Dictionary):
		return null
	var stored: Variant = (bag as Dictionary).get(region_id, null)
	if not (stored is Dictionary):
		return null
	return Layout.from_dict(stored)


## Persist a Layout into `world_state` (versioned-JSON dict, ADR-012; never a .tres). In place, so
## the caller's RunContext.world_state carries it into the next save.
func store(layout: Layout, world_state: Dictionary) -> void:
	if layout == null:
		return
	if not (world_state.get(WORLD_STATE_KEY, null) is Dictionary):
		world_state[WORLD_STATE_KEY] = {}
	(world_state[WORLD_STATE_KEY] as Dictionary)[layout.region_id] = layout.to_dict()


# --- canonical RNG derivation (public + static so tests reproduce it EXACTLY) ---------------- #


## The canonical sub-stream that seeds generation for (run_seed, region_id). Reproducible + pure:
## the same inputs always rebuild the same RNG, so a test can regenerate the exact stream the
## generator used. region_id is hashed to an int "purpose" (FNV-1a, the LabBench scheme).
static func region_rng(run_seed: int, region_id: String) -> CanonicalRNG:
	return CanonicalRNG.new(run_seed).substream(region_purpose(region_id) ^ _WORLDGEN_SALT)


## Deterministic int purpose for CanonicalRNG.substream from a region id string (FNV-1a 64-bit,
## masked into int64 — GDScript int wraps two's-complement on overflow). Pure + reproducible.
static func region_purpose(region_id: String) -> int:
	var h: int = _FNV_BASIS
	for i in region_id.length():
		h = h ^ region_id.unicode_at(i)
		h = h * _FNV_PRIME
	return h


# --- internals -------------------------------------------------------------------------------- #


func _generate_with_rng(region_id: String, seed: int, rng: CanonicalRNG) -> Layout:
	var rules: Dictionary = _rules.wfc_rules(region_id) if _rules != null else {}
	if rules.is_empty():
		# Unknown region (or no catalog) -> authored fallback for a sane default-sized grid.
		return _authored_fallback(region_id, seed, 16, 16, "unknown_region")
	var width: int = int(rules.get("width", 16))
	var height: int = int(rules.get("height", 16))
	var attempt_limit: int = int(rules.get("attempt_limit", 20000))
	var solver := WfcSolver.new(width, height, rules, attempt_limit)
	var grid := solver.solve(rng)
	if grid.is_empty() or grid.size() != width * height:
		# Solver failed (over-constrained ruleset or attempt budget exhausted) -> authored fallback.
		var reason := "wfc_" + _result_name(solver.last_result())
		return _authored_fallback(region_id, seed, width, height, reason)
	var layout := Layout.new(region_id, seed, width, height)
	layout.tiles = grid
	layout.metadata = {
		"source": "wfc",
		"fallback": false,
		"attempts": solver.attempts_used(),
	}
	# D5 — stitch authored SimpleDungeons set-piece rooms ON TOP of the organic WFC fill, using the
	# SAME canonical sub-stream (so room placement is part of the reproducible (region, seed) output).
	if _rules != null:
		var spec := _rules.setpiece(region_id)
		if not spec.is_empty():
			DungeonAssembler.stitch(layout, spec, rng)
			layout.metadata["setpiece"] = true
	return layout


## The hand-authored fallback layout (ADR-014: "fallback to a hand-authored layout if it fails (no
## soft-lock)"). A simple, always-valid walled room: a wall ring (tile 3) around a floor (tile 0).
## Deterministic, depends on nothing random — it is the guaranteed-traversable safety net. Marked in
## metadata so callers/tests can see the fallback fired.
func _authored_fallback(
	region_id: String, seed: int, width: int, height: int, reason: String
) -> Layout:
	var w: int = max(width, 4)
	var h: int = max(height, 4)
	var layout := Layout.new(region_id, seed, w, h)
	for y in h:
		for x in w:
			var is_border := x == 0 or y == 0 or x == w - 1 or y == h - 1
			layout.set_cell(x, y, 3 if is_border else 0)
	layout.metadata = {"source": "authored_fallback", "fallback": true, "reason": reason}
	# Set-piece rooms still stitch onto the authored base so a fallback region keeps its boss lair /
	# ritual site (D5 composes with the fallback too), using a fresh deterministic sub-stream.
	if _rules != null:
		var spec := _rules.setpiece(region_id)
		if not spec.is_empty():
			DungeonAssembler.stitch(layout, spec, region_rng(seed, region_id + ":fallback"))
			layout.metadata["setpiece"] = true
	return layout


func _result_name(code: int) -> String:
	match code:
		WfcSolver.Result.CONTRADICTION:
			return "contradiction"
		WfcSolver.Result.BUDGET_EXHAUSTED:
			return "budget_exhausted"
		_:
			return "ok"
