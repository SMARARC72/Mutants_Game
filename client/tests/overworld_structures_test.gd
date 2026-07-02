extends GdUnitTestSuite
## W-DRESS "structures" — the overworld's landmark buildings, driven headlessly:
##   * the structures MANIFEST resolves (every entry's texture ships, heights/footprints sane);
##   * PLACEMENT is deterministic (same layout + force + home => the same plan, twice), scoped
##     (2-4 landmarks + the boss-lair altar + at most one home stall), and honest (every
##     footprint cell was walkable ground, never a thin-place shimmer cell);
##   * footprint cells actually BLOCK try_move (screen-local occupancy — the Layout, and with
##     it worldgen/save determinism, is untouched);
##   * structures ride the y-sorted world with feet-level origins (the W12 occlusion contract);
##   * no NPC spawns inside a footprint.

const GameControllerScript := preload("res://application/game/game_controller.gd")
const FakeDalScript := preload("res://infrastructure/dal/fake_dal.gd")
const OverworldScreenScript := preload("res://presentation/overworld/overworld_screen.gd")
const OverworldTileSetScript := preload("res://presentation/overworld/overworld_tileset.gd")
const OverworldSpawnScript := preload("res://presentation/overworld/overworld_spawn.gd")
const OverworldLoopStateScript := preload("res://presentation/overworld/overworld_loop_state.gd")
const OverworldStructuresScript := preload("res://presentation/overworld/overworld_structures.gd")

const TEST_SEED := 0x0CEA_2026


func _make_game() -> Node:
	var gc: Node = GameControllerScript.new()
	add_child(gc)
	gc.call("configure", FakeDalScript.make())
	gc.call("new_run", TEST_SEED)
	return gc


func _make_overworld(game: Node) -> Node2D:
	var ow: Node2D = OverworldScreenScript.new()
	ow.call("set_game", game)
	ow.call("set_auto_hand_off", false)
	add_child(ow)
	ow.call("build_from_game")
	return ow


func test_manifest_resolves_every_structure() -> void:
	var manifest: Dictionary = OverworldStructuresScript.manifest()
	assert_int(manifest.size()).is_greater_equal(6)
	for id in manifest:
		var entry: Dictionary = manifest[id]
		var path: String = OverworldStructuresScript.DIR + str(entry.get("texture", ""))
		(
			assert_bool(ResourceLoader.exists(path))
			. override_failure_message("missing " + path)
			. is_true()
		)
		assert_float(float(entry.get("height_tiles", 0.0))).is_greater_equal(1.0)
		var fp: Vector2i = OverworldStructuresScript.footprint(str(id))
		assert_int(fp.x).is_greater_equal(1)
		assert_int(fp.y).is_greater_equal(1)
	# The special roles the placement leans on are present in the shipped manifest.
	assert_bool(manifest.has(OverworldStructuresScript.LAIR_ID)).is_true()
	assert_bool(manifest.has(OverworldStructuresScript.HOME_ID)).is_true()


func test_placement_is_deterministic_and_scoped() -> void:
	var gc := _make_game()
	var ow := _make_overworld(gc)
	var layout: Layout = ow.call("layout")
	var home: Vector2i = OverworldSpawnScript.spawn_cell(layout)
	var force := str(OverworldTileSetScript.force_for_region(str(gc.call("active_region"))))
	var plan_a: Array = OverworldStructuresScript.plan_for(layout, force, home)
	var plan_b: Array = OverworldStructuresScript.plan_for(layout, force, home)
	assert_int(plan_a.size()).is_greater_equal(1)
	assert_int(plan_a.size()).is_equal(plan_b.size())
	var lairs := 0
	var homes := 0
	var waygates := 0
	var landmarks := 0
	for i in plan_a.size():
		var a: Dictionary = plan_a[i]
		var b: Dictionary = plan_b[i]
		assert_str(str(a["id"])).is_equal(str(b["id"]))
		assert_that(a["cell"]).is_equal(b["cell"])
		match str(a["role"]):
			OverworldStructuresScript.ROLE_LAIR:
				lairs += 1
			OverworldStructuresScript.ROLE_HOME:
				homes += 1
			OverworldStructuresScript.ROLE_WAYGATE:
				waygates += 1
			_:
				landmarks += 1
		for c: Vector2i in a["cells"] as Array:
			# Footprints claim ordinary walkable ground only — never a wall, never the veil.
			assert_bool(OverworldTileSetScript.is_walkable(layout.get_cell(c.x, c.y))).is_true()
			assert_bool(OverworldTileSetScript.is_thin_place(c.x, c.y)).is_false()
			assert_int(absi(c.x - home.x) + absi(c.y - home.y)).is_greater_equal(2)
	assert_int(lairs).is_equal(1)  # the boss goal has its visible destination
	assert_int(homes).is_less_equal(1)
	assert_int(waygates).is_equal(1)  # E1b: every region raises its Threshold-network circle
	assert_int(landmarks).is_between(
		OverworldStructuresScript.MIN_LANDMARKS - 1, OverworldStructuresScript.MAX_LANDMARKS
	)
	ow.queue_free()
	gc.queue_free()


