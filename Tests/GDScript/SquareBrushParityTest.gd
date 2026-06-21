extends SceneTree

var _failures := 0

func _init() -> void:
	_run()
	quit(1 if _failures > 0 else 0)

func _run() -> void:
	_check_square_brush_layout_and_spawn_interval()
	_check_square_brush_geometry()
	_check_square_brush_shared_ring_continuation()
	_check_square_brush_sharp_turn_breaks_segment()
	_check_square_brush_short_segment_break_restarts()
	_check_square_brush_back_invisible_frame()
	if _failures == 0:
		print("GDSCRIPT_PARITY_SQUAREBRUSH: all checks passed")

func _check_square_brush_layout_and_spawn_interval() -> void:
	var brush := _make_square_brush()
	brush.m_BaseSize_PS = 2.0
	var layout := brush.get_vertex_layout(brush.m_Desc)

	_expect_equal(layout.texcoord0.size, 2, "square uv0 layout size")
	_expect_equal(layout.texcoord0.semantic, GeometryPool.Semantic.XY_IS_UV, "square uv0 semantic")
	_expect(layout.bUseNormals, "square uses normals")
	_expect(layout.bUseColors, "square uses colors")
	_expect(not layout.bUseTangents, "square does not use tangents")
	_expect_close(brush.get_spawn_interval(0.0), 0.42, "square spawn interval pressure 0")
	_expect_close(brush.get_spawn_interval(0.5), 0.42, "square spawn interval pressure 0.5")
	_expect_close(brush.get_spawn_interval(1.0), 0.42, "square spawn interval pressure 1")
	brush.free()

func _check_square_brush_geometry() -> void:
	var desc := BrushDescriptor.new()
	desc.name = "SquarePaper"
	desc.m_Guid = "3d9755da-56c7-7294-9b1d-5ec349975f52"
	desc.m_DurableName = "SquarePaper"
	desc.m_RenderBackfaces = false
	desc.m_BackIsInvisible = false
	desc.m_M11Compatibility = false
	desc.m_PressureSizeRange = Vector2(1.0, 1.0)
	desc.m_PressureOpacityRange = Vector2(1.0, 1.0)
	desc.m_Opacity = 1.0
	desc.m_SizeVariance = 0.0

	var brush := SquareBrush.new()
	brush.m_BaseSize_PS = 1.0
	brush.m_Color = Color(0.25, 0.5, 0.75, 0.2)
	brush.init_brush(desc, TrTransform.identity())

	var kept := brush.update_position_ls(TrTransform.trs(Vector3.RIGHT, Quaternion.IDENTITY, 1.0), 1.0)
	_expect(kept, "square update keeps one solid")
	brush.apply_changes_to_visuals()

	_expect(brush.check_knot_invariants(), "square knot invariants")
	_expect_equal(brush.m_geometry.num_verts(), 16, "square vertex count")
	_expect_equal(brush.m_geometry.num_tri_indices(), 36, "square triangle index count")
	_expect_equal(brush.m_knots[1].nVert, 16, "square knot vertex count")
	_expect_equal(brush.m_knots[1].nTri, 12, "square knot triangle count with end caps")
	_expect(brush.m_knots[1].startsGeometry, "square starts geometry")
	_expect(brush.m_knots[1].endsGeometry, "square ends geometry")

	_expect_equal(brush.m_geometry.m_Tris.slice(0, 6), [4, 2, 12, 12, 2, 10], "square top tris")
	_expect_equal(brush.m_geometry.m_Tris.slice(24, 30), [5, 1, 3, 3, 1, 7], "square start cap tris")

	_expect_vec3_close(brush.m_geometry.m_Vertices[SquareBrush.BBR_B], Vector3(0.0, 0.5, -0.1875), "square back bottom right")
	_expect_vec3_close(brush.m_geometry.m_Vertices[SquareBrush.BTL_T], Vector3(0.0, -0.5, 0.1875), "square back top left")
	_expect_vec3_close(brush.m_geometry.m_Vertices[SquareBrush.FTR_T], Vector3(1.0, 0.5, 0.1875), "square front top right")
	_expect_vec3_close(brush.m_geometry.m_Normals[SquareBrush.FBR_R], Vector3.UP, "square right normal")
	_expect_vec3_close(brush.m_geometry.m_Normals[SquareBrush.FTL_T], Vector3.BACK, "square top normal")
	_expect_equal(brush.m_geometry.m_Texcoord0.v2[SquareBrush.FBL_L], Vector2(0.5, 0.5), "square default uv")
	_expect_color_close(brush.m_geometry.m_Colors[SquareBrush.FBL_L], _color32(Color(0.25, 0.5, 0.75, 1.0)), "square color32 alpha forced opaque")

	brush.finalize_solitary_brush()
	_expect_equal(brush.mesh_data.vertices.size(), 16, "square finalized vertex count")
	_expect(brush.m_geometry == null, "square releases geometry")
	brush.free()

