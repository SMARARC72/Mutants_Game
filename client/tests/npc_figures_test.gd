extends GdUnitTestSuite
## W-DRESS "characters, not circles" — the procedural NPC figure sprites, headless:
##   * the figure painter is DETERMINISTIC per name (same name + ring + size => identical
##     pixel bytes, cache cleared between draws) and DISTINCT across the cast (10 names =>
##     10 different textures — hood/pose/build/rune all hash from the name);
##   * pose variants actually spread across the cast (not one pose for everyone);
##   * creature-NPCs (species hint in OverworldContent.NPC_DEFS) walk as their ACTUAL
##     painterly cutout at NPC scale; the signpost stays a signpost; everyone else is a
##     hooded figure with a feet-level offset (the WorldYSort contract);
##   * the built overworld carries figure tokens, not wax seals, on its NPC nodes.

const GameControllerScript := preload("res://application/game/game_controller.gd")
const FakeDalScript := preload("res://infrastructure/dal/fake_dal.gd")
const OverworldScreenScript := preload("res://presentation/overworld/overworld_screen.gd")
const OverworldTileSetScript := preload("res://presentation/overworld/overworld_tileset.gd")
const NpcFiguresScript := preload("res://presentation/overworld/npc_figures.gd")

const TEST_SEED := 0x0CEA_2026
const FIG_PX := 90


func test_figure_is_deterministic_per_name() -> void:
	var ring := Color(0.667, 0.376, 0.69)
	var first: PackedByteArray = (
		NpcFiguresScript.figure("Old Marrow", ring, FIG_PX).get_image().get_data()
	)
	NpcFiguresScript._cache.clear()  # force a genuine re-draw, not a cache hit
	var second: PackedByteArray = (
		NpcFiguresScript.figure("Old Marrow", ring, FIG_PX).get_image().get_data()
	)
	assert_bool(first == second).is_true()
	assert_int(first.size()).is_greater(0)


func test_figures_distinct_across_ten_names() -> void:
	var seen := {}
	var names: Array = []
	for def: Dictionary in OverworldContent.NPC_DEFS:
		if names.size() < 10:
			names.append([str(def["name"]), def["ring"] as Color])
	assert_int(names.size()).is_equal(10)
	for pair: Array in names:
		var tex: ImageTexture = NpcFiguresScript.figure(str(pair[0]), pair[1] as Color, FIG_PX)
		seen[hash(tex.get_image().get_data())] = true
	assert_int(seen.size()).is_equal(10)


func test_pose_variants_spread_across_the_cast() -> void:
	var poses := {}
	for def: Dictionary in OverworldContent.NPC_DEFS:
		poses[NpcFiguresScript.pose_for(str(def["name"]))] = true
	assert_int(poses.size()).is_greater_equal(3)


func test_creature_npcs_use_their_actual_cutouts() -> void:
	var s := OverworldTileSetScript.TILE_SIZE
	var melon := _def_named("The Melon")
	assert_str(str(melon.get("species", ""))).is_equal("SB09")
	var sprite: Sprite2D = NpcFiguresScript.npc_sprite(melon, s)
	# The creature cameo is a square box at NPC scale (the cutout + baked ground shadow).
	assert_int(sprite.texture.get_width()).is_equal(int(s * 0.95))
	assert_int(sprite.texture.get_height()).is_equal(int(s * 0.95))
	assert_float(sprite.offset.y).is_less(0.0)
	# A plain soul gets the tall hooded figure instead.
	var marrow: Sprite2D = NpcFiguresScript.npc_sprite(_def_named("Old Marrow"), s)
	assert_int(marrow.texture.get_height()).is_equal(int(s * 1.0))
	assert_float(marrow.offset.y).is_less(0.0)
	# And the Weathered Signpost is a signpost, not a person (distinct from the figure).
	var sign_sprite: Sprite2D = NpcFiguresScript.npc_sprite(_def_named("Weathered Signpost"), s)
	var fig_bytes: PackedByteArray = marrow.texture.get_image().get_data()
	assert_bool(sign_sprite.texture.get_image().get_data() == fig_bytes).is_false()
	sprite.free()
	marrow.free()
	sign_sprite.free()


func test_overworld_npcs_wear_figures_with_feet_origins() -> void:
	var gc: Node = GameControllerScript.new()
	add_child(gc)
	gc.call("configure", FakeDalScript.make())
	gc.call("new_run", TEST_SEED)
	var ow: Node2D = OverworldScreenScript.new()
	ow.call("set_game", gc)
	ow.call("set_auto_hand_off", false)
	add_child(ow)
	ow.call("build_from_game")
	var world := ow.call("world_root") as Node2D
	var checked := 0
	for child: Node in world.get_children():
		if not str(child.name).begins_with("NPC_"):
			continue
		var token := (child as Node2D).get_child(0) as Sprite2D
		assert_object(token).is_not_null()
		assert_str(str(token.name)).is_equal("Token")
		# Feet-level origin: the texture rides above the ground-contact node position.
		assert_float(token.offset.y).is_less(0.0)
		# Taller than the old flat seal (s * 0.84) — these are standing characters.
		assert_int(token.texture.get_height()).is_greater(
			int(OverworldTileSetScript.TILE_SIZE * 0.9)
		)
		checked += 1
	assert_int(checked).is_greater(0)
	ow.queue_free()
	gc.queue_free()


func _def_named(wanted: String) -> Dictionary:
	for def: Dictionary in OverworldContent.NPC_DEFS:
		if str(def["name"]) == wanted:
			return def
	return {}
