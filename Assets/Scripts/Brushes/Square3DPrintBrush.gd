class_name Square3DPrintBrush
extends GeometryBrush

const K_RING_DENSE_DISTANCE_METERS_LS := 0.005
const K_RING_SPARSE_DISTANCE_METERS_LS := 0.1
const K_MAX_CAP_FORWARD_RATIO := 0.01
const K_MIN_DIST_KNOTS_METERS_LS := 0.003
const K_SWING_BREAK_VALUE := 0.940
const K_TWIST_BREAK_VALUE := 0.940
const K_INDICATOR_PLANE_BREAK_VALUE := 0.0087
const K_NUM_CAP_VERTS := 4
const K_MAX_BEVEL_VERTS := 10

const K_DEFAULT_BEVEL_SIZE := 0.01
const K_DEFAULT_BEVEL_VERTS := 2
const K_DEFAULT_TESSELLATION := 1.0
const K_DEFAULT_TRANSPARENCY := 255

class GeometryBasis:
	var nStrokeTangent := Vector3.ZERO
	var strokeInlineWithPlaneNormal := false
	var nCrossSectionNormal := Vector3.ZERO
	var nCrossSectionTangentWidth := Vector3.ZERO
	var nCrossSectionTangentThickness := Vector3.ZERO
	var widthVectorToEdge := Vector3.ZERO
	var thicknessVectorToEdge := Vector3.ZERO
	var widthVectorToBevel := Vector3.ZERO
	var thicknessVectorToBevel := Vector3.ZERO
	var capNormalOffset := Vector3.ZERO

	func _init(knot: GeometryBrush.Knot, brush: Square3DPrintBrush, manually_set_stroke_tangent: Variant = null) -> void:
		nStrokeTangent = manually_set_stroke_tangent if manually_set_stroke_tangent != null else Basis(knot.qFrame) * Vector3.BACK
		var orientation_basis := Basis(knot.point.m_Orient)
		var indicator_plane_tangent_right := orientation_basis * Vector3.RIGHT
		var indicator_plane_tangent_forward := orientation_basis * Vector3.BACK
		var indicator_plane_normal := orientation_basis * Vector3.UP
		strokeInlineWithPlaneNormal = nStrokeTangent.dot(indicator_plane_normal) > 0.0
		if strokeInlineWithPlaneNormal:
			nCrossSectionNormal = indicator_plane_normal
			nCrossSectionTangentWidth = indicator_plane_tangent_right
			nCrossSectionTangentThickness = -indicator_plane_tangent_forward
		else:
			nCrossSectionNormal = -indicator_plane_normal
			nCrossSectionTangentWidth = indicator_plane_tangent_right
			nCrossSectionTangentThickness = indicator_plane_tangent_forward
		var half_width := brush.pressured_size(knot.smoothedPressure) * 0.5
		var half_thickness := brush.pressured_size(knot.smoothedPressure) * 0.5
		widthVectorToEdge = half_width * nCrossSectionTangentWidth
		widthVectorToBevel = widthVectorToEdge * brush.m_bevelRatio
		thicknessVectorToEdge = half_thickness * nCrossSectionTangentThickness
		thicknessVectorToBevel = thicknessVectorToEdge * brush.m_bevelRatio
		capNormalOffset = nStrokeTangent * minf(1.0 - brush.m_bevelRatio, K_MAX_CAP_FORWARD_RATIO)

var m_bevelRatio := 0.99
var m_bevelVerts := 2
var m_tessellation := 1.0
var m_transparency := 255
var m_debugShowSurfaceOrientation := false

func _init(can_batch: bool = true) -> void:
	setup_geometry_brush(can_batch, 2 * 4 * K_MAX_BEVEL_VERTS, false)

func _verts_per_ring() -> int:
	return 4 * m_bevelVerts

func init_brush(desc: BrushDescriptor, local_pointer_xf: TrTransform) -> void:
	super.init_brush(desc, local_pointer_xf)
	m_geometry.set_layout(get_vertex_layout(desc))
	m_bevelRatio = 1.0 - K_DEFAULT_BEVEL_SIZE
	m_bevelVerts = K_DEFAULT_BEVEL_VERTS
	m_tessellation = K_DEFAULT_TESSELLATION
	m_transparency = K_DEFAULT_TRANSPARENCY

func control_points_changed(knot_index: int) -> void:
	var start := knot_index - 1 if m_knots[knot_index - 1].has_geometry() else knot_index
	if on_changed_frame_knots(start):
		start = maxi(1, start - 1)
	on_changed_make_geometry(start)
	resize_geometry()

