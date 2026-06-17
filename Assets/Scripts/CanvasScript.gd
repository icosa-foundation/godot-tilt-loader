class_name CanvasScript
extends Node3D

func pose() -> TrTransform:
	return Coords.as_global(self)

func clear_canvas() -> void:
	var child_count := get_child_count()
	print("Clearing canvas: removing %d strokes" % child_count)
	for index in range(child_count - 1, -1, -1):
		get_child(index).queue_free()
