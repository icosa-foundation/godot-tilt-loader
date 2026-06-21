class_name TubeBrush
extends GeometryBrush

const TWO_PI := 2.0 * PI
const K_MINIMUM_MOVE_METERS_PS := 5e-4
const K_UPPER_BOUND_VERTS_PER_KNOT := 12
const K_SOLID_ASPECT_RATIO := 0.2

enum UVStyle {
	DISTANCE,
	STRETCH,
}

enum ShapeModifier {
	NONE,
	DOUBLE_SIDED_TAPER,
	SIN,
	COMET,
	TAPER,
	PETAL,
}

class LoftedProfile:
	const K_NUM_END_KNOTS := 5
	const K_MIN_KNOT_COUNT := 3

	var partial_progress := 0.0
	var knot_count := 0

	func _init(brush: TubeBrush, first_knot_index: int, last_knot_index: int, last_length: float, knots: Array[GeometryBrush.Knot]) -> void:
		partial_progress = clampf(last_length / brush.get_spawn_interval(knots[last_knot_index].smoothedPressure), 0.0, 1.0)
		knot_count = last_knot_index - first_knot_index + 1

	func compute_curve(knot_index: int, first_knot_index: int, _last_knot_index: int, _t: float, _t_prev: float) -> float:
		if knot_count < K_MIN_KNOT_COUNT:
			return 0.0
		var half_count := ceili(minf(float(K_NUM_END_KNOTS), knot_count / 2.0))
		var next_half_count := ceili(minf(float(K_NUM_END_KNOTS), (knot_count + 1.0) / 2.0))
		var local_index := knot_index - first_knot_index
		var reverse_index := knot_count - local_index - 1
		var next_reverse_index := (knot_count + 1) - local_index - 1
		var cur_value := 1.0
		var next_value := 1.0

		if local_index < half_count:
			cur_value = local_index / maxf(half_count - 1.0, 1.0)
		elif reverse_index < half_count:
			cur_value = maxf(0.0, reverse_index - 1.0) / maxf(1.0, half_count - 1.0)

		if local_index < next_half_count:
			next_value = local_index / maxf(next_half_count - 1.0, 1.0)
		elif next_reverse_index < next_half_count:
			next_value = maxf(0.0, next_reverse_index - 1.0) / maxf(1.0, next_half_count - 1.0)

		cur_value = lerpf(cur_value, next_value, 0.185)
		cur_value = lerpf(cur_value, next_value, partial_progress)
		var atten := clampf((knot_count - K_MIN_KNOT_COUNT + partial_progress) / (K_NUM_END_KNOTS * 2.0 - K_MIN_KNOT_COUNT), 0.0, 1.0)
		return clampf(cur_value * atten, 0.0, 1.0)

var m_CapAspect := 0.8
var m_PointsInClosedCircle := 8
var m_EndCaps := true
var m_HardEdges := false
var m_uvStyle := UVStyle.DISTANCE
var m_ShapeModifier := ShapeModifier.NONE
var m_TaperScalar := 1.0
var m_PetalDisplacementAmt := 0.5
var m_PetalDisplacementExp := 3.0
var m_BreakAngleMultiplier := 2.0

var m_VertsInClosedCircle := 0
var m_VertsInCap := 0
var m_Displacements: Array[Vector3] = []

func _init(can_batch: bool = true) -> void:
	setup_geometry_brush(can_batch, K_UPPER_BOUND_VERTS_PER_KNOT * 2, false)

func init_brush(desc: BrushDescriptor, local_pointer_xf: TrTransform) -> void:
	super.init_brush(desc, local_pointer_xf)
	m_geometry.set_layout(get_vertex_layout(desc))
	if m_ShapeModifier != ShapeModifier.NONE:
		m_Displacements.clear()
	m_VertsInClosedCircle = m_PointsInClosedCircle * 2 if m_HardEdges else m_PointsInClosedCircle + 1
	m_VertsInCap = m_PointsInClosedCircle if m_EndCaps else 0
	assert(m_PointsInClosedCircle > 2)
	assert(m_VertsInClosedCircle <= K_UPPER_BOUND_VERTS_PER_KNOT)

