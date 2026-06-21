class_name GeometryBrush
extends BaseBrushScript

const K_PRESSURE_SMOOTH_WINDOW_METERS_PS := 0.20

class Knot:
	var point: ControlPoint
	var smoothedPos := Vector3.ZERO
	var smoothedPressure := 0.0
	var length := 0.0
	var qFrame := Quaternion.IDENTITY
	var nRight := Vector3.ZERO
	var nSurface := Vector3.ZERO
	var iTri := 0
	var iVert := 0
	var nTri := 0
	var nVert := 0
	var startsGeometry := false
	var endsGeometry := false

	func has_geometry() -> bool:
		return nVert > 0

	func frame() -> Variant:
		return qFrame if has_geometry() else null

	func duplicate_knot() -> Knot:
		var knot := Knot.new()
		knot.point = point.duplicate_point()
		knot.smoothedPos = smoothedPos
		knot.smoothedPressure = smoothedPressure
		knot.length = length
		knot.qFrame = qFrame
		knot.nRight = nRight
		knot.nSurface = nSurface
		knot.iTri = iTri
		knot.iVert = iVert
		knot.nTri = nTri
		knot.nVert = nVert
		knot.startsGeometry = startsGeometry
		knot.endsGeometry = endsGeometry
		return knot

var m_UpperBoundVertsPerKnot := 0
var m_bDoubleSided := false
var m_bSmoothPositions := true
var m_bM11Compatibility := false
var m_SoftVertexLimit := 9000
var NS := 1
var m_knots: Array[Knot] = []
var m_geometry: GeometryPool
var m_CachedNumVerts := 0
var m_CachedNumTris := 0
var m_FirstChangedControlPoint: Variant = null

func setup_geometry_brush(can_batch: bool, upper_bound_verts_per_knot: int, double_sided: bool, smooth_positions: bool = true) -> void:
	setup_base(can_batch)
	m_bDoubleSided = double_sided
	NS = 2 if double_sided else 1
	m_UpperBoundVertsPerKnot = NS * upper_bound_verts_per_knot
	m_SoftVertexLimit = 9000
	m_bSmoothPositions = smooth_positions

func num_verts() -> int:
	return m_geometry.num_verts() if m_geometry != null else m_CachedNumVerts

func num_tris() -> int:
	return m_geometry.num_tri_indices() if m_geometry != null else m_CachedNumTris

func check_knot_invariants() -> bool:
	if m_knots.is_empty():
		return true
	var k0 := m_knots[0]
	if k0.iTri != 0 or k0.iVert != 0 or k0.nTri != 0 or k0.nVert != 0:
		return false
	for index in range(1, m_knots.size()):
		var prev := m_knots[index - 1]
		var cur := m_knots[index]
		if prev.iTri > cur.iTri:
			return false
		if cur.iTri > prev.iTri + prev.nTri:
			return false
		if cur.iTri + cur.nTri < prev.iTri + prev.nTri:
			return false
		if prev.iVert > cur.iVert:
			return false
		if cur.iVert > prev.iVert + prev.nVert:
			return false
		if cur.iVert + cur.nVert < prev.iVert + prev.nVert:
			return false
	return true

func remove_initial_knots(knots_to_shift: int) -> void:
	if knots_to_shift == 0:
		return
	m_knots = m_knots.slice(knots_to_shift)
	if m_FirstChangedControlPoint != null:
		m_FirstChangedControlPoint = max(int(m_FirstChangedControlPoint) - knots_to_shift, 1)
	var k0 := m_knots[0]
	var vert_shift := k0.iVert + k0.nVert
	var tri_shift := k0.iTri + k0.nTri
	k0.iVert = 0
	k0.nVert = 0
	k0.iTri = 0
	k0.nTri = 0
	m_knots[0] = k0
	for index in range(1, m_knots.size()):
		var shifted := m_knots[index]
		shifted.iVert -= vert_shift
		shifted.iTri -= tri_shift
		m_knots[index] = shifted
	if m_geometry != null:
		m_geometry.shift_forward(vert_shift, tri_shift)

func control_points_changed(_knot_index: int) -> void:
	pass

func distance_from_knot(knot_index: int, position: Vector3) -> float:
	return position.distance_to(m_knots[knot_index].point.m_Pos)

func always_rebuild_preview_brush() -> bool:
	return true

func get_num_used_verts() -> int:
	return num_verts()

func is_out_of_verts() -> bool:
	var last_valid_index := 0xfffe
	return (get_num_used_verts() + m_UpperBoundVertsPerKnot) - 1 > last_valid_index

