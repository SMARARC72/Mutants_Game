extends Control
## LabScreen (Phase 5 · Slice 3a) — the playable LAB BENCH for the MVP's two Creator ops: FUSE and
## MUTATE. PRESENTATION layer, CODE-BUILT (a thin .tscn just loads this script) so it is unit-testable
## headless. It is a STANDALONE scene reachable at the fixed path res://presentation/lab/lab_screen.tscn
## (the sibling camp menu navigates here); with an injected GameController (party + inventory) it
## previews + commits with no rendering.
##
## THE BOUNDARY HOLDS (ADR-015): this screen computes NO stat / blend / cost. It only:
##   * resolves the chosen party creature_instance(s) -> the LabBench [name, prim, sec, tier] tuples,
##   * resolves the chosen inventory ingredient(s) -> ingredient-id Strings,
##   * authors a LabRecipe and routes it through LabRecipeBench -> LabBench -> client/domain/lab_engine,
##   * RENDERS the verdict (LEGAL / ILLEGAL(reason) / TABOO(unlock cost)) and the oracle's reported
##     forces / tier / entropy / corruption — every number comes BACK from the oracle, never from here.
## On a LEGAL + affordable/gated COMMIT it debits the consumed parts (the recipe bench does this),
## ADDS the resulting creature to run.party as a creature_instance carrying its splice_config in
## lineage, and saves. A Toast announces the outcome.
##
## creature_instance -> LabBench inputs: a party entry is { species_id, nickname, ... }. We read the
## species row via SpeciesCatalog.get_by_id and build [nickname|name, force_primary, force_secondary,
## tier] — exactly what battle/capture do to go creature_instance -> engine inputs (MonFactory mirror).
## Committed result -> party: the oracle's creature dict { name, prim, sec, tier, stats, hp, bst,
## entropy, corruption, ... } is shaped into a creature_instance with lineage.splice = { op,
## splice_config, parents, rng_seed_tag } so the splice is replayable + auditable.

const SpliceRulesScript := preload("res://infrastructure/lab/splice_rules.gd")
const LabRecipeBenchScript := preload("res://application/lab/lab_recipe_bench.gd")
const LabRecipeScript := preload("res://infrastructure/inventory/lab_recipe.gd")
const LegalitySolverScript := preload("res://infrastructure/lab/legality_solver.gd")
const InputActions := preload("res://infrastructure/input/input_actions.gd")
const OVERWORLD_SCENE := "res://presentation/overworld/overworld_screen.tscn"

## The two MVP ops this bench exposes. (graft/self_splice/reanimate are out of this slice's scope.)
const OPS: Array = ["fuse", "mutate"]

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
var _last_verdict: Dictionary = {}
var _last_commit: Dictionary = {}
var _commit_count: int = 0  # distinguishes successive op_ids within one run (reproducible per index)

## When false, _ready does NOT auto-build (a headless test injects a GameController + drives build()).
var _auto_build: bool = true

# --- UI node handles (code-built; styled via ThemeService) ------------------------------------- #
var _root_box: VBoxContainer = null
var _op_row: HBoxContainer = null
var _a_picker: VBoxContainer = null
var _b_picker: VBoxContainer = null
var _ingredient_picker: VBoxContainer = null
var _b_section: VBoxContainer = null
var _verdict_label: RichTextLabel = null
var _result_label: RichTextLabel = null
var _preview_button: Button = null
var _commit_button: Button = null
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


# === injection seams (tests / non-autoload contexts) ========================================== #


## Inject the GameController. Call BEFORE add_child/build() so injection wins over the autoload.
func set_game(game: Node) -> void:
	_game = game


## Disable the automatic build on _ready (tests drive build() explicitly after configuring a game).
func set_auto_build(enabled: bool) -> void:
	_auto_build = enabled


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
	if _b_section != null:
		_b_section.visible = _op == "fuse"
	refresh()


## Select creature A (fuse host / mutate host) by party index. Refreshes the preview affordances.
func set_creature_a(party_index: int) -> void:
	_idx_a = party_index
	refresh()


## Select the fuse partner B by party index (ignored for mutate). Refreshes the preview affordances.
func set_creature_b(party_index: int) -> void:
	_idx_b = party_index
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
	refresh()


# === preview / commit (route through the boundary; compute NOTHING here) ======================= #