func reset_brush_for_preview(local_pointer_xf: TrTransform) -> void:
	super.reset_brush_for_preview(local_pointer_xf)
	m_Displacements.clear()

func get_vertex_layout(desc: BrushDescriptor) -> GeometryPool.VertexLayout:
	var uv0_size := 3 if desc.m_TubeStoreRadiusInTexcoord0Z else 2
	var uv0_semantic := GeometryPool.Semantic.XY_IS_UV_Z_IS_DISTANCE if desc.m_TubeStoreRadiusInTexcoord0Z else GeometryPool.Semantic.XY_IS_UV
	return GeometryPool.VertexLayout.create(
		GeometryPool.TexcoordInfo.create(uv0_size, uv0_semantic),
		GeometryPool.TexcoordInfo.create(),
		null,
		true,
		true,
		true
	)

func get_spawn_interval(pressure01: float) -> float:
	return m_Desc.m_SolidMinLengthMeters_PS * pointer_to_local() * App.METERS_TO_UNITS + pressured_size(pressure01) * K_SOLID_ASPECT_RATIO

func control_points_changed(knot_index: int) -> void:
	var start := knot_index - 1 if m_knots[knot_index - 1].has_geometry() else knot_index
	if on_changed_frame_knots(start):
		start = maxi(1, start - 1)
	on_changed_make_geometry(start)
	resize_geometry()
	if m_uvStyle == UVStyle.STRETCH:
		on_changed_stretch_uvs(start)
	if m_ShapeModifier != ShapeModifier.NONE:
		on_changed_modify_silhouette(start)

func on_changed_frame_knots(knot_index: int) -> bool:
	var initial_knot_contains_break := false
	var prev := m_knots[knot_index - 1]
	for index in range(knot_index, m_knots.size()):
		var cur := m_knots[index]
		var should_break := false
		var move := cur.smoothedPos - prev.smoothedPos
		cur.length = move.length()

		if cur.length < K_MINIMUM_MOVE_METERS_PS * App.METERS_TO_UNITS * pointer_to_local():
			should_break = true
		else:
			var tangent := move / cur.length
			if prev.has_geometry():
				cur.qFrame = _compute_minimal_rotation_frame(tangent, prev.qFrame)
			else:
				var frame := BaseBrushScript.compute_surface_frame_new(Vector3.ZERO, tangent, cur.point.m_Orient)
				var up: Vector3 = frame.normal
				cur.qFrame = _look_rotation(tangent, up)

			if prev.has_geometry() and not m_PreviewMode:
				var width_height_ratio := cur.length / pressured_size(cur.smoothedPressure)
				var break_angle := rad_to_deg(atan(width_height_ratio)) * m_BreakAngleMultiplier
				var angle := rad_to_deg(prev.qFrame.angle_to(cur.qFrame))
				if angle > break_angle:
					should_break = true

		if should_break:
			cur.qFrame = Quaternion(0.0, 0.0, 0.0, 0.0)
			cur.nRight = Vector3.ZERO
			cur.nSurface = Vector3.ZERO
			if index == knot_index:
				initial_knot_contains_break = true
		else:
			var basis := Basis(cur.qFrame)
			cur.nRight = basis * Vector3.RIGHT
			cur.nSurface = basis * Vector3.UP

		cur.nTri = 0 if should_break else 1
		cur.nVert = 0 if should_break else 1
		m_knots[index] = cur
		prev = cur
	return initial_knot_contains_break

