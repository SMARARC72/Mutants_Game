class_name OverworldAmbience
extends RefCounted
## OverworldAmbience (Wave 13) — the overworld's small-life kit, extracted so overworld_screen
## stays under the lint line cap (the OverworldMotion/OverworldDepth pattern):
##   * TILE CLASS: maps a stepped cell to the EncounterDirector encounter class ("thin" on the
##     visible ritual-accent cells — feature cells OverworldTileSet.is_thin_place picks — else "");
##   * VEIL SHIMMER: a soft pulsing marker on every thin-place cell (ONE looping tween on the
##     holder, not per marker) + a rate-limited SfxService "veil_whisper" when stepping onto one;
##   * FOLLOWER EMOTES: the lead cameo alert-hops when the walk nears a thin place, shivers on a
##     blocked move, and joy-hops once after a capture (correction C15) — all tween-cheap and
##     skipped headless / under reduce_motion;
##   * NPC face-player flips when the tamer stands adjacent;
##   * MOOD: pushes run corruption + thin-place dread into the AtmosphereLayer and the HUD pip.
## Presentation only: LOCAL clocks/hashes, never the canonical RNG streams.

const OverworldTileSetScript := preload("res://presentation/overworld/overworld_tileset.gd")
const EncounterDirectorScript := preload("res://application/overworld/encounter_director.gd")

const WHISPER_COOLDOWN_MS := 4000  # veil_whisper never re-fires inside this window
const BASE_DREAD := 0.2  # the overworld's resting dread; nearing the veil raises it
const NEAR_THIN_DREAD := 0.55
const HOP_PX := 7.0
const SHIMMER_ALPHA := 0.5

## Capture joy-hops already played, keyed by (seed, step) — session-static so the one rebuild
## that follows a catching battle hops exactly once, and re-entries at the same step stay calm.
static var _joy_played: Dictionary = {}
## The shared soft veil-glow texture (built once; violet ritual light).
static var _shimmer_cache: Texture2D = null

var _last_whisper_ms := -WHISPER_COOLDOWN_MS
var _was_near_thin := false


static func clear_runtime_cache() -> void:
	_shimmer_cache = null
	_joy_played.clear()


## The EncounterDirector tile class for a cell: TILE_CLASS_THIN on the VISIBLE ritual-accent
## cells (feature cells promoted by OverworldTileSet.is_thin_place — the same pure function that
## paints them), "" everywhere else. The encounter surface and the shimmering tiles never disagree.
static func tile_class_at(layout: Layout, cell: Vector2i) -> String:
	if layout == null or not layout.in_bounds(cell.x, cell.y):
		return ""
	if layout.get_cell(cell.x, cell.y) != OverworldTileSetScript.FEATURE_TILE:
		return ""
	if OverworldTileSetScript.is_thin_place(cell.x, cell.y):
		return EncounterDirectorScript.TILE_CLASS_THIN
	return ""


## True when `cell` or any cardinal neighbour is a thin place (the follower's alert radius).
static func near_thin(layout: Layout, cell: Vector2i) -> bool:
	var dirs := [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]
	for dir: Vector2i in dirs:
		if tile_class_at(layout, cell + dir) != "":
			return true
	return false


## Push the run's mood into the atmosphere + the HUD pip (build, post-step, post-quest-effect).
static func refresh_mood(
	atmosphere: AtmosphereLayer,
	pip: CorruptionPip,
	run_ctx: RunContext,
	force_climate: String,
	is_near_thin: bool
) -> void:
	var corruption := float(run_ctx.corruption) if run_ctx != null else 0.0
	if atmosphere != null and is_instance_valid(atmosphere):
		var dread := NEAR_THIN_DREAD if is_near_thin else BASE_DREAD
		atmosphere.set_mood(dread, 0.0, corruption, force_climate)
	if pip != null and is_instance_valid(pip):
		pip.refresh(run_ctx)


# === veil shimmer ============================================================================= #


## (Re)build the shimmer markers over every thin-place cell of the layout. The holder sits above
## the ground tiles (z 0 sibling added after the tile layer) and below the y-sorted world (z 1) —
## a ground glow, never an occluder. ONE looping tween pulses the whole holder (cheap); headless /
## reduce_motion get a static mid-alpha instead. Frees `old`; returns the new holder.
static func build_shimmer(screen: Node2D, old: Node2D, layout: Layout) -> Node2D:
	if old != null and is_instance_valid(old):
		screen.remove_child(old)
		old.queue_free()
	var holder := Node2D.new()
	holder.name = "VeilShimmer"
	holder.z_index = 0
	screen.add_child(holder)
	if layout == null:
		return holder
	var s := OverworldTileSetScript.TILE_SIZE
	var glow := _shimmer_texture()
	for y in layout.height:
		for x in layout.width:
			if tile_class_at(layout, Vector2i(x, y)) == "":
				continue
			var marker := Sprite2D.new()
			marker.texture = glow
			marker.position = Vector2(x * s + s / 2.0, y * s + s / 2.0)
			marker.scale = Vector2.ONE * (float(s) * 1.35 / float(glow.get_width()))
			holder.add_child(marker)
	holder.modulate = Color(1, 1, 1, SHIMMER_ALPHA)
	if _can_animate(holder):
		var tween := holder.create_tween().set_loops()
		tween.tween_property(holder, "modulate:a", SHIMMER_ALPHA + 0.28, 1.4)
		tween.tween_property(holder, "modulate:a", SHIMMER_ALPHA - 0.18, 1.4)
	return holder


