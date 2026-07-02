extends RefCounted
## BattleCardKit (Wave 8 extraction) — the battle screen's STATIC card + arena visual kit.
##
## PRESENTATION layer. Pure node-building/styling helpers pulled out of battle_screen.gd when the
## Wave 8 time axis pushed it past the 1000-line cap: combatant cards (portrait + HP bar + status
## chips), the HP-bar colour band, damage floats, the portrait damage flash, the radial vignette,
## and the backdrop-lite arena picker. Everything is STATIC and self-contained — tweens are created
## off the nodes they animate, so no screen back-reference is held. The screen keeps ownership of
## all live state (teams, card-ref dicts, transcript); this file never reads a session.

const BACKDROP_DIR := "res://assets/backdrops/"
const STATUS_ICON_DIR := "res://assets/icons/statuses/"

## Wave 3 honesty copy (moved here from battle_screen with toast_outcome — W17 line-cap diet):
## the distinct turn-cap-with-enemies-alive banner + its VERBATIM voice line
## (docs/content/voice_library.md §5.5 "A creature that refuses to fight").
const STALEMATE_BANNER := "THE WILD SLINKS AWAY — STALEMATE"
const STALEMATE_VOICE_LINE := "No battle today. It's tired, you're tired, the gods are dead — what's the point, really?"

## One-line tooltips for the engine-state chips (W17 scryed legibility — every chip answers on hover).
const SHIELD_TIP := "Ward — absorbs this much damage before flesh is touched."
const BUFF_TIP := "Roused — its strikes land this much heavier while the surge holds."
const DEFDOWN_TIP := "Guard broken — incoming blows bite this much deeper."


## One combatant card: framed bestiary-plate portrait + name + force icon(s) + HP bar (with a
## SHIELD overlay) + HP text + a status-chip row. Reads the AbilityContainer's engine-owned state;
## computes nothing. `creature` (the run.party dict) wins over `species_id` for hybrid plates.
## Returns the node-refs dict the screen keeps for in-place updates + beat glides.
static func make_card(
	container: VBoxContainer,
	ac: AbilityContainer,
	species_id: String,
	is_enemy: bool,
	sc: StatusContainer,
	creature: Dictionary = {}
) -> Dictionary:
	var card := PanelContainer.new()
	card.name = ("Enemy" if is_enemy else "Party") + "Card"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)

	# Wave 9 LivingPlate: the portrait breathes/sways in the same 88px slot the old TextureRect
	# held. Hybrids render their dominant parent's plate + a deterministic corruption tint
	# (PortraitUtil, same face as party/lab/camp); the tint lands on the plate's SPRITE
	# self_modulate so it still composes with the damage-flash tween on the plate's modulate.
	var portrait := LivingPlate.new()
	portrait.name = "Portrait"
	portrait.set_plate_size(Vector2(88, 88))
	var portrait_source := creature if not creature.is_empty() else {"species_id": species_id}
	portrait.set_texture(PortraitUtil.creature_plate(portrait_source))
	portrait.set_tint(PortraitUtil.creature_tint(portrait_source))
	# Per-instance identity: hybrids/party carry their own tag; wild enemies fall back to the
	# combatant name so two same-species wilds still breathe out of phase.
	var identity_tag := PortraitUtil.instance_tag_of(portrait_source)
	if identity_tag == "":
		identity_tag = ac.combatant_name()
	portrait.set_identity(str(portrait_source.get("species_id", "")), identity_tag)
	row.add_child(PortraitUtil.framed(portrait))
	# The one-of-one mark rides the portrait corner (Wave 9 sigils).
	PortraitUtil.stamp_sigil(portrait, portrait_source, ac.primary_force(), 16, identity_tag)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 3)
	row.add_child(info)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 5)
	var name_label := Label.new()
	name_label.text = ac.combatant_name()
	name_row.add_child(name_label)
	for f: String in [ac.primary_force(), ac.secondary_force()]:
		var tr := PortraitUtil.force_icon_node(f)
		if tr != null:
			name_row.add_child(tr)
	info.add_child(name_row)
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = ac.max_hp()
	bar.value = maxi(0, ac.hp())
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)
	style_hp_bar(bar)
	info.add_child(bar)
	var hp_label := Label.new()
	hp_label.theme_type_variation = "MutedLabel"
	hp_label.text = "%d / %d" % [maxi(0, ac.hp()), ac.max_hp()]
	info.add_child(hp_label)
	# A status-chip row: shield / buff / defdown, surfaced only when active (skill-battle depth).
	var chips := HBoxContainer.new()
	chips.name = "Chips"
	chips.add_theme_constant_override("separation", 6)
	info.add_child(chips)

	container.add_child(card)
	var refs := {
		"card": card,
		"portrait": portrait,
		"name": name_label,
		"bar": bar,
		"hp": hp_label,
		"chips": chips,
		"last_hp": ac.hp()
	}
	update_card_chips(ac, chips, sc)
	return refs


