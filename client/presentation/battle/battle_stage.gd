extends Control
## BattleStage (Wave 10 — "Battle Stage & Impact", PR-1) — the ARENA layer between the flat void
## and the vignette/HUD: the painterly backdrop, TWO staged LivingPlates (the active player
## creature bottom-left, the targeted/acting enemy top-right, ~2.6x the old card slot) and the
## boss dressing (Cinzel name splash + a full-width boss HP bar). The card LISTS keep the HAWKING
## legibility read; this layer is the spectacle — plates swap to follow whoever acts (the screen
## routes every beat's actor through stage_side()).
##
## PRESENTATION layer, code-built (the battle screen is code-built + headless-tested). INSTANT /
## headless contract (the battle_beats pattern): `instant` swaps plate textures with NO tweens and
## the boss splash never animates (built, text set, hidden at once), so every synchronous suite
## stays green. Reveals >0.4s honor held-CONFIRM dismissal (plan tension 10): the screen polls
## splash_active() each frame and calls dismiss_splash().

const BattleCardKitScript := preload("res://presentation/battle/battle_card_kit.gd")

const PLATE_SIZE := Vector2(232, 232)  # ~2.6x the 88px slot the pre-stage cards used
const PLATE_SIDE_MARGIN := 56.0
const PLAYER_BOTTOM_MARGIN := 200.0  # clears the bottom action verbs (menu + utility rows)
const ENEMY_TOP_MARGIN := 88.0  # clears the banner/turn strip (and the boss bar above it)
const SIGIL_PX := 26  # the one-of-one mark scales up with the plate (cards carry 16px)
const ACTING_OUTLINE := 2.5  # texels of brass outline on the acting creature (Wave 10 impact)
const SPLASH_FADE_IN := 0.25
const SPLASH_HOLD := 1.1
const SPLASH_FADE_OUT := 0.45

var _plates: Dictionary = {}  # is_enemy (bool) -> LivingPlate
var _actors: Dictionary = {}  # is_enemy (bool) -> AbilityContainer currently staged
var _instant := true
var _splash: Control = null
var _splash_name: Label = null
var _splash_line: Label = null
var _splash_tween: Tween = null
var _boss_bar: ProgressBar = null
var _boss_label: Label = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## Build the arena once: backdrop (null leaves the screen's flat void), the two stage plates,
## and — boss battles only — the full-width HP bar + the name-splash overlay.
func build(backdrop: Texture2D, is_boss: bool, instant: bool) -> void:
	_instant = instant
	if backdrop != null:
		var arena := TextureRect.new()
		arena.name = "ArenaBackdrop"
		arena.texture = backdrop
		arena.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		arena.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		arena.set_anchors_preset(Control.PRESET_FULL_RECT)
		arena.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(arena)
	_plates[false] = _make_plate(false)
	_plates[true] = _make_plate(true)
	if is_boss:
		_build_boss_bar()
		_build_splash()


# === staged plates ============================================================================= #


## Swap one side's stage plate to `ac` (no-op when it is already staged there). `source` is the
## portrait source dict (a run.party creature or {"species_id": id}); `tag` the per-instance
## identity for phase/sigil hashing; `force` the accent for the sigil stamp. Resets the material
## hooks (flash/dissolve/outline) so a previous occupant's death state never leaks onto the next.
func stage_side(
	is_enemy: bool, ac: AbilityContainer, source: Dictionary, tag: String, force: String
) -> void:
	var plate := _plates.get(is_enemy) as LivingPlate
	if plate == null or ac == null or _actors.get(is_enemy) == ac:
		return
	_actors[is_enemy] = ac
	plate.set_texture(PortraitUtil.creature_plate(source))
	plate.set_tint(PortraitUtil.creature_tint(source))
	plate.set_identity(str(source.get("species_id", "")), tag)
	plate.set_hit_flash(0.0)
	plate.set_dissolve(0.0)
	plate.set_outline(0.0)
	PortraitUtil.stamp_sigil(plate, source, force, SIGIL_PX, tag)


## The combatant currently staged on a side (null before the first stage_side call).
func shown_actor(is_enemy: bool) -> Variant:
	return _actors.get(is_enemy, null)


## One side's stage plate (the Wave 10 impact stack drives its material hooks).
func plate(is_enemy: bool) -> LivingPlate:
	return _plates.get(is_enemy) as LivingPlate


## The stage plate showing `actor` right now, or null when it is not staged on either side.
func plate_of(actor: Variant) -> LivingPlate:
	for is_enemy in [false, true]:
		if _actors.get(is_enemy) == actor:
			return _plates.get(is_enemy) as LivingPlate
	return null


## Outline the plate showing `actor` in lit brass (the who-acts read, Wave 10 impact stack) and
## clear the other side. `null` clears both. A pure shader-uniform write — headless-safe.
func set_acting(actor: Variant) -> void:
	for is_enemy in [false, true]:
		var plate := _plates.get(is_enemy) as LivingPlate
		if plate == null:
			continue
		var on: bool = actor != null and _actors.get(is_enemy) == actor
		plate.set_outline(ACTING_OUTLINE if on else 0.0)


