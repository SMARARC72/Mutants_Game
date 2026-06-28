extends GdUnitTestSuite
## ParityProbe (D6) — the LimboConsole `parity_battle` probe runs the GDScript BattleEngine on a
## golden seed and reports MATCH against the committed Python golden vector (TDD §11.2).
##
## This is the automated guard for the dev-console probe: it exercises the SAME code path the console
## command calls (ParityProbe.battle), so a parity drift would fail CI here and surface live in the
## console identically.

const ParityProbeScript := preload("res://presentation/devtools/parity_probe.gd")


func test_probe_reports_match_for_golden_seed_0() -> void:
	var report := ParityProbeScript.battle(0)
	assert_int(report.size()).is_greater(0)
	var joined := "\n".join(PackedStringArray(report))
	# A green probe says MATCH and never MISMATCH.
	assert_bool(joined.contains("MATCH")).is_true()
	assert_bool(joined.contains("MISMATCH")).is_false()


func test_probe_matches_across_several_golden_seeds() -> void:
	for seed in [0, 1, 2, 3]:
		var report := ParityProbeScript.battle(seed)
		var joined := "\n".join(PackedStringArray(report))
		assert_bool(joined.contains("MATCH")).is_true()
		assert_bool(joined.contains("MISMATCH")).is_false()


func test_probe_handles_unknown_seed_cleanly() -> void:
	# A seed with no golden vector reports a clear message — never crashes, never false-MATCHes.
	var report := ParityProbeScript.battle(999999)
	var joined := "\n".join(PackedStringArray(report))
	assert_bool(joined.contains("no golden")).is_true()
	assert_bool(joined.contains("MATCH")).is_false()


func test_transcript_hash_is_stable_and_sensitive() -> void:
	var a := ParityProbeScript.transcript_hash(["line one", "line two"])
	var b := ParityProbeScript.transcript_hash(["line one", "line two"])
	var c := ParityProbeScript.transcript_hash(["line one", "line TWO"])
	assert_int(a).is_equal(b)  # stable
	assert_bool(a == c).is_false()  # sensitive to any change
