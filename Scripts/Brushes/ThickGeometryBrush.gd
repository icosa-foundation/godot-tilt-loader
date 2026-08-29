class_name ThickGeometryBrush
extends GeometryBrush

const K_VERTS_IN_SOLID := 12
const K_SHARED_VERTS_IN_SOLID_PAIR := 6
const K_TRIS_IN_SOLID := 8
const K_SHARED_TRIS_IN_SOLID_PAIR := 0

const BRT := 0
const BRB := 1
const BMT := 2
const BMB := 3
const BLT := 4
const BLB := 5
const FRT := 6
const FRB := 7
const FMT := 8
const FMB := 9
const FLT := 10
const FLB := 11

enum UVStyle {
	DISTANCE,
	STRETCH,
}

const K_SOLID_MIN_LENGTH_METERS_PS := 0.002
const K_MIN_MOVE_LENGTH_METERS_PS := 5e-4
const K_BREAK_ANGLE_SCALAR := 2.0
const K_SOLID_ASPECT_RATIO := 0.2

var m_TextureEdgeChop := 0.1
var m_uvStyle := UVStyle.DISTANCE

func _init() -> void:
	setup_geometry_brush(true, K_VERTS_IN_SOLID, false)

func init_brush(desc: BrushDescriptor, local_pointer_xf: TrTransform) -> void:
	super.init_brush(desc, local_pointer_xf)
	m_geometry.set_layout(get_vertex_layout(desc))

func get_vertex_layout(_desc: BrushDescriptor) -> GeometryPool.VertexLayout:
	return GeometryPool.VertexLayout.create(
		GeometryPool.TexcoordInfo.create(2, GeometryPool.Semantic.XY_IS_UV),
		GeometryPool.TexcoordInfo.create(),
		null,
		true,
		true,
		true
	)

func get_spawn_interval(pressure01: float) -> float:
	return K_SOLID_MIN_LENGTH_METERS_PS * App.METERS_TO_UNITS * pointer_to_local() + pressured_size(pressure01) * K_SOLID_ASPECT_RATIO