func on_changed_make_geometry(knot_index: int) -> void:
	var prev := m_knots[knot_index - 1]
	for index in range(knot_index, m_knots.size()):
		var cur := m_knots[index]
		cur.iTri = prev.iTri + prev.nTri
		cur.iVert = prev.iVert + prev.nVert

		if cur.has_geometry():
			cur.nVert = 0
			cur.nTri = 0
			var basis := Basis(cur.qFrame)
			var right := basis * Vector3.RIGHT
			var up := basis * Vector3.UP
			var forward := basis * Vector3.BACK
			var is_start := not prev.has_geometry()
			var is_end := is_penultimate(index)
			var u0 := 0.0
			var v0 := 0.0
			var v1 := 1.0

			if is_start:
				var random01 := m_rng.in01(cur.iVert - 1)
				u0 = random01
				var num_v: int = m_Desc.m_TextureAtlasV
				var atlas := int(random01 * 3331.0) % num_v
				v0 = atlas / float(num_v)
				v1 = (atlas + 1.0) / float(num_v)
				var prev_size := pressured_size(prev.smoothedPressure)
				var prev_radius := prev_size * 0.5
				var prev_circumference := TWO_PI * prev_radius
				var prev_u_rate := m_Desc.m_TileRate / prev_circumference
				if m_EndCaps:
					make_cap_verts(cur, m_PointsInClosedCircle, prev.smoothedPos - forward * prev_radius * m_CapAspect, prev.smoothedPos, prev_radius, u0, v0, v1, -prev_u_rate, up, right, forward)
				make_closed_circle(cur, prev.smoothedPos, prev_radius, m_PointsInClosedCircle, up, right, forward, u0, v0, v1)
			else:
				cur.iVert -= m_VertsInClosedCircle
				cur.nVert += m_VertsInClosedCircle
				var edge_loop_start := cur.iVert
				var edge_loop_end := cur.iVert + m_VertsInClosedCircle - 1
				if m_HardEdges:
					edge_loop_start = cur.iVert + 1
					edge_loop_end = cur.iVert
				if _uses_vector3_uv0():
					var u0v0 := m_geometry.m_Texcoord0.v3[edge_loop_start]
					u0 = u0v0.x
					v0 = u0v0.y
					v1 = m_geometry.m_Texcoord0.v3[edge_loop_end].y
				else:
					var u0v0 := m_geometry.m_Texcoord0.v2[edge_loop_start]
					u0 = u0v0.x
					v0 = u0v0.y
					v1 = m_geometry.m_Texcoord0.v2[edge_loop_end].y

			var size := pressured_size(cur.smoothedPressure)
			var radius := size * 0.5
			var circumference := TWO_PI * radius
			var u_rate := m_Desc.m_TileRate / circumference
			var u1 := u0 + cur.length * u_rate
			make_closed_circle(cur, cur.smoothedPos, radius, m_PointsInClosedCircle, up, right, forward, u1, v0, v1)
			if is_end and m_EndCaps:
				make_cap_verts(cur, m_PointsInClosedCircle, cur.smoothedPos + forward * radius * m_CapAspect, cur.smoothedPos, radius, u1, v0, v1, u_rate, up, right, forward)

			var back_circle := m_VertsInCap if is_start else 0
			var front_circle := back_circle + m_VertsInClosedCircle
			if is_start:
				var cap := 0
				if m_HardEdges:
					for circle_index in range(m_VertsInCap):
						var j := circle_index * 2 + 1
						var ii := (j + 1) % m_VertsInClosedCircle
						append_tri(cur, cap + circle_index, back_circle + j, back_circle + ii)
				else:
					for circle_index in range(m_VertsInCap):
						var ii := circle_index + 1
						append_tri(cur, cap + circle_index, back_circle + circle_index, back_circle + ii)

			if m_HardEdges:
				for circle_index in range(m_PointsInClosedCircle):
					var j := circle_index * 2 + 1
					var ii := (j + 1) % m_VertsInClosedCircle
					append_tri(cur, back_circle + j, front_circle + j, back_circle + ii)
					append_tri(cur, back_circle + ii, front_circle + j, front_circle + ii)
			else:
				for circle_index in range(m_VertsInClosedCircle - 1):
					var ii := circle_index + 1
					append_tri(cur, back_circle + circle_index, front_circle + circle_index, back_circle + ii)
					append_tri(cur, back_circle + ii, front_circle + circle_index, front_circle + ii)

			if is_end:
				var cap := front_circle + m_VertsInClosedCircle
				if m_HardEdges:
					for circle_index in range(m_VertsInCap):
						var j := circle_index * 2 + 1
						var ii := (j + 1) % m_VertsInClosedCircle
						append_tri(cur, cap + circle_index, front_circle + ii, front_circle + j)
				else:
					for circle_index in range(m_VertsInCap):
						var ii := circle_index + 1
						append_tri(cur, cap + circle_index, front_circle + ii, front_circle + circle_index)

		m_knots[index] = cur
		prev = cur

