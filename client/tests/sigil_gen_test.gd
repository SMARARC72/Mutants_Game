extends GdUnitTestSuite
## Wave 9 — one-of-one creature sigils, asserted on GEOMETRY (red-team correction C6): under the
## headless harness SubViewports render nothing, so pixel hashes are vacuously equal — determinism
## is proven on sigil_gen's seeded polar stroke arrays instead. Pixel comparisons are reserved for
## the non-headless devcap path.
##   * same (species_id, instance_tag) => byte-identical stroke arrays;
##   * 20 distinct identities => 20 distinct geometries;
##   * every sigil stays in the 8-16 element band and carries EXACTLY one force-accent stroke;
##   * the SigilMark _draw() Control re-aims safely headless; bake_texture never touches the
##     render loop headless (blank of the right size, no hang).


func test_same_identity_yields_identical_stroke_geometry() -> void:
	var a: Array = SigilGen.strokes_for("SB07", "wisp-1")
	var b: Array = SigilGen.strokes_for("SB07", "wisp-1")
	assert_str(JSON.stringify(a)).is_equal(JSON.stringify(b))


func test_species_and_tag_both_shift_the_geometry() -> void:
	var base := JSON.stringify(SigilGen.strokes_for("SB07", "wisp-1"))
	assert_str(JSON.stringify(SigilGen.strokes_for("SB08", "wisp-1"))).is_not_equal(base)
	assert_str(JSON.stringify(SigilGen.strokes_for("SB07", "wisp-2"))).is_not_equal(base)


func test_twenty_distinct_seeds_yield_twenty_distinct_sigils() -> void:
	var seen := {}
	for i in 20:
		seen[JSON.stringify(SigilGen.strokes_for("SB07", "capture-%d" % i))] = true
	assert_int(seen.size()).is_equal(20)


func test_element_band_and_exactly_one_accent() -> void:
	for i in 20:
		var strokes: Array = SigilGen.strokes_for("SB%02d" % i, "tag-%d" % i)
		assert_int(strokes.size()).is_between(SigilGen.STROKES_MIN, SigilGen.STROKES_MAX)
		var accents := 0
		for s_v in strokes:
			var s: Dictionary = s_v
			if str(s.get("ink", "")) == SigilGen.INK_ACCENT:
				accents += 1
		assert_int(accents).is_equal(1)
		# The accent is the LAST element (draw order: the force mark seals the sigil).
		assert_str(str((strokes.back() as Dictionary).get("ink", ""))).is_equal(SigilGen.INK_ACCENT)


func test_inks_resolve_through_the_palette() -> void:
	var brass := SigilGen.ink_color(SigilGen.INK_BRASS, Color.RED)
	assert_bool(brass == GrimoirePalette.BRASS).is_true()
	var bright := SigilGen.ink_color(SigilGen.INK_BRIGHT, Color.RED)
	assert_bool(bright == GrimoirePalette.BRASS_BRIGHT).is_true()
	# The accent ink is the caller's force colour (GrimoirePalette.force_color at the call site).
	var accent := SigilGen.ink_color(SigilGen.INK_ACCENT, GrimoirePalette.force_color("Eros"))
	assert_bool(accent == GrimoirePalette.EROS).is_true()


func test_mark_control_builds_and_reaims_headless() -> void:
	var mark := SigilGen.make_mark("SB07", "wisp-1", "Eros", 16)
	add_child(mark)
	assert_bool(mark.mouse_filter == Control.MOUSE_FILTER_IGNORE).is_true()
	var first := JSON.stringify(mark.call("strokes"))
	assert_bool(first != "[]").is_true()
	mark.call("set_identity", "SB07", "wisp-2", "Gaia")
	assert_str(JSON.stringify(mark.call("strokes"))).is_not_equal(first)
	mark.queue_free()


func test_bake_texture_headless_skips_the_render_loop() -> void:
	var tex: Texture2D = await SigilGen.bake_texture(self, "SB07", "wisp-1", "Eros", 32)
	assert_object(tex).is_not_null()
	assert_int(tex.get_width()).is_equal(32)
	assert_int(tex.get_height()).is_equal(32)
