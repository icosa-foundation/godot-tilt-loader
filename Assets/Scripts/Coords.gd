class_name Coords
extends RefCounted

static func as_room(node: Node3D) -> TrTransform:
	return TrTransform.from_global_node(node)

static func as_global(node: Node3D) -> TrTransform:
	return TrTransform.from_global_node(node)

static func as_local(node: Node3D) -> TrTransform:
	return TrTransform.from_local_node(node)

static func apply_local(node: Node3D, xf: TrTransform) -> void:
	xf.to_local_node(node)

static func get_global_uniform_scale(node: Node3D) -> float:
	var uniform_scale := node.scale.x
	var parent := node.get_parent()
	while parent is Node3D:
		uniform_scale *= (parent as Node3D).scale.x
		parent = parent.get_parent()
	return uniform_scale

static func set_global_uniform_scale(node: Node3D, uniform_scale: float) -> void:
	var local_scale := uniform_scale
	var parent := node.get_parent()
	if parent is Node3D:
		local_scale /= get_global_uniform_scale(parent as Node3D)
	node.scale = Vector3.ONE * local_scale
