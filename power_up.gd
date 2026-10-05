extends "res://collectible.gd"
class_name MazePowerUp

var duration: float


func _init(cell: Vector2i, seconds: float = 7.0) -> void:
	super(cell, &"power")
	duration = seconds