## Update each card's HP bar / text / alive-dim from the live container; flash the portrait +
## float a damage number + fire the hit/death stingers on an HP drop (`fx` = the battle screen's
## fx_damage/play_stinger surface); refresh the shield/buff/defdown chips. `status_of` resolves an
## AbilityContainer's StatusContainer (null when the status layer is off).
static func update_team_cards(cards: Array, team: Array, status_of: Callable, fx: Object) -> void:
	for i in mini(cards.size(), team.size()):
		var ac := team[i] as AbilityContainer
		var c: Dictionary = cards[i]
		var bar := c["bar"] as ProgressBar
		bar.max_value = ac.max_hp()
		bar.value = maxi(0, ac.hp())
		style_hp_bar(bar)
		(c["hp"] as Label).text = "%d / %d" % [maxi(0, ac.hp()), ac.max_hp()]
		(c["name"] as Label).text = ac.combatant_name() + ("   (down)" if not ac.is_alive() else "")
		(c["card"] as Control).modulate = (
			Color(1, 1, 1, 0.4) if not ac.is_alive() else Color(1, 1, 1, 1)
		)
		update_card_chips(ac, c["chips"] as HBoxContainer, status_of.call(ac) as StatusContainer)
		var last := int(c.get("last_hp", ac.hp()))
		if ac.hp() < last:
			flash_portrait(c["portrait"] as CanvasItem)
			fx.call("fx_damage", c["card"], last - ac.hp())
			# Instant/drain path stingers (the animated path fires these from battle_beats).
			fx.call("play_stinger", "hit_crunch", 0.15)
			if ac.hp() <= 0:
				fx.call("play_stinger", "death_knell", 0.0)
		c["last_hp"] = ac.hp()


## Rebuild a card's status chips from the live engine state: shield (◈) / buff (▲) / defdown (▼)
## from the AbilityContainer, then the active DOT/control STATUSES (Wither/Petrify/...) from the
## parallel StatusContainer — DOTs show a stack count (×N), controls a remaining duration ([N]).
## W17 scryed legibility: each status chip carries its restyled SVG icon + short label + a ONE-LINE
## tooltip built from the status table (kind/effect — no invented numbers), and every colour is
## paired with an icon/glyph so the row survives grayscale. Absent effects show no chip.
static func update_card_chips(
	ac: AbilityContainer, chips: HBoxContainer, sc: StatusContainer
) -> void:
	if chips == null:
		return
	for child in chips.get_children():
		child.queue_free()
	if ac.shield() > 0:
		chips.add_child(make_chip("◈ %d" % ac.shield(), Color(0.435, 0.722, 0.839), SHIELD_TIP))  # Ouranos blue
	if ac.buff() > 0.0:
		chips.add_child(
			make_chip("▲ +%d%%" % int(ac.buff() * 100.0), Color(0.498, 0.682, 0.353), BUFF_TIP)
		)
	if ac.defdown() > 0.0:
		chips.add_child(
			make_chip(
				"▼ -%d%%" % int(ac.defdown() * 100.0), Color(0.761, 0.251, 0.184), DEFDOWN_TIP
			)
		)
	if sc != null:
		var table: Dictionary = Constants.BALANCE["status"]["statuses"]
		for status_name: String in sc.active_statuses():
			var s: Dictionary = table.get(status_name, {})
			var force := str(s.get("force", ""))
			var col := GrimoirePalette.force_color(force) if force != "" else Color(0.82, 0.5, 0.5)
			var label := str(status_name)
			var tip: String
			if str(s.get("kind", "")) == "dot":
				label += " ×%d" % sc.stacks_of(status_name)
				tip = (
					"%s — a %s rot that burns at each turn's end; stacks deepen it."
					% [status_name, force]
				)
			else:
				label += " [%d]" % sc.duration_of(status_name)
				tip = (
					"%s — %s for %d more turn(s)."
					% [status_name, str(s.get("effect", "controlled")), sc.duration_of(status_name)]
				)
			chips.add_child(make_chip(label, col, tip, status_icon(status_name)))


