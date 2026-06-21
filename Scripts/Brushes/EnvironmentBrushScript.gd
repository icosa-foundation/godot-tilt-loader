class_name EnvironmentBrushScript
extends BaseBrushScript

enum UvSetCount {
	ONE,
	TWO,
}

var m_UvSetCount := UvSetCount.ONE

func _init() -> void:
	setup_base(true)

func get_vertex_layout(_desc: BrushDescriptor) -> GeometryPool.VertexLayout:
	return GeometryPool.VertexLayout.create(
		GeometryPool.TexcoordInfo.create(2, GeometryPool.Semantic.XY_IS_UV),
		GeometryPool.TexcoordInfo.create(2, GeometryPool.Semantic.XY_IS_UV) if m_UvSetCount == UvSetCount.TWO else GeometryPool.TexcoordInfo.create(0, GeometryPool.Semantic.XY_IS_UV),
		null,
		true,
		true,
		false
	)

func update_position_impl(_position: Vector3, _orientation: Quaternion, _pressure: float) -> bool:
	return true

func get_num_used_verts() -> int:
	return 0

func get_spawn_interval(_pressure01: float) -> float:
	return 0.0

func init_undo_clone(_clone: Node3D) -> void:
	pass

func finalize_solitary_brush() -> void:
	pass

func finalize_batched_brush() -> void:
	pass

func apply_changes_to_visuals() -> void:
	pass
