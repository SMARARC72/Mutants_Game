extends Control
## LabBenchView (Wave 15 — "The Living Creation Table") — the STAGED TABLE the splicing bench
## reads as: subject/donor LivingPlates on PlatePanel frames flanking a central code-drawn
## bubbling VESSEL, with Line2D conduits subject -> vessel <- donor that PULSE while the previewed
## rite is LEGAL. PRESENTATION ONLY (ADR-015): this class renders identity and mood — it never
## sees, stores or computes a stat. The method continuum is presentation too: set_wildness()
## scales bench jitter, bubble emission and the vessel's corruption tint while the ENGINE stays
## binary precise/wild upstream.
##
## HEADLESS/reduce_motion (the battle_beats pattern): set_juice(false) keeps everything static —
## no _process, no particle emission, no jitter — so the suites never run per-frame work. All
## motion is deterministic sine wobble (no RNG at all); colors come from GrimoirePalette only.
##
## Also home to the Wave 15 STATIC dressers the screen calls per refresh: painterly op/reagent
## icons, ingredient_compat hover tooltips (verbatim splice_rules.json data), and the read-only
## Forbidden Ladder rail (graft/self_splice/reanimate gates vs the run's corruption/unlocks —
## flavor only; those ops stay out of scope).

const PLATE_SIZE := Vector2(104, 104)
const STAGE_HEIGHT := 196.0
const JITTER_MAX := 2.4  # px of bench tremble at full wild
const CONDUIT_WIDTH := 3.0
const LADDER_OPS: Array = ["graft", "self_splice", "reanimate"]

const OP_ICONS := {
	"fuse": "res://assets/icons/painterly/lab_verbs/ICON-034_fuse.png",
	"mutate": "res://assets/icons/painterly/lab_verbs/ICON-033_mutate.png",
}
const FORCE_ICONS := {
	"Gaia": "res://assets/icons/painterly/forces/ICON-001_gaia-force.png",
	"Ouranos": "res://assets/icons/painterly/forces/ICON-002_ouranos-force.png",
	"Cosmos": "res://assets/icons/painterly/forces/ICON-003_cosmos-force.png",
	"Chaos": "res://assets/icons/painterly/forces/ICON-004_chaos-force.png",
	"Eros": "res://assets/icons/painterly/forces/ICON-005_eros-force.png",
	"Thanatos": "res://assets/icons/painterly/forces/ICON-006_thanatos-force.png",
}

var _row: HBoxContainer = null
var _subject_col: VBoxContainer = null
var _donor_col: VBoxContainer = null
var _subject_plate: LivingPlate = null
var _donor_plate: LivingPlate = null
var _subject_name: Label = null
var _donor_name: Label = null
var _vessel: Vessel = null
var _conduit_a: Line2D = null
var _conduit_b: Line2D = null
var _base_pos: Dictionary = {}  # column -> layout position (jitter oscillates around it)
var _wildness := 0.0
var _legal := false
var _juice := false
var _surge := 0.0  # reveal-time conduit/bubble swell, decays in _process
var _time := 0.0


static func clear_runtime_cache() -> void:
	Vessel._bubble_gradient = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, STAGE_HEIGHT)
	# Conduits FIRST so they render under the plate panels and the vessel glass.
	_conduit_a = _make_conduit("ConduitSubject")
	add_child(_conduit_a)
	_conduit_b = _make_conduit("ConduitDonor")
	add_child(_conduit_b)
	_row = HBoxContainer.new()
	_row.name = "StageRow"
	_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 26)
	add_child(_row)
	var subject := _make_plate_column("Subject")
	_subject_col = subject["column"]
	_subject_plate = subject["plate"]
	_subject_name = subject["name"]
	_row.add_child(_subject_col)
	_vessel = Vessel.new()
	_vessel.name = "Vessel"
	_row.add_child(_vessel)
	var donor := _make_plate_column("Donor")
	_donor_col = donor["column"]
	_donor_plate = donor["plate"]
	_donor_name = donor["name"]
	_row.add_child(_donor_col)
	_row.sort_children.connect(_on_row_sorted)
	set_process(false)


# === screen-facing state (identity + mood; never numbers) ====================================== #