func on_changed_frame_knots(knot_index: int) -> bool:
	var initial_knot_contains_break := false
	var prev := m_knots[knot_index - 1]
	for index in range(knot_index, m_knots.size()):
		var cur := m_knots[index]
		var stroke := cur.smoothedPos - prev.smoothedPos
		cur.length = stroke.length()
		var should_break := cur.length <= 0.0
		var cur_stroke_tangent := Vector3.ZERO
		if not should_break:
			var prev_basis := Basis(prev.point.m_Orient)
			var cur_basis := Basis(cur.point.m_Orient)
			var prev_plane_normal := prev_basis * Vector3.UP
			var prev_plane_tangent := prev_basis * Vector3.RIGHT
			var cur_plane_normal := cur_basis * Vector3.UP
			var cur_plane_tangent := cur_basis * Vector3.RIGHT
			cur_stroke_tangent = stroke / cur.length
			var cur_normal_stroke_alignment := cur_stroke_tangent.dot(cur_plane_normal)
			var in_plane := absf(cur_normal_stroke_alignment) < K_INDICATOR_PLANE_BREAK_VALUE
			var close_to_prev := cur.length < K_MIN_DIST_KNOTS_METERS_LS * App.METERS_TO_UNITS
			var large_swing := false
			var large_twist := false
			if prev.has_geometry():
				large_swing = prev_plane_normal.dot(cur_plane_normal) < K_SWING_BREAK_VALUE
				large_twist = prev_plane_tangent.dot(cur_plane_tangent) < K_TWIST_BREAK_VALUE
			should_break = large_swing or large_twist or close_to_prev or in_plane

		if should_break:
			if index == knot_index:
				initial_knot_contains_break = true
			cur.qFrame = Quaternion(0.0, 0.0, 0.0, 0.0)
			cur.nRight = Vector3.ZERO
			cur.nSurface = Vector3.ZERO
			cur.nTri = 0
			cur.nVert = 0
		else:
			cur.qFrame = _look_rotation(cur_stroke_tangent, Vector3.UP)
			cur.nRight = Vector3.ZERO
			cur.nSurface = Vector3.ZERO
			cur.nTri = 1
			cur.nVert = 1
		m_knots[index] = cur
		prev = cur
	return initial_knot_contains_break

func on_changed_make_geometry(knot_index: int) -> void:
	m_Color.a = m_transparency / 255.0
	var prev := m_knots[knot_index - 1]
	for index in range(knot_index, m_knots.size()):
		var cur := m_knots[index]
		cur.iTri = prev.iTri + prev.nTri
		cur.iVert = prev.iVert + prev.nVert
		if cur.has_geometry():
			cur.nVert = 0
			cur.nTri = 0
			var cur_basis := GeometryBasis.new(cur, self)
			var is_start := not prev.has_geometry()
			var is_end := is_penultimate(index)
			var is_flip := alignment_parity_reverses(cur, prev)
			if is_start:
				var start_cap := 0
				var ring0 := start_cap + K_NUM_CAP_VERTS
				add_start_cap_verts(cur, prev.smoothedPos, cur_basis)
				add_start_cap_tris(cur, start_cap)
				add_ring_verts(cur, prev.smoothedPos, cur_basis)
				add_cap_to_ring_tris(cur, ring0, start_cap)
				add_ring_verts(cur, cur.smoothedPos, cur_basis)
				add_middle_ring_tris(cur, ring0)
				if is_end:
					var ring1 := ring0 + _verts_per_ring()
					var end_cap := ring1 + _verts_per_ring()
					add_end_cap_verts(cur, cur.smoothedPos, cur_basis)
					add_cap_to_ring_tris(cur, ring1, end_cap)
					add_end_cap_tris(cur, end_cap)
			else:
				var shared_ring := 0
				cur.iVert -= _verts_per_ring()
				cur.nVert += _verts_per_ring()
				if is_flip:
					var prev_basis_cur_stroke := GeometryBasis.new(prev, self, cur_basis.nStrokeTangent)
					add_ring_face_tris(cur, shared_ring, true)
					add_ring_verts(cur, prev.smoothedPos, prev_basis_cur_stroke)
					var ring0 := shared_ring + _verts_per_ring()
					add_ring_verts(cur, cur.smoothedPos, cur_basis)
					add_middle_ring_tris(cur, ring0)
					if is_end:
						var ring1 := ring0 + _verts_per_ring()
						var end_cap := ring1 + _verts_per_ring()
						add_end_cap_verts(cur, cur.smoothedPos, cur_basis)
						add_cap_to_ring_tris(cur, ring1, end_cap)
						add_end_cap_tris(cur, end_cap)
				else:
					add_ring_verts(cur, cur.smoothedPos, cur_basis)
					add_middle_ring_tris(cur, shared_ring)
					if is_end:
						var ring0 := shared_ring + _verts_per_ring()
						var end_cap := ring0 + _verts_per_ring()
						add_end_cap_verts(cur, cur.smoothedPos, cur_basis)
						add_cap_to_ring_tris(cur, ring0, end_cap)
						add_end_cap_tris(cur, end_cap)
		m_knots[index] = cur
		prev = cur