## A small coloured status chip: an optional ICON beside a short label, with a one-line tooltip
## (W17). Colour is always paired with the icon/glyph half, so the chip reads in grayscale.
static func make_chip(
	text: String, color: Color, tooltip: String = "", icon: Texture2D = null
) -> Control:
	var chip := HBoxContainer.new()
	chip.add_theme_constant_override("separation", 3)
	chip.tooltip_text = tooltip
	chip.mouse_filter = Control.MOUSE_FILTER_STOP  # chips must actually catch the hover
	if icon != null:
		var tr := TextureRect.new()
		tr.texture = icon
		tr.custom_minimum_size = Vector2(14, 14)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tr.modulate = color
		chip.add_child(tr)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", color)
	chip.add_child(label)
	return chip


## The restyled SVG icon for a status name ("Bloom-rot" -> statuses/bloom_rot.svg), or null.
static func status_icon(status_name: String) -> Texture2D:
	var file := status_name.to_lower().replace("-", "_").replace(" ", "_")
	var path := STATUS_ICON_DIR + file + ".svg"
	return load(path) if ResourceLoader.exists(path) else null


## Float a "-N" damage number up from a card and fade it (impact feedback). Lives on the FX
## overlay so the card's container layout never clips it. No-op headless / before layout.
static func spawn_damage_number(fx_layer: Control, card: Control, amount: int) -> void:
	if fx_layer == null or card == null or not fx_layer.is_inside_tree():
		return
	var lbl := Label.new()
	lbl.text = "-%d" % amount
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.42, 0.36))
	lbl.add_theme_color_override("font_outline_color", Color(0.07, 0.05, 0.09))
	lbl.add_theme_constant_override("outline_size", 5)
	lbl.z_index = 60
	fx_layer.add_child(lbl)
	lbl.position = card.global_position + Vector2(card.size.x * 0.5, 8.0)
	var tw := lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position", lbl.position + Vector2(0, -42), 0.75).set_trans(
		Tween.TRANS_QUAD
	)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.75).set_delay(0.15)
	tw.chain().tween_callback(lbl.queue_free)


## A quick red→normal flash on a portrait when its creature takes damage (impact juice). Takes
## any CanvasItem — the Wave 9 LivingPlate root as readily as the old TextureRect (the modulate
## tween composes with the plate's tint, which lives on the sprite's self_modulate).
static func flash_portrait(portrait: CanvasItem) -> void:
	if portrait == null or not portrait.is_inside_tree():
		return
	portrait.modulate = Color(1.7, 0.55, 0.5)
	portrait.create_tween().tween_property(portrait, "modulate", Color(1, 1, 1, 1), 0.35)


## The outcome BANNER text for a finished battle result (moved from battle_screen — W17 line-cap
## diet). Wave 3 honesty: a turn cap expiring with enemies still standing is a STALEMATE, never a
## lying VICTORY.
static func banner_text_for(result: Dictionary, reason: String) -> String:
	if bool(result.get("stalemate", false)):
		return STALEMATE_BANNER
	match reason:
		"caught":
			return "CAUGHT"
		"fled":
			return "FLED"
		_:
			return "VICTORY" if bool(result.get("player_won", false)) else "DEFEAT"


