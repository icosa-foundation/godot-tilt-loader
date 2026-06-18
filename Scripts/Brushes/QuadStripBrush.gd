class_name QuadStripBrush
extends BaseBrushScript

const K_PRESSURE_SMOOTH_WINDOW_METERS_PS := 0.20
const K_SOLID_MIN_LENGTH_METERS_PS := 0.0015
const K_MINIMUM_MOVE_LENGTH_METERS_PS := 5e-4
const K_SOLID_ASPECT_RATIO := 0.2

var m_Geometry: MasterBrush
var m_LastFacing := Vector3.ZERO
var m_LastQuadCenter := Vector3.ZERO
var m_LastQuadForward := Vector3.ZERO
var m_LastQuadRight := Vector3.ZERO
var m_LastQuadNormal := Vector3.ZERO
var m_LastSegmentLengthSolids := 0
var m_LastSpawnPressure := 0.0
var m_LastSizeShrink := 0.0
var m_NumQuads := 0
var m_LeadingQuadIndex := 0
var m_InitialQuadIndex := 0
var m_AllowStripBreak := true
var m_LeadingSegmentInitialQuadIndex: Variant = null

func _init() -> void:
	setup_base(true)

func stride() -> int:
	return 6 * (2 if m_EnableBackfaces else 1)

func get_spawn_interval(pressure01: float) -> float:
	return K_SOLID_MIN_LENGTH_METERS_PS * App.METERS_TO_UNITS * pointer_to_local() + pressured_size(pressure01) * K_SOLID_ASPECT_RATIO

func get_num_used_verts() -> int:
	var quads_per_solid := 2 if m_EnableBackfaces else 1
	var leading_segment_length := 0 if m_LeadingSegmentInitialQuadIndex == null else m_LeadingQuadIndex - int(m_LeadingSegmentInitialQuadIndex)
	var solid_adjustment := 1
	if leading_segment_length == 0:
		solid_adjustment = 0
		if m_LastSegmentLengthSolids == 1:
			solid_adjustment = -1
	elif leading_segment_length == quads_per_solid:
		solid_adjustment = -1
	return (m_LeadingQuadIndex + solid_adjustment * quads_per_solid) * 6

func always_rebuild_preview_brush() -> bool:
	return true

func reset_brush_for_preview(local_pointer_xf: TrTransform) -> void:
	super.reset_brush_for_preview(local_pointer_xf)
	var quads_per_solid := 2 if m_EnableBackfaces else 1
	m_Geometry.reset((m_LeadingQuadIndex + quads_per_solid) * 6)
	m_Geometry.set_vertex_layout(get_vertex_layout(m_Desc))
	m_LeadingQuadIndex = 0
	m_InitialQuadIndex = 0
	m_LastQuadRight = Vector3.ZERO

func init_brush(desc: BrushDescriptor, local_pointer_xf: TrTransform) -> void:
	super.init_brush(desc, local_pointer_xf)
	m_Geometry = MasterBrush.shared_pool.get_instance()
	m_Geometry.set_vertex_layout(get_vertex_layout(desc))
	m_LastQuadRight = Vector3.ZERO
	m_NumQuads = int(m_Geometry.num_verts() / 6)

func debug_get_geometry() -> Dictionary:
	return {
		"verts": m_Geometry.m_Vertices if m_Geometry != null else [],
		"nVerts": get_num_used_verts(),
		"uv0s": m_Geometry.m_UVs if m_Geometry != null else [],
		"tris": m_Geometry.m_Tris if m_Geometry != null else [],
		"nTris": get_num_used_verts()
	}

func get_vertex_layout(_desc: BrushDescriptor) -> GeometryPool.VertexLayout:
	return GeometryPool.VertexLayout.create(
		GeometryPool.TexcoordInfo.create(2, GeometryPool.Semantic.XY_IS_UV),
		GeometryPool.TexcoordInfo.create(),
		null,
		true,
		true,
		true
	)

func finalize_solitary_brush() -> void:
	var used_verts := get_num_used_verts()
	mesh_data.clear()
	if m_Geometry == null:
		return
	mesh_data.vertices.assign(m_Geometry.m_Vertices.slice(0, used_verts))
	mesh_data.triangles.assign(m_Geometry.m_Tris.slice(0, used_verts))
	mesh_data.normals.assign(m_Geometry.m_Normals.slice(0, used_verts))
	if m_Geometry.vertex_layout != null and m_Geometry.vertex_layout.texcoord0.size == 3:
		mesh_data.uv0_v3.assign(m_Geometry.m_UVWs.slice(0, used_verts))
	else:
		mesh_data.uv0_v2.assign(m_Geometry.m_UVs.slice(0, used_verts))
	mesh_data.colors.assign(m_Geometry.m_Colors.slice(0, used_verts))
	mesh_data.tangents.assign(m_Geometry.m_Tangents.slice(0, used_verts))
	MasterBrush.shared_pool.put(m_Geometry)
	m_Geometry = null

func should_discard() -> bool:
	return get_num_used_verts() <= 0

