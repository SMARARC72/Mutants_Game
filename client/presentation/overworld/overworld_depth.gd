class_name OverworldDepth
extends RefCounted
## OverworldDepth (Wave 12 "Overworld Depth") — the flat map's depth kit, extracted from
## overworld_screen to keep it under the lint line cap (the incremental-decomposition rule):
##   * WORLD ROOT: one y-sorted Node2D holding props + player + NPC tokens + the lead cameo,
##     all at z 0 with feet-level y-origins — occlusion comes from Y, never hand-set z layers;
##   * HORIZON: the region force's blurred+darkened backdrop strip (tools/gen_horizon.py) on a
##     Parallax2D drifting at ~0.15 scroll behind the tiles, over an ink backing plate — the
##     void beyond the map's edge reads as distant land under an ink sky, not raw clear-colour;
##   * PROPS: painterly decals on feature cells at believable height (tall props ~1.4 tiles);
##   * GLOW: ONE warm brass PointLight2D on the tamer (shadows OFF) that shades the ground via
##     OverworldTileSet's normal-mapped CanvasTexture atlas.
## All builders are deterministic pure functions of their inputs; headless-safe (nothing renders).

const OverworldTileSetScript := preload("res://presentation/overworld/overworld_tileset.gd")
const OverworldSpawnScript := preload("res://presentation/overworld/overworld_spawn.gd")

## Per-force horizon strips (tools/gen_horizon.py outputs), upscaled in-scene (they are heavy
## blurs; the asset-contract CI caps sources at 1024px).
const HORIZON_DIR := "res://assets/backdrops/horizon/"
const HORIZON_SCROLL := 0.15  # scroll ratio — near-screen-fixed, drifting like a distant band
const HORIZON_SCALE := 2.75  # covers the zoomed view + the drift range vertically


## Create the Y-SORTED world root under `parent`. It rides z 1 so it always draws above the
## ground TileMapLayer (z 0) regardless of child order across rebuilds; INSIDE it, draw order
## is pure Y — props and actors all sit at z 0 with feet-level origins.
static func make_world_root(parent: Node2D) -> Node2D:
	var world := Node2D.new()
	world.name = "WorldYSort"
	world.y_sort_enabled = true
	world.z_index = 1
	parent.add_child(world)
	return world


## (Re)build the painterly horizon behind the tile field. Rebuilt per build (the force can
## change with the region); the ink backing plate is created once.
static func setup_horizon(parent: Node2D, force_climate: String, layout: Layout) -> void:
	var old := parent.get_node_or_null("HorizonParallax")
	if old != null:
		parent.remove_child(old)  # release the name NOW so the rebuilt node is findable
		old.queue_free()
	if parent.get_node_or_null("HorizonBacking") == null:
		var backing := CanvasLayer.new()
		backing.name = "HorizonBacking"
		backing.layer = -10  # behind the whole world canvas
		var ink := ColorRect.new()
		ink.color = GrimoirePalette.INK
		ink.set_anchors_preset(Control.PRESET_FULL_RECT)
		ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
		backing.add_child(ink)
		parent.add_child(backing)
	var path := HORIZON_DIR + force_climate.get_slice("+", 0).to_lower() + ".png"
	if not ResourceLoader.exists(path):
		return
	var tex := load(path) as Texture2D
	if tex == null:
		return
	var par := Parallax2D.new()
	par.name = "HorizonParallax"
	par.scroll_scale = Vector2(HORIZON_SCROLL, HORIZON_SCROLL)
	par.repeat_size = Vector2(tex.get_width() * HORIZON_SCALE, 0)
	par.repeat_times = 2
	par.z_index = -20  # behind the ground tiles (0) and the y-sorted world (1)
	parent.add_child(par)
	var strip := Sprite2D.new()
	strip.name = "HorizonStrip"
	strip.texture = tex
	strip.scale = Vector2(HORIZON_SCALE, HORIZON_SCALE)
	# Centre the strip on the spawn view: at 0.15 scroll it stays near-screen-fixed, so it only
	# needs to cover the view plus the small drift range, which the scale provides.
	var s := OverworldTileSetScript.TILE_SIZE
	var spawn: Vector2i = OverworldSpawnScript.spawn_cell(layout)
	strip.position = Vector2(spawn.x * s + s / 2.0, spawn.y * s + s / 2.0)
	par.add_child(strip)


