extends RefCounted
class_name MazeCollectible

var tile: Vector2i
var kind: StringName


func _init(cell: Vector2i, item_kind: StringName = &"pellet") -> void:
	tile = cell
	kind = item_kind