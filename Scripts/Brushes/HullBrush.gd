class_name HullBrush
extends GeometryBrush

const K_TOLERANCE_METERS_PS := 1e-6
const K_VERTICES_PER_KNOT_POINT := 1
const K_VERTICES_PER_KNOT_TETRAHEDRON := 4
const K_DIRECTED_SPHERE_RING_POINTS := 4
const K_DIRECTED_SPHERE_RINGS := 2
const K_DIRECTED_SPHERE_RING_ANGLE_DEGREES := 45.0
const K_VERTICES_PER_KNOT_DIRECTED_SPHERE := 1 + K_DIRECTED_SPHERE_RING_POINTS * K_DIRECTED_SPHERE_RINGS
const K_FACETED_FACE_NORMAL_DOT := 0.985

enum KnotConversion {
	POINT,
	TETRAHEDRON,
	DIRECTED_SPHERE,
}

enum SimplifyMode {
	DISABLED,
	SIMPLIFY_AT_END,
	SIMPLIFY_INTERACTIVELY,
}

var m_Faceted := false
var m_TrackInterior := false
var m_KnotConversion := KnotConversion.POINT
var m_Simplification_PS := 0.0
var m_SimplifyMode := SimplifyMode.DISABLED
var m_LastHullInputCount := 0
var m_AllVertices: Array[Dictionary] = []

func _init() -> void:
	setup_geometry_brush(true, 1, false)

func should_current_line_end() -> bool:
	return super.should_current_line_end()

func init_brush(desc: BrushDescriptor, local_pointer_xf: TrTransform) -> void:
	super.init_brush(desc, local_pointer_xf)
	set_double_sided(desc)
	m_geometry.set_layout(get_vertex_layout(desc))
	create_vertices_from_knots(0)

func get_spawn_interval(_pressure01: float) -> float:
	return m_Desc.m_SolidMinLengthMeters_PS * pointer_to_local() * App.METERS_TO_UNITS

func control_points_changed(knot_index: int) -> void:
	on_changed_frame_knots(knot_index)
	create_vertices_from_knots(knot_index)
	on_changed_make_geometry()

func reset_brush_for_preview(local_pointer_xf: TrTransform) -> void:
	super.reset_brush_for_preview(local_pointer_xf)
	create_vertices_from_knots(0)

func resize_vertices(desired: int) -> void:
	if m_AllVertices.size() > desired:
		m_AllVertices = m_AllVertices.slice(0, desired)
	else:
		while m_AllVertices.size() < desired:
			m_AllVertices.append({"position": Vector3.ZERO, "interior": false})

func on_changed_frame_knots(knot_index: int) -> void:
	var prev := m_knots[knot_index - 1]
	for index in range(knot_index, m_knots.size()):
		var cur := m_knots[index]
		var move := cur.point.m_Pos - prev.point.m_Pos
		var frame := BaseBrushScript.compute_surface_frame_new(prev.nRight, move.normalized(), cur.point.m_Orient)
		cur.nRight = frame.right
		cur.nSurface = frame.normal
		m_knots[index] = cur
		prev = cur

func get_num_vertices_per_knot() -> int:
	match m_KnotConversion:
		KnotConversion.POINT:
			return K_VERTICES_PER_KNOT_POINT
		KnotConversion.TETRAHEDRON:
			return K_VERTICES_PER_KNOT_TETRAHEDRON
		KnotConversion.DIRECTED_SPHERE:
			return K_VERTICES_PER_KNOT_DIRECTED_SPHERE
		_:
			return 0

