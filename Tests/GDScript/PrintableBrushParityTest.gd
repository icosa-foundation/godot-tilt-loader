extends SceneTree

var _failures := 0

func _init() -> void:
	_run()
	quit(1 if _failures > 0 else 0)

func _run() -> void:
	_check_printable_brush_layout_and_spawn_interval()
	_check_printable_brush_geometry()
	_check_printable_brush_shared_ring_continuation()
	_check_printable_brush_sharp_turn_breaks_segment()
	_check_printable_brush_short_segment_break_restarts()
	_check_printable_brush_back_invisible_frame()
	if _failures == 0:
		print("GDSCRIPT_PARITY_PRINTABLEBRUSH: all checks passed")

func _check_printable_brush_layout_and_spawn_interval() -> void:
	var brush := _make_printable_brush()
	brush.m_BaseSize_PS = 2.0
	var layout := brush.get_vertex_layout(brush.m_Desc)

	_expect_equal(layout.texcoord0.size, 2, "printable uv0 layout size")
	_expect_equal(layout.texcoord0.semantic, GeometryPool.Semantic.XY_IS_UV, "printable uv0 semantic")
	_expect(layout.bUseNormals, "printable uses normals")
	_expect(layout.bUseColors, "printable uses colors")
	_expect(not layout.bUseTangents, "printable does not use tangents")
	_expect_close(brush.get_spawn_interval(0.0), 0.42, "printable spawn interval pressure 0")
	_expect_close(brush.get_spawn_interval(0.5), 0.42, "printable spawn interval pressure 0.5")
	_expect_close(brush.get_spawn_interval(1.0), 0.42, "printable spawn interval pressure 1")
	brush.free()

func _check_printable_brush_geometry() -> void:
	var desc := BrushDescriptor.new()
	desc.m_DurableName = "SquarePaper"
	desc.m_RenderBackfaces = false
	desc.m_BackIsInvisible = false
	desc.m_M11Compatibility = false
	desc.m_PressureSizeRange = Vector2(1.0, 1.0)
	desc.m_PressureOpacityRange = Vector2(1.0, 1.0)
	desc.m_Opacity = 1.0
	desc.m_SizeVariance = 0.0

	var brush := PrintableBrush.new()
	brush.m_BaseSize_PS = 1.0
	brush.m_Color = Color(0.6, 0.4, 0.2, 0.1)
	brush.init_brush(desc, TrTransform.identity())
	_expect(brush.update_position_ls(TrTransform.trs(Vector3.RIGHT, Quaternion.IDENTITY, 1.0), 1.0), "printable update keeps one solid")
	brush.apply_changes_to_visuals()

	_expect(brush.check_knot_invariants(), "printable knot invariants")
	_expect_equal(brush.m_geometry.num_verts(), 8, "printable vertex count")
	_expect_equal(brush.m_geometry.num_tri_indices(), 36, "printable triangle index count")
	_expect_equal(brush.m_knots[1].nTri, 12, "printable knot triangle count with caps")
	_expect_close(brush.m_knots[0].qFrame.x, 0.8, "printable initial envelope")
	_expect_close(brush.m_knots[1].qFrame.x, 1.0, "printable front envelope")

	_expect_equal(brush.m_geometry.m_Tris.slice(0, 6), [2, 1, 6, 6, 1, 5], "printable top tris")
	_expect_equal(brush.m_geometry.m_Tris.slice(24, 30), [2, 0, 1, 1, 0, 3], "printable start cap tris")
	_expect_vec3_close(brush.m_geometry.m_Vertices[PrintableBrush.BR], Vector3(0.0, 0.4, 0.0), "printable back right envelope")
	_expect_vec3_close(brush.m_geometry.m_Vertices[PrintableBrush.BT], Vector3(0.0, 0.0, -0.15), "printable back top envelope")
	_expect_vec3_close(brush.m_geometry.m_Vertices[PrintableBrush.FR], Vector3(1.0, 0.5, 0.0), "printable front right")
	_expect_vec3_close(brush.m_geometry.m_Vertices[PrintableBrush.FT], Vector3(1.0, 0.0, -0.1875), "printable front top")
	_expect_vec3_close(brush.m_geometry.m_Normals[PrintableBrush.FL], Vector3.DOWN, "printable left normal")
	_expect_equal(brush.m_geometry.m_Texcoord0.v2[PrintableBrush.FB], Vector2(0.5, 0.5), "printable default uv")
	_expect_color_close(brush.m_geometry.m_Colors[PrintableBrush.FB], _color32(Color(0.6, 0.4, 0.2, 1.0)), "printable color32 alpha forced opaque")

	brush.finalize_solitary_brush()
	_expect_equal(brush.mesh_data.vertices.size(), 8, "printable finalized vertex count")
	_expect(brush.m_geometry == null, "printable releases geometry")
	brush.free()