func control_points_changed(knot_index: int) -> void:
	on_changed_frame_knots(knot_index)
	resize_geometry()
	var start := knot_index - 1 if m_knots[knot_index - 1].has_geometry() else knot_index
	on_changed_make_verts_and_normals(start)
	if m_uvStyle == UVStyle.STRETCH:
		on_changed_stretch_uvs(knot_index)
	else:
		on_changed_distance_uvs(knot_index)
	on_changed_tangents(start)

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
	var belly := 1.0 / 8.0
	var hypotenuse := sqrt(1.0 + belly * belly)
	var sin_theta := belly / hypotenuse
	var cos_theta := 1.0 / hypotenuse
	var prev := m_knots[knot_index - 1]

	for index in range(knot_index, m_knots.size()):
		var cur := m_knots[index]
		if cur.has_geometry():
			var is_start := not prev.has_geometry()
			var is_end := is_penultimate(index)
			var tri := 0
			set_tri(cur.iTri, cur.iVert, tri, BRT, BMT, FMT)
			tri += 1
			set_tri(cur.iTri, cur.iVert, tri, BRT, FMT, FRT)
			tri += 1
			set_tri(cur.iTri, cur.iVert, tri, BRB, FRB, FMB)
			tri += 1
			set_tri(cur.iTri, cur.iVert, tri, BRB, FMB, BMB)
			tri += 1
			set_tri(cur.iTri, cur.iVert, tri, BMB, FLB, BLB)
			tri += 1
			set_tri(cur.iTri, cur.iVert, tri, BMB, FMB, FLB)
			tri += 1
			set_tri(cur.iTri, cur.iVert, tri, BMT, FLT, FMT)
			tri += 1
			set_tri(cur.iTri, cur.iVert, tri, BMT, BLT, FLT)

			var up_normal := cur.nSurface
			if is_start:
				var start_size := pressured_size(prev.smoothedPressure)
				var alpha := pressured_opacity(prev.smoothedPressure)
				var right := cur.nRight * (start_size * 0.5)
				set_vert(cur.iVert, BRT, prev.point.m_Pos + right, up_normal, m_Color, alpha)
				set_vert(cur.iVert, BRB, prev.point.m_Pos + right, -up_normal, m_Color, alpha)
				set_vert(cur.iVert, BMT, prev.point.m_Pos, up_normal, m_Color, alpha)
				set_vert(cur.iVert, BMB, prev.point.m_Pos, -up_normal, m_Color, alpha)
				set_vert(cur.iVert, BLT, prev.point.m_Pos - right, up_normal, m_Color, alpha)
				set_vert(cur.iVert, BLB, prev.point.m_Pos - right, -up_normal, m_Color, alpha)

			var size := pressured_size(cur.smoothedPressure)
			var alpha := pressured_opacity(cur.smoothedPressure)
			var right := cur.nRight * (size * 0.5)
			var up := cur.nSurface * (belly * size * 0.5)
			var cos_up: Vector3
			var sin_right: Vector3
			if is_end:
				cos_up = up_normal
				up = Vector3.ZERO
				sin_right = Vector3.ZERO
			else:
				cos_up = cos_theta * cur.nSurface
				sin_right = sin_theta * cur.nRight

			set_vert(cur.iVert, FRT, cur.point.m_Pos + right, cos_up + sin_right, m_Color, alpha)
			set_vert(cur.iVert, FRB, cur.point.m_Pos + right, -cos_up + sin_right, m_Color, alpha)
			set_vert(cur.iVert, FMT, cur.point.m_Pos + up, up_normal, m_Color, alpha)
			set_vert(cur.iVert, FMB, cur.point.m_Pos - up, -up_normal, m_Color, alpha)
			set_vert(cur.iVert, FLT, cur.point.m_Pos - right, cos_up - sin_right, m_Color, alpha)
			set_vert(cur.iVert, FLB, cur.point.m_Pos - right, -cos_up - sin_right, m_Color, alpha)
		prev = cur

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
		var num_v: int = m_Desc.m_TextureAtlasV
		var atlas := int(random01 * 3331.0) % num_v
		var v0 := (atlas + m_TextureEdgeChop) / float(num_v)
		var v1 := (atlas + 1.0 - m_TextureEdgeChop) / float(num_v)
		var vmid := (v0 + v1) * 0.5
		var distance := 0.0
		for index in range(knot0, knot1):
			var cur := m_knots[index]
			distance += cur.length
			var u := distance / total_length if total_length != 0.0 else 1.0
			if index == knot0:
				set_uv0(cur.iVert, BLT, Vector2(0.0, v0))
				set_uv0(cur.iVert, BLB, Vector2(0.0, v0))
				set_uv0(cur.iVert, BRT, Vector2(0.0, v1))
				set_uv0(cur.iVert, BRB, Vector2(0.0, v1))
				set_uv0(cur.iVert, BMT, Vector2(0.0, vmid))
				set_uv0(cur.iVert, BMB, Vector2(0.0, vmid))
			set_uv0(cur.iVert, FLT, Vector2(u, v0))
			set_uv0(cur.iVert, FLB, Vector2(u, v0))
			set_uv0(cur.iVert, FRT, Vector2(u, v1))
			set_uv0(cur.iVert, FRB, Vector2(u, v1))
			set_uv0(cur.iVert, FMT, Vector2(u, vmid))
			set_uv0(cur.iVert, FMB, Vector2(u, vmid))

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
				var u0v0 := m_geometry.m_Texcoord0.v2[prev.iVert + FLT * NS]
				u0 = u0v0.x
				v0 = u0v0.y
				v1 = m_geometry.m_Texcoord0.v2[prev.iVert + FRT * NS].y
			else:
				var random01 := m_rng.in01(cur.iVert - 1)
				u0 = random01
				var num_v: int = m_Desc.m_TextureAtlasV
				var atlas := int(random01 * 3331.0) % num_v
				v0 = (atlas + m_TextureEdgeChop) / float(num_v)
				v1 = (atlas + 1.0 - m_TextureEdgeChop) / float(num_v)
				var vmid := (v0 + v1) * 0.5
				set_uv0(cur.iVert, BLT, Vector2(u0, v0))
				set_uv0(cur.iVert, BLB, Vector2(u0, v0))
				set_uv0(cur.iVert, BRT, Vector2(u0, v1))
				set_uv0(cur.iVert, BRB, Vector2(u0, v1))
				set_uv0(cur.iVert, BMT, Vector2(u0, vmid))
				set_uv0(cur.iVert, BMB, Vector2(u0, vmid))

			var length := m_knots[index].length
			var size := pressured_size(m_knots[index].smoothedPressure)
			var u1 := u0 + m_Desc.m_TileRate * (length / size)
			var vmid := (v0 + v1) * 0.5
			set_uv0(cur.iVert, FLT, Vector2(u1, v0))
			set_uv0(cur.iVert, FLB, Vector2(u1, v0))
			set_uv0(cur.iVert, FRT, Vector2(u1, v1))
			set_uv0(cur.iVert, FRB, Vector2(u1, v1))
			set_uv0(cur.iVert, FMT, Vector2(u1, vmid))
			set_uv0(cur.iVert, FMB, Vector2(u1, vmid))
		prev = cur

func on_changed_tangents(knot_index: int) -> void:
	var prev := m_knots[knot_index - 1]
	for index in range(knot_index, m_knots.size()):
		var cur := m_knots[index]
		if cur.has_geometry():
			var st := BaseBrushScript.compute_st(m_geometry.m_Vertices, m_geometry.m_Texcoord0.v2, cur.iVert, BRT, BMT, FMT)
			var s: Vector3 = st.s
			if not prev.has_geometry():
				set_tangent(cur.iVert, BLT, s, -1.0)
				set_tangent(cur.iVert, BLB, s, -1.0)
				set_tangent(cur.iVert, BRT, s, -1.0)
				set_tangent(cur.iVert, BRB, s, -1.0)
				set_tangent(cur.iVert, BMT, s, -1.0)
				set_tangent(cur.iVert, BMB, s, -1.0)
			set_tangent(cur.iVert, FLT, s, -1.0)
			set_tangent(cur.iVert, FLB, s, -1.0)
			set_tangent(cur.iVert, FRT, s, -1.0)
			set_tangent(cur.iVert, FRB, s, -1.0)
			set_tangent(cur.iVert, FMT, s, -1.0)
			set_tangent(cur.iVert, FMB, s, -1.0)
		prev = cur

func is_penultimate(knot_index: int) -> bool:
	return knot_index + 1 == m_knots.size() or not m_knots[knot_index + 1].has_geometry()
