class_name QuadStripBrushDistanceUV
extends QuadStripBrush

const K_OPACITY_FADE_DISTANCE_METERS_PS := 0.025

var _tangent_request_back := -1
var _tangent_request_front := -1

func init_brush(desc: BrushDescriptor, local_pointer_xf: TrTransform) -> void:
	super.init_brush(desc, local_pointer_xf)
	clear_tangent_request()

func reset_brush_for_preview(local_pointer_xf: TrTransform) -> void:
	super.reset_brush_for_preview(local_pointer_xf)
	clear_tangent_request()

func clear_tangent_request() -> void:
	_tangent_request_back = -1
	_tangent_request_front = -1

func has_tangent_request() -> bool:
	return _tangent_request_back != -1

func update_uvs_for_segment(quad0: int, quad1: int, size: float) -> void:
	var fade_distance := K_OPACITY_FADE_DISTANCE_METERS_PS * App.METERS_TO_UNITS * pointer_to_local()
	var current_stride := stride()
	var quads_per_solid := 2 if m_EnableBackfaces else 1
	var solid0 := int(quad0 / quads_per_solid)
	var solid1 := int(quad1 / quads_per_solid)
	for solid in range(max(solid0, solid1 - 3), solid1):
		var vert := solid * current_stride
		var prev_u: float
		var prev_v0: float
		var prev_v1: float
		if solid == solid0:
			var random01 := m_rng.in01(solid0 * current_stride)
			prev_u = random01
			var num_v: int = m_Desc.m_TextureAtlasV
			var atlas: int = int(random01 * 3331.0) % num_v
			prev_v0 = atlas / float(num_v)
			prev_v1 = (atlas + 1) / float(num_v)
		else:
			prev_u = m_Geometry.m_UVs[vert - current_stride + 4].x
			prev_v0 = m_Geometry.m_UVs[vert - current_stride + 4].y
			prev_v1 = m_Geometry.m_UVs[vert - current_stride + 5].y
		var length := solid_length(m_Geometry.m_Vertices, solid)
		var next_u := prev_u + m_Desc.m_TileRate * (length / size)
		m_Geometry.m_UVs[vert] = Vector2(prev_u, prev_v0)
		m_Geometry.m_UVs[vert + 2] = Vector2(prev_u, prev_v1)
		m_Geometry.m_UVs[vert + 3] = Vector2(prev_u, prev_v1)
		m_Geometry.m_UVs[vert + 1] = Vector2(next_u, prev_v0)
		m_Geometry.m_UVs[vert + 4] = Vector2(next_u, prev_v0)
		m_Geometry.m_UVs[vert + 5] = Vector2(next_u, prev_v1)
		if m_EnableBackfaces:
			BaseBrushScript.mirror_quad_face(m_Geometry.m_UVs, vert)
	var total_dist := 0.0
	for solid in range(solid1 - 1, solid0 - 1, -1):
		var leading_a := _color32_alpha(min(1.0, total_dist / fade_distance))
		total_dist += solid_length(m_Geometry.m_Vertices, solid)
		var trailing_a := _color32_alpha(min(1.0, total_dist / fade_distance))
		if solid == solid0:
			trailing_a = 0.0
		var vert := solid * current_stride
		var trailing_color := m_Geometry.m_Colors[vert]
		trailing_color.a = trailing_a
		m_Geometry.m_Colors[vert] = trailing_color
		m_Geometry.m_Colors[vert + 2] = trailing_color
		m_Geometry.m_Colors[vert + 3] = trailing_color
		var leading_color := m_Geometry.m_Colors[vert + 1]
		leading_color.a = leading_a
		m_Geometry.m_Colors[vert + 1] = leading_color
		m_Geometry.m_Colors[vert + 4] = leading_color
		m_Geometry.m_Colors[vert + 5] = leading_color
		if m_EnableBackfaces:
			BaseBrushScript.mirror_quad_face(m_Geometry.m_Colors, vert)
		if solid != solid0 and is_equal_approx(m_Geometry.m_Colors[vert - 6 + 5].a, trailing_a):
			break
	lazy_update_tangents_for_segment(quad0, quad1)

func apply_changes_to_visuals() -> void:
	flush_tangent_request()
	super.apply_changes_to_visuals()

func finalize_batched_brush() -> void:
	flush_tangent_request()
	super.finalize_batched_brush()

func lazy_update_tangents_for_segment(quad0: int, quad1: int) -> void:
	if has_tangent_request() and _tangent_request_back != quad0:
		flush_tangent_request()
	if has_tangent_request():
		quad1 = max(quad1, _tangent_request_front)
	_tangent_request_back = quad0
	_tangent_request_front = quad1

func flush_tangent_request() -> void:
	if not has_tangent_request():
		return
	var quads_per_solid := 2 if m_EnableBackfaces else 1
	var solid0 := int(_tangent_request_back / quads_per_solid)
	var solid1 := int(_tangent_request_front / quads_per_solid)
	clear_tangent_request()
	BaseBrushScript.compute_tangent_space_for_quads(
		m_Geometry.m_Vertices,
		m_Geometry.m_UVs,
		m_Geometry.m_Normals,
		m_Geometry.m_Tangents,
		stride(),
		solid0 * stride(),
		solid1 * stride()
	)
	if m_EnableBackfaces:
		for solid in range(solid0, solid1):
			BaseBrushScript.mirror_tangents(m_Geometry.m_Tangents, solid * stride())

func update_uvs(quad0: int, quad1: int, size: float) -> void:
	update_uvs_for_segment(m_InitialQuadIndex, quad1, size)

func update_uvs_for_quad(_quad_index: int) -> void:
	pass