## Show the chosen SUBJECT on the left plate. `entry` is the party creature_instance ({} clears);
## `display_name` is the resolved bench-tuple name (nickname | species | "").
func set_subject(entry: Dictionary, display_name: String) -> void:
	_dress_plate(_subject_plate, _subject_name, entry, display_name)


## Show the chosen DONOR on the right plate (fuse only — see set_donor_visible).
func set_donor(entry: Dictionary, display_name: String) -> void:
	_dress_plate(_donor_plate, _donor_name, entry, display_name)


## Hide the donor column + its conduit for single-creature rites (mutate).
func set_donor_visible(on: bool) -> void:
	if _donor_col != null:
		_donor_col.visible = on
	if _conduit_b != null:
		_conduit_b.visible = on
	call_deferred("_update_conduits")


## The method continuum, 0 = precise .. 1 = wild — PRESENTATION ONLY (the recipe upstream stays
## binary). Scales bench jitter, bubble emission and the vessel's corruption tint.
func set_wildness(v: float) -> void:
	_wildness = clampf(v, 0.0, 1.0)
	if _vessel == null:
		return
	_vessel.fluid = GrimoirePalette.VERDANT_DIM.lerp(
		GrimoirePalette.corruption_color(_wildness), _wildness * 0.85
	)
	_vessel.boil = _wildness
	var bubbles := _vessel.bubbles
	var want := 6 + int(round(_wildness * 22.0))
	if bubbles.amount != want:
		bubbles.amount = want
	bubbles.speed_scale = 1.0 + _wildness * 1.4
	_vessel.queue_redraw()


## Whether the CURRENT preview is LEGAL — legal conduits burn lit brass (and pulse when juiced);
## anything else dims them to cold slack lines.
func set_legal(legal: bool) -> void:
	_legal = legal
	for line in [_conduit_a, _conduit_b]:
		if line == null:
			continue
		line.default_color = (
			GrimoirePalette.BRASS_BRIGHT if legal else Color(GrimoirePalette.TEXT_MUTED, 0.45)
		)
		line.width = CONDUIT_WIDTH


## Enable/disable the living layer (jitter, conduit pulse, bubbling). false = fully static
## (headless / reduce_motion / tests) — zero per-frame work.
func set_juice(on: bool) -> void:
	_juice = on
	set_process(on)
	if _vessel != null:
		_vessel.bubbles.emitting = on
	if not on:
		_restore_base_positions()


## Reveal-time conduit/bubble SURGE (the commit rush). Decays over ~0.6s; no-op unjuiced.
func surge(strength: float = 1.0) -> void:
	if not _juice:
		return
	_surge = maxf(_surge, clampf(strength, 0.0, 1.0))


# === static dressers (screen calls these per refresh) ========================================== #


