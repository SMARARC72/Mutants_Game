extends Node2D
## TEMP world-travel critic driver (delete after the capture run). Walks to the waygate, opens
## the Threshold overlay, unlocks via the REAL gate flag (region_layouts.json: registered_aspirant
## gates both mournmarch + forgefell), travels to each, caps terrain/cast/structures, and triggers
## one wild battle per region through the real EncounterDirector roll. Run WINDOWED.

const OUT := (
	"C:/Users/arahi/AppData/Local/Temp/claude"
	+ "/c--Users-arahi-Documents-Claude-Projects-Mutants-Game"
	+ "/25f1769e-3108-40a6-aa8b-e78af8055c80/scratchpad/final_caps/travel"
)
const RUN_SEED := 771177

const OwTiles := preload("res://presentation/overworld/overworld_tileset.gd")
const OwScreenScript := preload("res://presentation/overworld/overworld_screen.gd")
const OVERWORLD_SCENE := "res://presentation/overworld/overworld_screen.tscn"
const BATTLE_SCENE := "res://presentation/battle/battle_screen.tscn"

var _log_lines: PackedStringArray = []
var _game: Node = null
var _screen: Node = null


func _ready() -> void:
	await _run()
	_flush()
	get_tree().quit()


func _run() -> void:
	# Let the tree finish setting up before any root add_child (add_child during the main
	# scene's _ready is refused with "parent busy setting up children").
	await get_tree().process_frame
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(OUT)
	_game = get_node_or_null("/root/GameController")
	if _game == null:
		_log("FATAL: no GameController autoload")
		return
	_game.call("new_run", RUN_SEED)
	var run: RunContext = _game.call("run")
	run.flags["intro_played"] = true  # skip the cold-open scene: clean captures
	# No-op the peculiar seam so a peculiar roll never opens a modal Dialogic beat mid-hunt.
	OwScreenScript.peculiar_hook = func(_s: Node, _r: Dictionary) -> void: pass

	_screen = await _fresh_overworld()
	_log("start region=%s player=%s" % [str(_game.call("active_region")), str(_screen.call("player_cell"))])
	await _cap("01_verdant_spawn")

	# --- walk to the waygate (real grid steps, no rolls) ---
	var reached := await _walk_to_waygate()
	_log("waygate reached=%s player=%s" % [reached, str(_screen.call("player_cell"))])
	await _cap("02_waygate_approach")

	# --- open the Threshold overlay through the real interact path ---
	var threshold: Node = null
	if reached and not _npc_adjacent():
		var token: String = _screen.call("try_interact")
		_log("try_interact -> " + token)
	threshold = _screen.call("open_threshold")  # idempotent: returns the live overlay
	await _frames(25)
	_log_threshold(threshold, "LOCKED")
	await _cap("03_threshold_locked")

	# --- force-unlock via the REAL gate flag, reopen, cap, travel ---
	run.flags["registered_aspirant"] = true
	threshold.call("close")
	await _frames(10)
	threshold = _screen.call("open_threshold")
	await _frames(25)
	_log_threshold(threshold, "UNLOCKED")
	await _cap("04_threshold_unlocked")
	var ok: bool = threshold.call("travel", "mournmarch")
	_log("travel mournmarch accepted=%s active=%s" % [ok, str(_game.call("active_region"))])
	await _frames(50)
	await _cap("05_mournmarch_arrival")
	await _wander(12)
	await _cap("06_mournmarch_walk")
	var party: Array = await _hunt_encounter(240)
	if party.is_empty():
		party = _force_stash("mournmarch")
	await _battle_caps("07_mournmarch_battle", party)

	# --- fresh overworld (still mournmarch), then the forgefell hop ---
	_screen = await _fresh_overworld()
	threshold = _screen.call("open_threshold")
	await _frames(25)
	_log_threshold(threshold, "FROM_MOURNMARCH")
	await _cap("08_threshold_from_mournmarch")
	ok = threshold.call("travel", "forgefell")
	_log("travel forgefell accepted=%s active=%s" % [ok, str(_game.call("active_region"))])
	await _frames(50)
	await _cap("09_forgefell_arrival")
	await _wander(12)
	await _cap("10_forgefell_walk")
	party = await _hunt_encounter(240)
	if party.is_empty():
		party = _force_stash("forgefell")
	await _battle_caps("11_forgefell_battle", party)
	_cleanup_save()