## Fire the end-of-battle outcome toast (moved from battle_screen — W17 line-cap diet). A catch
## carries the creature's one-of-one sigil payload; a stalemate carries the verbatim §5.5 voice
## line + the halved-spoils note; everything else toasts its banner. `battle` is the screen's
## SkillInteractiveBattle (duck-typed), `game` the GameController.
static func toast_outcome(
	toast: Node, result: Dictionary, reason: String, battle, game: Node
) -> void:
	if toast == null:
		return
	if reason == "caught" and toast.has_method("event_with"):
		# Wave 9: the catch toast bears the creature's one-of-one sigil (the same geometry
		# party/lab render for this creature forever after).
		toast.call("event_with", "creature_caught", {"sigil": caught_sigil_payload(battle, game)})
	elif reason == "caught" and toast.has_method("event"):
		toast.call("event", "creature_caught")
	elif bool(result.get("stalemate", false)) and toast.has_method("show"):
		(
			toast
			. call(
				"show",
				{
					"title": STALEMATE_BANNER,
					"body": STALEMATE_VOICE_LINE + "\n(Spoils halved.)",
					"sound": "chime",
				}
			)
		)
	elif toast.has_method("show"):
		toast.call("show", {"title": banner_text_for(result, reason), "body": "", "sound": "chime"})


## The caught creature's sigil identity for the capture toast (Wave 9): species + instance tag
## (PortraitUtil derivation — the same inputs every other screen hashes) + its primary force for
## the accent stroke. `battle` is the screen's SkillInteractiveBattle (duck-typed: caught());
## `game` the GameController (catalog()). Cheap: one lookup on the already-cached caught dict.
static func caught_sigil_payload(battle, game: Node) -> Dictionary:
	var caught: Dictionary = battle.caught() if battle != null else {}
	var species_id := str(caught.get("species_id", ""))
	var force := ""
	if game != null and game.has_method("catalog"):
		var catalog: SpeciesCatalog = game.call("catalog")
		if catalog != null:
			var species: SpeciesData = catalog.get_by_id(species_id)
			if species != null:
				force = species.force_primary
	return {
		"species": species_id,
		"tag": PortraitUtil.instance_tag_of(caught),
		"force": force,
	}


## A radial vignette texture (transparent centre -> soft dark edges) for arena atmosphere.
static func make_vignette(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) * 0.5
	var maxd := Vector2(c, c).length()
	for y in size:
		for x in size:
			var t := clampf((Vector2(x - c, y - c).length() / maxd - 0.5) / 0.5, 0.0, 1.0)
			img.set_pixel(x, y, Color(0.02, 0.012, 0.03, t * t * 0.66))
	return ImageTexture.create_from_image(img)


## Colour the HP bar green -> amber -> red by health fraction (an instant read-out) over a dark
## INK track, with rounded corners to match the grimoire theme (replaces the default pink fill).
static func style_hp_bar(bar: ProgressBar) -> void:
	var frac := 0.0
	if bar.max_value > 0:
		frac = clampf(bar.value / bar.max_value, 0.0, 1.0)
	var fill_color := Color(0.498039, 0.682353, 0.352941)  # SUCCESS green #7fae5a
	if frac < 0.3:
		fill_color = Color(0.760784, 0.25098, 0.184314)  # DANGER red #c2402f
	elif frac < 0.6:
		fill_color = Color(0.839216, 0.635294, 0.247059)  # WARNING amber #d6a23f
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(3)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.090196, 0.07451, 0.109804)  # INK track
	track.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", track)


## The painterly arena backdrop for a battle (Wave 8 backdrop-lite): manifest force -> files,
## preferring the *_battle dim variant. Unknown/missing force falls back eros (wild) / thanatos
## (boss/adversary). Compound forces ("Ouranos+Gaia") resolve to their first token.
static func pick_backdrop(region_force: String, is_wild: bool) -> Texture2D:
	var manifest := load_backdrop_manifest()
	if manifest.is_empty():
		return null
	var key := region_force.to_lower().get_slice("+", 0)
	if not manifest.has(key):
		key = "eros" if is_wild else "thanatos"
	var files_v: Variant = manifest.get(key, [])
	var files: Array = files_v if files_v is Array else []
	var pick := ""
	for f in files:
		if str(f).ends_with("_battle.png"):
			pick = str(f)
			break
	if pick == "" and not files.is_empty():
		pick = str(files[0])
	if pick == "" or not ResourceLoader.exists(BACKDROP_DIR + pick):
		return null
	return load(BACKDROP_DIR + pick) as Texture2D


static func load_backdrop_manifest() -> Dictionary:
	var f := FileAccess.open(BACKDROP_DIR + "manifest.json", FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed as Dictionary if parsed is Dictionary else {}
