extends GdUnitTestSuite
## Persistence round-trip (Cluster 4 D4, ADR-012): the inventory + status/ability state serialize ->
## JSON -> deserialize INTACT, as DATA ONLY (no objects/Resources cross the wire). Also proves the
## inventory payload embeds cleanly in the RunContext.inventory slice and survives a SaveEnvelope
## round-trip (the .tres-free path the brief requires).

const InventoryAdapterScript := preload("res://infrastructure/inventory/inventory_adapter.gd")
const StatusContainerScript := preload("res://application/status/status_container.gd")
const AbilityContainerScript := preload("res://application/status/ability_container.gd")
const RunContextScript := preload("res://application/persistence/run_context.gd")
const SaveEnvelopeScript := preload("res://application/persistence/save_envelope.gd")
const SkillEngineScript := preload("res://domain/skill_engine.gd")


func test_inventory_round_trips_as_pure_data() -> void:
	var inv := InventoryAdapterScript.new()
	inv.add("organ", "ruin_heart", 2)
	inv.add("gene", "venom", 1)
	inv.add("organ", "claw", 1, {"rank": "god", "source": "boss"})
	inv.add("consumable", "stim", 4)

	# Serialize -> JSON string -> parse: must be plain JSON (no objects/Resources).
	var rows := inv.to_dict()
	var parsed: Variant = JSON.parse_string(JSON.stringify(rows))
	assert_bool(parsed is Array).is_true()

	var back := InventoryAdapterScript.from_rows(parsed)
	assert_int(back.count("organ", "ruin_heart")).is_equal(2)
	assert_int(back.count("gene", "venom")).is_equal(1)
	assert_int(back.count("consumable", "stim")).is_equal(4)
	# The meta-tagged god claw survives as its own variant (not merged with a wild claw).
	assert_int(back.count("organ", "claw", {"rank": "god", "source": "boss"})).is_equal(1)
	assert_int(back.stack_count()).is_equal(inv.stack_count())


func test_qty_stays_integral_across_json() -> void:
	# Regression for the JSON-number-as-float gotcha: a bare `2` reparses as 2.0; from_dict int()-wraps
	# it so consume math stays integral. Round-trip then consume to prove the qty is a true int.
	var inv := InventoryAdapterScript.new()
	inv.add("plating", "scale", 3)
	var back := InventoryAdapterScript.from_rows(JSON.parse_string(JSON.stringify(inv.to_dict())))
	assert_int(back.consume("plating", "scale", 3)).is_equal(3)
	assert_int(back.count("plating", "scale")).is_equal(0)


func test_status_container_round_trips() -> void:
	var sc := StatusContainerScript.new("Gnash", "Thanatos", "Chaos", "T2")
	sc.apply("Wither")
	sc.apply("Wither")  # stacks
	sc.apply("Petrify")  # control, refresh
	sc.add_corruption(30, "taboo splice")
	var before_hp := sc.hp()
	var before_corr := sc.corruption()
	var before_stacks := sc.stacks_of("Wither")

	var data := sc.to_dict()
	var parsed: Variant = JSON.parse_string(JSON.stringify(data))
	assert_bool(parsed is Dictionary).is_true()

	var back := StatusContainerScript.new("placeholder", "Thanatos", "Chaos", "T2")
	back.load_from(parsed)
	assert_str(back.combatant_name()).is_equal("Gnash")
	assert_bool(back.has_status("Wither")).is_true()
	assert_int(back.hp()).is_equal(before_hp)
	assert_int(back.corruption()).is_equal(before_corr)
	assert_int(back.stacks_of("Wither")).is_equal(before_stacks)
	assert_bool(back.has_status("Petrify")).is_true()
	assert_int(back.duration_of("Petrify")).is_equal(sc.duration_of("Petrify"))


