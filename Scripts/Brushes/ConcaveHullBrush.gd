class_name ConcaveHullBrush
extends GeometryBrush

const K_TOLERANCE_METERS_PS := 1e-6
const K_VERTICES_PER_KNOT_RAPIDOGRAPH := 1
const K_VERTICES_PER_KNOT_QUILL_PEN := 2
const K_VERTICES_PER_KNOT_TETRAHEDRON := 4
const K_VERTICES_PER_KNOT_OCTAHEDRON := 6
const K_VERTICES_PER_KNOT_CUBE := 8

enum KnotConversion {
	RAPIDOGRAPH,
	QUILL_PEN,
	TETRAHEDRON,
	OCTAHEDRON,
	CUBE,
}

var m_KnotsInHull := 1
var m_Faceted := false
var m_KnotConversion := KnotConversion.RAPIDOGRAPH
var m_AllVertices: Array[Vector3] = []

func _init() -> void:
	setup_geometry_brush(true, 1, false)

func init_brush(desc: BrushDescriptor, local_pointer_xf: TrTransform) -> void:
	super.init_brush(desc, local_pointer_xf)
	m_geometry.set_layout(get_vertex_layout(desc))
	fix_initial_knot_size()
	create_vertices_from_knots(0)

func reset_brush_for_preview(local_pointer_xf: TrTransform) -> void:
	super.reset_brush_for_preview(local_pointer_xf)
	fix_initial_knot_size()
	create_vertices_from_knots(0)

func fix_initial_knot_size() -> void:
	for index in range(mini(2, m_knots.size())):
		var knot := m_knots[index]
		knot.point.m_Pressure = 0.0
		knot.smoothedPressure = 0.0
		m_knots[index] = knot

func get_spawn_interval(_pressure01: float) -> float:
	return m_Desc.m_SolidMinLengthMeters_PS * pointer_to_local() * App.METERS_TO_UNITS

func control_points_changed(knot_index: int) -> void:
	create_vertices_from_knots(knot_index)
	on_changed_make_geometry(knot_index)

func get_vertex_layout(_desc: BrushDescriptor) -> GeometryPool.VertexLayout:
	return GeometryPool.VertexLayout.create(
		GeometryPool.TexcoordInfo.create(),
		GeometryPool.TexcoordInfo.create(),
		null,
		true,
		true,
		false
	)

func resize_vertices(desired: int) -> void:
	ListUtils.set_count(m_AllVertices, desired, Vector3.ZERO)

func get_num_vertices_per_knot() -> int:
	match m_KnotConversion:
		KnotConversion.RAPIDOGRAPH:
			return K_VERTICES_PER_KNOT_RAPIDOGRAPH
		KnotConversion.QUILL_PEN:
			return K_VERTICES_PER_KNOT_QUILL_PEN
		KnotConversion.TETRAHEDRON:
			return K_VERTICES_PER_KNOT_TETRAHEDRON
		KnotConversion.OCTAHEDRON:
			return K_VERTICES_PER_KNOT_OCTAHEDRON
		KnotConversion.CUBE:
			return K_VERTICES_PER_KNOT_CUBE
		_:
			return 0

func create_vertices_from_knots(knot_index: int) -> void:
	var vertices_per_knot := get_num_vertices_per_knot()
	resize_vertices(m_knots.size() * vertices_per_knot)
	match m_KnotConversion:
		KnotConversion.RAPIDOGRAPH:
			for index in range(knot_index, m_knots.size()):
				m_AllVertices[index] = m_knots[index].point.m_Pos
		KnotConversion.QUILL_PEN:
			for index in range(knot_index, m_knots.size()):
				var knot := m_knots[index]
				var half_size := 0.5 * pressured_size(knot.point.m_Pressure)
				var half_extent := half_size * (Basis(knot.point.m_Orient) * Vector3.RIGHT)
				var vertex_index := index * vertices_per_knot
				m_AllVertices[vertex_index] = knot.point.m_Pos - half_extent
				m_AllVertices[vertex_index + 1] = knot.point.m_Pos + half_extent
		KnotConversion.TETRAHEDRON:
			for index in range(knot_index, m_knots.size()):
				var knot := m_knots[index]
				var half_size := 0.5 * pressured_size(knot.point.m_Pressure)
				var h := half_size / sqrt(3.0)
				var basis := Basis(knot.point.m_Orient)
				var vertex0 := index * vertices_per_knot
				m_AllVertices[vertex0 + 0] = knot.point.m_Pos + basis * Vector3(-h, -h, -h)
				m_AllVertices[vertex0 + 1] = knot.point.m_Pos + basis * Vector3(+h, +h, -h)
				m_AllVertices[vertex0 + 2] = knot.point.m_Pos + basis * Vector3(+h, -h, +h)
				m_AllVertices[vertex0 + 3] = knot.point.m_Pos + basis * Vector3(-h, +h, +h)
		KnotConversion.OCTAHEDRON:
			for index in range(knot_index, m_knots.size()):
				var knot := m_knots[index]
				var half_size := 0.5 * pressured_size(knot.point.m_Pressure)
				var basis := Basis(knot.point.m_Orient)
				var vertex_index := index * vertices_per_knot
				for axis in range(3):
					var offset := Vector3.ZERO
					offset[axis] = half_size
					offset = basis * offset
					m_AllVertices[vertex_index] = knot.point.m_Pos + offset
					m_AllVertices[vertex_index + 1] = knot.point.m_Pos - offset
					vertex_index += 2
		KnotConversion.CUBE:
			for index in range(knot_index, m_knots.size()):
				var knot := m_knots[index]
				var half_size := 0.5 * pressured_size(knot.point.m_Pressure)
				var basis := Basis(knot.point.m_Orient)
				var vertex_index := index * vertices_per_knot
				for xm in [-1.0, 1.0]:
					for ym in [-1.0, 1.0]:
						for zm in [-1.0, 1.0]:
							var offset := Vector3(xm * half_size, ym * half_size, zm * half_size)
							m_AllVertices[vertex_index] = knot.point.m_Pos + basis * offset
							vertex_index += 1

