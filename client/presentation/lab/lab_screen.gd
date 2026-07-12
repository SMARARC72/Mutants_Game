extends Control
## LabScreen — THE LIVING CREATION TABLE (Wave 15, over the Phase 5 · Slice 3a bench). The lab's
## two MVP ops (FUSE / MUTATE) staged as apparatus: subject/donor LivingPlates flanking a bubbling
## vessel (LabBenchView), a method HSlider whose CONTINUUM is pure presentation (the recipe stays
## BINARY: "wild" iff value >= 0.5 — Geneticist veto, parity/goldens untouched), a hold-to-seal
## commit ring (LabRitual, player-driven, exempt from fast-forward), a taboo arm-then-seal pact,
## and a <3s newborn reveal (dim -> surge -> dissolve-in -> name types on -> ledger count-up).
##
## THE BOUNDARY HOLDS (ADR-015): this screen computes NO stat / blend / cost. It only:
##   * resolves party creature_instance(s) -> LabBench [name, prim, sec, tier] tuples (LabLineage),
##   * resolves chosen inventory ingredient(s) -> ingredient-id Strings,
##   * authors a LabRecipe and routes it through LabRecipeBench -> LabBench -> domain/lab_engine,
##   * RENDERS the verdict + the oracle's numbers — count-up tweens interpolate the DISPLAY toward
##     the oracle's reported values, never a computed one. At the wild end the preview flickers
##     through the LegalitySolver's FULL configs array (~8Hz) — real alternates, no UI math.
## HEADLESS: `_juice_enabled` stays false (battle_beats pattern) — every animated path has a
## synchronous twin, and the ritual state machine is tick()-driven so suites stay green.

const SpliceRulesScript := preload("res://infrastructure/lab/splice_rules.gd")
const LabRecipeBenchScript := preload("res://application/lab/lab_recipe_bench.gd")
const LabRecipeScript := preload("res://infrastructure/inventory/lab_recipe.gd")
const LegalitySolverScript := preload("res://infrastructure/lab/legality_solver.gd")
const InputActions := preload("res://infrastructure/input/input_actions.gd")
const LabLineageScript := preload("res://presentation/lab/lab_lineage.gd")
const LabBenchViewScript := preload("res://presentation/lab/lab_bench_view.gd")
const LabTableBuildScript := preload("res://presentation/lab/lab_table_build.gd")
const LabVerdictKitScript := preload("res://presentation/lab/lab_verdict_kit.gd")
const OVERWORLD_SCENE := "res://presentation/overworld/overworld_screen.tscn"

## The two MVP ops this bench exposes. (graft/self_splice/reanimate live on the Forbidden Ladder
## rail as read-only flavor — out of this slice's scope.)
const OPS: Array = ["fuse", "mutate"]

## Essence a sealed splice drinks (Wave 5 — costs bite). Application-side economy bookkeeping
## (mirrors LevelingService.RESONANCE_ESSENCE_COST — not an oracle number). Debited on a LEGAL
## commit, FLOORED AT ZERO so a fresh (essence-0) run can still seal its first rite.
const SPLICE_ESSENCE_COST := 10

var _game: Node = null
var _transition: Node = null
var _input: Node = null
var _rules: SpliceRules = null
var _bench: LabRecipeBench = null

# --- selection state (indices into the party / item keys; never resolved numbers) -------------- #
var _op: String = "fuse"
var _idx_a: int = -1  # party index of creature A (fuse host / mutate host)
var _idx_b: int = -1  # party index of creature B (fuse partner; unused for mutate)
var _ingredients: Array = []  # chosen ingredient item_keys (fuse: optional organs; mutate: one gene)
var _method_value := 0.0  # the slider's continuum; the RECIPE only ever sees precise|wild
var _last_verdict: Dictionary = {}
var _last_commit: Dictionary = {}
var _commit_count: int = 0  # distinguishes successive op_ids within one run (reproducible per index)
var _alt_index: int = 0  # which solver config the wild preview currently shows
var _pact_armed := false  # taboo two-step: first press arms, second press starts the hold

## When false, _ready does NOT auto-build (a headless test injects a GameController + drives build()).
var _auto_build: bool = true
## Juice = tweens/particles/reveal choreography. -1 auto (windowed && !reduce_motion), 0/1 forced.
var _juice_override: int = -1
var _juice_enabled := false

# --- reveal state (juice mode only) ------------------------------------------------------------ #
var _reveal_playing := false
var _reveal_tweens: Array = []
var _reveal_dim: ColorRect = null
var _reveal_creature: Dictionary = {}
var _reveal_instance: Dictionary = {}

