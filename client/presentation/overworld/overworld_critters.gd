class_name OverworldCritters
extends RefCounted
## OverworldCritters (Wave 13 / red-team C15) — 2-3 ambient critters wandering the region on
## SIMPLE Beehave behavior trees, so the vendored addon is finally, genuinely exercised: each
## critter is a tiny recolored cutout sprite of a small slice species (~0.4 tile scale) driven by
## a BeehaveTree of SequenceComposite[IdleLeaf -> WanderLeaf] (idle a beat, amble one walkable
## tile, repeat). They spawn on DISTANT walkable cells and are recycled to a fresh distant cell
## once the tamer leaves them far behind (the cheap despawn-off-screen: out of view = out of the
## world). PRESENTATION ONLY and determinism-exempt per THIRD_PARTY.md's Beehave note: all
## randomness is a LOCAL RandomNumberGenerator — never the canonical PCG32 streams. Headless-safe:
## trees tick plain position math without a display, no tweens; leaves carry their own config
## (Beehave's Blackboard resets its store on _ready, so only TRANSIENT state lives there).

const CRITTER_COUNT := 3
const SCALE_TILES := 0.4  # critter height as a fraction of a tile
const MIN_SPAWN_TILES := 7  # spawn ring around the anchor: far enough to feel found, not placed
const MAX_SPAWN_TILES := 14
const RECYCLE_TILES := 26.0  # farther than this from the tamer -> recycled to a fresh cell
const WANDER_SPEED := 34.0  # px/s — an amble, not a patrol
## Gentle recolour modulates (cutout tints, not palette semantics) picked per critter.
const TINTS := [Color(0.85, 1.0, 0.88), Color(1.0, 0.92, 0.8), Color(0.85, 0.9, 1.0)]

var _rng := RandomNumberGenerator.new()  # LOCAL presentation stream (determinism-exempt)
var _holder: Node2D = null
var _layout: Layout = null


func _init() -> void:
	_rng.randomize()


## (Re)build the critter population under the y-sorted world root. `species_pool` is the region
## wild pool (small slice species ids); `anchor` is the canonical spawn the distance ring centres
## on. Returns the holder (tests). Safe headless; safe with an empty pool (spawns nothing).
func build(world: Node2D, layout: Layout, species_pool: Array, anchor: Vector2i) -> Node2D:
	_layout = layout
	if _holder != null and is_instance_valid(_holder):
		if _holder.get_parent() != null:
			_holder.get_parent().remove_child(_holder)
		_holder.queue_free()
	_holder = Node2D.new()
	_holder.name = "Critters"
	_holder.y_sort_enabled = true  # critters join the WorldYSort space like props/actors
	world.add_child(_holder)
	if layout == null or species_pool.is_empty():
		return _holder
	for i in CRITTER_COUNT:
		var species := str(species_pool[i % species_pool.size()])
		var cell := _distant_walkable_cell(anchor)
		if cell.x < 0:
			continue
		_holder.add_child(_make_critter(species, i, cell))
	return _holder


## The critter holder (or null before build) — for tests.
func holder() -> Node2D:
	return _holder


## Recycle any critter the tamer has left far behind onto a fresh distant cell (the despawn).
## Called on player steps — cheap (3 distance checks), never per frame.
func recycle_far(player_cell: Vector2i) -> void:
	if _holder == null or not is_instance_valid(_holder) or _layout == null:
		return
	var s := OverworldTileSet.TILE_SIZE
	var player_px := Vector2(player_cell.x * s + s / 2.0, player_cell.y * s + s / 2.0)
	for critter: Node2D in _holder.get_children():
		if critter.position.distance_to(player_px) < RECYCLE_TILES * float(s):
			continue
		var cell := _distant_walkable_cell(player_cell)
		if cell.x >= 0:
			critter.position = _cell_px(cell)


## One critter: a recolored cutout sprite + its BeehaveTree(Sequence[Idle -> Wander]).
func _make_critter(species: String, index: int, cell: Vector2i) -> Node2D:
	var critter := Node2D.new()
	critter.name = "Critter_%d" % index
	critter.position = _cell_px(cell)
	var s := OverworldTileSet.TILE_SIZE
	var tex: Texture2D = SpeciesArt.plate(species)
	if tex != null:
		var sprite := Sprite2D.new()
		sprite.name = "Cutout"
		sprite.texture = tex
		var fit := (float(s) * SCALE_TILES) / maxf(float(tex.get_height()), 1.0)
		sprite.scale = Vector2(fit, fit)
		sprite.modulate = TINTS[index % TINTS.size()]
		# Feet-level origin so the WorldYSort parent occludes it like every other actor.
		sprite.offset = Vector2(0, -tex.get_height() * 0.5)
		critter.add_child(sprite)
	var tree := BeehaveTree.new()
	tree.name = "Brain"
	var seq := SequenceComposite.new()
	seq.name = "AmbleLoop"
	seq.add_child(IdleLeaf.new(_rng))
	seq.add_child(WanderLeaf.new(_layout, _rng))
	tree.add_child(seq)
	critter.add_child(tree)  # tree._ready resolves actor = its parent (the critter)
	return critter