func _check_printable_brush_shared_ring_continuation() -> void:
	var brush := _make_printable_brush()
	_expect(brush.update_position_ls(TrTransform.trs(Vector3.RIGHT, Quaternion.IDENTITY, 1.0), 1.0), "printable continuation first update keeps")
	_expect(brush.update_position_ls(TrTransform.trs(Vector3(2.0, 0.0, 0.0), Quaternion.IDENTITY, 1.0), 1.0), "printable continuation second update keeps")
	brush.apply_changes_to_visuals()

	_expect(brush.check_knot_invariants(), "printable continuation knot invariants")
	_expect_equal(brush.m_geometry.num_verts(), 12, "printable continuation vertex count")
	_expect_equal(brush.m_geometry.num_tri_indices(), 60, "printable continuation triangle index count")
	_expect_equal(brush.m_knots[1].iVert, 0, "printable continuation first knot vertex start")
	_expect_equal(brush.m_knots[1].nVert, 8, "printable continuation first knot verts")
	_expect_equal(brush.m_knots[1].nTri, 10, "printable continuation first knot tris with start cap only")
	_expect_equal(brush.m_knots[2].iVert, 4, "printable continuation second knot rewinds shared ring")
	_expect_equal(brush.m_knots[2].nVert, 8, "printable continuation second knot verts include shared ring")
	_expect_equal(brush.m_knots[2].nTri, 10, "printable continuation second knot tris with end cap only")
	_expect(not brush.m_knots[1].endsGeometry, "printable continuation first knot has no end cap")
	_expect(brush.m_knots[2].endsGeometry, "printable continuation second knot has end cap")
	_expect_vec3_close(brush.m_geometry.m_Vertices[PrintableBrush.FR], Vector3(1.0, 0.5, 0.0), "printable continuation shared ring position")
	_expect_vec3_close(brush.m_geometry.m_Vertices[brush.m_knots[2].iVert + PrintableBrush.FR], Vector3(2.0, 0.15, 0.0), "printable continuation second front ring position")
	brush.free()

func _check_printable_brush_sharp_turn_breaks_segment() -> void:
	var brush := _make_printable_brush()
	_expect(brush.update_position_ls(TrTransform.trs(Vector3.RIGHT, Quaternion.IDENTITY, 1.0), 1.0), "printable break first update keeps")
	_expect(brush.update_position_ls(TrTransform.trs(Vector3.ZERO, Quaternion.IDENTITY, 1.0), 1.0), "printable break reverse update keeps")
	_expect(brush.update_position_ls(TrTransform.trs(Vector3.LEFT, Quaternion.IDENTITY, 1.0), 1.0), "printable break new segment update keeps")
	brush.apply_changes_to_visuals()

	_expect(brush.check_knot_invariants(), "printable break knot invariants")
	_expect_equal(brush.m_geometry.num_verts(), 16, "printable break vertex count")
	_expect_equal(brush.m_geometry.num_tri_indices(), 72, "printable break triangle index count")
	_expect(brush.m_knots[1].endsGeometry, "printable break first segment closed")
	_expect(not brush.m_knots[2].has_geometry(), "printable break reversing knot has no geometry")
	_expect(brush.m_knots[3].startsGeometry, "printable break new segment starts")
	_expect(brush.m_knots[3].endsGeometry, "printable break new segment ends")
	_expect_equal(brush.m_knots[3].iVert, 8, "printable break new segment vertex start")
	_expect_equal(brush.m_geometry.m_Tris.slice(24, 36), [2, 0, 1, 1, 0, 3, 6, 5, 4, 4, 5, 7], "printable break first segment caps")
	brush.free()