func add_start_cap_verts(cur: Knot, position: Vector3, basis: GeometryBasis) -> void:
	append_vert_square(cur, position + basis.widthVectorToBevel - basis.thicknessVectorToBevel - basis.capNormalOffset, m_Color)
	append_vert_square(cur, position - basis.widthVectorToBevel - basis.thicknessVectorToBevel - basis.capNormalOffset, m_Color)
	append_vert_square(cur, position - basis.widthVectorToBevel + basis.thicknessVectorToBevel - basis.capNormalOffset, m_Color)
	append_vert_square(cur, position + basis.widthVectorToBevel + basis.thicknessVectorToBevel - basis.capNormalOffset, m_Color)

func add_end_cap_verts(cur: Knot, position: Vector3, basis: GeometryBasis) -> void:
	append_vert_square(cur, position + basis.widthVectorToBevel - basis.thicknessVectorToBevel + basis.capNormalOffset, m_Color)
	append_vert_square(cur, position - basis.widthVectorToBevel - basis.thicknessVectorToBevel + basis.capNormalOffset, m_Color)
	append_vert_square(cur, position - basis.widthVectorToBevel + basis.thicknessVectorToBevel + basis.capNormalOffset, m_Color)
	append_vert_square(cur, position + basis.widthVectorToBevel + basis.thicknessVectorToBevel + basis.capNormalOffset, m_Color)

func add_ring_verts(cur: Knot, position: Vector3, basis: GeometryBasis) -> void:
	var c1 := Color.BLUE if m_debugShowSurfaceOrientation else m_Color
	var c2 := Color.RED if m_debugShowSurfaceOrientation else m_Color
	add_bevel_verts(cur, position, 360.0, 270.0, basis, c1)
	add_bevel_verts(cur, position, 270.0, 180.0, basis, c1)
	add_bevel_verts(cur, position, 180.0, 90.0, basis, c2)
	add_bevel_verts(cur, position, 90.0, 0.0, basis, c2)

func add_bevel_verts(cur: Knot, position: Vector3, start_angle: float, stop_angle: float, basis: GeometryBasis, color_value: Color) -> void:
	var mid_angle := (start_angle + stop_angle) * 0.5
	var bevel_origin := position + signf(cos(deg_to_rad(mid_angle))) * basis.widthVectorToBevel + signf(sin(deg_to_rad(mid_angle))) * basis.thicknessVectorToBevel
	var right_inset_outer_dist := (basis.widthVectorToEdge - basis.widthVectorToBevel).length()
	var up_inset_outer_dist := (basis.thicknessVectorToEdge - basis.thicknessVectorToBevel).length()
	for bevel_index in range(m_bevelVerts):
		var dt := 1.0 / maxf(m_bevelVerts - 1.0, 1.0)
		var t := 0.5 if m_bevelVerts == 1 else bevel_index * dt
		var offset := ellipse_offset(basis.nCrossSectionTangentWidth, right_inset_outer_dist, basis.nCrossSectionTangentThickness, up_inset_outer_dist, lerpf(start_angle, stop_angle, t))
		append_vert_square(cur, bevel_origin + offset, color_value)

func add_start_cap_tris(cur: Knot, cap: int) -> void:
	append_tri(cur, cap + 2, cap + 3, cap + 1)
	append_tri(cur, cap + 1, cap + 3, cap + 0)

func add_end_cap_tris(cur: Knot, cap: int) -> void:
	append_tri(cur, cap + 1, cap + 0, cap + 2)
	append_tri(cur, cap + 2, cap + 0, cap + 3)

func add_ring_face_tris(cur: Knot, ring: int, clockwise: bool) -> void:
	if clockwise:
		for index in range(2, _verts_per_ring()):
			append_tri(cur, index + ring, index - 1 + ring, ring)
	else:
		for index in range(1, _verts_per_ring() - 1):
			append_tri(cur, index + ring, index + 1 + ring, ring)

func add_middle_ring_tris(cur: Knot, ring: int) -> void:
	for index in range(_verts_per_ring()):
		var i0 := index + ring
		var i1 := (index + 1) % _verts_per_ring() + ring
		var j0 := i0 + _verts_per_ring()
		var j1 := i1 + _verts_per_ring()
		append_quad(cur, i1, i0, j0, j1)

