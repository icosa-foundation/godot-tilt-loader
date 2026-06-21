class_name BubbleWandBrush
extends TubeBrush

const K_VERTS_IN_CLOSED_CIRCLE := 9

var bubble_radius := 0.0
var bubble_center := Vector3.ZERO
var release_time := 0.0

func _init() -> void:
	super(false)

func init_brush(desc: BrushDescriptor, local_pointer_xf: TrTransform) -> void:
	super.init_brush(desc, local_pointer_xf)
	m_geometry.set_layout(get_vertex_layout(desc))

func get_vertex_layout(_desc: BrushDescriptor) -> GeometryPool.VertexLayout:
	return GeometryPool.VertexLayout.create(
		GeometryPool.TexcoordInfo.create(3),
		GeometryPool.TexcoordInfo.create(4),
		null,
		true,
		true,
		false
	)

func control_points_changed(knot_index: int) -> void:
	super.control_points_changed(knot_index)
	ListUtils.set_count(m_geometry.m_Texcoord1.v4, m_geometry.m_Vertices.size(), Vector4.ZERO)
	var num_uvws := m_geometry.m_Texcoord0.v3.size()
	for index in range(num_uvws):
		var uvw := m_geometry.m_Texcoord0.v3[index]
		var y := float((index + 1) % K_VERTS_IN_CLOSED_CIRCLE)
		uvw.x = (index + 1.0 - y) / (num_uvws + 2.0 - K_VERTS_IN_CLOSED_CIRCLE)
		uvw.y = y / float(K_VERTS_IN_CLOSED_CIRCLE - 1)
		m_geometry.m_Texcoord0.v3[index] = uvw

	var changed_vert0 := m_knots[knot_index].iVert
	var now := float(Time.get_ticks_msec()) / 1000.0
	for index in range(changed_vert0, num_uvws):
		var uvw := m_geometry.m_Texcoord0.v3[index]
		uvw.z = now
		m_geometry.m_Texcoord0.v3[index] = uvw

	var tube_centers: Array[Vector3] = []
	var radii: Array[float] = []
	var num_verts := m_geometry.m_Vertices.size()
	for index in range(K_VERTS_IN_CLOSED_CIRCLE - 1, num_verts - K_VERTS_IN_CLOSED_CIRCLE + 1, K_VERTS_IN_CLOSED_CIRCLE):
		var vertex_sum_circle := Vector3.ZERO
		for offset in range(K_VERTS_IN_CLOSED_CIRCLE - 1):
			vertex_sum_circle += m_geometry.m_Vertices[index + offset]
		vertex_sum_circle /= float(K_VERTS_IN_CLOSED_CIRCLE - 1)
		tube_centers.append(vertex_sum_circle)
		radii.append(vertex_sum_circle.distance_to(m_geometry.m_Vertices[index]))

	var volume := 0.0
	for index in range(1, tube_centers.size()):
		volume += tube_centers[index].distance_to(tube_centers[index - 1]) * PI * (radii[index] + radii[index - 1])
	bubble_radius = pow(0.75 * volume / PI, 1.0 / 3.0) if volume > 0.0 else 0.0

	var vertex_sum := Vector3.ZERO
	for vertex in m_geometry.m_Vertices:
		vertex_sum += vertex
	bubble_center = vertex_sum / float(num_verts) if num_verts > 0 else Vector3.ZERO

func finalize_solitary_brush() -> void:
	var num_verts := m_geometry.m_Vertices.size()
	for index in range(num_verts):
		var vertex := m_geometry.m_Vertices[index]
		m_geometry.m_Texcoord1.v4[index] = Vector4(vertex.x, vertex.y, vertex.z, 0.0)

	for _smooth_pass in range(2):
		for index in range(num_verts - K_VERTS_IN_CLOSED_CIRCLE, K_VERTS_IN_CLOSED_CIRCLE - 2, -1):
			var previous_index := index - K_VERTS_IN_CLOSED_CIRCLE
			if previous_index < 0:
				previous_index = 0
			var next_index := index + K_VERTS_IN_CLOSED_CIRCLE
			if next_index > num_verts - 1:
				next_index = num_verts - 1
			m_geometry.m_Vertices[index] = 0.5 * m_geometry.m_Vertices[previous_index] + 0.5 * m_geometry.m_Vertices[next_index]

		var vertex_sum := Vector3.ZERO
		for index in range(K_VERTS_IN_CLOSED_CIRCLE - 1, 2 * K_VERTS_IN_CLOSED_CIRCLE - 1):
			vertex_sum += m_geometry.m_Vertices[index]
		vertex_sum /= float(K_VERTS_IN_CLOSED_CIRCLE)
		for index in range(K_VERTS_IN_CLOSED_CIRCLE - 1):
			m_geometry.m_Vertices[index] = vertex_sum

		vertex_sum = Vector3.ZERO
		for index in range(num_verts - 2 * K_VERTS_IN_CLOSED_CIRCLE + 1, num_verts - K_VERTS_IN_CLOSED_CIRCLE + 1):
			vertex_sum += m_geometry.m_Vertices[index]
		vertex_sum /= float(K_VERTS_IN_CLOSED_CIRCLE)
		for index in range(num_verts - K_VERTS_IN_CLOSED_CIRCLE + 1, num_verts):
			m_geometry.m_Vertices[index] = vertex_sum

	release_time = float(Time.get_ticks_msec()) / 1000.0
	super.finalize_solitary_brush()
