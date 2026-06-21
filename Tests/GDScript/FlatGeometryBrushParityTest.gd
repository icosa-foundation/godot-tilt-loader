extends SceneTree

var _failures := 0

func _init() -> void:
	_run()
	quit(1 if _failures > 0 else 0)

func _run() -> void:
	_check_distance_uv_double_sided_geometry()
	_check_distance_uv_atlas_branch()
	_check_stretch_uv_mode()
	_check_stretch_uv_atlas_branch()
	_check_batched_finalization_trims_short_post_break_tail()
	if _failures == 0:
		print("GDSCRIPT_PARITY_FLATBRUSH: all checks passed")

func _check_distance_uv_double_sided_geometry() -> void:
	var brush := _make_flat_brush(FlatGeometryBrush.UVStyle.DISTANCE, true)
	_expect(brush.update_position_ls(TrTransform.trs(Vector3.RIGHT, Quaternion.IDENTITY, 1.0), 1.0), "flat distance first update keeps")
	brush.apply_changes_to_visuals()

	_expect(brush.check_knot_invariants(), "flat distance invariants")
	_expect_equal(brush.NS, 2, "flat double-sided stride")
	_expect_equal(brush.m_geometry.num_verts(), 8, "flat distance vertex count")
	_expect_equal(brush.m_geometry.num_tri_indices(), 12, "flat distance tri index count")
	_expect_equal(brush.m_geometry.m_Tris.slice(0, 6), [0, 2, 6, 7, 3, 1], "flat double-sided first tri pair")
	_expect_vec3_close(brush.m_geometry.m_Vertices[FlatGeometryBrush.BR * brush.NS], Vector3(0.0, 0.5, 0.0), "flat back right")
	_expect_vec3_close(brush.m_geometry.m_Vertices[FlatGeometryBrush.BL * brush.NS], Vector3(0.0, -0.5, 0.0), "flat back left")
	_expect_vec3_close(brush.m_geometry.m_Vertices[FlatGeometryBrush.FR * brush.NS], Vector3(1.0, 0.5, 0.0), "flat front right")
	_expect_vec3_close(brush.m_geometry.m_Normals[0], Vector3.BACK, "flat front normal")
	_expect_vec3_close(brush.m_geometry.m_Normals[1], -Vector3.BACK, "flat backface normal")
	_expect_color_close(brush.m_geometry.m_Colors[0], _color32(Color(0.1, 0.2, 0.3, 0.75)), "flat color32 color")
	_expect_equal(brush.m_geometry.m_Texcoord0.v2[FlatGeometryBrush.BL * brush.NS].y, 0.0, "flat distance v0")
	_expect_equal(brush.m_geometry.m_Texcoord0.v2[FlatGeometryBrush.BR * brush.NS].y, 1.0, "flat distance v1")
	_expect_close(brush.m_geometry.m_Texcoord0.v2[FlatGeometryBrush.FL * brush.NS].x - brush.m_geometry.m_Texcoord0.v2[FlatGeometryBrush.BL * brush.NS].x, 1.0, "flat distance u delta")
	_expect_close(brush.m_geometry.m_Tangents[0].length(), sqrt(2.0), "flat tangent length includes handedness")
	_expect_close(brush.m_geometry.m_Tangents[1].w, -1.0, "flat backface tangent handedness")

	brush.finalize_solitary_brush()
	_expect_equal(brush.mesh_data.vertices.size(), 8, "flat finalized vertex count")
	_expect(brush.m_geometry == null, "flat releases geometry")
	brush.free()

func _check_distance_uv_atlas_branch() -> void:
	var brush := _make_flat_brush(FlatGeometryBrush.UVStyle.DISTANCE, false)
	brush.m_Desc.m_TextureAtlasV = 4
	_expect(brush.update_position_ls(TrTransform.trs(Vector3.RIGHT, Quaternion.IDENTITY, 1.0), 1.0), "flat distance atlas first update keeps")
	brush.apply_changes_to_visuals()

	var random01 := brush.m_rng.in01(brush.m_knots[1].iVert - 1)
	var atlas := int(random01 * 3331.0) % brush.m_Desc.m_TextureAtlasV
	var v0 := atlas / float(brush.m_Desc.m_TextureAtlasV)
	var v1 := (atlas + 1) / float(brush.m_Desc.m_TextureAtlasV)
	_expect_close(brush.m_geometry.m_Texcoord0.v2[FlatGeometryBrush.BL].x, random01, "flat distance atlas u0")
	_expect_close(brush.m_geometry.m_Texcoord0.v2[FlatGeometryBrush.BL].y, v0, "flat distance atlas v0")
	_expect_close(brush.m_geometry.m_Texcoord0.v2[FlatGeometryBrush.BR].y, v1, "flat distance atlas v1")
	_expect_close(brush.m_geometry.m_Texcoord0.v2[FlatGeometryBrush.FL].y, v0, "flat distance atlas front v0")
	_expect_close(brush.m_geometry.m_Texcoord0.v2[FlatGeometryBrush.FR].y, v1, "flat distance atlas front v1")
	brush.finalize_solitary_brush()
	brush.free()

