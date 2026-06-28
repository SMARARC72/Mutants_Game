extends GdUnitTestSuite
## Phase 0.5 asset smoke: the CC0 starter shaders compile (load as Shader) and the curated
## force icons import (load as textures) in Godot 4.7.


func test_starter_shaders_compile() -> void:
	for s in ["hit_flash", "outline", "dissolve"]:
		var sh = load("res://presentation/shaders/%s.gdshader" % s)
		assert_object(sh).is_not_null()
		assert_bool(sh is Shader).is_true()


func test_force_icons_import() -> void:
	for f in ["gaia", "ouranos", "cosmos", "chaos", "eros", "thanatos"]:
		var tex = load("res://assets/icons/forces/%s.svg" % f)
		assert_object(tex).is_not_null()
		assert_bool(tex is Texture2D).is_true()
