extends GdUnitTestSuite
## Wave 9 — LivingPlate: the ONE living creature stamp. Headless truths:
##   * headless => fully static: no per-frame processing, sway amplitude zeroed (the suite never
##     pays for breath/sway);
##   * the API (set_texture / set_identity / set_tint / material hooks) is safe without a display;
##   * the identity phase is a deterministic LOCAL hash — same identity, same phase, everywhere;
##   * the battle card kit swapped its static 88px portrait for a LivingPlate WITHOUT breaking
##     the card contract (refs dict, sigil stamp, portrait-flash hook battle_beats drives).

const GameControllerScript := preload("res://application/game/game_controller.gd")
const FakeDalScript := preload("res://infrastructure/dal/fake_dal.gd")
const BattleScreenScript := preload("res://presentation/battle/battle_screen.gd")
const BattleCardKitScript := preload("res://presentation/battle/battle_card_kit.gd")
const LivingPlateScene := preload("res://presentation/creature/living_plate.tscn")

const TEST_SEED := 0x11F3A7
const BATTLE_SEED := 0x5117E1
const ENEMY_PARTY := [{"species_id": "SB33"}, {"species_id": "SB14"}]


func test_headless_plate_does_no_per_frame_work() -> void:
	var plate := LivingPlate.new()
	add_child(plate)
	assert_bool(plate.is_animated()).is_false()
	assert_bool(plate.is_processing()).is_false()
	# Sway is zeroed at the material so even the GPU path is still (C6-adjacent honesty).
	var amp := float(plate.plate_material().get_shader_parameter("sway_amplitude"))
	assert_float(amp).is_equal_approx(0.0, 0.001)
	plate.queue_free()


func test_scene_api_is_safe_headless() -> void:
	var plate: Control = LivingPlateScene.instantiate()
	add_child(plate)
	plate.call("set_plate_size", Vector2(88, 88))
	plate.call("set_texture", SpeciesArt.plate("SB07"))
	plate.call("set_identity", "SB07", "wisp-1")
	plate.call("set_tint", Color(1.0, 0.9, 0.9))
	plate.call("set_hit_flash", 0.5)
	plate.call("set_dissolve", 0.25)
	plate.call("set_outline", 2.0)
	assert_object(plate.call("texture")).is_not_null()
	var mat: ShaderMaterial = plate.call("plate_material")
	assert_object(mat).is_not_null()
	assert_object(mat.shader).is_not_null()
	# The Wave 10 hooks landed on the material (hit_flash / dissolve / outline params).
	assert_float(float(mat.get_shader_parameter("flash_amount"))).is_equal_approx(0.5, 0.001)
	assert_float(float(mat.get_shader_parameter("dissolve"))).is_equal_approx(0.25, 0.001)
	assert_float(float(mat.get_shader_parameter("outline_width"))).is_equal_approx(2.0, 0.001)
	plate.queue_free()


func test_identity_phase_is_deterministic_and_instance_distinct() -> void:
	var a := LivingPlate.new()
	var b := LivingPlate.new()
	var c := LivingPlate.new()
	add_child(a)
	add_child(b)
	add_child(c)
	a.set_identity("SB07", "one")
	b.set_identity("SB07", "one")
	c.set_identity("SB07", "two")
	# Same creature => the same phase on every screen; a different instance drifts out of step.
	assert_float(a.phase()).is_equal(b.phase())
	assert_bool(is_equal_approx(a.phase(), c.phase())).is_false()
	a.queue_free()
	b.queue_free()
	c.queue_free()


func test_battle_cards_swap_in_living_plates_with_sigils() -> void:
	var gc: Node = GameControllerScript.new()
	add_child(gc)
	gc.call("configure", FakeDalScript.make())
	var run: RunContext = gc.call("new_run", TEST_SEED)
	run.flags["pending_battle"] = {
		"enemy_party": ENEMY_PARTY.duplicate(true),
		"battle_seed": BATTLE_SEED,
		"is_wild": true,
	}
	var screen: Control = BattleScreenScript.new()
	screen.call("set_game", gc)
	screen.call("set_auto_run", false)
	add_child(screen)
	var step: Dictionary = screen.call("run_pending_battle")
	assert_str(str(step.get("kind", ""))).is_equal("await_player")
	for is_enemy in [false, true]:
		var cards: Array = screen.call("side_cards", is_enemy)
		assert_int(cards.size()).is_greater(0)
		for c_v in cards:
			var card: Dictionary = c_v
			var portrait := card["portrait"] as Control
			assert_object(portrait).is_not_null()
			assert_bool(portrait is LivingPlate).is_true()
			assert_object((portrait as LivingPlate).texture()).is_not_null()
			assert_bool(portrait.is_processing()).is_false()
			# The one-of-one mark rides the portrait corner (Wave 9 sigils, cross-screen).
			assert_object(portrait.get_node_or_null("SigilStamp")).is_not_null()
	# The portrait-flash hook battle_beats drives still lands on the plate root's modulate
	# (composing with the tint on the sprite's self_modulate — the old TextureRect contract).
	var first: Dictionary = (screen.call("side_cards", true) as Array)[0]
	BattleCardKitScript.flash_portrait(first["portrait"] as CanvasItem)
	assert_bool((first["portrait"] as Control).modulate == Color(1, 1, 1, 1)).is_false()
	screen.queue_free()
	gc.queue_free()