func on_changed_stretch_uvs(changed_knot: int) -> void:
	var knot_segment_start := changed_knot
	while m_knots[knot_segment_start - 1].has_geometry():
		knot_segment_start -= 1
	while true:
		var knot_past_segment_end := modify_stretch_uvs_of_segment(knot_segment_start)
		if knot_past_segment_end >= m_knots.size():
			break
		knot_segment_start = knot_past_segment_end

func modify_stretch_uvs_of_segment(initial_segment_knot: int) -> int:
	var total_num_knots := 0
	var end_segment_knot := initial_segment_knot
	while end_segment_knot < m_knots.size():
		var cur := m_knots[end_segment_knot]
		if not cur.has_geometry():
			break
		total_num_knots += 1
		end_segment_knot += 1
	var num_knots := 0
	for knot_index in range(initial_segment_knot, end_segment_knot):
		var cur := m_knots[knot_index]
		var u := num_knots / float(total_num_knots)
		for offset in range(cur.nVert):
			var vert := cur.iVert + offset
			if _uses_vector3_uv0():
				var tmp := m_geometry.m_Texcoord0.v3[vert]
				tmp.x = u
				m_geometry.m_Texcoord0.v3[vert] = tmp
			else:
				var tmp := m_geometry.m_Texcoord0.v2[vert]
				tmp.x = u
				m_geometry.m_Texcoord0.v2[vert] = tmp
		num_knots += 1
	return end_segment_knot + 1

func on_changed_modify_silhouette(changed_knot: int) -> void:
	var knot_segment_start := changed_knot
	while m_knots[knot_segment_start - 1].has_geometry():
		knot_segment_start -= 1
	while true:
		var knot_past_segment_end := modify_silhouette_of_segment(knot_segment_start)
		if knot_past_segment_end >= m_knots.size():
			break
		knot_segment_start = knot_past_segment_end

func modify_silhouette_of_segment(initial_segment_knot: int) -> int:
	var total_length := 0.0
	var end_segment_knot := initial_segment_knot
	while end_segment_knot < m_knots.size():
		var cur := m_knots[end_segment_knot]
		if not cur.has_geometry():
			break
		total_length += cur.length
		end_segment_knot += 1
	if total_length <= 0.0:
		return end_segment_knot + 1

	var petal_amount := m_PetalDisplacementAmt * pointer_to_local() * m_BaseSize_PS
	var lofted: LoftedProfile = null
	if m_ShapeModifier == ShapeModifier.DOUBLE_SIDED_TAPER:
		var last_length := distance_from_knot(maxi(0, end_segment_knot - 2), m_knots[end_segment_knot - 1].point.m_Pos)
		lofted = LoftedProfile.new(self, initial_segment_knot, end_segment_knot - 1, last_length, m_knots)

	var distance := 0.0
	for knot_index in range(initial_segment_knot, end_segment_knot):
		var cur := m_knots[knot_index]
		var prev := m_knots[knot_index - 1]
		var is_start := not prev.has_geometry()
		var is_end := is_penultimate(knot_index)
		var t_prev := distance / total_length
		distance += cur.length
		var t := distance / total_length
		for offset_index in range(cur.nVert):
			var vert := cur.iVert + offset_index
			var radius := pressured_size(cur.smoothedPressure) * 0.5
			var dir := m_Displacements[vert] if vert < m_Displacements.size() else Vector3.ZERO
			if m_EndCaps:
				if is_start and offset_index < m_VertsInCap:
					continue
				var end_cap_geometry_is_complete := (m_VertsInClosedCircle * 2 + m_VertsInCap) == cur.nVert
				if is_end and end_cap_geometry_is_complete and offset_index >= m_VertsInClosedCircle * 2:
					continue
			var curve := 0.0
			var extra_offset := Vector3.ZERO
			match m_ShapeModifier:
				ShapeModifier.DOUBLE_SIDED_TAPER:
					curve = lofted.compute_curve(knot_index, initial_segment_knot, end_segment_knot - 1, t, t_prev) if lofted != null else 0.0
				ShapeModifier.SIN:
					curve = absf(sin(t * PI))
				ShapeModifier.COMET:
					curve = sin(t * 1.5 + 1.55)
				ShapeModifier.TAPER:
					curve = m_TaperScalar * (1.0 - t)
				ShapeModifier.PETAL:
					curve = absf(sin(t * PI))
					var displacement := pow(t, m_PetalDisplacementExp)
					extra_offset = m_geometry.m_Normals[vert] * displacement * petal_amount * cur.smoothedPressure
			m_geometry.m_Vertices[vert] = extra_offset + cur.smoothedPos + radius * dir * curve
	return end_segment_knot + 1