# --- UI node handles (code-built; styled via ThemeService) ------------------------------------- #
var _root_box: VBoxContainer = null
var _bench_view: Control = null  # LabBenchView — the staged table
var _ladder_rail: VBoxContainer = null
var _op_row: HBoxContainer = null
var _a_picker: HFlowContainer = null
var _b_picker: HFlowContainer = null
var _ingredient_picker: HFlowContainer = null
var _b_section: VBoxContainer = null
var _method_slider: HSlider = null
var _method_readout: Label = null
var _verdict_panel: PanelContainer = null
var _verdict_label: RichTextLabel = null
var _result_label: RichTextLabel = null
var _pact_tween: Tween = null
var _cycle_timer: Timer = null
## Wave 9: the committed newborn's LivingPlate + one-of-one sigil in the verdict panel (hidden
## until a splice lands; a fresh preview hides it again).
var _newborn_row: HBoxContainer = null
var _newborn_plate: LivingPlate = null
var _newborn_sigil: Control = null
var _again_row: HBoxContainer = null
var _gallows_label: Label = null
var _preview_button: Button = null
var _commit_button: Button = null
var _ritual: Control = null  # LabRitual — the seal ring on the commit verb
var _first_op_button: Button = null  # first rite button (the W1 focus anchor)


func _ready() -> void:
	# An injected _game (set_game before add_child) MUST win; only fall back to the autoload when
	# nothing was injected, so the test harness is never clobbered (mirrors battle/overworld screens).
	if _game == null:
		_game = get_node_or_null("/root/GameController")
	_transition = get_node_or_null("/root/Transition")
	_input = get_node_or_null("/root/InputService")
	var theme_service := get_node_or_null("/root/ThemeService")
	if theme_service != null and theme_service.has_method("apply_to"):
		theme_service.call("apply_to", self)
	if _input != null and _input.has_method("switch_context"):
		_input.call("switch_context", InputActions.CTX_LAB)
	if _auto_build and _game != null and _game.has_method("has_run") and _game.call("has_run"):
		build()


## Reveal skip (tension 10): any press skips once the first-ever reveal has been seen; a held
## CONFIRM always fast-forwards. (Named _unhandled_input — `_input` is the InputService handle.)
func _unhandled_input(event: InputEvent) -> void:
	if not _reveal_playing:
		return
	var pressy := (
		event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton
	)
	if pressy and event.is_pressed():
		_try_skip_reveal()


# === injection seams (tests / non-autoload contexts) ========================================== #


## Inject the GameController. Call BEFORE add_child/build() so injection wins over the autoload.
func set_game(game: Node) -> void:
	_game = game


## Disable the automatic build on _ready (tests drive build() explicitly after configuring a game).
func set_auto_build(enabled: bool) -> void:
	_auto_build = enabled


## Force the juice layer on/off (tests exercise both routes; devcap forces on). Default: on only
## windowed with reduce_motion off — headless suites never animate.
func set_juice_enabled(enabled: bool) -> void:
	_juice_override = 1 if enabled else 0
	_apply_juice()


# === build ==================================================================================== #


## Build the bench from the active GameController run. Public so a test drives it after injecting a
## configured GameController. Loads the ruleset + recipe bench, then renders the code-built UI.
func build() -> void:
	if _game == null:
		return
	if _rules == null:
		_rules = SpliceRulesScript.load_default()
	if _rules == null:
		return
	_bench = LabRecipeBenchScript.new(_rules)
	# Default the selection to the first two party creatures so a headless preview has inputs.
	var party: Array = _party()
	_idx_a = 0 if party.size() >= 1 else -1
	_idx_b = 1 if party.size() >= 2 else -1
	_build_ui()
	_apply_juice()
	refresh()
	# W1 focus pass: the op row owns first focus so the bench is keyboard/gamepad-drivable.
	_focus_op_row()


# === op + input selection (public so UI buttons AND headless tests drive them) ================ #


## Choose the op ("fuse" | "mutate"). Resets the op-specific ingredient picks (a gene is mutate-only).
func select_op(op: String) -> void:
	if not OPS.has(op):
		return
	_op = op
	_ingredients.clear()
	_pact_armed = false
	if _b_section != null:
		_b_section.visible = _op == "fuse"
	refresh()


## Select creature A (fuse host / mutate host) by party index. Refreshes the preview affordances.
func set_creature_a(party_index: int) -> void:
	_idx_a = party_index
	_pact_armed = false
	refresh()


## Select the fuse partner B by party index (ignored for mutate). Refreshes the preview affordances.
func set_creature_b(party_index: int) -> void:
	_idx_b = party_index
	_pact_armed = false
	refresh()


## Toggle an ingredient item_key in/out of the recipe. FUSE: optional organs (any number, the solver
## may skip). MUTATE: exactly ONE gene-vial (selecting a gene replaces the prior pick). Refreshes.
func toggle_ingredient(item_key: String) -> void:
	if _op == "mutate":
		# A mutate carries a single gene-vial: selecting one replaces any prior pick.
		_ingredients = [] if _ingredients.has(item_key) else [item_key]
	elif _ingredients.has(item_key):
		_ingredients.erase(item_key)
	else:
		_ingredients.append(item_key)
	_pact_armed = false
	refresh()