## The shared soft veil-glow texture (violet ritual light — GrimoirePalette.THANATOS).
static func _shimmer_texture() -> Texture2D:
	if _shimmer_cache != null:
		return _shimmer_cache
	var grad := Gradient.new()
	var core := GrimoirePalette.THANATOS.lightened(0.25)
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	grad.colors = PackedColorArray(
		[Color(core, 0.5), Color(GrimoirePalette.THANATOS, 0.22), Color(core, 0.0)]
	)
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 96
	tex.height = 96
	_shimmer_cache = tex
	return tex


# === per-step reactions ======================================================================== #


## Everything small that reacts to a successful step: the veil whisper on stepping ONTO a thin
## cell (rate-limited), the lead's alert hop when the walk ENTERS the veil's reach, and the NPC
## face-player flips. Called by the screen after the move logic resolves. Returns true when the
## near-the-veil state CHANGED (the screen re-moods the atmosphere only on transitions).
func on_step(layout: Layout, lead: Sprite2D, npcs: Array, player_cell: Vector2i) -> bool:
	face_npcs(npcs, player_cell)
	if tile_class_at(layout, player_cell) != "":
		_whisper()
	var near := near_thin(layout, player_cell)
	if near and not _was_near_thin:
		hop(lead, 1)
	var changed := near != _was_near_thin
	_was_near_thin = near
	return changed


## The lead's wall shiver on a blocked move — a quick sympathetic x-jitter. Emotes tween the
## sprite's texture OFFSET, never its position (the screen's _process lerps the lead's position
## every frame; offset rides on top without a fight).
func on_blocked(lead: Sprite2D) -> void:
	if lead == null or not _can_animate(lead):
		return
	var base := lead.offset
	var tween := lead.create_tween()
	for jitter: float in [2.5, -2.5, 1.2]:
		tween.tween_property(lead, "offset:x", base.x + jitter, 0.045)
	tween.tween_property(lead, "offset:x", base.x, 0.045)


## Joy hop after a capture: the rebuilt post-battle overworld reads the battle bookkeeping and
## hops the lead exactly once per caught battle (keyed by seed+step — reload/re-entry stay calm).
func maybe_joy_hop(lead: Sprite2D, run_ctx: RunContext, step: int) -> void:
	if run_ctx == null or str(run_ctx.flags.get("last_battle_reason", "")) != "caught":
		return
	var key := "%d#%d" % [run_ctx.seed, step]
	if _joy_played.has(key):
		return
	_joy_played[key] = true
	hop(lead, 2)


## A small tween hop (`count` bounces) — the follower's emote verb. No-op headless/reduce_motion.
func hop(lead: Sprite2D, count: int) -> void:
	if lead == null or not _can_animate(lead):
		return
	var base := lead.offset
	var tween := lead.create_tween()
	for _i in count:
		var up := tween.tween_property(lead, "offset:y", base.y - HOP_PX, 0.09)
		up.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		var down := tween.tween_property(lead, "offset:y", base.y, 0.09)
		down.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


## Flip every ADJACENT NPC token to face the tamer (the seals politely turn to you — C15).
func face_npcs(npcs: Array, player_cell: Vector2i) -> void:
	for npc: Dictionary in npcs:
		var cell: Vector2i = npc.get("cell", Vector2i.ZERO)
		var delta := player_cell - cell
		if absi(delta.x) + absi(delta.y) != 1 or delta.x == 0:
			continue
		var node: Node2D = npc.get("node")
		if node == null or not is_instance_valid(node) or node.get_child_count() == 0:
			continue
		var token := node.get_child(0) as Sprite2D
		if token != null:
			token.flip_h = delta.x < 0


## A brief brass spark-burst trailing the tamer on a dash (ley-line residue; moved from
## overworld_screen for the line cap). No-op headless.
static func dash_trail(player: Node2D, last_dir: Vector2i) -> void:
	if player == null or not player.is_inside_tree():
		return
	var spark := CPUParticles2D.new()
	spark.one_shot = true
	spark.emitting = true
	spark.amount = 18
	spark.lifetime = 0.5
	spark.explosiveness = 0.9
	spark.direction = Vector2(-last_dir.x, -last_dir.y)
	spark.spread = 38.0
	spark.initial_velocity_min = 40.0
	spark.initial_velocity_max = 130.0
	spark.scale_amount_min = 1.0
	spark.scale_amount_max = 2.6
	spark.color = GrimoirePalette.BRASS_BRIGHT
	player.add_child(spark)
	player.get_tree().create_timer(0.9).timeout.connect(spark.queue_free)


## Rate-limited veil whisper (W-SND asset; the W14 hook the plan reserved). Headless-recorded.
func _whisper() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_whisper_ms < WHISPER_COOLDOWN_MS:
		return
	_last_whisper_ms = now
	var sfx := _sfx()
	if sfx != null and sfx.has_method("play"):
		sfx.call("play", "veil_whisper", 0.1)


static func _sfx() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("SfxService")
	return null


## Tweens only where they can run AND the player wants them (OverworldMotion's contract).
static func _can_animate(node: Node) -> bool:
	if node == null or not node.is_inside_tree():
		return false
	if DisplayServer.get_name() == "headless":
		return false
	return not OverworldMotion.reduce_motion()