func create_vertices_from_knots(knot_index: int) -> void:
	var vertices_per_knot := get_num_vertices_per_knot()
	resize_vertices(m_knots.size() * vertices_per_knot)
	match m_KnotConversion:
		KnotConversion.POINT:
			for index in range(knot_index, m_knots.size()):
				_set_vertex(index, m_knots[index].point.m_Pos)
		KnotConversion.TETRAHEDRON:
			var half_width := m_BaseSize_PS / sqrt(3.0)
			for index in range(knot_index, m_knots.size()):
				var position := m_knots[index].point.m_Pos
				var vertex0 := index * vertices_per_knot
				_set_vertex(vertex0 + 0, position + Vector3(-half_width, -half_width, -half_width))
				_set_vertex(vertex0 + 1, position + Vector3(+half_width, +half_width, -half_width))
				_set_vertex(vertex0 + 2, position + Vector3(+half_width, -half_width, +half_width))
				_set_vertex(vertex0 + 3, position + Vector3(-half_width, +half_width, +half_width))
		KnotConversion.DIRECTED_SPHERE:
			for index in range(knot_index, m_knots.size()):
				var center := m_knots[index].point.m_Pos
				var vertex0 := index * vertices_per_knot
				if index == 0:
					for offset in range(vertices_per_knot):
						_set_vertex(vertex0 + offset, center)
				else:
					var pressure := m_knots[index].smoothedPressure if m_PreviewMode else m_knots[index].point.m_Pressure
					var radius := pressured_size(pressure) * 0.5
					var move := center - m_knots[index - 1].point.m_Pos
					if move.length_squared() <= 1e-12:
						for offset in range(vertices_per_knot):
							_set_vertex(vertex0 + offset, center)
						continue
					var direction := move.normalized()
					var ortho := m_knots[index].nRight.normalized()
					if ortho.length_squared() <= 1e-12:
						ortho = direction.cross(Vector3.UP)
						if ortho.length_squared() <= 1e-12:
							ortho = direction.cross(Vector3.RIGHT)
						ortho = ortho.normalized()
					var point := direction * radius
					_set_vertex(vertex0, center + point)
					var q_phi := Quaternion(ortho, deg_to_rad(K_DIRECTED_SPHERE_RING_ANGLE_DEGREES))
					var q_half_theta := Quaternion(direction, deg_to_rad(360.0 / K_DIRECTED_SPHERE_RING_POINTS / 2.0))
					var q_theta := q_half_theta * q_half_theta
					for ring in range(K_DIRECTED_SPHERE_RINGS):
						point = q_phi * point
						for ring_point in range(K_DIRECTED_SPHERE_RING_POINTS):
							_set_vertex(vertex0 + 1 + ring * K_DIRECTED_SPHERE_RING_POINTS + ring_point, center + point)
							point = q_theta * point

func on_changed_make_geometry(_is_end: bool = false) -> void:
	if m_knots.size() < 2:
		return
	var input: Array[Vector3] = []
	var input_indices: Array[int] = []
	var input_vertex_count := m_AllVertices.size()
	var record_interior := false
	if m_TrackInterior and m_knots.size() >= 2:
		var last := m_knots.size() - 1
		if m_knots[last].point.m_Pos == m_knots[last - 1].point.m_Pos:
			record_interior = true
			input_vertex_count = maxi(0, input_vertex_count - get_num_vertices_per_knot())
	for vertex_index in range(input_vertex_count):
		var vertex := m_AllVertices[vertex_index]
		if not bool(vertex.interior):
			input.append(vertex.position)
			input_indices.append(vertex_index)
	m_LastHullInputCount = input.size()
	var knot := m_knots[1]
	knot.iVert = 0
	knot.nVert = 0
	knot.iTri = 0
	knot.nTri = 0
	m_geometry.m_Vertices.clear()
	m_geometry.m_Normals.clear()
	m_geometry.m_Colors.clear()
	m_geometry.m_Texcoord0.v3.clear()
	m_geometry.m_Tris.clear()

	var hull := create_hull(input)
	if bool(hull.ok):
		if record_interior:
			record_interior_vertices(input_indices, hull.points)
		if m_Faceted:
			hull = merge_similar_faceted_faces(hull)
			create_faceted_geometry(knot, hull)
		else:
			create_smooth_geometry(knot, hull)
	m_knots[1] = knot

func create_hull(input: Array[Vector3]) -> Dictionary:
	if input.size() < 4:
		return {"ok": false, "points": [], "faces": []}
	return ConvexHullUtil.create(input, K_TOLERANCE_METERS_PS * App.METERS_TO_UNITS * pointer_to_local())

