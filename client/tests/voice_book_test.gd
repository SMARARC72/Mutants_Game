extends GdUnitTestSuite
## Wave 16a — VoiceBook ingest parity, headless.
##   * the committed client/catalog/voice.json parses and carries the full authored ingest
##     (767 verbatim lines — binding tension 11);
##   * every REQUIRED key (the rewired call sites + the battle keys reserved for the
##     battle-screen sibling in client/catalog/VOICE_KEYS.md) resolves to non-empty copy;
##   * pick() is deterministic per (key, salt) and varied across salts (LOCAL hash — never
##     the canonical PCG32 streams);
##   * every ingested variant is a non-empty string (no blank toasts, ever).

const VoiceBookScript := preload("res://presentation/narrative/voice_book.gd")

## The call-site contract: keys the shipped rewires + VOICE_KEYS.md consumers rely on.
const REQUIRED_KEYS := [
	"toast.caught",
	"toast.harvest",
	"toast.awakening",
	"toast.quest",
	"toast.rival",
	"toast.corruption",
	"capture.success",
	"capture.fail",
	"capture.befriend.success",
	"capture.befriend.fail",
	"capture.trap.success",
	"capture.trap.fail",
	"capture.refuses",
	"battle.start",
	"battle.victory",
	"battle.defeat",
	"battle.stalemate",
	"battle.downed",
	"battle.boss.prefight",
	"battle.boss.victory",
	"region.verdant_glut.enter",
	"region.verdant_glut.ambient",
	"bark.region.verdant_glut",
	"empty.party",
	"empty.quests",
	"empty.parts",
	"empty.inventory",
	"quest.refused_garran",
	"quest.accepted_garran",
]


func test_catalog_loads_with_full_line_count() -> void:
	# The ingest wrote its own audit into _meta; the book must carry the whole library.
	assert_int(VoiceBookScript.line_count()).is_equal(767)
	assert_int(VoiceBookScript.keys().size()).is_greater(300)


func test_required_keys_resolve_to_copy() -> void:
	for key: String in REQUIRED_KEYS:
		(
			assert_bool(VoiceBookScript.has_key(key))
			. override_failure_message("missing key: " + key)
			. is_true()
		)
		(
			assert_str(VoiceBookScript.pick(key))
			. override_failure_message("empty pick: " + key)
			. is_not_empty()
		)


func test_pick_is_deterministic_per_salt() -> void:
	for salt in 8:
		assert_str(VoiceBookScript.pick("toast.caught", salt)).is_equal(
			VoiceBookScript.pick("toast.caught", salt)
		)


func test_pick_varies_across_salts() -> void:
	# toast.caught carries 5 authored variants; ten salts must surface at least two of them.
	var seen := {}
	for salt in 10:
		seen[VoiceBookScript.pick("toast.caught", salt)] = true
	assert_int(seen.size()).is_greater(1)


func test_every_variant_is_a_non_empty_string() -> void:
	for key: String in VoiceBookScript.keys():
		var variants: Array = VoiceBookScript.lines(key)
		assert_int(variants.size()).override_failure_message("no variants: " + key).is_greater(0)
		for line: Variant in variants:
			(
				assert_bool(line is String and str(line) != "")
				. override_failure_message("blank/typed-wrong variant under " + key)
				. is_true()
			)


func test_stalemate_alias_carries_the_wave3_banner_line() -> void:
	# Wave 3 shipped this exact verbatim line; the W16 ingest must keep serving it so the
	# battle sibling's rewire is a pure key swap (no copy change).
	var wave3_line := "No battle today. It's tired, you're tired, the gods are dead — what's the point, really?"
	assert_array(VoiceBookScript.lines("battle.stalemate")).contains([wave3_line])


func test_missing_key_falls_back_empty() -> void:
	assert_bool(VoiceBookScript.has_key("no.such.key")).is_false()
	assert_str(VoiceBookScript.pick("no.such.key")).is_empty()