func should_current_line_end() -> bool:
	return is_out_of_verts() or num_verts() > m_SoftVertexLimit

func should_discard() -> bool:
	return get_num_used_verts() <= 0

func reset_brush_for_preview(local_pointer_xf: TrTransform) -> void:
	super.reset_brush_for_preview(local_pointer_xf)
	m_knots.clear()
	var knot := _make_initial_knot(local_pointer_xf, 1.0)
	m_knots.append(knot)
	m_knots.append(knot.duplicate_knot())

func set_double_sided(desc: BrushDescriptor) -> void:
	if desc.m_RenderBackfaces and not m_bDoubleSided:
		m_bDoubleSided = true
		NS *= 2
		m_UpperBoundVertsPerKnot *= 2
	elif not desc.m_RenderBackfaces and m_bDoubleSided:
		m_bDoubleSided = false
		NS /= 2
		m_UpperBoundVertsPerKnot /= 2

func init_brush(desc: BrushDescriptor, local_pointer_xf: TrTransform) -> void:
	super.init_brush(desc, local_pointer_xf)
	m_bM11Compatibility = desc.m_M11Compatibility
	m_geometry = GeometryPool.allocate()
	m_geometry.set_layout(get_vertex_layout(desc))
	m_knots.clear()
	var knot := _make_initial_knot(local_pointer_xf, 1.0)
	m_knots.append(knot)
	m_knots.append(knot.duplicate_knot())

func debug_get_geometry() -> Dictionary:
	if m_geometry == null:
		return {"verts": [], "nVerts": m_CachedNumVerts, "uv0s": [], "tris": [], "nTris": m_CachedNumTris}
	var uv0s: Array = []
	if m_geometry.get_layout().texcoord0.size == 2:
		uv0s = m_geometry.m_Texcoord0.v2
	return {
		"verts": m_geometry.m_Vertices,
		"nVerts": m_geometry.m_Vertices.size(),
		"uv0s": uv0s,
		"tris": m_geometry.m_Tris,
		"nTris": m_geometry.m_Tris.size()
	}

func _finalize_geometry_mesh() -> void:
	if m_geometry == null:
		return
	m_geometry.copy_to_mesh_data(mesh_data)
	m_CachedNumVerts = num_verts()
	m_CachedNumTris = num_tris()
	GeometryPool.release(m_geometry)
	m_geometry = null
	update_visible_mesh()

func finalize_solitary_brush() -> void:
	_finalize_geometry_mesh()

func finalize_batched_brush() -> void:
	_finalize_geometry_mesh()

func apply_changes_to_visuals() -> void:
	if m_geometry == null or not m_geometry.verify_sizes():
		return
	if m_FirstChangedControlPoint != null:
		control_points_changed(int(m_FirstChangedControlPoint))
		m_FirstChangedControlPoint = null
	m_geometry.copy_to_mesh_data(mesh_data)
	update_visible_mesh()

func update_position_impl(position: Vector3, orientation: Quaternion, pressure: float) -> bool:
	assert(m_knots.size() >= 2)
	var update_index := m_knots.size() - 1
	var updated := m_knots[update_index]
	updated.point.m_Pos = position
	updated.point.m_Orient = orientation
	updated.point.m_Pressure = pressure
	updated.point.m_TimestampMs = int(App.current_sketch_time() * 1000.0)
	updated.smoothedPos = position
	if update_index < 2:
		var initial_pressure := 0.0 if m_bM11Compatibility or m_PreviewMode else pressure
		var initial_knot := m_knots[0]
		initial_knot.point.m_Pressure = initial_pressure
		initial_knot.smoothedPressure = initial_pressure
		m_knots[0] = initial_knot
	elif m_bSmoothPositions:
		var middle := m_knots[update_index - 1]
		var v0 := m_knots[update_index - 2].point.m_Pos
		var v1 := middle.point.m_Pos
		var v2 := position
		middle.smoothedPos = (v0 + 2.0 * v1 + v2) / 4.0
		m_knots[update_index - 1] = middle

	if m_bSmoothPositions:
		apply_smoothing(m_knots[update_index - 1], updated)
	else:
		updated.smoothedPressure = updated.point.m_Pressure
	m_knots[update_index] = updated

	if m_FirstChangedControlPoint != null:
		m_FirstChangedControlPoint = min(int(m_FirstChangedControlPoint), update_index)
	else:
		m_FirstChangedControlPoint = update_index

	var last_length := distance_from_knot(update_index - 1, updated.point.m_Pos)
	var keep := last_length > get_spawn_interval(updated.smoothedPressure)
	if keep:
		var dupe := updated.duplicate_knot()
		dupe.iVert = updated.iVert + updated.nVert
		dupe.nVert = 0
		dupe.iTri = updated.iTri + updated.nTri
		dupe.nTri = 0
		m_knots.append(dupe)
	return keep