## The method slider's continuum position (0 precise .. 1 wild). PRESENTATION drives bench jitter/
## sparks/tint continuously; the RECIPE stays binary via current_method() (engine untouched).
func set_method_value(v: float) -> void:
	_method_value = clampf(v, 0.0, 1.0)
	_pact_armed = false
	if _method_slider != null and not is_equal_approx(_method_slider.value, _method_value):
		_method_slider.set_value_no_signal(_method_value)
	refresh()


## The BINARY method the recipe carries: "wild" iff the slider sits at/past the midpoint.
func current_method() -> String:
	return "wild" if _method_value >= 0.5 else "precise"


# === preview / commit (route through the boundary; compute NOTHING here) ======================= #


## PREVIEW the current selection via LabRecipeBench (no consumption). Returns the LegalitySolver
## verdict verbatim ({ verdict, reason, unlock_cost, configs, ingredients_available }) and renders it.
## Returns {} when the selection is incomplete (e.g. no creatures chosen / unknown ingredient).
func preview() -> Dictionary:
	if _bench == null:
		return {}
	_alt_index = 0
	var recipe := _build_recipe()
	if recipe == null:
		_last_verdict = {}
		_render_verdict(_last_verdict)
		return {}
	_last_verdict = _bench.preview_recipe(recipe, _inventory(), _player_state())
	_render_verdict(_last_verdict)
	return _last_verdict


## COMMIT the current selection. Only proceeds on a LEGAL + affordable verdict; otherwise returns the
## non-LEGAL verdict unchanged and does NOTHING (no creature, no inventory change — ADR-015). On
## success: the recipe bench debits the consumed parts, the oracle's creature is shaped into a party
## creature_instance (lineage carries the splice_config), added to the run, and the run is saved.
## Returns the LabRecipeBench result ({ verdict, creature, splice_config, consumed } on LEGAL).
## This is the DIRECT path (tests / the sealed ritual both land here).
func commit() -> Dictionary:
	if _bench == null or _game == null:
		return {}
	var recipe := _build_recipe()
	if recipe == null:
		return {}
	var run: RunContext = _game.call("run")
	if run == null:
		return {}
	var op_id := _next_op_id()
	var result := _bench.commit_recipe(recipe, _inventory(), _player_state(), run.seed, op_id)
	_last_commit = result
	if int(result.get("verdict", -1)) != LegalitySolverScript.Verdict.LEGAL:
		# ILLEGAL / TABOO / unaffordable: surface the verdict, add NOTHING, eat NO parts.
		_render_verdict(result)
		LabVerdictKitScript.toast_outcome(self, result, false)
		return result

	# LEGAL: the oracle already produced the creature; shape it into a party creature_instance
	# (BEFORE the parents leave the roster — the lineage tags read them by index).
	var creature: Dictionary = result.get("creature", {})
	var party: Array = _party()
	var catalog := _catalog()
	var parents: Array = [LabLineageScript.parent_tag(party, _idx_a)]
	var tuples: Array = [LabLineageScript.creature_tuple(party, _idx_a, catalog)]
	if _op == "fuse":
		parents.append(LabLineageScript.parent_tag(party, _idx_b))
		tuples.append(LabLineageScript.creature_tuple(party, _idx_b, catalog))
	var instance := LabLineageScript.to_creature_instance(
		creature, result.get("splice_config", {}), _op, op_id, parents, tuples
	)
	# COSTS BITE (Wave 5): the oracle's corruption ledger lands on the RUN track, the rite drinks
	# essence (floored at 0), and the PARENTS ARE CONSUMED — the hybrid replaces them.
	run.corruption += int(creature.get("corruption", 0))
	run.essence = maxi(0, run.essence - SPLICE_ESSENCE_COST)
	var parent_indices: Array = [_idx_a]
	if _op == "fuse" and _idx_b != _idx_a:
		parent_indices.append(_idx_b)
	LabLineageScript.consume_parents(run, parent_indices)
	if _game.has_method("add_party_member"):
		_game.call("add_party_member", instance)
	# Re-aim the bench at the newborn (recursion: the committed hybrid is itself pickable again —
	# this is what "Again?" pre-arms).
	party = _party()
	_idx_a = party.size() - 1
	_idx_b = -1
	for i in party.size():
		if i != _idx_a:
			_idx_b = i
			break
	# W18 save trust: the witnessed save path first (SaveSentry surfaces the outcome).
	if _game.has_method("request_save"):
		_game.call("request_save")
	elif _game.has_method("save_run"):
		_game.call("save_run")
	_pact_armed = false
	LabVerdictKitScript.toast_outcome(self, result, true)
	refresh()  # the consumed parts + parents are gone — rebuild the pickers and drawer
	# AFTER the refresh (whose live preview clears the result panel): the newborn showcase. Juice
	# mode plays the staged reveal; headless/instant renders the identical end-state synchronously.
	if _juice_enabled and is_inside_tree():
		_play_reveal(creature, instance)
	else:
		_render_commit(creature, instance)
		_show_again_row()
	return result


# === ritual seal (hold-to-commit; player-driven, exempt from fast-forward) ===================== #