## PREVIEW the current selection via LabRecipeBench (no consumption). Returns the LegalitySolver
## verdict verbatim ({ verdict, reason, unlock_cost, configs, ingredients_available }) and renders it.
## Returns {} when the selection is incomplete (e.g. no creatures chosen / unknown ingredient).
func preview() -> Dictionary:
	if _bench == null:
		return {}
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
		_toast_outcome(result, false)
		return result

	# LEGAL: the oracle already produced the creature; shape it into a party creature_instance and add.
	var creature: Dictionary = result.get("creature", {})
	var instance := _to_creature_instance(creature, result.get("splice_config", {}), op_id)
	if _game.has_method("add_party_member"):
		_game.call("add_party_member", instance)
	if _game.has_method("save_run"):
		_game.call("save_run")
	_render_commit(creature)
	_toast_outcome(result, true)
	refresh()  # the consumed parts are gone — rebuild the ingredient drawer
	return result


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
	var a := _creature_tuple(_idx_a)
	if a.is_empty():
		return null
	if _op == "fuse":
		var b := _creature_tuple(_idx_b)
		if b.is_empty():
			return null
		return LabRecipeScript.new("fuse", a, b, _ingredients.duplicate(), "precise")
	# mutate: one host + the chosen ingredients (a gene-vial). b is unused ([] placeholder).
	return LabRecipeScript.new("mutate", a, [], _ingredients.duplicate(), "precise")


## Map a party creature_instance (by index) into the LabBench tuple [name, prim, sec, tier] by reading
## its species row through the catalog (mirrors MonFactory.from_creature). Returns [] if unresolvable.
func _creature_tuple(party_index: int) -> Array:
	var party: Array = _party()
	if party_index < 0 or party_index >= party.size():
		return []
	var entry: Variant = party[party_index]
	if not (entry is Dictionary):
		return []
	var creature: Dictionary = entry
	var species_id := str(creature.get("species_id", ""))
	var catalog: SpeciesCatalog = _game.call("catalog")
	var species: SpeciesData = catalog.get_by_id(species_id) if catalog != null else null
	if species == null:
		return []
	var display_name := str(creature.get("nickname", ""))
	if display_name == "":
		display_name = species.name
	return [display_name, species.force_primary, species.force_secondary, species.tier]


## Shape the oracle's creature dict into a creature_instance (RunContext.party shape / the
## creature_instances column contract). The oracle's numbers are cached VERBATIM (stats_cached,
## entropy) — this never recomputes them. lineage.splice records provenance so the op is replayable.
func _to_creature_instance(
	creature: Dictionary, splice_config: Dictionary, op_id: String
) -> Dictionary:
	var parents := [_parent_tag(_idx_a)]
	if _op == "fuse":
		parents.append(_parent_tag(_idx_b))
	return {
		"species_id": "",  # a spliced hybrid is not a catalog species — its forces live in lineage
		"nickname": str(creature.get("name", "Splice")),
		"genome": {},
		"expression": 1.0,
		"bond": 0,
		# The oracle's entropy ledger (a number it computed — cached, not recomputed here).
		"entropy": int(creature.get("entropy", 0)),
		"awakenings": 0,
		# The oracle's stat block, cached verbatim (the contamination guard proves equality vs the
		# engine on the same config+seed). prim/sec/tier/hp/bst are carried so the party entry is usable
		# without re-deriving a species row this hybrid does not have.
		"stats_cached":
		{
			"prim": str(creature.get("prim", "")),
			"sec": str(creature.get("sec", "")),
			"tier": str(creature.get("tier", "")),
			"hp": int(creature.get("hp", 0)),
			"bst": int(creature.get("bst", 0)),
			"stats": (creature.get("stats", {}) as Dictionary).duplicate(true),
		},
		"skills": [],
		"status_effects": {},
		"lineage":
		{
			"spliced": true,
			"op": _op,
			"parents": parents,
			"splice_config": splice_config.duplicate(true),
			"rng_seed_tag": op_id,
			"taboo": bool(creature.get("taboo", false)),
		},
		"is_dead": false,
	}


## A compact, non-numeric provenance tag for a parent party creature (for lineage.parents).
func _parent_tag(party_index: int) -> Dictionary:
	var party: Array = _party()
	if party_index < 0 or party_index >= party.size() or not (party[party_index] is Dictionary):
		return {}
	var entry: Dictionary = party[party_index]
	return {
		"species_id": str(entry.get("species_id", "")),
		"nickname": str(entry.get("nickname", "")),
	}


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


func _inventory() -> InventoryAdapter:
	if _game != null and _game.has_method("inventory"):
		return _game.call("inventory")
	return InventoryAdapter.new()


