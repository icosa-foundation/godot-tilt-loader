class_name QuadStripUnitizedUVBrush
extends QuadStripBrush

func update_uvs(quad0: int, quad1: int, _size: float) -> void:
	var quads_created := quad1 - quad0
	var quads_per_solid := 2 if m_EnableBackfaces else 1
	for offset in range(quads_created, 0, -quads_per_solid):
		var index := (quad1 - offset) * 6
		m_Geometry.m_UVs[index] = Vector2(0.0, 1.0)
		m_Geometry.m_UVs[index + 1] = Vector2(1.0, 1.0)
		m_Geometry.m_UVs[index + 2] = Vector2(0.0, 0.0)
		m_Geometry.m_UVs[index + 3] = Vector2(0.0, 0.0)
		m_Geometry.m_UVs[index + 4] = Vector2(1.0, 1.0)
		m_Geometry.m_UVs[index + 5] = Vector2(1.0, 0.0)
	BaseBrushScript.compute_tangent_space_for_quads(
		m_Geometry.m_Vertices,
		m_Geometry.m_UVs,
		m_Geometry.m_Normals,
		m_Geometry.m_Tangents,
		quads_per_solid * 6,
		quad0 * 6,
		quad1 * 6
	)
	if m_EnableBackfaces:
		for offset in range(quads_created, 0, -quads_per_solid):
			var index := (quad1 - offset) * 6
			BaseBrushScript.mirror_quad_face(m_Geometry.m_UVs, index)
			BaseBrushScript.mirror_tangents(m_Geometry.m_Tangents, index)

func update_uvs_for_quad(_quad_index: int) -> void:
	pass

func update_uvs_for_segment(_segment_back: int, _segment_front: int, _size: float) -> void:
	pass
