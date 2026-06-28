class_name WfcSolver
extends RefCounted
## WfcSolver — a self-contained, deterministic Wave-Function-Collapse 2D tile solver
## (ADR-014). INFRASTRUCTURE layer: it COLLAPSES a tile grid under adjacency constraints; it
## computes NO gameplay number (purity gate, Cluster 4 §3). This is the same job
## godot-constraint-solving's `WFC2DGenerator` does — see infrastructure/worldgen/README and
## THIRD_PARTY.md for why we ship a small self-contained core instead of that Node-based addon
## (its WFC draws from Godot's `RandomNumberGenerator`, which is NOT bit-identical to our
## canonical PCG32 across OS targets, so it cannot satisfy ADR-014's cross-platform reproducible
## seeding without forking its internals — and Godot is not installable here to verify a clean 4.7
## vendor). The CSP/backtracking shape mirrors infrastructure/lab/csp_solver.gd's precedent.
##
## DETERMINISM (the load-bearing property, ADR-014/001): ALL randomness is drawn from the injected
## CanonicalRNG sub-stream — never `randf`/`randi`/`randomize` or wall-clock/thread scheduling. The
## cell-selection + weighted-tile-pick order is a pure function of (grid state, rng draws), so the
## SAME (rules, seed) yields a bit-identical grid regardless of which thread runs it. Ties in
## entropy are broken by the lowest flat index (stable), never by hashing/iteration order.
##
## ALGORITHM: classic observe/propagate WFC with chronological backtracking.
##   1. observe   — pick the undecided cell with the fewest remaining options (min-entropy);
##                  collapse it to ONE tile chosen by a weighted canonical-RNG draw.
##   2. propagate — remove now-impossible options from neighbours (arc consistency over the
##                  adjacency rules); cascade. A cell reaching ZERO options = a contradiction.
##   3. on contradiction, BACKTRACK to the last collapse and try the next tile; if a cell
##      exhausts every tile, unwind further. An overall attempt budget bounds the work so a
##      pathological ruleset fails CLEANLY (the facade then uses the authored fallback) instead
##      of soft-locking.
##
## RULES (data): { "tiles": Array[int] (the palette),
##                 "weights": { tile_id: float } (selection weight; default 1.0),
##                 "adjacency": { dir: { tile_id: Array[int] (tiles allowed on that side) } } }
## dir is one of N/E/S/W. Adjacency is treated as the caller authored it (we do NOT auto-symmetrise
## — author both directions; tests + the facade's region rules do). Missing entries = "nothing
## allowed", which the solver surfaces as a contradiction rather than silently permitting all.

# Result codes from solve().
enum Result { OK, CONTRADICTION, BUDGET_EXHAUSTED }

const DIRS := ["N", "E", "S", "W"]
const DX := {"N": 0, "E": 1, "S": 0, "W": -1}
const DY := {"N": -1, "E": 0, "S": 1, "W": 0}
const OPPOSITE := {"N": "S", "S": "N", "E": "W", "W": "E"}

var _width: int = 0
var _height: int = 0
var _palette: Array = []  # Array[int] of tile ids, in a stable order.
var _weights: Dictionary = {}  # tile_id -> float weight.
var _adjacency: Dictionary = {}  # dir -> { tile_id -> Array[int] allowed neighbours }.
var _attempt_limit: int = 0
var _last_result: int = Result.OK
var _attempts_used: int = 0
# How many times the solver had to UNWIND a collapse — i.e. a propagation dead-ended and we re-tried
# a different tile (_retry_or_backtrack) or popped the decision stack (_backtrack). Zero means the
# grid collapsed greedily with no contradiction; >0 proves the backtracking path actually fired
# (the determinism-fragile code is exercised). Read via backtracks_used().
var _backtracks_used: int = 0

# Per-cell option sets: Array of Dictionary acting as an ordered int-set (tile_id -> true).
var _cells: Array = []


func _init(width: int, height: int, rules: Dictionary, attempt_limit: int = 10000) -> void:
	_width = width
	_height = height
	_palette = (rules.get("tiles", []) as Array).duplicate()
	_weights = (rules.get("weights", {}) as Dictionary).duplicate(true)
	_adjacency = (rules.get("adjacency", {}) as Dictionary).duplicate(true)
	_attempt_limit = attempt_limit


func last_result() -> int:
	return _last_result


func attempts_used() -> int:
	return _attempts_used


## Count of collapse UNWINDS (retries + decision-stack pops). >0 proves the backtracking path ran.
func backtracks_used() -> int:
	return _backtracks_used


## Solve the grid. `rng` is the injected canonical sub-stream (NEVER global RNG). On success
## returns a row-major PackedInt32Array of length width*height; on failure returns an empty array
## and last_result() explains why (CONTRADICTION = over-constrained ruleset, BUDGET_EXHAUSTED =
## attempt limit hit). The facade maps either failure to the authored fallback (ADR-014). One
## return point: the observe/propagate loop lives in _run_loop so this stays under max-returns.
func solve(rng: CanonicalRNG) -> PackedInt32Array:
	_attempts_used = 0
	_backtracks_used = 0
	var grid := PackedInt32Array()
	if _width <= 0 or _height <= 0:
		_last_result = Result.CONTRADICTION
	elif _palette.is_empty() or _attempt_limit <= 0:
		# No tiles to place, or a zero attempt budget (the forced-failure test path) -> clean fail.
		_last_result = Result.BUDGET_EXHAUSTED if _attempt_limit <= 0 else Result.CONTRADICTION
	else:
		_init_cells()
		_last_result = _run_loop(rng)
		if _last_result == Result.OK:
			grid = _collapse_to_grid()
	return grid