# === overworld lifecycle ======================================================================= #


func _fresh_overworld() -> Node:
	if _screen != null and is_instance_valid(_screen):
		_screen.queue_free()
		await _frames(6)
	var packed: PackedScene = load(OVERWORLD_SCENE)
	var node := packed.instantiate()
	node.call("set_auto_hand_off", false)
	node.call("set_instant_moves", true)
	node.call("set_camp_enabled", false)
	get_tree().root.add_child(node)
	await _frames(45)
	var layout: Variant = node.call("layout")
	_log(
		"overworld fresh: in_tree=%s layout=%s region=%s"
		% [node.is_inside_tree(), layout != null, str(_game.call("active_region"))]
	)
	return node


# === waygate walk ============================================================================== #


func _walk_to_waygate() -> bool:
	var layout: Layout = _screen.call("layout")
	var structures: Object = _screen.call("structures")
	var gate: Dictionary = structures.call("waygate")
	if gate.is_empty():
		_log("NO WAYGATE in the region plan (region=%s)" % str(_game.call("active_region")))
		return false
	_log("waygate id=%s cell=%s" % [str(gate.get("id", "")), str(gate.get("cell", ""))])
	var goals := {}
	for gc_v in gate.get("cells", []) as Array:
		var gc: Vector2i = gc_v
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var c := gc + Vector2i(dx, dy)
				if not layout.in_bounds(c.x, c.y):
					continue
				if not OwTiles.is_walkable(layout.get_cell(c.x, c.y)):
					continue
				if bool(structures.call("blocks", c)):
					continue
				goals[c] = true
	var start: Vector2i = _screen.call("player_cell")
	if goals.has(start):
		return true
	var path := _bfs_path(layout, structures, start, goals)
	if path.is_empty():
		_log("BFS found no path to the waygate")
		return false
	for cell_v in path:
		var cell: Vector2i = cell_v
		var dir: Vector2i = cell - Vector2i(_screen.call("player_cell"))
		var res: Dictionary = _screen.call("try_move", dir, false)
		if not bool(res.get("moved", false)):
			_log("walk blocked stepping to %s" % str(cell))
			break
		await _frames(2)
	return bool(structures.call("waygate_adjacent", _screen.call("player_cell")))


func _bfs_path(layout: Layout, structures: Object, start: Vector2i, goals: Dictionary) -> Array:
	var prev := {start: start}
	var queue: Array = [start]
	var found := Vector2i(-9999, -9999)
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		if goals.has(cell):
			found = cell
			break
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := cell + d
			if prev.has(n) or not layout.in_bounds(n.x, n.y):
				continue
			if not OwTiles.is_walkable(layout.get_cell(n.x, n.y)):
				continue
			if bool(structures.call("blocks", n)):
				continue
			prev[n] = cell
			queue.append(n)
	if found.x == -9999:
		return []
	var path: Array = []
	var cur := found
	while cur != start:
		path.push_front(cur)
		cur = prev[cur]
	return path


func _npc_adjacent() -> bool:
	var cell: Vector2i = _screen.call("player_cell")
	for npc_v in _screen.get("_npcs") as Array:
		var npc: Dictionary = npc_v
		if (Vector2(npc["cell"] - cell)).length() <= 1.5:
			return true
	return false


# === wandering + encounter hunt ================================================================ #


