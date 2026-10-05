extends "res://grid_mover.gd"
class_name MazePlayer

@export var player_speed := 142.0


func set_movement_input(next_direction: Vector2i) -> void:
	queue_direction(next_direction)


func move_player(delta: float, maze) -> void:
	advance(delta, player_speed, maze)