## The observe/propagate/backtrack loop. Returns a Result code; on OK every cell holds exactly one
## option (the caller reads them with _collapse_to_grid). `decisions` is the backtracking stack:
## each entry records a collapsed cell, the tiles already TRIED there (never retried), and a
## SNAPSHOT of every cell's options to restore on unwind. Snapshotting is simple + correct; grids
## here are small (region-sized), so the cost is fine and determinism is trivially preserved.
func _run_loop(rng: CanonicalRNG) -> int:
	var decisions: Array = []
	while true:
		_attempts_used += 1
		if _attempts_used > _attempt_limit:
			return Result.BUDGET_EXHAUSTED
		var cell_index := _pick_min_entropy_cell()
		if cell_index == -1:
			return Result.OK  # every cell decided (exactly one option each).
		var options := _options_of(cell_index)
		if options.is_empty():
			# Contradiction at observe time: unwind to the most recent collapse with an untried tile.
			_backtracks_used += 1
			if not _backtrack(decisions):
				return Result.CONTRADICTION
			continue
		var snapshot := _snapshot_cells()
		var chosen := _weighted_pick(options, rng)
		if chosen == Layout.EMPTY:
			# Malformed ruleset: this cell's options are all outside the palette -> contradiction.
			return Result.CONTRADICTION
		_set_single(cell_index, chosen)
		if _propagate(cell_index):
			decisions.append({"cell": cell_index, "tried": [chosen], "snapshot": snapshot})
		else:
			# Propagation dead-ended (a cell lost every option): restore, then unwind — re-try a
			# different tile here, or pop the decision stack. This is the determinism-fragile path.
			_backtracks_used += 1
			_restore_cells(snapshot)
			if not _retry_or_backtrack(cell_index, chosen, snapshot, decisions, rng):
				return Result.CONTRADICTION
	# Unreachable (the loop only exits via return); satisfies the typed-return checker.
	@warning_ignore("unreachable_code")
	return Result.CONTRADICTION


# --- observe ---------------------------------------------------------------------------------- #


## The undecided cell with the FEWEST remaining options (>1). Ties broken by lowest flat index
## (stable, deterministic). Returns -1 when all cells are decided (size 1). A size-0 cell short-
## circuits to itself so the caller sees the contradiction immediately.
func _pick_min_entropy_cell() -> int:
	var best := -1
	var best_count := 0x7FFFFFFF
	for i in _cells.size():
		var count: int = (_cells[i] as Dictionary).size()
		if count == 0:
			return i
		if count <= 1:
			continue
		if count < best_count:
			best_count = count
			best = i
	return best


## Weighted choice among `options` using the canonical RNG. Walks the palette in its STABLE order
## (not the option-dict order) so the cumulative bands are reproducible; draws ONE float in [0,1).
## Returns Layout.EMPTY (-1) when NO option survives the palette filter — i.e. a malformed ruleset
## left a cell whose only options are tiles absent from `tiles`/the palette. The caller treats EMPTY
## as a contradiction (clean CONTRADICTION result), never indexing into an empty array (a crash).
func _weighted_pick(options: Array, rng: CanonicalRNG) -> int:
	# Keep only options that actually exist in the palette (defensive against malformed adjacency
	# that references an undeclared tile). In well-formed rules every option is already in _palette.
	var ordered: Array = []
	for tile in _palette:
		if options.has(tile):
			ordered.append(tile)
	if ordered.is_empty():
		return Layout.EMPTY
	var total := 0.0
	for tile in ordered:
		total += _weight_of(tile)
	if total <= 0.0:
		# All-zero (or missing) weights: fall back to a uniform canonical pick over the stable order.
		return int(ordered[rng.randint(0, ordered.size() - 1)])
	var roll := rng.next_float() * total
	var acc := 0.0
	for tile in ordered:
		acc += _weight_of(tile)
		if roll < acc:
			return int(tile)
	return int(ordered[ordered.size() - 1])


func _weight_of(tile: int) -> float:
	return float(_weights.get(tile, 1.0))


# --- propagate (arc consistency) -------------------------------------------------------------- #


## Remove options made impossible by the current grid, cascading from `start_index`. Returns false
## if any cell loses ALL options (a contradiction). Worklist-based so a single collapse fully
## settles before observe runs again.
func _propagate(start_index: int) -> bool:
	var work: Array = [start_index]
	while not work.is_empty():
		var idx: int = work.pop_back()
		var x := idx % _width
		var y := idx / _width
		for dir in DIRS:
			var nx: int = x + int(DX[dir])
			var ny: int = y + int(DY[dir])
			if nx < 0 or ny < 0 or nx >= _width or ny >= _height:
				continue
			var n_index := ny * _width + nx
			if _constrain_neighbour(idx, n_index, dir):
				if (_cells[n_index] as Dictionary).is_empty():
					return false
				if not work.has(n_index):
					work.append(n_index)
	return true


