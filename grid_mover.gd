extends Node2D
class_name GridMover

signal tile_entered(cell: Vector2i)

var tile := Vector2i.ZERO
var direction := Vector2i.ZERO
var queued_direction := Vector2i.ZERO
var progress := 0.0


func setup(start: Vector2i, maze) -> void:
	tile = start
	direction = Vector2i.ZERO
	queued_direction = Vector2i.ZERO
	progress = 0.0
	position = maze.cell_center(tile)


func reset_to(start: Vector2i, maze) -> void:
	setup(start, maze)


func queue_direction(next_direction: Vector2i) -> void:
	if next_direction != Vector2i.ZERO:
		queued_direction = next_direction


func advance(delta: float, move_speed: float, maze) -> void:
	var distance_left := move_speed * delta
	var safety := 0
	while distance_left > 0.001 and safety < 20:
		if progress <= 0.001:
			progress = 0.0
			if queued_direction != Vector2i.ZERO and maze.is_open(tile + queued_direction):
				direction = queued_direction
				queued_direction = Vector2i.ZERO
			if direction == Vector2i.ZERO or not maze.is_open(tile + direction):
				direction = Vector2i.ZERO
				return

		var step_distance := minf(distance_left, float(maze.tile_size) - progress)
		position += Vector2(direction) * step_distance
		progress += step_distance
		distance_left -= step_distance
		if progress >= float(maze.tile_size) - 0.001:
			tile += direction
			position = maze.cell_center(tile)
			progress = 0.0
			tile_entered.emit(tile)
		safety += 1