## The commit VERB's press path. Taboo pact: the first press only ARMS (a VoiceBook warning lands
## in the verdict panel); the second press begins the hold. Clean rites hold immediately.
func press_commit() -> void:
	if _commit_button != null and _commit_button.disabled:
		return
	if int(_last_verdict.get("verdict", -1)) != LegalitySolverScript.Verdict.LEGAL:
		return
	if pact_required() and not _pact_armed:
		_pact_armed = true
		_append_pact_warning()
		_update_commit_enabled()
		return
	if _ritual != null:
		_ritual.call("begin_hold")


## Release the seal hold (button_up). Early release SNUFFS the ring — nothing commits.
func release_seal_hold() -> void:
	if _ritual != null:
		_ritual.call("release_hold")


## Advance the seal hold by `delta` seconds — the instant/headless drive (juice mode self-ticks).
func ritual_tick(delta: float) -> void:
	if _ritual != null:
		_ritual.call("tick", delta)


## Current seal fill 0..1 (0 after a snuff).
func seal_progress() -> float:
	return float(_ritual.call("progress")) if _ritual != null else 0.0


## True while the seal hold is filling.
func is_sealing() -> bool:
	return bool(_ritual.call("is_holding")) if _ritual != null else false


## True when the previewed rite is LEGAL but taboo-flagged (gate met): sealing it is a PACT —
## two-step arm-then-seal, and the verb names the corruption price (a displayed constant).
func pact_required() -> bool:
	if int(_last_verdict.get("verdict", -1)) != LegalitySolverScript.Verdict.LEGAL:
		return false
	var configs: Array = _last_verdict.get("configs", [])
	if configs.is_empty():
		return false
	var flags: Dictionary = (configs[0] as Dictionary).get("flags", {})
	return bool(flags.get("taboo", false))


## True after the pact's first press (the second press seals).
func pact_armed() -> bool:
	return _pact_armed


# === wild preview alternates (REAL solver configs — no UI math) ================================ #


## The DISTINCT config summaries the solver returned for the current preview (>=2 means the wild
## flicker has real alternates to walk).
func alternate_summaries() -> Array:
	var out: Array = []
	for cfg in _last_verdict.get("configs", []):
		var s := LabVerdictKitScript.config_summary(cfg as Dictionary)
		if not out.has(s):
			out.append(s)
	return out


## Step the previewed config to the next solver alternate and re-render the verdict line. The
## juice-mode timer calls this at ~8Hz at the wild end; tests call it directly.
func cycle_alternate() -> void:
	var configs: Array = _last_verdict.get("configs", [])
	if configs.size() <= 1:
		return
	_alt_index = (_alt_index + 1) % configs.size()
	_render_verdict_text(_last_verdict)


# === accessors (for headless test assertions) ================================================= #


## The most recent preview/commit verdict dict (empty until a preview/commit runs).
func last_verdict() -> Dictionary:
	return _last_verdict


## The most recent commit result dict (empty until commit() runs).
func last_commit() -> Dictionary:
	return _last_commit


## The current op ("fuse" | "mutate").
func current_op() -> String:
	return _op


## True while the newborn reveal choreography is on stage (always false headless — instant twin).
func reveal_playing() -> bool:
	return _reveal_playing


## Return to the previous scene. The camp menu will set where "back" goes; for a standalone run we
## fall back to the overworld (keep it simple per the DoD).
func return_to_overworld() -> void:
	if _transition != null and _transition.has_method("change_scene_ritual"):
		await _transition.call("change_scene_ritual", OVERWORLD_SCENE)
	elif is_inside_tree():
		get_tree().change_scene_to_file(OVERWORLD_SCENE)


# === recipe assembly (selection -> LabRecipe; NO math) ======================================== #


## Build the LabRecipe for the current selection, or null if the selection is structurally incomplete
## (no host, fuse missing its partner, or an unresolvable creature index). The solver still decides
## LEGALITY at preview/commit; this only checks we have the inputs to ask the question.
func _build_recipe() -> LabRecipe:
	var party: Array = _party()
	var catalog := _catalog()
	var a: Array = LabLineageScript.creature_tuple(party, _idx_a, catalog)
	if a.is_empty():
		return null
	if _op == "fuse":
		var b: Array = LabLineageScript.creature_tuple(party, _idx_b, catalog)
		if b.is_empty():
			return null
		return LabRecipeScript.new("fuse", a, b, _ingredients.duplicate(), current_method())
	# mutate: one host + the chosen ingredients (a gene-vial). b is unused ([] placeholder).
	return LabRecipeScript.new("mutate", a, [], _ingredients.duplicate(), current_method())


## A reproducible-but-distinct op id for a commit: the op + the chosen party indices + a per-run
## counter, so the same selection committed twice draws fresh canonical sub-streams (each splice is a
## new creature) while remaining a pure function of (run.seed, op_id) for replay (LabBench derives the
## sub-stream from these). Tests can reproduce the exact rng from (run.seed, this op_id).
func _next_op_id() -> String:
	var id := "lab_%s_%d_%d_%d" % [_op, _idx_a, _idx_b, _commit_count]
	_commit_count += 1
	return id


