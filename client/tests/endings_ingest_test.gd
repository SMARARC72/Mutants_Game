extends GdUnitTestSuite
## Batch E2b — endings ingest PARITY suite. The authored doc is the source
## (endgame_succession.md PART ONE, eleven endings); tools/ingest_endings.py is
## the deterministic transform. This suite proves the generated catalog holds
## its contract:
##   * 11 authored endings + exactly ONE always-true fallback, ids unique,
##     every entry carries a non-empty name + VERBATIM epigraph;
##   * the nine grid ascensions PARTITION the 3x3 morality grid (every
##     god_alignment x corruption band cell exactly once, band3 bounds ±34);
##   * the two refusal doors are flag-gated (`unmaking` / `god_maker`) and
##     outrank the grid; the fallback has empty conditions at priority 0;
##   * conditions are well-formed (only known clause keys, sane shapes).

const EXPECTED_ENDINGS := 11
const EXPECTED_GRID := 9
const OC_LABELS := ["Order", "Balanced", "Chaos"]
const KNOWN_CONDITION_KEYS := [
	"god_alignment", "corruption_min", "corruption_max", "flags_all", "flags_any", "standing_min"
]


func test_counts_match_the_authored_doc() -> void:
	var all: Array = EndingsService.endings()
	assert_int(all.size()).is_equal(EXPECTED_ENDINGS + 1)
	var fallbacks := 0
	var grid := 0
	for e: Dictionary in all:
		if bool(e.get("fallback", false)):
			fallbacks += 1
		if str(e.get("grid", "")) != "":
			grid += 1
	assert_int(fallbacks).is_equal(1)
	assert_int(grid).is_equal(EXPECTED_GRID)


func test_every_entry_is_structurally_sound() -> void:
	var ids: Dictionary = {}
	for e: Dictionary in EndingsService.endings():
		var ending_id := str(e.get("id", ""))
		assert_str(ending_id).is_not_empty()
		(
			assert_bool(ids.has(ending_id))
			. override_failure_message("duplicate ending id: " + ending_id)
			. is_false()
		)
		ids[ending_id] = true
		assert_str(str(e.get("name", ""))).is_not_empty()
		(
			assert_str(str(e.get("epigraph", "")))
			. override_failure_message(ending_id + ": empty epigraph")
			. is_not_empty()
		)
		var conditions: Dictionary = e.get("conditions", {}) as Dictionary
		for key: Variant in conditions:
			(
				assert_bool(KNOWN_CONDITION_KEYS.has(str(key)))
				. override_failure_message("%s: unknown condition key '%s'" % [ending_id, key])
				. is_true()
			)
		if conditions.has("god_alignment"):
			assert_bool(OC_LABELS.has(str(conditions.god_alignment))).is_true()
		if conditions.has("flags_all"):
			assert_bool((conditions.flags_all as Array).is_empty()).is_false()


func test_the_nine_grid_endings_partition_the_grid() -> void:
	# Every (Order⇄Chaos band, Purity⇄Corrupt band) cell must resolve to EXACTLY one grid
	# ending — probe a representative axis value per band3 cell through conditions_met.
	var probes := {"Order": -80, "Balanced": 0, "Chaos": 80}
	var pc_probes := {"Pure": -80, "Tainted": 0, "Corrupt": 80}
	for oc_label: String in probes:
		for pc_label: String in pc_probes:
			var run := RunContext.new()
			run.order_chaos = int(probes[oc_label])
			run.purity_corrupt = int(pc_probes[pc_label])
			var matches: Array = []
			for e: Dictionary in EndingsService.endings():
				if str(e.get("grid", "")) == "":
					continue
				if EndingsService.conditions_met(e.get("conditions", {}) as Dictionary, run):
					matches.append(str(e.get("id", "")))
			(
				assert_int(matches.size())
				. override_failure_message("%s|%s matched %s" % [oc_label, pc_label, str(matches)])
				. is_equal(1)
			)
			# The grid key on the matched entry names the same cell.
			var matched: Dictionary = EndingsService.ending(str(matches[0]))
			assert_str(str(matched.get("grid", ""))).is_equal("%s|%s" % [oc_label, pc_label])


func test_refusal_doors_and_priorities() -> void:
	var unmaking := EndingsService.ending("the_unmaking")
	var god_maker := EndingsService.ending("the_god_maker")
	assert_bool(unmaking.is_empty()).is_false()
	assert_bool(god_maker.is_empty()).is_false()
	assert_array((unmaking.get("conditions", {}) as Dictionary).get("flags_all", [])).contains(
		["unmaking"]
	)
	assert_array((god_maker.get("conditions", {}) as Dictionary).get("flags_all", [])).contains(
		["god_maker"]
	)
	# Resolve order: the true ending > the refusal-by-pride > every grid ascension > fallback.
	var grid_priority := int(EndingsService.ending("the_lawgiver").get("priority", -1))
	assert_bool(int(unmaking.get("priority", 0)) > int(god_maker.get("priority", 0))).is_true()
	assert_bool(int(god_maker.get("priority", 0)) > grid_priority).is_true()
	assert_bool(grid_priority > 0).is_true()


func test_the_fallback_is_always_satisfiable_at_priority_zero() -> void:
	var fallback := EndingsService.ending("a_graveyard_of_winners")
	assert_bool(fallback.is_empty()).is_false()
	assert_bool(bool(fallback.get("fallback", false))).is_true()
	assert_bool((fallback.get("conditions", {}) as Dictionary).is_empty()).is_true()
	assert_int(int(fallback.get("priority", -1))).is_equal(0)
	# Empty conditions satisfy ANY run — the never-null resolve() contract's floor.
	assert_bool(EndingsService.conditions_met({}, RunContext.new())).is_true()


func test_epigraphs_are_verbatim_doc_lines() -> void:
	# Spot-check the authored own-voice lines landed word-for-word (emphasis stripped).
	assert_str(str(EndingsService.ending("the_lawgiver").get("epigraph", ""))).contains(
		"I am the text. Sit down. You're out of order."
	)
	assert_str(str(EndingsService.ending("the_unmaking").get("epigraph", ""))).contains(
		"The silence is the answer."
	)
	assert_str(str(EndingsService.ending("the_god_maker").get("epigraph", ""))).contains(
		"I won by staying small."
	)