func _check_square_brush_shared_ring_continuation() -> void:
	var brush := _make_square_brush()
	_expect(brush.update_position_ls(TrTransform.trs(Vector3.RIGHT, Quaternion.IDENTITY, 1.0), 1.0), "square continuation first update keeps")
	_expect(brush.update_position_ls(TrTransform.trs(Vector3(2.0, 0.0, 0.0), Quaternion.IDENTITY, 1.0), 1.0), "square continuation second update keeps")
	brush.apply_changes_to_visuals()

	_expect(brush.check_knot_invariants(), "square continuation knot invariants")
	_expect_equal(brush.m_geometry.num_verts(), 24, "square continuation vertex count")
	_expect_equal(brush.m_geometry.num_tri_indices(), 60, "square continuation triangle index count")
	_expect_equal(brush.m_knots[1].iVert, 0, "square continuation first knot vertex start")
	_expect_equal(brush.m_knots[1].nVert, 16, "square continuation first knot verts")
	_expect_equal(brush.m_knots[1].nTri, 10, "square continuation first knot tris with start cap only")
	_expect_equal(brush.m_knots[2].iVert, 8, "square continuation second knot rewinds shared ring")
	_expect_equal(brush.m_knots[2].nVert, 16, "square continuation second knot verts include shared ring")
	_expect_equal(brush.m_knots[2].nTri, 10, "square continuation second knot tris with end cap only")
	_expect(not brush.m_knots[1].endsGeometry, "square continuation first knot has no end cap")
	_expect(brush.m_knots[2].endsGeometry, "square continuation second knot has end cap")
	_expect_vec3_close(brush.m_geometry.m_Vertices[SquareBrush.FBR_B], Vector3(1.0, 0.5, -0.1875), "square continuation shared ring position")
	_expect_vec3_close(brush.m_geometry.m_Vertices[brush.m_knots[2].iVert + SquareBrush.FBR_B], Vector3(2.0, 0.5, -0.1875), "square continuation second front ring position")
	brush.free()

func _check_square_brush_sharp_turn_breaks_segment() -> void:
	var brush := _make_square_brush()
	_expect(brush.update_position_ls(TrTransform.trs(Vector3.RIGHT, Quaternion.IDENTITY, 1.0), 1.0), "square break first update keeps")
	_expect(brush.update_position_ls(TrTransform.trs(Vector3.ZERO, Quaternion.IDENTITY, 1.0), 1.0), "square break reverse update keeps")
	_expect(brush.update_position_ls(TrTransform.trs(Vector3.LEFT, Quaternion.IDENTITY, 1.0), 1.0), "square break new segment update keeps")
	brush.apply_changes_to_visuals()

	_expect(brush.check_knot_invariants(), "square break knot invariants")
	_expect_equal(brush.m_geometry.num_verts(), 32, "square break vertex count")
	_expect_equal(brush.m_geometry.num_tri_indices(), 72, "square break triangle index count")
	_expect(brush.m_knots[1].endsGeometry, "square break first segment closed")
	_expect(not brush.m_knots[2].has_geometry(), "square break reversing knot has no geometry")
	_expect(brush.m_knots[3].startsGeometry, "square break new segment starts")
	_expect(brush.m_knots[3].endsGeometry, "square break new segment ends")
	_expect_equal(brush.m_knots[3].iVert, 16, "square break new segment vertex start")
	_expect_equal(brush.m_geometry.m_Tris.slice(24, 36), [5, 1, 3, 3, 1, 7, 13, 11, 9, 9, 11, 15], "square break first segment caps")
	brush.free()

