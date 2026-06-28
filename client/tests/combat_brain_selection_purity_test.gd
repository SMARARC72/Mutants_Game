extends GdUnitTestSuite
## CombatBrain selection purity (ADR-016 — the non-negotiable RNG rule).
##
## Proves the AI path consumes ONLY the injected canonical RNG sub-stream and never global/addon RNG:
##   1. SOURCE GREP (committed assertion): every .gd under application/ai/ + application/battle/ is
##      free of randf()/randi()/randomize()/randf_range/randi_range and of Beehave/LimboAI RNG
##      helpers. This mirrors the CI grep gate so the rule is enforced in-repo too.
##   2. RUNTIME DETERMINISM: a brain decision sequence driven by a given CanonicalRNG seed is
##      byte-identical when replayed with a fresh RNG of the same seed (no hidden randomness leaks
##      in), and DIFFERS for a different seed (it really does draw from the injected stream).

const CombatBrainScript := preload("res://application/ai/combat_brain.gd")
const RngServiceScript := preload("res://application/ai/rng_service.gd")

const AI_DIRS := ["res://application/ai", "res://application/battle"]
# Forbidden in the AI selection path (ADR-016). \b-anchored where it matters; we match on substrings
# of the source line. LimboAI/Beehave RNG helpers would surface as those identifiers if ever used.
const FORBIDDEN := [
	"randf(",
	"randi(",
	"randf_range(",
	"randi_range(",
	"randomize(",
	"RandomNumberGenerator",
	".rand_range(",
	"randv(",
]


func _gd_files(dir_path: String, acc: Array) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		if name == "." or name == "..":
			name = d.get_next()
			continue
		var full := dir_path + "/" + name
		if d.current_is_dir():
			_gd_files(full, acc)
		elif name.ends_with(".gd"):
			acc.append(full)
		name = d.get_next()
	d.list_dir_end()


func test_ai_path_has_no_global_or_addon_rng() -> void:
	var files: Array = []
	for dir_path in AI_DIRS:
		_gd_files(dir_path, files)
	assert_int(files.size()).is_greater(0)  # the AI path must actually exist

	var violations: Array = []
	for path in files:
		var f := FileAccess.open(path, FileAccess.READ)
		assert_object(f).is_not_null()
		var text := f.get_as_text()
		f.close()
		# Strip nothing fancy: a forbidden token anywhere in source is a violation. (Our files mention
		# these tokens ONLY in this test, never in the AI path — which is exactly what we assert.)
		for token in FORBIDDEN:
			if text.contains(token):
				violations.append("%s contains forbidden RNG token: %s" % [path, token])

	assert_array(violations).is_empty()


func test_brain_choose_action_is_driven_only_by_injected_rng() -> void:
	# The REAL test of ADR-016 (not the RNG primitive): build a CombatBrain, assign an RNG-consuming
	# brain, and call choose_action(state, CanonicalRNG.new(seed)) over a FIXED turn script. The chosen
	# TARGET sequence must be:
	#   - identical for the same seed (no hidden/global randomness leaked in), AND
	#   - able to DIFFER for a different seed (the brain genuinely draws from the injected stream).
	# If the brain never touched ctx.rng, the "different seed" sequences could never differ.
	var seq_a1 := _boss_target_sequence(123)
	var seq_a2 := _boss_target_sequence(123)
	var seq_b := _boss_target_sequence(456)

	# A real sequence was produced (the script ran), and it actually consumed the stream (the boss
	# Apotheosis phase rolls chance()+choice() every turn).
	assert_int(seq_a1.size()).is_greater(0)
	# Same seed -> byte-identical decision sequence.
	assert_array(seq_a1).is_equal(seq_a2)
	# Different seed -> the decisions CAN differ. (If they didn't, the RNG path would be paper-only.)
	assert_bool(seq_a1 == seq_b).is_false()


func test_neutral_brain_consumes_no_rng_and_is_seed_independent() -> void:
	# The flip side of the guarantee: the NEUTRAL (first-alive) brain draws NOTHING, so its decisions
	# are identical REGARDLESS of seed. This is what keeps controller-vs-simulate parity byte-identical.
	var seq_seed_1 := _neutral_target_sequence(123)
	var seq_seed_2 := _neutral_target_sequence(999)
	assert_array(seq_seed_1).is_equal(seq_seed_2)


func _three_foes() -> Array:
	# Three live foes, distinct names; the unpredictable/choice draws have real options to differ on.
	return [
		BattleEngine.Mon.new("Foe_A", "Gaia", "Ouranos", "wild", "T2"),
		BattleEngine.Mon.new("Foe_B", "Cosmos", "Eros", "wild", "T2"),
		BattleEngine.Mon.new("Foe_C", "Chaos", "Thanatos", "wild", "T2"),
	]


# Drive the boss brain (Apotheosis phase = unpredictable: a chance()+choice() draw every turn) over a
# fixed 6-turn script and collect the chosen target name each turn. ONE CanonicalRNG instance is
# threaded across the turns (exactly how BattleController feeds its SEL sub-stream), so the stream
# advances naturally. Gates are set so the HSM is in Apotheosis from turn 1 (low HP / high entropy).
func _boss_target_sequence(seed: int) -> Array:
	var brain := CombatBrainScript.new({"name": "Ascended"})
	var boss := BattleEngine.Mon.new("Boss", "Chaos", "Thanatos", "god", "god")
	brain.assign_boss(boss)
	var foes := _three_foes()
	var sel_rng := CanonicalRNG.new(seed)
	var out: Array = []
	for turn in range(1, 7):
		var st := {
			"actor": boss,
			"allies": [boss],
			"foes": foes,
			"turn": turn,
			"entropy": 2.0,  # past apotheosis_entropy -> Apotheosis from the first decision
			"boss_hp_frac": 0.1,  # past apotheosis_hp_frac -> Apotheosis
			"boss_squad_losses": 0,
		}
		var action := brain.choose_action(st, sel_rng)
		out.append(_target_name(action))
	return out


func _neutral_target_sequence(seed: int) -> Array:
	var brain := CombatBrainScript.new()  # default = neutral brain (RNG-free)
	var actor := BattleEngine.Mon.new("Hero", "Gaia", "Ouranos", "wild", "T2")
	var foes := _three_foes()
	var sel_rng := CanonicalRNG.new(seed)
	var out: Array = []
	for turn in range(1, 7):
		var st := {"actor": actor, "allies": [actor], "foes": foes, "turn": turn, "entropy": 1.0}
		var action := brain.choose_action(st, sel_rng)
		out.append(_target_name(action))
	return out


func _target_name(action: Dictionary) -> String:
	if action.is_empty():
		return "<none>"
	var tgt := action.get("target") as BattleEngine.Mon
	return tgt.name if tgt != null else "<none>"
