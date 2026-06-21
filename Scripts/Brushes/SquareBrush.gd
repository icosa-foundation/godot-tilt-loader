class_name SquareBrush
extends GeometryBrush

const BBR_B := 0
const BBR_R := 1
const BTL_T := 2
const BTL_L := 3
const BTR_T := 4
const BTR_R := 5
const BBL_B := 6
const BBL_L := 7
const FBR_B := 8
const FBR_R := 9
const FTL_T := 10
const FTL_L := 11
const FTR_T := 12
const FTR_R := 13
const FBL_B := 14
const FBL_L := 15

const K_SOLID_MIN_LENGTH_METERS_PS := 0.002
const K_MIN_MOVE_LENGTH_METERS_PS := 5e-4
const K_BREAK_ANGLE_SCALAR := 2.0
const K_SOLID_ASPECT_RATIO := 0.2
const K_CROSS_SECTION_ASPECT_RATIO := 0.375

func _init() -> void:
	setup_geometry_brush(true, 8, false)

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
	resize_geometry()
	var start := knot_index - 1 if m_knots[knot_index - 1].has_geometry() else knot_index
	on_changed_make_geometry(start)

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
			var preferred_right := (Basis(cur.point.m_Orient) * Vector3.FORWARD * -1.0).cross(move_normal) if m_Desc.m_BackIsInvisible else prev.nRight
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
			cur.nVert = 16
			cur.nTri = 8
			cur.iTri = prev.iTri + prev.nTri
			if cur.startsGeometry:
				cur.iVert = prev.iVert + prev.nVert
				cur.nTri += 2
			else:
				cur.iVert = prev.iVert + prev.nVert - 8

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
			set_tri(cur.iTri, cur.iVert, tri, BTR_T, BTL_T, FTR_T)
			tri += 1
			set_tri(cur.iTri, cur.iVert, tri, FTR_T, BTL_T, FTL_T)
			tri += 1
			set_tri(cur.iTri, cur.iVert, tri, BTR_R, FTR_R, BBR_R)
			tri += 1
			set_tri(cur.iTri, cur.iVert, tri, BBR_R, FTR_R, FBR_R)
			tri += 1
			set_tri(cur.iTri, cur.iVert, tri, BBL_L, FBL_L, BTL_L)
			tri += 1
			set_tri(cur.iTri, cur.iVert, tri, BTL_L, FBL_L, FTL_L)
			tri += 1
			set_tri(cur.iTri, cur.iVert, tri, BBL_B, BBR_B, FBL_B)
			tri += 1
			set_tri(cur.iTri, cur.iVert, tri, FBL_B, BBR_B, FBR_B)
			tri += 1

			if cur.startsGeometry:
				set_tri(cur.iTri, cur.iVert, tri, BTR_R, BBR_R, BTL_L)
				tri += 1
				set_tri(cur.iTri, cur.iVert, tri, BTL_L, BBR_R, BBL_L)
				tri += 1
			if cur.endsGeometry:
				set_tri(cur.iTri, cur.iVert, tri, FTR_R, FTL_L, FBR_R)
				tri += 1
				set_tri(cur.iTri, cur.iVert, tri, FBR_R, FTL_L, FBL_L)
				tri += 1
			assert(tri == cur.nTri)

			if cur.startsGeometry:
				var start_size := pressured_size(prev.smoothedPressure)
				var start_half_right := cur.nRight * (start_size * 0.5)
				var start_half_up := cur.nSurface * (start_size * 0.5 * K_CROSS_SECTION_ASPECT_RATIO)
				my_set_vert(cur.iVert, BBR_B, prev.point.m_Pos - start_half_up + start_half_right, -cur.nSurface)
				my_set_vert(cur.iVert, BBR_R, prev.point.m_Pos - start_half_up + start_half_right, cur.nRight)
				my_set_vert(cur.iVert, BTL_T, prev.point.m_Pos + start_half_up - start_half_right, cur.nSurface)
				my_set_vert(cur.iVert, BTL_L, prev.point.m_Pos + start_half_up - start_half_right, -cur.nRight)
				my_set_vert(cur.iVert, BTR_T, prev.point.m_Pos + start_half_up + start_half_right, cur.nSurface)
				my_set_vert(cur.iVert, BTR_R, prev.point.m_Pos + start_half_up + start_half_right, cur.nRight)
				my_set_vert(cur.iVert, BBL_B, prev.point.m_Pos - start_half_up - start_half_right, -cur.nSurface)
				my_set_vert(cur.iVert, BBL_L, prev.point.m_Pos - start_half_up - start_half_right, -cur.nRight)

			var size := pressured_size(cur.smoothedPressure)
			var half_right := cur.nRight * (size * 0.5)
			var half_up := cur.nSurface * (size * 0.5 * K_CROSS_SECTION_ASPECT_RATIO)
			my_set_vert(cur.iVert, FBR_B, cur.point.m_Pos - half_up + half_right, -cur.nSurface)
			my_set_vert(cur.iVert, FBR_R, cur.point.m_Pos - half_up + half_right, cur.nRight)
			my_set_vert(cur.iVert, FTL_T, cur.point.m_Pos + half_up - half_right, cur.nSurface)
			my_set_vert(cur.iVert, FTL_L, cur.point.m_Pos + half_up - half_right, -cur.nRight)
			my_set_vert(cur.iVert, FTR_T, cur.point.m_Pos + half_up + half_right, cur.nSurface)
			my_set_vert(cur.iVert, FTR_R, cur.point.m_Pos + half_up + half_right, cur.nRight)
			my_set_vert(cur.iVert, FBL_B, cur.point.m_Pos - half_up - half_right, -cur.nSurface)
			my_set_vert(cur.iVert, FBL_L, cur.point.m_Pos - half_up - half_right, -cur.nRight)
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
