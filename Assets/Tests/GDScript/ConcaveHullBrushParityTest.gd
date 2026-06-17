extends SceneTree

var _failures := 0

func _init() -> void:
	_run()
	quit(1 if _failures > 0 else 0)

func _run() -> void:
	_check_cube_window_geometry()
	if _failures == 0:
		print("GDSCRIPT_PARITY_CONCAVEHULL: all checks passed")

func _check_cube_window_geometry() -> void:
	var brush := _make_concave_brush()
	_expect_equal(brush.m_knots[0].point.m_Pressure, 0.0, "concave initial pressure 0")
	_expect_equal(brush.m_knots[1].point.m_Pressure, 0.0, "concave duplicate initial pressure 0")
	_expect(brush.update_position_ls(TrTransform.trs(Vector3.RIGHT, Quaternion.IDENTITY, 1.0), 1.0), "concave first update keeps")
	brush.apply_changes_to_visuals()

	_expect(brush.check_knot_invariants(), "concave knot invariants")
	_expect_equal(brush.m_AllVertices.size(), 24, "concave converted cube vertices")
	_expect_equal(brush.m_geometry.get_layout().texcoord0.size, 0, "concave uv0 omitted")
	_expect(brush.m_geometry.get_layout().bUseNormals, "concave normals enabled")
	_expect(not brush.m_geometry.get_layout().bUseTangents, "concave tangents omitted")
	_expect(brush.m_geometry.num_verts() >= 8, "concave vertex count")
	_expect(brush.m_geometry.num_tri_indices() >= 36, "concave triangle count")
	_expect_equal(brush.m_geometry.m_Normals.size(), brush.m_geometry.num_verts(), "concave normal count")
	_expect_equal(brush.m_geometry.m_Colors.size(), brush.m_geometry.num_verts(), "concave color count")
	_expect_close(brush.m_geometry.m_Normals[0].length(), 1.0, "concave normal length")
	_expect_close(brush.m_geometry.m_Colors[0].a, 1.0, "concave color alpha")
	brush.finalize_solitary_brush()
	_expect(brush.m_geometry == null, "concave releases geometry")
	_expect(brush.mesh_data.vertices.size() >= 8, "concave finalized vertices")
	brush.free()

func _make_concave_brush() -> ConcaveHullBrush:
	var desc := BrushDescriptor.new()
	desc.m_DurableName = "ConcaveHull"
	desc.m_RenderBackfaces = false
	desc.m_BackIsInvisible = false
	desc.m_M11Compatibility = false
	desc.m_TextureAtlasV = 1
	desc.m_TileRate = 1.0
	desc.m_PressureSizeRange = Vector2(1.0, 1.0)
	desc.m_PressureOpacityRange = Vector2(1.0, 1.0)
	desc.m_Opacity = 1.0
	desc.m_SizeVariance = 0.0
	desc.m_SolidMinLengthMeters_PS = 0.002

	var brush := ConcaveHullBrush.new()
	brush.m_KnotConversion = ConcaveHullBrush.KnotConversion.CUBE
	brush.m_KnotsInHull = 2
	brush.m_BaseSize_PS = 1.0
	brush.m_Color = Color(0.95, 0.55, 0.25, 1.0)
	brush.set_random_seed(0)
	brush.init_brush(desc, TrTransform.identity())
	brush.set_random_seed(0)
	return brush

func _expect(condition: bool, label: String) -> void:
	if not condition:
		_fail(label)

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_fail("%s expected %s but got %s" % [label, expected, actual])

func _expect_close(actual: float, expected: float, label: String) -> void:
	if absf(actual - expected) > 1e-5:
		_fail("%s expected %.8f but got %.8f" % [label, expected, actual])

func _fail(message: String) -> void:
	_failures += 1
	push_error("GDSCRIPT_PARITY_CONCAVEHULL: %s" % message)
