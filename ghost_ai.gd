extends "res://grid_mover.gd"
class_name HunterGhost

const CHASE: StringName = &"CHASE"
const AMBUSH: StringName = &"AMBUSH"
const SEARCH: StringName = &"SEARCH"
const FRIGHTENED: StringName = &"FRIGHTENED"
const RETURN: StringName = &"RETURN"
const RESUME: StringName = &"RESUME"

@export var ghost_speed := 116.0
@export var path_recalculation_interval := 0.42
@export_range(0.0, 1.0) var aggression := 0.48
@export_range(0.0, 1.0) var randomness := 0.22
@export var prediction_distance := 2.0
@export var search_duration := 3.6
@export var frightened_duration := 7.0

signal state_changed(previous_state: StringName, next_state: StringName)

var ai_state: StringName = CHASE
var home_tile := Vector2i(9, 7)
var route: Array[Vector2i] = []
var route_clock := 0.0
var state_clock := 0.0
var unseen_clock := 0.0
var last_seen_tile := Vector2i(1, 1)
var search_target := Vector2i(1, 1)
var prediction_tiles := 0


func setup(start: Vector2i, maze) -> void:
	super.setup(start, maze)
	home_tile = start
	ai_state = CHASE
	route.clear()
	route_clock = 0.0
	state_clock = 0.0
	unseen_clock = 0.0
	last_seen_tile = start
	search_target = start


func reset_ai(maze) -> void:
	reset_to(home_tile, maze)
	ai_state = CHASE
	route.clear()
	route_clock = 0.0
	state_clock = 0.0
	unseen_clock = 0.0


func trigger_frightened(seconds: float = -1.0) -> void:
	state_clock = frightened_duration if seconds < 0.0 else seconds
	_set_state(FRIGHTENED)
	route.clear()
	route_clock = 0.0


func catch_ghost() -> void:
	_set_state(RETURN)
	route.clear()
	route_clock = 0.0


func update_brain(delta: float, maze, player_tile: Vector2i, player_direction: Vector2i, level: int, aggression_mod := 0.0) -> void:
	if ai_state == FRIGHTENED:
		state_clock -= delta
		if state_clock <= 0.0:
			_set_state(RESUME)
			state_clock = 0.72
	elif ai_state == RESUME:
		state_clock -= delta
		if state_clock <= 0.0:
			_set_state(CHASE)
			route_clock = 0.0
	elif ai_state != RETURN:
		if maze.has_line_of_sight(tile, player_tile):
			last_seen_tile = player_tile
			unseen_clock = 0.0
			if ai_state == SEARCH:
				_set_state(CHASE)
				route_clock = 0.0
		else:
			unseen_clock += delta
			if unseen_clock >= search_duration and ai_state != SEARCH:
				_set_state(SEARCH)
				search_target = last_seen_tile
				state_clock = 2.4
				route_clock = 0.0

	route_clock -= delta
	if route_clock <= 0.0 or (progress <= 0.001 and route.is_empty()):
		_recalculate_route(maze, player_tile, player_direction, level, aggression_mod)
	if route.size() > 1:
		queue_direction(route[1] - tile)

	var speed := ghost_speed + minf(float(level - 1), 10.0) * 5.0 + aggression_mod * 70.0
	if ai_state == FRIGHTENED:
		speed *= 0.76
	elif ai_state == RETURN:
		speed *= 1.34
	advance(delta, speed, maze)

	if ai_state == RETURN and tile == home_tile and progress <= 0.001:
		_set_state(RESUME)
		state_clock = 0.62
		route.clear()
		route_clock = 0.0
	if ai_state == SEARCH:
		state_clock -= delta
		if state_clock <= 0.0 or (tile == search_target and progress <= 0.001):
			search_target = _choose_search_point(maze, last_seen_tile)
			state_clock = 1.8
			route_clock = 0.0


func _recalculate_route(maze, player_tile: Vector2i, player_direction: Vector2i, level: int, aggression_mod: float = 0.0) -> void:
	var target := player_tile
	if ai_state == RETURN:
		target = home_tile
	elif ai_state == SEARCH:
		target = search_target
	elif ai_state == FRIGHTENED:
		target = _escape_target(maze, player_tile)
	else:
		var ambush_chance := clampf(aggression + float(level - 1) * 0.025 + aggression_mod, 0.0, 0.82)
		if ai_state != RESUME and player_direction != Vector2i.ZERO and randf() < ambush_chance:
			_set_state(AMBUSH)
			target = _predicted_tile(maze, player_tile, player_direction, level, aggression_mod)
		elif ai_state != RESUME:
			_set_state(CHASE)
			target = player_tile
		else:
			target = player_tile

	var mistake_chance := maxf(0.02, randomness / (1.0 + float(level - 1) * 0.35) - aggression_mod)
	if ai_state == CHASE and randf() < mistake_chance:
		var exits: Array[Vector2i] = maze.open_neighbors(tile)
		if exits.size() > 1:
			target = exits[randi_range(0, exits.size() - 1)]

	route = maze.find_path(tile, target)
	if route.is_empty() and target != home_tile:
		route = maze.find_path(tile, player_tile)
	route_clock = maxf(0.16, path_recalculation_interval - float(level - 1) * 0.022)


func _predicted_tile(maze, player_tile: Vector2i, player_direction: Vector2i, level: int, aggression_mod: float = 0.0) -> Vector2i:
	var requested := clampi(roundi(prediction_distance + float(level - 1) * 0.22 + aggression_mod * 5.0), 1, 5)
	prediction_tiles = requested
	var predicted := player_tile
	for _step in range(requested):
		var next_cell: Vector2i = predicted + player_direction
		if not maze.is_open(next_cell):
			break
		predicted = next_cell
	return predicted


func _escape_target(maze, player_tile: Vector2i) -> Vector2i:
	var exits: Array[Vector2i] = maze.open_neighbors(tile)
	if exits.is_empty():
		return tile
	var best_cell: Vector2i = exits[0]
	var best_distance := -1
	for cell in exits:
		var distance := absi(cell.x - player_tile.x) + absi(cell.y - player_tile.y)
		if distance > best_distance:
			best_distance = distance
			best_cell = cell
	return best_cell


func _choose_search_point(maze, from_cell: Vector2i) -> Vector2i:
	var best_cell := from_cell
	var best_distance := -1
	for y in range(1, maze.height - 1):
		for x in range(1, maze.width - 1):
			var candidate := Vector2i(x, y)
			if not maze.is_open(candidate):
				continue
			var distance := absi(x - from_cell.x) + absi(y - from_cell.y)
			if distance > best_distance and not maze.find_path(tile, candidate).is_empty():
				best_distance = distance
				best_cell = candidate
	return best_cell


func _set_state(next_state: StringName) -> void:
	if next_state == ai_state:
		return
	var previous := ai_state
	ai_state = next_state
	state_changed.emit(previous, next_state)


func path_length() -> int:
	return maxi(0, route.size() - 1)