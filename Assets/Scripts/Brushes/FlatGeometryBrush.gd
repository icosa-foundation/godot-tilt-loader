class_name FlatGeometryBrush
extends GeometryBrush

const K_VERTS_IN_SOLID := 4
const K_SHARED_VERTS_IN_SOLID_PAIR := 2
const K_TRIS_IN_SOLID := 2
const K_SHARED_TRIS_IN_SOLID_PAIR := 0
const K_MINIMUM_KNOTS_AFTER_BREAK := 6

const BR := 0
const BL := 1
const FR := 2
const FL := 3

enum UVStyle {
	DISTANCE,
	STRETCH,
}

const K_SOLID_MIN_LENGTH_METERS_PS := 0.002
const K_MIN_MOVE_LENGTH_METERS_PS := 5e-4
const K_BREAK_ANGLE_SCALAR := 2.0
const K_SOLID_ASPECT_RATIO := 0.2
const K_SMOOTHING_WINDOW := 1

var m_sizes: Array[float] = []
var m_uvStyle := UVStyle.DISTANCE
var m_bOffsetInTexcoord1 := false

func _init() -> void:
	setup_geometry_brush(true, K_VERTS_IN_SOLID, true)

func init_brush(desc: BrushDescriptor, local_pointer_xf: TrTransform) -> void:
	super.init_brush(desc, local_pointer_xf)
	set_double_sided(desc)
	m_geometry.set_layout(get_vertex_layout(desc))
	m_sizes = []

func get_vertex_layout(_desc: BrushDescriptor) -> GeometryPool.VertexLayout:
	return GeometryPool.VertexLayout.create(
		GeometryPool.TexcoordInfo.create(2, GeometryPool.Semantic.XY_IS_UV),
		GeometryPool.TexcoordInfo.create(3, GeometryPool.Semantic.VECTOR) if m_bOffsetInTexcoord1 else GeometryPool.TexcoordInfo.create(),
		null,
		true,
		true,
		true
	)

func get_spawn_interval(pressure01: float) -> float:
	return K_SOLID_MIN_LENGTH_METERS_PS * pointer_to_local() * App.METERS_TO_UNITS + pressured_size(pressure01) * K_SOLID_ASPECT_RATIO

func control_points_changed(knot_index: int) -> void:
	on_changed_frame_knots(knot_index)
	resize_geometry()

	var knot_start := knot_index
	for test in range(knot_start - 1, knot_index - K_SMOOTHING_WINDOW - 2, -1):
		if test < 0 or not m_knots[test].has_geometry():
			break
		knot_start = test
	on_changed_make_verts_and_normals(knot_start)

	if m_uvStyle == UVStyle.STRETCH:
		var start := knot_index - 2 if knot_index > 2 and not m_knots[knot_index - 1].has_geometry() else knot_index
		on_changed_stretch_uvs(start)
	else:
		on_changed_distance_uvs(knot_index)

	var tangent_start := knot_index - 1 if m_knots[knot_index - 1].has_geometry() else knot_index
	on_changed_tangents(tangent_start)

func trim_short_stroke_after_break() -> void:
	if m_bM11Compatibility:
		return
	var last_index := m_knots.size() - 1
	while last_index > 0 and m_knots[last_index].has_geometry():
		last_index -= 1
	if last_index > 1 and (m_knots.size() - last_index) < K_MINIMUM_KNOTS_AFTER_BREAK:
		m_knots = m_knots.slice(0, last_index + 1)
		resize_geometry()

func finalize_solitary_brush() -> void:
	trim_short_stroke_after_break()
	super.finalize_solitary_brush()

