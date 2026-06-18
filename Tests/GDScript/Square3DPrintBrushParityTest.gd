extends SceneTree

var _failures := 0

func _init() -> void:
	_run()
	quit(1 if _failures > 0 else 0)

func _run() -> void:
	_check_single_segment_topology()
	_check_two_segment_shared_ring_topology()
	if _failures == 0:
		print("GDSCRIPT_PARITY_SQUARE3DPRINT: all checks passed")

func _check_single_segment_topology() -> void:
	var brush := _make_square3d_brush()
	var orientation := _orientation_with_up_along_x()
	_expect(brush.update_position_ls(TrTransform.trs(Vector3.RIGHT, orientation, 1.0), 1.0), "square3d first update keeps")
	brush.apply_changes_to_visuals()

	_expect(brush.check_knot_invariants(), "square3d single knot invariants")
	_expect_equal(brush.m_geometry.get_layout().texcoord0.size, 0, "square3d uv0 omitted")
	_expect(not brush.m_geometry.get_layout().bUseNormals, "square3d normals omitted")
	_expect(not brush.m_geometry.get_layout().bUseTangents, "square3d tangents omitted")
	_expect_equal(brush.m_geometry.num_verts(), 24, "square3d single vertex count")
	_expect_equal(brush.m_geometry.num_tri_indices(), 132, "square3d single triangle index count")
	_expect_equal(brush.m_knots[1].nVert, 24, "square3d single knot verts")
	_expect_equal(brush.m_knots[1].nTri, 44, "square3d single knot tris")
	_expect_equal(brush.m_geometry.m_Tris.slice(0, 6), [2, 3, 1, 1, 3, 0], "square3d start cap tris")
	_expect_equal(brush.m_geometry.m_Tris.slice(126, 132), [21, 20, 22, 22, 20, 23], "square3d end cap tris")
	_expect_close(brush.m_geometry.m_Colors[0].a, 1.0, "square3d color alpha")
	_expect(brush.m_geometry.m_Vertices[0].x < 0.0, "square3d start cap offset backward")
	_expect(brush.m_geometry.m_Vertices[20].x > 1.0, "square3d end cap offset forward")
	brush.finalize_solitary_brush()
	_expect_equal(brush.mesh_data.vertices.size(), 24, "square3d finalized vertex count")
	_expect_equal(brush.mesh_data.triangles.size(), 132, "square3d finalized triangle count")
	_expect(brush.m_geometry == null, "square3d releases geometry")
	brush.free()

func _check_two_segment_shared_ring_topology() -> void:
	var brush := _make_square3d_brush()
	var orientation := _orientation_with_up_along_x()
	_expect(brush.update_position_ls(TrTransform.trs(Vector3.RIGHT, orientation, 1.0), 1.0), "square3d two first update keeps")
	_expect(brush.update_position_ls(TrTransform.trs(Vector3(2.0, 0.0, 0.0), orientation, 1.0), 1.0), "square3d two second update keeps")
	brush.apply_changes_to_visuals()

	_expect(brush.check_knot_invariants(), "square3d two knot invariants")
	_expect_equal(brush.m_geometry.num_verts(), 32, "square3d two vertex count")
	_expect_equal(brush.m_geometry.num_tri_indices(), 180, "square3d two triangle index count")
	_expect_equal(brush.m_knots[1].iVert, 0, "square3d first knot vertex start")
	_expect_equal(brush.m_knots[1].nVert, 20, "square3d first knot verts")
	_expect_equal(brush.m_knots[1].nTri, 30, "square3d first knot tris")
	_expect_equal(brush.m_knots[2].iVert, 12, "square3d second knot rewinds to shared ring")
	_expect_equal(brush.m_knots[2].nVert, 20, "square3d second knot verts include shared ring")
	_expect_equal(brush.m_knots[2].nTri, 30, "square3d second knot tris")
	_expect_vec3_close(brush.m_geometry.m_Vertices[12], brush.m_geometry.m_Vertices[12], "square3d shared ring stable")
	_expect(brush.m_geometry.m_Tris[90] >= 12, "square3d second knot tris use rewound base")
	brush.free()

func _make_square3d_brush() -> Square3DPrintBrush:
	var desc := BrushDescriptor.new()
	desc.m_DurableName = "Square3DPrint"
	desc.m_RenderBackfaces = false
	desc.m_BackIsInvisible = false
	desc.m_M11Compatibility = false
	desc.m_TextureAtlasV = 1
	desc.m_TileRate = 1.0
	desc.m_PressureSizeRange = Vector2(1.0, 1.0)
	desc.m_PressureOpacityRange = Vector2(1.0, 1.0)
	desc.m_Opacity = 1.0
	desc.m_SizeVariance = 0.0

	var brush := Square3DPrintBrush.new()
	brush.m_BaseSize_PS = 1.0
	brush.m_Color = Color(0.1, 0.8, 0.35, 1.0)
	brush.set_random_seed(0)
	brush.init_brush(desc, TrTransform.identity())
	brush.set_random_seed(0)
	return brush

func _orientation_with_up_along_x() -> Quaternion:
	return Quaternion(Vector3.BACK, -PI * 0.5)

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
	if absf(actual - expected) > 1e-5:
		_fail("%s expected %.8f but got %.8f" % [label, expected, actual])

func _fail(message: String) -> void:
	_failures += 1
	push_error("GDSCRIPT_PARITY_SQUARE3DPRINT: %s" % message)