## Prop decals on feature cells: a deterministic minority of feature-classified cells (chosen by
## OverworldTileSet.prop_texture — pure function of force + cell, so the same map always dresses
## the same way) get a painterly decal sprite (boulder ledge / moss mound / crystals / bones /
## ward stone). Walkability is untouched — these are set dressing. Props live in a y-sorted
## holder under the world root with FEET-level origins and real height, so they occlude actors
## walking behind them and are occluded from in front. Frees `old_props`, returns the new holder.
static func scatter_props(
	world: Node2D, old_props: Node2D, layout: Layout, force_climate: String
) -> Node2D:
	if old_props != null and is_instance_valid(old_props):
		world.remove_child(old_props)  # release the name NOW (rebuild lands in the same frame)
		old_props.queue_free()
	var props := Node2D.new()
	props.name = "Props"
	props.y_sort_enabled = true  # its children join the WorldYSort sort space (nested y-sort)
	world.add_child(props)
	var s := OverworldTileSetScript.TILE_SIZE
	for y in layout.height:
		for x in layout.width:
			if layout.get_cell(x, y) != OverworldTileSetScript.FEATURE_TILE:
				continue
			var tex: Texture2D = OverworldTileSetScript.prop_texture(force_climate, x, y)
			if tex == null:
				continue
			var prop := Sprite2D.new()
			prop.texture = tex
			var height := s * OverworldTileSetScript.prop_height_tiles(tex)
			var fit := height / float(tex.get_height())
			# The prop plates are landscape (aspect ~1.4-1.85), so the width cap is generous —
			# a ward-stone spilling past its cell reads as a monument, not a sprite bug — while
			# still keeping the tall ones over a tile high (they must hide a medallion).
			fit = minf(fit, (s * 1.7) / float(tex.get_width()))
			prop.scale = Vector2(fit, fit)
			# Feet origin: the node's position IS the base of the prop (texture raised above
			# it), so the y-sort compares ground contact lines, not sprite centres.
			prop.offset = Vector2(0, -tex.get_height() * 0.5)
			prop.position = Vector2(x * s + s / 2.0, y * s + s * 0.82)
			props.add_child(prop)
	return props


## W-DRESS: free the previous build's NPC nodes before a re-spawn. A rebuilt screen re-spawns
## the whole cast; without this the stale twins keep drawing AND shadow name lookups (the
## quest markers would retune a corpse). Safe on empty lists / freed nodes.
static func free_cast(npcs: Array) -> void:
	for npc: Dictionary in npcs:
		var node: Node2D = npc.get("node")
		if node == null or not is_instance_valid(node):
			continue
		var parent := node.get_parent()
		if parent != null:
			parent.remove_child(node)  # release the name NOW (the rebuild lands this frame)
		node.queue_free()


## ONE warm brass PointLight2D riding the player — with the normal-mapped ground atlas
## (OverworldTileSet) the tiles shade toward the tamer, and the CanvasModulate dim gives the
## pool of light something to read against. Radial-gradient texture, shadows OFF, energy ~0.7:
## well inside the Iris Xe light budget (1 light, 0 shadow casters). Idempotent.
static func attach_player_glow(player: Node2D) -> void:
	if player == null or player.get_node_or_null("PlayerGlow") != null:
		return
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.3), Color(1, 1, 1, 0)])
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill = GradientTexture2D.FILL_RADIAL
	gtex.fill_from = Vector2(0.5, 0.5)
	gtex.fill_to = Vector2(0.5, 0.0)
	gtex.width = 256
	gtex.height = 256
	var glow := PointLight2D.new()
	glow.name = "PlayerGlow"
	glow.texture = gtex
	glow.color = GrimoirePalette.BRASS_BRIGHT
	glow.energy = 0.7
	glow.texture_scale = 2.0  # ~8-tile soft pool around the tamer
	glow.shadow_enabled = false
	player.add_child(glow)


