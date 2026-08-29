class_name SprayBrush
extends GeometryBrush

const K_VERTS_IN_SOLID := 4
const K_TRIS_IN_SOLID := 2
const K_MAX_QUADS_PER_KNOT := 500

const K_SALT_MAX_QUADS_PER_KNOT := 12
const K_SALT_MAX_SALTS_PER_QUAD := 10
const K_SALT_PRESSURE := 0
const K_SALT_ROTATION := K_SALT_PRESSURE + 1
const K_SALT_POSITION := K_SALT_ROTATION + 1
const K_SALT_ALPHA := K_SALT_POSITION + 3
const K_SALT_ATLAS := K_SALT_ALPHA + 1

const BR := 0
const BL := 1
const FR := 2
const FL := 3

const TEXTURE_ATLAS_00 := Vector2(0.0, 0.0)
const TEXTURE_ATLAS_05 := Vector2(0.0, 0.5)
const TEXTURE_ATLAS_50 := Vector2(0.5, 0.0)
const TEXTURE_ATLAS_55 := Vector2(0.5, 0.5)

var m_DecayTimers: Array[float] = []
var m_DecayedKnots := 0
var m_LastDecayTimeSeconds := -1.0

func _init() -> void:
	setup_geometry_brush(true, K_VERTS_IN_SOLID, true, false)

func calculate_salt(knot_index: int, quad_index: int) -> int:
	var pretend_knot_index := knot_index + m_DecayedKnots
	return K_SALT_MAX_SALTS_PER_QUAD * (pretend_knot_index * K_SALT_MAX_QUADS_PER_KNOT + quad_index % K_SALT_MAX_QUADS_PER_KNOT)

func get_spawn_interval(pressure01: float) -> float:
	return pressured_size(pressure01) / m_Desc.m_SprayRateMultiplier

func always_rebuild_preview_brush() -> bool:
	return false

func init_brush(desc: BrushDescriptor, local_pointer_xf: TrTransform) -> void:
	super.init_brush(desc, local_pointer_xf)
	set_double_sided(desc)
	m_DecayTimers.clear()
	m_geometry.set_layout(get_vertex_layout(desc))
	m_LastDecayTimeSeconds = _current_decay_time_seconds()

func get_vertex_layout(_desc: BrushDescriptor) -> GeometryPool.VertexLayout:
	return GeometryPool.VertexLayout.create(
		GeometryPool.TexcoordInfo.create(2, GeometryPool.Semantic.XY_IS_UV),
		GeometryPool.TexcoordInfo.create(),
		null,
		true,
		true,
		true
	)

func decay_brush() -> void:
	var now := _current_decay_time_seconds()
	var delta := maxf(0.0, now - m_LastDecayTimeSeconds) if m_LastDecayTimeSeconds >= 0.0 else 0.0
	m_LastDecayTimeSeconds = now
	var knots_to_shift := 0
	for index in range(m_DecayTimers.size()):
		m_DecayTimers[index] += delta
		if m_DecayTimers[index] > K_PREVIEW_DURATION:
			knots_to_shift += 1
	m_DecayTimers = m_DecayTimers.slice(knots_to_shift)
	remove_initial_knots(knots_to_shift)
	m_DecayedKnots += knots_to_shift

func reset_brush_for_preview(local_pointer_xf: TrTransform) -> void:
	super.reset_brush_for_preview(local_pointer_xf)
	m_DecayTimers.clear()
	m_LastDecayTimeSeconds = _current_decay_time_seconds()

func update_position_impl(position: Vector3, orientation: Quaternion, pressure: float) -> bool:
	var keep := super.update_position_impl(position, orientation, pressure)
	if keep and m_PreviewMode:
		m_DecayTimers.append(0.0)
	return keep

func control_points_changed(knot_index: int) -> void:
	on_changed_frame_knots(knot_index)
	resize_geometry()
	on_changed_make_geometry(knot_index)
	on_changed_uvs(knot_index)
	on_changed_tangents(knot_index)

func needs_straight_edge_proxy() -> bool:
	return true

func on_changed_frame_knots(knot_index: int) -> void:
	var prev := m_knots[knot_index - 1]
	for index in range(knot_index, m_knots.size()):
		var cur := m_knots[index]
		cur.iTri = prev.iTri + prev.nTri
		cur.iVert = prev.iVert + prev.nVert
		var move := cur.point.m_Pos - prev.point.m_Pos
		cur.length = move.length()
		var min_distance_to_spawn := get_spawn_interval(cur.smoothedPressure)
		if cur.length < min_distance_to_spawn:
			cur.nTri = 0
			cur.nVert = 0
			cur.nRight = Vector3.ZERO
			cur.nSurface = Vector3.ZERO
		else:
			var facing := move.normalized()
			var frame := BaseBrushScript.compute_surface_frame_new(Vector3.ZERO, facing, cur.point.m_Orient)
			cur.nRight = frame.right
			cur.nSurface = frame.normal
			var num_quads: int = min(int(cur.length / min_distance_to_spawn), get_num_quads_allowed())
			cur.nTri = num_quads * K_TRIS_IN_SOLID * NS
			cur.nVert = num_quads * K_VERTS_IN_SOLID * NS
		m_knots[index] = cur
		prev = cur

