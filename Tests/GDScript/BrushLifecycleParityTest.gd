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

class TestBaseBrush:
	extends BaseBrushScript

	var should_generate := true

	func update_position_impl(_position: Vector3, _orientation: Quaternion, _pressure: float) -> bool:
		return should_generate

var _failures := 0

func _init() -> void:
	_run()
	quit(1 if _failures > 0 else 0)

func _run() -> void:
	_check_base_helpers()
	_check_geometry_brush_lifecycle()
	_check_bounds_padding_applies_to_generated_mesh()
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
	_expect_vec3_close(frame.right, Vector3.RIGHT, "surface frame right exact")
	_expect_vec3_close(frame.normal, Vector3.UP, "surface frame normal exact")

	var desc := BrushDescriptor.new()
	desc.m_DurableName = "BaseLifecycleProbe"
	desc.m_RenderBackfaces = true
	desc.m_PressureSizeRange = Vector2(0.25, 1.0)
	desc.m_PressureOpacityRange = Vector2(0.1, 0.9)
	desc.m_Opacity = 0.5
	desc.m_SizeVariance = 0.2

	var brush := TestBaseBrush.new()
	brush.m_BaseSize_PS = 2.0
	brush.m_Color = Color(0.1, 0.2, 0.3, 1.0)
	brush.init_brush(desc, TrTransform.trs(Vector3(1.0, 2.0, 3.0), Quaternion.IDENTITY, 4.0))
	_expect(brush.m_EnableBackfaces, "init_brush copies backface flag")
	_expect_close(brush.stroke_scale(), 4.0, "stroke scale")
	_expect_close(brush.local_to_pointer(), 0.25, "local to pointer")
	_expect_close(brush.pointer_to_local(), 4.0, "pointer to local")
	_expect_close(brush.base_size_ls(), 8.0, "base size local space")
	_expect_close(brush.pressured_size(0.5), 5.0, "base pressured size")
	_expect_close(brush.pressured_opacity(0.5), 0.25, "base pressured opacity")

	brush.set_random_seed(1234)
	_expect_equal(brush.random_seed(), 1234, "random seed setter")
	var prior_xf := brush.m_LastSpawnXf
	brush.should_generate = false
	_expect(not brush.update_position_ls(TrTransform.trs(Vector3(9.0, 0.0, 0.0), Quaternion.IDENTITY, 2.0), 1.0), "failed base update returns false")
	_expect_vec3_close(brush.m_LastSpawnXf.translation, prior_xf.translation, "failed update preserves last spawn translation")
	_expect_close(brush.m_LastSpawnXf.scale, prior_xf.scale, "failed update preserves last spawn scale")
	brush.should_generate = true
	_expect(brush.update_position_ls(TrTransform.trs(Vector3(9.0, 0.0, 0.0), Quaternion.IDENTITY, 2.0), 1.0), "successful base update returns true")
	_expect_vec3_close(brush.m_LastSpawnXf.translation, Vector3(9.0, 0.0, 0.0), "successful update stores last spawn translation")
	_expect_close(brush.m_LastSpawnXf.scale, 2.0, "successful update stores last spawn scale")
	brush.free()

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

	canvas.free()

func _check_bounds_padding_applies_to_generated_mesh() -> void:
	var desc := BrushDescriptor.new()
	desc.m_DurableName = "Ink"
	desc.m_Guid = "c0012095-3ffd-4040-8ee1-fc180d346eaa"
	desc.m_BoundsPadding = 0.5

	var brush := TestBaseBrush.new()
	get_root().add_child(brush)
	brush.m_BaseSize_PS = 1.0
	brush.init_brush(desc, TrTransform.trs(Vector3.ZERO, Quaternion.IDENTITY, 2.0))
	brush.mesh_data.vertices = [Vector3.ZERO, Vector3.RIGHT, Vector3.UP]
	brush.mesh_data.triangles = [0, 1, 2]
	brush.mesh_data.uv0_v2 = [Vector2.ZERO, Vector2.RIGHT, Vector2.UP]
	brush.mesh_data.colors = [Color.WHITE, Color.WHITE, Color.WHITE]
	brush.update_visible_mesh()

	var mesh_instance := brush.get_node("GeneratedMesh") as MeshInstance3D
	_expect(mesh_instance != null, "bounds padding generated mesh instance")
	if mesh_instance != null:
		var mesh := mesh_instance.mesh as ArrayMesh
		_expect(mesh != null, "bounds padding generated array mesh")
		if mesh != null:
			var expected_padding := desc.m_BoundsPadding * App.METERS_TO_UNITS * brush.pointer_to_local()
			var expected := AABB(Vector3.ZERO, Vector3(1.0, 1.0, 0.0)).grow(expected_padding)
			_expect_vec3_close(mesh.custom_aabb.position, expected.position, "bounds padding custom aabb position")
			_expect_vec3_close(mesh.custom_aabb.size, expected.size, "bounds padding custom aabb size")

	brush.free()

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