func set_tri(i_tri: int, i_vert: int, triangle_pair: int, vp0: int, vp1: int, vp2: int) -> void:
	var i := (i_tri + triangle_pair * NS) * 3
	m_geometry.m_Tris[i] = i_vert + vp0 * NS
	m_geometry.m_Tris[i + 1] = i_vert + vp1 * NS
	m_geometry.m_Tris[i + 2] = i_vert + vp2 * NS
	if m_bDoubleSided:
		m_geometry.m_Tris[i + 3] = i_vert + vp2 * NS + 1
		m_geometry.m_Tris[i + 4] = i_vert + vp1 * NS + 1
		m_geometry.m_Tris[i + 5] = i_vert + vp0 * NS + 1

func set_vert(i_vert: int, vp: int, vertex: Vector3, normal: Vector3, color: Color, alpha: float) -> void:
	var final_color := _to_color32(color)
	final_color.a = _color32_alpha(alpha)
	var i := i_vert + vp * NS
	m_geometry.m_Vertices[i] = vertex
	m_geometry.m_Normals[i] = normal
	m_geometry.m_Colors[i] = final_color
	if m_bDoubleSided:
		m_geometry.m_Vertices[i + 1] = vertex
		m_geometry.m_Normals[i + 1] = -normal
		m_geometry.m_Colors[i + 1] = final_color

func set_uv0(i_vert: int, vp: int, data: Variant) -> void:
	var i := i_vert + vp * NS
	if data is Vector2:
		m_geometry.m_Texcoord0.v2[i] = data
		if m_bDoubleSided:
			m_geometry.m_Texcoord0.v2[i + 1] = data
	elif data is Vector3:
		m_geometry.m_Texcoord0.v3[i] = data
		if m_bDoubleSided:
			m_geometry.m_Texcoord0.v3[i + 1] = data
	elif data is Vector4:
		m_geometry.m_Texcoord0.v4[i] = data
		if m_bDoubleSided:
			m_geometry.m_Texcoord0.v4[i + 1] = data

func set_uv1(i_vert: int, vp: int, data: Variant) -> void:
	var i := i_vert + vp * NS
	if data is Vector3:
		m_geometry.m_Texcoord1.v3[i] = data
		if m_bDoubleSided:
			m_geometry.m_Texcoord1.v3[i + 1] = data
	elif data is Vector4:
		m_geometry.m_Texcoord1.v4[i] = data
		if m_bDoubleSided:
			m_geometry.m_Texcoord1.v4[i + 1] = data

func set_tangent(i_vert: int, vp: int, tangent: Vector3, w: float = 1.0) -> void:
	var i := i_vert + vp * NS
	var normal := m_geometry.m_Normals[i]
	var ortho := (tangent - tangent.dot(normal) * normal).normalized()
	var ortho_tangent := Vector4(ortho.x, ortho.y, ortho.z, w)
	m_geometry.m_Tangents[i] = ortho_tangent
	if m_bDoubleSided:
		ortho_tangent.w = -w
		m_geometry.m_Tangents[i + 1] = ortho_tangent

func resize_geometry() -> void:
	var knot := m_knots[m_knots.size() - 1]
	m_geometry.set_num_verts(knot.iVert + knot.nVert)
	m_geometry.set_num_tri_indices((knot.iTri + knot.nTri) * 3)

func apply_smoothing(previous: Knot, next: Knot) -> void:
	var distance := previous.point.m_Pos.distance_to(next.point.m_Pos)
	var pressure_smooth_window_meters_ps := 0.1 if m_bM11Compatibility else K_PRESSURE_SMOOTH_WINDOW_METERS_PS
	var window := pressure_smooth_window_meters_ps * App.METERS_TO_UNITS * pointer_to_local()
	var k := pow(0.1, distance / window)
	next.smoothedPressure = k * previous.smoothedPressure + (1.0 - k) * next.point.m_Pressure

func _make_initial_knot(local_pointer_xf: TrTransform, pressure: float) -> Knot:
	var knot := Knot.new()
	knot.point = ControlPoint.create(local_pointer_xf.translation, local_pointer_xf.rotation, pressure, 0)
	knot.length = 0.0
	knot.smoothedPos = local_pointer_xf.translation
	return knot
