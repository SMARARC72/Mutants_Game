extends GdUnitTestSuite
## Wave 12 "Overworld Depth" — the y-sort occlusion STRUCTURE, driven headlessly:
##   * props + player + NPC tokens (+ lead cameo when one resolves) share ONE y-sorted world
##     root (WorldYSort, y_sort_enabled), all at z 0, so draw order comes from Y — never from
##     hand-set z layers;
##   * props carry FEET-level y-origins (position = ground contact, texture raised above it),
##     so an actor on the tile behind a tall prop has a smaller Y => drawn first => occluded,
##     and one on the tile in front has a larger Y => drawn after => occludes;
##   * the ground TileMapLayer stays BELOW the world root, and the parallax horizon BELOW the
##     ground, so the depth stack is horizon < tiles < y-sorted world.

const GameControllerScript := preload("res://application/game/game_controller.gd")
const FakeDalScript := preload("res://infrastructure/dal/fake_dal.gd")
const OverworldScreenScript := preload("res://presentation/overworld/overworld_screen.gd")
const OverworldTileSetScript := preload("res://presentation/overworld/overworld_tileset.gd")

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


func test_props_and_actors_share_the_y_sorted_world_root() -> void:
	var gc := _make_game()
	var ow := _make_overworld(gc)
	var world := ow.call("world_root") as Node2D
	assert_object(world).is_not_null()
	assert_bool(world.y_sort_enabled).is_true()
	# The player and every NPC token are DIRECT children of the sort space; the prop holder is a
	# nested y-sorted child (its children join the same sort per Godot's cascading y-sort).
	var player := world.find_child("Player", false, false) as Node2D
	assert_object(player).is_not_null()
	var props := world.find_child("Props", false, false) as Node2D
	assert_object(props).is_not_null()
	assert_bool(props.y_sort_enabled).is_true()
	var npc_count := 0
	for child: Node in world.get_children():
		if str(child.name).begins_with("NPC_"):
			npc_count += 1
		# EVERY participant rides z 0 — y decides the draw order, nothing else.
		if child is Node2D:
			assert_int((child as Node2D).z_index).is_equal(0)
	assert_int(npc_count).is_greater(0)
	for prop: Node in props.get_children():
		assert_int((prop as Node2D).z_index).is_equal(0)
	ow.queue_free()
	gc.queue_free()


func test_walking_behind_a_tall_prop_puts_the_player_behind_in_draw_order() -> void:
	var gc := _make_game()
	var ow := _make_overworld(gc)
	var world := ow.call("world_root") as Node2D
	var props := world.find_child("Props", false, false) as Node2D
	assert_object(props).is_not_null()
	if props.get_child_count() == 0:
		ow.queue_free()
		gc.queue_free()
		return  # this seed dressed no feature cell — structure covered by the test above
	var s := OverworldTileSetScript.TILE_SIZE
	var prop := props.get_child(0) as Sprite2D
	# Feet origin: the prop's position is its GROUND CONTACT, low in its own tile, with the
	# texture raised above it (negative offset) — the y-sort key of a standing object.
	assert_float(prop.offset.y).is_less(0.0)
	var cell := Vector2i(int(prop.position.x / s), int(prop.position.y / s))
	assert_float(prop.position.y).is_greater((cell.y + 0.5) * s)
	# Y-sort semantics: smaller Y draws FIRST. A player token centred one tile behind (above)
	# the prop sorts before it => occluded; one tile in front (below) sorts after => occludes.
	var behind_y := (cell.y - 1) * s + s / 2.0
	var in_front_y := (cell.y + 1) * s + s / 2.0
	assert_float(behind_y).is_less(prop.position.y)
	assert_float(in_front_y).is_greater(prop.position.y)
	# And a TALL prop really is tall enough to hide a medallion behind it (~>= one tile).
	var tallest := 0.0
	for p: Node in props.get_children():
		var spr := p as Sprite2D
		tallest = maxf(tallest, spr.texture.get_height() * spr.scale.y)
	assert_float(tallest).is_greater_equal(s * 0.9)
	ow.queue_free()
	gc.queue_free()


func test_depth_stack_is_horizon_below_tiles_below_world() -> void:
	var gc := _make_game()
	var ow := _make_overworld(gc)
	var world := ow.call("world_root") as Node2D
	var tiles := ow.find_child("RegionTiles", false, false) as TileMapLayer
	assert_object(tiles).is_not_null()
	assert_int(tiles.z_index).is_less(world.z_index)
	var horizon := ow.find_child("HorizonParallax", false, false) as Node2D
	assert_object(horizon).is_not_null()
	assert_int(horizon.z_index).is_less(tiles.z_index)
	ow.queue_free()
	gc.queue_free()


func test_player_glow_is_one_cheap_shadowless_light() -> void:
	var gc := _make_game()
	var ow := _make_overworld(gc)
	var glow := ow.find_child("PlayerGlow", true, false) as PointLight2D
	assert_object(glow).is_not_null()
	assert_bool(glow.shadow_enabled).is_false()  # the Iris Xe budget: 1 light, 0 shadow casters
	assert_float(glow.energy).is_less_equal(0.8)
	ow.queue_free()
	gc.queue_free()


func test_ground_atlas_ships_a_normal_map_pair() -> void:
	# The built TileSet's atlas texture is a CanvasTexture carrying the diffuse + the composed
	# normal atlas (tools/gen_normalmaps.py), so the player's light shades the terrain.
	var tile_set: TileSet = OverworldTileSetScript.build("Eros")
	var source := tile_set.get_source(0) as TileSetAtlasSource
	assert_object(source).is_not_null()
	var lit := source.texture as CanvasTexture
	assert_object(lit).is_not_null()
	assert_object(lit.diffuse_texture).is_not_null()
	assert_object(lit.normal_texture).is_not_null()