# === run reads (through the GameController seams) ============================================== #


func _party() -> Array:
	if _game != null and _game.has_method("party"):
		return _game.call("party")
	return []


func _catalog() -> SpeciesCatalog:
	if _game != null and _game.has_method("catalog"):
		return _game.call("catalog")
	return null


func _inventory() -> InventoryAdapter:
	if _game != null and _game.has_method("inventory"):
		return _game.call("inventory")
	return InventoryAdapter.new()


func _player_state() -> Dictionary:
	if _game != null and _game.has_method("lab_player_state"):
		return _game.call("lab_player_state")
	return {"corruption": 0, "unlocks": [], "has_parts": []}


# === UI (code-built, themed) =================================================================== #


## Re-render the dynamic parts of the bench (op highlight, stage plates, pickers, ladder, live
## preview) without rebuilding the whole tree. Cheap to call after any selection change.
func refresh() -> void:
	if _root_box == null:
		return
	_render_op_row()
	_render_creature_pickers()
	_render_ingredient_picker()
	# A live preview keeps the verdict panel honest with the current selection.
	preview()
	_update_stage()
	_update_commit_enabled()
	_update_cycle_timer()
	if _ladder_rail != null:
		LabBenchViewScript.fill_ladder(_ladder_rail, _rules, _player_state())
	_ensure_focus()


## Keep keyboard focus ALIVE across refreshes: the pickers rebuild their buttons (queue_free), so
## a click/activation can leave focus on a dying node — re-anchor it to the op row when that
## happens. Never steals focus from a live control.
func _ensure_focus() -> void:
	if not is_inside_tree():
		return
	var focused := get_viewport().gui_get_focus_owner()
	if focused == null or focused.is_queued_for_deletion():
		_focus_op_row()


func _focus_op_row() -> void:
	if (
		_first_op_button != null
		and is_instance_valid(_first_op_button)
		and _first_op_button.is_inside_tree()
	):
		_first_op_button.grab_focus()


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# The table is ASSEMBLED by LabTableBuild (static, duck-typed — the battle_card_kit pattern);
	# this screen only keeps the refs and owns the wiring/state.
	var shell := LabTableBuildScript.build_shell(self)
	_root_box = shell["root_box"]
	_bench_view = shell["bench_view"]
	_op_row = shell["op_row"]
	_a_picker = shell["a_picker"]
	_b_section = shell["b_section"]
	_b_picker = shell["b_picker"]
	_ingredient_picker = shell["ingredient_picker"]
	_ladder_rail = shell["ladder_rail"]
	_b_section.visible = _op == "fuse"
	var method := LabTableBuildScript.build_method_row(self, _root_box)
	_method_slider = method["slider"]
	_method_slider.set_value_no_signal(_method_value)
	_method_readout = method["readout"]
	var verdict := LabTableBuildScript.build_verdict_panel(self, _root_box)
	_verdict_panel = verdict["panel"]
	_verdict_label = verdict["verdict_label"]
	_newborn_row = verdict["newborn_row"]
	_newborn_plate = verdict["newborn_plate"]
	_newborn_sigil = verdict["newborn_sigil"]
	_result_label = verdict["result_label"]
	_again_row = verdict["again_row"]
	_gallows_label = verdict["gallows_label"]
	var actions := LabTableBuildScript.build_actions(self, _root_box)
	_preview_button = actions["preview_button"]
	_commit_button = actions["commit_button"]
	_ritual = actions["ritual"]
	_cycle_timer = actions["cycle_timer"]


func _render_op_row() -> void:
	if _op_row == null:
		return
	_first_op_button = LabTableBuildScript.fill_op_row(self, _op_row, OPS, _op)


func _render_creature_pickers() -> void:
	var party: Array = _party()
	var catalog := _catalog()
	LabTableBuildScript.fill_creature_picker(
		self, _a_picker, party, catalog, _idx_a, "set_creature_a", "A"
	)
	if _b_section != null:
		_b_section.visible = _op == "fuse"
	if _op == "fuse":
		LabTableBuildScript.fill_creature_picker(
			self, _b_picker, party, catalog, _idx_b, "set_creature_b", "B"
		)


func _render_ingredient_picker() -> void:
	if _ingredient_picker == null:
		return
	LabTableBuildScript.fill_reagent_chips(
		self, _ingredient_picker, _eligible_ingredient_stacks(), _rules, _ingredients, _op
	)


## The inventory stacks that may be fed to THIS op: mutate accepts only gene-vials; fuse accepts the
## organ-type ingredients (its optional body parts). The solver still gates legality; this only filters
## the drawer to what the op could plausibly take, so the picker is not a wall of irrelevant parts.
func _eligible_ingredient_stacks() -> Array:
	var out: Array = []
	for it in _inventory().ingredient_items():
		var item: InventoryItem = it
		if _op == "mutate" and item.item_type == "gene":
			out.append(item)
		elif _op == "fuse" and item.item_type != "gene":
			out.append(item)
	return out