## Drop from neighbour `n_index` (on side `dir` of `idx`) any tile that NO current option of `idx`
## permits. Returns true if the neighbour's option set shrank (so it must be re-propagated).
func _constrain_neighbour(idx: int, n_index: int, dir: String) -> bool:
	var allowed := _allowed_into(idx, dir)
	var neighbour: Dictionary = _cells[n_index]
	var to_remove: Array = []
	for tile in neighbour:
		if not allowed.has(tile):
			to_remove.append(tile)
	for tile in to_remove:
		neighbour.erase(tile)
	return not to_remove.is_empty()


## The union of all tiles permitted on the `dir` side of cell `idx`, given its current options.
## (For each option of idx, the adjacency rule lists which neighbour tiles are legal on that side.)
func _allowed_into(idx: int, dir: String) -> Dictionary:
	var dir_rules: Dictionary = _adjacency.get(dir, {})
	var allowed: Dictionary = {}
	for tile in _cells[idx] as Dictionary:
		var legal: Array = dir_rules.get(tile, [])
		for t in legal:
			allowed[int(t)] = true
	return allowed


# --- backtracking ----------------------------------------------------------------------------- #


func _retry_or_backtrack(
	cell_index: int, chosen: int, snapshot: Array, decisions: Array, rng: CanonicalRNG
) -> bool:
	# `chosen` failed at this cell. Try the next untried option here; if none remain, unwind.
	var tried: Array = [chosen]
	while true:
		var remaining: Array = []
		for tile in _options_of(cell_index):
			if not tried.has(tile):
				remaining.append(tile)
		if remaining.is_empty():
			return _backtrack(decisions)
		var next_tile := _weighted_pick(remaining, rng)
		if next_tile == Layout.EMPTY:
			# Defensive: malformed options with nothing in-palette -> unwind the decision stack.
			return _backtrack(decisions)
		tried.append(next_tile)
		_set_single(cell_index, next_tile)
		if _propagate(cell_index):
			decisions.append({"cell": cell_index, "tried": tried.duplicate(), "snapshot": snapshot})
			return true
		_restore_cells(snapshot)
	# Unreachable (the loop only returns via the branches above); required so GDScript's static
	# analysis can prove every path returns a value ("Not all code paths return").
	@warning_ignore("unreachable_code")
	return false


func _backtrack(decisions: Array) -> bool:
	# Pop collapses until one has an untried tile, then re-collapse it to that tile. Restoring the
	# popped decision's snapshot returns the grid to its exact pre-collapse state.
	while not decisions.is_empty():
		var decision: Dictionary = decisions.pop_back()
		var cell_index: int = decision["cell"]
		var tried: Array = decision["tried"]
		var snapshot: Array = decision["snapshot"]
		_restore_cells(snapshot)
		var remaining: Array = []
		for tile in _options_of(cell_index):
			if not tried.has(tile):
				remaining.append(tile)
		if remaining.is_empty():
			continue  # exhausted this cell; unwind further.
		# Deterministically take the FIRST remaining option (palette order) on a backtrack re-try.
		var next_tile := -1
		for tile in _palette:
			if remaining.has(tile):
				next_tile = int(tile)
				break
		tried.append(next_tile)
		_set_single(cell_index, next_tile)
		if _propagate(cell_index):
			decisions.append({"cell": cell_index, "tried": tried.duplicate(), "snapshot": snapshot})
			return true
		_restore_cells(snapshot)
		# Re-push so the next loop iteration considers the still-untried tiles of THIS cell.
		decisions.append({"cell": cell_index, "tried": tried.duplicate(), "snapshot": snapshot})
	return false


# --- cell state helpers ----------------------------------------------------------------------- #


func _init_cells() -> void:
	_cells = []
	_cells.resize(_width * _height)
	for i in _cells.size():
		var opts: Dictionary = {}
		for tile in _palette:
			opts[int(tile)] = true
		_cells[i] = opts


func _options_of(index: int) -> Array:
	return (_cells[index] as Dictionary).keys()


func _set_single(index: int, tile: int) -> void:
	_cells[index] = {tile: true}


func _snapshot_cells() -> Array:
	var snap: Array = []
	snap.resize(_cells.size())
	for i in _cells.size():
		snap[i] = (_cells[i] as Dictionary).duplicate()
	return snap


func _restore_cells(snapshot: Array) -> void:
	for i in snapshot.size():
		_cells[i] = (snapshot[i] as Dictionary).duplicate()


func _collapse_to_grid() -> PackedInt32Array:
	var grid := PackedInt32Array()
	grid.resize(_cells.size())
	for i in _cells.size():
		var opts: Dictionary = _cells[i]
		grid[i] = int(opts.keys()[0]) if opts.size() == 1 else Layout.EMPTY
	return grid
