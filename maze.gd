extends RefCounted
class_name MazeGrid

const WALL := 0
const FLOOR := 1

const COLLECTIBLE_SCRIPT := preload("res://collectible.gd")
const POWER_UP_SCRIPT := preload("res://power_up.gd")

signal collectible_collected(kind: StringName, cell: Vector2i, duration: float)

var width := 19
var height := 15
var tile_size := 32
var origin := Vector2(176, 96)
var tiles: Array = []
var collectibles: Dictionary = {}
var player_start := Vector2i(1, 1)
var ghost_home := Vector2i(9, 7)


func build(level: int) -> void:
	tiles.clear()
	collectibles.clear()
	for y in range(height):
		var row: Array[int] = []
		for x in range(width):
			row.append(WALL if x == 0 or y == 0 or x == width - 1 or y == height - 1 else FLOOR)
		tiles.append(row)

	var horizontal_bars := [
		{"y": 3, "holes": [5, 9, 13]},
		{"y": 6, "holes": [3, 7, 11, 15]},
		{"y": 8, "holes": [5, 9, 13]},
		{"y": 11, "holes": [3, 7, 11, 15]},
	]
	var opening_shift := posmod(level - 1, 3) - 1
	for bar in horizontal_bars:
		for x in range(2, width - 2):
			var has_opening := false
			for opening in bar["holes"]:
				if x == int(opening) + opening_shift:
					has_opening = true
					break
			if not has_opening:
				_set_wall(Vector2i(x, bar["y"]))

	var vertical_bars := [
		{"x": 4, "holes": [4, 7, 10]},
		{"x": 9, "holes": [3, 5, 9, 11]},
		{"x": 14, "holes": [4, 7, 10]},
	]
	for bar in vertical_bars:
		for y in range(2, height - 2):
			var has_opening := false
			for opening in bar["holes"]:
				if y == int(opening) + opening_shift:
					has_opening = true
					break
			if not has_opening:
				_set_wall(Vector2i(bar["x"], y))

	# Keep the central base open as a distinctive landmark and ghost spawn.
	for y in range(6, 9):
		for x in range(8, 11):
			_set_floor(Vector2i(x, y))
	for y in range(2, 5):
		_set_floor(Vector2i(9, y))
	_set_floor(player_start)
	_set_floor(ghost_home)
	_ensure_connected(player_start)

	var power_cells := [Vector2i(1, 13), Vector2i(17, 1), Vector2i(17, 13), Vector2i(1, 7)]
	for y in range(1, height - 1):
		for x in range(1, width - 1):
			var cell := Vector2i(x, y)
			if not is_open(cell) or cell == player_start or cell == ghost_home:
				continue
			if power_cells.has(cell):
				collectibles[cell] = POWER_UP_SCRIPT.new(cell, maxf(5.5, 7.0 - float(level - 1) * 0.12))
			else:
				collectibles[cell] = COLLECTIBLE_SCRIPT.new(cell)


func _ensure_connected(start: Vector2i) -> void:
	var reachable := _reachable_cells(start)
	for y in range(1, height - 1):
		for x in range(1, width - 1):
			var cell := Vector2i(x, y)
			if not is_open(cell) or reachable.has(cell):
				continue
			var cursor := cell
			while cursor.y > 1 and not reachable.has(cursor):
				cursor = Vector2i(cursor.x, cursor.y - 1)
				_set_floor(cursor)
			if not reachable.has(cursor):
				_set_floor(cursor)
			reachable = _reachable_cells(start)


func _reachable_cells(start: Vector2i) -> Dictionary:
	var reachable: Dictionary = {start: true}
	var frontier: Array[Vector2i] = [start]
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_back()
		for neighbor in open_neighbors(current):
			if not reachable.has(neighbor):
				reachable[neighbor] = true
				frontier.append(neighbor)
	return reachable


func _set_wall(cell: Vector2i) -> void:
	if _inside(cell):
		tiles[cell.y][cell.x] = WALL


func _set_floor(cell: Vector2i) -> void:
	if _inside(cell):
		tiles[cell.y][cell.x] = FLOOR


func _inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func is_open(cell: Vector2i) -> bool:
	return _inside(cell) and tiles[cell.y][cell.x] == FLOOR


func cell_center(cell: Vector2i) -> Vector2:
	return origin + (Vector2(cell) + Vector2(0.5, 0.5)) * tile_size


func open_neighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for step in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var candidate: Vector2i = cell + step
		if is_open(candidate):
			result.append(candidate)
	return result


func find_path(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not is_open(start) or not is_open(goal):
		return result
	if start == goal:
		result.append(start)
		return result

	var frontier: Array[Vector2i] = [start]
	var came_from: Dictionary = {}
	var cost_so_far: Dictionary = {start: 0}
	var estimated_total: Dictionary = {start: _manhattan(start, goal)}
	var visited: Dictionary = {}
	while not frontier.is_empty():
		var best_index := 0
		var best_score := float(estimated_total.get(frontier[0], INF))
		for index in range(1, frontier.size()):
			var score := float(estimated_total.get(frontier[index], INF))
			if score < best_score:
				best_score = score
				best_index = index
		var current: Vector2i = frontier.pop_at(best_index)
		if current == goal:
			var step := goal
			result.append(step)
			while step != start:
				step = came_from[step]
				result.push_front(step)
			return result
		visited[current] = true
		for neighbor in open_neighbors(current):
			if visited.has(neighbor):
				continue
			var new_cost := int(cost_so_far[current]) + 1
			if not cost_so_far.has(neighbor) or new_cost < int(cost_so_far[neighbor]):
				came_from[neighbor] = current
				cost_so_far[neighbor] = new_cost
				estimated_total[neighbor] = new_cost + _manhattan(neighbor, goal)
				if not frontier.has(neighbor):
					frontier.append(neighbor)
	return result


func has_line_of_sight(start: Vector2i, goal: Vector2i, max_distance: int = 7) -> bool:
	if start.x != goal.x and start.y != goal.y:
		return false
	if _manhattan(start, goal) > max_distance:
		return false
	var step := Vector2i(signi(goal.x - start.x), signi(goal.y - start.y))
	var cursor := start
	while cursor != goal:
		cursor += step
		if not is_open(cursor):
			return false
	return true


func collect_at(cell: Vector2i) -> StringName:
	if not collectibles.has(cell):
		return &""
	var item = collectibles[cell]
	collectibles.erase(cell)
	var duration: float = item.duration if item.kind == &"power" else 0.0
	collectible_collected.emit(item.kind, cell, duration)
	return item.kind


func _manhattan(first: Vector2i, second: Vector2i) -> int:
	return absi(first.x - second.x) + absi(first.y - second.y)