func _check_stretch_uv_mode() -> void:
	var brush := _make_flat_brush(FlatGeometryBrush.UVStyle.STRETCH, false)
	_expect(brush.update_position_ls(TrTransform.trs(Vector3.RIGHT, Quaternion.IDENTITY, 1.0), 1.0), "flat stretch first update keeps")
	_expect(brush.update_position_ls(TrTransform.trs(Vector3(2.0, 0.0, 0.0), Quaternion.IDENTITY, 1.0), 1.0), "flat stretch second update keeps")
	brush.apply_changes_to_visuals()

	_expect_equal(brush.NS, 1, "flat single-sided stride")
	_expect_equal(brush.m_geometry.num_verts(), 6, "flat stretch shared vertex count")
	_expect_equal(brush.m_geometry.num_tri_indices(), 12, "flat stretch tri index count")
	_expect_equal(brush.m_geometry.m_Texcoord0.v2[FlatGeometryBrush.BL].x, 0.0, "flat stretch start x")
	_expect_close(brush.m_geometry.m_Texcoord0.v2[FlatGeometryBrush.FL].x, 0.5, "flat stretch first segment x")
	_expect_close(brush.m_geometry.m_Texcoord0.v2[4 + FlatGeometryBrush.FL - 2].x, 1.0, "flat stretch second segment x")
	brush.finalize_solitary_brush()
	brush.free()

func _check_stretch_uv_atlas_branch() -> void:
	var brush := _make_flat_brush(FlatGeometryBrush.UVStyle.STRETCH, false)
	brush.m_Desc.m_TextureAtlasV = 4
	_expect(brush.update_position_ls(TrTransform.trs(Vector3.RIGHT, Quaternion.IDENTITY, 1.0), 1.0), "flat stretch atlas first update keeps")
	_expect(brush.update_position_ls(TrTransform.trs(Vector3(2.0, 0.0, 0.0), Quaternion.IDENTITY, 1.0), 1.0), "flat stretch atlas second update keeps")
	brush.apply_changes_to_visuals()

	var random01 := brush.m_rng.in01(brush.m_knots[1].iVert - 1)
	var atlas := int(random01 * 3331.0) % brush.m_Desc.m_TextureAtlasV
	var v0 := atlas / float(brush.m_Desc.m_TextureAtlasV)
	var v1 := (atlas + 1) / float(brush.m_Desc.m_TextureAtlasV)
	_expect_close(brush.m_geometry.m_Texcoord0.v2[FlatGeometryBrush.BL].y, v0, "flat stretch atlas start v0")
	_expect_close(brush.m_geometry.m_Texcoord0.v2[FlatGeometryBrush.BR].y, v1, "flat stretch atlas start v1")
	_expect_close(brush.m_geometry.m_Texcoord0.v2[FlatGeometryBrush.FL].y, v0, "flat stretch atlas first front v0")
	_expect_close(brush.m_geometry.m_Texcoord0.v2[FlatGeometryBrush.FR].y, v1, "flat stretch atlas first front v1")
	brush.finalize_solitary_brush()
	brush.free()

func _check_batched_finalization_trims_short_post_break_tail() -> void:
	var brush := _make_flat_brush(FlatGeometryBrush.UVStyle.DISTANCE, false)
	brush.m_bM11Compatibility = false
	_seed_short_post_break_tail(brush)
	_expect_equal(brush.m_geometry.num_verts(), 10, "flat batched seeded vertex count")
	_expect_equal(brush.m_geometry.num_tri_indices(), 18, "flat batched seeded tri index count")

	brush.finalize_batched_brush()

	_expect_equal(brush.m_knots.size(), 4, "flat batched trims short tail knots")
	_expect_equal(brush.mesh_data.vertices.size(), 6, "flat batched trimmed vertex count")
	_expect_equal(brush.mesh_data.triangles.size(), 12, "flat batched trimmed tri index count")
	brush.free()

func _make_flat_brush(uv_style: int, backfaces: bool) -> FlatGeometryBrush:
	var desc := BrushDescriptor.new()
	desc.m_DurableName = "Flat"
	desc.m_RenderBackfaces = backfaces
	desc.m_BackIsInvisible = false
	desc.m_M11Compatibility = true
	desc.m_TextureAtlasV = 1
	desc.m_TileRate = 1.0
	desc.m_PressureSizeRange = Vector2(1.0, 1.0)
	desc.m_PressureOpacityRange = Vector2(1.0, 1.0)
	desc.m_Opacity = 0.75
	desc.m_SizeVariance = 0.0

	var brush := FlatGeometryBrush.new()
	brush.m_uvStyle = uv_style
	brush.m_BaseSize_PS = 1.0
	brush.m_Color = Color(0.1, 0.2, 0.3, 1.0)
	brush.set_random_seed(0)
	brush.init_brush(desc, TrTransform.identity())
	brush.set_random_seed(0)
	return brush

func _seed_short_post_break_tail(brush: FlatGeometryBrush) -> void:
	brush.m_knots.clear()
	brush.m_knots.append(_make_knot(0, 0, 0, 0))
	brush.m_knots.append(_make_knot(0, 4, 0, 2))
	brush.m_knots.append(_make_knot(2, 4, 2, 2))
	brush.m_knots.append(_make_knot(6, 0, 4, 0))
	brush.m_knots.append(_make_knot(6, 4, 4, 2))
	brush.resize_geometry()

func _make_knot(i_vert: int, n_vert: int, i_tri: int, n_tri: int) -> GeometryBrush.Knot:
	var knot := GeometryBrush.Knot.new()
	knot.iVert = i_vert
	knot.nVert = n_vert
	knot.iTri = i_tri
	knot.nTri = n_tri
	knot.point = ControlPoint.create(Vector3.ZERO, Quaternion.IDENTITY, 1.0, 0)
	return knot

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

func _expect_close(actual: float, expected: float, label: String) -> void:
	if abs(actual - expected) > 1e-5:
		_fail("%s expected %.8f but got %.8f" % [label, expected, actual])

func _fail(message: String) -> void:
	_failures += 1
	push_error("GDSCRIPT_PARITY_FLATBRUSH: %s" % message)
