extends SceneTree

class TestGeometryBrush:
	extends GeometryBrush

	func _init() -> void:
		setup_geometry_brush(true, 3, false, true)

	func get_vertex_layout(_desc: BrushDescriptor) -> GeometryPool.VertexLayout:
		return GeometryPool.VertexLayout.create(
			GeometryPool.TexcoordInfo.create(),
			null,
			null,
			false,
			false,
			false
		)

	func get_spawn_interval(_pressure01: float) -> float:
		return 0.5

	func control_points_changed(knot_index: int) -> void:
		var knot := m_knots[knot_index]
		knot.iVert = 0
		knot.nVert = 3
		knot.iTri = 0
		knot.nTri = 1
		m_knots[knot_index] = knot
		var tail := m_knots[m_knots.size() - 1]
		tail.iVert = knot.iVert
		tail.nVert = knot.nVert
		tail.iTri = knot.iTri
		tail.nTri = knot.nTri
		m_knots[m_knots.size() - 1] = tail
		resize_geometry()
		m_geometry.m_Vertices[0] = Vector3.ZERO
		m_geometry.m_Vertices[1] = Vector3.RIGHT
		m_geometry.m_Vertices[2] = Vector3.UP
		m_geometry.m_Tris[0] = 0
		m_geometry.m_Tris[1] = 1
		m_geometry.m_Tris[2] = 2

var _failures := 0

func _init() -> void:
	_run()
	quit(1 if _failures > 0 else 0)

func _run() -> void:
	_check_base_helpers()
	_check_geometry_brush_lifecycle()
	if _failures == 0:
		print("GDSCRIPT_PARITY_BRUSHLIFECYCLE: all checks passed")

func _check_base_helpers() -> void:
	var verts: Array[Vector3] = [
		Vector3.ZERO,
		Vector3.RIGHT,
		Vector3.UP,
		Vector3.ZERO,
		Vector3.ZERO,
		Vector3.ZERO,
		Vector3.ZERO,
		Vector3.ZERO,
		Vector3.ZERO,
		Vector3.ZERO,
		Vector3.ZERO,
		Vector3.ZERO,
	]
	var uvs: Array[Vector2] = [
		Vector2.ZERO,
		Vector2.RIGHT,
		Vector2(0.0, 1.0),
		Vector2.ZERO,
		Vector2.ZERO,
		Vector2.ZERO,
	]
	var st := BaseBrushScript.compute_st(verts, uvs, 0)
	_expect_vec3_close(st.s, Vector3.RIGHT, "compute_st s")
	_expect_vec3_close(st.t, Vector3.UP, "compute_st t")

	verts[0] = Vector3(1.0, 0.0, 0.0)
	verts[1] = Vector3(2.0, 0.0, 0.0)
	verts[2] = Vector3(1.0, 1.0, 0.0)
	verts[3] = Vector3(1.0, 1.0, 0.0)
	verts[4] = Vector3(2.0, 0.0, 0.0)
	verts[5] = Vector3(2.0, 1.0, 0.0)
	BaseBrushScript.mirror_quad_face(verts, 0)
	_expect_vec3_close(verts[6], verts[0], "mirror quad 0")
	_expect_vec3_close(verts[7], verts[2], "mirror quad 1")
	_expect_vec3_close(verts[8], verts[1], "mirror quad 2")

	var frame := BaseBrushScript.compute_surface_frame_new(Vector3.RIGHT, Vector3.FORWARD * -1.0, Quaternion.IDENTITY)
	_expect_close(frame.right.length(), 1.0, "surface frame right length")
	_expect_close(frame.normal.length(), 1.0, "surface frame normal length")

func _check_geometry_brush_lifecycle() -> void:
	var desc := BrushDescriptor.new()
	desc.m_DurableName = "Ink"
	desc.m_Guid = "c0012095-3ffd-4040-8ee1-fc180d346eaa"
	desc.m_RenderBackfaces = false
	desc.m_M11Compatibility = false
	desc.m_PressureSizeRange = Vector2(0.2, 1.0)
	desc.m_PressureOpacityRange = Vector2(0.25, 1.0)
	desc.m_Opacity = 0.8
	desc.m_SizeVariance = 0.5

	var canvas := CanvasScript.new()
	get_root().add_child(canvas)
	var brush := TestGeometryBrush.new()
	canvas.add_child(brush)
	brush.m_BaseSize_PS = 2.0
	brush.m_Color = Color(0.2, 0.5, 1.0, 1.0)
	brush.init_brush(desc, TrTransform.identity())

	_expect_equal(brush.m_knots.size(), 2, "initial knot count")
	_expect(brush.check_knot_invariants(), "initial knot invariants")
	_expect_close(brush.m_knots[0].point.m_Pressure, 1.0, "initial knot point pressure")
	_expect_close(brush.m_knots[0].smoothedPressure, 0.0, "initial knot smoothed pressure default")
	_expect_close(brush.m_knots[1].smoothedPressure, 0.0, "initial duplicate smoothed pressure default")
	_expect_close(brush.pressured_size(0.5), 1.2, "pressured size")
	_expect_close(brush.pressured_opacity(0.5), 0.5, "pressured opacity")

	var kept := brush.update_position_ls(TrTransform.trs(Vector3(1.0, 0.0, 0.0), Quaternion.IDENTITY, 1.0), 1.0)
	_expect(kept, "update_position_ls keeps long move")
	_expect_equal(brush.m_knots.size(), 3, "kept update appends knot")
	_expect_equal(int(brush.m_FirstChangedControlPoint), 1, "first changed knot")

	brush.apply_changes_to_visuals()
	_expect_equal(brush.m_geometry.num_verts(), 3, "control change generated verts")
	_expect_equal(brush.mesh_data.vertices.size(), 3, "visual mesh data copied")

	brush.finalize_solitary_brush()
	_expect_equal(brush.m_CachedNumVerts, 3, "finalize cached verts")
	_expect(brush.m_geometry == null, "finalize releases geometry")
	_expect_equal(brush.mesh_data.triangles, [0, 1, 2], "finalize mesh triangles")

	canvas.queue_free()

func _expect(condition: bool, label: String) -> void:
	if not condition:
		_fail(label)

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_fail("%s expected %s but got %s" % [label, expected, actual])

func _expect_vec3_close(actual: Vector3, expected: Vector3, label: String) -> void:
	_expect_close(actual.x, expected.x, "%s x" % label)
	_expect_close(actual.y, expected.y, "%s y" % label)
	_expect_close(actual.z, expected.z, "%s z" % label)

func _expect_close(actual: float, expected: float, label: String) -> void:
	if abs(actual - expected) > 1e-5:
		_fail("%s expected %.8f but got %.8f" % [label, expected, actual])

func _fail(message: String) -> void:
	_failures += 1
	push_error("GDSCRIPT_PARITY_BRUSHLIFECYCLE: %s" % message)
