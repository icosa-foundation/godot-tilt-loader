class_name TetraBrush
extends GeometryBrush

const TWO_PI := 2.0 * PI
const K_MINIMUM_MOVE := 5e-4 * App.METERS_TO_UNITS
const K_VERTS_IN_CLOSED_CIRCLE := 4
const K_BREAK_ANGLE_SCALAR := 3.0
const K_SOLID_MIN_LENGTH_METERS := 0.002
const K_SOLID_ASPECT_RATIO := 0.2

enum UVStyle {
	DISTANCE,
	UNITIZED,
}

var m_BreakAngleMultiplier := 2.0
var m_TextureEdgeChop := 0.0
var m_uvStyle := UVStyle.DISTANCE

func _init(can_batch: bool = true) -> void:
	setup_geometry_brush(can_batch, K_VERTS_IN_CLOSED_CIRCLE * 2, false)

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
	return K_SOLID_MIN_LENGTH_METERS * App.METERS_TO_UNITS + pressured_size(pressure01) * K_SOLID_ASPECT_RATIO

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
		var move := cur.smoothedPos - prev.smoothedPos
		cur.length = move.length()

		if cur.length < K_MINIMUM_MOVE:
			should_break = true
		else:
			var tangent := move / cur.length
			if prev.has_geometry():
				cur.qFrame = compute_minimal_rotation_frame(tangent, prev.qFrame, cur.point.m_Orient)
			else:
				var frame := BaseBrushScript.compute_surface_frame_new(Vector3.ZERO, tangent, cur.point.m_Orient)
				var up: Vector3 = frame.normal
				cur.qFrame = look_rotation(tangent, up)

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
		else:
			var basis := Basis(cur.qFrame)
			cur.nRight = basis * Vector3.RIGHT
			cur.nSurface = basis * Vector3.UP

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
			var right := basis * Vector3.RIGHT
			var up := basis * Vector3.UP
			var forward := basis * Vector3.BACK

			var random01 := m_rng.in01(cur.iVert - 1)
			var u0 := 0.0 if m_uvStyle == UVStyle.UNITIZED else random01
			var num_v: int = max(m_Desc.m_TextureAtlasV, 1)
			var atlas := int(random01 * 3331.0) % num_v
			var v0 := (atlas + m_TextureEdgeChop) / float(num_v)
			var v1 := (atlas + 1.0 - m_TextureEdgeChop) / float(num_v)

			var prev_size := pressured_size(prev.smoothedPressure)
			var prev_radius := prev_size * 0.5
			make_closed_circle(cur, prev.smoothedPos, prev_radius, K_VERTS_IN_CLOSED_CIRCLE, up, right, forward, u0, v0, v1)

			append_vert(cur, cur.smoothedPos, forward, m_Color, forward, Vector2.ZERO)

			var back_circle := 0
			var front_center := back_circle + K_VERTS_IN_CLOSED_CIRCLE
			for offset in range(K_VERTS_IN_CLOSED_CIRCLE - 1):
				append_tri(cur, back_circle + offset, front_center, back_circle + offset + 1)
			append_tri(cur, back_circle, back_circle + 1, back_circle + 2)
			append_tri(cur, back_circle + 2, back_circle + 3, back_circle)

		m_knots[index] = cur
		prev = cur

func make_closed_circle(
	knot: Knot,
	center: Vector3,
	radius: float,
	count: int,
	up: Vector3,
	right: Vector3,
	forward: Vector3,
	u: float,
	v0: float,
	v1: float
) -> void:
	up *= radius
	right *= radius
	for index in range(count):
		var t := index / float(count - 1)
		var theta := 0.0 if t == 1.0 else TWO_PI * t
		var uv := Vector2(u, index) if m_uvStyle == UVStyle.UNITIZED else Vector2(u, lerpf(v0, v1, t))
		var offset := -cos(theta) * up + -sin(theta) * right
		append_vert(knot, center + offset, offset.normalized(), m_Color, forward, uv)

func append_vert(knot: Knot, position: Vector3, normal: Vector3, color_value: Color, tangent: Vector3, uv: Vector2) -> void:
	var color := color_value
	color.a = 1.0
	var tangent4 := Vector4(tangent.x, tangent.y, tangent.z, 1.0)
	var index := knot.iVert + knot.nVert
	knot.nVert += 1
	if index == m_geometry.m_Vertices.size():
		m_geometry.m_Vertices.append(position)
		m_geometry.m_Normals.append(normal)
		m_geometry.m_Colors.append(color)
		m_geometry.m_Tangents.append(tangent4)
		m_geometry.m_Texcoord0.v2.append(uv)
	else:
		m_geometry.m_Vertices[index] = position
		m_geometry.m_Normals[index] = normal
		m_geometry.m_Colors[index] = color
		m_geometry.m_Tangents[index] = tangent4
		m_geometry.m_Texcoord0.v2[index] = uv

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

static func compute_minimal_rotation_frame(tangent: Vector3, previous_frame: Quaternion, _bootstrap_orientation: Quaternion) -> Quaternion:
	var previous_tangent := Basis(previous_frame) * Vector3.BACK
	var minimal := QuaternionUtils.from_to_rotation(previous_tangent, tangent)
	return (minimal * previous_frame).normalized()

static func look_rotation(forward: Vector3, up: Vector3) -> Quaternion:
	if abs(up.normalized().dot(forward.normalized())) > 0.99:
		up = Vector3.UP if abs(Vector3.UP.dot(forward.normalized())) < 0.99 else Vector3.RIGHT
	return Basis.looking_at(-forward, up).get_rotation_quaternion()