func _player_state() -> Dictionary:
	if _game != null and _game.has_method("lab_player_state"):
		return _game.call("lab_player_state")
	return {"corruption": 0, "unlocks": [], "has_parts": []}


# === UI (minimal, code-built, themed) ========================================================= #


## Re-render the dynamic parts of the bench (op highlight, pickers, live preview) without rebuilding
## the whole tree. Cheap to call after any selection change.
func refresh() -> void:
	if _root_box == null:
		return
	_render_op_row()
	_render_creature_pickers()
	_render_ingredient_picker()
	# A live preview keeps the verdict panel honest with the current selection.
	preview()
	_update_commit_enabled()
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

	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.05, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)

	var box := VBoxContainer.new()
	box.name = "RootBox"
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	_root_box = box

	var title := Label.new()
	title.name = "LabTitle"
	title.text = "The Splicing Bench"
	title.theme_type_variation = "TitleLabel"
	box.add_child(title)

	# The bench stack (rite / subject / donor / reagents) scrolls if it overflows so the
	# verdict panel and the Divine/Splice/Back verbs below stay on-screen at any size.
	var bench_scroll := ScrollContainer.new()
	bench_scroll.name = "BenchScroll"
	bench_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bench_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(bench_scroll)
	var bench_box := VBoxContainer.new()
	bench_box.add_theme_constant_override("separation", 10)
	bench_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bench_scroll.add_child(bench_box)

	# Op selector row (Fuse / Mutate).
	var op_title := Label.new()
	op_title.text = "Rite"
	op_title.theme_type_variation = "MutedLabel"
	bench_box.add_child(op_title)
	_op_row = HBoxContainer.new()
	_op_row.name = "OpRow"
	_op_row.add_theme_constant_override("separation", 8)
	bench_box.add_child(_op_row)

	# Creature A picker (host / first parent).
	var a_title := Label.new()
	a_title.text = "Subject"
	a_title.theme_type_variation = "MutedLabel"
	bench_box.add_child(a_title)
	_a_picker = VBoxContainer.new()
	_a_picker.name = "CreatureAPicker"
	bench_box.add_child(_a_picker)

	# Creature B section (fuse only).
	_b_section = VBoxContainer.new()
	_b_section.name = "CreatureBSection"
	bench_box.add_child(_b_section)
	var b_title := Label.new()
	b_title.text = "Donor"
	b_title.theme_type_variation = "MutedLabel"
	_b_section.add_child(b_title)
	_b_picker = VBoxContainer.new()
	_b_picker.name = "CreatureBPicker"
	_b_section.add_child(_b_picker)
	_b_section.visible = _op == "fuse"

	# Ingredient picker (fuse: optional organs; mutate: a gene-vial).
	var ing_title := Label.new()
	ing_title.text = "Reagents"
	ing_title.theme_type_variation = "MutedLabel"
	bench_box.add_child(ing_title)
	_ingredient_picker = VBoxContainer.new()
	_ingredient_picker.name = "IngredientPicker"
	bench_box.add_child(_ingredient_picker)

	# Verdict + result panels — the oracle's ruling reads as an open grimoire page
	# (ParchmentPanel), so both rich-text readouts flip to ink (TEXT_ON_PARCHMENT).
	var verdict_panel := PanelContainer.new()
	verdict_panel.theme_type_variation = "ParchmentPanel"
	box.add_child(verdict_panel)
	var verdict_box := VBoxContainer.new()
	verdict_panel.add_child(verdict_box)
	_verdict_label = RichTextLabel.new()
	_verdict_label.name = "VerdictLabel"
	_verdict_label.bbcode_enabled = true
	_verdict_label.fit_content = true
	_verdict_label.scroll_active = false
	_verdict_label.custom_minimum_size = Vector2(0, 96)
	_verdict_label.add_theme_color_override("default_color", GrimoirePalette.TEXT_ON_PARCHMENT)
	verdict_box.add_child(_verdict_label)
	_result_label = RichTextLabel.new()
	_result_label.name = "ResultLabel"
	_result_label.bbcode_enabled = true
	_result_label.fit_content = true
	_result_label.scroll_active = false
	_result_label.add_theme_color_override("default_color", GrimoirePalette.TEXT_ON_PARCHMENT)
	verdict_box.add_child(_result_label)

	# Action row: Preview, Commit, Back.
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	box.add_child(actions)
	_preview_button = Button.new()
	_preview_button.name = "PreviewButton"
	_preview_button.text = "Divine"
	_preview_button.pressed.connect(func() -> void: preview())
	actions.add_child(_preview_button)
	_commit_button = Button.new()
	_commit_button.name = "CommitButton"
	_commit_button.text = "Splice"
	_commit_button.pressed.connect(func() -> void: commit())
	actions.add_child(_commit_button)
	var back_button := Button.new()
	back_button.name = "BackButton"
	back_button.text = "Leave the Bench"
	back_button.pressed.connect(return_to_overworld)
	actions.add_child(back_button)


