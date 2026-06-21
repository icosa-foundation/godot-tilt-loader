class_name QuadStripBrushStretchUV
extends QuadStripBrush

var m_StoreWidthInTexcoord0Z := false
var m_QuadLengths: Array[float] = []
var _uv_request_back := -1
var _uv_request_front := -1

func init_brush(desc: BrushDescriptor, local_pointer_xf: TrTransform) -> void:
	super.init_brush(desc, local_pointer_xf)
	m_QuadLengths.resize(m_NumQuads)
	for index in range(m_QuadLengths.size()):
		m_QuadLengths[index] = 0.0
	clear_update_uv_request()

func get_vertex_layout(_desc: BrushDescriptor) -> GeometryPool.VertexLayout:
	var size: int = 3 if m_StoreWidthInTexcoord0Z else 2
	var semantic: GeometryPool.Semantic = GeometryPool.Semantic.XY_IS_UV_Z_IS_DISTANCE if m_StoreWidthInTexcoord0Z else GeometryPool.Semantic.XY_IS_UV
	return GeometryPool.VertexLayout.create(
		GeometryPool.TexcoordInfo.create(size, semantic),
		GeometryPool.TexcoordInfo.create(),
		null,
		true,
		true,
		true
	)

func clear_update_uv_request() -> void:
	_uv_request_back = -1
	_uv_request_front = -1

func has_update_uv_request() -> bool:
	return _uv_request_back != -1

func update_uvs_for_quad(quad_index: int) -> void:
	var quad_len := quad_length(m_Geometry.m_Vertices, quad_index)
	m_QuadLengths[quad_index] = quad_len
	if m_EnableBackfaces:
		m_QuadLengths[quad_index + 1] = quad_len

func update_uvs_for_segment(segment_back: int, segment_front: int, _size: float) -> void:
	if has_update_uv_request() and _uv_request_back != segment_back:
		flush_update_uv_request()
	if has_update_uv_request():
		segment_front = max(segment_front, _uv_request_front)
	_uv_request_back = segment_back
	_uv_request_front = segment_front

func apply_changes_to_visuals() -> void:
	flush_update_uv_request()
	super.apply_changes_to_visuals()

func flush_update_uv_request() -> void:
	if not has_update_uv_request():
		return
	var segment_back := _uv_request_back
	var segment_front := _uv_request_front
	clear_update_uv_request()
	var quads_per_solid := 2 if m_EnableBackfaces else 1
	var num_solids := int((segment_front - segment_back) / quads_per_solid)
	var random01 := m_rng.in01(segment_back * 6)
	var num_v: int = max(m_Desc.m_TextureAtlasV, 1)
	var atlas := int(random01 * num_v)
	var y_start := atlas / float(num_v)
	var y_end := (atlas + 1) / float(num_v)
	var segment_length := 0.0
	for solid in range(num_solids):
		segment_length += m_QuadLengths[segment_back + solid * quads_per_solid]
	if segment_length == 0.0:
		segment_length = 1.0
	var running := 0.0
	for solid in range(num_solids):
		var quad_index := segment_back + solid * quads_per_solid
		var vert_index := quad_index * 6
		var solid_length_value := m_QuadLengths[quad_index]
		var x_start := running / segment_length
		var x_end := (running + solid_length_value) / segment_length
		running += solid_length_value
		m_Geometry.m_UVs[vert_index] = Vector2(x_start, y_start)
		m_Geometry.m_UVs[vert_index + 1] = Vector2(x_end, y_start)
		m_Geometry.m_UVs[vert_index + 2] = Vector2(x_start, y_end)
		m_Geometry.m_UVs[vert_index + 3] = Vector2(x_start, y_end)
		m_Geometry.m_UVs[vert_index + 4] = Vector2(x_end, y_start)
		m_Geometry.m_UVs[vert_index + 5] = Vector2(x_end, y_end)
		if m_StoreWidthInTexcoord0Z:
			for offset in range(6):
				m_Geometry.m_UVWs[vert_index + offset] = Vector3(m_Geometry.m_UVs[vert_index + offset].x, m_Geometry.m_UVs[vert_index + offset].y, 0.0)
	BaseBrushScript.compute_tangent_space_for_quads(
		m_Geometry.m_Vertices,
		m_Geometry.m_UVs,
		m_Geometry.m_Normals,
		m_Geometry.m_Tangents,
		quads_per_solid * 6,
		segment_back * 6,
		segment_front * 6
	)
	if m_StoreWidthInTexcoord0Z:
		for solid in range(num_solids):
			var quad_index := segment_back + solid * quads_per_solid
			var vert_index := quad_index * 6
			var width := m_Geometry.m_Vertices[vert_index].distance_to(m_Geometry.m_Vertices[vert_index + 2])
			for offset in range(6):
				var uvw := m_Geometry.m_UVWs[vert_index + offset]
				uvw.z = width
				m_Geometry.m_UVWs[vert_index + offset] = uvw
	if m_EnableBackfaces:
		for solid in range(num_solids):
			var vert_index := (segment_back + solid * quads_per_solid) * 6
			BaseBrushScript.mirror_quad_face(m_Geometry.m_UVWs if m_StoreWidthInTexcoord0Z else m_Geometry.m_UVs, vert_index)
			BaseBrushScript.mirror_tangents(m_Geometry.m_Tangents, vert_index)

func update_uvs(quad0: int, quad1: int, size: float) -> void:
	var quads_per := 2 if m_EnableBackfaces else 1
	for quad in range(quad0, quad1, quads_per):
		update_uvs_for_quad(quad)
	update_uvs_for_segment(m_InitialQuadIndex, quad1, size)

func finalize_solitary_brush() -> void:
	flush_update_uv_request()
	super.finalize_solitary_brush()
