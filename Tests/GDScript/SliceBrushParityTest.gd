extends SceneTree

var _failures := 0

func _init() -> void:
	_run()
	quit(1 if _failures > 0 else 0)

func _run() -> void:
	_check_spawn_interval_and_layout()
	_check_slice_geometry_path()
	_check_short_segment_break_restarts_slice_strip()
	if _failures == 0:
		print("GDSCRIPT_PARITY_SLICEBRUSH: all checks passed")

func _check_spawn_interval_and_layout() -> void:
	var brush := _make_slice_brush()
	brush.m_Desc.m_PressureSizeRange = Vector2(0.5, 1.0)
	brush.m_BaseSize_PS = 2.0

	var layout := brush.get_vertex_layout(brush.m_Desc)
	_expect_equal(layout.texcoord0.size, 3, "slice uv0 size")
	_expect(layout.bUseNormals, "slice uses normals")
	_expect(layout.bUseColors, "slice uses colors")
	_expect(not layout.bUseTangents, "slice omits tangents")
	_expect_close(brush.get_spawn_interval(0.0), 0.201, "slice spawn interval minimum pressure")
	_expect_close(brush.get_spawn_interval(0.5), 0.301, "slice spawn interval interpolated pressure")
	_expect_close(brush.get_spawn_interval(1.0), 0.401, "slice spawn interval full pressure")
	brush.free()

func _check_slice_geometry_path() -> void:
	var brush := _make_slice_brush()
	_expect(brush.update_position_ls(TrTransform.trs(Vector3.RIGHT, Quaternion.IDENTITY, 1.0), 1.0), "slice first update keeps")
	_expect(brush.update_position_ls(TrTransform.trs(Vector3(2.0, 0.0, 0.0), Quaternion.IDENTITY, 1.0), 1.0), "slice second update keeps")
	brush.apply_changes_to_visuals()

	_expect(brush.check_knot_invariants(), "slice knot invariants")
	_expect_equal(brush.m_geometry.num_verts(), 12, "slice shared vertex count")
	_expect_equal(brush.m_geometry.num_tri_indices(), 18, "slice triangle index count")
	_expect_equal(brush.m_geometry.m_Tris.slice(0, 6), [0, 2, 1, 2, 0, 3], "slice first quad tris")
	_expect_equal(brush.m_geometry.m_Tris.slice(12, 18), [4, 6, 5, 6, 4, 7], "slice shared second quad tris")
	_expect_equal(brush.m_knots[1].iVert, 0, "slice first knot vertex start")
	_expect_equal(brush.m_knots[2].iVert, 4, "slice second knot rewinds to shared quad")
	_expect_equal(brush.m_knots[1].nVert, 8, "slice first knot vertices")
	_expect_equal(brush.m_knots[2].nVert, 8, "slice second knot vertices with shared back")

	_expect_equal(brush.m_geometry.m_Texcoord0.v3[0], Vector3(0.0, 0.0, 0.0), "slice first uvw")
	_expect_equal(brush.m_geometry.m_Texcoord0.v3[3], Vector3(1.0, 0.0, 0.0), "slice first uvw corner")
	_expect_close(brush.m_geometry.m_Texcoord0.v3[4].z, 0.1, "slice first distance")
	_expect_close(brush.m_geometry.m_Texcoord0.v3[8].z, 0.2, "slice second distance")
	_expect_vec3_close(brush.m_geometry.m_Normals[0], Vector3.RIGHT, "slice initial normal direction")
	_expect_vec3_close(brush.m_geometry.m_Normals[4], Vector3.RIGHT, "slice first front normal direction")
	_expect_color_close(brush.m_geometry.m_Colors[0], _color32(Color(0.8, 0.3, 0.2, 1.0)), "slice color32 alpha forced opaque")
	_expect_close(brush.m_geometry.m_Vertices[0].distance_to(brush.m_geometry.m_Vertices[2]), sqrt(2.0), "slice first quad diagonal")
	var center_a := _quad_center(brush.m_geometry.m_Vertices, 4)
	var center_b := _quad_center(brush.m_geometry.m_Vertices, 8)
	_expect_close(center_a.distance_to(center_b), 1.0, "slice segment spacing")

	brush.finalize_solitary_brush()
	_expect_equal(brush.mesh_data.vertices.size(), 12, "slice finalized vertex count")
	_expect(brush.m_geometry == null, "slice releases geometry")
	brush.free()