func on_changed_frame_knots(knot_index: int) -> void:
	var min_move := K_MIN_MOVE_LENGTH_METERS_PS * App.METERS_TO_UNITS * pointer_to_local()
	var knot_start := knot_index - 1 if m_knots[knot_index - 1].has_geometry() else knot_index
	var prev := m_knots[knot_start - 1]
	for index in range(knot_start, m_knots.size()):
		var cur := m_knots[index]
		var should_break := false
		var move := cur.point.m_Pos - prev.point.m_Pos
		cur.length = move.length()
		if cur.length < min_move:
			should_break = true

		if not should_break:
			var tangent := move / cur.length
			if not m_bM11Compatibility and index < m_knots.size() - 1:
				var next := m_knots[index + 1]
				tangent = (next.point.m_Pos - prev.point.m_Pos).normalized()
				if move.dot(next.point.m_Pos - cur.point.m_Pos) < 0.0:
					should_break = true

			var preferred_right := (Basis(cur.point.m_Orient) * Vector3.FORWARD * -1.0).cross(tangent) if m_Desc.m_BackIsInvisible else prev.nRight
			var frame := BaseBrushScript.compute_surface_frame_new(preferred_right, tangent, cur.point.m_Orient)
			cur.nRight = frame.right
			cur.nSurface = frame.normal

		if not should_break and m_bM11Compatibility and prev.has_geometry():
			var width_height_ratio := cur.length / pressured_size(cur.smoothedPressure)
			var break_angle := rad_to_deg(atan(width_height_ratio)) * K_BREAK_ANGLE_SCALAR
			var previous_move := prev.point.m_Pos - m_knots[index - 2].point.m_Pos
			if rad_to_deg(previous_move.angle_to(move)) > break_angle:
				should_break = true

		if should_break:
			cur.iTri = prev.iTri + prev.nTri
			cur.nTri = 0
			cur.iVert = prev.iVert + prev.nVert
			cur.nVert = 0
			cur.nRight = Vector3.ZERO
			cur.nSurface = Vector3.ZERO
		else:
			cur.iTri = prev.iTri + prev.nTri
			cur.iVert = prev.iVert + prev.nVert
			if prev.has_geometry():
				cur.iTri -= K_SHARED_TRIS_IN_SOLID_PAIR * NS
				cur.iVert -= K_SHARED_VERTS_IN_SOLID_PAIR * NS
			cur.nTri = K_TRIS_IN_SOLID * NS
			cur.nVert = K_VERTS_IN_SOLID * NS

		m_knots[index] = cur
		prev = cur

func on_changed_make_verts_and_normals(knot_index: int) -> void:
	while m_sizes.size() < m_knots.size():
		m_sizes.append(0.0)

	var prev := m_knots[knot_index - 1]
	var size_prev := m_sizes[knot_index - 1]

	for index in range(knot_index, m_knots.size()):
		var cur := m_knots[index]
		if cur.has_geometry():
			set_tri(cur.iTri, cur.iVert, 0, BR, BL, FL)
			set_tri(cur.iTri, cur.iVert, 1, BR, FL, FR)

			if not prev.has_geometry():
				var size := pressured_size(prev.smoothedPressure)
				var alpha := pressured_opacity(prev.smoothedPressure)
				var half_right := cur.nRight * (size * 0.5)
				set_vert(cur.iVert, BR, prev.point.m_Pos + half_right, cur.nSurface, m_Color, alpha)
				set_vert(cur.iVert, BL, prev.point.m_Pos - half_right, cur.nSurface, m_Color, alpha)
				if m_bOffsetInTexcoord1:
					set_uv1(cur.iVert, BR, half_right)
					set_uv1(cur.iVert, BL, -half_right)
				size_prev = size
				m_sizes[index - 1] = size

			if m_bM11Compatibility:
				var size := pressured_size(cur.smoothedPressure)
				var alpha := pressured_opacity(cur.smoothedPressure)
				var half_right := cur.nRight * (size * 0.5)
				set_vert(cur.iVert, FR, cur.point.m_Pos + half_right, cur.nSurface, m_Color, alpha)
				set_vert(cur.iVert, FL, cur.point.m_Pos - half_right, cur.nSurface, m_Color, alpha)
				if m_bOffsetInTexcoord1:
					set_uv1(cur.iVert, FR, half_right)
					set_uv1(cur.iVert, FL, -half_right)
			else:
				var size := pressured_size(cur.smoothedPressure)
				var prev_forward := prev.nRight.cross(prev.nSurface)
				var dot_right := prev_forward.dot(cur.point.m_Pos + 0.5 * size * cur.nRight - prev.point.m_Pos)
				var dot_left := prev_forward.dot(cur.point.m_Pos - 0.5 * size * cur.nRight - prev.point.m_Pos)
				if (dot_left < 0.0 and dot_right > 0.0) or (dot_left > 0.0 and dot_right < 0.0):
					var endpoint_left := prev.point.m_Pos - 0.5 * size_prev * prev.nRight
					var endpoint_right := prev.point.m_Pos + 0.5 * size_prev * prev.nRight
					var clipped_right := cur.point.m_Pos - endpoint_left if dot_left < 0.0 else endpoint_right - cur.point.m_Pos
					size = clipped_right.length()

				var move_length := cur.point.m_Pos.distance_to(prev.point.m_Pos)
				if size > size_prev + move_length:
					size = size_prev + move_length
				size_prev = size
				m_sizes[index] = size
		prev = cur

	if not m_bM11Compatibility:
		var half_right_prev := m_knots[knot_index - 1].nRight * m_sizes[knot_index - 1] * 0.5
		var knot_point_prev := m_knots[knot_index - 1].point.m_Pos
		var half_right_cur := m_knots[knot_index].nRight * m_sizes[knot_index] * 0.5
		var knot_point_cur := m_knots[knot_index].point.m_Pos
		if not m_knots[knot_index - 1].has_geometry():
			half_right_prev = half_right_cur
		for index in range(knot_index, m_knots.size()):
			var cur := m_knots[index]
			var next_index := index + 1 if index < m_knots.size() - 1 else index
			var half_right_next := m_knots[next_index].nRight * m_sizes[next_index] * 0.5
			var knot_point_next := m_knots[next_index].point.m_Pos
			if cur.has_geometry():
				var alpha := pressured_opacity(cur.smoothedPressure)
				var surface := cur.nSurface
				var knot_point := 0.3 * knot_point_prev + 0.4 * knot_point_cur + 0.3 * knot_point_next
				var half_right := 0.3 * half_right_prev + 0.4 * half_right_cur + 0.3 * half_right_next
				if not m_knots[next_index].has_geometry():
					half_right = half_right_cur
				set_vert(cur.iVert, FL, knot_point - half_right, surface, m_Color, alpha)
				set_vert(cur.iVert, FR, knot_point + half_right, surface, m_Color, alpha)
				if m_bOffsetInTexcoord1:
					set_uv1(cur.iVert, FR, half_right_cur)
					set_uv1(cur.iVert, FL, -half_right_cur)
			half_right_prev = half_right_cur
			half_right_cur = half_right_next
			knot_point_prev = knot_point_cur
			knot_point_cur = knot_point_next

