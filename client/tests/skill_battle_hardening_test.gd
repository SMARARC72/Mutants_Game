extends GdUnitTestSuite
## Battle v2 hardening (Phase 12) — the Codex findings the auto-merges didn't address:
##   * a Rouse skill with NO eligible ally (last-survivor / solo actor) is a SAFE no-op, not a null
##     deref in SkillEngine.support (Codex #42/#44);
##   * a control status holds the afflicted actor for its FULL duration regardless of when it was
##     applied — the turn-start snapshot fixes the off-by-one where the final turn was lost to the
##     tick's erase-then-act (Codex #45).
## Teams are explicit AbilityContainers so kits + forces are controlled.

const SkillBattleControllerScript := preload("res://application/battle/skill_battle_controller.gd")


func _ac(
	name: String, prim: String, sec: String, rank: String, tier: String, kit: Array
) -> AbilityContainer:
	return AbilityContainer.new(name, prim, sec, rank, tier, kit)


func _advance_to_player(sess: Variant) -> Dictionary:
	var step: Dictionary = sess.advance()
	var guard := 0
	while not sess.is_ended() and str(step.get("kind", "")) != "await_player" and guard < 80:
		guard += 1
		step = sess.advance()
	return step


func test_solo_rouse_is_a_safe_no_op() -> void:
	# A lone Ouranos creature knows Tailwind (Rouse) + Gale Slash. Choosing the Rouse with no other ally
	# must NOT crash (the engine guards the null target) — the battle stays coherent.
	var ctrl := SkillBattleControllerScript.new(CanonicalRNG.new(0x12345))
	var lone := _ac("Lone", "Ouranos", "Eros", "wild", "T2", ["Tailwind", "Gale Slash"])
	var foe := _ac("Foe", "Gaia", "Cosmos", "wild", "T2", ["Boulder Smash", "Bulwark"])
	var sess: Variant = ctrl.interactive([lone], [foe], "A", false)
	var step := _advance_to_player(sess)
	assert_str(str(step.get("kind", ""))).is_equal("await_player")
	var after: Dictionary = sess.use_skill("Tailwind", null)  # Rouse with no ally -> safe no-op
	assert_object(after).is_not_null()
	assert_bool(lone.is_alive()).is_true()  # unharmed by its own no-op; no crash


func test_control_holds_for_its_full_duration() -> void:
	# A tanky Cosmos sealer Binds a tanky mook ONCE (Seal, dur 2), then only self-Wards (never re-sealing
	# / killing). The mook must skip TWICE (the snapshot fix); the pre-fix bug lost the 2nd skip.
	var ctrl := SkillBattleControllerScript.new(CanonicalRNG.new(0xBADA55))
	var sealer := _ac("Sealer", "Cosmos", "Ouranos", "wild", "T3", ["Bind", "Aegis"])
	var mook := _ac("Mook", "Gaia", "Cosmos", "wild", "T3", ["Boulder Smash", "Bulwark"])
	var sess: Variant = ctrl.interactive([sealer], [mook], "A", true)
	var bound := false
	var guard := 0
	var step: Dictionary = sess.advance()
	while not sess.is_ended() and guard < 120:
		guard += 1
		if str(step.get("kind", "")) == "await_player":
			if not bound:
				step = sess.use_skill("Bind", mook)  # Cosmos Hex -> Seal (control), once
				bound = true
			else:
				step = sess.use_skill("Aegis", null)  # self-ward; never re-seal, never kill
		else:
			step = sess.advance()
	var skips := 0
	for line in sess.transcript():
		if str(line).contains("is held by a status"):
			skips += 1
	assert_bool(bound).is_true()
	assert_int(skips).is_greater_equal(2)  # full dur-2 hold (the bug gave only 1)