# === stage + verdict rendering ================================================================= #


## Aim the staged table at the current selection: plates, donor visibility, conduit legality,
## and the method continuum's jitter/spark/tint scale.
func _update_stage() -> void:
	if _bench_view == null:
		return
	var party: Array = _party()
	var catalog := _catalog()
	var tuple_a: Array = LabLineageScript.creature_tuple(party, _idx_a, catalog)
	var entry_a: Dictionary = {}
	if _idx_a >= 0 and _idx_a < party.size() and party[_idx_a] is Dictionary:
		entry_a = party[_idx_a]
	_bench_view.call("set_subject", entry_a, str(tuple_a[0]) if tuple_a.size() > 0 else "")
	_bench_view.call("set_donor_visible", _op == "fuse")
	if _op == "fuse":
		var tuple_b: Array = LabLineageScript.creature_tuple(party, _idx_b, catalog)
		var entry_b: Dictionary = {}
		if _idx_b >= 0 and _idx_b < party.size() and party[_idx_b] is Dictionary:
			entry_b = party[_idx_b]
		_bench_view.call("set_donor", entry_b, str(tuple_b[0]) if tuple_b.size() > 0 else "")
	_bench_view.call("set_wildness", _method_value)
	_bench_view.call(
		"set_legal", int(_last_verdict.get("verdict", -1)) == LegalitySolverScript.Verdict.LEGAL
	)
	if _method_readout != null:
		_method_readout.text = current_method().capitalize()


## Full verdict repaint: clears the result/newborn/again showcase, then renders the ruling text
## and the taboo pact tint. (The wild flicker re-renders TEXT ONLY via _render_verdict_text.)
func _render_verdict(verdict: Dictionary) -> void:
	if _verdict_label == null:
		return
	_result_label.text = ""
	if _newborn_row != null:
		_newborn_row.visible = false  # a fresh divination clears the last newborn's showcase
	if _again_row != null:
		_again_row.visible = false
	_render_verdict_text(verdict)
	_update_pact_tint(verdict)


## The ruling line + the previewed config summary. At the wild end the summary walks the solver's
## FULL configs array (index _alt_index) — real alternates, cycled at ~8Hz in juice mode.
func _render_verdict_text(verdict: Dictionary) -> void:
	if _verdict_label == null:
		return
	if verdict.is_empty():
		_verdict_label.text = (
			"[color=#%s]Choose your subjects.[/color]"
			% LabVerdictKitScript.parchment_hex(GrimoirePalette.TEXT_MUTED)
		)
		return
	var code := int(verdict.get("verdict", -1))
	var configs: Array = verdict.get("configs", [])
	var idx := 0
	var flicker := current_method() == "wild" and configs.size() > 1
	if flicker:
		idx = _alt_index % configs.size()
	var cfg: Dictionary = configs[idx] if configs.size() > 0 else {}
	var suffix := ""
	if flicker:
		suffix = (
			"\n[color=#%s]the wild way — possibility %d of %d[/color]"
			% [
				LabVerdictKitScript.parchment_hex(GrimoirePalette.TEXT_MUTED),
				idx + 1,
				configs.size()
			]
		)
	match code:
		LegalitySolverScript.Verdict.LEGAL:
			_verdict_label.text = (
				(
					"[color=#%s]LEGAL[/color]\n"
					% LabVerdictKitScript.parchment_hex(GrimoirePalette.SUCCESS)
				)
				+ LabVerdictKitScript.config_summary(cfg)
				+ suffix
			)
		LegalitySolverScript.Verdict.TABOO:
			var reason := str(verdict.get("reason", "this rite is forbidden"))
			var cost := LabVerdictKitScript.cost_summary(verdict.get("unlock_cost", {}))
			_verdict_label.text = (
				"[color=#%s]TABOO[/color]  %s\n%s\n%s"
				% [
					LabVerdictKitScript.parchment_hex(GrimoirePalette.WARNING),
					reason,
					cost,
					LabVerdictKitScript.config_summary(cfg)
				]
			)
		_:
			var why := str(verdict.get("reason", "the flesh refuses"))
			_verdict_label.text = (
				(
					"[color=#%s]ILLEGAL[/color]  "
					% LabVerdictKitScript.parchment_hex(GrimoirePalette.DANGER)
				)
				+ why
			)