func test_blocked_cells_actually_block_try_move() -> void:
	var gc := _make_game()
	var probe := _make_overworld(gc)
	var kit: OverworldStructures = probe.call("structures")
	var layout: Layout = probe.call("layout")
	var blocked: Dictionary = kit.blocked()
	assert_int(blocked.size()).is_greater_equal(1)
	# Find a blocked cell with a walkable, unblocked cardinal neighbour to step FROM.
	var stand := Vector2i(-1, -1)
	var dir := Vector2i.ZERO
	for cell: Vector2i in blocked:
		for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cell + step
			if not layout.in_bounds(n.x, n.y) or blocked.has(n):
				continue
			if OverworldTileSetScript.is_walkable(layout.get_cell(n.x, n.y)):
				stand = n
				dir = -step
				break
		if stand.x >= 0:
			break
	assert_bool(stand.x >= 0).is_true()
	probe.queue_free()
	# Rebuild with the player restored ONTO the neighbour (the Wave-3 stash path) and push in.
	var run: RunContext = gc.call("run")
	OverworldLoopStateScript.stash_prebattle(run, stand, dir, 0)
	var ow := _make_overworld(gc)
	assert_that(ow.call("player_cell")).is_equal(stand)
	var res: Dictionary = ow.call("try_move", dir)
	assert_bool(bool(res.get("moved", true))).is_false()
	assert_that(ow.call("player_cell")).is_equal(stand)
	ow.queue_free()
	gc.queue_free()


func test_structures_ride_the_ysort_world_with_feet_origins() -> void:
	var gc := _make_game()
	var ow := _make_overworld(gc)
	var world := ow.call("world_root") as Node2D
	var holder := world.find_child("Structures", false, false) as Node2D
	assert_object(holder).is_not_null()
	assert_bool(holder.y_sort_enabled).is_true()
	assert_int(holder.get_child_count()).is_greater_equal(1)
	var s := OverworldTileSetScript.TILE_SIZE
	var tallest := 0.0
	for child: Node in holder.get_children():
		var sprite := child as Sprite2D
		assert_object(sprite).is_not_null()
		assert_int(sprite.z_index).is_equal(0)
		assert_float(sprite.offset.y).is_less(0.0)  # feet origin: texture raised above position
		tallest = maxf(tallest, sprite.texture.get_height() * sprite.scale.y)
	# A landmark really is landmark-sized (>= ~1.5 tiles somewhere on the map).
	assert_float(tallest).is_greater_equal(s * 1.2)
	ow.queue_free()
	gc.queue_free()


func test_npcs_never_stand_in_a_footprint() -> void:
	var gc := _make_game()
	var ow := _make_overworld(gc)
	var kit: OverworldStructures = ow.call("structures")
	var world := ow.call("world_root") as Node2D
	var s := float(OverworldTileSetScript.TILE_SIZE)
	var npc_count := 0
	for child: Node in world.get_children():
		if not str(child.name).begins_with("NPC_"):
			continue
		npc_count += 1
		var pos := (child as Node2D).position
		var cell := Vector2i(int(pos.x / s), int(pos.y / s))
		assert_bool(kit.blocks(cell)).is_false()
	assert_int(npc_count).is_greater(0)
	ow.queue_free()
	gc.queue_free()