func append_leading_quad(generate_new: bool, opacity01: float, center: Vector3, forward: Vector3, normal: Vector3, right: Vector3) -> int:
	var verts := m_Geometry.m_Vertices
	var norms := m_Geometry.m_Normals
	var colors := m_Geometry.m_Colors
	var current_stride := stride()
	var vert_index := m_LeadingQuadIndex * 6
	position_quad(verts, vert_index, center, forward, right)
	for offset in range(6):
		norms[vert_index + offset] = normal
	var earliest_changed_quad := m_LeadingQuadIndex
	var color := m_Color
	color.a = opacity01
	var last_color := colors[vert_index - current_stride + 4] if vert_index - current_stride >= 0 else color
	colors[vert_index] = last_color
	colors[vert_index + 1] = color
	colors[vert_index + 2] = last_color
	colors[vert_index + 3] = last_color
	colors[vert_index + 4] = color
	colors[vert_index + 5] = color
	m_LeadingQuadIndex += 1
	if m_EnableBackfaces:
		var back_vert_index := m_LeadingQuadIndex * 6
		BaseBrushScript.create_duplicate_quad(verts, norms, m_LeadingQuadIndex, normal)
		for offset in range(6):
			colors[back_vert_index + offset] = color
		m_LeadingQuadIndex += 1

	var strip_length := m_LeadingQuadIndex
	var segment_length := m_LeadingQuadIndex - m_InitialQuadIndex
	if m_EnableBackfaces:
		strip_length = int(strip_length / 2)
		segment_length = int(segment_length / 2)
	if strip_length > 1:
		var indexing_offset := 2 if m_EnableBackfaces else 1
		var back_quad_vert := (m_LeadingQuadIndex - 3 * indexing_offset) * 6
		var mid_quad_index := m_LeadingQuadIndex - 2 * indexing_offset
		var mid_quad_vert := mid_quad_index * 6
		var front_quad_vert := (m_LeadingQuadIndex - indexing_offset) * 6
		if segment_length == 1:
			position_quad(verts, mid_quad_vert, m_LastQuadCenter, m_LastQuadForward, m_LastQuadRight)
			earliest_changed_quad = min(earliest_changed_quad, mid_quad_index)
			if strip_length > 2 and m_LastSegmentLengthSolids > 1:
				fuse_quads(verts, norms, back_quad_vert, mid_quad_vert, generate_new)
			elif generate_new and m_LastSegmentLengthSolids == 1:
				position_quad(verts, mid_quad_vert, m_LastQuadCenter, Vector3.ZERO, Vector3.ZERO)
		elif segment_length == 2:
			fuse_quads(verts, norms, mid_quad_vert, front_quad_vert, generate_new)
		else:
			for offset in range(6):
				verts[mid_quad_vert + offset] = (verts[back_quad_vert + offset] + verts[front_quad_vert + offset]) * 0.5
			fuse_quads(verts, norms, back_quad_vert, mid_quad_vert, generate_new)
			fuse_quads(verts, norms, mid_quad_vert, front_quad_vert, generate_new)
			update_uvs_for_quad(mid_quad_index)
	return earliest_changed_quad

func position_quad(vertices: Array[Vector3], vert_index: int, center: Vector3, forward: Vector3, right: Vector3) -> void:
	vertices[vert_index] = center - forward - right
	vertices[vert_index + 1] = center + forward - right
	vertices[vert_index + 2] = center - forward + right
	vertices[vert_index + 3] = center - forward + right
	vertices[vert_index + 4] = center + forward - right
	vertices[vert_index + 5] = center + forward + right

func make_consistent_backside_quad(vertices: Array[Vector3], normals: Array[Vector3], front_vert_index: int) -> void:
	var back := front_vert_index + 6
	vertices[back] = vertices[front_vert_index]
	vertices[back + 1] = vertices[front_vert_index + 2]
	vertices[back + 2] = vertices[front_vert_index + 1]
	vertices[back + 3] = vertices[front_vert_index + 3]
	vertices[back + 4] = vertices[front_vert_index + 5]
	vertices[back + 5] = vertices[front_vert_index + 4]
	normals[back] = -normals[front_vert_index]
	normals[back + 1] = -normals[front_vert_index + 2]
	normals[back + 2] = -normals[front_vert_index + 1]
	normals[back + 3] = -normals[front_vert_index + 3]
	normals[back + 4] = -normals[front_vert_index + 5]
	normals[back + 5] = -normals[front_vert_index + 4]

func fuse_quads(vertices: Array[Vector3], normals: Array[Vector3], back_vert: int, front_vert: int, alter_back_quad: bool) -> void:
	var top_pos := (vertices[back_vert + 1] + vertices[front_vert]) * 0.5 if alter_back_quad else vertices[back_vert + 1]
	var bottom_pos := (vertices[back_vert + 5] + vertices[front_vert + 2]) * 0.5 if alter_back_quad else vertices[back_vert + 5]
	vertices[back_vert + 1] = top_pos
	vertices[back_vert + 4] = top_pos
	vertices[back_vert + 5] = bottom_pos
	vertices[front_vert] = top_pos
	vertices[front_vert + 2] = bottom_pos
	vertices[front_vert + 3] = bottom_pos
	var normal_avg := normals[back_vert + 1].slerp(normals[front_vert], 0.5).normalized() if alter_back_quad else normals[back_vert + 1]
	normals[back_vert + 1] = normal_avg
	normals[back_vert + 4] = normal_avg
	normals[back_vert + 5] = normal_avg
	normals[front_vert] = normal_avg
	normals[front_vert + 2] = normal_avg
	normals[front_vert + 3] = normal_avg