## The world CanvasModulate the AtmosphereLayer drives (Wave 13: the layer's set_mood owns the
## colour; the raw Wave-12 tint + baked vignette TextureRect are superseded). Idempotent — the
## screen rebuilds on every visit but the tint node is created once. Starts at the Wave-12
## verdant grade so a frame before the first set_mood still reads correctly.
static func ensure_world_tint(screen: Node2D) -> CanvasModulate:
	var tint := screen.get_node_or_null("ClimateTint") as CanvasModulate
	if tint == null:
		tint = CanvasModulate.new()
		tint.name = "ClimateTint"
		tint.color = Color(0.75, 0.81, 0.74)
		screen.add_child(tint)
	return tint


## Faint drifting spore-motes, parented to the tamer so they always fill the framed view
## (kept from the Wave-12 pass; idempotent across rebuilds).
static func setup_motes(player: Node2D) -> void:
	if player == null or player.get_node_or_null("Motes") != null:
		return
	var motes := CPUParticles2D.new()
	motes.name = "Motes"
	motes.z_index = 12
	motes.amount = 36
	motes.lifetime = 7.0
	motes.preprocess = 5.0
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(820, 520)
	motes.gravity = Vector2(0, -5)
	motes.initial_velocity_min = 3.0
	motes.initial_velocity_max = 11.0
	motes.scale_amount_min = 1.0
	motes.scale_amount_max = 2.4
	motes.color = Color(0.88, 0.78, 0.42, 0.5)
	player.add_child(motes)


## The lead-creature cameo (the ACTIVE party lead's painterly cutout, feet-origin for the
## WorldYSort) trailing the tamer HG/SS-style. Returns the Sprite2D (added to `world`) or null
## when no plate resolves. Moved from overworld_screen (line cap).
static func spawn_lead_cameo(
	game: Node, world: Node2D, player_cell: Vector2i, last_dir: Vector2i
) -> Sprite2D:
	var species := lead_species_id(game)
	var tex: Texture2D = SpeciesArt.plate(species)
	if tex == null:
		return null
	var box := int(OverworldTileSet.TILE_SIZE * 1.18)
	var lead := Sprite2D.new()
	lead.name = "LeadCreature"
	lead.texture = OverworldTokens.creature_cameo(tex, box, species)
	# Feet-level y-origin: the cameo's ground shadow sits at ~0.92 of its box — raise the texture
	# so that contact line lands on the node position; WorldYSort then occludes it correctly.
	lead.offset = Vector2(0, -box * 0.42)
	world.add_child(lead)
	var s := OverworldTileSet.TILE_SIZE
	var here := Vector2(player_cell.x * s + s / 2.0, player_cell.y * s + s / 2.0)
	lead.position = here - Vector2(last_dir) * float(s)
	return lead


## The species id of the run's ACTIVE lead creature (not just party[0]), or "".
static func lead_species_id(game: Node) -> String:
	if game == null or not game.has_method("run"):
		return ""
	var run: RunContext = game.call("run")
	if run == null or not (run.party is Array) or (run.party as Array).is_empty():
		return ""
	var party: Array = run.party
	var idx := 0
	if game.has_method("active_creature_index"):
		idx = clampi(int(game.call("active_creature_index")), 0, party.size() - 1)
	var lead: Variant = party[idx]
	return str((lead as Dictionary).get("species_id", "")) if lead is Dictionary else ""