func record_interior_vertices(input_indices: Array[int], hull_points: Array) -> void:
	var hull_lookup := {}
	for point in hull_points:
		hull_lookup[_point_key(point)] = true
	for vertex_index in input_indices:
		var vertex := m_AllVertices[vertex_index]
		vertex.interior = not hull_lookup.has(_point_key(vertex.position))
		m_AllVertices[vertex_index] = vertex

func _point_key(point: Vector3) -> String:
	return "%d:%d:%d" % [
		roundi(point.x / K_TOLERANCE_METERS_PS),
		roundi(point.y / K_TOLERANCE_METERS_PS),
		roundi(point.z / K_TOLERANCE_METERS_PS),
	]

func merge_similar_faceted_faces(hull: Dictionary) -> Dictionary:
	var points: Array = hull.points
	var groups: Array[Dictionary] = []
	for face in hull.faces:
		var normal: Vector3 = face.normal
		var group := _find_similar_face_group(groups, normal)
		if group.is_empty():
			group = {
				"normal_sum": Vector3.ZERO,
				"normal": normal,
				"indices": {},
			}
			groups.append(group)
		group.normal_sum += normal
		group.normal = (group.normal_sum as Vector3).normalized()
		for index in face.indices:
			group.indices[int(index)] = true

	var faces: Array = []
	for group in groups:
		var indices: Array[int] = []
		for index in group.indices.keys():
			indices.append(int(index))
		if indices.size() < 3:
			continue
		var normal: Vector3 = group.normal
		var boundary := _convex_face_boundary(points, indices, normal)
		if boundary.size() >= 3:
			faces.append({
				"indices": boundary,
				"normal": normal,
				"vertices": _project_face_vertices(points, boundary, normal),
			})

	if faces.is_empty():
		return hull
	return {"ok": true, "points": points, "faces": faces}

func _find_similar_face_group(groups: Array[Dictionary], normal: Vector3) -> Dictionary:
	for group in groups:
		var group_normal: Vector3 = group.normal
		if group_normal.dot(normal) >= K_FACETED_FACE_NORMAL_DOT:
			return group
	return {}

func _convex_face_boundary(points: Array, indices: Array[int], normal: Vector3) -> Array[int]:
	var center := Vector3.ZERO
	for index in indices:
		center += points[index]
	center /= float(indices.size())
	var axis_u := normal.cross(Vector3.UP)
	if axis_u.length_squared() <= 1e-12:
		axis_u = normal.cross(Vector3.RIGHT)
	axis_u = axis_u.normalized()
	var axis_v := normal.cross(axis_u).normalized()

	var projected: Array[Dictionary] = []
	for index in indices:
		var offset: Vector3 = points[index] - center
		projected.append({
			"index": index,
			"uv": Vector2(offset.dot(axis_u), offset.dot(axis_v)),
		})
	var boundary := _convex_hull_2d(projected)
	if boundary.size() >= 3:
		var p0: Vector3 = points[boundary[0]]
		var p1: Vector3 = points[boundary[1]]
		var p2: Vector3 = points[boundary[2]]
		if (p1 - p0).cross(p2 - p0).dot(normal) < 0.0:
			boundary.reverse()
	return boundary

func _project_face_vertices(points: Array, indices: Array[int], normal: Vector3) -> Array[Vector3]:
	var support_distance := -INF
	for index in indices:
		support_distance = maxf(support_distance, normal.dot(points[index]))
	var vertices: Array[Vector3] = []
	for index in indices:
		var point: Vector3 = points[index]
		vertices.append(point + normal * (support_distance - normal.dot(point)))
	return vertices

func _convex_hull_2d(projected: Array[Dictionary]) -> Array[int]:
	projected.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var auv: Vector2 = a.uv
		var buv: Vector2 = b.uv
		if not is_equal_approx(auv.x, buv.x):
			return auv.x < buv.x
		return auv.y < buv.y
	)

	var lower: Array[Dictionary] = []
	for item in projected:
		while lower.size() >= 2 and _cross_2d(lower[lower.size() - 2].uv, lower[lower.size() - 1].uv, item.uv) <= 0.0:
			lower.pop_back()
		lower.append(item)

	var upper: Array[Dictionary] = []
	for reverse_index in range(projected.size() - 1, -1, -1):
		var item := projected[reverse_index]
		while upper.size() >= 2 and _cross_2d(upper[upper.size() - 2].uv, upper[upper.size() - 1].uv, item.uv) <= 0.0:
			upper.pop_back()
		upper.append(item)

	lower.pop_back()
	upper.pop_back()
	var boundary: Array[int] = []
	for item in lower:
		boundary.append(int(item.index))
	for item in upper:
		boundary.append(int(item.index))
	return boundary