func on_changed_stretch_uvs(changed_knot: int) -> void:
	var knot0 := changed_knot
	while m_knots[knot0 - 1].has_geometry():
		knot0 -= 1

	while knot0 < m_knots.size():
		var total_length := 0.0
		var knot1 := knot0
		while knot1 < m_knots.size():
			var cur := m_knots[knot1]
			if not cur.has_geometry():
				break
			total_length += cur.length
			knot1 += 1

		var random01 := m_rng.in01(m_knots[knot0].iVert - 1)
		var num_v: int = max(m_Desc.m_TextureAtlasV, 1)
		var atlas := int(random01 * 3331.0) % num_v
		var v0 := atlas / float(num_v)
		var v1 := (atlas + 1) / float(num_v)
		var distance := 0.0
		for index in range(knot0, knot1):
			var cur := m_knots[index]
			distance += cur.length
			var u := distance / total_length if total_length != 0.0 else 1.0
			if index == knot0:
				set_uv0(cur.iVert, BL, Vector2(0.0, v0))
				set_uv0(cur.iVert, BR, Vector2(0.0, v1))
			set_uv0(cur.iVert, FL, Vector2(u, v0))
			set_uv0(cur.iVert, FR, Vector2(u, v1))

		knot0 = knot1 + 1

func on_changed_distance_uvs(knot_index: int) -> void:
	var prev := m_knots[knot_index - 1]
	for index in range(knot_index, m_knots.size()):
		var cur := m_knots[index]
		if cur.has_geometry():
			var u0: float
			var v0: float
			var v1: float
			if prev.has_geometry():
				var u0v0 := m_geometry.m_Texcoord0.v2[prev.iVert + FL * NS]
				u0 = u0v0.x
				v0 = u0v0.y
				v1 = m_geometry.m_Texcoord0.v2[prev.iVert + FR * NS].y
			else:
				var random01 := m_rng.in01(cur.iVert - 1)
				u0 = random01
				var num_v: int = max(m_Desc.m_TextureAtlasV, 1)
				var atlas := int(random01 * 3331.0) % num_v
				v0 = atlas / float(num_v)
				v1 = (atlas + 1) / float(num_v)
				set_uv0(cur.iVert, BL, Vector2(u0, v0))
				set_uv0(cur.iVert, BR, Vector2(u0, v1))

			var length := m_knots[index].length
			var size := pressured_size(m_knots[index].smoothedPressure)
			var u1 := u0 + m_Desc.m_TileRate * (length / size)
			set_uv0(cur.iVert, FL, Vector2(u1, v0))
			set_uv0(cur.iVert, FR, Vector2(u1, v1))
		prev = cur

func on_changed_tangents(knot_index: int) -> void:
	var prev := m_knots[knot_index - 1]
	for index in range(knot_index, m_knots.size()):
		var cur := m_knots[index]
		if cur.has_geometry():
			var st0 := BaseBrushScript.compute_st(m_geometry.m_Vertices, m_geometry.m_Texcoord0.v2, cur.iVert, BR * NS, BL * NS, FL * NS)
			var st1 := BaseBrushScript.compute_st(m_geometry.m_Vertices, m_geometry.m_Texcoord0.v2, cur.iVert, BR * NS, FL * NS, FR * NS)
			var s0: Vector3 = st0.s
			var s1: Vector3 = st1.s
			if not prev.has_geometry():
				set_tangent(cur.iVert, BL, s0)
				set_tangent(cur.iVert, BR, s0 + s1)
			set_tangent(cur.iVert, FL, s0 + s1)
			set_tangent(cur.iVert, FR, s1)
		prev = cur