func on_changed_make_geometry(knot_index: int) -> void:
	var vertices_per_knot := get_num_vertices_per_knot()
	var knots_in_hull := maxi(m_KnotsInHull, 1)
	for index in range(knot_index, m_knots.size()):
		var cur := m_knots[index]
		if index > 0:
			var prev := m_knots[index - 1]
			cur.iVert = prev.iVert + prev.nVert
			cur.iTri = prev.iTri + prev.nTri
		else:
			cur.iVert = 0
			cur.iTri = 0
		cur.nVert = 0
		cur.nTri = 0
		var knot_range0 := maxi(0, index + 1 - knots_in_hull)
		var knot_range1 := index + 1
		var vertex_start := vertices_per_knot * knot_range0
		var vertex_count := vertices_per_knot * (knot_range1 - knot_range0)
		var input := m_AllVertices.slice(vertex_start, vertex_start + vertex_count)
		var hull := create_hull(input)
		if bool(hull.ok):
			if m_Faceted:
				create_faceted_geometry(cur, hull)
			else:
				create_smooth_geometry(cur, hull)
		m_knots[index] = cur

func create_hull(input: Array[Vector3]) -> Dictionary:
	if input.size() < 4:
		return {"ok": false, "points": [], "faces": []}
	return ConvexHullUtil.create(input, K_TOLERANCE_METERS_PS * App.METERS_TO_UNITS * pointer_to_local())

func create_faceted_geometry(knot: Knot, hull: Dictionary) -> void:
	m_geometry.set_num_verts(knot.iVert)
	m_geometry.set_num_tri_indices(knot.iTri * 3)
	var points: Array = hull.points
	for face in hull.faces:
		var base_vertex := knot.iVert + knot.nVert
		var normal: Vector3 = face.normal
		for point_index in face.indices:
			append_vert(knot, points[int(point_index)], normal)
		var num_fan: int = face.indices.size() - 2
		for fan in range(num_fan):
			append_tri(knot, base_vertex, base_vertex + fan + 1, base_vertex + fan + 2)

func create_smooth_geometry(knot: Knot, hull: Dictionary) -> void:
	m_geometry.set_num_verts(knot.iVert)
	m_geometry.set_num_tri_indices(knot.iTri * 3)
	var points: Array = hull.points
	var temp_normals: Array[Vector3] = []
	var temp_indices: Array[int] = []
	ListUtils.set_count(temp_normals, points.size(), Vector3.ZERO)
	ListUtils.set_count(temp_indices, points.size(), 0)
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
	for point_index in range(points.size()):
		temp_indices[point_index] = knot.iVert + knot.nVert
		append_vert(knot, points[point_index], temp_normals[point_index].normalized())
	for face in hull.faces:
		var indices: Array = face.indices
		var num_fan: int = indices.size() - 2
		for fan in range(num_fan):
			append_tri(knot, temp_indices[int(indices[0])], temp_indices[int(indices[fan + 1])], temp_indices[int(indices[fan + 2])])
			append_tri(knot, temp_indices[int(indices[0])], temp_indices[int(indices[fan + 2])], temp_indices[int(indices[fan + 1])])

func append_vert(knot: Knot, position: Vector3, normal: Vector3) -> void:
	m_geometry.m_Vertices.append(position)
	m_geometry.m_Normals.append(normal)
	m_geometry.m_Colors.append(m_Color)
	knot.nVert += 1
	if m_bDoubleSided:
		m_geometry.m_Vertices.append(position)
		m_geometry.m_Normals.append(-normal)
		m_geometry.m_Colors.append(m_Color)
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
