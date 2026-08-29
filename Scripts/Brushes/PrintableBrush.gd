class_name PrintableBrush
extends GeometryBrush

const BR := 0
const BL := 1
const BT := 2
const BB := 3
const FR := 4
const FL := 5
const FT := 6
const FB := 7

const K_SOLID_MIN_LENGTH_METERS_PS := 0.002
const K_MIN_MOVE_LENGTH_METERS_PS := 5e-4
const K_BREAK_ANGLE_SCALAR := 2.0
const K_SOLID_ASPECT_RATIO := 0.2
const K_CROSS_SECTION_ASPECT_RATIO := 0.375
const K_INITIAL_ENVELOPE := 0.8
const K_FINAL_ENVELOPE := 0.3

var m_UseEnvelope := false

func _init() -> void:
	setup_geometry_brush(true, 4, false)

func init_brush(desc: BrushDescriptor, local_pointer_xf: TrTransform) -> void:
	super.init_brush(desc, local_pointer_xf)
	m_geometry.set_layout(get_vertex_layout(desc))

func get_vertex_layout(_desc: BrushDescriptor) -> GeometryPool.VertexLayout:
	return GeometryPool.VertexLayout.create(
		GeometryPool.TexcoordInfo.create(2, GeometryPool.Semantic.XY_IS_UV),
		null,
		null,
		true,
		true,
		false
	)

func get_spawn_interval(pressure01: float) -> float:
	return K_SOLID_MIN_LENGTH_METERS_PS * pointer_to_local() * App.METERS_TO_UNITS + pressured_size(pressure01) * K_SOLID_ASPECT_RATIO

func control_points_changed(knot_index: int) -> void:
	on_changed_frame_knots(knot_index)
	on_changed_set_envelope(knot_index)
	resize_geometry()
	var start := knot_index - 1 if m_knots[knot_index - 1].has_geometry() else knot_index
	on_changed_make_geometry(start)

func set_knot_envelope(index: int, width: float) -> void:
	var knot := m_knots[index]
	knot.qFrame.x = width
	m_knots[index] = knot

func on_changed_set_envelope(_knot_index: int) -> void:
	var segment_start := 0
	var knot_count := m_knots.size()
	while segment_start < knot_count:
		var segment_end := segment_start + 1
		var total_length := 0.0
		while segment_end < knot_count and m_knots[segment_end].has_geometry():
			total_length += m_knots[segment_end].length
			segment_end += 1

		set_knot_envelope(segment_start, K_INITIAL_ENVELOPE)
		if segment_start + 1 < segment_end:
			total_length -= m_knots[segment_start + 1].length
			set_knot_envelope(segment_start + 1, 1.0)
			var current_length := 0.0
			for index in range(segment_start + 2, segment_end):
				current_length += m_knots[index].length
				var t := 1.0 if current_length >= total_length else current_length / total_length
				set_knot_envelope(index, lerpf(1.0, K_FINAL_ENVELOPE, t))

		segment_start = segment_end

func on_changed_frame_knots(knot_index: int) -> void:
	var min_move := K_MIN_MOVE_LENGTH_METERS_PS * App.METERS_TO_UNITS * pointer_to_local()
	var prev := m_knots[knot_index - 1]
	for index in range(knot_index, m_knots.size()):
		var cur := m_knots[index]
		var should_break := false
		var move := cur.point.m_Pos - prev.point.m_Pos
		cur.length = move.length()
		if cur.length < min_move:
			should_break = true
		if not should_break:
			var move_normal := move / cur.length
			var preferred_right := -(Basis(cur.point.m_Orient) * Vector3.FORWARD).cross(move_normal) if m_Desc.m_BackIsInvisible else prev.nRight
			var frame := BaseBrushScript.compute_surface_frame_new(preferred_right, move_normal, cur.point.m_Orient)
			cur.nRight = frame.right
			cur.nSurface = frame.normal

		if not should_break and prev.has_geometry():
			var width_height_ratio := cur.length / pressured_size(cur.smoothedPressure)
			var break_angle := rad_to_deg(atan(width_height_ratio)) * K_BREAK_ANGLE_SCALAR
			var previous_move := prev.point.m_Pos - m_knots[index - 2].point.m_Pos
			if rad_to_deg(previous_move.angle_to(move)) > break_angle:
				should_break = true

		if should_break:
			cur.nRight = Vector3.ZERO
			cur.nSurface = Vector3.ZERO
			cur.startsGeometry = false
			cur.endsGeometry = false
			if prev.has_geometry() and not prev.endsGeometry:
				prev.endsGeometry = true
				prev.nTri += 2
				m_knots[index - 1] = prev
			cur.iTri = prev.iTri + prev.nTri
			cur.iVert = prev.iVert + prev.nVert
			cur.nTri = 0
			cur.nVert = 0
		else:
			if prev.has_geometry() and prev.endsGeometry:
				prev.endsGeometry = false
				prev.nTri -= 2
				m_knots[index - 1] = prev
			cur.startsGeometry = not prev.has_geometry()
			cur.endsGeometry = false
			cur.nVert = 8
			cur.nTri = 8
			cur.iTri = prev.iTri + prev.nTri
			if cur.startsGeometry:
				cur.iVert = prev.iVert + prev.nVert
				cur.nTri += 2
			else:
				cur.iVert = prev.iVert + prev.nVert - 4

		m_knots[index] = cur
		prev = cur

	if prev.has_geometry() and not prev.endsGeometry:
		prev.endsGeometry = true
		prev.nTri += 2
		m_knots[m_knots.size() - 1] = prev