func _render_op_row() -> void:
	if _op_row == null:
		return
	for child in _op_row.get_children():
		child.queue_free()
	_first_op_button = null
	for op in OPS:
		var btn := Button.new()
		btn.name = "Op_" + op
		btn.toggle_mode = true
		btn.button_pressed = op == _op
		btn.text = op.capitalize()
		var chosen: String = op
		btn.pressed.connect(func() -> void: select_op(chosen))
		_op_row.add_child(btn)
		if _first_op_button == null:
			_first_op_button = btn


func _render_creature_pickers() -> void:
	_rebuild_creature_picker(_a_picker, _idx_a, set_creature_a, "A")
	if _b_section != null:
		_b_section.visible = _op == "fuse"
	if _op == "fuse":
		_rebuild_creature_picker(_b_picker, _idx_b, set_creature_b, "B")


func _rebuild_creature_picker(
	container: VBoxContainer, selected_index: int, on_pick: Callable, tag: String
) -> void:
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()
	var party: Array = _party()
	for i in party.size():
		var entry: Variant = party[i]
		if not (entry is Dictionary):
			continue
		var tuple := _creature_tuple(i)
		var label := _tuple_label(entry, tuple)
		var btn := Button.new()
		btn.name = "Pick%s_%d" % [tag, i]
		btn.toggle_mode = true
		btn.button_pressed = i == selected_index
		btn.text = ("• " if i == selected_index else "  ") + label
		var plate := SpeciesArt.plate(str(entry.get("species_id", "")))
		if plate != null:
			btn.icon = plate
			btn.expand_icon = true
			btn.add_theme_constant_override("icon_max_width", 36)
		btn.custom_minimum_size = Vector2(0, 44)
		var idx := i
		btn.pressed.connect(func() -> void: on_pick.call(idx))
		container.add_child(btn)


func _tuple_label(entry: Dictionary, tuple: Array) -> String:
	if tuple.size() >= 4:
		var force: String = str(tuple[1])
		if str(tuple[2]) != "":
			force += "/" + str(tuple[2])
		return "%s — %s %s" % [str(tuple[0]), force, str(tuple[3])]
	# A spliced/unresolvable entry (no catalog row): show its nickname so it is still selectable info.
	return str(entry.get("nickname", "Unknown"))


func _render_ingredient_picker() -> void:
	if _ingredient_picker == null:
		return
	for child in _ingredient_picker.get_children():
		child.queue_free()
	var stacks := _eligible_ingredient_stacks()
	if stacks.is_empty():
		var empty := Label.new()
		empty.name = "NoReagents"
		var what := "gene-vials" if _op == "mutate" else "organs"
		empty.text = "(the drawer holds no %s)" % what
		empty.theme_type_variation = "MutedLabel"
		_ingredient_picker.add_child(empty)
		return
	for stack in stacks:
		var item: InventoryItem = stack
		var btn := Button.new()
		btn.name = "Reagent_" + item.item_key
		btn.toggle_mode = true
		btn.button_pressed = _ingredients.has(item.item_key)
		var mark := "• " if _ingredients.has(item.item_key) else "  "
		btn.text = "%s%s ×%d  (%s)" % [mark, item.item_key, item.qty, item.item_type]
		var key: String = item.item_key
		btn.pressed.connect(func() -> void: toggle_ingredient(key))
		_ingredient_picker.add_child(btn)


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