func test_ability_container_round_trips_live_state() -> void:
	var kit := ["Riot Fang", "Aegis"]
	var ac := AbilityContainerScript.new("Brute", "Chaos", "Gaia", "wild", "T2", kit)
	# Mutate live state through engine-resolved methods, then snapshot.
	var ally := AbilityContainerScript.new("Brute", "Chaos", "Gaia", "wild", "T2", kit)
	ac.use_support("Aegis", [ally])  # gives a shield (engine-computed)
	var data := ac.to_dict()
	var parsed: Variant = JSON.parse_string(JSON.stringify(data))
	assert_bool(parsed is Dictionary).is_true()

	var back := AbilityContainerScript.new("placeholder", "Chaos", "Gaia", "wild", "T2", kit)
	back.load_from(parsed)
	assert_str(back.combatant_name()).is_equal("Brute")
	assert_int(back.hp()).is_equal(ac.hp())
	assert_int(back.max_hp()).is_equal(ac.max_hp())
	assert_bool(back.is_alive()).is_equal(ac.is_alive())
	assert_array(back.abilities()).contains(["Riot Fang", "Aegis"])


# Pins the bug_risk fix (Sourcery): maxhp is NOT persisted; it is RE-DERIVED from the persisted
# identity (rank/tier) on load through the oracle. The serialized dict omits maxhp and carries
# rank/tier; load_from rebuilds the Mon from the SAVED identity (not the constructor args of `back`),
# so even a placeholder built with a DIFFERENT identity ends up with the oracle's correct maxhp.
func test_ability_container_rederives_maxhp_not_persisted() -> void:
	var kit := ["Riot Fang", "Aegis"]
	var ac := AbilityContainerScript.new("Brute", "Chaos", "Gaia", "wild", "T2", kit)
	var data := ac.to_dict()

	# maxhp is intentionally NOT in the snapshot; rank/tier (the stat sources) ARE.
	assert_bool(data.has("maxhp")).is_false()
	assert_bool(data.has("rank")).is_true()
	assert_bool(data.has("tier")).is_true()
	assert_str(str(data["rank"])).is_equal("wild")
	assert_str(str(data["tier"])).is_equal("T2")

	# Build `back` with a DELIBERATELY DIFFERENT identity (different forces + tier => different stats).
	# load_from must REBUILD from the saved identity and re-derive maxhp through the oracle, so back's
	# maxhp equals a fresh Mon built from the SAVED identity — NOT the placeholder's maxhp.
	var back := AbilityContainerScript.new("placeholder", "Eros", "Cosmos", "wild", "T1", [])
	var placeholder_maxhp := back.max_hp()
	back.load_from(JSON.parse_string(JSON.stringify(data)))
	var oracle := SkillEngineScript.Mon.new("Brute", "Chaos", "Gaia", "wild", "T2", kit)
	assert_int(back.max_hp()).is_equal(oracle.maxhp)
	assert_int(back.max_hp()).is_equal(ac.max_hp())
	assert_int(back.max_hp()).is_not_equal(placeholder_maxhp)  # proves it re-derived, not kept


func test_inventory_embeds_in_run_context_and_save_envelope() -> void:
	var inv := InventoryAdapterScript.new()
	inv.add("organ", "ruin_heart", 2)
	inv.add("core", "god_core", 1, {"rank": "god"})

	var ctx: RunContext = RunContextScript.new()
	ctx.run_id = "run-d4"
	ctx.seed = 99
	ctx.inventory = inv.to_dict()  # the inventory slice is the data-only array

	var json := SaveEnvelopeScript.build_json(ctx.to_dict())
	var envelope := SaveEnvelopeScript.parse_json(json)
	assert_dict(envelope).is_not_empty()
	assert_bool(SaveEnvelopeScript.verify_checksum(envelope)).is_true()

	var back: RunContext = RunContextScript.from_dict(SaveEnvelopeScript.run_payload(envelope))
	var back_inv := InventoryAdapterScript.from_rows(back.inventory)
	assert_int(back_inv.count("organ", "ruin_heart")).is_equal(2)
	assert_int(back_inv.count("core", "god_core", {"rank": "god"})).is_equal(1)
