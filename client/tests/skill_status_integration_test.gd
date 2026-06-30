extends GdUnitTestSuite
## Skill-battle STATUS integration (Phase 10 · Slice 4), headless. Proves the opt-in status layer:
##   * a Hex skill inflicts its force's signature status (Wither->Wither DOT, Bind/Cosmos->Seal control);
##   * a DOT ticks real damage onto the canonical combat HP on later turns (StatusEngine math, reconciled);
##   * a CONTROL status makes the afflicted actor forfeit its action (the control-skip);
##   * with the layer OFF (the parity mode) there are NO status containers (status_of -> null).
## Teams are built as explicit AbilityContainers so the kit (who has the Hex) is controlled.

const SkillBattleControllerScript := preload("res://application/battle/skill_battle_controller.gd")


func _ac(
	name: String, prim: String, sec: String, rank: String, tier: String, kit: Array
) -> AbilityContainer:
	return AbilityContainer.new(name, prim, sec, rank, tier, kit)


## A Thanatos hexer (knows Wither) vs a beefy Gaia tank (legendary HP, survives to be ticked).
func _hexer_vs_tank() -> Dictionary:
	var hexer := _ac("Hexer", "Thanatos", "Ouranos", "wild", "T2", ["Wither", "Soul Leech"])
	var tank := _ac("Tank", "Gaia", "Cosmos", "wild", "T3", ["Boulder Smash", "Bulwark"])
	return {"a": [hexer], "b": [tank]}


func _binder_vs_tank() -> Dictionary:
	var binder := _ac("Binder", "Cosmos", "Gaia", "wild", "T2", ["Bind", "Aegis"])
	var tank := _ac("Tank", "Gaia", "Eros", "wild", "T3", ["Boulder Smash", "Bulwark"])
	return {"a": [binder], "b": [tank]}


func _session(teams: Dictionary, with_statuses: bool) -> Variant:
	var ctrl := SkillBattleControllerScript.new(CanonicalRNG.new(0x5747A))
	return ctrl.interactive(teams["a"], teams["b"], "A", with_statuses)


func _advance_to_player(sess: Variant) -> Dictionary:
	var step: Dictionary = sess.advance()
	var guard := 0
	while not sess.is_ended() and str(step.get("kind", "")) != "await_player" and guard < 200:
		guard += 1
		step = sess.advance()
	return step


func test_status_layer_off_has_no_containers() -> void:
	var teams := _hexer_vs_tank()
	var sess: Variant = _session(teams, false)
	_advance_to_player(sess)
	# In parity mode there is no parallel status state at all.
	assert_object(sess.status_of(teams["a"][0])).is_null()


func test_hex_inflicts_its_force_signature_status() -> void:
	var teams := _hexer_vs_tank()
	var sess: Variant = _session(teams, true)
	var tank: AbilityContainer = teams["b"][0]
	var step := _advance_to_player(sess)
	assert_str(str(step.get("kind", ""))).is_equal("await_player")
	sess.use_skill("Wither", tank)  # Thanatos Hex -> Wither DOT
	var sc: StatusContainer = sess.status_of(tank)
	assert_object(sc).is_not_null()
	assert_bool(sc.has_status("Wither")).is_true()
	assert_int(sc.stacks_of("Wither")).is_greater(0)


func test_dot_ticks_real_damage_on_later_turns() -> void:
	var teams := _hexer_vs_tank()
	var sess: Variant = _session(teams, true)
	var tank: AbilityContainer = teams["b"][0]
	# Each player turn re-applies Wither (stacking the DOT); the tank is legendary so it survives to tick.
	var guard := 0
	while not sess.is_ended() and guard < 60:
		guard += 1
		var step: Dictionary = sess.advance()
		if str(step.get("kind", "")) == "await_player":
			sess.use_skill("Wither", tank)
	# The DOT actually ticked (engine-produced line) and the tank lost HP from it.
	var ticked := false
	for line in sess.transcript():
		if str(line).begins_with("   Wither ticks "):
			ticked = true
			break
	assert_bool(ticked).is_true()
	assert_int(tank.hp()).is_less(tank.max_hp())


func test_control_status_skips_the_afflicted_actor() -> void:
	var teams := _binder_vs_tank()
	var sess: Variant = _session(teams, true)
	var tank: AbilityContainer = teams["b"][0]
	# Bind (Cosmos Hex) -> Seal control on the tank; over the next turns it forfeits its action.
	var guard := 0
	var saw_skip := false
	while not sess.is_ended() and guard < 60:
		guard += 1
		var step: Dictionary = sess.advance()
		if str(step.get("kind", "")) == "await_player":
			sess.use_skill("Bind", tank)
		for line in sess.transcript():
			if str(line).contains("is held by a status"):
				saw_skip = true
	var sc: StatusContainer = sess.status_of(tank)
	assert_object(sc).is_not_null()
	# Seal was inflicted at least once, and a held actor skipped its turn.
	assert_bool(saw_skip).is_true()