func _render_verdict(verdict: Dictionary) -> void:
	if _verdict_label == null:
		return
	_result_label.text = ""
	if verdict.is_empty():
		_verdict_label.text = "[color=#9a8fb0]Choose your subjects.[/color]"
		return
	var code := int(verdict.get("verdict", -1))
	var configs: Array = verdict.get("configs", [])
	var cfg: Dictionary = configs[0] if configs.size() > 0 else {}
	match code:
		LegalitySolverScript.Verdict.LEGAL:
			_verdict_label.text = "[color=#8cd96f]LEGAL[/color]\n" + _config_summary(cfg)
		LegalitySolverScript.Verdict.TABOO:
			var reason := str(verdict.get("reason", "this rite is forbidden"))
			var cost := _cost_summary(verdict.get("unlock_cost", {}))
			_verdict_label.text = (
				"[color=#d9a86f]TABOO[/color]  %s\n%s\n%s" % [reason, cost, _config_summary(cfg)]
			)
		_:
			var why := str(verdict.get("reason", "the flesh refuses"))
			_verdict_label.text = "[color=#d96f6f]ILLEGAL[/color]  " + why


## A non-numeric-source summary of the candidate config's forces/tier (the oracle reports the final
## numbers on commit; the config carries force_intent + tier_target the CSP resolved). The entropy /
## corruption COST is shown from the oracle on commit (preview has no roll); here we surface the
## resolved force/tier the splice would carry so the player sees the shape of the outcome.
func _config_summary(cfg: Dictionary) -> String:
	if cfg.is_empty():
		return ""
	var fi: Array = cfg.get("force_intent", [])
	var force := ""
	if fi.size() >= 1:
		force = str(fi[0])
		if fi.size() >= 2 and str(fi[1]) != "":
			force += "/" + str(fi[1])
	var tier := str(cfg.get("tier_target", ""))
	var cls := str(cfg.get("class_target", ""))
	return (
		"[color=#c7bce0]forces[/color] %s   [color=#c7bce0]tier[/color] %s   [color=#c7bce0]class[/color] %s"
		% [force, tier, cls]
	)


func _cost_summary(cost: Dictionary) -> String:
	if cost.is_empty():
		return ""
	var parts: Array = []
	if cost.has("corruption_min"):
		parts.append("corruption ≥ %d" % int(cost["corruption_min"]))
	if cost.has("unlock"):
		parts.append("the %s rite" % str(cost["unlock"]))
	if cost.has("part"):
		parts.append("a %s" % str(cost["part"]))
	return (
		"[color=#d9a86f]unlock cost:[/color] "
		+ ", ".join(PackedStringArray(parts.map(func(s: Variant) -> String: return str(s))))
	)


## Render the COMMITTED creature's oracle-reported numbers (forces, tier, BST/HP, and the entropy +
## corruption the oracle charged). Every number here came BACK from the oracle — the screen computed
## none of it (the contamination guard proves it equals the engine on the same config+seed).
func _render_commit(creature: Dictionary) -> void:
	if _result_label == null:
		return
	var force := str(creature.get("prim", ""))
	if str(creature.get("sec", "")) != "":
		force += "/" + str(creature.get("sec", ""))
	var head := (
		"[color=#8cd96f]Spliced:[/color] %s  —  %s %s"
		% [str(creature.get("name", "")), force, str(creature.get("tier", ""))]
	)
	var ledger := (
		"[color=#c7bce0]HP[/color] %d   [color=#c7bce0]BST[/color] %d   "
		+ "[color=#c7bce0]entropy[/color] %d   [color=#c7bce0]corruption[/color] %d"
	)
	ledger = (
		ledger
		% [
			int(creature.get("hp", 0)),
			int(creature.get("bst", 0)),
			int(creature.get("entropy", 0)),
			int(creature.get("corruption", 0)),
		]
	)
	_result_label.text = head + "\n" + ledger


## Commit is enabled only when the current preview is LEGAL (and, for a recipe needing parts, the
## drawer has them — the recipe bench re-checks affordability, but the button reflects it up front).
func _update_commit_enabled() -> void:
	if _commit_button == null:
		return
	var legal := int(_last_verdict.get("verdict", -1)) == LegalitySolverScript.Verdict.LEGAL
	var affordable := bool(_last_verdict.get("ingredients_available", true))
	_commit_button.disabled = not (legal and affordable)


func _toast_outcome(result: Dictionary, success: bool) -> void:
	var toast := get_node_or_null("/root/Toast")
	if toast == null or not toast.has_method("show"):
		return
	if success:
		var creature: Dictionary = result.get("creature", {})
		(
			toast
			. call(
				"show",
				{
					"title": "A new horror draws breath",
					"body": str(creature.get("name", "")),
					"sound": "wet",
				}
			)
		)
	else:
		(
			toast
			. call(
				"show",
				{
					"title": "The rite recoils",
					"body": str(result.get("reason", "the flesh refuses")),
					"sound": "toll",
				}
			)
		)
