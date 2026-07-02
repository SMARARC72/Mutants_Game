class_name OverworldSpawn
extends RefCounted
## Spawn-cell selection for the overworld (extracted verbatim from overworld_screen in Wave 6
## to keep the screen under the lint line cap). Pure functions of the Layout — deterministic,
## headless-safe, no state.


## The cell nearest the region CENTRE that belongs to the LARGEST reachable open area — the player
## spawns here (not the top-left corner) so every direction is usable immediately and the camera
## frames the player mid-region. Selecting from the biggest 4-connected walkable component (not just
## any walkable tile) keeps the spawn in the navigable field and OUT of a SEALED set-piece room — a
## DungeonAssembler room is stamped with a wall ring and no doorway, so a spawn inside its isolated
## interior could move around the room but never leave, soft-locking the run.
static func spawn_cell(layout: Layout) -> Vector2i:
	var field := largest_open_component(layout)
	if field.is_empty():
		return first_walkable_cell(layout)
	var cx := layout.width / 2
	var cy := layout.height / 2
	var best := Vector2i(-1, -1)
	var best_d := 1 << 30
	for cell: Vector2i in field:
		var d := (cell.x - cx) * (cell.x - cx) + (cell.y - cy) * (cell.y - cy)
		if d < best_d:
			best_d = d
			best = cell
	return best if best.x >= 0 else first_walkable_cell(layout)


## Pick `count` walkable cells near `home` (manhattan radius 2..7), deterministic, skipping the
## home cell itself — the NPC placement ring (moved from overworld_screen for the line cap).
## Anchoring on the CANONICAL spawn keeps the cast put across battles and reloads. `blocked`
## (W-DRESS) is the screen-local structure occupancy set — no soul spawns inside a temple wall.
static func npc_cells(
	layout: Layout, home: Vector2i, count: int, blocked: Dictionary = {}
) -> Array:
	var found: Array = []
	# Ring search out to the full region span (W16b: the cast grew to 16 with Act-0) —
	# early NPCs keep their exact historical cells; only the overflow walks further out.
	for radius in range(2, 16):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if abs(dx) + abs(dy) != radius:
					continue
				var c := home + Vector2i(dx, dy)
				if c == home or found.has(c) or blocked.has(c):
					continue
				if not layout.in_bounds(c.x, c.y):
					continue
				if OverworldTileSet.is_walkable(layout.get_cell(c.x, c.y)):
					found.append(c)
					if found.size() >= count:
						return found
	return found


## The first walkable cell scanning row-major; falls back to (0,0) if the layout is somehow all
## walls (the authored fallback guarantees an interior floor, so this is defensive).
static func first_walkable_cell(layout: Layout) -> Vector2i:
	for y in layout.height:
		for x in layout.width:
			if OverworldTileSet.is_walkable(layout.get_cell(x, y)):
				return Vector2i(x, y)
	return Vector2i.ZERO


## The cells of the LARGEST 4-connected component of walkable tiles — the main reachable field. A
## flood fill seeded from every unvisited walkable cell; the biggest basin wins (sealed rooms and
## other islands are smaller, so they lose). Empty only if the layout has no walkable tile at all.
static func largest_open_component(layout: Layout) -> Array[Vector2i]:
	var visited := {}
	var best: Array[Vector2i] = []
	for y in layout.height:
		for x in layout.width:
			var start := Vector2i(x, y)
			if visited.has(start) or not OverworldTileSet.is_walkable(layout.get_cell(x, y)):
				continue
			var component := _flood_open(layout, start, visited)
			if component.size() > best.size():
				best = component
	return best


## Flood fill (4-connected, matching the cardinal grid steps of try_move) of the walkable region
## containing `start`, marking every reached cell in the shared `visited` set so each cell is
## scanned once across the whole sweep. Returns the cells of that one component.
static func _flood_open(layout: Layout, start: Vector2i, visited: Dictionary) -> Array[Vector2i]:
	var component: Array[Vector2i] = []
	var queue: Array[Vector2i] = [start]
	visited[start] = true
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		component.append(cell)
		for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := cell + step
			if visited.has(n) or not layout.in_bounds(n.x, n.y):
				continue
			if not OverworldTileSet.is_walkable(layout.get_cell(n.x, n.y)):
				continue
			visited[n] = true
			queue.append(n)
	return component