func _wander(steps: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var dirs := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
	var last: Vector2i = Vector2i.RIGHT
	var done := 0
	var guard := 0
	while done < steps and guard < steps * 8:
		guard += 1
		var dir: Vector2i = last if rng.randf() < 0.6 else dirs[rng.randi_range(0, 3)]
		var res: Dictionary = _screen.call("try_move", dir, false)
		if bool(res.get("moved", false)):
			done += 1
			last = dir
			await _frames(1)
		else:
			last = dirs[rng.randi_range(0, 3)]


## Walk WITH encounter rolls until a wild battle fires. Ignores the boss climax (logged; the
## one-shot lair flag lets later steps roll wild again). Returns the fired enemy_party or [].
func _hunt_encounter(max_steps: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9090
	var dirs := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
	var last: Vector2i = Vector2i.DOWN
	for i in max_steps:
		var dir: Vector2i = last if rng.randf() < 0.6 else dirs[rng.randi_range(0, 3)]
		var res: Dictionary = _screen.call("try_move", dir, true)
		if not bool(res.get("moved", false)):
			last = dirs[rng.randi_range(0, 3)]
			continue
		last = dir
		await _frames(1)
		if bool(res.get("boss", false)):
			_log("boss climax fired at hunt step %d (ignored; hunting wild)" % i)
			continue
		if bool(res.get("encounter", false)) and str(res.get("kind", "")) != "peculiar":
			_log(
				"wild encounter at hunt step %d region=%s party=%s"
				% [i, str(_game.call("active_region")), JSON.stringify(res.get("enemy_party", []))]
			)
			return res.get("enemy_party", [])
		if bool(res.get("encounter", false)):
			_log("peculiar rolled at hunt step %d (no-op hook)" % i)
	_log("NO wild encounter in %d rolled steps" % max_steps)
	return []


## Fallback: stash a pending battle straight from the region's wild pool (top two entries).
func _force_stash(region: String) -> Array:
	var text := FileAccess.get_file_as_string("res://catalog/region_pools.json")
	var parsed: Variant = JSON.parse_string(text)
	var pool: Array = (((parsed as Dictionary).get("regions", {}) as Dictionary).get(region, {}) as Dictionary).get(
		"wild_pool", []
	)
	var party: Array = []
	for i in mini(2, pool.size()):
		party.append({"species_id": str((pool[i] as Dictionary).get("species_id", ""))})
	var run: RunContext = _game.call("run")
	run.flags["pending_battle"] = {
		"enemy_party": party,
		"battle_seed": 5150,
		"is_wild": true,
		"region": region,
		"force": OwTiles.force_for_region(region),
	}
	_log("FORCED pending_battle stash for %s: %s" % [region, JSON.stringify(party)])
	return party


# === battle capture ============================================================================ #


func _battle_caps(prefix: String, party: Array) -> void:
	for e_v in party:
		var sid := str((e_v as Dictionary).get("species_id", ""))
		_log(
			"art check %s has_art=%s plate=%s"
			% [sid, SpeciesArt.has_art(sid), SpeciesArt.plate_path(sid)]
		)
	if _screen != null and is_instance_valid(_screen):
		_screen.queue_free()
		_screen = null
		await _frames(6)
	var packed: PackedScene = load(BATTLE_SCENE)
	var battle := packed.instantiate()
	get_tree().root.add_child(battle)
	await _frames(35)
	await _cap(prefix + "_open")
	var menu := battle.find_child("ActionMenu", true, false)
	if menu != null:
		for child in menu.get_children():
			if child is Button:
				(child as Button).pressed.emit()
				break
	await _frames(55)
	await _cap(prefix + "_beat")
	battle.queue_free()
	await _frames(8)


# === plumbing ================================================================================== #


func _log_threshold(threshold: Node, tag: String) -> void:
	if threshold == null:
		_log("threshold overlay NULL (%s)" % tag)
		return
	for row_v in threshold.call("regions") as Array:
		var row: Dictionary = row_v
		var btn: Button = threshold.call("row_for", str(row["id"]))
		var text := btn.text if btn != null else "<no row>"
		var tip := btn.tooltip_text if btn != null else ""
		_log(
			"%s row %s here=%s unlocked=%s text=%s tooltip=%s"
			% [tag, row["id"], row["here"], row["unlocked"], text, tip]
		)


func _cap(name: String) -> void:
	await _frames(2)
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT + "/" + name + ".png")
	_log("cap " + name)


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _cleanup_save() -> void:
	var dir := DirAccess.open("user://saves")
	var fname := "run-%d.json" % RUN_SEED
	if dir != null and dir.file_exists(fname):
		dir.remove(fname)
		_log("removed user://saves/" + fname)


func _log(line: String) -> void:
	_log_lines.append(line)
	print("[travel_cap] " + line)


func _flush() -> void:
	var f := FileAccess.open(OUT + "/travel_log.txt", FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_log_lines))
		f.close()