## TABOO PACT skin: while the previewed rite is taboo-flagged (or hard-TABOO), the parchment
## bruises — self_modulate shifts through corruption_color (a slow pulse in juice mode).
func _update_pact_tint(verdict: Dictionary) -> void:
	if _verdict_panel == null:
		return
	if _pact_tween != null and _pact_tween.is_valid():
		_pact_tween.kill()
	_pact_tween = null
	var taboo := int(verdict.get("verdict", -1)) == LegalitySolverScript.Verdict.TABOO
	var configs: Array = verdict.get("configs", [])
	if not taboo and configs.size() > 0:
		taboo = bool(
			((configs[0] as Dictionary).get("flags", {}) as Dictionary).get("taboo", false)
		)
	if not taboo:
		_verdict_panel.self_modulate = Color.WHITE
		return
	var low := Color.WHITE.lerp(GrimoirePalette.corruption_color(0.25), 0.3)
	var high := Color.WHITE.lerp(GrimoirePalette.corruption_color(0.9), 0.42)
	_verdict_panel.self_modulate = high
	if _juice_enabled and is_inside_tree():
		_pact_tween = create_tween().set_loops()
		_pact_tween.tween_property(_verdict_panel, "self_modulate", low, 0.9)
		_pact_tween.tween_property(_verdict_panel, "self_modulate", high, 0.9)


# === commit showcase + ledger =================================================================== #


## Render the COMMITTED creature's oracle-reported numbers (forces, tier, BST/HP, and the entropy +
## corruption the oracle charged) plus the newborn LivingPlate + sigil. Every number came BACK from
## the oracle — the screen computed none of it.
func _render_commit(creature: Dictionary, instance: Dictionary = {}) -> void:
	if _result_label == null:
		return
	_render_commit_showcase(creature, instance)
	_result_label.text = (
		LabVerdictKitScript.commit_head(creature)
		+ "\n"
		+ LabVerdictKitScript.ledger_text(creature, 1.0)
	)


## The newborn's plate + one-of-one sigil (Wave 9), shown when a commit lands.
func _render_commit_showcase(creature: Dictionary, instance: Dictionary) -> void:
	if _newborn_row == null or instance.is_empty():
		return
	var tag := PortraitUtil.instance_tag_of(instance)
	_newborn_plate.set_texture(PortraitUtil.creature_plate(instance))
	_newborn_plate.set_tint(PortraitUtil.creature_tint(instance))
	_newborn_plate.set_identity(str(instance.get("species_id", "")), tag)
	_newborn_sigil.call(
		"set_identity", str(instance.get("species_id", "")), tag, str(creature.get("prim", ""))
	)
	_newborn_row.visible = true


# === the reveal (juice mode; <3s; seen-once/held-CONFIRM skippable — tension 10) =============== #


## The newborn reveal: dim -> conduit/vessel surge -> the plate materializes through the dissolve
## hook (1 -> 0) -> the name types on -> the ledger counts up to the oracle's numbers -> Again?/
## Done. Fire-and-forget coroutine; _finish_reveal() is the single (skippable) exit.
func _play_reveal(creature: Dictionary, instance: Dictionary) -> void:
	_reveal_playing = true
	_reveal_creature = creature
	_reveal_instance = instance
	_reveal_tweens.clear()
	_reveal_dim = ColorRect.new()
	_reveal_dim.name = "RevealDim"
	_reveal_dim.color = Color(GrimoirePalette.INK, 0.0)
	_reveal_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_reveal_dim.gui_input.connect(_on_reveal_dim_input)
	add_child(_reveal_dim)
	var tw := create_tween()
	tw.tween_property(_reveal_dim, "color:a", 0.55, 0.25)
	_reveal_tweens.append(tw)
	if _bench_view != null:
		_bench_view.call("surge", 1.0)
	await get_tree().create_timer(0.35).timeout
	if not _reveal_playing:
		return
	# Materialize: the plate burns IN through the dissolve hook while the dim lifts.
	_render_commit_showcase(creature, instance)
	_result_label.text = LabVerdictKitScript.commit_head(creature)
	_result_label.visible_ratio = 0.0
	_newborn_plate.set_dissolve(1.0)
	var tw2 := create_tween()
	tw2.tween_method(_newborn_plate.set_dissolve, 1.0, 0.0, 0.7)
	tw2.parallel().tween_property(_reveal_dim, "color:a", 0.0, 0.7)
	_reveal_tweens.append(tw2)
	await get_tree().create_timer(0.75).timeout
	if not _reveal_playing:
		return
	# The name types on…
	var tw3 := create_tween()
	tw3.tween_property(_result_label, "visible_ratio", 1.0, 0.4)
	_reveal_tweens.append(tw3)
	await get_tree().create_timer(0.45).timeout
	if not _reveal_playing:
		return
	# …and the ledger counts up to the oracle's numbers.
	_result_label.visible_ratio = 1.0
	var tw4 := create_tween()
	tw4.tween_method(_ledger_countup.bind(creature), 0.0, 1.0, 0.5)
	_reveal_tweens.append(tw4)
	await get_tree().create_timer(0.55).timeout
	if not _reveal_playing:
		return
	_finish_reveal()


func _ledger_countup(f: float, creature: Dictionary) -> void:
	if _result_label != null:
		_result_label.text = (
			LabVerdictKitScript.commit_head(creature)
			+ "\n"
			+ LabVerdictKitScript.ledger_text(creature, f)
		)


func _on_reveal_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		_try_skip_reveal()


