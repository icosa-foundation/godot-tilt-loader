extends SceneTree

var _failures := 0

func _init() -> void:
	_run()
	quit(1 if _failures > 0 else 0)

func _run() -> void:
	_check_layout_and_spawn_interval()
	_check_single_segment_topology()
	_check_two_segment_shared_ring_topology()
	_check_flip_branch_adds_ring_face_and_extra_ring()
	_check_close_segment_break_restarts_stroke()
	if _failures == 0:
		print("GDSCRIPT_PARITY_SQUARE3DPRINT: all checks passed")

func _check_layout_and_spawn_interval() -> void:
	var brush := _make_square3d_brush()
	var layout := brush.get_vertex_layout(brush.m_Desc)

	_expect_equal(layout.texcoord0.size, 0, "square3d uv0 omitted")
	_expect_equal(layout.texcoord1.size, 0, "square3d uv1 omitted")
	_expect(not layout.bUseNormals, "square3d normals omitted")
	_expect(layout.bUseColors, "square3d colors enabled")
	_expect(not layout.bUseTangents, "square3d tangents omitted")
	_expect_close(brush.get_spawn_interval(0.0), 0.05, "square3d default dense spawn interval")

	brush.m_tessellation = 0.0
	_expect_close(brush.get_spawn_interval(1.0), 0.5, "square3d sparse spawn interval clamps to max")
	brush.m_tessellation = 1.0
	brush.m_LastSpawnXf = TrTransform.trs(Vector3.ZERO, Quaternion.IDENTITY, 10.0)
	_expect_close(brush.get_spawn_interval(1.0), 0.1, "square3d dense spawn interval clamps to pointer min")
	brush.free()

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
	_expect_color_close(brush.m_geometry.m_Colors[0], _color32(Color(0.1, 0.8, 0.35, 1.0)), "square3d color32 color")
	_expect(brush.m_geometry.m_Vertices[0].x < 0.0, "square3d start cap offset backward")
	_expect(brush.m_geometry.m_Vertices[0].z < 0.0, "square3d reflected indicator forward sets thickness direction")
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

func _check_flip_branch_adds_ring_face_and_extra_ring() -> void:
	var brush := _make_square3d_brush()
	var orientation := _orientation_with_up_along_x()
	_expect(brush.update_position_ls(TrTransform.trs(Vector3.RIGHT, orientation, 1.0), 1.0), "square3d flip first update keeps")
	_expect(brush.update_position_ls(TrTransform.trs(Vector3.LEFT, orientation, 1.0), 1.0), "square3d flip second update keeps")
	brush.apply_changes_to_visuals()

	_expect(brush.check_knot_invariants(), "square3d flip knot invariants")
	_expect(brush.alignment_parity_reverses(brush.m_knots[2], brush.m_knots[1]), "square3d flip branch active")
	_expect_equal(brush.m_geometry.num_verts(), 40, "square3d flip vertex count")
	_expect_equal(brush.m_geometry.num_tri_indices(), 198, "square3d flip triangle index count")
	_expect_equal(brush.m_knots[1].iVert, 0, "square3d flip first knot vertex start")
	_expect_equal(brush.m_knots[1].nVert, 20, "square3d flip first knot verts")
	_expect_equal(brush.m_knots[1].nTri, 30, "square3d flip first knot tris")
	_expect_equal(brush.m_knots[2].iVert, 12, "square3d flip second knot rewinds shared ring")
	_expect_equal(brush.m_knots[2].nVert, 28, "square3d flip second knot adds closing and current rings")
	_expect_equal(brush.m_knots[2].nTri, 36, "square3d flip second knot tris include ring face")
	_expect_equal(brush.m_geometry.m_Tris.slice(90, 108), [14, 13, 12, 15, 14, 12, 16, 15, 12, 17, 16, 12, 18, 17, 12, 19, 18, 12], "square3d flip closing ring face tris")
	brush.free()

func _check_close_segment_break_restarts_stroke() -> void:
	var brush := _make_square3d_brush()
	var orientation := _orientation_with_up_along_x()
	_expect(brush.update_position_ls(TrTransform.trs(Vector3.RIGHT, orientation, 1.0), 1.0), "square3d close first update keeps")
	_expect(brush.update_position_ls(TrTransform.trs(Vector3(2.0, 0.0, 0.0), orientation, 1.0), 1.0), "square3d close second update keeps")
	brush.apply_changes_to_visuals()

	var close_knot := brush.m_knots[2]
	close_knot.point.m_Pos = brush.m_knots[1].point.m_Pos + Vector3(0.001, 0.0, 0.0)
	close_knot.smoothedPos = close_knot.point.m_Pos
	brush.m_knots[2] = close_knot
	brush.control_points_changed(2)

	_expect(brush.check_knot_invariants(), "square3d close restart knot invariants")
	_expect_equal(brush.m_geometry.num_verts(), 48, "square3d close restart vertex count")
	_expect_equal(brush.m_geometry.num_tri_indices(), 264, "square3d close restart triangle index count")
	_expect_equal(brush.m_knots[1].nVert, 24, "square3d close first segment closed verts")
	_expect_equal(brush.m_knots[1].nTri, 44, "square3d close first segment closed tris")
	_expect(not brush.m_knots[2].has_geometry(), "square3d close knot has no geometry")
	_expect_equal(brush.m_knots[2].nVert, 0, "square3d close knot vertex count")
	_expect_equal(brush.m_knots[2].nTri, 0, "square3d close knot triangle count")
	_expect_equal(brush.m_knots[2].qFrame, Quaternion(0.0, 0.0, 0.0, 0.0), "square3d close knot clears frame")
	_expect(brush.m_knots[3].has_geometry(), "square3d close restart has geometry")
	_expect_equal(brush.m_knots[3].iVert, 24, "square3d close restart vertex start")
	_expect_equal(brush.m_knots[3].iTri, 44, "square3d close restart triangle start")
	_expect_equal(brush.m_knots[3].nVert, 24, "square3d close restart verts")
	_expect_equal(brush.m_knots[3].nTri, 44, "square3d close restart tris")
	brush.free()

func _make_square3d_brush() -> Square3DPrintBrush:
	var desc := BrushDescriptor.new()
	desc.name = "Square3DPrintBrush"
	desc.m_Guid = "d3f3b18a-da03-f694-b838-28ba8e749a98"
	desc.m_DurableName = "3D Printing Brush"
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
	push_error("GDSCRIPT_PARITY_SQUARE3DPRINT: %s" % message)