func on_changed_make_geometry(knot_index: int) -> void:
	var prev := m_knots[knot_index - 1]
	for index in range(knot_index, m_knots.size()):
		var cur := m_knots[index]
		if cur.has_geometry():
			var num_quads := int(cur.nTri / (K_TRIS_IN_SOLID * NS))
			var move_direction := (cur.point.m_Pos - prev.point.m_Pos).normalized()
			var min_distance_to_spawn := get_spawn_interval(cur.smoothedPressure)
			var last_spawn_pos := prev.point.m_Pos
			var vert_index := cur.iVert
			var tri_index := cur.iTri
			var alpha := pressured_opacity(cur.smoothedPressure)

			for quad in range(num_quads):
				var salt := calculate_salt(index, quad)
				var center := last_spawn_pos
				var right := cur.nRight
				var facing := move_direction
				var rotation_variance := m_Desc.m_RotationVariance
				if rotation_variance > 0.0001:
					var rotate := Quaternion((-cur.nSurface).normalized(), deg_to_rad(m_rng.in_range(salt + K_SALT_ROTATION, -rotation_variance, rotation_variance)))
					right = rotate * right
					facing = rotate * facing

				var size := pressured_random_size(cur.smoothedPressure, salt + K_SALT_PRESSURE)
				var forward_offset := facing * size * m_Desc.m_SizeRatio.x * 0.5
				var right_offset := right * size * m_Desc.m_SizeRatio.y * 0.5
				var random_offset := m_rng.in_unit_sphere(salt + K_SALT_POSITION)
				random_offset.z = -random_offset.z
				center += size * m_Desc.m_PositionVariance * random_offset

				set_tri(tri_index, vert_index, 0, BR, BL, FL)
				set_tri(tri_index, vert_index, 1, BR, FL, FR)
				if m_Desc.m_RandomizeAlpha:
					alpha = m_rng.in_range(salt + K_SALT_ALPHA, 0.0, 1.0)

				set_vert(vert_index, BR, center - forward_offset + right_offset, cur.nSurface, m_Color, alpha)
				set_vert(vert_index, BL, center - forward_offset - right_offset, cur.nSurface, m_Color, alpha)
				set_vert(vert_index, FR, center + forward_offset + right_offset, cur.nSurface, m_Color, alpha)
				set_vert(vert_index, FL, center + forward_offset - right_offset, cur.nSurface, m_Color, alpha)

				tri_index += K_TRIS_IN_SOLID * NS
				vert_index += K_VERTS_IN_SOLID * NS
				last_spawn_pos += move_direction * min_distance_to_spawn
		prev = cur

func on_changed_uvs(knot_index: int) -> void:
	for index in range(knot_index, m_knots.size()):
		var cur := m_knots[index]
		if cur.has_geometry():
			var quad := 0
			for vert_index in range(cur.iVert, cur.iVert + cur.nVert, K_VERTS_IN_SOLID * NS):
				var offset := Vector2.ZERO
				if m_Desc.m_TextureAtlasV > 1:
					var salt := calculate_salt(index, quad)
					var rand := m_rng.in_int_range(salt + K_SALT_ATLAS, 0, 4)
					if rand == 1:
						offset = TEXTURE_ATLAS_50
					elif rand == 2:
						offset = TEXTURE_ATLAS_05
					elif rand == 3:
						offset = TEXTURE_ATLAS_55
					set_uv0(vert_index, BL, TEXTURE_ATLAS_00 + offset)
					set_uv0(vert_index, FL, TEXTURE_ATLAS_50 + offset)
					set_uv0(vert_index, BR, TEXTURE_ATLAS_05 + offset)
					set_uv0(vert_index, FR, TEXTURE_ATLAS_55 + offset)
				else:
					set_uv0(vert_index, BL, Vector2(0.0, 0.0))
					set_uv0(vert_index, FL, Vector2(1.0, 0.0))
					set_uv0(vert_index, BR, Vector2(0.0, 1.0))
					set_uv0(vert_index, FR, Vector2(1.0, 1.0))
				quad += 1

func on_changed_tangents(knot_index: int) -> void:
	for index in range(knot_index, m_knots.size()):
		var cur := m_knots[index]
		if cur.has_geometry():
			for vert_index in range(cur.iVert, cur.iVert + cur.nVert, K_VERTS_IN_SOLID * NS):
				var bl := m_geometry.m_Vertices[vert_index + BL * NS]
				var fl := m_geometry.m_Vertices[vert_index + FL * NS]
				var facing := fl - bl
				set_tangent(vert_index, BL, facing, -1.0)
				set_tangent(vert_index, BR, facing, -1.0)
				set_tangent(vert_index, FL, facing, -1.0)
				set_tangent(vert_index, FR, facing, -1.0)

func get_num_quads_allowed() -> int:
	var max_num_verts := 0xffff
	return min(int((max_num_verts - get_num_used_verts()) / (K_VERTS_IN_SOLID * NS)), K_MAX_QUADS_PER_KNOT)

static func _current_decay_time_seconds() -> float:
	return float(Time.get_ticks_msec()) / 1000.0