func make_cap_verts(
	knot: Knot,
	num_points: int,
	tip: Vector3,
	circle_center: Vector3,
	radius: float,
	u0: float,
	v0: float,
	v1: float,
	u_rate: float,
	up: Vector3,
	right: Vector3,
	forward: Vector3
) -> void:
	var diagonal := ((circle_center + up * radius) - tip).length()
	var u := u0 + u_rate * diagonal
	var forward_normal := signf((tip - circle_center).dot(forward)) * forward
	for index in range(num_points):
		var t := (index + 0.5) / float(num_points)
		var theta := TWO_PI * t
		var tangent := -cos(theta) * up + -sin(theta) * right
		var uv := Vector2(u, lerpf(v0, v1, t))
		var normal := forward_normal
		if m_HardEdges:
			normal = -cos(theta) * up + -sin(theta) * right
		append_vert(knot, tip, normal.normalized(), m_Color, tangent, uv, 0.0)
		append_displacement(knot, forward_normal)

func make_closed_circle(
	knot: Knot,
	center: Vector3,
	radius: float,
	num_points: int,
	up: Vector3,
	right: Vector3,
	forward: Vector3,
	u: float,
	v0: float,
	v1: float
) -> void:
	if m_HardEdges:
		make_closed_circle_hard_edges(knot, center, radius, num_points, up, right, forward, u, v0, v1)
	else:
		make_closed_circle_soft_edges(knot, center, radius, num_points, up, right, forward, u, v0, v1)

func make_closed_circle_soft_edges(
	knot: Knot,
	center: Vector3,
	radius: float,
	num_points: int,
	up: Vector3,
	right: Vector3,
	forward: Vector3,
	u: float,
	v0: float,
	v1: float
) -> void:
	var num_verts := num_points + 1
	for index in range(num_verts):
		var t := index / float(num_verts - 1)
		var theta := 0.0 if t == 1.0 else TWO_PI * t
		var uv := Vector2(u, lerpf(v0, v1, t))
		var offset := -cos(theta) * up + -sin(theta) * right
		append_vert(knot, center + radius * offset, offset, m_Color, forward, uv, radius)
		append_displacement(knot, offset.normalized())

func make_closed_circle_hard_edges(
	knot: Knot,
	center: Vector3,
	radius: float,
	num_points: int,
	up: Vector3,
	right: Vector3,
	forward: Vector3,
	u: float,
	v0: float,
	v1: float
) -> void:
	for index in range(num_points):
		var t := index / float(num_points)
		var theta := 0.0 if t == 0.0 else TWO_PI * t
		var tangent := -cos(theta) * up + -sin(theta) * right
		var delta_theta := TWO_PI / num_points * 0.5
		var offset := -cos(theta) * up + -sin(theta) * right
		var normal_current := -cos(theta + delta_theta) * up + -sin(theta + delta_theta) * right
		var normal_previous := -cos(theta - delta_theta) * up + -sin(theta - delta_theta) * right
		var previous_face := (index + (num_points - 1)) % num_points
		var uv := Vector2(u, lerpf(v0, v1, previous_face / float(num_points) + (1.0 / num_points)))
		append_vert(knot, center + radius * offset, normal_previous, m_Color, tangent, uv, radius)
		append_displacement(knot, offset)
		var current_face := index
		uv = Vector2(u, lerpf(v0, v1, current_face / float(num_points)))
		append_vert(knot, center + radius * offset, normal_current, m_Color, tangent, uv, radius)
		append_displacement(knot, offset)