func _check_square_brush_short_segment_break_restarts() -> void:
	var brush := _make_square_brush()
	_expect(brush.update_position_ls(TrTransform.trs(Vector3.RIGHT, Quaternion.IDENTITY, 1.0), 1.0), "square short first update keeps")
	_expect(brush.update_position_ls(TrTransform.trs(Vector3(2.0, 0.0, 0.0), Quaternion.IDENTITY, 1.0), 1.0), "square short second update keeps")
	brush.apply_changes_to_visuals()

	var short_knot := brush.m_knots[2]
	short_knot.point.m_Pos = brush.m_knots[1].point.m_Pos + Vector3(0.0001, 0.0, 0.0)
	brush.m_knots[2] = short_knot
	brush.control_points_changed(2)

	_expect(brush.check_knot_invariants(), "square short restart knot invariants")
	_expect_equal(brush.m_geometry.num_verts(), 32, "square short restart vertex count")
	_expect_equal(brush.m_geometry.num_tri_indices(), 72, "square short restart triangle index count")
	_expect(brush.m_knots[1].endsGeometry, "square short closes previous segment")
	_expect(not brush.m_knots[2].has_geometry(), "square short knot has no geometry")
	_expect_equal(brush.m_knots[2].nVert, 0, "square short knot vertex count")
	_expect_equal(brush.m_knots[2].nTri, 0, "square short knot triangle count")
	_expect_vec3_close(brush.m_knots[2].nRight, Vector3.ZERO, "square short knot right reset")
	_expect_vec3_close(brush.m_knots[2].nSurface, Vector3.ZERO, "square short knot surface reset")
	_expect(brush.m_knots[3].startsGeometry, "square short restart starts new segment")
	_expect(brush.m_knots[3].endsGeometry, "square short restart ends new segment")
	_expect_equal(brush.m_knots[3].iVert, 16, "square short restart vertex start")
	_expect_equal(brush.m_knots[3].iTri, 12, "square short restart tri start")
	brush.free()

func _check_square_brush_back_invisible_frame() -> void:
	var desc := BrushDescriptor.new()
	desc.name = "SquarePaper"
	desc.m_Guid = "3d9755da-56c7-7294-9b1d-5ec349975f52"
	desc.m_DurableName = "SquarePaper"
	desc.m_RenderBackfaces = false
	desc.m_BackIsInvisible = true
	desc.m_M11Compatibility = false
	desc.m_PressureSizeRange = Vector2(1.0, 1.0)
	desc.m_PressureOpacityRange = Vector2(1.0, 1.0)
	desc.m_Opacity = 1.0
	desc.m_SizeVariance = 0.0

	var brush := SquareBrush.new()
	brush.m_BaseSize_PS = 1.0
	brush.init_brush(desc, TrTransform.identity())
	_expect(brush.update_position_ls(TrTransform.trs(Vector3.UP, Quaternion.IDENTITY, 1.0), 1.0), "square invisible-back update keeps")
	brush.apply_changes_to_visuals()

	_expect_vec3_close(brush.m_knots[1].nRight, Vector3.LEFT, "square invisible-back preferred right")
	_expect_vec3_close(brush.m_knots[1].nSurface, Vector3.FORWARD * -1.0, "square invisible-back surface")
	_expect_vec3_close(brush.m_geometry.m_Vertices[SquareBrush.FBR_R], Vector3(-0.5, 1.0, -0.1875), "square invisible-back front right vertex")
	_expect_vec3_close(brush.m_geometry.m_Normals[SquareBrush.FBR_R], Vector3.LEFT, "square invisible-back right normal")
	brush.free()

func _make_square_brush() -> SquareBrush:
	var desc := BrushDescriptor.new()
	desc.name = "SquarePaper"
	desc.m_Guid = "3d9755da-56c7-7294-9b1d-5ec349975f52"
	desc.m_DurableName = "SquarePaper"
	desc.m_RenderBackfaces = false
	desc.m_BackIsInvisible = false
	desc.m_M11Compatibility = false
	desc.m_PressureSizeRange = Vector2(1.0, 1.0)
	desc.m_PressureOpacityRange = Vector2(1.0, 1.0)
	desc.m_Opacity = 1.0
	desc.m_SizeVariance = 0.0

	var brush := SquareBrush.new()
	brush.m_BaseSize_PS = 1.0
	brush.m_Color = Color(0.25, 0.5, 0.75, 0.2)
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
	push_error("GDSCRIPT_PARITY_SQUAREBRUSH: %s" % message)