func _check_short_segment_break_restarts_slice_strip() -> void:
	var brush := _make_slice_brush()
	_expect(brush.update_position_ls(TrTransform.trs(Vector3.RIGHT, Quaternion.IDENTITY, 1.0), 1.0), "slice break first update keeps")
	_expect(brush.update_position_ls(TrTransform.trs(Vector3(2.0, 0.0, 0.0), Quaternion.IDENTITY, 1.0), 1.0), "slice break second update keeps")
	brush.apply_changes_to_visuals()

	var short_knot := brush.m_knots[2]
	short_knot.point.m_Pos = brush.m_knots[1].point.m_Pos + Vector3(0.0001, 0.0, 0.0)
	brush.m_knots[2] = short_knot
	brush.control_points_changed(2)

	_expect_equal(brush.m_knots[2].nVert, 0, "slice short segment has no vertices")
	_expect_equal(brush.m_knots[2].nTri, 0, "slice short segment has no triangles")
	_expect_equal(brush.m_knots[2].qFrame, Quaternion(0.0, 0.0, 0.0, 0.0), "slice short segment clears frame")
	_expect(brush.is_penultimate(1), "slice geometry before break is penultimate")
	_expect(brush.m_knots[3].has_geometry(), "slice strip restarts after break")
	_expect_equal(brush.m_knots[3].iVert, 8, "slice restarted strip vertex start")
	_expect_equal(brush.m_knots[3].nVert, 8, "slice restarted strip vertices")
	_expect_equal(brush.m_geometry.num_verts(), 16, "slice restarted geometry vertex count")
	_expect_equal(brush.m_geometry.num_tri_indices(), 24, "slice restarted geometry tri count")
	_expect_close(brush.m_geometry.m_Texcoord0.v3[8].z, 0.0, "slice restarted strip resets uvw distance")
	_expect_close(brush.m_geometry.m_Texcoord0.v3[12].z, (brush.m_knots[3].point.m_Pos - brush.m_knots[2].point.m_Pos).length() * App.UNITS_TO_METERS, "slice restarted strip front uvw distance")
	brush.free()

func _make_slice_brush() -> SliceBrush:
	var desc := BrushDescriptor.new()
	desc.m_DurableName = "Slice"
	desc.m_RenderBackfaces = false
	desc.m_BackIsInvisible = false
	desc.m_M11Compatibility = false
	desc.m_PressureSizeRange = Vector2(1.0, 1.0)
	desc.m_PressureOpacityRange = Vector2(1.0, 1.0)
	desc.m_Opacity = 1.0
	desc.m_SizeVariance = 0.0

	var brush := SliceBrush.new()
	brush.m_BaseSize_PS = 1.0
	brush.m_Color = Color(0.8, 0.3, 0.2, 0.25)
	brush.init_brush(desc, TrTransform.identity())
	return brush

func _expect(condition: bool, label: String) -> void:
	if not condition:
		_fail(label)

func _quad_center(vertices: Array[Vector3], start: int) -> Vector3:
	return (vertices[start] + vertices[start + 1] + vertices[start + 2] + vertices[start + 3]) * 0.25

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

func _expect_color_close(actual: Color, expected: Color, label: String) -> void:
	_expect_close(actual.r, expected.r, "%s r" % label)
	_expect_close(actual.g, expected.g, "%s g" % label)
	_expect_close(actual.b, expected.b, "%s b" % label)
	_expect_close(actual.a, expected.a, "%s a" % label)

func _color32_channel(value: float) -> float:
	return float(int(clamp(value, 0.0, 1.0) * 255.0)) / 255.0

func _color32(value: Color) -> Color:
	return Color(
		_color32_channel(value.r),
		_color32_channel(value.g),
		_color32_channel(value.b),
		_color32_channel(value.a)
	)

func _fail(message: String) -> void:
	_failures += 1
	push_error("GDSCRIPT_PARITY_SLICEBRUSH: %s" % message)