func _cell_px(cell: Vector2i) -> Vector2:
	var s := OverworldTileSet.TILE_SIZE
	return Vector2(cell.x * s + s / 2.0, cell.y * s + s * 0.78)


## A random walkable cell MIN..MAX tiles (manhattan) from `anchor`, or (-1,-1) after bounded
## tries (a cramped layout simply hosts fewer critters).
func _distant_walkable_cell(anchor: Vector2i) -> Vector2i:
	for _try in 40:
		var dx := _rng.randi_range(-MAX_SPAWN_TILES, MAX_SPAWN_TILES)
		var dy := _rng.randi_range(-MAX_SPAWN_TILES, MAX_SPAWN_TILES)
		if absi(dx) + absi(dy) < MIN_SPAWN_TILES or absi(dx) + absi(dy) > MAX_SPAWN_TILES:
			continue
		var cell := anchor + Vector2i(dx, dy)
		if not _layout.in_bounds(cell.x, cell.y):
			continue
		if OverworldTileSet.is_walkable(_layout.get_cell(cell.x, cell.y)):
			return cell
	return Vector2i(-1, -1)


## Idle a random beat (0.7-2.4s), then hand the sequence to the wander step. Transient state
## (the wake deadline) lives on the tree's blackboard; the rng is leaf config.
class IdleLeaf:
	extends ActionLeaf

	var _rng: RandomNumberGenerator

	func _init(rng: RandomNumberGenerator) -> void:
		name = "Idle"
		_rng = rng

	func tick(_actor: Node, blackboard: Blackboard) -> int:
		var until := float(blackboard.get_value("idle_until", -1.0))
		var now := Time.get_ticks_msec() / 1000.0
		if until < 0.0:
			var wait := _rng.randf_range(0.7, 2.4) if _rng != null else 1.2
			blackboard.set_value("idle_until", now + wait)
			return RUNNING
		if now < until:
			return RUNNING
		blackboard.set_value("idle_until", -1.0)
		return SUCCESS


## Amble ONE walkable tile in a random cardinal direction (FAILURE restarts the sequence when
## boxed in). Plain per-tick position math — headless-safe, no tweens.
class WanderLeaf:
	extends ActionLeaf

	var _layout: Layout
	var _rng: RandomNumberGenerator

	func _init(layout: Layout, rng: RandomNumberGenerator) -> void:
		name = "Wander"
		_layout = layout
		_rng = rng

	func tick(actor: Node, blackboard: Blackboard) -> int:
		var critter := actor as Node2D
		if critter == null:
			return FAILURE
		var target: Variant = blackboard.get_value("wander_target")
		if target == null:
			return _pick_target(critter, blackboard)
		var target_px: Vector2 = target
		var delta := float(critter.get_physics_process_delta_time())
		critter.position = critter.position.move_toward(target_px, WANDER_SPEED * delta)
		if critter.position.distance_to(target_px) > 0.5:
			return RUNNING
		blackboard.set_value("wander_target", null)
		return SUCCESS

	func _pick_target(critter: Node2D, blackboard: Blackboard) -> int:
		if _layout == null or _rng == null:
			return FAILURE
		var s := OverworldTileSet.TILE_SIZE
		var dirs := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
		var dir: Vector2i = dirs[_rng.randi_range(0, dirs.size() - 1)]
		var cell := Vector2i(int(critter.position.x / s), int(critter.position.y / s)) + dir
		if not _layout.in_bounds(cell.x, cell.y):
			return FAILURE
		if not OverworldTileSet.is_walkable(_layout.get_cell(cell.x, cell.y)):
			return FAILURE
		var cutout := critter.get_node_or_null("Cutout") as Sprite2D
		if cutout != null and dir.x != 0:
			cutout.flip_h = dir.x < 0
		var target := Vector2(cell.x * s + s / 2.0, cell.y * s + s * 0.78)
		blackboard.set_value("wander_target", target)
		return RUNNING