func append_displacement(knot: Knot, value: Vector3) -> void:
	if m_ShapeModifier == ShapeModifier.NONE:
		return
	var index := knot.iVert + knot.nVert - 1
	while index >= m_Displacements.size():
		m_Displacements.append(Vector3.ZERO)
	m_Displacements[index] = value

func append_vert(knot: Knot, position: Vector3, normal: Vector3, color_value: Color, tangent: Vector3, uv: Vector2, radius: float) -> void:
	var index := knot.iVert + knot.nVert
	knot.nVert += 1
	var color := _to_color32(color_value)
	var tangent4 := Vector4(tangent.x, tangent.y, tangent.z, 1.0)
	if index == m_geometry.m_Vertices.size():
		m_geometry.m_Vertices.append(position)
		m_geometry.m_Normals.append(normal)
		m_geometry.m_Colors.append(color)
		if _uses_vector3_uv0():
			m_geometry.m_Texcoord0.v3.append(Vector3(uv.x, uv.y, radius))
		else:
			m_geometry.m_Texcoord0.v2.append(uv)
		if m_geometry.get_layout().bUseTangents:
			m_geometry.m_Tangents.append(tangent4)
	else:
		m_geometry.m_Vertices[index] = position
		m_geometry.m_Normals[index] = normal
		m_geometry.m_Colors[index] = color
		if _uses_vector3_uv0():
			m_geometry.m_Texcoord0.v3[index] = Vector3(uv.x, uv.y, radius)
		else:
			m_geometry.m_Texcoord0.v2[index] = uv
		if m_geometry.get_layout().bUseTangents:
			m_geometry.m_Tangents[index] = tangent4

func append_tri(knot: Knot, t0: int, t1: int, t2: int) -> void:
	var index := (knot.iTri + knot.nTri) * 3
	knot.nTri += 1
	if index == m_geometry.m_Tris.size():
		m_geometry.m_Tris.append(knot.iVert + t0)
		m_geometry.m_Tris.append(knot.iVert + t1)
		m_geometry.m_Tris.append(knot.iVert + t2)
	else:
		m_geometry.m_Tris[index] = knot.iVert + t0
		m_geometry.m_Tris[index + 1] = knot.iVert + t1
		m_geometry.m_Tris[index + 2] = knot.iVert + t2

func is_penultimate(knot_index: int) -> bool:
	return knot_index + 1 == m_knots.size() or not m_knots[knot_index + 1].has_geometry()

static func _compute_minimal_rotation_frame(tangent: Vector3, previous_frame: Quaternion) -> Quaternion:
	var previous_tangent := Basis(previous_frame) * Vector3.BACK
	var minimal := QuaternionUtils.from_to_rotation(previous_tangent, tangent)
	return (minimal * previous_frame).normalized()

static func _look_rotation(forward: Vector3, up: Vector3) -> Quaternion:
	var normalized_forward := forward.normalized()
	var normalized_up := up.normalized()
	if absf(normalized_up.dot(normalized_forward)) > 0.99:
		normalized_up = Vector3.UP if absf(Vector3.UP.dot(normalized_forward)) < 0.99 else Vector3.RIGHT
	return Basis.looking_at(-normalized_forward, normalized_up).get_rotation_quaternion()

func _uses_vector3_uv0() -> bool:
	return m_geometry != null and m_geometry.get_layout().texcoord0.size == 3