func add_middle_ring_tris_across_flip(cur: Knot, ring: int) -> void:
	var last_vert_flipped_ring := ring + 2 * _verts_per_ring() - 1
	var first_vert_flipped_ring := ring + _verts_per_ring()
	for index in range(_verts_per_ring()):
		var i0 := index + ring
		var i1 := (index + 1) % _verts_per_ring() + ring
		var j0 := last_vert_flipped_ring - index
		var j1 := j0 - 1
		j1 = last_vert_flipped_ring if j1 < first_vert_flipped_ring else j1
		append_quad(cur, i0, i1, j1, j0)

func add_cap_to_ring_tris(cur: Knot, ring: int, cap: int) -> void:
	var starting := ring > cap
	var n := m_bevelVerts
	var num_corners := 4
	for index in range(num_corners):
		var inner := cap + index
		var fan_start0 := ring + index * n
		var fan_end0 := fan_start0 + (n - 1)
		var inner1 := cap + (index + 1) % num_corners
		var fan_start1 := ring + (index + 1) % num_corners * n
		if starting:
			append_fan(cur, inner, fan_start0, fan_end0)
			append_quad(cur, inner, fan_end0, fan_start1, inner1)
		else:
			append_fan(cur, inner, fan_end0, fan_start0)
			append_quad(cur, fan_end0, inner, inner1, fan_start1)

func append_quad(cur: Knot, v0: int, v1: int, v2: int, v3: int) -> void:
	append_tri(cur, v0, v1, v3)
	append_tri(cur, v3, v1, v2)

func append_fan(cur: Knot, pivot: int, start: int, end: int) -> void:
	var num_tris := absi(end - start)
	var delta := 1 if end > start else -1
	for index in range(num_tris):
		var v0 := start + index * delta
		var v1 := v0 + delta
		append_tri(cur, pivot, v0, v1)

static func ellipse_offset(right: Vector3, half_right: float, up: Vector3, half_up: float, theta: float) -> Vector3:
	return half_right * cos(deg_to_rad(theta)) * right + half_up * sin(deg_to_rad(theta)) * up

func get_vertex_layout(_desc: BrushDescriptor) -> GeometryPool.VertexLayout:
	return GeometryPool.VertexLayout.create(
		GeometryPool.TexcoordInfo.create(),
		GeometryPool.TexcoordInfo.create(),
		null,
		false,
		true,
		false
	)

func append_vert_square(knot: Knot, position: Vector3, color_value: Color) -> void:
	var index := knot.iVert + knot.nVert
	knot.nVert += 1
	if index == m_geometry.m_Vertices.size():
		m_geometry.m_Vertices.append(position)
		m_geometry.m_Colors.append(color_value)
	else:
		m_geometry.m_Vertices[index] = position
		m_geometry.m_Colors[index] = color_value

func get_spawn_interval(_pressure01: float) -> float:
	var ring_distance_meters_ls := lerpf(K_RING_SPARSE_DISTANCE_METERS_LS, K_RING_DENSE_DISTANCE_METERS_LS, m_tessellation)
	var min_knot_distance_meters_ps := 0.001
	var max_knot_distance_meters_ps := 0.05
	var ring_distance_min_ls := min_knot_distance_meters_ps * pointer_to_local() * App.METERS_TO_UNITS
	var ring_distance_max_ls := max_knot_distance_meters_ps * pointer_to_local() * App.METERS_TO_UNITS
	var ring_distance_ls := ring_distance_meters_ls * App.METERS_TO_UNITS
	return clampf(ring_distance_ls, ring_distance_min_ls, ring_distance_max_ls)

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

func alignment_parity_reverses(cur: Knot, prev: Knot) -> bool:
	var prev_plane_normal := Basis(prev.point.m_Orient) * Vector3.UP
	var prev_stroke_tangent := Basis(prev.qFrame) * Vector3.BACK
	var cur_plane_normal := Basis(cur.point.m_Orient) * Vector3.UP
	var cur_stroke_tangent := Basis(cur.qFrame) * Vector3.BACK
	var prev_inline := prev_plane_normal.dot(prev_stroke_tangent) > 0.0
	var cur_inline := cur_plane_normal.dot(cur_stroke_tangent) > 0.0
	return prev_inline != cur_inline

static func _look_rotation(forward: Vector3, up: Vector3) -> Quaternion:
	var normalized_forward := forward.normalized()
	var normalized_up := up.normalized()
	if absf(normalized_up.dot(normalized_forward)) > 0.99:
		normalized_up = Vector3.UP if absf(Vector3.UP.dot(normalized_forward)) < 0.99 else Vector3.RIGHT
	return Basis.looking_at(-normalized_forward, normalized_up).get_rotation_quaternion()
