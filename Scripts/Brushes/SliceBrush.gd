class_name SliceBrush
extends GeometryBrush

const K_MINIMUM_MOVE_PS := 5e-4 * App.METERS_TO_UNITS
const K_VERTS_IN_QUAD := 4
const K_SOLID_MIN_LENGTH_METERS_PS := 0.0001
const K_SOLID_ASPECT_RATIO := 0.2

func _init() -> void:
	setup_geometry_brush(true, K_VERTS_IN_QUAD * 2, true)

func init_brush(desc: BrushDescriptor, local_pointer_xf: TrTransform) -> void:
	super.init_brush(desc, local_pointer_xf)
	m_geometry.set_layout(get_vertex_layout(desc))

func get_vertex_layout(_desc: BrushDescriptor) -> GeometryPool.VertexLayout:
	return GeometryPool.VertexLayout.create(
		GeometryPool.TexcoordInfo.create(3),
		null,
		null,
		true,
		true,
		false
	)

func get_spawn_interval(pressure01: float) -> float:
	return K_SOLID_MIN_LENGTH_METERS_PS * App.METERS_TO_UNITS * pointer_to_local() + pressured_size(pressure01) * K_SOLID_ASPECT_RATIO

func control_points_changed(knot_index: int) -> void:
	var start := knot_index - 1 if m_knots[knot_index - 1].has_geometry() else knot_index
	on_changed_frame_knots(start)
	on_changed_make_geometry(start)
	resize_geometry()

func on_changed_frame_knots(knot_index: int) -> void:
	var prev := m_knots[knot_index - 1]
	for index in range(knot_index, m_knots.size()):
		var cur := m_knots[index]
		var should_break := false
		var move := cur.point.m_Pos - prev.point.m_Pos
		cur.length = move.length()
		if cur.length < K_MINIMUM_MOVE_PS * pointer_to_local():
			should_break = true
		else:
			var tangent := move / cur.length
			if prev.has_geometry():
				cur.qFrame = compute_minimal_rotation_frame(tangent, prev.qFrame, cur.point.m_Orient)
			else:
				cur.qFrame = compute_minimal_rotation_frame(tangent, null, cur.point.m_Orient)
		if should_break:
			cur.qFrame = Quaternion(0.0, 0.0, 0.0, 0.0)
		cur.nTri = 0 if should_break else 1
		cur.nVert = 0 if should_break else 1
		m_knots[index] = cur
		prev = cur

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
			var rt := basis * Vector3.RIGHT
			var up := basis * Vector3.UP
			var fwd := basis * Vector3.FORWARD * -1.0
			var is_start := not prev.has_geometry()
			var w0: float
			if is_start:
				var half_size := pressured_size(prev.smoothedPressure) * 0.5
				w0 = 0.0
				make_quad(cur, prev.point.m_Pos, half_size, up, rt, fwd, w0)
			else:
				cur.iVert -= 4
				cur.nVert += 4
				w0 = m_geometry.m_Texcoord0.v3[cur.iVert].z

			var half_size := pressured_size(cur.smoothedPressure) * 0.5
			var w1 := w0 + cur.length * App.UNITS_TO_METERS
			make_quad(cur, cur.point.m_Pos, half_size, up, rt, fwd, w1)
		m_knots[index] = cur
		prev = cur

func make_quad(knot: Knot, center: Vector3, half_size: float, up: Vector3, rt: Vector3, fwd: Vector3, w: float) -> void:
	up *= half_size
	rt *= half_size
	append_vert(knot, center - rt - up, fwd, 0.0, 0.0, w)
	append_vert(knot, center - rt + up, fwd, 0.0, 1.0, w)
	append_vert(knot, center + rt + up, fwd, 1.0, 1.0, w)
	append_vert(knot, center + rt - up, fwd, 1.0, 0.0, w)
	append_tri(knot, 0, 1, 2)
	append_tri(knot, 2, 3, 0)

func append_vert(knot: Knot, position: Vector3, normal: Vector3, u: float, v: float, w: float) -> void:
	var color := m_Color
	color.a = 1.0
	color = _to_color32(color)
	var uvw := Vector3(u, v, w)
	var index := knot.iVert + knot.nVert
	knot.nVert += 1
	if index == m_geometry.m_Vertices.size():
		m_geometry.m_Vertices.append(position)
		m_geometry.m_Colors.append(color)
		m_geometry.m_Normals.append(normal)
		m_geometry.m_Texcoord0.v3.append(uvw)
	else:
		m_geometry.m_Vertices[index] = position
		m_geometry.m_Colors[index] = color
		m_geometry.m_Normals[index] = normal
		m_geometry.m_Texcoord0.v3[index] = uvw

func append_tri(knot: Knot, t0: int, t1: int, t2: int) -> void:
	var index := (knot.iTri + knot.nTri) * 3
	knot.nTri += 1
	if index == m_geometry.m_Tris.size():
		m_geometry.m_Tris.append(knot.iVert + t0)
		m_geometry.m_Tris.append(knot.iVert + t2)
		m_geometry.m_Tris.append(knot.iVert + t1)
	else:
		m_geometry.m_Tris[index] = knot.iVert + t0
		m_geometry.m_Tris[index + 1] = knot.iVert + t2
		m_geometry.m_Tris[index + 2] = knot.iVert + t1

func is_penultimate(knot_index: int) -> bool:
	return knot_index + 1 == m_knots.size() or not m_knots[knot_index + 1].has_geometry()

static func compute_minimal_rotation_frame(tangent: Vector3, previous_frame: Variant, bootstrap_orientation: Quaternion) -> Quaternion:
	if previous_frame == null:
		var desired_up := Basis(bootstrap_orientation) * Vector3.UP
		if abs(desired_up.dot(tangent)) > 0.99:
			desired_up = Basis(bootstrap_orientation) * Vector3.RIGHT
		return Basis.looking_at(-tangent, desired_up).get_rotation_quaternion()
	var previous_tangent := Basis(previous_frame as Quaternion) * Vector3.FORWARD * -1.0
	var minimal := QuaternionUtils.from_to_rotation(previous_tangent, tangent)
	return (minimal * (previous_frame as Quaternion)).normalized()
