## Grid A* pathfinding and line-of-sight waypoint smoothing over battlefield terrain.
##
## Operates over the 28 x 42 terrain cells (1,176 nodes).
## Edge cost is cell distance / speed_factor; impassable cells (deep water, rocks) have infinite cost.
extends RefCounted

const Terrain = preload("res://scripts/battle/terrain.gd")


class MinHeap:
	var idx := PackedInt32Array()
	var f := PackedFloat32Array()

	func push(i: int, score: float) -> void:
		idx.append(i)
		f.append(score)
		_up(idx.size() - 1)

	func pop() -> int:
		var top := idx[0]
		var last := idx.size() - 1
		idx[0] = idx[last]
		f[0] = f[last]
		idx.resize(last)
		f.resize(last)
		if last > 0:
			_down(0)
		return top

	func is_empty() -> bool:
		return idx.is_empty()

	func _swap(a: int, b: int) -> void:
		var ti := idx[a]
		idx[a] = idx[b]
		idx[b] = ti
		var tf := f[a]
		f[a] = f[b]
		f[b] = tf

	func _up(i: int) -> void:
		while i > 0:
			var p := (i - 1) >> 1
			if f[i] < f[p]:
				_swap(i, p)
				i = p
			else:
				break

	func _down(i: int) -> void:
		var n := idx.size()
		while true:
			var l := (i << 1) + 1
			var r := l + 1
			var best := i
			if l < n and f[l] < f[best]:
				best = l
			if r < n and f[r] < f[best]:
				best = r
			if best == i:
				break
			_swap(i, best)
			i = best


## Find a sequence of world waypoints from `start` to `goal`.
## Returns [goal] if direct line of sight is clear or terrain is empty.
static func find_path(terrain: Terrain, start: Vector2, goal: Vector2, mounted: bool = false) -> Array:
	if terrain == null:
		return [goal]

	# Fast-path: direct line of sight with no impassable cells
	if has_line_of_sight(terrain, start, goal):
		return [goal]

	var c_start := terrain.cell_coords(start)
	var c_goal := terrain.cell_coords(goal)

	# If start or goal are in impassable cells, find nearest passable cells
	c_start = _nearest_passable_cell(terrain, c_start)
	c_goal = _nearest_passable_cell(terrain, c_goal)

	if c_start == c_goal:
		return [goal]
	if terrain.foot_speed.is_empty():
		terrain.bake()

	var total_cells := Terrain.TOTAL_CELLS
	var g_score := PackedFloat32Array()
	g_score.resize(total_cells)
	g_score.fill(INF)

	var came_from := PackedInt32Array()
	came_from.resize(total_cells)
	came_from.fill(-1)

	var closed := PackedByteArray()
	closed.resize(total_cells)
	closed.fill(0)

	var start_idx := c_start.y * Terrain.COLS + c_start.x
	var goal_idx := c_goal.y * Terrain.COLS + c_goal.x

	g_score[start_idx] = 0.0
	var heap := MinHeap.new()
	heap.push(start_idx, _heuristic(c_start.x, c_start.y, c_goal.x, c_goal.y))

	var dirs := [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)
	]

	var reached := false

	while not heap.is_empty():
		var curr_idx := heap.pop()
		if curr_idx == goal_idx:
			reached = true
			break
		if closed[curr_idx] == 1:
			continue
		closed[curr_idx] = 1

		var cx := curr_idx % Terrain.COLS
		var cy := curr_idx / Terrain.COLS
		var curr_g := g_score[curr_idx]
		var cost_curr := _cell_cost(terrain, cx, cy, mounted)

		for d in dirs:
			var nx: int = cx + d.x
			var ny: int = cy + d.y
			if nx < 0 or nx >= Terrain.COLS or ny < 0 or ny >= Terrain.ROWS:
				continue
			var n_idx: int = ny * Terrain.COLS + nx
			if closed[n_idx] == 1:
				continue
			if not terrain.passable_cell(nx, ny):
				continue

			# Corner cutting check for diagonal movements
			if d.x != 0 and d.y != 0:
				if not terrain.passable_cell(cx + d.x, cy) or not terrain.passable_cell(cx, cy + d.y):
					continue

			var cost_next := _cell_cost(terrain, nx, ny, mounted)
			if is_inf(cost_next):
				continue

			var dist_mult := 1.41421356 if (d.x != 0 and d.y != 0) else 1.0
			var step_cost := dist_mult * (cost_curr + cost_next) * 0.5 * Terrain.CELL
			var tentative_g := curr_g + step_cost

			if tentative_g < g_score[n_idx]:
				g_score[n_idx] = tentative_g
				came_from[n_idx] = curr_idx
				var h := _heuristic(nx, ny, c_goal.x, c_goal.y)
				heap.push(n_idx, tentative_g + h)

	if not reached:
		return [goal]

	# Reconstruct path of cell centers
	var raw_points: Array = []
	var curr := goal_idx
	while curr != -1:
		var rx := curr % Terrain.COLS
		var ry := curr / Terrain.COLS
		raw_points.append(terrain.cell_pos(rx, ry))
		if curr == start_idx:
			break
		curr = came_from[curr]

	raw_points.reverse()

	# String pulling: from each corner, walk on along the path for as long as the way from
	# the corner stays clear, and turn only where it doesn't.
	var waypoints: Array = []
	var check_from := start
	var i := 0
	while i < raw_points.size():
		var furthest := i
		while furthest + 1 < raw_points.size() and has_line_of_sight(terrain, check_from, raw_points[furthest + 1]):
			furthest += 1
		var pt: Vector2 = raw_points[furthest]
		waypoints.append(pt)
		check_from = pt
		i = furthest + 1

	if waypoints.is_empty() or not has_line_of_sight(terrain, waypoints[-1], goal):
		waypoints.append(goal)
	else:
		waypoints[-1] = goal

	return waypoints


## Raycast across grid cells to verify line of sight with no impassable cells.
static func has_line_of_sight(terrain: Terrain, p0: Vector2, p1: Vector2) -> bool:
	var dist := p0.distance_to(p1)
	if dist < 1.0:
		return terrain.passable(p0) and terrain.passable(p1)
	var steps := maxi(1, int(ceil(dist / (Terrain.CELL * 0.4))))
	for i in range(0, steps + 1):
		var p := p0.lerp(p1, float(i) / float(steps))
		if not terrain.passable(p):
			return false
	return true


static func _cell_cost(terrain: Terrain, cx: int, cy: int, mounted: bool) -> float:
	var i := cy * Terrain.COLS + cx
	var sf: float = terrain.horse_speed[i] if mounted else terrain.foot_speed[i]
	if sf <= 0.01:
		return INF
	return 1.0 / sf


static func _heuristic(cx: int, cy: int, gx: int, gy: int) -> float:
	var dx := absf(float(cx - gx))
	var dy := absf(float(cy - gy))
	var d_min := minf(dx, dy)
	var d_max := maxf(dx, dy)
	return (d_min * 1.41421356 + (d_max - d_min)) * Terrain.CELL


static func _nearest_passable_cell(terrain: Terrain, c: Vector2i) -> Vector2i:
	if terrain.passable_cell(c.x, c.y):
		return c
	for r in range(1, 10):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var nx := c.x + dx
				var ny := c.y + dy
				if terrain.passable_cell(nx, ny):
					return Vector2i(nx, ny)
	return c