func _cross_2d(a: Vector2, b: Vector2, c: Vector2) -> float:
	return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)

func create_faceted_geometry(knot: Knot, hull: Dictionary) -> void:
	var points: Array = hull.points
	for face in hull.faces:
		var base_vertex := int(m_geometry.m_Vertices.size() / NS)
		var normal: Vector3 = face.normal
		var face_vertices: Array = face.get("vertices", [])
		if face_vertices.is_empty():
			for index in face.indices:
				append_vert(knot, points[int(index)], normal)
		else:
			for position in face_vertices:
				append_vert(knot, position, normal)
		var num_fan: int = face.indices.size() - 2
		for fan in range(num_fan):
			append_tri(knot, base_vertex, base_vertex + fan + 1, base_vertex + fan + 2)

func create_smooth_geometry(knot: Knot, hull: Dictionary) -> void:
	var points: Array = hull.points
	var temp_normals: Array[Vector3] = []
	ListUtils.set_count(temp_normals, points.size(), Vector3.ZERO)
	for face in hull.faces:
		var normal: Vector3 = face.normal
		var indices: Array = face.indices
		var count := indices.size()
		for offset in range(count):
			var prev: Vector3 = points[int(indices[(offset - 1 + count) % count])]
			var next: Vector3 = points[int(indices[(offset + 1) % count])]
			var cur: Vector3 = points[int(indices[offset])]
			var angle := rad_to_deg((prev - cur).angle_to(next - cur))
			temp_normals[int(indices[offset])] += normal * angle
		var num_fan: int = indices.size() - 2
		for fan in range(num_fan):
			append_tri(knot, int(indices[0]), int(indices[fan + 1]), int(indices[fan + 2]))
	for index in range(points.size()):
		append_vert(knot, points[index], temp_normals[index].normalized())

func get_vertex_layout(_desc: BrushDescriptor) -> GeometryPool.VertexLayout:
	return GeometryPool.VertexLayout.create(
		GeometryPool.TexcoordInfo.create(3, GeometryPool.Semantic.XY_IS_UV_Z_IS_DISTANCE),
		GeometryPool.TexcoordInfo.create(),
		null,
		true,
		true,
		false
	)

func append_vert(knot: Knot, position: Vector3, normal: Vector3) -> void:
	var uv := Vector3(0.0, 0.0, m_BaseSize_PS)
	m_geometry.m_Vertices.append(position)
	m_geometry.m_Normals.append(normal)
	m_geometry.m_Colors.append(m_Color)
	m_geometry.m_Texcoord0.v3.append(uv)
	knot.nVert += 1
	if m_bDoubleSided:
		m_geometry.m_Vertices.append(position)
		m_geometry.m_Normals.append(-normal)
		m_geometry.m_Colors.append(m_Color)
		m_geometry.m_Texcoord0.v3.append(uv)
		knot.nVert += 1

func append_tri(knot: Knot, vp0: int, vp1: int, vp2: int) -> void:
	m_geometry.m_Tris.append(vp0 * NS)
	m_geometry.m_Tris.append(vp1 * NS)
	m_geometry.m_Tris.append(vp2 * NS)
	knot.nTri += 1
	if m_bDoubleSided:
		m_geometry.m_Tris.append(vp0 * NS + 1)
		m_geometry.m_Tris.append(vp2 * NS + 1)
		m_geometry.m_Tris.append(vp1 * NS + 1)
		knot.nTri += 1

func _set_vertex(index: int, position: Vector3) -> void:
	m_AllVertices[index].position = position
	m_AllVertices[index].interior = false
