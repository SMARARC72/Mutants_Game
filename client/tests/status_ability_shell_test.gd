extends GdUnitTestSuite
## OctoD shell parity (Cluster 4 D4, ADR-015 / DoD item 4): a status/buff/ability applied THROUGH the
## container shell reflects the status_engine / skill_engine numbers EXACTLY — no addon-computed value.
## We compare the container's reported state against a DIRECT call to the oracle on a parallel state.
## If the shell added or recomputed any number (DOT damage, control duration, shield, buff, HP), these
## would diverge. The shell contributes lifecycle/presentation only.

const StatusContainerScript := preload("res://application/status/status_container.gd")
const AbilityContainerScript := preload("res://application/status/ability_container.gd")
const StatusEngineScript := preload("res://domain/status_engine.gd")
const SkillEngineScript := preload("res://domain/skill_engine.gd")


# A DOT applied + ticked through the shell deals the SAME damage as StatusEngine on a parallel C.
func test_status_dot_matches_oracle() -> void:
	var sc := StatusContainerScript.new("Gnash", "Thanatos", "Chaos", "T2")
	# Parallel oracle state, built identically.
	var c := StatusEngineScript.C.new("Gnash", "Thanatos", "Chaos", "T2")
	var oracle_log: Array = []

	# Same starting HP (the shell asked the oracle for it).
	assert_int(sc.hp()).is_equal(c.hp)

	# Apply Wither twice (DOTs stack) on both, then tick both once.
	sc.apply("Wither")
	sc.apply("Wither")
	StatusEngineScript.apply(c, "Wither", oracle_log)
	StatusEngineScript.apply(c, "Wither", oracle_log)
	assert_int(sc.stacks_of("Wither")).is_equal(int(c.status["Wither"]["stacks"]))

	sc.tick()
	StatusEngineScript.tick(c, [c], oracle_log)
	# The shell's HP after the tick equals the oracle's — the DOT number is the engine's, not the shell's.
	assert_int(sc.hp()).is_equal(c.hp)
	assert_int(sc.hp()).is_less(sc.max_hp())  # it actually took damage


# A control status refreshes to the engine's duration; the countdown is the engine's.
func test_control_duration_matches_oracle() -> void:
	var sc := StatusContainerScript.new("Stoneback", "Gaia", "Cosmos", "T2")
	var c := StatusEngineScript.C.new("Stoneback", "Gaia", "Cosmos", "T2")
	var log: Array = []

	sc.apply("Petrify")
	StatusEngineScript.apply(c, "Petrify", log)
	assert_int(sc.duration_of("Petrify")).is_equal(int(c.status["Petrify"]["dur"]))

	sc.tick()
	StatusEngineScript.tick(c, [c], log)
	assert_int(sc.duration_of("Petrify")).is_equal(int(c.status["Petrify"]["dur"]))


# Corruption burnout (feral) flips at the oracle's threshold — the shell does not own the threshold.
func test_corruption_burnout_matches_oracle() -> void:
	var sc := StatusContainerScript.new("Wretch", "Chaos", "Thanatos", "T2")
	var c := StatusEngineScript.C.new("Wretch", "Chaos", "Thanatos", "T2")
	var log: Array = []

	sc.add_corruption(100, "taboo")
	StatusEngineScript.add_corruption(c, 100, "taboo", log)
	assert_int(sc.corruption()).is_equal(c.corruption)
	assert_bool(sc.is_feral()).is_equal(c.feral)
	assert_bool(sc.is_feral()).is_true()


# A support skill (Ward) applied through the ability shell yields the SAME shield as SkillEngine.
func test_ability_support_matches_oracle() -> void:
	var kit := ["Aegis"]  # a Ward-verb skill (shield 0.3)
	var caster := AbilityContainerScript.new("Warden", "Cosmos", "Eros", "wild", "T2", kit)
	var ally := AbilityContainerScript.new("Ward Me", "Gaia", "Eros", "wild", "T2", [])

	# Parallel oracle Mons.
	var o_caster := SkillEngineScript.Mon.new("Warden", "Cosmos", "Eros", "wild", "T2", kit)
	var o_ally := SkillEngineScript.Mon.new("Ward Me", "Gaia", "Eros", "wild", "T2", [])
	var o_log: Array = []

	caster.use_support("Aegis", [ally])
	SkillEngineScript.support(o_caster, "Aegis", [o_ally], o_log)
	# The ally's shield through the shell equals the engine's shield (Ward picks the lowest-hp-frac ally;
	# with one ally that's the ally). The number is the engine's; the shell only forwarded the call.
	assert_int(ally.shield()).is_equal(o_ally.shield)
	assert_int(ally.shield()).is_greater(0)


# A damaging skill through the shell deals the SAME damage as SkillEngine.damage on a parallel target.
func test_ability_damage_matches_oracle() -> void:
	var attacker := AbilityContainerScript.new(
		"Maw", "Chaos", "Thanatos", "wild", "T2", ["Riot Fang"]
	)
	var target := AbilityContainerScript.new("Prey", "Cosmos", "Gaia", "wild", "T2", [])

	var o_atk := SkillEngineScript.Mon.new("Maw", "Chaos", "Thanatos", "wild", "T2", ["Riot Fang"])
	var o_tgt := SkillEngineScript.Mon.new("Prey", "Cosmos", "Gaia", "wild", "T2", [])
	var o_log: Array = []

	attacker.use_damage("Riot Fang", target, 1.0, 1.0)
	SkillEngineScript.damage(o_atk, "Riot Fang", o_tgt, 1.0, 1.0, o_log)
	assert_int(target.hp()).is_equal(o_tgt.hp)
	assert_int(target.hp()).is_less(target.max_hp())  # damage actually landed