## The lunge for `actor`'s staged plate: {"plate": LivingPlate, "dir": Vector2 toward the OTHER
## side's plate} — {} when the actor is not staged. JuiceDirector consumes this (attack beat).
func lunge_of(actor: Variant) -> Dictionary:
	for is_enemy in [false, true]:
		if actor == null or _actors.get(is_enemy) != actor:
			continue
		var plate := _plates.get(is_enemy) as LivingPlate
		var other := _plates.get(not is_enemy) as LivingPlate
		if plate == null or other == null:
			return {}
		var dir: Vector2 = (other.position + other.size * 0.5) - (plate.position + plate.size * 0.5)
		return {"plate": plate, "dir": dir}
	return {}


# === boss dressing ============================================================================= #


## Refresh the full-width boss HP bar from the live enemy team (sum across the boss side, so a
## boss with adds still reads as one threat bar). No-op in non-boss battles.
func update_boss(enemy_team: Array) -> void:
	if _boss_bar == null:
		return
	var hp := 0
	var max_hp := 0
	for ac_v in enemy_team:
		var ac := ac_v as AbilityContainer
		hp += maxi(0, ac.hp())
		max_hp += ac.max_hp()
	_boss_bar.max_value = maxi(1, max_hp)
	_boss_bar.value = hp
	BattleCardKitScript.style_hp_bar(_boss_bar)
	if _boss_label != null and not enemy_team.is_empty():
		_boss_label.text = (enemy_team[0] as AbilityContainer).combatant_name()


## Splash the boss name (Cinzel via the TitleLabel variation) + an optional authored line.
## Instant mode: text lands but the overlay stays hidden (headless suites never wait). Animated:
## fade in → hold → fade out (~1.8s), dismissable any moment via dismiss_splash().
func show_boss_splash(boss_name: String, line: String = "") -> void:
	if _splash == null:
		return
	_splash_name.text = boss_name
	_splash_line.text = line
	_splash_line.visible = line != ""
	if _instant:
		_splash.visible = false
		return
	_splash.visible = true
	_splash.modulate = Color(1, 1, 1, 0)
	_splash_tween = create_tween()
	_splash_tween.tween_property(_splash, "modulate:a", 1.0, SPLASH_FADE_IN)
	_splash_tween.tween_interval(SPLASH_HOLD)
	_splash_tween.tween_property(_splash, "modulate:a", 0.0, SPLASH_FADE_OUT)
	_splash_tween.tween_callback(func() -> void: _splash.visible = false)


## True while the splash overlay is on screen (the screen's CONFIRM poll gates on this).
func splash_active() -> bool:
	return _splash != null and _splash.visible


## Hide the splash immediately (held-CONFIRM skip — never-wait-twice, tension 10).
func dismiss_splash() -> void:
	if _splash_tween != null and _splash_tween.is_valid():
		_splash_tween.kill()
	if _splash != null:
		_splash.visible = false


# === internals ================================================================================= #


func _make_plate(is_enemy: bool) -> LivingPlate:
	var plate := LivingPlate.new()
	plate.name = "EnemyStagePlate" if is_enemy else "PlayerStagePlate"
	plate.set_plate_size(PLATE_SIZE)
	if is_enemy:
		plate.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		plate.offset_left = -PLATE_SIDE_MARGIN - PLATE_SIZE.x
		plate.offset_right = -PLATE_SIDE_MARGIN
		plate.offset_top = ENEMY_TOP_MARGIN
		plate.offset_bottom = ENEMY_TOP_MARGIN + PLATE_SIZE.y
	else:
		plate.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		plate.offset_left = PLATE_SIDE_MARGIN
		plate.offset_right = PLATE_SIDE_MARGIN + PLATE_SIZE.x
		plate.offset_bottom = -PLAYER_BOTTOM_MARGIN
		plate.offset_top = -PLAYER_BOTTOM_MARGIN - PLATE_SIZE.y
	add_child(plate)
	return plate


func _build_boss_bar() -> void:
	var panel := PanelContainer.new()
	panel.name = "BossBarPanel"
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left = 16.0
	panel.offset_right = -16.0
	panel.offset_top = 8.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	_boss_label = Label.new()
	_boss_label.name = "BossName"
	_boss_label.theme_type_variation = "TitleLabel"
	row.add_child(_boss_label)
	_boss_bar = ProgressBar.new()
	_boss_bar.name = "BossBar"
	_boss_bar.show_percentage = false
	_boss_bar.custom_minimum_size = Vector2(0, 18)
	_boss_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_boss_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_boss_bar)


func _build_splash() -> void:
	_splash = CenterContainer.new()
	_splash.name = "BossSplash"
	_splash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_splash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_splash.visible = false
	add_child(_splash)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_splash.add_child(box)
	_splash_name = Label.new()
	_splash_name.name = "BossSplashName"
	_splash_name.theme_type_variation = "TitleLabel"  # Cinzel display face (W4 grimoire skin)
	_splash_name.add_theme_font_size_override("font_size", 52)
	_splash_name.add_theme_color_override("font_color", GrimoirePalette.BRASS_BRIGHT)
	_splash_name.add_theme_color_override("font_outline_color", GrimoirePalette.INK)
	_splash_name.add_theme_constant_override("outline_size", 8)
	_splash_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_splash_name)
	_splash_line = Label.new()
	_splash_line.name = "BossSplashLine"
	_splash_line.theme_type_variation = "MutedLabel"
	_splash_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_splash_line.visible = false
	box.add_child(_splash_line)