## Skip rules (tension 10): any input skips once the first-ever reveal has been seen (persisted
## Settings flag); a held CONFIRM fast-forwards even the first one.
func _try_skip_reveal() -> void:
	if not _reveal_playing:
		return
	if _reveal_seen() or _is_confirm_pressed():
		_finish_reveal()


## The single reveal exit: kill the choreography, land the exact end-state (full ledger, whole
## plate, Again?/Done), and latch the seen-once flag.
func _finish_reveal() -> void:
	if not _reveal_playing:
		return
	_reveal_playing = false
	for tw in _reveal_tweens:
		if tw is Tween and (tw as Tween).is_valid():
			(tw as Tween).kill()
	_reveal_tweens.clear()
	if _reveal_dim != null and is_instance_valid(_reveal_dim):
		_reveal_dim.queue_free()
	_reveal_dim = null
	if not _reveal_creature.is_empty():
		_render_commit(_reveal_creature, _reveal_instance)
		_newborn_plate.set_dissolve(0.0)
		_result_label.visible_ratio = 1.0
	_show_again_row()
	_mark_reveal_seen()


func _on_seal_complete() -> void:
	_pact_armed = false
	commit()


func _on_again_pressed() -> void:
	# The newborn is already pre-armed as Subject (commit re-aims the bench) — just fold the
	# showcase away and put the table back in the player's hands.
	if _again_row != null:
		_again_row.visible = false
	refresh()
	_focus_op_row()


func _show_again_row() -> void:
	if _again_row == null:
		return
	_again_row.visible = true
	if _gallows_label != null:
		# Rotating gallows microcopy — the authored lab voice, salted by commit count.
		var line := VoiceBook.pick("lab.reveal", _commit_count)
		if line == "":
			line = VoiceBook.pick("lab.commit", _commit_count)
		_gallows_label.text = line


## Append the pact's arming warning (authored VoiceBook lab.taboo line) to the verdict page.
func _append_pact_warning() -> void:
	if _verdict_label == null:
		return
	var line := VoiceBook.pick("lab.taboo", _commit_count)
	if line == "":
		return
	_verdict_label.text += (
		"\n[color=#%s]%s[/color]"
		% [LabVerdictKitScript.parchment_hex(GrimoirePalette.WARNING), line]
	)


# === juice plumbing ============================================================================ #


func _apply_juice() -> void:
	var on := _juice_override == 1
	if _juice_override == -1:
		on = DisplayServer.get_name() != "headless" and not _reduce_motion()
	_juice_enabled = on
	if _bench_view != null:
		_bench_view.call("set_juice", on)
	if _ritual != null:
		_ritual.call("set_juice", on)
	_update_cycle_timer()


## The wild flicker clock only runs juiced, at the wild end, with real alternates to walk.
func _update_cycle_timer() -> void:
	if _cycle_timer == null or not _cycle_timer.is_inside_tree():
		return
	var configs: Array = _last_verdict.get("configs", [])
	var want := _juice_enabled and current_method() == "wild" and configs.size() > 1
	if want and _cycle_timer.is_stopped():
		_cycle_timer.start()
	elif not want and not _cycle_timer.is_stopped():
		_cycle_timer.stop()


func _reduce_motion() -> bool:
	var settings := get_node_or_null("/root/Settings")
	if settings == null:
		return false
	return bool(settings.call("get_value", "accessibility", "reduce_motion", false))


func _reveal_seen() -> bool:
	var settings := get_node_or_null("/root/Settings")
	if settings == null:
		return false
	return bool(settings.call("get_value", "lab", "reveal_seen", false))


func _mark_reveal_seen() -> void:
	var settings := get_node_or_null("/root/Settings")
	if settings == null:
		return
	if bool(settings.call("get_value", "lab", "reveal_seen", false)):
		return
	settings.call("set_value", "lab", "reveal_seen", true)
	if settings.has_method("save_settings"):
		settings.call("save_settings")


func _is_confirm_pressed() -> bool:
	if _input == null or not _input.has_method("is_pressed"):
		return false
	return bool(_input.call("is_pressed", InputActions.CONFIRM))


## Commit is enabled only when the current preview is LEGAL (and, for a recipe needing parts, the
## drawer has them). A LEGAL-but-taboo rite is a PACT: the verb names its corruption price (the
## oracle's authored constant, DISPLAYED not computed) and arms before it seals.
func _update_commit_enabled() -> void:
	if _commit_button == null:
		return
	var legal := int(_last_verdict.get("verdict", -1)) == LegalitySolverScript.Verdict.LEGAL
	var affordable := bool(_last_verdict.get("ingredients_available", true))
	_commit_button.disabled = not (legal and affordable)
	if legal and pact_required():
		if _pact_armed:
			_commit_button.text = "Seal the Pact"
		else:
			var lab_constants: Dictionary = Constants.BALANCE.get("lab", {})
			_commit_button.text = (
				"Break the Taboo (+%d corruption)" % int(lab_constants.get("taboo_corruption", 0))
			)
	else:
		_commit_button.text = "Splice"