func _check_printable_brush_short_segment_break_restarts() -> void:
	var brush := _make_printable_brush()
	_expect(brush.update_position_ls(TrTransform.trs(Vector3.RIGHT, Quaternion.IDENTITY, 1.0), 1.0), "printable short first update keeps")
	_expect(brush.update_position_ls(TrTransform.trs(Vector3(2.0, 0.0, 0.0), Quaternion.IDENTITY, 1.0), 1.0), "printable short second update keeps")
	brush.apply_changes_to_visuals()

	var short_knot := brush.m_knots[2]
	short_knot.point.m_Pos = brush.m_knots[1].point.m_Pos + Vector3(0.0001, 0.0, 0.0)
	brush.m_knots[2] = short_knot
	brush.control_points_changed(2)

	_expect(brush.check_knot_invariants(), "printable short restart knot invariants")
	_expect_equal(brush.m_geometry.num_verts(), 16, "printable short restart vertex count")
	_expect_equal(brush.m_geometry.num_tri_indices(), 72, "printable short restart triangle index count")
	_expect(brush.m_knots[1].endsGeometry, "printable short closes previous segment")
	_expect(not brush.m_knots[2].has_geometry(), "printable short knot has no geometry")
	_expect_equal(brush.m_knots[2].nVert, 0, "printable short knot vertex count")
	_expect_equal(brush.m_knots[2].nTri, 0, "printable short knot triangle count")
	_expect_vec3_close(brush.m_knots[2].nRight, Vector3.ZERO, "printable short knot right reset")
	_expect_vec3_close(brush.m_knots[2].nSurface, Vector3.ZERO, "printable short knot surface reset")
	_expect(brush.m_knots[3].startsGeometry, "printable short restart starts new segment")
	_expect(brush.m_knots[3].endsGeometry, "printable short restart ends new segment")
	_expect_equal(brush.m_knots[3].iVert, 8, "printable short restart vertex start")
	_expect_equal(brush.m_knots[3].iTri, 12, "printable short restart tri start")
	brush.free()

func _check_printable_brush_back_invisible_frame() -> void:
	var desc := BrushDescriptor.new()
	desc.m_DurableName = "SquarePaper"
	desc.m_RenderBackfaces = false
	desc.m_BackIsInvisible = true
	desc.m_M11Compatibility = false
	desc.m_PressureSizeRange = Vector2(1.0, 1.0)
	desc.m_PressureOpacityRange = Vector2(1.0, 1.0)
	desc.m_Opacity = 1.0
	desc.m_SizeVariance = 0.0

	var brush := PrintableBrush.new()
	brush.m_BaseSize_PS = 1.0
	brush.init_brush(desc, TrTransform.identity())
	_expect(brush.update_position_ls(TrTransform.trs(Vector3.UP, Quaternion.IDENTITY, 1.0), 1.0), "printable invisible-back update keeps")
	brush.apply_changes_to_visuals()

	_expect_vec3_close(brush.m_knots[1].nRight, Vector3.LEFT, "printable invisible-back preferred right")
	_expect_vec3_close(brush.m_knots[1].nSurface, Vector3.FORWARD, "printable invisible-back surface")
	_expect_vec3_close(brush.m_geometry.m_Vertices[PrintableBrush.FR], Vector3(-0.5, 1.0, 0.0), "printable invisible-back front right vertex")
	_expect_vec3_close(brush.m_geometry.m_Vertices[PrintableBrush.FT], Vector3(0.0, 1.0, -0.1875), "printable invisible-back front top vertex")
	_expect_vec3_close(brush.m_geometry.m_Normals[PrintableBrush.FR], Vector3.LEFT, "printable invisible-back right normal")
	brush.free()

func _make_printable_brush() -> PrintableBrush:
	var desc := BrushDescriptor.new()
	desc.m_DurableName = "SquarePaper"
	desc.m_RenderBackfaces = false
	desc.m_BackIsInvisible = false
	desc.m_M11Compatibility = false
	desc.m_PressureSizeRange = Vector2(1.0, 1.0)
	desc.m_PressureOpacityRange = Vector2(1.0, 1.0)
	desc.m_Opacity = 1.0
	desc.m_SizeVariance = 0.0

	var brush := PrintableBrush.new()
	brush.m_BaseSize_PS = 1.0
	brush.m_Color = Color(0.6, 0.4, 0.2, 0.1)
	brush.init_brush(desc, TrTransform.identity())
	return brush

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
	push_error("GDSCRIPT_PARITY_PRINTABLEBRUSH: %s" % message)