func get_smoothed_pressure(pressure01: float, position: Vector3) -> float:
	if m_PreviewMode or m_LeadingQuadIndex == 0:
		return pressure01
	var distance_m := m_LastSpawnXf.translation.distance_to(position) * App.UNITS_TO_METERS
	var window_m := K_PRESSURE_SMOOTH_WINDOW_METERS_PS * pointer_to_local()
	var k := pow(0.1, distance_m / window_m)
	return k * m_LastSpawnPressure + (1.0 - k) * pressure01

func apply_changes_to_visuals() -> void:
	if m_Geometry == null:
		return
	mesh_data.clear()
	mesh_data.vertices.assign(m_Geometry.m_Vertices)
	mesh_data.triangles.assign(m_Geometry.m_Tris)
	mesh_data.normals.assign(m_Geometry.m_Normals)
	mesh_data.colors.assign(m_Geometry.m_Colors)
	mesh_data.uv0_v2.assign(m_Geometry.m_UVs)
	mesh_data.tangents.assign(m_Geometry.m_Tangents)

func update_position_impl(position: Vector3, orientation: Quaternion, pressure: float) -> bool:
	var smoothed_pressure := get_smoothed_pressure(pressure, position)
	var spawn_interval := get_spawn_interval(smoothed_pressure)
	var facing := position - m_LastSpawnXf.translation
	var move_length := facing.length()
	if move_length < K_MINIMUM_MOVE_LENGTH_METERS_PS * App.METERS_TO_UNITS * pointer_to_local():
		return false
	facing /= move_length
	var generate_new_quad := move_length >= spawn_interval
	var quads_per := 2 if m_EnableBackfaces else 1
	var preferred_right := (Basis(orientation) * Vector3.FORWARD * -1.0).cross(facing) if m_Desc.m_BackIsInvisible else m_LastQuadRight.normalized()
	var frame := BaseBrushScript.compute_surface_frame_new(preferred_right, facing, orientation)
	var right: Vector3 = frame.right
	var surface_normal: Vector3 = frame.normal
	if not generate_new_quad:
		var ratio := move_length / spawn_interval
		facing = m_LastFacing.slerp(facing, ratio)
	var pressured_size_value := pressured_size(smoothed_pressure) - m_LastSizeShrink
	var quad_center := (position + m_LastSpawnXf.translation) * 0.5
	var quad_forward := facing * move_length * 0.5
	var quad_right := right * pressured_size_value * 0.5
	var previous_initial_index := m_InitialQuadIndex
	var size_shrink := m_LastSizeShrink
	var previous_leading_index := m_LeadingQuadIndex
	var earliest_quad := append_leading_quad(generate_new_quad, pressured_opacity(smoothed_pressure), quad_center, quad_forward, surface_normal, quad_right)
	update_uvs(min(previous_initial_index, earliest_quad), m_LeadingQuadIndex, pressured_size_value)
	if generate_new_quad:
		m_LastFacing = facing
		m_LastQuadCenter = quad_center
		m_LastQuadForward = quad_forward
		m_LastQuadRight = quad_right
		m_LastQuadNormal = surface_normal
		m_LastSegmentLengthSolids = int((m_LeadingQuadIndex - m_InitialQuadIndex) / quads_per)
		m_LastSpawnPressure = smoothed_pressure
		m_LastSizeShrink = size_shrink
		m_LeadingSegmentInitialQuadIndex = null
	else:
		m_LeadingSegmentInitialQuadIndex = m_InitialQuadIndex
		m_InitialQuadIndex = previous_initial_index
		m_LeadingQuadIndex = previous_leading_index
	return generate_new_quad

func is_out_of_verts() -> bool:
	var indexing_offset := 2 if m_EnableBackfaces else 1
	return m_LeadingQuadIndex >= m_NumQuads - indexing_offset

func update_uvs_for_quad(_quad_index: int) -> void:
	pass

func update_uvs_for_segment(_segment_back: int, _segment_front: int, _size: float) -> void:
	pass

func update_uvs(_quad0: int, _quad1: int, _size: float) -> void:
	pass

func solid_length(vertices: Array[Vector3], solid: int) -> float:
	var quads_per_solid := 2 if m_EnableBackfaces else 1
	var vert := solid * quads_per_solid * 6
	var length_a := vertices[vert].distance_to(vertices[vert + 1])
	var length_b := vertices[vert + 3].distance_to(vertices[vert + 5])
	return lerpf(length_a, length_b, 0.5)

func quad_length(vertices: Array[Vector3], quad: int) -> float:
	var quads_per_solid := 2 if m_EnableBackfaces else 1
	return solid_length(vertices, int(quad / quads_per_solid))