## The painterly rite icon for an op button ("fuse"/"mutate"), or null.
static func op_icon(op: String) -> Texture2D:
	var path := str(OP_ICONS.get(op, ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path)


## The painterly force icon matching a reagent's PRIMARY compat force, or null. (Only stamped
## where a painterly icon actually matches — no invented art.)
static func reagent_icon(spec: Dictionary) -> Texture2D:
	var forces: Array = spec.get("forces", [])
	if forces.is_empty():
		return null
	var path := str(FORCE_ICONS.get(str(forces[0]), ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path)


## The ingredient_compat/gene_compat hover tooltip for a reagent chip — VERBATIM rules data
## (slot/forces/class/rank/conflicts), never a computed number.
static func reagent_tooltip(item_key: String, spec: Dictionary) -> String:
	if spec.is_empty():
		return item_key.replace("_", " ")
	var bits: Array = []
	if spec.has("slot"):
		bits.append("slot: %s" % str(spec["slot"]))
	var forces: Array = spec.get("forces", [])
	if not forces.is_empty():
		bits.append("forces: %s" % _join(forces, " / "))
	var classes: Array = spec.get("class", [])
	if not classes.is_empty():
		bits.append("class: %s" % _join(classes, " / "))
	if spec.has("rank"):
		bits.append("rank: %s" % str(spec["rank"]))
	var conflicts: Array = spec.get("conflicts_with", [])
	if not conflicts.is_empty():
		bits.append("conflicts with %s" % _join(conflicts, ", "))
	if bool(spec.get("raises_tier", false)):
		bits.append("raises the tier ceiling")
	return "%s — %s" % [item_key.replace("_", " "), " · ".join(PackedStringArray(bits))]


## (Re)fill the Forbidden Ladder rail: the three out-of-scope rites (graft/self_splice/reanimate)
## with a lock glyph vs their splice_rules.json gates against the RUN's corruption/unlocks.
## READ-ONLY FLAVOR — display comparisons only, the ops themselves stay unreachable this pass.
static func fill_ladder(rail: VBoxContainer, rules: SpliceRules, player_state: Dictionary) -> void:
	if rail == null or rules == null:
		return
	for child in rail.get_children():
		child.queue_free()
	var title := Label.new()
	title.name = "LadderTitle"
	title.text = "The Forbidden Ladder"
	title.theme_type_variation = "MutedLabel"
	rail.add_child(title)
	var corruption := int(player_state.get("corruption", 0))
	var unlocks: Array = player_state.get("unlocks", [])
	for op in LADDER_OPS:
		var gate: Dictionary = rules.operation(op).get("taboo_when", {}).get("gate", {})
		var met := _gate_met_display(rules, gate, corruption, unlocks)
		var row := HBoxContainer.new()
		row.name = "Ladder_" + str(op)
		row.add_theme_constant_override("separation", 8)
		var lock := LockGlyph.new()
		lock.name = "Lock_" + str(op)
		lock.locked = not met
		row.add_child(lock)
		var text_box := VBoxContainer.new()
		text_box.add_theme_constant_override("separation", 0)
		var name_label := Label.new()
		name_label.text = str(op).capitalize()
		text_box.add_child(name_label)
		var gate_label := Label.new()
		gate_label.text = _gate_text(rules, gate)
		gate_label.theme_type_variation = "MutedLabel"
		gate_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		gate_label.custom_minimum_size = Vector2(190, 0)
		text_box.add_child(gate_label)
		row.add_child(text_box)
		rail.add_child(row)


# === internals ================================================================================= #


func _process(delta: float) -> void:
	_time += delta
	_surge = maxf(0.0, _surge - delta * 1.7)
	# Bench jitter: deterministic sine tremble around the container's layout positions.
	var amp := JITTER_MAX * _wildness + _surge * 1.5
	if amp > 0.01:
		var i := 0
		for col in [_subject_col, _donor_col]:
			i += 1
			if col == null or not _base_pos.has(col):
				continue
			var base: Vector2 = _base_pos[col]
			col.position = (
				base + Vector2(sin(_time * 21.0 + i * 2.1), cos(_time * 17.0 + i * 1.3)) * amp
			)
	else:
		_restore_base_positions()
	# Conduit pulse: legal rites throb; a surge swells everything briefly.
	var pulse := 1.0
	if _legal:
		pulse += 0.45 * (0.5 + 0.5 * sin(_time * 6.4))
	pulse += _surge * 1.6
	for line in [_conduit_a, _conduit_b]:
		if line != null:
			line.width = CONDUIT_WIDTH * pulse
	if _vessel != null:
		_vessel.phase = _time
		_vessel.bubbles.speed_scale = 1.0 + _wildness * 1.4 + _surge * 2.0
		_vessel.queue_redraw()
	_update_conduits()


func _on_row_sorted() -> void:
	for col in [_subject_col, _donor_col]:
		if col != null:
			_base_pos[col] = col.position
	_update_conduits()


func _restore_base_positions() -> void:
	for col in [_subject_col, _donor_col]:
		if col != null and _base_pos.has(col):
			col.position = _base_pos[col]


## Re-aim the conduit endpoints (plate panel edge -> vessel heart) from live rects. Cheap: two
## 2-point lines. Valid only in-tree (bare instances keep their empty default points).
func _update_conduits() -> void:
	if not is_inside_tree() or _vessel == null:
		return
	var inv := get_global_transform().affine_inverse()
	var vessel_heart: Vector2 = inv * _vessel.get_global_rect().get_center()
	if _subject_plate != null:
		var a: Vector2 = inv * _subject_plate.get_global_rect().get_center()
		_conduit_a.points = PackedVector2Array([a, vessel_heart])
	if _donor_plate != null and _donor_col != null and _donor_col.visible:
		var b: Vector2 = inv * _donor_plate.get_global_rect().get_center()
		_conduit_b.points = PackedVector2Array([b, vessel_heart])


func _make_conduit(conduit_name: String) -> Line2D:
	var line := Line2D.new()
	line.name = conduit_name
	line.width = CONDUIT_WIDTH
	line.default_color = Color(GrimoirePalette.TEXT_MUTED, 0.45)
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	return line


## One flank of the table: a PlatePanel-framed LivingPlate over its name + role captions.
func _make_plate_column(role: String) -> Dictionary:
	var column := VBoxContainer.new()
	column.name = role + "Column"
	column.add_theme_constant_override("separation", 4)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	var panel := PanelContainer.new()
	panel.name = role + "Frame"
	panel.theme_type_variation = "PlatePanel"
	var plate := LivingPlate.new()
	plate.name = role + "Plate"
	plate.set_plate_size(PLATE_SIZE)
	panel.add_child(plate)
	column.add_child(panel)
	var name_label := Label.new()
	name_label.name = role + "Name"
	name_label.text = "—"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(name_label)
	var caption := Label.new()
	caption.text = role
	caption.theme_type_variation = "MutedLabel"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(caption)
	return {"column": column, "plate": plate, "name": name_label}


func _dress_plate(
	plate: LivingPlate, name_label: Label, entry: Dictionary, display_name: String
) -> void:
	if plate == null:
		return
	if entry.is_empty():
		plate.set_texture(null)
		name_label.text = "—"
	else:
		plate.set_texture(PortraitUtil.creature_plate(entry))
		plate.set_tint(PortraitUtil.creature_tint(entry))
		plate.set_identity(str(entry.get("species_id", "")), PortraitUtil.instance_tag_of(entry))
		name_label.text = display_name if display_name != "" else str(entry.get("nickname", "?"))
	call_deferred("_update_conduits")


static func _join(values: Array, sep: String) -> String:
	var out: Array = []
	for v in values:
		out.append(str(v))
	return sep.join(PackedStringArray(out))


## The gate's requirements as authored data ("corruption ≥ 70 · a god core") — mirrors the
## solver's own cost summary vocabulary, sourced from the SAME rules JSON.
static func _gate_text(rules: SpliceRules, gate: Dictionary) -> String:
	var bits: Array = []
	if gate.has("corruption"):
		bits.append("corruption ≥ %d" % rules.threshold(str(gate["corruption"])))
	if gate.has("or_unlock"):
		bits.append("or the %s rite" % str(gate["or_unlock"]).replace("_", " "))
	if gate.has("requires_unlock"):
		bits.append("the %s rite" % str(gate["requires_unlock"]).replace("_", " "))
	if gate.has("requires_part"):
		bits.append("a %s" % str(gate["requires_part"]).replace("_", " "))
	if gate.has("requires_part_any"):
		var parts: Array = gate["requires_part_any"]
		bits.append("a %s" % _join(parts, " or "))
	if bits.is_empty():
		return "forbidden"
	return " · ".join(PackedStringArray(bits))


## DISPLAY-ONLY lock read: corruption/unlock thresholds vs the run (parts ownership is not
## tracked here — the solver remains the sole authority when these ops ever go live).
static func _gate_met_display(
	rules: SpliceRules, gate: Dictionary, corruption: int, unlocks: Array
) -> bool:
	if gate.has("corruption") and corruption < rules.threshold(str(gate["corruption"])):
		if not (gate.has("or_unlock") and unlocks.has(gate["or_unlock"])):
			return false
	if gate.has("requires_unlock") and not unlocks.has(gate["requires_unlock"]):
		return false
	return true


class Vessel:
	extends Control
	## The central flask: layered code-drawn circles (ink backing, glass, fluid, rim highlights)
	## with a CPUParticles2D bubble column. `fluid`/`boil` scale with the method continuum;
	## `phase` animates the wobble (juice mode only — static at phase 0 headless).

	## Soft radial dot every vessel's bubbles share (built once — no set_pixel synthesis).
	static var _bubble_gradient: GradientTexture2D = null

	var fluid: Color = GrimoirePalette.VERDANT_DIM
	var boil := 0.0
	var phase := 0.0
	var bubbles: CPUParticles2D = null

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(120, 156)
		bubbles = CPUParticles2D.new()
		bubbles.name = "Bubbles"
		bubbles.emitting = false
		bubbles.amount = 6
		bubbles.lifetime = 1.4
		bubbles.direction = Vector2.UP
		bubbles.spread = 20.0
		bubbles.gravity = Vector2(0, -70)
		bubbles.initial_velocity_min = 8.0
		bubbles.initial_velocity_max = 22.0
		bubbles.scale_amount_min = 0.35
		bubbles.scale_amount_max = 1.1
		bubbles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		bubbles.emission_sphere_radius = 13.0
		bubbles.texture = _shared_bubble_texture()
		bubbles.color = Color(GrimoirePalette.OURANOS, 0.5)
		add_child(bubbles)
		resized.connect(_relayout)

	static func _shared_bubble_texture() -> GradientTexture2D:
		if _bubble_gradient == null:
			var grad := Gradient.new()
			grad.set_color(0, Color(1, 1, 1, 0.9))
			grad.set_color(1, Color(1, 1, 1, 0.0))
			_bubble_gradient = GradientTexture2D.new()
			_bubble_gradient.gradient = grad
			_bubble_gradient.width = 16
			_bubble_gradient.height = 16
			_bubble_gradient.fill = GradientTexture2D.FILL_RADIAL
			_bubble_gradient.fill_from = Vector2(0.5, 0.5)
			_bubble_gradient.fill_to = Vector2(1.0, 0.5)
		return _bubble_gradient

	func _relayout() -> void:
		bubbles.position = _bulb_center()

	func _bulb_center() -> Vector2:
		return Vector2(size.x * 0.5, size.y * 0.62)

	func _bulb_radius() -> float:
		return minf(size.x, size.y) * 0.34

	func _draw() -> void:
		var bulb := _bulb_center()
		var r := _bulb_radius()
		if r <= 2.0:
			return
		var glass := Color(GrimoirePalette.OURANOS, 0.16)
		# Ink backing plate, glass bulb, then the living fluid (wobbles when boiling).
		draw_circle(bulb, r + 4.0, GrimoirePalette.INK_PANEL)
		draw_circle(bulb, r, glass)
		var wobble := sin(phase * 7.0) * boil * 2.0
		draw_circle(bulb, r * 0.8 + wobble, Color(fluid, 0.85))
		# Neck + brass rim.
		var neck_w := r * 0.52
		var neck_h := r * 0.75
		var neck := Rect2(bulb.x - neck_w * 0.5, bulb.y - r - neck_h + 4.0, neck_w, neck_h)
		draw_rect(neck, glass)
		draw_arc(
			Vector2(bulb.x, neck.position.y), neck_w * 0.62, PI, TAU, 16, GrimoirePalette.BRASS, 2.0
		)
		# Glass highlight + three slow in-fluid bubbles (static charm at phase 0).
		draw_arc(bulb, r * 0.86, -2.5, -1.3, 12, Color(1, 1, 1, 0.16), 2.0)
		for i in 3:
			var t := fposmod(phase * (0.35 + 0.11 * i) + i * 0.37, 1.0)
			var bub := bulb + Vector2((i - 1) * r * 0.3, r * 0.55 - t * r * 1.1)
			draw_circle(bub, 2.0 + float(i) * 0.8, Color(GrimoirePalette.OURANOS, 0.35 * (1.0 - t)))


class LockGlyph:
	extends Control
	## A tiny drawn padlock for the Forbidden Ladder — closed+muted while the gate is unmet,
	## open+brass once the run qualifies. Palette colors only; no bitmap.

	var locked := true

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(18, 20)
		size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	func _draw() -> void:
		var color := GrimoirePalette.TEXT_MUTED if locked else GrimoirePalette.BRASS_BRIGHT
		var body := Rect2(3, 10, 12, 8)
		draw_rect(body, color)
		var hinge := Vector2(9, 10)
		if locked:
			draw_arc(hinge, 4.5, PI, TAU, 10, color, 2.0)
		else:
			# Sprung shackle: swung up-right off the body.
			draw_arc(Vector2(12, 8), 4.5, PI * 0.9, TAU * 0.86, 10, color, 2.0)
