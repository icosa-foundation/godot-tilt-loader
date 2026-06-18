class_name ListUtils
extends RefCounted

static func set_count(array: Array, new_count: int, default_value: Variant = null) -> void:
	if new_count < array.size():
		array.resize(new_count)
		return
	while array.size() < new_count:
		array.append(default_value)

static func add_range(array: Array, source: Array, start: int, length: int) -> void:
	var end := start + length
	if end < start or end > source.size():
		push_error("bad range")
		return
	for index in range(start, end):
		array.append(source[index])

static func copy_subrange(source: Array, start: int, length: int) -> Array:
	var output := []
	add_range(output, source, start, length)
	return output