func on_changed_make_geometry(knot_index: int) -> void:
	var prev := m_knots[knot_index - 1]
	for index in range(knot_index, m_knots.size()):
		var cur := m_knots[index]
		if cur.has_geometry():
			var tri := 0
			set_tri(cur.iTri, cur.iVert, tri, BT, BL, FT)
			tri += 1
			set_tri(cur.iTri, cur.iVert, tri, FT, BL, FL)
			tri += 1
			set_tri(cur.iTri, cur.iVert, tri, BT, FT, BR)
			tri += 1
			set_tri(cur.iTri, cur.iVert, tri, BR, FT, FR)
			tri += 1
			set_tri(cur.iTri, cur.iVert, tri, BB, FB, BL)
			tri += 1
			set_tri(cur.iTri, cur.iVert, tri, BL, FB, FL)
			tri += 1
			set_tri(cur.iTri, cur.iVert, tri, BB, BR, FB)
			tri += 1
			set_tri(cur.iTri, cur.iVert, tri, FB, BR, FR)
			tri += 1
			if cur.startsGeometry:
				set_tri(cur.iTri, cur.iVert, tri, BT, BR, BL)
				tri += 1
				set_tri(cur.iTri, cur.iVert, tri, BL, BR, BB)
				tri += 1
			if cur.endsGeometry:
				set_tri(cur.iTri, cur.iVert, tri, FT, FL, FR)
				tri += 1
				set_tri(cur.iTri, cur.iVert, tri, FR, FL, FB)
				tri += 1
			assert(tri == cur.nTri)

			if cur.startsGeometry:
				var start_size := pressured_size(prev.smoothedPressure) * prev.qFrame.x
				var start_half_right := cur.nRight * (start_size * 0.5)
				var start_half_up := cur.nSurface * (start_size * 0.5 * K_CROSS_SECTION_ASPECT_RATIO)
				my_set_vert(cur.iVert, BR, prev.point.m_Pos + start_half_right, cur.nRight)
				my_set_vert(cur.iVert, BL, prev.point.m_Pos - start_half_right, -cur.nRight)
				my_set_vert(cur.iVert, BT, prev.point.m_Pos + start_half_up, cur.nSurface)
				my_set_vert(cur.iVert, BB, prev.point.m_Pos - start_half_up, -cur.nSurface)

			var size := pressured_size(cur.smoothedPressure) * cur.qFrame.x
			var half_right := cur.nRight * (size * 0.5)
			var half_up := cur.nSurface * (size * 0.5 * K_CROSS_SECTION_ASPECT_RATIO)
			my_set_vert(cur.iVert, FR, cur.point.m_Pos + half_right, cur.nRight)
			my_set_vert(cur.iVert, FL, cur.point.m_Pos - half_right, -cur.nRight)
			my_set_vert(cur.iVert, FT, cur.point.m_Pos + half_up, cur.nSurface)
			my_set_vert(cur.iVert, FB, cur.point.m_Pos - half_up, -cur.nSurface)
		prev = cur

func my_set_vert(i_vert: int, vp: int, vertex: Vector3, normal: Vector3) -> void:
	var index := i_vert + vp * NS
	m_geometry.m_Vertices[index] = vertex
	m_geometry.m_Normals[index] = normal
	var color := m_Color
	color.a = 1.0
	color = _to_color32(color)
	m_geometry.m_Colors[index] = color
	m_geometry.m_Texcoord0.v2[index] = Vector2(0.5, 0.5)
